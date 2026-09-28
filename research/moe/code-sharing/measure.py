#!/usr/bin/env python3
"""Count exact packed-code reuse across the expert axis of the pinned GGUF.

Same-position collisions are an optimistic bound on sharing integer dot work:
equal code bytes need not have equal scale/min metadata or full operands.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def collisions(values):
    # Sort expert labels separately at each fixed (block, code-fragment) position.
    ordered = np.sort(values, axis=0)
    return int(np.count_nonzero(ordered[1:] == ordered[:-1]))


def route_collisions(values, routes):
    # Fixed seeded eight-of-256 selections, evaluated at all positions. This is
    # a route-conditional *upper* bound: metadata and Q5/Q6 high bits are ignored.
    return [collisions(values[route]) / (8 * values.shape[1]) for route in routes]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--inventory', type=Path, default=Path('/path/to/workspace/data/qwen-moe/traffic.json'))
    p.add_argument('--model', type=Path, default=Path('/path/to/workspace/data/qwen-moe/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'))
    p.add_argument('--layer', type=int, default=0)
    p.add_argument('--experts', type=int, default=256)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    inventory = json.loads(a.inventory.read_text())
    assert inventory['experts_per_token'] == 8 and inventory['expert_count'] == 256
    assert a.experts <= 256 and a.experts > 1
    alignment = inventory['metadata'].get('general.alignment', 32)
    base = (inventory['header_bytes'] + alignment - 1) // alignment * alignment
    with a.model.open('rb') as f:
        header = f.read(inventory['header_bytes'])
    assert hashlib.sha256(header).hexdigest() == inventory['header_sha256']
    rng = np.random.default_rng(20260923)
    routes = np.array([rng.choice(a.experts, 8, replace=False) for _ in range(16)])
    result = {'model_path': str(a.model), 'model_sha256': 'ac0e2c1189e055faa36eff361580e79c5bd6f8e76bffb4ce547f167d53e31a61',
              'inventory_sha256': digest(a.inventory), 'source_sha256': digest(__file__),
              'header_sha256': inventory['header_sha256'], 'layer': a.layer, 'experts': a.experts,
              'synthetic_routes': routes.tolist(), 'banks': []}
    for t in inventory['tensors']:
        if not t['name'].startswith(f'blk.{a.layer}.ffn_') or '_exps.' not in t['name']:
            continue
        if t['type'] not in ('Q4_K', 'Q5_K', 'Q6_K'):
            raise ValueError((t['name'], t['type']))
        block_bytes = {'Q4_K': 144, 'Q5_K': 176, 'Q6_K': 210}[t['type']]
        assert t['bytes'] % (256 * block_bytes) == 0
        blocks = t['bytes'] // (256 * block_bytes)
        offset = base + t['offset']
        raw = np.memmap(a.model, dtype=np.uint8, mode='r', offset=offset,
                        shape=(256, blocks, block_bytes))[:a.experts]
        assert offset + t['bytes'] <= a.model.stat().st_size
        # Ignore scales and the Q5/Q6 high-bit plane. This makes collisions
        # *more* likely than equal full 32-weight integer dot operands.
        code = raw[:, :, :128] if t['type'] == 'Q6_K' else raw[:, :, block_bytes - 128:]
        bank = {'name': t['name'], 'type': t['type'], 'offset': offset,
                'blocks_per_expert': blocks, 'code_bytes_per_block': 128,
                'optimistic_code_fragments': []}
        for n in (4, 8, 16, 32, 128):
            # Same-position collisions permit sharing one dot against one input
            # only if the missing high bits, scales and placement also agree.
            v = np.ascontiguousarray(code.reshape(a.experts, -1, n))
            v = v.view(f'V{n}').reshape(a.experts, -1)
            redundant = collisions(v)
            route_fractions = route_collisions(v, routes)
            bank['optimistic_code_fragments'].append({'bytes': n, 'total': int(v.size),
                                                       'redundant_same_position': redundant,
                                                       'fraction': redundant / v.size,
                                                       'synthetic_route_fractions': route_fractions})
        # Full blocks include their scales, mins, and Q5 high bits, so exact
        # duplicates have an identical quantized weight map at this position.
        v = np.ascontiguousarray(raw).view(f'V{block_bytes}').reshape(a.experts, blocks)
        bank['exact_full_block_redundant_same_position'] = collisions(v)
        result['banks'].append(bank)
    if len(result['banks']) != 3:
        raise ValueError('Expected down, gate and up routed banks')
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'layer': a.layer, 'experts': a.experts,
                      'banks': [(x['name'], [(c['bytes'], c['redundant_same_position']) for c in x['optimistic_code_fragments']],
                                 x['exact_full_block_redundant_same_position']) for x in result['banks']]}))


if __name__ == '__main__':
    main()
