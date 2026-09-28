#!/usr/bin/env python3
"""Decode the actual held eight-expert gate/up preactivation map (CPU only)."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
ROUTE = (10, 3, 239, 129, 1, 225, 109, 190)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    ids_file = BASE / 'route-capture/held.0.ffn_moe_topk-0.bin'
    ids = np.fromfile(ids_file, '<i4').reshape(-1, 8)
    assert tuple(ids[113]) == ROUTE
    scores_file = BASE / 'route-capture/held.0.ffn_moe_weights_norm-0.bin'
    scores = np.fromfile(scores_file, '<f4').reshape(-1, 8)
    assert np.all(np.isfinite(scores[113])) and np.all(scores[113] > 0)
    inventory = BASE / 'traffic.json'
    inv = json.loads(inventory.read_text())
    image = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    libpath = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    decode = ctypes.CDLL(str(libpath)).dequantize_row_q4_K
    decode.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64)
    decode.restype = None
    a.output.parent.mkdir(parents=True, exist_ok=True)
    counts = []
    with a.output.open('wb') as out:
        for expert in ROUTE:
            entry = {'expert': expert}
            for name in ('gate', 'up'):
                t = next(t for t in inv['tensors'] if t['name'] == f'blk.0.ffn_{name}_exps.weight')
                assert t['type'] == 'Q4_K' and t['shape'] == [2048, 512, 256]
                stride = 2048 * 512 // 256 * 144
                assert t['bytes'] == 256 * stride
                offset = (inv['header_bytes'] + 31) // 32 * 32 + t['offset']
                bank = np.memmap(image, dtype=np.uint8, mode='r', offset=offset, shape=(256, stride))
                w = np.empty((512, 2048), dtype='<f4')
                decode(bank[expert].ctypes.data, w.ctypes.data, w.size)
                assert np.all(np.isfinite(w))
                live = np.any(w != 0, axis=1)
                out.write(w[live].tobytes())
                entry[name + '_nonzero_rows'] = int(live.sum())
                entry[name + '_row_mask_sha256'] = hashlib.sha256(live.tobytes()).hexdigest()
            counts.append(entry)
    receipt = {'domain': 'installed GGUF decoded real gate/up preactivations on held layer-0 token 113 route',
               'route': ROUTE, 'row_order': 'route expert order, gate then up, nonzero rows ascending; FP32 little endian [rows,2048]',
               'rows': sum(e['gate_nonzero_rows'] + e['up_nonzero_rows'] for e in counts),
               'per_expert': counts, 'matrix_sha256': sha(a.output), 'source_sha256': sha(__file__),
               'library_sha256': sha(libpath), 'inventory_sha256': sha(inventory),
               'route_sha256': sha(ids_file), 'scores_sha256': sha(scores_file),
               'scores_bits': [hex(int(x)) for x in scores[113].view('<u4')],
               'model_acquisition_sha256': sha(BASE / 'acquisition.json')}
    a.output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'rows': receipt['rows'], 'per_expert': counts, 'matrix_sha256': receipt['matrix_sha256']}))

if __name__ == '__main__':
    main()
