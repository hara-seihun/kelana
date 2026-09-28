#!/usr/bin/env python3
"""Extract distinct decoded Q5_K down columns for a real eight-expert route."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
ROUTE = (10, 3, 239, 129, 1, 225, 109, 190)


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    ids_path = BASE / 'route-capture/held.0.ffn_moe_topk-0.bin'
    scores_path = BASE / 'route-capture/held.0.ffn_moe_weights_norm-0.bin'
    ids = np.fromfile(ids_path, dtype='<i4').reshape(-1, 8)
    scores = np.fromfile(scores_path, dtype='<f4').reshape(-1, 8)
    hidden_path = BASE / 'route-capture/held.0.ffn_moe_swiglu-0.bin'
    hidden = np.memmap(hidden_path, dtype='<f4', mode='r', shape=(len(ids), 8, 512))
    assert tuple(ids[113]) == ROUTE and np.all(np.isfinite(scores[113])) and np.all(scores[113] > 0)
    traffic = BASE / 'traffic.json'
    inv = json.loads(traffic.read_text())
    tensor = next(t for t in inv['tensors'] if t['name'] == 'blk.0.ffn_down_exps.weight')
    assert tensor['type'] == 'Q5_K' and tensor['shape'] == [512, 2048, 256]
    image = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    offset = (inv['header_bytes'] + 31) // 32 * 32 + tensor['offset']
    stride = 2048 * 512 // 256 * 176
    assert tensor['bytes'] == stride * 256
    bank = np.memmap(image, dtype=np.uint8, mode='r', offset=offset, shape=(256, stride))
    library = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    lib = ctypes.CDLL(str(library))
    decode = lib.dequantize_row_q5_K
    decode.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64)
    decode.restype = None
    a.output.parent.mkdir(parents=True, exist_ok=True)
    classes = []
    with a.output.open('wb') as output:
        w = np.empty((2048, 512), dtype='<f4')
        for slot, e in enumerate(ROUTE):
            decode(bank[e].ctypes.data, w.ctypes.data, w.size)
            assert np.all(np.isfinite(w))
            # Bitwise labels avoid silently merging distinct signed-zero images.
            unique, inverse, counts = np.unique(w.T.copy().view('<u4'), axis=0,
                                                 return_inverse=True, return_counts=True)
            output.write(unique.view('<f4').tobytes())
            repeated = counts[inverse] > 1
            classes.append({'expert': e, 'distinct_columns': len(counts),
                            'duplicate_columns': int(sum(counts-1)),
                            'repeated_coordinates': int(repeated.sum()),
                            'repeated_hidden_nonzero_on_token_113': int(np.count_nonzero(hidden[113, slot, repeated])),
                            'singleton_hidden_nonzero_on_token_113': int(np.count_nonzero(hidden[113, slot, ~repeated])),
                            'largest_class': int(max(counts)),
                            'class_counts_sha256': hashlib.sha256(counts.astype('<i4').tobytes()).hexdigest(),
                            'column_to_class_sha256': hashlib.sha256(inverse.astype('<i4').tobytes()).hexdigest()})
    receipt = {'domain': 'held installed-GGUF layer-0 token 113; all eight selected experts in router rank',
               'experts': ROUTE, 'classes': classes, 'total_distinct_columns': sum(c['distinct_columns'] for c in classes),
               'scores_bits_hex': [hex(int(x)) for x in scores[113].view('<u4')],
               'matrix_layout': 'concatenated lexicographically distinct bitwise FP32 decoded down columns, each length 2048, little-endian; includes all eight experts',
               'matrix_sha256': digest(a.output),
               'source_sha256': digest(Path(__file__)),
               'installed_library_sha256': digest(library), 'inventory_sha256': digest(traffic),
               'route_sha256': digest(ids_path), 'scores_sha256': digest(scores_path),
               'hidden_sha256': digest(hidden_path),
               'model_acquisition_sha256': digest(BASE / 'acquisition.json'),
               'model_sha256': json.loads((BASE / 'acquisition.json').read_text()).get('sha256')}
    a.output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'matrix_sha256': receipt['matrix_sha256'], 'route': ROUTE, 'scores_bits': receipt['scores_bits_hex']}))


if __name__ == '__main__':
    main()
