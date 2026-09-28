#!/usr/bin/env python3
"""Train a lossless temporal key code and charge independently decodable streams."""
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
spec = importlib.util.spec_from_file_location('key_delta_parallel', ROOT/'key-delta-parallel/measure.py')
parent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parent)
spec = importlib.util.spec_from_file_location('value_entropy', ROOT/'value-entropy-ceiling/measure.py')
entropy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(entropy)
paid, finite = parent.paid, parent.finite


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def image(layer, split, windows, weights, gamma, nibble):
    x = finite.load_capture(layer, split).reshape(-1,256,1024)[:windows]
    _, k = paid.projected(x, weights, gamma)
    codes = []
    for group, row in enumerate(nibble['groups']):
        idx = row['mask'] + [i+64 for i in row['mask']]
        selected = nibble['group_arms_selected_by_train']['coordinate'][group]
        arm = row['int4'][selected+'_coordinate']
        center = torch.tensor(row['train_center']).reshape(1,1,1,32) if selected == 'centered' else 0
        step = torch.tensor(arm['steps']).reshape(1,1,1,32)
        codes.append(((k[:,group:group+1,:,idx]-center)/step).round().clamp(-7,7).to(torch.int8))
    return torch.cat(codes,1).numpy()


def differences(codes, restart):
    blocks = codes.reshape(codes.shape[0],8,256//restart,restart,32).astype(np.int16)
    return blocks[:,:,:,1:,:] - blocks[:,:,:,:-1,:]


def decode(raw, mapping, count):
    inverse = {(code,width):symbol-15 for symbol,(code,width) in mapping.items()}
    result = []
    code = width = 0
    for byte in raw:
        for shift in range(7,-1,-1):
            if len(result) == count:
                break
            code = 2*code + ((byte >> shift)&1)
            width += 1
            if (code,width) in inverse:
                result.append(inverse[code,width])
                code = width = 0
    assert len(result) == count
    return np.asarray(result,dtype=np.int16)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0,14), required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    layer = args.layer
    suffix = f'layer{layer:02d}'
    nibble_path = DATA/f'key-nibble-cache/{suffix}.json'
    prior_path = DATA/f'paid-qk-cache-slack/{suffix}.json'
    q_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    nibble = json.loads(nibble_path.read_text())
    prior = json.loads(prior_path.read_text())
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{layer}.self_attn.'
        weights = {name:model.get_tensor(prefix+name+'.weight').float() for name in ('q_proj','k_proj','q_norm','k_norm')}
    weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    train = image(layer,'train',8,weights,gamma,nibble)
    held = image(layer,'validation',4,weights,gamma,nibble)
    rows = []
    for restart in (32,256):
        tr = differences(train,restart)
        hd = differences(held,restart)
        tables = []
        for g in range(8):
            hist = np.bincount((tr[:,g]+15).ravel(),minlength=31)
            tables.append(entropy.canonical(hist))
        table_bytes = (8*31*5+7)//8
        group_bytes = 0
        coordinate_bytes = 0
        row_bytes = 0
        window_bytes = []
        stream_sha = hashlib.sha256()
        max_stream = 0
        max_row_stream = 0
        for w in range(4):
            group_window = coordinate_window = row_window = 0
            for g in range(8):
                mapping = tables[g][1]
                for b in range(256//restart):
                    block = held[w,g,b*restart:(b+1)*restart]
                    delta = hd[w,g,b]
                    group_stream = entropy.roundtrip((delta+15).ravel(),mapping)
                    stream_sha.update(group_stream)
                    group_window += 16 + 4 + len(group_stream)
                    row_window += 16 + 4 + (restart-1)  # byte lengths locate independent key rows
                    decoded_rows = []
                    for key in range(restart-1):
                        stream = entropy.roundtrip(delta[key]+15,mapping)
                        stream_sha.update(stream)
                        row_window += len(stream)
                        max_row_stream = max(max_row_stream,len(stream))
                        if w == 0 and b == 0:
                            decoded_rows.append(decode(stream,mapping,32))
                    if w == 0 and b == 0:
                        # Both heads consume decoded deltas directly. The integer score
                        # scan must agree for every key, not merely for a sampled logit.
                        two_queries = np.stack((np.arange(32)%11-5,5-np.arange(32)%9))
                        anchor = block[0].astype(np.int64) @ two_queries.T
                        scan = anchor + np.cumsum(np.stack(decoded_rows).astype(np.int64) @ two_queries.T,axis=0)
                        direct = block[1:].astype(np.int64) @ two_queries.T
                        assert np.array_equal(scan,direct)
                    coordinate_window += 16 + 4 + 32  # one byte length per independent coordinate
                    for c in range(32):
                        stream = entropy.roundtrip(delta[:,c]+15,mapping)
                        stream_sha.update(stream)
                        coordinate_window += len(stream)
                        max_stream = max(max_stream,len(stream))
                    assert np.array_equal(block[0].astype(np.int16) + np.cumsum(delta,axis=0),block[1:])
            group_bytes += group_window
            coordinate_bytes += coordinate_window
            row_bytes += row_window
            window_bytes.append({'window':w,'group_bytes':group_window,'row_bytes':row_window,'coordinate_bytes':coordinate_window})
        assert max_stream <= 255 and max_row_stream <= 255
        counts = np.bincount((hd+15).ravel(),minlength=31)
        probs = counts[counts>0]/counts.sum()
        rows.append({'restart':restart,'table_bytes':table_bytes,
                     'group_total_bytes':group_bytes+table_bytes,
                     'coordinate_total_bytes':coordinate_bytes+table_bytes,
                     'row_total_bytes':row_bytes+table_bytes,
                     'group_bytes_per_token':(group_bytes+table_bytes)/1024,
                     'row_bytes_per_token':(row_bytes+table_bytes)/1024,
                     'coordinate_bytes_per_token':(coordinate_bytes+table_bytes)/1024,
                     'entropy_bits_per_difference':float(-(probs*np.log2(probs)).sum()),
                     'max_coordinate_stream_bytes':max_stream,'max_row_stream_bytes':max_row_stream,'per_window':window_bytes,
                     'train_code_lengths':[t[0] for t in tables],
                     'streams_sha256':stream_sha.hexdigest()})
    result = {'layer':layer,'contract':'Eight train windows choose one canonical Huffman difference table per KV group; four repeatedly inspected original-producer validation windows; paid binary Q/K and frozen centered signed-nibble key codes. Exact byte-aligned streams, one absolute anchor and four-byte offset per group block, 31 five-bit lengths per table, and one byte per independent row or coordinate stream length. No online time measured.',
              'shape':list(held.shape),'static_mixed_bytes':112*1024,
              'three_bit_escape_bytes':json.loads((DATA/f'key-delta-parallel/{suffix}.json').read_text())['bytes_including_offsets'],
              'rows':rows,'source_sha256':sha(Path(__file__)),
              'model_sha256':sha(finite.MODEL),'capture_sha256':sha(finite.value_fit.CAPTURES/f'{suffix}.npz'),
              'nibble_sha256':sha(nibble_path),'prior_sha256':sha(prior_path),
              'paid_q_sha256':sha(q_path),'paid_k_sha256':sha(k_path)}
    out = DATA/f'key-entropy-direct/{suffix}.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'layer':layer,'rates':[(r['restart'],r['group_bytes_per_token'],r['row_bytes_per_token'],r['coordinate_bytes_per_token']) for r in rows]}),flush=True)


if __name__ == '__main__':
    main()
