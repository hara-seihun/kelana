#!/usr/bin/env python3
"""Decode four co-routed installed layer-20 down maps into an exact-rank witness."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
LAYER, TOKEN = 20, 1
ROUTE = (172, 128, 232, 255, 191, 222, 178, 6)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    ids_path = BASE / f'all-down-zero/held.layer-{LAYER}.ffn_moe_topk.i32'
    scores_path = BASE / f'all-down-zero/held.layer-{LAYER}.ffn_moe_weights_norm.f32'
    ids = np.fromfile(ids_path, '<i4').reshape(-1, 8)
    scores = np.fromfile(scores_path, '<f4').reshape(-1, 8)
    assert tuple(ids[TOKEN]) == ROUTE and len(scores) == len(ids)
    assert np.all(np.isfinite(scores[TOKEN])) and np.all(scores[TOKEN] > 0)
    inventory = BASE / 'traffic.json'
    inv = json.loads(inventory.read_text())
    t = next(t for t in inv['tensors'] if t['name'] == f'blk.{LAYER}.ffn_down_exps.weight')
    assert t['type'] == 'Q5_K' and t['shape'] == [512, 2048, 256]
    stride = 512*2048//256*176
    assert t['bytes'] == 256*stride
    image = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    offset = (inv['header_bytes'] + 31)//32*32 + t['offset']
    bank = np.memmap(image, dtype=np.uint8, mode='r', offset=offset, shape=(256, stride))
    libpath = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    decode = ctypes.CDLL(str(libpath)).dequantize_row_q5_K
    decode.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64)
    decode.restype = None
    a.output.parent.mkdir(parents=True, exist_ok=True)
    with a.output.open('wb') as out:
        for expert in ROUTE[:4]:
            w = np.empty((2048, 512), dtype='<f4')
            decode(bank[expert].ctypes.data, w.ctypes.data, w.size)
            assert np.all(np.isfinite(w))
            out.write(w.T.copy().tobytes())
    receipt = {'domain': 'installed GGUF layer-20 Q5_K first four down experts on actual held routed token 1',
               'layer': LAYER, 'token': TOKEN, 'route': ROUTE, 'selected_experts': ROUTE[:4],
               'shape': [2048, 2048], 'matrix_sha256': sha(a.output),
               'source_sha256': sha(__file__), 'library_sha256': sha(libpath),
               'inventory_sha256': sha(inventory), 'route_sha256': sha(ids_path),
               'scores_sha256': sha(scores_path),
               'scores_bits': [hex(int(x)) for x in scores[TOKEN].view('<u4')],
               'model_acquisition_sha256': sha(BASE / 'acquisition.json')}
    a.output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'route': ROUTE, 'four_column_image_sha256': receipt['matrix_sha256']}))

if __name__ == '__main__':
    main()
