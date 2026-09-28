#!/usr/bin/env python3
"""Bound four-row key-delta Huffman segments to one-byte lengths on every code history."""
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
spec = importlib.util.spec_from_file_location('microstreams', ROOT/'key-entropy-microstreams/measure.py')
micro = importlib.util.module_from_spec(spec)
spec.loader.exec_module(micro)
parent = micro.parent


def bounded(hist, max_depth):
    # Adding a uniform pseudocount gives a total prefix tree while reducing
    # its maximum depth. Select by paid train bits, not held stream length.
    choices = []
    for extra in (0, 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072):
        lengths, mapping = parent.entropy.canonical(hist + extra)
        if max(lengths) <= max_depth:
            choices.append((int(np.dot(hist, lengths)), extra, lengths, mapping))
    assert choices
    return min(choices, key=lambda x: (x[0], x[1]))


def stream(delta, mapping, length_bytes, digest, rows, limit=None, check=False):
    parts = []
    for first in range(0, 31, rows):
        piece = delta[first:first+rows]
        raw = parent.entropy.roundtrip((piece+15).ravel(), mapping)
        if limit is not None:
            assert len(raw) <= limit
        if check:
            assert np.array_equal(parent.decode(raw, mapping, piece.size).reshape(piece.shape), piece)
        parts.append(raw)
        digest.update(raw)
    # The last length follows from the next block address.
    return sum(map(len, parts)) + (len(parts)-1)*length_bytes, max(map(len, parts))


def run(layer):
    torch.set_num_threads(4)
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
    tr = parent.differences(train,32)
    hd = parent.differences(held,32)
    original = []
    selected = {4:[],8:[]}
    for g in range(8):
        hist = np.bincount((tr[:,g]+15).ravel(), minlength=31)
        lengths, mapping = parent.entropy.canonical(hist)
        original.append((lengths, mapping))
        selected[4].append(bounded(hist,15))
        selected[8].append(bounded(hist,7))
    configs = {'four_old2':(4,original,2,None), 'four_bounded1':(4,selected[4],1,240),
               'eight_old2':(8,original,2,None), 'eight_bounded1':(8,selected[8],1,224)}
    digests = {name:hashlib.sha256() for name in configs}
    windows = []
    max_part = {name:0 for name in digests}
    for w in range(4):
        counts = {name:0 for name in digests}
        for g in range(8):
            for b in range(8):
                delta = hd[w,g,b]
                for name, (rows, tables, width, limit) in configs.items():
                    mapping = tables[g][1] if name.endswith('old2') else tables[g][3]
                    total, maximum = stream(delta,mapping,width,digests[name],rows,limit,check=w==0 and b==0)
                    counts[name] += 20 + total
                    max_part[name] = max(max_part[name],maximum)
        windows.append(counts)
    table_bytes = (8*31*5+7)//8
    result = {'layer':layer,'restart':32,'table_bytes':table_bytes,
        'bounded_worst_segment_bytes':{'four_bounded1':240,'eight_bounded1':224},
        'original_max_code_lengths':[max(x[0]) for x in original],
        'bounded_max_code_lengths':{str(rows):[max(x[2]) for x in selected[rows]] for rows in selected},
        'selected_extra_pseudocount':{str(rows):[x[1] for x in selected[rows]] for rows in selected},
        'selected_code_lengths':{str(rows):[x[2] for x in selected[rows]] for rows in selected},
        'windows':windows,'max_observed_segment_bytes':max_part,
        'bytes_per_token':{name:(sum(w[name] for w in windows)+table_bytes)/1024 for name in digests},
        'stream_sha256':{name:digests[name].hexdigest() for name in digests},
        'source_sha256':parent.sha(Path(__file__)),'parent_source_sha256':parent.sha(ROOT/'key-entropy-microstreams/measure.py'),
        'model_sha256':parent.sha(parent.finite.MODEL),'capture_sha256':parent.sha(parent.finite.value_fit.CAPTURES/f'{suffix}.npz'),
        'nibble_sha256':parent.sha(nibble_path),'prior_sha256':parent.sha(prior_path),
        'paid_q_sha256':parent.sha(q_path),'paid_k_sha256':parent.sha(k_path)}
    out = DATA/f'key-length-bounded/{suffix}.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'layer':layer,'max_original':result['original_max_code_lengths'],'extra':result['selected_extra_pseudocount'],'bytes_per_token':result['bytes_per_token']}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer',type=int,choices=(0,14),required=True)
    run(parser.parse_args().layer)
