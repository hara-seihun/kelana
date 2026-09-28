#!/usr/bin/env python3
"""One input coordinate and code shared across a train-selected set of routed experts."""
import argparse
import json
import time
from pathlib import Path

import numpy as np

from study import BASE, DIM, ALPHAS, sha, quant, forward, weights


def capture(split):
    prefix = BASE / 'route-capture' / split
    n = np.fromfile(str(prefix) + '.tokens', np.int32).size
    def field(node, dtype, shape):
        return np.memmap(str(prefix) + '.0.' + node + '-0.bin', dtype, 'r', shape=shape)
    return {'x': field('attn_post_norm', np.float32, (n, DIM)),
            'ids': field('ffn_moe_topk', np.int32, (n, 8)),
            'scores': field('ffn_moe_weights_norm', np.float32, (n, 8)),
            'native_down': field('ffn_moe_down', np.float32, (n, 8, DIM))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--split', choices=('train', 'held'), required=True)
    args = parser.parse_args()
    train = capture('train')
    observed = capture(args.split)
    counts = np.bincount(train['ids'].ravel(), minlength=256)
    experts = np.argsort(-counts, kind='stable')[:16]
    selected = np.isin(observed['ids'], experts)
    selected_token = selected.any(axis=1)
    x_train = np.asarray(train['x'])
    wmax = np.zeros(DIM, np.float32)
    for expert in experts:
        (gate, up, _), _ = weights(int(expert))
        wmax = np.maximum(wmax, np.maximum(np.max(np.abs(gate), axis=0), np.max(np.abs(up), axis=0)))
    xmax = np.maximum(np.max(np.abs(x_train), axis=0), 1e-7)
    logratio = np.log2(np.maximum(wmax, 1e-7) / xmax)
    centered = logratio - np.median(logratio)
    x = np.asarray(observed['x'])
    arms = ['gguf-q4', 'gguf-q8', 'q4w-q8x'] + [str(a) for a in ALPHAS]
    codes = {}
    input_ms = {}
    exponents = {}
    for arm in arms:
        if arm in ('gguf-q4', '0.0'):
            d = np.ones(DIM, np.float32)
            bits = 4
        elif arm in ('gguf-q8', 'q4w-q8x'):
            d = np.ones(DIM, np.float32)
            bits = 8
        else:
            exponent = np.clip(np.rint(float(arm) * centered / 2), -3, 3).astype(np.int8)
            exponents[arm] = {'nonzero': int(np.count_nonzero(exponent)),
                              'minimum': int(exponent.min()), 'maximum': int(exponent.max())}
            d = np.exp2(exponent.astype(np.float32))
            bits = 4
        t0 = time.perf_counter()
        codes[arm] = quant(x[selected_token] * d, bits)
        input_ms[arm] = (time.perf_counter() - t0) * 1000
    included_rows = np.flatnonzero(selected_token)
    position = np.full(len(x), -1, np.int32)
    position[included_rows] = np.arange(len(included_rows))
    native_sum = np.einsum('te,ted->td', observed['scores'].astype(np.float64),
                           observed['native_down'].astype(np.float64))
    reference_sum = native_sum.copy()
    deltas = {arm: np.zeros_like(native_sum) for arm in arms}
    weight_encode_ms = {arm: 0. for arm in arms}
    decoded_consumer_ms = {arm: 0. for arm in arms}
    provenance = None
    for expert in experts:
        rows, slots = np.where(observed['ids'] == expert)
        (gate, up, down), provenance = weights(int(expert))
        reference = forward(x[rows], gate, up, down).astype(np.float64)
        score = observed['scores'][rows, slots].astype(np.float64)[:, None]
        native = observed['native_down'][rows, slots].astype(np.float64)
        reference_sum[rows] += score * (reference - native)
        w = np.concatenate((gate, up))
        for arm in arms:
            if arm.startswith('gguf'):
                target_gate, target_up = gate, up
            else:
                exponent = np.zeros(DIM, np.float32) if arm == 'q4w-q8x' else np.clip(
                    np.rint(float(arm) * centered / 2), -3, 3)
                d = np.exp2(exponent.astype(np.float32))
                t0 = time.perf_counter()
                encoded_w = quant(w / d, 4)
                weight_encode_ms[arm] += (time.perf_counter() - t0) * 1000
                target_gate, target_up = encoded_w[:512], encoded_w[512:]
            t0 = time.perf_counter()
            output = forward(codes[arm][position[rows]], target_gate, target_up, down)
            decoded_consumer_ms[arm] += (time.perf_counter() - t0) * 1000
            deltas[arm][rows] += score * (output.astype(np.float64) - reference)
    denom = np.square(reference_sum).sum()
    result = {'split': args.split, 'source_sha256': sha(__file__), 'study_source_sha256': sha(Path(__file__).with_name('study.py')),
              'provenance': provenance, 'expert_selection': 'top 16 by train routed slot count, ties by ascending ID',
              'experts': experts.tolist(), 'train_slot_counts': counts[experts].tolist(),
              'tokens': len(x), 'tokens_with_selected_expert': int(selected_token.sum()),
              'selected_slots': int(selected.sum()), 'total_slots': int(selected.size),
              'tokens_with_two_or_more_selected_experts': int((selected.sum(axis=1) >= 2).sum()),
              'reference_sum_norm': float(np.sqrt(denom)),
              'input_coordinate': 'common across all 16 experts, trained on all train inputs and selected gate/up bank; same Q4 code per token for every selected gate/up projection',
              'unchanged_other_experts': 'captured down outputs and actual route scores; decoded GGUF offline reference replaces selected slots',
              'exponents': exponents,
              'arms': {arm: {'complete_routed_sum_delta_rms': float(np.sqrt(np.square(delta).sum() / denom)),
                             'input_encode_ms_per_covered_token': input_ms[arm] / int(selected_token.sum()),
                             'decoded_consumer_ms_per_selected_slot': decoded_consumer_ms[arm] / int(selected.sum()),
                             'offline_weight_encode_ms_for_16_experts': weight_encode_ms[arm]}
                       for arm, delta in deltas.items()},
              'bytes': {'original_gguf_gate_up_16_experts': 16 * 1179648,
                        'repacked_gate_up_16_experts': 16 * 1179648,
                        'common_diagonal_fp16': DIM * 2,
                        'q4_common_input_per_covered_token': 1152,
                        'q8_common_input_per_covered_token': 2176,
                        'unchanged_gguf_down_16_experts': 16 * 720896},
              'operations': {'common_diagonal_products_per_covered_token': DIM,
                             'common_input_group_reductions_per_covered_token': DIM // 32,
                             'gate_up_terms_per_selected_slot': 2 * 512 * DIM,
                             'down_terms_per_selected_slot': DIM * 512}}
    path = Path(__file__).with_name('shared-' + args.split + '.json')
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'split': args.split, 'selected_slots': result['selected_slots'],
                      'rms': {arm: entry['complete_routed_sum_delta_rms'] for arm, entry in result['arms'].items()}}, indent=2))


if __name__ == '__main__':
    main()
