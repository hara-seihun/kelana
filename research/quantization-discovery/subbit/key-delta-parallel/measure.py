#!/usr/bin/env python3
"""Split fixed-width delta symbols from escapes, then scan scores in 32 lanes."""
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
spec = importlib.util.spec_from_file_location('delta_score', ROOT/'key-delta-score/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
paid, finite = parent.paid, parent.finite


def hash_file(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def append_bits(out, value, width, state):
    byte, used = state
    for bit in range(width):
        byte |= ((value >> bit) & 1) << used
        used += 1
        if used == 8:
            out.append(byte)
            byte, used = 0, 0
    return byte, used


def bits_at(data, bit, width):
    i = bit // 8
    return (int.from_bytes(data[i:i+3], 'little') >> (bit % 8)) & ((1 << width)-1)


def inclusive_warp_scan(values):
    values = list(values)
    for offset in (1, 2, 4, 8, 16):
        prev = values[:]
        for lane in range(offset, 32):
            values[lane] += prev[lane-offset]
    return values


def encode(block):
    """32x32 integer codes; row-aligned fixed symbols and one block escape stream."""
    assert len(block) == 32 and all(len(row) == 32 for row in block)
    assert all(-7 <= v <= 7 for row in block for v in row)
    anchor = bytes(((v+7) | ((row[j+1]+7)<<4)) for row in [block[0]] for j,v in enumerate(row) if j % 2 == 0)
    base = bytearray()
    escapes = bytearray()
    esc_state = (0, 0)
    for key in range(1, 32):
        symbols = 0
        for coord in range(32):
            d = block[key][coord] - block[key-1][coord]
            esc = abs(d) > 3
            symbols |= (7 if esc else d+3) << (3*coord)
            if esc:
                esc_state = append_bits(escapes, d+14, 5, esc_state)
        base.extend(symbols.to_bytes(12, 'little'))
    if esc_state[1]:
        escapes.append(esc_state[0])
    return anchor, bytes(base), bytes(escapes)


def decode(anchor, base, escapes):
    assert len(anchor) == 16 and len(base) == 372
    first = [((v >> shift) & 15)-7 for v in anchor for shift in (0,4)]
    masks = []
    symbols = []
    for key in range(31):
        packed = int.from_bytes(base[12*key:12*(key+1)], 'little')
        row = [(packed >> (3*j)) & 7 for j in range(32)]
        symbols.append(row)
        masks.append(sum((s == 7) << j for j,s in enumerate(row)))
    counts = [0] + [m.bit_count() for m in masks]
    prefix = inclusive_warp_scan(counts)
    assert len(escapes) == (5*prefix[-1]+7)//8
    delta = [[0]*32]
    for lane in range(1, 32):
        mask = masks[lane-1]
        row = []
        for coord,s in enumerate(symbols[lane-1]):
            index = prefix[lane-1] + (mask & ((1 << coord)-1)).bit_count()
            row.append(bits_at(escapes, 5*index, 5)-14 if s == 7 else s-3)
        delta.append(row)
    codes = [first]
    for row in delta[1:]:
        codes.append([a+b for a,b in zip(codes[-1], row)])
    return delta, codes, prefix[-1]


def score_scan(delta, anchor, query):
    """Real-score map via a five-stage inclusive scan; FP32 has another reduction tree."""
    values = (torch.tensor(delta, dtype=torch.float32)*query).sum(-1)
    for offset in (1, 2, 4, 8, 16):
        previous = values.clone()
        values[offset:] = previous[offset:] + previous[:-offset]
    base = (torch.tensor(anchor, dtype=torch.float32)*query).sum()
    return base + values


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--layer', type=int, choices=(0,14), required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    torch.set_num_threads(4)
    suffix = f'layer{args.layer:02d}'
    nibble_path = DATA/f'key-nibble-cache/{suffix}.json'
    prior_path = DATA/f'paid-qk-cache-slack/{suffix}.json'
    q_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    nibble = json.loads(nibble_path.read_text())
    prior = json.loads(prior_path.read_text())
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        weights = {n:model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj','k_proj','q_norm','k_norm')}
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    x = finite.load_capture(args.layer, 'validation').reshape(4,256,1024)
    q,k = paid.projected(x, weights, gamma)
    codes, queries = [], []
    for group,row in enumerate(nibble['groups']):
        idx = row['mask'] + [i+64 for i in row['mask']]
        selected = nibble['group_arms_selected_by_train']['coordinate'][group]
        arm = row['int4'][selected+'_coordinate']
        center = torch.tensor(row['train_center']).reshape(1,1,1,32) if selected == 'centered' else 0
        step = torch.tensor(arm['steps']).reshape(1,1,1,32)
        codes.append(((k[:,group:group+1,:,idx]-center)/step).round().clamp(-7,7).to(torch.int32))
        queries.append(q[:,2*group:2*group+2,:,idx]*step)
    c = torch.cat(codes,1)
    query = torch.cat(queries,1)
    nesc, total_bytes, max_err, total_kl, nrows = 0, 0, 0., 0., 0
    per_window = []
    payload_hash = hashlib.sha256()
    for w in range(4):
        window_bytes, window_esc, window_err, window_kl, window_rows = 0,0,0.,0.,0
        for g in range(8):
            blocks = []
            for b in range(8):
                block = c[w,g,32*b:32*(b+1)].tolist()
                anchor,base,esc = encode(block)
                delta,decoded,count = decode(anchor,base,esc)
                assert decoded == block
                assert count == sum(abs(block[t][j]-block[t-1][j])>3 for t in range(1,32) for j in range(32))
                payload_hash.update(anchor+base+esc)
                window_bytes += len(anchor)+len(base)+len(esc)+4
                window_esc += count
                blocks.append((delta,block[0]))
            for h in range(2):
                for pos in (31,63,127,255):
                    u = query[w,2*g+h,pos].float()
                    pieces = [score_scan(delta,anchor,u) for delta,anchor in blocks]
                    scanned = torch.cat(pieces)[:pos+1]
                    direct = (c[w,g,:pos+1].float()*u).sum(-1)
                    window_err = max(window_err,float((direct-scanned).abs().max()))
                    a = (direct.double()/math.sqrt(128)).log_softmax(-1)
                    b = (scanned.double()/math.sqrt(128)).log_softmax(-1)
                    window_kl += float((a.exp()*(a-b)).sum())
                    window_rows += 1
        per_window.append({'window':w,'bytes_including_offsets':window_bytes,'escapes':window_esc,
                           'sampled_rows':window_rows,'max_fp32_score_difference':window_err,
                           'mean_direct_to_scan_softmax_kl':window_kl/window_rows})
        nesc += window_esc
        total_bytes += window_bytes
        max_err = max(max_err,window_err)
        total_kl += window_kl
        nrows += window_rows
    predecessor = json.loads((DATA/f'key-delta-score/{suffix}.json').read_text())
    assert total_bytes == predecessor['bytes']['delta_aligned_plus_four_byte_offsets']
    assert nesc == predecessor['escapes']
    report = {'layer':args.layer,'contract':'Four repeatedly inspected 256-token original-producer validation windows; frozen paid Q/K and signed-nibble codes, 32-key blocks; split fixed three-bit delta rows and five-bit escape side stream; FP32 Hillis-Steele score scan versus direct per-key FP32 dots',
              'bytes_including_offsets':total_bytes,'bytes_per_token':total_bytes/1024,
              'escape_count':nesc,'payload_concat_sha256':payload_hash.hexdigest(),
              'static_mixed_bytes':114688,'parallel_scan_stages':5,'max_fp32_score_difference':max_err,
              'mean_direct_to_scan_softmax_kl':total_kl/nrows,'windows':per_window,
              'source_sha256':hash_file(Path(__file__)),'parent_source_sha256':hash_file(ROOT/'key-delta-score/measure.py'),
              'parent_receipt_sha256':hash_file(DATA/f'key-delta-score/{suffix}.json'),
              'model_sha256':hash_file(finite.MODEL),'capture_sha256':hash_file(finite.value_fit.CAPTURES/f'{suffix}.npz'),
              'paid_q_sha256':hash_file(q_path),'paid_k_sha256':hash_file(k_path),
              'nibble_receipt_sha256':hash_file(nibble_path),'prior_sha256':hash_file(prior_path)}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'layer':args.layer,'bytes':total_bytes,'escapes':nesc,'max_score_difference':max_err,'mean_kl':total_kl/nrows}))

if __name__ == '__main__':
    main()
