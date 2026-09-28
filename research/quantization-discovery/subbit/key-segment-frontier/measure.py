#!/usr/bin/env python3
"""Optimize fixed K-difference segment boundaries for charged, independently parsed score streams."""
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
spec = importlib.util.spec_from_file_location('bounded_key', ROOT/'key-length-bounded/measure.py')
bounded_key = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bounded_key)
parent = bounded_key.parent


def segment_bytes(delta, lengths):
    bits = lengths[(delta + 15).astype(np.intp)].sum(axis=-1)
    cumulative = np.pad(np.cumsum(bits, axis=-1), [(0,0)]*(bits.ndim-1)+[(1,0)])
    return {(a,b): (np.ceil((cumulative[...,b]-cumulative[...,a])/8).astype(np.int32))
            for a in range(31) for b in range(a+1,32)}


def optimum(train, segments, maximum):
    # Additive byte cost over train blocks makes this a shortest path through
    # (number of completed segments, difference-row position).
    dp = {(0,0): (0,())}
    for k in range(1,segments+1):
        for end in range(k,32):
            choices = []
            for start in range(max(k-1,end-maximum),end):
                if (k-1,start) in dp:
                    cost, edges = dp[k-1,start]
                    choices.append((cost + int(train[start,end].sum()), edges + (end,)))
            if choices:
                dp[k,end] = min(choices)
    return dp[segments,31]


def record(chunks, bits):
    sentinel = (1<<bits)-1
    lengths = [len(chunk) for chunk in chunks[:-1]]
    fields = [min(length,sentinel) for length in lengths]
    directory_value = 0
    for field in fields:
        directory_value = (directory_value<<bits) | field
    width = (bits*len(fields)+7)//8
    directory_value <<= 8*width-bits*len(fields)
    directory = directory_value.to_bytes(width,'big')
    body = bytearray()
    for i, chunk in enumerate(chunks):
        if i < len(fields) and fields[i] == sentinel:
            body.extend(len(chunk).to_bytes(2,'little'))
        body.extend(chunk)
    packed = directory + body
    # Address each parser by scanning only directory fields and exceptional
    # length words, then verify its independent byte interval.
    pos = width
    for i, chunk in enumerate(chunks):
        if i < len(fields):
            field = (directory_value >> (8*width-bits*(i+1))) & sentinel
            length = field
            if field == sentinel:
                length = int.from_bytes(packed[pos:pos+2],'little')
                pos += 2
            assert length == len(chunk)
        else:
            length = len(packed)-pos
        assert packed[pos:pos+length] == chunk
        pos += length
    assert pos == len(packed)
    return len(packed), sum(field == sentinel for field in fields)


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
    gamma = torch.tensor(prior['new_group_affine_bf16'],dtype=torch.bfloat16).float()
    train = parent.image(layer,'train',8,weights,gamma,nibble)
    held = parent.image(layer,'validation',4,weights,gamma,nibble)
    tr = parent.differences(train,32)
    hd = parent.differences(held,32)
    configs = ((8,4,1,True),(7,5,2,False),(6,6,2,False),(5,7,2,False),(4,8,2,False))
    outputs = {}
    for segments, maximum, directory_width, limited in configs:
        name = f'{segments}x{maximum}'
        window = np.zeros(4,dtype=np.int64)
        train_cost = 0
        edges = []
        stream_hash = hashlib.sha256()
        observed_maximum = 0
        for g in range(8):
            histogram = np.bincount((tr[:,g]+15).ravel(),minlength=31)
            if limited:
                _,_,lengths,mapping = bounded_key.bounded(histogram,15)
            else:
                lengths,mapping = parent.entropy.canonical(histogram)
            train_bytes = segment_bytes(tr[:,g].reshape(-1,31,32),np.asarray(lengths))
            held_bytes = segment_bytes(hd[:,g],np.asarray(lengths))
            cost, partition = optimum(train_bytes,segments,maximum)
            train_cost += cost
            edges.append(partition)
            for w in range(4):
                for b in range(8):
                    start = 0
                    for end in partition:
                        piece = hd[w,g,b,start:end]
                        raw = parent.entropy.roundtrip((piece+15).ravel(),mapping)
                        assert len(raw) == held_bytes[start,end][w,b]
                        if w == 0 and b == 0:
                            assert np.array_equal(parent.decode(raw,mapping,piece.size).reshape(piece.shape),piece)
                        stream_hash.update(raw)
                        window[w] += len(raw)
                        observed_maximum = max(observed_maximum,len(raw))
                        start = end
            assert start == 31
        # Each group's partition has `segments-1` five-bit boundaries. The
        # decoder shares them across all blocks, not a per-token partition.
        boundary_bytes = (8*(segments-1)*5+7)//8
        table_bytes = (8*31*5+7)//8
        window += 8*8*(20+directory_width*(segments-1))
        total = int(window.sum())+table_bytes+boundary_bytes
        outputs[name] = {'partition_per_group':edges,'train_payload_bytes':train_cost,
                         'per_window_bytes':window.tolist(),'table_bytes':table_bytes,
                         'partition_bytes':boundary_bytes,'total_bytes':total,
                         'bytes_per_token':total/1024,'observed_max_segment_bytes':observed_maximum,
                         'max_serial_symbols':32*maximum,'directory_bytes_per_block':directory_width*(segments-1),
                         'stream_sha256':stream_hash.hexdigest()}
    # Fixed boundaries remove the partition table. Inline extension words sit
    # directly before an exceptional segment; preceding segments never move.
    fixed = {}
    for rows, field_bits in ((4,6),(4,7),(4,9),(8,7),(8,8),(8,10),(16,8),(16,11)):
        name = f'{rows}-row-{field_bits}-bit'
        windows = np.zeros(4,dtype=np.int64)
        escapes = np.zeros(4,dtype=np.int64)
        max_seen = 0
        stream_hash = hashlib.sha256()
        for g in range(8):
            histogram = np.bincount((tr[:,g]+15).ravel(),minlength=31)
            lengths,mapping = parent.entropy.canonical(histogram)
            parts = segment_bytes(hd[:,g],np.asarray(lengths))
            for w in range(4):
                for b in range(8):
                    chunks = []
                    for start in range(0,31,rows):
                        end = min(start+rows,31)
                        piece = hd[w,g,b,start:end]
                        raw = parent.entropy.roundtrip((piece+15).ravel(),mapping)
                        assert len(raw) == parts[start,end][w,b]
                        if w == 0 and b == 0:
                            assert np.array_equal(parent.decode(raw,mapping,piece.size).reshape(piece.shape),piece)
                        stream_hash.update(raw)
                        chunks.append(raw)
                        max_seen = max(max_seen,len(raw))
                    encoded_bytes, exceptional = record(chunks,field_bits)
                    windows[w] += 20 + encoded_bytes
                    escapes[w] += exceptional
        segment_count = (30+rows)//rows
        directory_bytes = (field_bits*(segment_count-1)+7)//8
        total = int(windows.sum())+155
        fixed[name] = {'rows_per_segment':rows,'field_bits':field_bits,
                       'directory_bytes_per_block':directory_bytes,
                       'max_serial_symbols':32*rows,'max_observed_segment_bytes':max_seen,
                       'per_window_exceptions':escapes.tolist(),'per_window_bytes':windows.tolist(),
                       'total_bytes':total,'bytes_per_token':total/1024,
                       'stream_sha256':stream_hash.hexdigest()}
    result = {'layer':layer,'restart':32,'train_windows':8,'held_windows':4,'configs':outputs,
              'fixed_directory':fixed,
              'source_sha256':parent.sha(Path(__file__)),
              'parent_source_sha256':parent.sha(ROOT/'key-length-bounded/measure.py'),
              'model_sha256':parent.sha(parent.finite.MODEL),
              'capture_sha256':parent.sha(parent.finite.value_fit.CAPTURES/f'{suffix}.npz'),
              'nibble_sha256':parent.sha(nibble_path),'prior_sha256':parent.sha(prior_path),
              'paid_q_sha256':parent.sha(q_path),'paid_k_sha256':parent.sha(k_path)}
    out = DATA/f'key-segment-frontier/{suffix}.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'layer':layer,'partition_rates':{name:r['bytes_per_token'] for name,r in outputs.items()},
                      'fixed_rates':{name:r['bytes_per_token'] for name,r in fixed.items()},
                      'exceptions':{name:sum(r['per_window_exceptions']) for name,r in fixed.items()}}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer',type=int,choices=(0,14),required=True)
    run(parser.parse_args().layer)
