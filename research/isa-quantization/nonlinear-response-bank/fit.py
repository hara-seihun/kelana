#!/usr/bin/env python3
"""Ridge-correct a source-channel nonlinear bank and test held full MLP output."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
RIDGES=(0.,.01,.1,1.,10.,100.,1000.,10000.,100000.,1000000.)


def load(split):
    chunks=[np.load(HERE/f'{split}-{i}.npz') for i in range(4)]
    return {key:np.concatenate([c[key] for c in chunks]).astype(np.float64)
            for key in ('inputs','hidden','target','q4')}


def relative(pred,true):
    return float(np.linalg.norm(pred-true)/np.linalg.norm(true))


def solve(features,target,prior,alpha):
    mu=features.mean(0)
    scale=np.sqrt(np.mean((features-mu)**2,axis=0))
    a=(features-mu)/scale
    target_center=target-target.mean(0)
    regularization_target=prior*scale[:,None]
    gram=a.T@a
    right=a.T@target_center
    eigen,vec=np.linalg.eigh(gram)
    residual=right-gram@regularization_target
    rotated=vec.T@residual
    return dict(mu=mu,scale=scale,eigen=eigen,vec=vec,rotated=rotated,
                baseline=regularization_target,target_mean=target.mean(0))


def readout(state,alpha):
    delta=state['vec']@(state['rotated']/np.maximum(1e-8,state['eigen'][:,None]+alpha))
    weights=(state['baseline']+delta)/state['scale'][:,None]
    bias=state['target_mean']-state['mu']@weights
    return weights,bias


def predict(hidden,weights,bias):
    return hidden@weights+bias


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--rank',type=int,choices=(640,768,784,788),required=True)
    args=p.parse_args()
    k=args.rank
    train,held=load('train'),load('held')
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        down=f.get_tensor('model.layers.0.mlp.down_proj.weight').float().numpy().astype(np.float64)
    h=train['hidden']
    scores=np.linalg.norm(h-h.mean(0),axis=0)*np.linalg.norm(down,axis=0)
    selected=np.argsort(-scores,kind='stable')[:k]
    prior=down[:,selected].T.copy()
    tr=train['hidden'][:,selected]
    hv=held['hidden'][:,selected]
    internal=solve(tr[:768],train['target'][:768],prior,0.)
    cv={}
    for lam in RIDGES:
        weights,bias=readout(internal,lam)
        cv[str(lam)]=relative(predict(tr[768:],weights,bias),train['target'][768:])
    chosen=min(RIDGES,key=lambda lam:(cv[str(lam)],lam))
    state=solve(tr,train['target'],prior,chosen)
    records={}
    for lam in RIDGES:
        w,b=readout(state,lam)
        w=w.astype(np.float16).astype(np.float64)
        b=b.astype(np.float16).astype(np.float64)
        records[str(lam)]=dict(train=relative(predict(tr,w,b),train['target']),
                               held=relative(predict(hv,w,b),held['target']))
    # The stored image is the train-selected ridge, not the best choice on held.
    w,b=readout(state,chosen)
    w16=w.astype(np.float16)
    b16=b.astype(np.float16)
    q4_held=relative(held['q4'],held['target'])
    result=dict(rank=k,selection='top train-centered hidden norm times exact BF16 down-column norm',
                internal_train_states=768,internal_check_states=256,held_states=1024,
                ridge_values=list(RIDGES),internal_rms=cv,chosen_ridge=chosen,
                rounded_full_train_and_held=records,held_scalar_q4=q4_held,
                feature_ids_bytes=2*k,gate_up_bf16_bytes=4*k*1024,
                readout_fp16_bytes=2*k*1024,readout_bias_fp16_bytes=2048,
                total_image_bytes=6144*k+2*k+2048+7,
                selected_ids_sha256=hashlib.sha256(selected.astype('<u2').tobytes()).hexdigest(),
                stored_image=None)
    if records[str(chosen)]['held']<q4_held:
        with safe_open(MODEL,framework='pt',device='cpu') as f:
            gate=f.get_tensor('model.layers.0.mlp.gate_proj.weight')[selected].float().numpy().astype(np.float32)
            up=f.get_tensor('model.layers.0.mlp.up_proj.weight')[selected].float().numpy().astype(np.float32)
        bits=lambda matrix:(matrix.view(np.uint32)>>16).astype('<u2').tobytes()
        image=(b'NLRB1'+struct.pack('<H',k)+selected.astype('<u2').tobytes()+bits(gate)+bits(up)
               +w16.T.astype('<f2').tobytes()+b16.astype('<f2').tobytes())
        path=HERE/f'bank-{k}.bin'
        path.write_bytes(image)
        assert len(image)==result['total_image_bytes']
        result['stored_image']=dict(path=str(path),sha256=hashlib.sha256(image).hexdigest(),bytes=len(image))
    (HERE/f'fit-{k}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(dict(rank=k,chosen=chosen,cv=cv,full=records[str(chosen)],q4_held=q4_held,
                          image=result['stored_image'])),flush=True)


if __name__=='__main__':main()
