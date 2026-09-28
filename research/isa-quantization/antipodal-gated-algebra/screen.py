#!/usr/bin/env python3
"""Reflection algebra and coefficient-capacity screen for a complete real MLP."""
import hashlib
import json
from pathlib import Path

import numpy as np
from safetensors import safe_open

DATA = Path('/path/to/workspace/data/kelana-subbit')
SOURCE = DATA / 'models/qwen3-0.6b/model.safetensors'
CAPTURE = DATA / 'vector-full/capture/isa-response'
Q4 = DATA / 'full-scalar'
INPUT = 1024
HIDDEN = 3072
OUTPUT = 1024


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(4 << 20), b''):
            h.update(block)
    return h.hexdigest()


def q4_decode(path):
    with np.load(path) as image:
        rows, cols, bits, group = image['weight_shape'].tolist()
        assert bits == 4 and group == 128
        codes = np.unpackbits(image['weight_codes'], axis=1, bitorder='little')[:, :4*cols]
        codes = codes.reshape(rows, cols, 4)
        labels = (codes.astype(np.int16) << np.arange(4)).sum(axis=2).astype(np.float32)
        scales = np.repeat(image['weight_scales'].astype(np.float32), group, axis=1)[:, :cols]
        paid = sum(image[k].nbytes for k in ('weight_codes', 'weight_scales', 'weight_shape'))
        return np.ascontiguousarray((2*labels-15)*scales), int(paid)


def source():
    with safe_open(SOURCE, framework='pt', device='cpu') as m:
        return [m.get_tensor(f'model.layers.0.mlp.{name}_proj.weight').float().numpy()
                for name in ('gate', 'up', 'down')]


def component(g, u, down):
    bilinear = g * u
    even = (bilinear @ down.T) * .5
    odd = ((bilinear * np.tanh(g * .5)) @ down.T) * .5
    return even, odd


def response(x, gate, up, down):
    g = x @ gate.T
    u = x @ up.T
    return component(g, u, down)


def tensor_gram(gate, up, down):
    kernel = np.empty((HIDDEN, HIDDEN), dtype=np.float32)
    for start in range(0, HIDDEN, 128):
        end = min(start+128, HIDDEN)
        gg = gate[start:end] @ gate.T
        uu = up[start:end] @ up.T
        gu = gate[start:end] @ up.T
        ug = up[start:end] @ gate.T
        kernel[start:end] = (gg*uu + gu*ug) * .125
    gram = down @ kernel @ down.T
    spectrum = np.linalg.eigvalsh((gram+gram.T)*.5)[::-1].clip(0)
    return spectrum


def source_antipodes(gate, up, down):
    gate = gate / np.linalg.norm(gate, axis=1, keepdims=True)
    up = up / np.linalg.norm(up, axis=1, keepdims=True)
    down = down / np.linalg.norm(down, axis=0, keepdims=True)
    closest = np.empty(HIDDEN, np.float32)
    up_alignment = np.empty(HIDDEN, np.float32)
    down_alignment = np.empty(HIDDEN, np.float32)
    for start in range(0, HIDDEN, 128):
        end = min(start+128, HIDDEN)
        similarity = gate[start:end] @ gate.T
        similarity[np.arange(end-start), np.arange(start, end)] = np.inf
        other = similarity.argmin(axis=1)
        closest[start:end] = similarity[np.arange(end-start), other]
        up_alignment[start:end] = np.abs((up[start:end] * up[other]).sum(axis=1))
        down_alignment[start:end] = np.abs((down[:, start:end] * down[:, other]).sum(axis=0))
    return dict(gate_min_cosine_quantiles=np.quantile(closest, [.01,.5,.99]).tolist(),
                median_absolute_up_cosine_at_nearest_gate=float(np.median(up_alignment)),
                median_absolute_down_cosine_at_nearest_gate=float(np.median(down_alignment)),
                gate_pairs_with_cosine_below_minus_point_nine=int((closest < -.9).sum()))


def main():
    gate, up, down = source()
    q4_paths = {name: Q4 / f'model_layers_0_mlp_{name}_proj_weight-g128-b4.npz'
                for name in ('gate','up','down')}
    packed = {name: q4_decode(path) for name, path in q4_paths.items()}
    packed_weights = [packed[name][0] for name in ('gate','up','down')]
    q4_bytes = sum(entry[1] for entry in packed.values())
    assert q4_bytes == 4866096
    per_feature_bytes = (2*INPUT + OUTPUT)*2
    feature_budget = q4_bytes // per_feature_bytes
    spectral = tensor_gram(gate, up, down)
    squared = spectral.astype(np.float64)
    floor = squared[feature_budget:].sum() / squared.sum()
    result = dict(source_sha256=digest(SOURCE), q4_payload_bytes=q4_bytes,
                  q4_images={name: dict(sha256=digest(path), payload_bytes=packed[name][1])
                             for name, path in q4_paths.items()},
                  program=dict(input=INPUT, hidden=HIDDEN, output=OUTPUT,
                               quadratic_bilinear_feature_bytes=per_feature_bytes,
                               maximum_features_at_q4_payload=feature_budget,
                               dense_fp16_symmetric_tensor_bytes=OUTPUT*INPUT*(INPUT+1),
                               optimistic_quadratic_tensor_rank_floor_at_budget=float(floor),
                               spectrum_trace=float(squared.sum())),
                  source_pair_control=source_antipodes(gate, up, down),
                  panels={})
    for split in ('train','held'):
        path = CAPTURE/f'preactivation-{split}.npz'
        with np.load(path) as a:
            g, u = a['g'], a['u']
        even, odd = component(g, u, down)
        target = even + odd
        actual = np.concatenate([np.load(CAPTURE/f'{split}-{chunk}.npz')['target']
                                 for chunk in range(4)])
        x = np.concatenate([np.load(CAPTURE/f'{split}-{chunk}.npz')['inputs']
                            for chunk in range(4)])
        control = np.concatenate([np.load(CAPTURE/f'{split}-{chunk}.npz')['q4']
                                  for chunk in range(4)])
        denom = np.linalg.norm(actual.astype(np.float64))
        qe, qo = response(x, *packed_weights)
        q4_negative = qe-qo
        negative = even-odd
        pair_norm = np.sqrt(np.linalg.norm(actual.astype(np.float64))**2 +
                            np.linalg.norm(negative.astype(np.float64))**2)
        pair_q4_error = np.sqrt(np.linalg.norm((control-actual).astype(np.float64))**2 +
                                np.linalg.norm((q4_negative-negative).astype(np.float64))**2) / pair_norm
        result['panels'][split] = dict(preactivation_sha256=digest(path),
            states=len(x), source_replay_relative_rms=float(np.linalg.norm((target-actual).astype(np.float64))/denom),
            q4_saved_relative_rms=float(np.linalg.norm((control-actual).astype(np.float64))/denom),
            even_only_actual_relative_rms=float(np.linalg.norm(odd.astype(np.float64))/denom),
            even_to_target_norm_ratio=float(np.linalg.norm(even.astype(np.float64))/denom),
            odd_to_target_norm_ratio=float(np.linalg.norm(odd.astype(np.float64))/denom),
            even_odd_cosine=float(np.sum(even.astype(np.float64)*odd.astype(np.float64)) /
                                  (np.linalg.norm(even.astype(np.float64))*np.linalg.norm(odd.astype(np.float64)))),
            symmetric_even_optimal_relative_rms=float(np.linalg.norm(odd.astype(np.float64)) /
                np.sqrt(np.linalg.norm(even.astype(np.float64))**2+np.linalg.norm(odd.astype(np.float64))**2)),
            symmetric_q4_relative_rms=float(pair_q4_error),
            q4_replay_relative_rms=float(np.linalg.norm((qe+qo-control).astype(np.float64)) /
                                         np.linalg.norm(control.astype(np.float64))))
    output = Path(__file__).with_name('results.json')
    output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(dict(budget_rank=feature_budget, coefficient_floor=float(floor),
                          panels={k:dict(even_only=v['even_only_actual_relative_rms'],
                                         symmetric_floor=v['symmetric_even_optimal_relative_rms'],
                                         symmetric_q4=v['symmetric_q4_relative_rms'])
                                  for k,v in result['panels'].items()}), indent=2))


if __name__ == '__main__':
    main()
