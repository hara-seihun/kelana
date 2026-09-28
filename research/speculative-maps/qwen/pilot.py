#!/usr/bin/env python3
"""Small cached-feature experiment; proposal quality is not serving throughput."""
import argparse
import hashlib
import heapq
import json
import time
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

DATA = Path('/path/to/workspace/data/kelana-speculative')
SOURCE = Path('/path/to/workspace/data/kelana-subbit')
MODEL = SOURCE / 'models/qwen3-0.6b'
CORPUS = SOURCE / 'corpus/wikitext-2-raw'
HORIZON = 6


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def load_target():
    from transformers import AutoModelForCausalLM, AutoTokenizer
    tokenizer = AutoTokenizer.from_pretrained(MODEL, local_files_only=True)
    tokenizer.model_max_length = 10**12
    model = AutoModelForCausalLM.from_pretrained(
        MODEL, local_files_only=True, dtype=torch.bfloat16,
        attn_implementation='sdpa').eval().to('cuda')
    return tokenizer, model


def capture(args):
    tokenizer, model = load_target()
    text_path = CORPUS / (args.split + '.txt')
    ids = np.asarray(tokenizer(text_path.read_text(), add_special_tokens=False)['input_ids'])
    rng = np.random.default_rng({'train': 932311, 'validation': 932312, 'test': 932313}[args.split])
    length = 128
    starts = rng.choice(len(ids)//length, args.windows, replace=False)*length
    hidden, future, anchor, greedy = [], [], [], []
    begun = time.perf_counter()
    with torch.inference_mode():
        for start in starts:
            x = torch.tensor(ids[start:start+length], device='cuda').long()[None]
            if args.greedy:
                x = x[:, :64]
                out = model.model(x, use_cache=True)
                h = out.last_hidden_state[:, -1]
                hidden.append(h.float().cpu())
                anchor.append(x[:, -1].cpu())
                cache = out.past_key_values
                tokens = []
                for _ in range(HORIZON):
                    tok = model.lm_head(h).argmax(-1)
                    tokens.append(tok.cpu())
                    out = model.model(tok[:, None], past_key_values=cache, use_cache=True)
                    cache = out.past_key_values
                    h = out.last_hidden_state[:, -1]
                greedy.append(torch.stack(tokens, dim=1))
            else:
                h = model.model(x, use_cache=False).last_hidden_state[0]
                # Position t sees only x[:t+1]; labels are the following six corpus tokens.
                pos = torch.arange(16, length-HORIZON, device='cuda')
                hidden.append(h[pos].float().cpu())
                future.append(torch.stack([x[0, pos+j] for j in range(1, HORIZON+1)], 1).cpu())
                anchor.append(x[0, pos].cpu())
    name = args.split + ('-greedy' if args.greedy else '')
    dest = DATA / (name + '.pt')
    dest.parent.mkdir(parents=True, exist_ok=True)
    payload = {'hidden': torch.cat(hidden).half(), 'anchor': torch.cat(anchor),
               'future': torch.cat(greedy if args.greedy else future)}
    torch.save(payload, dest)
    record = {'model_revision': json.loads((MODEL/'source.json').read_text())['revision'],
              'corpus_sha256': sha(text_path), 'starts': starts.tolist(), 'window_length': length,
              'context_length': 64 if args.greedy else '16..121 prior tokens plus anchor',
              'kind': 'target greedy trajectories' if args.greedy else 'corpus teacher-forced labels',
              'split': args.split, 'rows': len(payload['hidden']), 'horizon': HORIZON,
              'dtype': 'BF16 target, FP16 saved final normalized hidden',
              'elapsed_seconds': time.perf_counter()-begun, 'sha256': sha(dest),
              'source_sha256': sha(__file__), 'torch': torch.__version__}
    save_json(dest.with_suffix('.json'), record)
    print(json.dumps(record), flush=True)


class Drafter(nn.Module):
    def __init__(self, vocab, conditional):
        super().__init__()
        self.conditional = conditional
        self.trunk = nn.Sequential(nn.LayerNorm(1024), nn.Linear(1024, 256), nn.SiLU(),
                                   nn.Linear(256, HORIZON*128))
        self.output = nn.Linear(128, 1024)
        nn.init.zeros_(self.output.weight)
        nn.init.zeros_(self.output.bias)
        self.register_buffer('target_head', torch.zeros(vocab, 1024))
        # This small shared code is both the incoming state and the outgoing scorer.
        self.labels = nn.Embedding(vocab+1, 32)
        self.gate = nn.Linear(128, 32)
        self.register_buffer('vocabulary', torch.zeros(vocab, dtype=torch.long))

    def backbone(self, x):
        h = self.trunk(x).reshape(-1, HORIZON, 128)
        projected = x[:, None, :] + self.output(h)
        return F.linear(projected, self.target_head), self.gate(h)

    def logits(self, base, gate, previous):
        if not self.conditional:
            return base
        state = self.labels(previous)*torch.tanh(gate)
        return base + (state @ self.labels.weight[:-1].T) / (32**0.5)

    def forward(self, x, anchor, future):
        base, gate = self.backbone(x)
        previous = torch.cat([anchor[:, None], future[:, :-1]], dim=1)
        return self.logits(base, gate, previous)


def dataset(split, lookup, device):
    raw = torch.load(DATA/(split+'.pt'), weights_only=True)
    return (raw['hidden'].float().to(device), lookup[raw['anchor']].to(device),
            lookup[raw['future']].to(device), raw['future'])


def fit(args):
    device = 'cuda' if args.gpu else 'cpu'
    raw = torch.load(DATA/'train.pt', weights_only=True)
    counts = torch.bincount(raw['future'].flatten(), minlength=151936)
    vocab = torch.argsort(counts, descending=True, stable=True)[:args.vocab]
    lookup = torch.full((151936,), args.vocab, dtype=torch.long)
    lookup[vocab] = torch.arange(args.vocab)
    x, anchor, y, _ = dataset('train', lookup, device)
    vx, va, vy, _ = dataset('validation', lookup, device)
    torch.manual_seed(20260923)
    model = Drafter(args.vocab, args.arm == 'conditional').to(device)
    model.vocabulary.copy_(vocab)
    from safetensors import safe_open
    with safe_open(MODEL/'model.safetensors', framework='pt', device='cpu') as weights:
        rows = weights.get_tensor('model.embed_tokens.weight')[vocab].float()
    model.target_head.copy_(rows)
    optimizer = torch.optim.AdamW(model.parameters(), lr=0.002, weight_decay=0.01)
    rng = torch.Generator(device=device).manual_seed(811)
    t0 = time.perf_counter()
    losses = []
    for step in range(args.steps):
        idx = torch.randint(len(x), (64,), generator=rng, device=device)
        logits = model(x[idx], anchor[idx], y[idx])
        loss = F.cross_entropy(logits.flatten(0, 1), y[idx].flatten(), ignore_index=args.vocab)
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        optimizer.step()
        if step % 50 == 0:
            losses.append({'step': step, 'nll': loss.item()})
    if device == 'cuda':
        torch.cuda.synchronize()
    elapsed = time.perf_counter()-t0
    model.eval()
    with torch.inference_mode():
        numerator = correct = total = 0
        for start in range(0, len(vx), 128):
            labels = vy[start:start+128]
            logits = model(vx[start:start+128], va[start:start+128], labels)
            numerator += F.cross_entropy(logits.flatten(0, 1), labels.flatten(),
                                          ignore_index=args.vocab, reduction='sum').item()
            mask = labels != args.vocab
            correct += ((logits.argmax(-1) == labels) & mask).sum().item()
            total += mask.sum().item()
    checkpoint = DATA/(args.arm+f'-s{args.steps}.pt')
    torch.save(model.cpu().state_dict(), checkpoint)
    record = {'arm': args.arm, 'steps': args.steps, 'vocabulary_size': args.vocab,
              'parameters': sum(p.numel() for p in model.parameters()),
              'shared_target_head_values': model.target_head.numel(),
              'active_parameters': sum(p.numel() for n,p in model.named_parameters()
                                       if args.arm == 'conditional' or not n.startswith(('labels.', 'gate.'))),
              'training_seconds': elapsed, 'training_curve': losses,
              'held_teacher_forced_in_shortlist_nll': numerator/total,
              'held_teacher_forced_in_shortlist_accuracy': correct/total,
              'held_shortlist_coverage': total/vy.numel(),
              'train_sha256': sha(DATA/'train.pt'), 'validation_sha256': sha(DATA/'validation.pt'),
              'checkpoint_sha256': sha(checkpoint), 'source_sha256': sha(__file__),
              'device': device, 'torch': torch.__version__,
              'contract': 'trained proposal only; no target weight changes; shortlist misses reject'}
    save_json(checkpoint.with_suffix('.json'), record)
    print(json.dumps(record), flush=True)


def trees(model, hidden, anchor, budget, width):
    with torch.no_grad():
        base, gate = model.backbone(hidden[None])
        base, gate = base[0], gate[0]
        # Position-wise shortlist is fixed before branch choices. Conditional scores
        # are normalized over the complete trained vocabulary, not this width.
        candidate_ids = base.topk(width, dim=-1).indices
        def children(prefix):
            d = len(prefix)
            prev = anchor if d == 0 else prefix[-1]
            logits = model.logits(base[d], gate[d], torch.tensor(prev))
            logp = logits.log_softmax(-1)
            cand = candidate_ids[d]
            return [(int(i), float(logp[i])) for i in cand]
        chain = []
        while len(chain) < HORIZON:
            choice = max(children(chain), key=lambda z: (z[1], -z[0]))[0]
            chain.append(choice)
        tree = set()
        heap = [(-lp, (tok,)) for tok, lp in children(())]
        heapq.heapify(heap)
        while heap and len(tree) < budget:
            nlogp, prefix = heapq.heappop(heap)
            tree.add(prefix)
            if len(prefix) < HORIZON:
                for tok, lp in children(prefix):
                    heapq.heappush(heap, (nlogp-lp, prefix+(tok,)))
        return chain, tree


def evaluate(args):
    record = {'source_sha256': sha(__file__), 'rows': {}, 'arms': {}}
    for arm in ['independent', 'conditional']:
        state = torch.load(DATA/(arm+f'-s{args.steps}.pt'), weights_only=True)
        vocab = state['vocabulary']
        model = Drafter(len(vocab), arm == 'conditional')
        model.load_state_dict(state)
        model.eval()
        lookup = torch.full((151936,), len(vocab), dtype=torch.long)
        lookup[vocab] = torch.arange(len(vocab))
        stats = {}
        for split in ['validation-greedy', 'test-greedy']:
            x, anchor, y, _ = dataset(split, lookup, 'cpu')
            record['rows'][split] = len(x)
            stats[split] = {}
            for budget in [6, 18, 32, 64]:
                progress, chain_progress, counts, pool_oracles, vocab_oracles = [], [], [], [], []
                started = time.perf_counter()
                for h, a, target in zip(x, anchor, y):
                    chain, tree = trees(model, h, int(a), budget, args.width)
                    path = tuple(target.tolist())
                    depth = next((j for j in range(HORIZON) if path[:j+1] not in tree), HORIZON)
                    cdepth = next((j for j in range(HORIZON) if path[j] != chain[j]), HORIZON)
                    with torch.no_grad():
                        base, _ = model.backbone(h[None])
                        candidates = base[0].topk(args.width, dim=-1).indices
                    pool_depth = next((j for j in range(HORIZON)
                                       if not bool((candidates[j] == target[j]).any())), HORIZON)
                    vocab_depth = next((j for j in range(HORIZON)
                                        if target[j] == len(vocab)), HORIZON)
                    pool_oracles.append(pool_depth+1)
                    vocab_oracles.append(vocab_depth+1)
                    progress.append(depth+1)
                    chain_progress.append(cdepth+1)
                    counts.append(len(tree))
                stats[split][str(budget)] = {
                    'tree_mean_tokens_including_bonus': float(np.mean(progress)),
                    'chain_mean_tokens_including_bonus': float(np.mean(chain_progress)),
                    'per_context_tree': progress, 'per_context_chain': chain_progress,
                    'mean_candidate_nodes': float(np.mean(counts)),
                    'candidate_pool_oracle_tokens': float(np.mean(pool_oracles)),
                    'vocabulary_oracle_tokens': float(np.mean(vocab_oracles)),
                    'cpu_construction_total_seconds': time.perf_counter()-started}
        record['arms'][arm] = {'checkpoint_sha256': sha(DATA/(arm+f'-s{args.steps}.pt')), 'metrics': stats}
    record['interpretation'] = ('Exact prefix agreement on cached BF16 target greedy trajectories, '
        'not online speculative-engine throughput. Bonus is the one target token at the exit, '
        'or after a full six-token match. Runtime cache equivalence is not exercised. '
        'Tree nodes are scored under the learned proposal, not target probability. '
        'CPU Python construction timing is an implementation cost, not a native comparison.')
    save_json(DATA/f'evaluation-s{args.steps}.json', record)
    print(json.dumps(record), flush=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['capture', 'fit', 'evaluate'])
    p.add_argument('--split', choices=['train', 'validation', 'test'], default='train')
    p.add_argument('--windows', type=int, default=32)
    p.add_argument('--greedy', action='store_true')
    p.add_argument('--arm', choices=['independent', 'conditional'], default='independent')
    p.add_argument('--steps', type=int, default=200)
    p.add_argument('--vocab', type=int, default=2048)
    p.add_argument('--width', type=int, default=16)
    p.add_argument('--gpu', action='store_true')
    args = p.parse_args()
    torch.set_num_threads(4)
    torch.manual_seed(9323)
    DATA.mkdir(parents=True, exist_ok=True)
    sources = DATA/'sources'
    sources.mkdir(exist_ok=True)
    (sources/(sha(__file__)+'.py')).write_bytes(Path(__file__).read_bytes())
    {'capture': capture, 'fit': fit, 'evaluate': evaluate}[args.action](args)


if __name__ == '__main__':
    main()
