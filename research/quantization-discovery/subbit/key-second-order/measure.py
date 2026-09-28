#!/usr/bin/env python3
"""Price causal order-two prediction of frozen signed-nibble key labels."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


parent = module('key_entropy_direct', ROOT/'key-entropy-direct/measure.py')
fits = parent.finite
paid = parent.paid


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def residuals(codes, width, order):
    blocks = codes.reshape(codes.shape[0], 8, 256//width, width, 32).astype(np.int16)
    previous = blocks[:, :, :, :-1, :]
    if order == 0:
        return blocks, blocks
    if order == 1:
        return blocks, blocks[:, :, :, 1:, :] - previous
    prediction = np.concatenate((previous[:, :, :, :1, :],
                                 2*previous[:, :, :, 1:, :] - previous[:, :, :, :-1, :]), axis=3)
    return blocks, blocks[:, :, :, 1:, :] - prediction


def bill(train, held, width, order):
    _, td = residuals(train, width, order)
    blocks, hd = residuals(held, width, order)
    limit = 7 if order == 0 else (15 if order == 1 else 28)
    symbols = 2*limit+1
    tables = []
    for group in range(8):
        hist = np.bincount((td[:, group]+limit).ravel(), minlength=symbols)
        lengths = canonical_lengths(hist)
        tables.append(lengths)
    depth = max(max(t) for t in tables)
    assert (32*depth+7)//8 <= 255
    length_bits = max(1, depth.bit_length())
    table_bytes = (8*symbols*length_bits+7)//8
    group_windows = []
    row_windows = []
    max_row_bytes = 0
    max_block_bytes = 0
    for window in range(4):
        gb = rb = 0
        for group in range(8):
            lengths = np.asarray(tables[group], dtype=np.int32)
            for block in range(256//width):
                weighted = lengths[(hd[window,group,block]+limit)]
                stream = (int(weighted.sum())+7)//8
                row = (weighted.sum(axis=1)+7)//8
                gb += (0 if order == 0 else 16)+4+stream
                rb += (0 if order == 0 else 16)+4+(width if order == 0 else width-1)+int(row.sum())
                max_row_bytes = max(max_row_bytes, int(row.max()))
                max_block_bytes = max(max_block_bytes, (0 if order == 0 else 16)+4+(width if order == 0 else width-1)+int(row.sum()))
                source = blocks[window,group,block]
                recovered = np.empty_like(source)
                if order == 0:
                    recovered[:] = hd[window,group,block]
                else:
                    recovered[0] = source[0]
                    for i in range(1,width):
                        pred = recovered[i-1] if order == 1 or i == 1 else 2*recovered[i-1]-recovered[i-2]
                        recovered[i] = pred + hd[window,group,block,i-1]
                assert np.array_equal(recovered,source)
                if block == 0:
                    queries = np.stack((np.arange(32)%11-5, 5-np.arange(32)%9),axis=1)
                    direct = source.astype(np.int64) @ queries
                    if order == 0:
                        scores = hd[window,group,block].astype(np.int64) @ queries
                    else:
                        dots = hd[window,group,block].astype(np.int64) @ queries
                        scores = np.empty_like(direct)
                        scores[0] = direct[0]
                        for i in range(1,width):
                            scores[i] = (scores[i-1] + dots[i-1] if order == 1 or i == 1
                                         else 2*scores[i-1]-scores[i-2]+dots[i-1])
                    assert np.array_equal(scores,direct)
        group_windows.append(gb)
        row_windows.append(rb)
    return {'order':order,'width':width,'group_bytes':sum(group_windows)+table_bytes,
            'row_bytes':sum(row_windows)+table_bytes,'group_window_bytes':group_windows,
            'row_window_bytes':row_windows,'table_bytes':table_bytes,
            'max_row_stream_bytes':max_row_bytes,'max_block_bytes':max_block_bytes,
            'length_bits':length_bits,'worst_case_row_bytes':(32*depth+7)//8,
            'train_lengths':tables,
            'held_residual_histogram':np.bincount((hd+limit).ravel(),minlength=symbols).tolist()}


def canonical_lengths(hist):
    import heapq
    heap = [(int(count)+1,i,(i,)) for i,count in enumerate(hist)]
    heapq.heapify(heap)
    lengths = [0]*len(hist)
    serial = len(hist)
    while len(heap)>1:
        a,b = heapq.heappop(heap),heapq.heappop(heap)
        for symbol in a[2]+b[2]:
            lengths[symbol] += 1
        heapq.heappush(heap,(a[0]+b[0],serial,a[2]+b[2]))
        serial += 1
    return lengths


def run(layer):
    torch.set_num_threads(4)
    suffix = f'layer{layer:02d}'
    nibble_path = DATA/f'key-nibble-cache/{suffix}.json'
    prior_path = DATA/f'paid-qk-cache-slack/{suffix}.json'
    q_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    nibble = json.loads(nibble_path.read_text())
    prior = json.loads(prior_path.read_text())
    with safe_open(fits.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{layer}.self_attn.'
        weights = {name:model.get_tensor(prefix+name+'.weight').float() for name in ('q_proj','k_proj','q_norm','k_norm')}
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'],dtype=torch.bfloat16).float()
    train = parent.image(layer,'train',8,weights,gamma,nibble)
    held = parent.image(layer,'validation',4,weights,gamma,nibble)
    rows = [bill(train,held,width,order) for width in (32,256) for order in (0,1,2)]
    result = {'layer':layer,'shape':list(held.shape),'rows':rows,
              'contract':'Frozen paid binary Q/K, signed-nibble keys, eight train windows fit complete-alphabet canonical tables, four inspected validation windows price byte-aligned blocks; absolute labels or one/two causal linear anchors. Integer score recurrences, not FP32-equivalent sums.',
              'source_sha256':digest(Path(__file__)),'model_sha256':digest(fits.MODEL),
              'capture_sha256':digest(fits.value_fit.CAPTURES/f'{suffix}.npz'),
              'nibble_sha256':digest(nibble_path),'prior_sha256':digest(prior_path),
              'paid_q_sha256':digest(q_path),'paid_k_sha256':digest(k_path)}
    output = DATA/f'key-second-order/{suffix}.json'
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'layer':layer,'rates':[(r['width'],r['order'],r['group_bytes']/1024,r['row_bytes']/1024) for r in rows]}),flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer',type=int,choices=(0,14),required=True)
    run(parser.parse_args().layer)
