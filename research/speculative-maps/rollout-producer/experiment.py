#!/usr/bin/env python3
"""Fine-tune the unchanged direct ID producer on target-generated rollout states."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from torch.nn import functional as F

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('direct_producer', HERE.parent / 'direct-producer' / 'experiment.py')
direct = importlib.util.module_from_spec(spec)
spec.loader.exec_module(direct)
DATA, OUT, VOCAB = direct.DATA, direct.DATA / 'rollout-producer', direct.VOCAB
STEPS = (20, 40, 80, 160)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def model_from(path):
    model = direct.Direct()
    model.load_state_dict(torch.load(path, weights_only=True, map_location='cpu'))
    model.eval()
    return model


def fixture(path, vocabulary):
    lookup = torch.full((151936,), VOCAB, dtype=torch.long)
    lookup[vocabulary] = torch.arange(VOCAB)
    return direct.fixture(path, lookup)[:2]


def coverage(model, x, y):
    rows = {str(b): [] for b in (6, 18)}
    with torch.no_grad():
        for hidden, labels in zip(x, y):
            target = tuple(labels.tolist())
            ordered, _, _, _ = direct.proposed(model, hidden, target[0], adaptive=False)
            for budget in (6, 18):
                rows[str(budget)].append(direct.depth(ordered[:budget], target))
    return rows


def fit(args):
    OUT.mkdir(parents=True, exist_ok=True)
    seed = DATA / 'direct-producer/direct-s200.pt'
    model = model_from(seed)
    original_path = DATA / 'residual-drafter/train-target.pt'
    rollout_path = OUT / 'train.pt'
    ox, oy = fixture(original_path, model.vocabulary)
    rx, ry = fixture(rollout_path, model.vocabulary)
    torch.manual_seed(2026092323)
    generator = torch.Generator().manual_seed(823)
    optimizer = torch.optim.AdamW(model.parameters(), lr=3e-4, weight_decay=.01)
    for step in range(1, args.steps + 1):
        oi = torch.randint(len(ox), (32,), generator=generator)
        ri = torch.randint(len(rx), (32,), generator=generator)
        x, y = torch.cat([ox[oi], rx[ri]]), torch.cat([oy[oi], ry[ri]])
        logits = model(x, y)
        loss = F.cross_entropy(logits.flatten(0, 1), y[:, 1:].flatten(), ignore_index=VOCAB)
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        optimizer.step()
        if step in STEPS:
            path = OUT / f'direct-mixed-s{step}.pt'
            torch.save(model.state_dict(), path)
            print(step, loss.detach().item(), flush=True)


def evaluate(args):
    reference = json.loads((DATA / 'direct-producer/results-s200.json').read_text())
    seed = DATA / 'direct-producer/direct-s200.pt'
    baseline = model_from(seed)
    val_path, test_path = DATA / 'validation-greedy.pt', DATA / 'test-greedy.pt'
    x, y = fixture(val_path, baseline.vocabulary)
    assert sha(val_path) == reference['splits']['validation-greedy']['fixture_sha256']
    choices = []
    for step, path in [(0, seed)] + [(step, OUT / f'direct-mixed-s{step}.pt') for step in STEPS]:
        model = model_from(path)
        rows = coverage(model, x, y)
        means = {b: float(np.mean(values)) for b, values in rows.items()}
        choices.append({'step': step, 'checkpoint': str(path), 'checkpoint_sha256': sha(path),
                        'validation_means_including_bonus': means,
                        'validation_per_context_including_bonus': rows})
        print(step, means, flush=True)
    selected = max(choices, key=lambda c: (sum(c['validation_means_including_bonus'].values()),
                                           c['validation_means_including_bonus']['6'], -c['step']))
    model = model_from(selected['checkpoint'])
    tx, ty = fixture(test_path, model.vocabulary)
    test_rows = coverage(model, tx, ty)
    train_path, original_path = OUT / 'train.pt', DATA / 'residual-drafter/train-target.pt'
    receipt = {'selection': 'maximum validation 6-plus-18-node static prefix mean, ties by 6-node mean then fewer updates; test read only after selection',
               'selected': selected, 'candidates': choices,
               'test': {b: {'mean_including_bonus': float(np.mean(v)), 'per_context_including_bonus': v}
                        for b, v in test_rows.items()},
               'baseline_test': {b: reference['splits']['test-greedy']['per_context_including_bonus']['direct_static'][b]
                                 for b in ('6', '18')},
               'rollout_train_sha256': sha(train_path), 'original_train_sha256': sha(original_path),
               'validation_fixture_sha256': sha(val_path), 'test_fixture_sha256': sha(test_path),
               'capture_receipt_sha256': sha(OUT / 'train.json'), 'source_sha256': sha(__file__),
               'training_mix': '32 replacement-sampled rows each from rollout and original target-generated training fixtures per 64-row batch',
               'vocabulary_source': 'unchanged direct-s200 vocabulary from residual-v4096-s200 selected on previous training fixtures',
               'model': 'unchanged Direct class and tree builder; 572896 learned FP32 parameters, no frozen target output head',
               'verifier': 'not run; static greedy prefix membership only'}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'results.json').write_text(json.dumps(receipt, indent=2) + '\n')
    source = OUT / 'sources'
    source.mkdir(exist_ok=True)
    (source / (receipt['source_sha256'] + '.py')).write_bytes(Path(__file__).read_bytes())
    print('SELECTED', selected['step'], 'TEST', {b: float(np.mean(v)) for b, v in test_rows.items()}, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('fit', 'evaluate'))
    parser.add_argument('--steps', type=int, default=160)
    args = parser.parse_args()
    torch.set_num_threads(4)
    {'fit': fit, 'evaluate': evaluate}[args.action](args)


if __name__ == '__main__':
    main()
