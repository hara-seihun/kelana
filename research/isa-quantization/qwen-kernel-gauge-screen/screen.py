"""Train-defined shared GQA score-row gauge, geometry only; no feature fit."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
CENTER=HERE/'train-causal-pair-center-f64.npy'

def source():
    torch.set_num_threads(1)
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        q=f.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float()
        k=f.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        qgamma=f.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma=f.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    spec=importlib.util.spec_from_file_location('original_kernel_geometry',ROOT/'attention-consumer/measure.py')
    consumer=importlib.util.module_from_spec(spec);spec.loader.exec_module(consumer)
    return q,k,qgamma,kgamma,consumer

def rotated(x,weights):
    q,k,qgamma,kgamma,consumer=weights
    x=torch.from_numpy(x.astype(np.float32))
    with torch.no_grad():
        queries=[(consumer.rope(consumer.normalized((x@q[j*128:(j+1)*128].T).to(torch.bfloat16).float(),qgamma)).numpy()*128**-.25).astype(np.float64) for j in range(2)]
        key=(consumer.rope(consumer.normalized((x@k.T).to(torch.bfloat16).float(),kgamma)).numpy()*128**-.25).astype(np.float64)
    return queries,key

def center():
    weights=source()
    with np.load(FIX) as f:
        train=f['train'].reshape(8,256,1024)
        original=f['weight'][:128].astype(np.float32)
    assert np.array_equal(original,weights[0][:128].numpy())
    counts=np.arange(1,257,dtype=np.float64)
    reverse=np.arange(256,0,-1,dtype=np.float64)
    total=np.zeros((128,),dtype=np.float64)
    for window in train:
        queries,key=rotated(window,weights)
        total+=np.sum(queries[0]*counts[:,None],axis=0)
        total+=np.sum(queries[1]*counts[:,None],axis=0)
        total+=2*np.sum(key*reverse[:,None],axis=0)
    c=total/(2*8*256*257/2)
    np.save(CENTER,c)
    metadata={'fixture_sha256':'389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f',
        'center_sha256':hashlib.sha256(CENTER.read_bytes()).hexdigest(),
        'weighting':'uniform across two GQA query heads, eight 256-position train windows, all 32896 causal (query,key) pairs per head/window',
        'center_squared_norm':float(c@c),'center_max_abs':float(np.max(np.abs(c)))}
    (HERE/'center.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps(metadata,indent=2))

def stats(values):
    return {'min':float(np.min(values)),'p05':float(np.quantile(values,.05)),
        'median':float(np.median(values)),'p95':float(np.quantile(values,.95)),
        'max':float(np.max(values)),'mean':float(np.mean(values))}

def inspect(panel,index):
    assert panel in ('train','held')
    metadata=json.loads((HERE/'center.json').read_text())
    assert hashlib.sha256(CENTER.read_bytes()).hexdigest()==metadata['center_sha256']
    c=np.load(CENTER).astype(np.float64)
    with np.load(FIX) as f:
        x=f['train' if panel=='train' else 'validation']
        assert index in range(len(x)//256)
        window=x[256*index:256*(index+1)].copy()
    queries,key=rotated(window,source())
    key_norm=np.sum(key*key,axis=1)
    centered_key_norm=np.sum((key-c)**2,axis=1)
    causal=np.tril(np.ones((256,256),bool))
    result={'panel':panel,'window':index,'center_sha256':metadata['center_sha256'],
            'key_squared_norm':stats(key_norm),'centered_key_squared_norm':stats(centered_key_norm),'heads':{}}
    for head,q in enumerate(queries):
        qnorm=np.sum(q*q,axis=1)
        score=q@key.T
        original=qnorm[:,None]+key_norm[None,:]+2*score
        centered=qnorm[:,None]+centered_key_norm[None,:]+2*(score-(q@c)[:,None])
        assert np.min(original[causal])>=-1e-8 and np.min(centered[causal])>=-1e-8
        # A shared key shift changes every score in the same query row by -q·c.
        row_bias=q@c
        shifted=score-row_bias[:,None]
        assert np.max(np.abs(shifted-score+row_bias[:,None]))<1e-9
        result['heads'][f'head{head}']={'query_squared_norm':stats(qnorm),
            'uncentered_exponent':stats(original[causal]),
            'train_centered_exponent':stats(centered[causal]),
            'score_row_gauge_max_abs':float(np.max(np.abs(row_bias)))}
    (HERE/f'{panel}-{index}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    if sys.argv[1]=='center':center()
    else:inspect(sys.argv[1],int(sys.argv[2]))
