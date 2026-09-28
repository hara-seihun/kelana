#!/usr/bin/env python3
"""Price bounded-depth Huffman K-delta parsers against the existing row and group formats."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parent.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
spec = importlib.util.spec_from_file_location('key_entropy_parent', ROOT/'key-entropy-direct/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)


def stream_cost(delta, mapping, rows, digest, check=False, block=None):
    # One byte records each independently addressable segment length. The
    # last segment length follows from the next block offset and other lengths.
    lengths = []
    decoded = []
    for first in range(0, len(delta), rows):
        piece = delta[first:first+rows]
        raw = parent.entropy.roundtrip((piece+15).ravel(), mapping)
        if first + rows < len(delta):
            assert len(raw) <= (65535 if rows >= 4 else 255)
        digest.update(raw)
        lengths.append(len(raw))
        if check:
            decoded.append(parent.decode(raw, mapping, piece.size).reshape(piece.shape))
    if check:
        recovered = np.concatenate(decoded, axis=0)
        assert np.array_equal(recovered, delta)
        query = np.stack((np.arange(32)%11-5, 5-np.arange(32)%9))
        scan = block[0].astype(np.int64) @ query.T + np.cumsum(recovered.astype(np.int64) @ query.T, axis=0)
        assert np.array_equal(scan, block[1:].astype(np.int64) @ query.T)
    return sum(lengths) + max(0, len(lengths)-1) * (2 if 4 <= rows < 31 else 1), max(lengths)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--layer', required=True, type=int, choices=(0,14))
    args = p.parse_args()
    torch.set_num_threads(4)
    layer = args.layer
    suffix = f'layer{layer:02d}'
    nibble_path = DATA/f'key-nibble-cache/{suffix}.json'
    prior_path = DATA/f'paid-qk-cache-slack/{suffix}.json'
    q_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    nibble = json.loads(nibble_path.read_text())
    prior = json.loads(prior_path.read_text())
    with safe_open(parent.finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{layer}.self_attn.'
        weights = {name:model.get_tensor(prefix+name+'.weight').float() for name in ('q_proj','k_proj','q_norm','k_norm')}
    weights['q_proj'] = parent.paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = parent.paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    train = parent.image(layer,'train',8,weights,gamma,nibble)
    held = parent.image(layer,'validation',4,weights,gamma,nibble)
    restart = 32
    tr = parent.differences(train,restart)
    hd = parent.differences(held,restart)
    tables = [parent.entropy.canonical(np.bincount((tr[:,g]+15).ravel(),minlength=31)) for g in range(8)]
    table_bytes = (8*31*5+7)//8
    widths = (1,2,4,8,16,31)
    counts = {s:[] for s in widths}
    maxima = {s:0 for s in widths}
    digests = {s:hashlib.sha256() for s in widths}
    for w in range(4):
        window = {s:0 for s in widths}
        for g in range(8):
            mapping = tables[g][1]
            for b in range(256//restart):
                block = held[w,g,b*restart:(b+1)*restart]
                delta = hd[w,g,b]
                for s in widths:
                    bytes_, maximum = stream_cost(delta,mapping,s,digests[s],check=(w==0 and b==0),block=block)
                    window[s] += 16 + 4 + bytes_
                    maxima[s] = max(maxima[s],maximum)
        for s in widths:
            counts[s].append(window[s])
    result = {
        'layer':layer,'shape':list(held.shape),'restart':restart,'table_bytes':table_bytes,
        'contract':'Train eight windows for one canonical difference Huffman table per group; four inspected original-producer validation windows. One 16-byte anchor and four-byte block offset per group/32-key block; byte-aligned independent segments of at most S successive difference rows, one byte per segment length except the last for S<=2, two for S=4,8,16 (full-domain maximum lengths do not fit one byte). Bounded serial Huffman parse of 32*S symbols, followed by two direct delta dots and a five-stage score scan. Unpriced: native parser, parallel scheduling, open-block append/repacking, table expansion and model loss.',
        'widths':[{ 'rows_per_segment':s,'parsers_per_group_block':(30+s)//s,
            'max_serial_symbols':32*s if s<=16 else 992, 'length_bytes':2 if 4<=s<31 else (0 if s==31 else 1),
            'per_window_bytes':counts[s],'total_bytes':sum(counts[s])+table_bytes,
            'bytes_per_token':(sum(counts[s])+table_bytes)/1024,
            'max_segment_bytes':maxima[s], 'streams_sha256':digests[s].hexdigest()} for s in widths],
        'parent_source_sha256':parent.sha(ROOT/'key-entropy-direct/measure.py'),
        'source_sha256':parent.sha(Path(__file__)),
        'model_sha256':parent.sha(parent.finite.MODEL),
        'capture_sha256':parent.sha(parent.finite.value_fit.CAPTURES/f'{suffix}.npz'),
        'nibble_sha256':parent.sha(nibble_path),'prior_sha256':parent.sha(prior_path),
        'paid_q_sha256':parent.sha(q_path),'paid_k_sha256':parent.sha(k_path),
    }
    out = DATA/f'key-entropy-microstreams/{suffix}.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'layer':layer,'bytes_per_token':[(r['rows_per_segment'],r['bytes_per_token']) for r in result['widths']]}))

if __name__ == '__main__':
    main()
