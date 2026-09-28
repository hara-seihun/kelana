#!/usr/bin/env python3
"""Measure local probability mass rounding with one-key conservation repair."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
sys.path.insert(0, str(SUBBIT / 'value-observer'))
spec = importlib.util.spec_from_file_location('integer_consumer', SUBBIT / 'value-integer-consumer/measure.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
MODEL, CAPTURES = prior.MODEL, prior.CAPTURES
probabilities, load_capture, sha = prior.probabilities, prior.load_capture, prior.sha
integer_mass = prior.integer_mass
DATA = Path('/path/to/workspace/data/kelana-subbit/value-mass-local')


def local_mass(p, mass):
    # Separate key counts; only the total and the maximum-key index cross key lanes.
    local = torch.round(p.double() * mass).to(torch.int32)
    deficit = mass - local.sum(-1, keepdim=True, dtype=torch.int32)
    owner = p.argmax(-1, keepdim=True)
    available = local.gather(-1, owner)
    feasible = (deficit >= 0) | (available >= -deficit)
    fixed = local.scatter_add(-1, owner, deficit)
    return fixed, feasible, deficit


def panel(p, mass):
    baseline = integer_mass(p, mass)
    candidate, feasible, deficit = local_mass(p, mass)
    length = p.shape[-1]
    causal = torch.ones((length, length), dtype=torch.bool).tril()
    active = causal.expand_as(p)
    rows = p.shape[0] * p.shape[1] * length
    assert bool(torch.all(p[~active] == 0))
    assert bool(torch.all(baseline.sum(-1) == mass))
    raw = torch.round(p.double() * mass).to(torch.int32)
    raw_nonnegative = bool(torch.all(raw >= 0))
    feasible_count = int(feasible.sum())
    d = (candidate - baseline).abs()
    # Finite input-independent code bound for each signed-nibble value coordinate:
    # |sum (candidate-baseline)*c| <= 7*||candidate-baseline||_1.
    l1 = d.sum(-1)
    out = {
        'rows': rows, 'feasible_rows': feasible_count,
        'max_abs_deficit': int(deficit.abs().max()),
        'deficit_nonzero_rows': int((deficit != 0).sum()),
        'max_l1_count_difference': int(l1.max()),
        'mean_l1_count_difference': float(l1.double().mean()),
        'p99_l1_count_difference': float(torch.quantile(l1.float().reshape(-1), .99)),
        'mean_l1_probability_difference': float(l1.double().mean() / mass),
        'max_integer_coordinate_error_bound': int(7 * l1.max()),
        'equal_count_rows': int((l1 == 0).sum()),
        'high_128_pairs_local': int(((candidate >= 128) & active).sum()) if feasible_count == rows else None,
        'high_128_pairs_prefix': int(((baseline >= 128) & active).sum()),
        'raw_nonnegative': raw_nonnegative,
        'candidate_nonnegative': bool(torch.all(candidate >= 0)),
        'candidate_sum_conserved': bool(torch.all(candidate.sum(-1) == mass)),
        'zero_probability_stays_zero_except_owner': bool(torch.all(candidate[(p == 0) & active] == 0)),
    }
    # Value-code replay uses frozen paid V/O factors and previously fitted signed-nibble cache.
    return out, candidate, baseline


def response_panel(layer, x, p, model):
    factor = DATA.parent / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    metadata = json.loads((DATA.parent / 'value-centered-int4' / f'layer{layer:02d}-8x4.json').read_text())
    assert sha(factor) == metadata['image_sha256']
    spec = importlib.util.spec_from_file_location('factor_decoder', prior.SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    teacher = prior.dense_attention(p, x, model.get_tensor(f'model.layers.{layer}.self_attn.v_proj.weight').float(),
                                    model.get_tensor(f'model.layers.{layer}.self_attn.o_proj.weight').float())
    output = {f'{arm}_{mass}': torch.zeros_like(teacher) for arm in ('prefix', 'local') for mass in (127, 4095)}
    count_pairs = {}
    for mass in (127, 4095):
        candidate, feasible, _ = local_mass(p, mass)
        assert bool(feasible.all()), 'one-owner correction is not valid on this capture'
        count_pairs[mass] = (integer_mass(p, mass), candidate)
    with np.load(factor) as image:
        for g in range(8):
            factors = {key: image[key][g].copy() for key in image.files}
            left = decoder.decode(factors, 'left')
            right = decoder.decode(factors, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            entry = metadata['metadata'][g]['int4_coordinate']
            center, step = torch.tensor(entry['center']), torch.tensor(entry['step'])
            code = ((z - center) / step).round().clamp(-7, 7).float()
            for head in range(2):
                index = 2*g + head
                l = left[head*1024:(head+1)*1024]
                for mass, (reference, candidate) in count_pairs.items():
                    for arm, n in (('prefix', reference), ('local', candidate)):
                        attention = (n[:, index].float() @ code) * (step / mass) + center
                        output[f'{arm}_{mass}'] += attention @ l.T
    return {
        str(mass): {
            'prefix_relative_teacher_error': prior.relative(output[f'prefix_{mass}'], teacher),
            'local_relative_teacher_error': prior.relative(output[f'local_{mass}'], teacher),
            'local_relative_prefix_error': prior.relative(output[f'local_{mass}'], output[f'prefix_{mass}']),
            'per_window_teacher_error': [
                [prior.relative(output[f'{arm}_{mass}'][i], teacher[i]) for i in range(4)]
                for arm in ('prefix', 'local')],
        } for mass in (127, 4095)
    }


def run(layer):
    torch.set_num_threads(8)
    # A probability row with 200 nearly-half counts and 56 larger counts
    # defeats single-owner subtraction. The empirical fast path is not universal.
    adversary = torch.tensor([15.51] * 200 + [(4095 - 200 * 15.51) / 56] * 56,
                             dtype=torch.float64).reshape(1, 1, 1, 256) / 4095
    _, feasible, deficit = local_mass(adversary, 4095)
    assert not bool(feasible.all()) and int(deficit.item()) == -113

    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {key: model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
             for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    result = {}
    with safe_open(MODEL, framework='pt', device='cpu') as model:
      for split in ('train', 'validation'):
          x = load_capture(layer, split).reshape(-1, 256, 1024)[:8 if split == 'train' else 4]
          p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
          result[split] = {}
          for mass in (127, 4095):
              stats, _, _ = panel(p, mass)
              result[split][str(mass)] = stats
          if split == 'validation':
              result['validation_response'] = response_panel(layer, x, p, model)
          print(layer, split, {m: (v['feasible_rows'], v['rows'], v['mean_l1_probability_difference']) for m, v in result[split].items()}, flush=True)
    receipt = {
        'layer': layer, 'source_sha256': sha(HERE),
        'parent_source_sha256': sha(SUBBIT / 'value-integer-consumer/measure.py'),
        'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
        'factor_sha256': sha(DATA.parent / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'),
        'nibble_fit_receipt_sha256': sha(DATA.parent / 'value-centered-int4' / f'layer{layer:02d}-8x4.json'),
        'domain': 'frozen original-producer Q/K; 8 train and 4 previously inspected validation 256-token windows, 16 heads; CPU FP64 mass product with Torch nearest-even rounding',
        'results': result,
        'cost_contract': 'one parallel rounding per key, sum and argmax reductions, owner scatter and feasibility check; probability softmax and nibble dot unchanged; no native time, scan-vs-reduction latency unpaid',
    }
    DATA.mkdir(parents=True, exist_ok=True)
    target = DATA / f'layer{layer:02d}.json'
    target.write_text(json.dumps(receipt, indent=2) + '\n')
    print(target, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
