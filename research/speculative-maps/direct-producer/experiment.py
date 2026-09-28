#!/usr/bin/env python3
"""CPU-only direct candidate-ID producer after a retained target token."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('residual_producer', HERE.parent/'residual-drafter/experiment.py')
residual = importlib.util.module_from_spec(spec)
spec.loader.exec_module(residual)
BUDGETS, HORIZON, RESIDUAL, DATA = residual.BUDGETS, residual.HORIZON, residual.OUT, residual.DATA
depth, proposed = residual.depth, residual.proposed

OUT = DATA / 'direct-producer'
VOCAB = 4096
WIDTH = 64
CODE = 16


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class Direct(nn.Module):
    def __init__(self):
        super().__init__()
        self.trunk = nn.Sequential(nn.LayerNorm(1024), nn.Linear(1024, 128), nn.SiLU(),
                                   nn.Linear(128, (HORIZON - 1) * WIDTH))
        self.head = nn.Linear(WIDTH, VOCAB)
        self.gate = nn.Linear(WIDTH, CODE)
        self.previous = nn.Embedding(VOCAB + 1, CODE)
        self.successor = nn.Embedding(VOCAB, CODE)
        self.register_buffer('vocabulary', torch.zeros(VOCAB, dtype=torch.long))

    def backbone(self, hidden):
        state = self.trunk(hidden).reshape(-1, HORIZON - 1, WIDTH)
        return self.head(state), torch.tanh(self.gate(state))

    def logits(self, base, gate, previous):
        code = self.previous(previous) * gate
        return base + (code @ self.successor.weight.T) / CODE**0.5

    def forward(self, hidden, trajectory):
        base, gate = self.backbone(hidden)
        return self.logits(base, gate, trajectory[:, :-1])


def fixture(split, lookup):
    raw = torch.load(split, weights_only=True, map_location='cpu')
    return raw['hidden'].float(), lookup[raw['future']], raw


def save_receipt(name, record):
    OUT.mkdir(parents=True, exist_ok=True)
    record['source_sha256'] = sha(__file__)
    (OUT / name).write_text(json.dumps(record, indent=2) + '\n')
    source = OUT / 'sources'
    source.mkdir(exist_ok=True)
    (source / (record['source_sha256'] + '.py')).write_bytes(Path(__file__).read_bytes())


def fit(args):
    OUT.mkdir(parents=True, exist_ok=True)
    source = torch.load(RESIDUAL / 'residual-v4096-s200.pt', weights_only=True, map_location='cpu')
    lookup = torch.full((151936,), VOCAB, dtype=torch.long)
    lookup[source['vocabulary']] = torch.arange(VOCAB)
    train_path = RESIDUAL / 'train-target.pt'
    val_path = DATA / 'validation-greedy.pt'
    x, y, _ = fixture(train_path, lookup)
    vx, vy, _ = fixture(val_path, lookup)
    torch.manual_seed(2026092314)
    model = Direct()
    model.vocabulary.copy_(source['vocabulary'])
    optimizer = torch.optim.AdamW(model.parameters(), lr=0.001, weight_decay=0.01)
    generator = torch.Generator().manual_seed(814)
    best = None
    curve = []
    for step in range(1, args.steps + 1):
        idx = torch.randint(len(x), (64,), generator=generator)
        logits = model(x[idx], y[idx])
        loss = F.cross_entropy(logits.flatten(0, 1), y[idx, 1:].flatten(), ignore_index=VOCAB)
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        optimizer.step()
        if step in (50, 100, 200, args.steps):
            model.eval()
            with torch.no_grad():
                vl = model(vx, vy)
                held = F.cross_entropy(vl.flatten(0, 1), vy[:, 1:].flatten(), ignore_index=VOCAB).item()
            curve.append({'step': step, 'train_batch_nll': loss.item(), 'validation_in_vocab_nll': held})
            if best is None or held < best[0]:
                best = (held, step, {key: value.detach().clone() for key, value in model.state_dict().items()})
            model.train()
    path = OUT / f'direct-s{args.steps}.pt'
    torch.save(best[2], path)
    record = {'steps': args.steps, 'selected_step_by_validation_nll': best[1], 'curve': curve,
              'train_rows': len(x), 'vocabulary_size': VOCAB,
              'vocabulary_source': 'unchanged residual-v4096-s200 checkpoint, chosen using training fixtures only',
              'learned_parameters': sum(p.numel() for p in model.parameters()),
              'frozen_target_head_values': 0, 'checkpoint_sha256': sha(path),
              'train_sha256': sha(train_path), 'validation_sha256': sha(val_path),
              'vocabulary_checkpoint_sha256': sha(RESIDUAL / 'residual-v4096-s200.pt')}
    save_receipt(path.stem + '.json', record)
    print(json.dumps(record), flush=True)


def evaluate(args):
    path = OUT / f'direct-s{args.steps}.pt'
    model = Direct()
    model.load_state_dict(torch.load(path, weights_only=True, map_location='cpu'))
    model.eval()
    lookup = torch.full((151936,), VOCAB, dtype=torch.long)
    lookup[model.vocabulary] = torch.arange(VOCAB)
    reference = json.loads((RESIDUAL / 'results-v4096-s200.json').read_text())
    result = {'checkpoint_sha256': sha(path), 'reference_receipt_sha256': sha(RESIDUAL / 'results-v4096-s200.json'),
              'budgets': BUDGETS, 'pool_width': 16, 'splits': {}}
    for split in ('validation-greedy', 'test-greedy'):
        fixture_path = DATA / f'{split}.pt'
        x, y, _ = fixture(fixture_path, lookup)
        assert sha(fixture_path) == reference['splits'][split]['fixture_sha256']
        rows = {arm: {str(b): [] for b in BUDGETS} for arm in ('direct_static', 'direct_adaptive')}
        misses = {'residual_oov': 0, 'static_pool': 0, 'adaptive_pool': 0}
        counted = {'static_correction_rows_scored': 0, 'adaptive_correction_rows_scored': 0}
        with torch.no_grad():
            for hidden, labels in zip(x, y):
                target = tuple(labels.tolist())
                misses['residual_oov'] += sum(t == VOCAB for t in target[1:])
                for adaptive, arm in ((False, 'direct_static'), (True, 'direct_adaptive')):
                    ordered, base, gate, scored = proposed(model, hidden, target[0], adaptive)
                    counted[('adaptive' if adaptive else 'static') + '_correction_rows_scored'] += scored
                    for budget in BUDGETS:
                        rows[arm][str(budget)].append(depth(ordered[:budget], target))
                    for pos in range(1, HORIZON):
                        previous = target[pos - 1]
                        logits = model.logits(base[pos - 1], gate[pos - 1], torch.tensor(previous))
                        pool = logits.topk(16).indices if adaptive else base[pos - 1].topk(16).indices
                        misses['adaptive_pool' if adaptive else 'static_pool'] += target[pos] not in pool
        result['splits'][split] = {
            'fixture_sha256': sha(fixture_path), 'rows': len(x), 'per_context_including_bonus': rows,
            'means_including_bonus': {arm: {budget: float(np.mean(values)) for budget, values in by_budget.items()}
                                      for arm, by_budget in rows.items()},
            'misses_all_five_residual_positions': misses, 'tree_correction_rows_scored': counted,
            'reference_means_including_bonus': {arm: reference['splits'][split]['means_including_bonus'][arm]
                                                 for arm in ('first_token_graft_s200', 'residual_static', 'residual_adaptive')},
        }
        print(split, result['splits'][split]['means_including_bonus'], misses, flush=True)
    result['accounting'] = {
        'known_anchor_nodes_per_tree': 1, 'new_draft_nodes_per_tree': [b - 1 for b in BUDGETS],
        'learned_parameters': sum(p.numel() for p in model.parameters()),
        'learned_parameter_fp32_bytes': sum(p.numel() for p in model.parameters()) * 4,
        'vocabulary_int64_bytes': VOCAB * 8, 'frozen_target_head_values': 0,
        'static_projection_scalar_products_per_context': (HORIZON - 1) * VOCAB * WIDTH,
        'static_head_fp32_bytes_if_streamed': VOCAB * WIDTH * 4,
        'conditioned_code_scalar_products_per_distinct_tree_row': VOCAB * CODE,
        'conditioned_log_softmax_and_topk': '4096 elements for every distinct position/predecessor row, same as the reference',
        'conditional_gate_scalar_products_per_context': (HORIZON - 1) * WIDTH * CODE,
        'known_root_and_bonus': 'retained target first token occupies one node; one target exit bonus counted',
        'verifier': 'not run; greedy prefix membership only, no tree attention or KV adoption',
    }
    save_receipt(f'results-s{args.steps}.json', result)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('fit', 'evaluate'))
    parser.add_argument('--steps', type=int, default=200)
    args = parser.parse_args()
    torch.set_num_threads(4)
    {'fit': fit, 'evaluate': evaluate}[args.action](args)


if __name__ == '__main__':
    main()
