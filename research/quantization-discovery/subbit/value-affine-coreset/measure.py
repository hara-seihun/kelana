#!/usr/bin/env python3
"""Sparse exact real convex representatives of frozen narrow-value attention rows."""
import argparse
import hashlib
import importlib.util
import json
import sys
import time
from pathlib import Path

import numpy as np
from scipy.optimize import linprog
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
sys.path.insert(0, str(SUBBIT / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def counts(prob, mass):
    prefix = (np.cumsum(prob, dtype=np.float64) * mass).round().clip(0, mass)
    prefix[-1] = mass
    result = np.diff(prefix, prepend=0).astype(np.int32)
    assert result.min() >= 0 and result.sum() == mass
    return result


def run(layer, positions):
    torch.set_num_threads(4)
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:1]
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        weights = [model.get_tensor(f'model.layers.{layer}.self_attn.{key}.weight').float()
                   for key in ('q_proj', 'k_proj', 'q_norm', 'k_norm')]
    prob = probabilities(x, *weights)[0].numpy()
    image = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    meta_path = DATA / 'value-centered-int4' / f'layer{layer:02d}-8x4.json'
    metadata = json.loads(meta_path.read_text())
    assert sha(image) == metadata['image_sha256']
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    samples = []
    with np.load(image) as factors:
        for group in range(8):
            arrays = {key: factors[key][group].copy() for key in factors.files}
            right = decoder.decode(arrays, 'right')
            value = (x[0] @ right.T).to(torch.bfloat16).float().numpy()
            step = np.asarray(metadata['metadata'][group]['int4_coordinate']['step'], dtype=np.float64)
            code = np.rint(value / step).clip(-7, 7).astype(np.int8)
            for local in range(2):
                head = 2*group + local
                for position in positions:
                    n = counts(prob[head, position, :position+1], 4095)
                    c = code[:position+1].astype(np.float64)
                    active = np.flatnonzero(n)
                    target = n @ c / 4095
                    matrix = np.vstack((np.ones(len(active)), c[active].T))
                    rhs = np.r_[1., target]
                    start = time.perf_counter()
                    solution = linprog(np.zeros(len(active)), A_eq=matrix, b_eq=rhs,
                                       bounds=(0, None), method='highs')
                    elapsed = time.perf_counter() - start
                    if not solution.success:
                        raise RuntimeError(f'LP failed at layer={layer}, head={head}, position={position}: {solution.message}')
                    selected = solution.x > 1e-8
                    fitted = solution.x @ c[active]
                    n15 = counts(prob[head, position, :position+1], 15)
                    approximate = n15 @ c / 15
                    samples.append({'head': head, 'position': position, 'input_active': len(active),
                                    'affine_rank': int(np.linalg.matrix_rank(matrix)),
                                    'support': int(selected.sum()), 'moment_max_error': float(np.max(np.abs(fitted-target))),
                                    'one_digit_support': int(np.count_nonzero(n15)),
                                    'one_digit_moment_error_l2': float(np.linalg.norm(approximate-target)),
                                    'lp_cpu_seconds': elapsed})
    output = {'layer': layer, 'positions': positions, 'samples': samples,
              'image_sha256': sha(image), 'metadata_sha256': sha(meta_path),
              'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
              'model_sha256': sha(MODEL), 'source_sha256': sha(HERE),
              'contract': 'First previously inspected validation window, original Q/K producer, paid rank-28 V/O signed-nibble codes; 4095-unit integer mass reference. LP uses real nonnegative coefficients over positive-mass keys. CPU LP work and solution are not a native sparse-value reader.'}
    dest = DATA / 'value-affine-coreset' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(output, indent=2) + '\n')
    summary = {key: (max(s[key] for s in samples) if key.endswith('error') or key == 'support' else sum(s[key] for s in samples))
               for key in ('support', 'input_active', 'lp_cpu_seconds', 'moment_max_error')}
    print(json.dumps({'receipt': str(dest), 'samples': len(samples), 'summary': summary}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--positions', type=int, nargs='+', default=[63, 127, 191, 255])
    args = parser.parse_args()
    run(args.layer, args.positions)
