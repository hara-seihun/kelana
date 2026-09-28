#!/usr/bin/env python3
"""Price a two-bit independently parsed temporal key-score carrier."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parent.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
spec = importlib.util.spec_from_file_location('parallel', ROOT/'key-delta-parallel/measure.py')
parallel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parallel)
paid, finite = parallel.paid, parallel.finite
ALPHABET = (-1, 0, 1)


def encode(block):
    anchor = bytes((block[0][j]+7) | ((block[0][j+1]+7)<<4) for j in range(0,32,2))
    rows, escapes, state = bytearray(), bytearray(), (0,0)
    for t in range(1,32):
        word = 0
        for j in range(32):
            d = block[t][j] - block[t-1][j]
            symbol = ALPHABET.index(d) if d in ALPHABET else 3
            word |= symbol << (2*j)
            if symbol == 3:
                state = parallel.append_bits(escapes, d+14, 5, state)
        rows.extend(word.to_bytes(8,'little'))
    if state[1]:
        escapes.append(state[0])
    return anchor, bytes(rows), bytes(escapes)


def decode(anchor, rows, escapes):
    first = [((v>>shift)&15)-7 for v in anchor for shift in (0,4)]
    symbols = [[(int.from_bytes(rows[8*t:8*t+8],'little')>>(2*j))&3 for j in range(32)] for t in range(31)]
    masks = [sum((s==3)<<j for j,s in enumerate(row)) for row in symbols]
    prefix = parallel.inclusive_warp_scan([0]+[m.bit_count() for m in masks])
    assert len(escapes) == (5*prefix[-1]+7)//8
    delta = [[0]*32]
    for lane in range(1,32):
        mask = masks[lane-1]
        delta.append([parallel.bits_at(escapes,5*(prefix[lane-1]+(mask&((1<<j)-1)).bit_count()),5)-14 if s==3 else ALPHABET[s] for j,s in enumerate(symbols[lane-1])])
    codes = [first]
    for row in delta[1:]:
        codes.append([a+b for a,b in zip(codes[-1],row)])
    return delta,codes,prefix[-1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--layer',type=int,choices=(0,14),required=True)
    ap.add_argument('--output',type=Path,required=True)
    args = ap.parse_args()
    torch.set_num_threads(4)
    suffix = f'layer{args.layer:02d}'
    nibble_path = DATA/f'key-nibble-cache/{suffix}.json'
    prior_path = DATA/f'paid-qk-cache-slack/{suffix}.json'
    k_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    nibble,prior = json.loads(nibble_path.read_text()),json.loads(prior_path.read_text())
    with safe_open(finite.MODEL,framework='pt',device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        weights = {n:model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj','k_proj','q_norm','k_norm')}
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'],dtype=torch.bfloat16).float()
    x = finite.load_capture(args.layer,'validation').reshape(4,256,1024)
    _,k = paid.projected(x,weights,gamma)
    codes = []
    for group,row in enumerate(nibble['groups']):
        idx = row['mask']+[i+64 for i in row['mask']]
        selected = nibble['group_arms_selected_by_train']['coordinate'][group]
        arm = row['int4'][selected+'_coordinate']
        center = torch.tensor(row['train_center']).reshape(1,1,1,32) if selected=='centered' else 0
        step = torch.tensor(arm['steps']).reshape(1,1,1,32)
        codes.append(((k[:,group:group+1,:,idx]-center)/step).round().clamp(-7,7).to(torch.int32))
    c = torch.cat(codes,1)
    window_receipts = []
    payload = hashlib.sha256()
    hist = [0]*29
    by_group = [[0]*29 for _ in range(8)]
    max_real_error = 0.
    for w in range(4):
        size, count, block_min, block_max = 0,0,10**9,0
        for g in range(8):
            for b in range(8):
                original = c[w,g,32*b:32*b+32].tolist()
                anchor,rows,esc = encode(original)
                for t in range(1,32):
                    for j in range(32):
                        d = original[t][j]-original[t-1][j]
                        hist[d+14] += 1
                        by_group[g][d+14] += 1
                delta,decoded,n = decode(anchor,rows,esc)
                assert decoded == original and len(rows)==248 and len(anchor)==16
                for query in tuple((j-15.5)/17 for j in range(32)), tuple(math.cos(j) for j in range(32)):
                    direct = [sum(a*v for a,v in zip(query,row)) for row in original]
                    base = sum(a*v for a,v in zip(query,original[0]))
                    scanned = [base+sum(sum(a*v for a,v in zip(query,row)) for row in delta[1:t+1]) for t in range(32)]
                    max_real_error = max(max_real_error,max(abs(a-b) for a,b in zip(direct,scanned)))
                payload.update(anchor+rows+esc)
                block_size = len(anchor)+len(rows)+len(esc)+4
                size += block_size
                count += n
                block_min = min(block_min,n)
                block_max = max(block_max,n)
        window_receipts.append({'window':w,'bytes_including_offsets':size,'escapes':count,'min_block_escapes':block_min,'max_block_escapes':block_max})
    old_path = DATA/f'key-delta-parallel/{suffix}.json'
    old = json.loads(old_path.read_text())
    total = sum(x['bytes_including_offsets'] for x in window_receipts)
    best_global = sum(hist)-sum(sorted(hist,reverse=True)[:3])
    best_group = sum(sum(row)-sum(sorted(row,reverse=True)[:3]) for row in by_group)
    assert best_global == sum(x['escapes'] for x in window_receipts)
    report = {'layer':args.layer,'blocked_delta_histogram_minus14_to_plus14':hist,
        'best_global_three_escape_count':best_global,'best_group_three_escape_count':best_group,
        'contract':'Frozen paid Q/K signed-nibble key codes on four inspected 256-token original-producer validation windows; fixed two-bit delta alphabet, five-bit escaped signed differences, 32-key restarts and four-byte offsets',
        'alphabet':ALPHABET,'bytes_including_offsets':total,'bytes_per_token':total/1024,'escapes':sum(x['escapes'] for x in window_receipts),
        'three_bit_control_bytes':old['bytes_including_offsets'],'static_mixed_bytes':114688,'nibble_bytes':131072,
        'max_real_score_error_two_deterministic_queries':max_real_error,'payload_concat_sha256':payload.hexdigest(),'windows':window_receipts,
        'source_sha256':parallel.hash_file(Path(__file__)),'parallel_receipt_sha256':parallel.hash_file(old_path),'nibble_receipt_sha256':parallel.hash_file(nibble_path),'prior_sha256':parallel.hash_file(prior_path),'paid_k_sha256':parallel.hash_file(k_path),'model_sha256':parallel.hash_file(finite.MODEL),'capture_sha256':parallel.hash_file(finite.value_fit.CAPTURES/f'{suffix}.npz')}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'layer':args.layer,'bytes':total,'prior':old['bytes_including_offsets'],'escapes':report['escapes'],'max_real_error':max_real_error,'windows':window_receipts}))

if __name__=='__main__':
    main()
