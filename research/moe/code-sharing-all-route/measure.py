#!/usr/bin/env python3
"""Finite exact same-K low-code reuse upper bound on real Qwen routed assignments."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np

DATA = Path('/path/to/workspace/data/qwen-moe')
MODEL = DATA / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def redundancy(codes, routes):
    # The eight selected expert labels occupy axis zero; sort each fixed K fragment.
    sums = np.zeros(len(routes), dtype=np.int64)
    for i, ids in enumerate(routes):
        ordered = np.sort(codes[ids], axis=0)
        sums[i] = np.count_nonzero(ordered[1:] == ordered[:-1])
    return sums.tolist()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--start', type=int, required=True)
    p.add_argument('--stop', type=int, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    assert 0 <= a.start < a.stop <= 40
    inv_path = DATA / 'traffic.json'
    cap_path = DATA / 'all-producers/receipt.json'
    inv, cap = json.loads(inv_path.read_text()), json.loads(cap_path.read_text())
    assert inv['expert_count'] == 256 and inv['experts_per_token'] == 8
    assert cap['model_sha256'] == 'ac0e2c1189e055faa36eff361580e79c5bd6f8e76bffb4ce547f167d53e31a61'
    with MODEL.open('rb') as f:
        assert hashlib.sha256(f.read(inv['header_bytes'])).hexdigest() == inv['header_sha256']
    align = inv['metadata'].get('general.alignment', 32)
    base = (inv['header_bytes'] + align - 1) // align * align
    output = {'start': a.start, 'stop': a.stop, 'model_sha256': cap['model_sha256'],
              'header_sha256': inv['header_sha256'], 'inventory_sha256': sha(inv_path),
              'capture_receipt_sha256': sha(cap_path), 'source_sha256': sha(__file__), 'layers': []}
    for layer in range(a.start, a.stop):
        routes = {}
        hashes = {}
        for split in ('train', 'held'):
            path = DATA / f'all-producers/{split}.layer-{layer}.ffn_moe_topk.i32'
            hashes[split] = sha(path)
            routes[split] = np.fromfile(path, dtype='<i4').reshape(64, 8)
            assert np.all((routes[split] >= 0) & (routes[split] < 256))
            assert all(len(set(row)) == 8 for row in routes[split])
        banks = []
        for bank in ('gate', 'up'):
            name = f'blk.{layer}.ffn_{bank}_exps.weight'
            t, = (x for x in inv['tensors'] if x['name'] == name)
            assert t['type'] == 'Q4_K' and t['bytes'] % (256*144) == 0
            blocks = t['bytes'] // (256*144)
            raw = np.memmap(MODEL, dtype='u1', offset=base+t['offset'], shape=(256, blocks, 144), mode='r')
            code = raw[:, :, 16:]
            counts = {}
            for n in (4, 8, 16):
                v = np.ascontiguousarray(code).view(f'V{n}').reshape(256, -1)
                counts[str(n)] = {s: redundancy(v, r) for s, r in routes.items()}
            full = np.ascontiguousarray(raw).view('V144').reshape(256, blocks)
            counts['full'] = {s: redundancy(full, r) for s, r in routes.items()}
            banks.append({'name': name, 'blocks_per_expert': blocks, 'tensor_offset': base+t['offset'],
                          'tensor_bytes': t['bytes'], 'counts': counts})
        output['layers'].append({'layer': layer, 'routes_sha256': hashes, 'banks': banks})
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(output, separators=(',', ':'))+'\n')
    for row in output['layers']:
        print(row['layer'], [(b['name'], {n:sum(b['counts'][n]['held']) for n in b['counts']}) for b in row['banks']])


if __name__ == '__main__':
    main()
