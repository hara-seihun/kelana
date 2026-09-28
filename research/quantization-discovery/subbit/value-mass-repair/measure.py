#!/usr/bin/env python3
"""Always-valid no-scan conservation for the frozen narrow-value integer consumer."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'value-observer'))
spec = importlib.util.spec_from_file_location('local_mass', ROOT / 'value-mass-local/measure.py')
local = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local)
prior = local.prior
DATA = Path('/path/to/workspace/data/kelana-subbit/value-mass-repair')


def safe_mass(p, mass):
    rounded = torch.round(p.double() * mass).to(torch.int32)
    owner = p.argmax(-1, keepdim=True)
    deficit = mass - rounded.sum(-1, keepdim=True, dtype=torch.int32)
    owner_count = rounded.gather(-1, owner)
    # This is the native fast arm's condition, and never changes its observation.
    good = deficit >= -owner_count
    floors = torch.floor(p.double() * mass).to(torch.int32)
    floor_deficit = mass - floors.sum(-1, keepdim=True, dtype=torch.int32)
    # Exact integer normalization makes the invalid-row repair valid even when
    # the input probabilities do not sum to one in floating-point arithmetic.
    total = rounded.sum(-1, keepdim=True, dtype=torch.int64)
    scaled = ((rounded.to(torch.int64) * mass) // total.clamp_min(1)).to(torch.int32)
    scaled_deficit = mass - scaled.sum(-1, keepdim=True, dtype=torch.int32)
    chosen = torch.where(good, rounded, scaled)
    correction = torch.where(good, deficit, scaled_deficit)
    return chosen.scatter_add(-1, owner, correction), good, deficit, floors.scatter_add(-1, owner, floor_deficit)


def stats(candidate, reference, active, mass):
    delta = (candidate - reference).abs().sum(-1)
    return {'mean_count_l1_over_mass': float(delta.double().mean() / mass),
            'max_count_l1': int(delta.max()),
            'equal_rows': int((delta == 0).sum()),
            'high_128_pairs': int(((candidate >= 128) & active).sum())}


def run(layer):
    torch.set_num_threads(8)
    model_path = prior.MODEL
    cap_path = prior.CAPTURES / f'layer{layer:02d}.npz'
    with safe_open(model_path, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm', 'v_proj', 'o_proj')}
    x = prior.load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    p = prior.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
    baseline = prior.integer_mass(p, 4095)
    safe, good, deficit, floor = safe_mass(p, 4095)
    assert bool(good.all()) and bool((safe >= 0).all()) and bool((safe.sum(-1) == 4095).all())
    assert bool((floor >= 0).all()) and bool((floor.sum(-1) == 4095).all())
    assert bool((safe[p == 0] == 0).all()) and bool((floor[p == 0] == 0).all())
    active = torch.ones((256, 256), dtype=torch.bool).tril().expand_as(p)
    counts = {'prefix': baseline, 'local_safe': safe, 'floor_owner': floor}
    teacher = prior.dense_attention(p, x, w['v_proj'], w['o_proj'])
    factor = DATA.parent / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    cache_receipt = DATA.parent / 'value-centered-int4' / f'layer{layer:02d}-8x4.json'
    metadata = json.loads(cache_receipt.read_text())
    assert prior.sha(factor) == metadata['image_sha256']
    decoder_spec = importlib.util.spec_from_file_location('factor_decoder', prior.SOURCE)
    decoder = importlib.util.module_from_spec(decoder_spec)
    decoder_spec.loader.exec_module(decoder)
    outputs = {arm: torch.zeros_like(teacher) for arm in counts}
    with np.load(factor) as image:
        for g in range(8):
            factors = {key: image[key][g].copy() for key in image.files}
            left = decoder.decode(factors, 'left')
            right = decoder.decode(factors, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            entry = metadata['metadata'][g]['int4_coordinate']
            center, step = torch.tensor(entry['center']), torch.tensor(entry['step'])
            codes = ((z - center) / step).round().clamp(-7, 7).float()
            for head in range(2):
                idx = 2 * g + head
                l = left[head * 1024:(head + 1) * 1024]
                for arm, n in counts.items():
                    outputs[arm] += ((n[:, idx].float() @ codes) * (step / 4095) + center) @ l.T
    # Invalid uniform-looking rows are part of the domain, not a claim about the model.
    adversary = torch.tensor([15.51] * 200 + [(4095 - 200 * 15.51) / 56] * 56,
                             dtype=torch.float64).reshape(1, 1, 1, 256) / 4095
    repaired, feasible, bad_deficit, fallback = safe_mass(adversary, 4095)
    assert not bool(feasible.all()) and int(bad_deficit.item()) == -113
    assert int(repaired.min()) >= 0 and int(repaired.sum()) == 4095
    assert int(fallback.min()) >= 0 and int(fallback.sum()) == 4095
    result = {
        'layer': layer, 'source_sha256': prior.sha(HERE),
        'parent_source_sha256': prior.sha(ROOT / 'value-mass-local/measure.py'),
        'parent_receipt_sha256': prior.sha(DATA.parent / 'value-mass-local' / f'layer{layer:02d}.json'),
        'model_sha256': prior.sha(model_path), 'capture_sha256': prior.sha(cap_path),
        'factor_sha256': prior.sha(factor), 'cache_fit_sha256': prior.sha(cache_receipt),
        'domain': 'four repeatedly inspected 256-token validation windows; original-producer Q/K; frozen paid rank-28 nibble V/O; FP64 nearest-even and floor count construction on CPU',
        'rows': int(good.numel()), 'fast_rows': int(good.sum()),
        'max_negative_deficit': max(0, int(-deficit.min())),
        'adversary': {'length': 256, 'nearest_deficit': -113,
                      'scaled_repair_l1_vs_prefix': int((repaired - prior.integer_mass(adversary, 4095)).abs().sum()),
                      'floor_owner_l1_vs_prefix': int((fallback - prior.integer_mass(adversary, 4095)).abs().sum())},
        'counts': {arm: stats(n, baseline, active, 4095) for arm, n in counts.items()},
        'post_o_relative_teacher_error': {arm: prior.relative(out, teacher) for arm, out in outputs.items()},
        'per_window_post_o_relative_teacher_error': {
            arm: [prior.relative(out[i], teacher[i]) for i in range(4)] for arm, out in outputs.items()},
        'cost_contract': 'fast path: independent nearest, count sum and owner max, scatter; invalid path: exact integer per-key proportional normalization, another sum and scatter; unconditional floor arm: floor, sum and owner scatter. Softmax and radix-128 nibble dots are otherwise identical. Native scheduling/latency unmeasured.',
    }
    DATA.mkdir(parents=True, exist_ok=True)
    target = DATA / f'layer{layer:02d}.json'
    target.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'receipt': str(target), 'rows': result['rows'], 'fast_rows': result['fast_rows'],
                      'counts': result['counts'], 'error': result['post_o_relative_teacher_error']}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
