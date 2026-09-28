#!/usr/bin/env python3
"""Fit finite three-bit K-difference alphabets and price direct-score streams."""
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
spec = importlib.util.spec_from_file_location('key_entropy_direct', ROOT/'key-entropy-direct/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)


def sha(path):
    with open(path, 'rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def alphabet(hist):
    # Every direct symbol saves exactly five escape bits. Stable signed-value
    # tie breaking makes the finite optimum reproducible.
    return sorted(sorted(range(-14, 15), key=lambda d: (-int(hist[d+14]), d))[:7])


def put_bits(buf, value, width, bit):
    for j in range(width):
        if (value >> j) & 1:
            buf[(bit+j)//8] |= 1 << ((bit+j)%8)


def get_bits(buf, bit, width):
    return sum(((buf[(bit+j)//8] >> ((bit+j)%8)) & 1) << j for j in range(width))


def block_stream(block, alphabets, verify=True):
    """Pack 31 fixed twelve-byte rows and a five-bit block escape side stream."""
    delta = np.diff(block.astype(np.int16), axis=0)
    mapping = [{d:i for i,d in enumerate(row)} for row in alphabets]
    symbols = bytearray(31*12)
    escaped = []
    for t in range(31):
        for j in range(32):
            d = int(delta[t,j])
            label = mapping[j].get(d, 7)
            put_bits(symbols,label,3,96*t+3*j)
            if label == 7:
                escaped.append(d+14)
    escapes = bytearray((5*len(escaped)+7)//8)
    for i,value in enumerate(escaped):
        put_bits(escapes,value,5,5*i)
    if verify:
        again = np.empty((31,32),dtype=np.int16)
        n = 0
        for t in range(31):
            for j in range(32):
                s = get_bits(symbols,96*t+3*j,3)
                if s == 7:
                    again[t,j] = get_bits(escapes,5*n,5)-14
                    n += 1
                else:
                    again[t,j] = alphabets[j][s]
        assert n == len(escaped)
        assert np.array_equal(again,delta)
        reconstructed = block[0].astype(np.int16) + np.cumsum(again,axis=0)
        assert np.array_equal(reconstructed,block[1:])
        # The two-head direct-score scan needs no expanded absolute vector.
        queries = np.stack((np.arange(32)%11-5,5-np.arange(32)%9)).T.astype(np.int64)
        direct = block.astype(np.int64) @ queries
        scanned = direct[0] + np.cumsum(again.astype(np.int64) @ queries,axis=0)
        assert np.array_equal(scanned,direct[1:])
    return bytes(symbols),bytes(escapes),len(escaped)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--layer',type=int,choices=(0,14),required=True)
    args = ap.parse_args()
    torch.set_num_threads(4)
    layer = args.layer
    suffix = f'layer{layer:02d}'
    nibble_path = DATA/f'key-nibble-cache/{suffix}.json'
    prior_path = DATA/f'paid-qk-cache-slack/{suffix}.json'
    q_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    nibble = json.loads(nibble_path.read_text())
    prior = json.loads(prior_path.read_text())
    with safe_open(parent.finite.MODEL,framework='pt',device='cpu') as model:
        prefix = f'model.layers.{layer}.self_attn.'
        weights = {name:model.get_tensor(prefix+name+'.weight').float() for name in ('q_proj','k_proj','q_norm','k_norm')}
    weights['q_proj'] = parent.paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = parent.paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'],dtype=torch.bfloat16).float()
    train = parent.image(layer,'train',8,weights,gamma,nibble)
    held = parent.image(layer,'validation',4,weights,gamma,nibble)
    tr = parent.differences(train,32)
    hd = parent.differences(held,32)
    # Train-only exact optimum within each independent seven-symbol partition.
    alph = {}
    alph['uniform'] = [[list(range(-3,4)) for _ in range(32)] for _ in range(8)]
    alph['group'] = []
    alph['coordinate'] = []
    for g in range(8):
        x = tr[:,g]
        group_hist = np.bincount((x+14).ravel(),minlength=29)
        a = alphabet(group_hist)
        alph['group'].append([a[:] for _ in range(32)])
        alph['coordinate'].append([alphabet(np.bincount((x[...,j]+14).ravel(),minlength=29)) for j in range(32)])
    # Diagnostic only: grant the selector all four held windows, then even
    # waive its table and block-alignment charges for a grammar lower bound.
    oracle = []
    for g in range(8):
        x = hd[:,g]
        oracle.append([alphabet(np.bincount((x[...,j]+14).ravel(),minlength=29)) for j in range(32)])
    alph['held_oracle'] = oracle
    sizes = {'uniform':0,'group':8*7*5//8,'coordinate':8*32*7*5//8,'held_oracle':8*32*7*5//8}
    # Tables are bit-packed five-bit signed difference labels, not a free oracle.
    # 32 group codes cost 35 bytes; 256 coordinate codes cost 1120 bytes.
    assert sizes['group']==35 and sizes['coordinate']==1120
    records = {}
    for name,by_group in alph.items():
        per_window = []
        digest = hashlib.sha256()
        total_esc = 0
        for w in range(4):
            bytes_,esc = 0,0
            for g in range(8):
                for b in range(8):
                    block = held[w,g,b*32:(b+1)*32]
                    sym,payload,count = block_stream(block,by_group[g])
                    # One 16-byte anchor, one four-byte group block offset.
                    anchor = bytes((int(block[0,j])+7) | ((int(block[0,j+1])+7)<<4) for j in range(0,32,2))
                    digest.update(anchor+sym+payload)
                    bytes_ += 16+4+len(sym)+len(payload)
                    esc += count
            total_esc += esc
            per_window.append({'window':w,'bytes_excluding_table':bytes_,'escapes':esc})
        records[name] = {'table_bytes':sizes[name], 'bytes':sum(row['bytes_excluding_table'] for row in per_window)+sizes[name],
                         'escapes':total_esc,'per_window':per_window,'payload_sha256':digest.hexdigest()}
        records[name]['bytes_per_token'] = records[name]['bytes']/1024
    baseline = json.loads((DATA/f'key-delta-parallel/{suffix}.json').read_text())
    assert records['uniform']['bytes'] == baseline['bytes_including_offsets']
    assert records['uniform']['escapes'] == baseline['escape_count']
    # Minimum escape count for every *fixed*, seven-symbol per-coordinate
    # alphabet, even if it is chosen using held data. Discarding the table and
    # pooling all escape bits across block boundaries only helps this bound.
    oracle_escapes = records['held_oracle']['escapes']
    lower_bytes = 8*8*4*(16+4+31*12) + (5*oracle_escapes+7)//8
    result = {'layer':layer,'shape':list(held.shape),'alphabet':alph,'arms':records,
              'free_table_unaligned_oracle_lower_bytes':lower_bytes,
              'static_mixed_bytes':112*1024,'packed_four_row_huffman_bytes_per_token':116.172 if layer==0 else 96.837,
              'contract':'Eight train 256-token windows choose exact top-seven signed differences for each group or coordinate; four inspected 256-token validation windows hold fixed paid binary Q/K, mask, center and steps. Held-oracle is a diagnostic bound, not a deployable train choice. One 32-key absolute nibble anchor, 31 byte-aligned 96-bit symbol rows, a five-bit escape stream and a four-byte block offset per group/block. Five-bit alphabet metadata paid once per layer. Two-head integer score scan exact. Open-block append can add one row of fixed symbols and append escape bits to each group-local tail without relocating completed blocks. Reader still pays escape count scan, table lookup, difference dots, score scan, query prep, producer, softmax. No FP32 bit identity, native latency or model loss claimed.',
              'source_sha256':sha(Path(__file__)),'parent_source_sha256':sha(ROOT/'key-entropy-direct/measure.py'),
              'baseline_sha256':sha(DATA/f'key-delta-parallel/{suffix}.json'),
              'model_sha256':sha(parent.finite.MODEL),'capture_sha256':sha(parent.finite.value_fit.CAPTURES/f'{suffix}.npz'),
              'paid_q_sha256':sha(q_path),'paid_k_sha256':sha(k_path),'nibble_sha256':sha(nibble_path),'prior_sha256':sha(prior_path)}
    out = DATA/f'key-coordinate-alphabet/{suffix}.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'layer':layer,'rates':{k:v['bytes_per_token'] for k,v in records.items()},'escapes':{k:v['escapes'] for k,v in records.items()},'free_table_unaligned_lower_bytes_per_token':lower_bytes/1024},indent=2),flush=True)

if __name__=='__main__':
    main()
