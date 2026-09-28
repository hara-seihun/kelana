#!/usr/bin/env python3
"""Count probability-only candidates for exact radix-128 high-digit V attention."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
sys.path.insert(0, str(SUBBIT / 'value-observer'))
spec = importlib.util.spec_from_file_location('mass_residual', SUBBIT / 'value-mass-residual/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
MODEL, CAPTURES = parent.MODEL, parent.CAPTURES
load_capture, probabilities, counts, sha = parent.load_capture, parent.probabilities, parent.counts, parent.sha

DATA = Path('/path/to/workspace/data/kelana-subbit/value-high-prefilter')
MASS = 4095
RADIX = 128


def panel(p):
    n = counts(p)
    active = torch.ones((p.shape[-1], p.shape[-1]), dtype=torch.bool).tril()
    x = p.double() * MASS
    candidate = (x >= RADIX - 1) & active
    guarded = (x >= RADIX - 2) & active
    high = (n >= RADIX) & active
    assert not bool((high & ~candidate).any())
    assert not bool((high & ~guarded).any())
    definite = (x > RADIX + 1) & active
    assert not bool((definite & ~high).any())
    possible = candidate.sum(-1).int()
    actual = high.sum(-1).int()
    pairs = p.shape[0] * p.shape[1] * p.shape[2] * (p.shape[2] + 1) // 2
    return {
        'rows': int(possible.numel()), 'causal_pairs': pairs,
        'high_pairs': int(high.sum()), 'candidate_pairs': int(candidate.sum()),
        'false_positive_pairs': int((candidate & ~high).sum()),
        'guarded_candidate_pairs': int(guarded.sum()),
        'max_probability_sum_error': float((p.double().sum(-1) - 1).abs().max()),
        'definite_high_pairs': int(definite.sum()),
        'candidate_fraction': float(candidate.sum() / pairs),
        'max_candidates_per_row': int(possible.max()),
        'max_high_per_row': int(actual.max()),
        'nonempty_candidate_rows': int((possible > 0).sum()),
        'nonempty_high_rows': int((actual > 0).sum()),
        'rounded_candidate_pairs': {str(width): int(((possible + width - 1) // width * width).sum()) for width in (4, 8, 16, 32)},
        'rounded_high_pairs': {str(width): int(((actual + width - 1) // width * width).sum()) for width in (4, 8, 16, 32)},
        'pre_scan_false_positive_bound': 'real-normalized row: candidate iff 4095*p >= 127; conservative measured-float guard 4095*p >= 126',
    }


def run(layer):
    torch.set_num_threads(8)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    result = {}
    for split in ('train', 'validation'):
        x = load_capture(layer, split).reshape(-1, 256, 1024)[:8 if split == 'train' else 4]
        result[split] = panel(probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm']))
        print(layer, split, result[split]['high_pairs'], result[split]['candidate_pairs'], flush=True)
    receipt = {
        'layer': layer, 'source_sha256': sha(HERE),
        'parent_source_sha256': sha(SUBBIT / 'value-mass-residual/measure.py'),
        'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
        'domain': 'frozen original-producer Q/K; 8 train and 4 previously inspected validation 256-token windows; 16 heads; 4095-unit prefix-rounded mass',
        'cost_contract': 'probability-only threshold and ballot before prefix; exact prefix retained for candidate high digits and all low digits; no native prep/compaction/gather/timing claim',
        'results': result,
    }
    DATA.mkdir(parents=True, exist_ok=True)
    target = DATA / f'layer{layer:02d}.json'
    target.write_text(json.dumps(receipt, indent=2) + '\n')
    print(target, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
