#!/usr/bin/env python3
"""Target-generated residual proposals at a retained-token handoff."""
import argparse
import hashlib
import heapq
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'qwen'))
from pilot import CORPUS, DATA, MODEL, Drafter, load_target

OUT = DATA / 'residual-drafter'
BUDGETS = (6, 18, 32, 64)
HORIZON = 6


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def receipt(name, data):
    OUT.mkdir(parents=True, exist_ok=True)
    data['source_sha256'] = sha(__file__)
    (OUT / name).write_text(json.dumps(data, indent=2) + '\n')
    source_dir = OUT / 'sources'
    source_dir.mkdir(exist_ok=True)
    (source_dir / (data['source_sha256'] + '.py')).write_bytes(Path(__file__).read_bytes())


def capture(args):
    tokenizer, model = load_target()
    text = CORPUS / 'train.txt'
    ids = np.asarray(tokenizer(text.read_text(), add_special_tokens=False)['input_ids'])
    prior = set(json.loads((DATA / 'train.json').read_text())['starts'])
    rng = np.random.default_rng(2026092307)
    eligible = np.asarray([i * 128 for i in range(len(ids)//128) if i*128 not in prior])
    starts = rng.choice(eligible, size=args.windows, replace=False)
    features, roots, continuations = [], [], []
    begun = time.perf_counter()
    with torch.inference_mode():
        for offset in range(0, len(starts), args.batch):
            contexts = torch.tensor(np.stack([ids[s:s+64] for s in starts[offset:offset+args.batch]]),
                                    device='cuda', dtype=torch.long)
            out = model.model(contexts, use_cache=True)
            h, cache = out.last_hidden_state[:, -1], out.past_key_values
            features.append(h.float().half().cpu())
            roots.append(contexts[:, -1].cpu())
            generated = []
            for _ in range(HORIZON):
                token = model.lm_head(h).argmax(-1)
                generated.append(token.cpu())
                out = model.model(token[:, None], past_key_values=cache, use_cache=True)
                h, cache = out.last_hidden_state[:, -1], out.past_key_values
            continuations.append(torch.stack(generated, 1))
    payload = {'hidden': torch.cat(features), 'anchor': torch.cat(roots),
               'future': torch.cat(continuations)}
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / 'train-target.pt'
    torch.save(payload, path)
    record = {'target_generated': True, 'split': 'train', 'model_revision': json.loads((MODEL/'source.json').read_text())['revision'],
              'corpus_sha256': sha(text), 'prior_pilot_train_starts_excluded': len(prior),
              'starts': starts.tolist(), 'context_length': 64, 'horizon': HORIZON,
              'rows': len(starts), 'batch_size': args.batch,
              'numerics': 'original BF16 model and BF16 lm_head argmax; FP16 saved normalized anchor feature',
              'elapsed_seconds': time.perf_counter()-begun, 'artifact_sha256': sha(path)}
    receipt('train-target.json', record)
    print(json.dumps({k: v for k, v in record.items() if k != 'starts'}), flush=True)


class Residual(nn.Module):
    def __init__(self, vocab):
        super().__init__()
        self.trunk = nn.Sequential(nn.LayerNorm(1024), nn.Linear(1024, 256), nn.SiLU(),
                                   nn.Linear(256, (HORIZON-1)*128))
        self.output = nn.Linear(128, 1024)
        nn.init.zeros_(self.output.weight)
        nn.init.zeros_(self.output.bias)
        self.labels = nn.Embedding(vocab+1, 32)
        self.gate = nn.Linear(128, 32)
        self.register_buffer('target_head', torch.zeros(vocab, 1024))
        self.register_buffer('vocabulary', torch.zeros(vocab, dtype=torch.long))

    def backbone(self, hidden):
        state = self.trunk(hidden).reshape(-1, HORIZON-1, 128)
        base = F.linear(hidden[:, None, :] + self.output(state), self.target_head)
        return base, self.gate(state)

    def logits(self, base, gate, previous):
        state = self.labels(previous) * torch.tanh(gate)
        return base + (state @ self.labels.weight[:-1].T) / (32**0.5)

    def forward(self, hidden, trajectory):
        base, gate = self.backbone(hidden)
        return self.logits(base, gate, trajectory[:, :-1])


def load_split(path, lookup, device):
    raw = torch.load(path, weights_only=True, map_location='cpu')
    return (raw['hidden'].float().to(device), lookup[raw['future']].to(device), raw)


def fit(args):
    from safetensors import safe_open
    train = torch.load(OUT/'train-target.pt', weights_only=True, map_location='cpu')
    counts = torch.bincount(train['future'].flatten(), minlength=151936)
    corpus = torch.load(DATA/'train.pt', weights_only=True, map_location='cpu')
    corpus_counts = torch.bincount(corpus['future'].flatten(), minlength=151936)
    target_rank = torch.argsort(counts, descending=True, stable=True)
    corpus_rank = torch.argsort(corpus_counts, descending=True, stable=True)
    target_tokens = target_rank[counts[target_rank] > 0]
    assert len(target_tokens) <= args.vocab
    extra = corpus_rank[~torch.isin(corpus_rank, target_tokens)][:args.vocab-len(target_tokens)]
    vocab = torch.cat([target_tokens, extra])
    lookup = torch.full((151936,), args.vocab, dtype=torch.long)
    lookup[vocab] = torch.arange(args.vocab)
    x, y, _ = load_split(OUT/'train-target.pt', lookup, 'cuda')
    vx, vy, _ = load_split(DATA/'validation-greedy.pt', lookup, 'cuda')
    torch.manual_seed(2026092308)
    model = Residual(args.vocab).cuda()
    model.vocabulary.copy_(vocab.cuda())
    with safe_open(MODEL/'model.safetensors', framework='pt', device='cpu') as weights:
        model.target_head.copy_(weights.get_tensor('model.embed_tokens.weight')[vocab].float().cuda())
    optimizer = torch.optim.AdamW(model.parameters(), lr=0.001, weight_decay=0.01)
    generator = torch.Generator(device='cuda').manual_seed(811)
    curve = []
    best = None
    begun = time.perf_counter()
    for step in range(1, args.steps+1):
        idx = torch.randint(len(x), (64,), device='cuda', generator=generator)
        logits = model(x[idx], y[idx])
        loss = F.cross_entropy(logits.flatten(0, 1), y[idx, 1:].flatten(), ignore_index=args.vocab)
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        optimizer.step()
        if step in (50, 100, 200, args.steps):
            with torch.no_grad():
                model.eval()
                vl = model(vx, vy)
                held = F.cross_entropy(vl.flatten(0, 1), vy[:, 1:].flatten(), ignore_index=args.vocab).item()
                curve.append({'step': step, 'train_batch_nll': loss.item(), 'validation_in_vocab_nll': held})
                if best is None or held < best[0]:
                    best = (held, step, {key: value.detach().cpu().clone() for key, value in model.state_dict().items()})
                model.train()
    torch.cuda.synchronize()
    elapsed = time.perf_counter()-begun
    path = OUT/f'residual-v{args.vocab}-s{args.steps}.pt'
    torch.save(best[2], path)
    record = {'steps': args.steps, 'selected_step_by_validation_nll': best[1],
              'vocabulary_size': args.vocab, 'train_rows': len(x),
              'training_seconds': elapsed, 'curve': curve,
              'learned_parameters': sum(p.numel() for p in model.parameters()),
              'frozen_shared_target_head_values': model.target_head.numel(),
              'frozen_shared_target_head_fp32_bytes': model.target_head.numel()*4,
              'stored_vocabulary_ids_bytes': model.vocabulary.numel()*8,
              'training_residual_token_coverage': float((y[:, 1:] != args.vocab).float().mean()),
              'validation_residual_token_coverage': float((vy[:, 1:] != args.vocab).float().mean()),
              'target_observed_vocabulary_ids': len(target_tokens),
              'supplemental_ids_from_pilot_corpus_train_frequency': len(extra),
              'pilot_corpus_train_sha256': sha(DATA/'train.pt'),
              'training_first_token_in_vocabulary': float((y[:, 0] != args.vocab).float().mean()),
              'validation_first_token_in_vocabulary': float((vy[:, 0] != args.vocab).float().mean()),
              'train_sha256': sha(OUT/'train-target.pt'), 'validation_sha256': sha(DATA/'validation-greedy.pt'),
              'checkpoint_sha256': sha(path)}
    receipt(path.stem+'.json', record)
    print(json.dumps(record), flush=True)


def proposed(model, hidden, known_root, adaptive):
    with torch.no_grad():
        base, gate = model.backbone(hidden[None])
        base, gate = base[0], gate[0]
        static = base.topk(16, dim=-1).indices
        tree = [(known_root,)]
        heap = []
        cache = {}

        def children(prefix):
            pos = len(prefix)-1
            previous = prefix[-1]
            key = (pos, previous)
            if key not in cache:
                logits = model.logits(base[pos], gate[pos], torch.tensor(previous))
                pool = logits.topk(16).indices if adaptive else static[pos]
                logp = logits.log_softmax(-1)
                cache[key] = [(int(tok), float(logp[tok])) for tok in pool]
            return cache[key]

        for token, score in children((known_root,)):
            heapq.heappush(heap, (-score, (known_root, token)))
        while heap and len(tree) < max(BUDGETS):
            negscore, prefix = heapq.heappop(heap)
            tree.append(prefix)
            if len(prefix) < HORIZON:
                for token, score in children(prefix):
                    heapq.heappush(heap, (negscore-score, prefix+(token,)))
        return tree, base, gate, len(cache)


def depth(nodes, target):
    selected = set(nodes)
    return next((j for j in range(1, HORIZON+1) if target[:j] not in selected), HORIZON+1)


def evaluate(args):
    from pilot import trees as baseline_trees
    import importlib.util
    spec = importlib.util.spec_from_file_location('candidate_repair', HERE.parent/'candidate-repair'/'experiment.py')
    repair = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(repair)
    forced_tree = repair.forced_tree
    checkpoint = OUT/f'residual-v{args.vocab}-s{args.steps}.pt'
    state = torch.load(checkpoint, weights_only=True, map_location='cpu')
    model = Residual(args.vocab)
    model.load_state_dict(state)
    model.eval()
    prior = torch.load(DATA/'conditional-s200.pt', weights_only=True, map_location='cpu')
    baseline = Drafter(len(prior['vocabulary']), True)
    baseline.load_state_dict(prior)
    baseline.eval()
    lookup = torch.full((151936,), args.vocab, dtype=torch.long)
    lookup[model.vocabulary] = torch.arange(args.vocab)
    old_lookup = torch.full((151936,), len(prior['vocabulary']), dtype=torch.long)
    old_lookup[prior['vocabulary']] = torch.arange(len(prior['vocabulary']))
    result = {'checkpoint_sha256': sha(checkpoint), 'baseline_checkpoint_sha256': sha(DATA/'conditional-s200.pt'),
              'budgets': BUDGETS, 'pool_width': 16, 'splits': {},
              'known_first_token': 'retained original BF16 target greedy decision; counted once, never counted as learned acceptance',
              'bonus': 'one target exit token after matched draft prefix; not a predicted token'}
    for split in ('validation-greedy', 'test-greedy'):
        raw = torch.load(DATA/(split+'.pt'), weights_only=True, map_location='cpu')
        rows = {arm: {str(b): [] for b in BUDGETS} for arm in ('conditional_s200', 'first_token_graft_s200', 'residual_static', 'residual_adaptive')}
        misses = {k: 0 for k in ('first_oov', 'residual_oov', 'static_pool', 'adaptive_pool')}
        accounted = {'static_correction_rows_scored': 0, 'adaptive_correction_rows_scored': 0}
        begun = time.perf_counter()
        for hidden, original_anchor, target_ids in zip(raw['hidden'].float(), raw['anchor'], raw['future']):
            target = tuple(lookup[target_ids].tolist())
            old_target = tuple(old_lookup[target_ids].tolist())
            known, old_known = target[0], old_target[0]
            misses['first_oov'] += known == args.vocab
            misses['residual_oov'] += sum(t == args.vocab for t in target[1:])
            for budget in BUDGETS:
                _, old_tree = baseline_trees(baseline, hidden, int(old_lookup[original_anchor]), budget, 16)
                _, graft = forced_tree(baseline, hidden, int(old_lookup[original_anchor]), old_known, budget, 16)
                rows['conditional_s200'][str(budget)].append(depth(old_tree, old_target))
                rows['first_token_graft_s200'][str(budget)].append(depth(graft, old_target))
            for adaptive, arm in ((False, 'residual_static'), (True, 'residual_adaptive')):
                ordered, base, gate, scored_rows = proposed(model, hidden, known, adaptive)
                accounted[('adaptive' if adaptive else 'static')+'_correction_rows_scored'] += scored_rows
                for budget in BUDGETS:
                    rows[arm][str(budget)].append(depth(ordered[:budget], target))
                for pos in range(1, HORIZON):
                    previous = target[pos-1]
                    logits = model.logits(base[pos-1], gate[pos-1], torch.tensor(previous))
                    pool = logits.topk(16).indices if adaptive else base[pos-1].topk(16).indices
                    if target[pos] not in pool:
                        misses['adaptive_pool' if adaptive else 'static_pool'] += 1
        split_result = {'fixture_sha256': sha(DATA/(split+'.pt')), 'rows': len(raw['hidden']),
                        'means_including_bonus': {arm: {budget: float(np.mean(values)) for budget, values in by_budget.items()}
                                                  for arm, by_budget in rows.items()},
                        'mean_newly_accepted_residual_tokens': {
                            arm: {budget: float(np.mean(values)-2) for budget, values in rows[arm].items()}
                            for arm in ('first_token_graft_s200', 'residual_static', 'residual_adaptive')},
                        'per_context_including_bonus': rows, 'misses_all_five_residual_positions': misses,
                        'tree_correction_rows_scored': accounted, 'cpu_reference_seconds': time.perf_counter()-begun}
        result['splits'][split] = split_result
        print(split, split_result['means_including_bonus'], misses, flush=True)
    result['accounting'] = {'known_anchor_nodes_per_tree': 1, 'new_draft_nodes_per_tree': [b-1 for b in BUDGETS],
        'all_learned_parameters': sum(p.numel() for p in model.parameters()),
        'shared_frozen_target_head_values': model.target_head.numel(),
        'static_vocabulary_ids': args.vocab,
        'shortlist_projection_values_per_context': (HORIZON-1)*args.vocab*1024,
        'shortlist_projection_fp32_weight_bytes_if_streamed': args.vocab*1024*4,
        'full_target_head_extra_if_retained_token_is_not_available': '151936*1024*2 BF16 bytes and ~311M FLOPs',
        'candidate_pool_search': 'static: 5 base top-16 pools plus conditioned correction rows for path probabilities; adaptive: a top-16 for every distinct conditioned position/predecessor row, cached per context',
        'verifier': 'not run; target greedy prefix membership only, no tree attention or KV adoption'}
    receipt(f'results-v{args.vocab}-s{args.steps}.json', result)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('capture', 'fit', 'evaluate'))
    parser.add_argument('--windows', type=int, default=2048)
    parser.add_argument('--batch', type=int, default=16)
    parser.add_argument('--vocab', type=int, default=4096)
    parser.add_argument('--steps', type=int, default=200)
    args = parser.parse_args()
    torch.set_num_threads(4)
    {'capture': capture, 'fit': fit, 'evaluate': evaluate}[args.action](args)


if __name__ == '__main__':
    main()
