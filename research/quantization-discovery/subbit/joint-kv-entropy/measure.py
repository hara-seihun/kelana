#!/usr/bin/env python3
"""Price a cross-K/V temporal side-information code on frozen paid Qwen caches."""
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
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


key = module('key_entropy', ROOT/'key-entropy-direct/measure.py')
value = module('value_entropy', ROOT/'value-entropy-ceiling/measure.py')


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def value_codes(layer):
    image = value.IMAGE/f'layer{layer:02d}-joint-r28.npz'
    parent = value.PARENT/f'layer{layer:02d}-8x4.json'
    selected = json.loads(parent.read_text())['selected']
    decoder = module('paid_factor_decode', value.SOURCE)
    with np.load(image) as factor:
        right = [decoder.decode({name:factor[name][g].copy() for name in factor.files}, 'right') for g in range(8)]
    steps = [s['steps'] for s in selected]
    lows = [s['lows'] for s in selected]
    return (value.codes(layer,'train',right,steps,lows,8),
            value.codes(layer,'validation',right,steps,lows,4),[image,parent])


def key_codes(layer):
    suffix = f'layer{layer:02d}'
    nibble_path = key.DATA/f'key-nibble-cache/{suffix}.json'
    prior_path = key.DATA/f'paid-qk-cache-slack/{suffix}.json'
    q_path = key.DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_q_proj.npz'
    k_path = key.DATA/f'full-model/image-binary055-refined/{suffix}-self_attn_k_proj.npz'
    nibble = json.loads(nibble_path.read_text())
    prior = json.loads(prior_path.read_text())
    with safe_open(key.finite.MODEL,framework='pt',device='cpu') as model:
        prefix = f'model.layers.{layer}.self_attn.'
        weights = {name:model.get_tensor(prefix+name+'.weight').float() for name in ('q_proj','k_proj','q_norm','k_norm')}
    weights['q_proj'] = key.paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = key.paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(prior['new_group_affine_bf16'],dtype=torch.bfloat16).float()
    return (key.image(layer,'train',8,weights,gamma,nibble).transpose(0,2,1,3),
            key.image(layer,'validation',4,weights,gamma,nibble).transpose(0,2,1,3),
            [nibble_path,prior_path,q_path,k_path])


def differences(c, block):
    c = c.reshape(c.shape[0],256//block,block,8,c.shape[-1]).astype(np.int16)
    return c[:,:,1:] - c[:,:,:-1]


def entropy(hist):
    probs = hist[hist>0]/hist.sum()
    return float(-(probs*np.log2(probs)).sum())


def evaluate(train_target,held_target,train_side,held_side,block,mode):
    dt,dh = differences(train_target,block),differences(held_target,block)
    st,sh = differences(train_side,block),differences(held_side,block)
    target_width,side_width = dt.shape[-1],st.shape[-1]
    # A local side symbol needs no extra cache bytes; both caches are already present.
    # A zero/nonzero side difference is independently available after its own stream is read.
    ti = np.arange(target_width)
    si = ti % side_width
    if mode == 'same-coordinate':
        tr = st[...,si] == 0
        he = sh[...,si] == 0
    elif mode == 'group-quiet':
        tr = np.count_nonzero(st,axis=-1)[...,None] < side_width//2
        he = np.count_nonzero(sh,axis=-1)[...,None] < side_width//2
        tr = np.broadcast_to(tr,dt.shape)
        he = np.broadcast_to(he,dh.shape)
    else:
        raise ValueError(mode)
    base_lengths=[]
    cond_lengths=[]
    mutual=[]
    total_base=total_cond=0
    window_base=np.zeros(4,dtype=np.int64)
    window_cond=np.zeros(4,dtype=np.int64)
    per_group=[]
    for g in range(8):
        a=dt[...,g,:].ravel()+15
        b=dh[...,g,:].ravel()+15
        x=tr[...,g,:].ravel().astype(np.int8)
        y=he[...,g,:].ravel().astype(np.int8)
        base_hist=np.bincount(a,minlength=31)
        base=value.canonical(base_hist)[0]
        cond=[value.canonical(np.bincount(a[x==z],minlength=31))[0] for z in (0,1)]
        base_lengths.append(base)
        cond_lengths.append(cond)
        joint=np.bincount(31*x+a,minlength=62).reshape(2,31)
        gain=entropy(base_hist)-sum(j.sum()/joint.sum()*entropy(j) for j in joint if j.sum())
        mutual.append(gain)
        # Independent key rows have one byte of length and byte alignment for each row.
        # The side condition is known to both ends; it never occupies this stream.
        bt=np.asarray(base,dtype=np.int16)[dh[...,g,:]+15].sum(axis=-1)
        ct=np.where(he[...,g,:],np.asarray(cond[1],dtype=np.int16)[dh[...,g,:]+15],
                    np.asarray(cond[0],dtype=np.int16)[dh[...,g,:]+15]).sum(axis=-1)
        base_bytes=(bt+7)//8
        cond_bytes=(ct+7)//8
        total_base+=int(base_bytes.sum())
        total_cond+=int(cond_bytes.sum())
        window_base+=base_bytes.sum(axis=(1,2))
        window_cond+=cond_bytes.sum(axis=(1,2))
        per_group.append({'group':g,'mutual_bits_per_symbol':gain,'base_payload_bytes':int(base_bytes.sum()),
                          'conditional_payload_bytes':int(cond_bytes.sum()),
                          'held_side_true_fraction':float(y.mean())})
    # Eight 31-entry five-bit tables for base, sixteen for conditional.
    table_base=(8*31*5+7)//8
    table_cond=(16*31*5+7)//8
    anchors_offsets_lengths=4*8*(256//block)*(16+4+block-1) if target_width==32 else 4*8*(256//block)*(14+4+block-1)
    return {'mode':mode,'restart':block,'target_width':target_width,
            'baseline_total_bytes':total_base+table_base+anchors_offsets_lengths,
            'conditional_total_bytes':total_cond+table_cond+anchors_offsets_lengths,
            'payload_base_bytes':total_base,'payload_conditional_bytes':total_cond,
            'extra_table_bytes':table_cond-table_base,'mutual_bits_per_symbol_by_group':mutual,
            'per_window_payload_bytes':[{'base':int(b),'conditional':int(c)} for b,c in zip(window_base,window_cond)],
            'per_group':per_group,'train_base_code_lengths':base_lengths,
            'train_conditional_code_lengths':cond_lengths}


def run(layer):
    torch.set_num_threads(4)
    kt,kh,kpaths=key_codes(layer)
    vt,vh,vpaths=value_codes(layer)
    assert kt.shape[:3]==vt.shape[:3] == (8,256,8)
    rows=[]
    for block in (32,256):
        for target,train,held,side_train,side_held in [('K',kt,kh,vt,vh),('V',vt,vh,kt,kh)]:
            for mode in ('same-coordinate','group-quiet'):
                row=evaluate(train,held,side_train,side_held,block,mode)
                row['target']=target
                rows.append(row)
    output={'layer':layer,'contract':'Frozen paid Q/K and rank-28 V/O, same eight original-producer train and four inspected validation windows. Two conditional canonical Huffman tables per KV group using contemporaneous other-cache temporal difference as side information; one independently decodable row per key, with anchors, four-byte block offsets, one-byte row lengths and exact byte rounding. This is a cache-rate experiment, not a weight-rate, latency, or quality change.',
            'shapes':{'K':list(kh.shape),'V':list(vh.shape)},'rows':rows,
            'hashes':{str(path):sha(path) for path in [Path(__file__),key.finite.MODEL,key.finite.value_fit.CAPTURES/f'layer{layer:02d}.npz',*kpaths,*vpaths]}}
    out=DATA/'joint-kv-entropy'/f'layer{layer:02d}.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({'layer':layer,'rows':[(r['target'],r['restart'],r['mode'],r['baseline_total_bytes'],r['conditional_total_bytes']) for r in rows]}))


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--layer',type=int,choices=(0,14),required=True)
    run(parser.parse_args().layer)
