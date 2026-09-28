#!/usr/bin/env python3
"""Train a prefix-focused direct ID producer and select it by validation tree coverage."""
import argparse
import hashlib
import heapq
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('direct_producer', HERE.parent / 'direct-producer' / 'experiment.py')
direct = importlib.util.module_from_spec(spec)
spec.loader.exec_module(direct)
DATA, VOCAB, Direct = direct.DATA, direct.VOCAB, direct.Direct


class RootConditioned(Direct):
    """Use the retained target decision to adjust all five position states."""
    def __init__(self):
        super().__init__()
        self.root_projection = nn.Linear(direct.CODE, (direct.HORIZON - 1) * direct.WIDTH, bias=False)
        nn.init.zeros_(self.root_projection.weight)

    def backbone_with_root(self, hidden, root_id):
        state = self.trunk(hidden).reshape(-1, direct.HORIZON - 1, direct.WIDTH)
        root_code = self.previous(root_id)
        root_adjustment = self.root_projection(root_code).reshape(-1, direct.HORIZON - 1, direct.WIDTH)
        state = state + root_adjustment
        return self.head(state), torch.tanh(self.gate(state))

    def forward(self, hidden, trajectory):
        base, gate = self.backbone_with_root(hidden, trajectory[:, 0])
        return self.logits(base, gate, trajectory[:, :-1])
OUT = DATA / 'prefix-producer'
WEIGHTS = {'front': (6., 3., 1., .5, .25), 'gentle': (3., 2., 1., 1., 1.)}
STEPS = (20, 40, 80)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(model_path):
    state = torch.load(model_path, weights_only=True, map_location='cpu')
    model = RootConditioned() if 'root_projection.weight' in state else Direct()
    model.load_state_dict(state)
    model.eval()
    return model


def split(path, vocabulary):
    lookup = torch.full((151936,), VOCAB, dtype=torch.long)
    lookup[vocabulary] = torch.arange(VOCAB)
    return direct.fixture(path, lookup)[:2]


def fit(args):
    OUT.mkdir(parents=True, exist_ok=True)
    seed = DATA / 'direct-producer/direct-s200.pt'
    model = load(seed)
    x, y = split(DATA / 'residual-drafter/train-target.pt', model.vocabulary)
    torch.manual_seed(2026092321)
    generator = torch.Generator().manual_seed(821)
    weights = torch.tensor(WEIGHTS[args.objective])
    optimizer = torch.optim.AdamW(model.parameters(), lr=3e-4, weight_decay=.01)
    for step in range(1, args.steps + 1):
        indices = torch.randint(len(x), (64,), generator=generator)
        logits = model(x[indices], y[indices])
        losses = F.cross_entropy(logits.flatten(0, 1), y[indices, 1:].flatten(), ignore_index=VOCAB,
                                 reduction='none').reshape(-1, 5)
        mask = (y[indices, 1:] != VOCAB).float()
        loss = (losses * weights).sum() / (mask * weights).sum()
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        optimizer.step()
        if step in STEPS:
            torch.save(model.state_dict(), OUT / f'{args.objective}-s{step}.pt')
            print(args.objective, step, loss.detach().item(), flush=True)


def proposed(model, hidden, root, depth_reward=0.):
    """Static top-16 pools, ordered by conditional log probability plus depth reward."""
    with torch.no_grad():
        base, gate = (model.backbone_with_root(hidden[None], torch.tensor([root]))
                      if isinstance(model, RootConditioned) else model.backbone(hidden[None]))
        base, gate = base[0], gate[0]
        pools = base.topk(16, dim=-1).indices
        tree = [(root,)]
        heap = []
        cache = {}

        def children(prefix):
            pos = len(prefix) - 1
            previous = prefix[-1]
            key = (pos, previous)
            if key not in cache:
                logits = model.logits(base[pos], gate[pos], torch.tensor(previous))
                logp = logits.log_softmax(-1)
                cache[key] = [(int(tok), float(logp[tok])) for tok in pools[pos]]
            return cache[key]

        for token, score in children((root,)):
            heapq.heappush(heap, (-score - depth_reward, (root, token)))
        while heap and len(tree) < 18:
            cost, prefix = heapq.heappop(heap)
            tree.append(prefix)
            if len(prefix) < direct.HORIZON:
                for token, score in children(prefix):
                    heapq.heappush(heap, (cost - score - depth_reward, prefix + (token,)))
        return tree


def coverage(model, x, y, depth_reward=0.):
    rows = {str(b): [] for b in (6, 18)}
    with torch.no_grad():
        for hidden, target_tensor in zip(x, y):
            target = tuple(target_tensor.tolist())
            ordered = proposed(model, hidden, target[0], depth_reward)
            for budget in (6, 18):
                rows[str(budget)].append(direct.depth(ordered[:budget], target))
    return rows


def fit_root(args):
    OUT.mkdir(parents=True, exist_ok=True)
    seed = DATA / 'direct-producer/direct-s200.pt'
    model = RootConditioned()
    model.load_state_dict(torch.load(seed, weights_only=True, map_location='cpu'), strict=False)
    x, y = split(DATA / 'residual-drafter/train-target.pt', model.vocabulary)
    torch.manual_seed(2026092322)
    generator = torch.Generator().manual_seed(822)
    optimizer = torch.optim.AdamW(model.parameters(), lr=3e-4, weight_decay=.01)
    for step in range(1, args.steps + 1):
        indices = torch.randint(len(x), (64,), generator=generator)
        logits = model(x[indices], y[indices])
        loss = F.cross_entropy(logits.flatten(0, 1), y[indices, 1:].flatten(), ignore_index=VOCAB)
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        optimizer.step()
        if step in (20, 40, 80, 120, args.steps):
            torch.save(model.state_dict(), OUT / f'root-s{step}.pt')
            print('root', step, loss.detach().item(), flush=True)


def evaluate_root(args):
    reference = json.loads((DATA / 'direct-producer/results-s200.json').read_text())
    seed = DATA / 'direct-producer/direct-s200.pt'
    baseline = load(seed)
    val_path, test_path = DATA / 'validation-greedy.pt', DATA / 'test-greedy.pt'
    x, y = split(val_path, baseline.vocabulary)
    assert sha(val_path) == reference['splits']['validation-greedy']['fixture_sha256']
    candidates = []
    for step, path in [(0, seed)] + [(step, OUT / f'root-s{step}.pt') for step in (20, 40, 80, 120)]:
        model = load(path)
        rows = coverage(model, x, y)
        means = {budget: float(np.mean(values)) for budget, values in rows.items()}
        candidates.append({'step': step, 'checkpoint': str(path), 'checkpoint_sha256': sha(path),
                           'validation_means_including_bonus': means,
                           'validation_per_context_including_bonus': rows})
        print(step, means, flush=True)
    selected = max(candidates, key=lambda row: (sum(row['validation_means_including_bonus'].values()),
                                                 row['validation_means_including_bonus']['6'], -row['step']))
    model = load(selected['checkpoint'])
    tx, ty = split(test_path, model.vocabulary)
    test_rows = coverage(model, tx, ty)
    result = {'selection': 'maximum validation 6-plus-18-node means, tie by 6-node mean then fewer updates; test read only after selection',
              'selected': selected, 'candidates': candidates,
              'test': {b: {'mean_including_bonus': float(np.mean(v)), 'per_context_including_bonus': v}
                       for b, v in test_rows.items()},
              'original_test': {b: reference['splits']['test-greedy']['per_context_including_bonus']['direct_static'][b]
                                for b in ('6', '18')},
              'train_sha256': sha(DATA / 'residual-drafter/train-target.pt'),
              'validation_sha256': sha(val_path), 'test_sha256': sha(test_path),
              'source_sha256': sha(__file__), 'learned_parameters': sum(p.numel() for p in model.parameters()),
              'frozen_target_head_values': 0,
              'inference': 'one 16-by-320 root projection per context, in addition to the direct base and code projections; unchanged top-16 pools and heap'}
    (OUT / 'root-results.json').write_text(json.dumps(result, indent=2) + '\n')
    sources = OUT / 'sources'
    sources.mkdir(exist_ok=True)
    (sources / (result['source_sha256'] + '.py')).write_bytes(Path(__file__).read_bytes())
    print('SELECTED', selected['step'], 'TEST', {b: float(np.mean(v)) for b, v in test_rows.items()}, flush=True)


def evaluate(args):
    reference = json.loads((DATA / 'direct-producer/results-s200.json').read_text())
    seed = DATA / 'direct-producer/direct-s200.pt'
    baseline = load(seed)
    source = DATA / 'residual-drafter/residual-v4096-s200.pt'
    validation = DATA / 'validation-greedy.pt'
    test = DATA / 'test-greedy.pt'
    x, y = split(validation, baseline.vocabulary)
    assert sha(validation) == reference['splits']['validation-greedy']['fixture_sha256']
    original = reference['splits']['validation-greedy']['per_context_including_bonus']['direct_static']
    candidates = []
    for objective, step, path in [('baseline', 0, seed)] + [
            (objective, step, OUT / f'{objective}-s{step}.pt')
            for objective in WEIGHTS for step in STEPS]:
        model = load(path)
        for reward in (0., 1., 2., 3., 4., 5.):
            rows = coverage(model, x, y, reward)
            means = {budget: float(np.mean(values)) for budget, values in rows.items()}
            candidates.append({'objective': objective, 'step': step, 'path': str(path),
                               'depth_reward': reward, 'validation_means_including_bonus': means,
                               'validation_per_context_including_bonus': rows,
                               'checkpoint_sha256': sha(path)})
            print(path.name, reward, means, flush=True)
    chosen = max(candidates, key=lambda c: (sum(c['validation_means_including_bonus'].values()),
                                            c['validation_means_including_bonus']['6'],
                                            -c['depth_reward'], -c['step']))
    model = load(chosen['path'])
    tx, ty = split(test, model.vocabulary)
    test_rows = coverage(model, tx, ty, chosen['depth_reward'])
    receipt = {'selection': 'maximum validation mean at 6 plus 18 nodes; ties by 6 nodes, less depth reward, then fewer updates; test untouched until selection',
               'selected': chosen, 'candidates': candidates,
               'baseline': {'checkpoint_sha256': sha(seed), 'validation': {b: original[b] for b in ('6', '18')},
                            'test': {b: reference['splits']['test-greedy']['per_context_including_bonus']['direct_static'][b] for b in ('6', '18')}},
               'test': {b: {'mean_including_bonus': float(np.mean(values)), 'per_context_including_bonus': values}
                        for b, values in test_rows.items()},
               'training_source_sha256': sha(DATA / 'residual-drafter/train-target.pt'),
               'validation_fixture_sha256': sha(validation), 'test_fixture_sha256': sha(test),
               'vocabulary_source_sha256': sha(source), 'source_sha256': sha(__file__),
               'storage': {'learned_parameters': sum(p.numel() for p in model.parameters()),
                           'fp32_parameter_bytes': sum(p.numel() for p in model.parameters()) * 4,
                           'vocabulary_int64_bytes': VOCAB * 8,
                           'frozen_target_head_values': 0},
               'compute': 'same five 64x4096 static projections and 16-wide tree pool as direct-s200; depth reward adds one scalar per heap edge'}
    (OUT / 'results.json').write_text(json.dumps(receipt, indent=2) + '\n')
    sources = OUT / 'sources'
    sources.mkdir(exist_ok=True)
    (sources / (receipt['source_sha256'] + '.py')).write_bytes(Path(__file__).read_bytes())
    print('SELECTED', chosen['path'], 'TEST', {b: float(np.mean(v)) for b, v in test_rows.items()}, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('fit', 'evaluate', 'fit-root', 'evaluate-root'))
    parser.add_argument('--objective', choices=WEIGHTS, default='front')
    parser.add_argument('--steps', type=int, default=80)
    args = parser.parse_args()
    torch.set_num_threads(4)
    {'fit': fit, 'evaluate': evaluate, 'fit-root': fit_root, 'evaluate-root': evaluate_root}[args.action](args)


if __name__ == '__main__':
    main()
