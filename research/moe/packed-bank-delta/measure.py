#!/usr/bin/env python3
"""Price lossless parent/XOR coding of routed experts in the pinned GGUF."""
import argparse
import hashlib
import json
import struct
import zlib
from pathlib import Path

import numpy as np

DATA = Path('/path/to/workspace/data/qwen-moe')
BLOCK = {'Q4_K': 144, 'Q5_K': 176, 'Q6_K': 210}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def routes(path, expected):
    blob = path.read_bytes()
    assert sha(path) == expected and len(blob) % 32 == 0
    rows = list(struct.iter_unpack('<8i', blob))
    assert all(len(set(row)) == 8 and min(row) >= 0 and max(row) < 256 for row in rows)
    return rows


def score(raw, ids):
    images = [raw[i].tobytes() for i in ids]
    packed = [len(zlib.compress(image, 1)) for image in images]
    size = len(images[0])
    xor_sizes = [[None] * 8 for _ in ids]
    for i in range(8):
        for j in range(i + 1, 8):
            delta = np.bitwise_xor(raw[ids[i]], raw[ids[j]]).tobytes()
            assert np.array_equal(np.frombuffer(delta, np.uint8) ^ np.frombuffer(images[i], np.uint8), np.frombuffer(images[j], np.uint8))
            xor_sizes[i][j] = xor_sizes[j][i] = len(zlib.compress(delta, 1))
    # Most generous conditional comparison: each child can reference any of the
    # other seven images at zero pointer or residency cost.
    best_parent = [min((xor_sizes[i][j], ids[j]) for j in range(8) if j != i) for i in range(8)]
    star = [packed[root] + sum(xor_sizes[root][j] for j in range(8) if j != root) for root in range(8)]
    return dict(ids=list(ids), raw_bytes=8 * size, independent_zlib_bytes=sum(packed),
                best_star_bytes=min(star), best_star_root=ids[int(np.argmin(star))],
                individual_zlib_bytes=packed, best_conditional_bytes=[p[0] for p in best_parent],
                conditional_wins=sum(p[0] < packed[i] for i, p in enumerate(best_parent)),
                best_parent_ids=[p[1] for p in best_parent])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--split', choices=['train', 'held'], required=True)
    p.add_argument('--rows', type=int, default=4)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    inventory_path = DATA / 'traffic.json'
    inventory = json.loads(inventory_path.read_text())
    receipt_path = DATA / 'route-capture/receipt.json'
    receipt = json.loads(receipt_path.read_text())
    route_path = DATA / 'route-capture' / f'{a.split}.0.ffn_moe_topk-0.bin'
    row_ids = routes(route_path, receipt[a.split]['tensor_sha256']['ids'])[:a.rows]
    alignment = inventory['metadata'].get('general.alignment', 32)
    base = (inventory['header_bytes'] + alignment - 1) // alignment * alignment
    model = DATA / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    with model.open('rb') as f:
        assert hashlib.sha256(f.read(inventory['header_bytes'])).hexdigest() == inventory['header_sha256']
    banks = {}
    for t in inventory['tensors']:
        if not t['name'].startswith('blk.0.ffn_') or '_exps.' not in t['name']:
            continue
        block_bytes = BLOCK[t['type']]
        assert t['bytes'] % (256 * block_bytes) == 0
        raw = np.memmap(model, dtype=np.uint8, mode='r', offset=base + t['offset'],
                        shape=(256, t['bytes'] // (256 * block_bytes), block_bytes))
        banks[t['name']] = dict(type=t['type'], offset=base + t['offset'],
                                rows=[score(raw, ids) for ids in row_ids])
    assert len(banks) == 3
    result = dict(contract='Full GGUF physical expert image, zlib level 1 independently versus XOR with a co-routed parent then zlib level 1; parent availability, indices and decode cost free; route-local groups of 8 at layer 0',
                  model_sha256='ac0e2c1189e055faa36eff361580e79c5bd6f8e76bffb4ce547f167d53e31a61',
                  gguf_header_sha256=inventory['header_sha256'], inventory_sha256=sha(inventory_path),
                  capture_sha256=sha(receipt_path), routes_sha256=sha(route_path),
                  script_sha256=sha(__file__), split=a.split, rows=a.rows, banks=banks)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2) + '\n')
    for name, bank in banks.items():
        rows = bank['rows']
        print(name, 'raw', sum(r['raw_bytes'] for r in rows), 'independent', sum(r['independent_zlib_bytes'] for r in rows),
              'best-star', sum(r['best_star_bytes'] for r in rows),
              'conditional-wins', sum(r['conditional_wins'] for r in rows), '/', len(rows)*8)


if __name__ == '__main__':
    main()
