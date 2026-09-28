#!/usr/bin/env python3
"""Decode an actual co-routed gate/up input map for a modular rank witness."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
TOKEN = 1


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(4 << 20), b''):
            h.update(block)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--layer', required=True, type=int, choices=range(40))
    a = p.parse_args()
    layer = a.layer
    ids_path = BASE / f'all-down-zero/held.layer-{layer}.ffn_moe_topk.i32'
    scores_path = BASE / f'all-down-zero/held.layer-{layer}.ffn_moe_weights_norm.f32'
    ids = np.fromfile(ids_path, '<i4').reshape(-1, 8)
    scores = np.fromfile(scores_path, '<f4').reshape(-1, 8)
    route = tuple(map(int, ids[TOKEN]))
    assert len(set(route)) == 8
    assert np.isfinite(scores[TOKEN]).all() and (scores[TOKEN] > 0).all()
    inventory = BASE / 'traffic.json'
    inv = json.loads(inventory.read_text())
    image = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    libpath = (BASE / 'runtime/current/bin/libggml-base.so').resolve()
    decode = ctypes.CDLL(str(libpath)).dequantize_row_q4_K
    decode.argtypes = (ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64)
    decode.restype = None
    stride = 512 * 2048 // 256 * 144
    a.output.parent.mkdir(parents=True, exist_ok=True)
    with a.output.open('wb') as out:
        for expert in route[:2]:
            for family in ('gate', 'up'):
                name = f'blk.{layer}.ffn_{family}_exps.weight'
                t = next(t for t in inv['tensors'] if t['name'] == name)
                assert t['type'] == 'Q4_K' and t['shape'] == [2048, 512, 256]
                assert t['bytes'] == 256 * stride
                offset = (inv['header_bytes'] + 31)//32*32 + t['offset']
                bank = np.memmap(image, dtype=np.uint8, mode='r', offset=offset,
                                 shape=(256, stride))
                w = np.empty((512, 2048), dtype='<f4')
                decode(bank[expert].ctypes.data, w.ctypes.data, w.size)
                assert np.isfinite(w).all()
                out.write(w.tobytes())
    receipt = {'domain': 'installed GGUF first two selected gate/up expert pairs on held routed token 1',
               'layer': layer, 'token': TOKEN, 'route': route, 'selected_experts': route[:2],
               'shape': [2048, 2048], 'matrix_sha256': sha(a.output),
               'source_sha256': sha(__file__), 'decoder_sha256': sha(libpath),
               'inventory_sha256': sha(inventory), 'route_sha256': sha(ids_path),
               'scores_sha256': sha(scores_path),
               'scores_bits': [hex(int(x)) for x in scores[TOKEN].view('<u4')],
               'model_acquisition_sha256': sha(BASE / 'acquisition.json')}
    a.output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'layer': layer, 'route': route, 'matrix_sha256': receipt['matrix_sha256']}))


if __name__ == '__main__':
    main()
