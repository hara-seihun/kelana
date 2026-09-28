#!/usr/bin/env python3
"""Exact expert-major dispatch and an explicit MoE weight-traffic model.

No model execution or GPU timing occurs here. All byte counts are logical transfers.
"""

import argparse
import json
import math
import random
import struct
from pathlib import Path

D = 2048
F = 512
E = 256
K = 8
LAYERS = 40
WEIGHTS_PER_EXPERT = 3 * D * F


def validate(routes):
    if not routes:
        raise ValueError("routes must contain at least one token")
    for row in routes:
        if len(row) != K or len(set(row)) != K or any(not isinstance(e, int) or not 0 <= e < E for e in row):
            raise ValueError("each token needs eight distinct expert ids in [0,256)")


def dispatch(routes):
    """Stable counting sort; each entry retains its source token and router rank."""
    validate(routes)
    counts = [0] * E
    for row in routes:
        for expert in row:
            counts[expert] += 1
    offsets = [0] * (E + 1)
    for i, n in enumerate(counts):
        offsets[i + 1] = offsets[i] + n
    cursor = offsets[:-1].copy()
    indices = [None] * offsets[-1]
    for token, row in enumerate(routes):
        for rank, expert in enumerate(row):
            pos = cursor[expert]
            indices[pos] = (token, rank)
            cursor[expert] += 1
    return offsets, indices


def f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]


def schedule_witness(routes):
    """Check the dispatch inverse and FP32 order on tiny deterministic expert outputs."""
    offsets, indices = dispatch(routes)
    slots = [[None] * K for _ in routes]
    for expert in range(E):
        for token, rank in indices[offsets[expert]:offsets[expert + 1]]:
            if routes[token][rank] != expert or slots[token][rank] is not None:
                raise AssertionError("dispatch is not a permutation of assignments")
            slots[token][rank] = (expert, token, rank)
    if any(any(item is None for item in row) for row in slots):
        raise AssertionError("missing inverse slot")
    # Bitwise comparison catches changed addition order, not a model projection.
    for token, row in enumerate(routes):
        gate = [f32((rank + 1) / 19) for rank in range(K)]
        def sample(expert, rank):
            return f32(((expert * 31 + token * 7 + rank * 13) % 101 - 50) / 17)
        original = [sample(expert, rank) for rank, expert in enumerate(row)]
        grouped = [sample(expert, rank) for expert, _, rank in slots[token]]
        a = f32(0)
        b = f32(0)
        for rank in range(K):
            a = f32(a + f32(gate[rank] * original[rank]))
            b = f32(b + f32(gate[rank] * grouped[rank]))
        if struct.pack('<f', a) != struct.pack('<f', b):
            raise AssertionError("FP32 ordered sum changed")
    return offsets, indices


def synthetic(batch, seed, family):
    rng = random.Random(seed)
    routes = []
    previous = None
    if family not in ('uniform', 'hot32', 'zipf', 'sticky'):
        raise ValueError(family)
    population = list(range(32 if family == 'hot32' else E))
    zipf_weights = [1 / (e + 1) for e in population] if family == 'zipf' else None
    for _ in range(batch):
        if family == 'sticky' and previous is not None and rng.random() < 0.75:
            row = previous.copy()
        elif family == 'zipf':
            row = []
            while len(row) < K:
                expert = rng.choices(population, weights=zipf_weights)[0]
                if expert not in row:
                    row.append(expert)
        else:
            row = rng.sample(population, K)
        routes.append(row)
        previous = row
    return routes


def estimate(routes, bytes_per_weight, tile, activation_bytes, launch_us=0.0, bandwidth_gbs=1000.0):
    offsets, _ = schedule_witness(routes)
    counts = [offsets[i + 1] - offsets[i] for i in range(E)]
    assignments = len(routes) * K
    nonempty = [n for n in counts if n]
    loads = sum(math.ceil(n / tile) for n in nonempty)
    weight_image = WEIGHTS_PER_EXPERT * bytes_per_weight
    baseline = assignments * weight_image
    grouped = loads * weight_image
    # Conservative *extra* traffic. An implementation may directly index x and write
    # partials into rank slots, removing the explicit x staging term. This upper bill
    # charges both a write and a read of x and the FP32 partial, plus 8-byte assignment
    # metadata written and read. Router logits/top-k and shared expert are unchanged.
    staging = assignments * (2 * D * activation_bytes + 2 * D * 4 + 16)
    saved = baseline - grouped
    return {
        'batch': len(routes), 'assignments': assignments, 'unique_experts': len(nonempty),
        'singletons': sum(n == 1 for n in nonempty),
        'experts_ge_4': sum(n >= 4 for n in nonempty),
        'experts_ge_8': sum(n >= 8 for n in nonempty),
        'max_group': max(nonempty), 'tile': tile,
        'weight_loads_baseline': assignments, 'weight_loads_grouped': loads,
        'weight_bytes_baseline': round(baseline), 'weight_bytes_grouped': round(grouped),
        'extra_staging_bytes_upper': staging, 'net_bytes_saved_after_upper_staging': round(saved - staging),
        'ideal_weight_reuse': assignments / loads,
        'traffic_margin_us_at_bandwidth': (saved - staging) / (bandwidth_gbs * 1000) - launch_us,
        'break_even_extra_launch_us_at_bandwidth': (saved - staging) / (bandwidth_gbs * 1000),
        'router_logits_per_token': E, 'topk_per_token': K, 'moe_layers': LAYERS,
        'routed_matmul_macs': assignments * WEIGHTS_PER_EXPERT,
        'shared_matmul_macs': len(routes) * WEIGHTS_PER_EXPERT,
        'route_weight_products': assignments * D,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--trace', type=Path, help='JSON array of token top-8 lists, or object with routes key')
    parser.add_argument('--batch', type=int, default=128)
    parser.add_argument('--family', choices=['uniform', 'hot32', 'zipf', 'sticky'], default='uniform')
    parser.add_argument('--seed', type=int, default=17)
    parser.add_argument('--tile', type=int, default=16, help='max tokens reusing one expert image per load')
    parser.add_argument('--bytes-per-weight', type=float, default=0.5625, help='including effective scales and alignment')
    parser.add_argument('--activation-bytes', type=int, default=2)
    parser.add_argument('--extra-launch-us', type=float, default=0)
    parser.add_argument('--bandwidth-gbs', type=float, default=1000)
    args = parser.parse_args()
    if args.batch <= 0 or args.tile <= 0 or args.bytes_per_weight <= 0 or args.activation_bytes <= 0 or args.bandwidth_gbs <= 0:
        parser.error('batch, tile, bytes-per-weight, activation-bytes and bandwidth must be positive')
    if args.trace:
        data = json.loads(args.trace.read_text())
        routes = data['routes'] if isinstance(data, dict) else data
    else:
        routes = synthetic(args.batch, args.seed, args.family)
    report = estimate(routes, args.bytes_per_weight, args.tile, args.activation_bytes,
                      args.extra_launch_us, args.bandwidth_gbs)
    report['source'] = str(args.trace) if args.trace else f'synthetic:{args.family}:seed={args.seed}'
    report['bytes_per_weight_assumption'] = args.bytes_per_weight
    report['bandwidth_gbs_assumption'] = args.bandwidth_gbs
    report['extra_launch_us_assumption'] = args.extra_launch_us
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
