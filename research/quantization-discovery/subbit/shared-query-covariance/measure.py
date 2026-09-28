#!/usr/bin/env python3
"""Frozen-key covariance coordinate descent for the shared two-head three-dot query."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('shared_query_base', ROOT/'shared-query-base/measure.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
cache, paid, finite, lowering = base.cache, base.paid, base.finite, base.lowering
DATA = Path('/path/to/workspace/data/kelana-subbit')


def covariance(codes):
    # A causal score can discard each prefix's common key translation.
    count = np.arange(1, codes.shape[1]+1)[None,:,None]
    mean = np.cumsum(codes,axis=1)/count
    outer = codes[:,:,:,None]*codes[:,:,None,:]
    prefix_outer = np.cumsum(outer,axis=1)/count[:,:,:,None]
    c = np.mean(prefix_outer - mean[:,:,:,None]*mean[:,:,None,:],axis=(0,1))
    c += np.eye(32) * (np.trace(c)/32 * 1e-8)
    return c


def fit(a0, a1, c, weight, sweeps):
    """Each coordinate update exactly minimizes the full correlated quadratic with others fixed."""
    d = np.maximum(np.max(np.abs(a0), axis=-1, keepdims=True), 1e-20)/119
    e = np.maximum(np.max(np.abs(a1-a0), axis=-1, keepdims=True), 1e-20)/7
    candidates = np.arange(-7,8).reshape((15,)+(1,)*a0.ndim)
    us = np.clip(np.rint((a0[None,...]+weight*(a1[None,...]-e[None,...]*candidates))/((1+weight)*d[None,...])), -119,119)
    loss = (a0[None,...]-d[None,...]*us)**2 + weight*(a1[None,...]-d[None,...]*us-e[None,...]*candidates)**2
    choice = np.argmin(loss,axis=0)
    u = np.take_along_axis(us,choice[None,...],axis=0)[0]
    v = np.take_along_axis(np.broadcast_to(candidates,loss.shape),choice[None,...],axis=0)[0].copy()
    initial_u,initial_v = u.copy(),v.copy()
    r0 = a0 - d*u
    r1 = a1 - d*u - e*v
    for _ in range(sweeps):
        for j in range(32):
            cj = c[:,j]
            # Shift the local target by the residual correlation with all other coordinates.
            target0 = d[...,0]*u[...,j] + np.einsum('...k,k->...',r0,cj)/c[j,j]
            target1 = d[...,0]*u[...,j] + e[...,0]*v[...,j] + np.einsum('...k,k->...',r1,cj)/c[j,j]
            vs = candidates[...,0] + np.zeros_like(target0)[None,...]
            us = np.clip(np.rint((target0[None,...]+weight*(target1[None,...]-e[...,0][None,...]*vs)) / ((1+weight)*d[...,0][None,...])), -119,119)
            loss = (target0[None,...]-d[...,0][None,...]*us)**2 + weight*(target1[None,...]-d[...,0][None,...]*us-e[...,0][None,...]*vs)**2
            choice = np.argmin(loss, axis=0)
            newu = np.take_along_axis(us,choice[None,...],axis=0)[0]
            newv = np.take_along_axis(vs,choice[None,...],axis=0)[0]
            changeu = newu-u[...,j]
            changev = newv-v[...,j]
            r0[...,j] -= d[...,0]*changeu
            r1[...,j] -= d[...,0]*changeu + e[...,0]*changev
            u[...,j],v[...,j] = newu,newv
    return u,v,d,e,r0,r1,initial_u,initial_v


def evaluate(a,codes,teacher,cov,base_head,weight):
    a0 = a[:,base_head].numpy()
    a1 = a[:,1-base_head].numpy()
    out = {}
    for passes in (0,1,2):
        u,v,d,e,r0,r1,initial_u,initial_v = fit(a0,a1,cov,weight,passes)
        before = (np.einsum('...j,jk,...k->...',r0,cov,r0) + weight*np.einsum('...j,jk,...k->...',r1,cov,r1)).mean()
        scores0 = torch.from_numpy(u) @ codes[:,0].transpose(-1,-2)
        scores1 = torch.from_numpy(v.astype(np.float64)) @ codes[:,0].transpose(-1,-2)
        scores0 = scores0 * torch.from_numpy(d) / math.sqrt(128)
        scores1 = scores0 + scores1 * torch.from_numpy(e) / math.sqrt(128)
        pair = [None,None]
        pair[base_head],pair[1-base_head] = scores0[:,None],scores1[:,None]
        out[str(passes)] = {'kl':lowering.causal_kl(torch.cat(pair,dim=1),teacher).tolist(), 'covariance_error':float(before),
                            'changed_u':int(np.count_nonzero(u-initial_u)),
                            'changed_v':int(np.count_nonzero(v-initial_v))}
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer',type=int,choices=(0,14),required=True)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    parent_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    prior_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    joint_path = DATA/f'shared-query-joint-round/layer{args.layer:02d}.json'
    parent,prior,joint = [json.loads(p.read_text()) for p in (parent_path,prior_path,joint_path)]
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL,framework='pt',device='cpu') as model:
        prefix=f'model.layers.{args.layer}.self_attn.'
        original={n:model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj','k_proj','q_norm','k_norm')}
    weights=dict(original)
    weights['q_proj']=paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj']=paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma=torch.tensor(prior['new_group_affine_bf16'],dtype=torch.bfloat16).float()
    captures={}
    for split,nw in (('train',8),('validation',4)):
        x=finite.load_capture(args.layer,split).reshape(-1,256,1024)[:nw]
        q,k=paid.projected(x,weights,gamma)
        tq,tk=paid.projected(x,original,original['k_norm'])
        captures[split]=(q,k,tq,tk)
    records=[]
    for g,group in enumerate(parent['groups']):
        mask=group['mask']+[p+64 for p in group['mask']]
        arm=parent['group_arms_selected_by_train']['coordinate'][g]+'_coordinate'
        step=torch.tensor(group['int4'][arm]['steps'],dtype=torch.float64)
        center=torch.tensor(group['train_center'] if arm.startswith('centered') else [0]*32,dtype=torch.float64)
        b,weight=joint['groups'][g]['selected_joint']
        record={'group':g,'base_head':b,'weight':weight,'splits':{}}
        keys={}
        for split,(q,k,tq,tk) in captures.items():
            keys[split]=((k[:,g,:,mask].double()-center)/step).round().clamp(-7,7)
        c=covariance(keys['train'].numpy())
        record['covariance_diagonal']=np.diag(c).tolist()
        record['off_diagonal_fraction']=float(np.linalg.norm(c-np.diag(np.diag(c)))/np.linalg.norm(c))
        for split,(q,k,tq,tk) in captures.items():
            a=q[:,2*g:2*g+2,:,mask].double()*step
            teacher=cache.scores(tq[:,2*g:2*g+2],tk[:,g:g+1],list(range(256)))
            record['splits'][split]=evaluate(a,keys[split][:,None],teacher,c,b,weight)
        records.append(record)
        print(args.layer,g,[sum(record['splits'][s][str(p)]['kl'])/len(record['splits'][s][str(p)]['kl']) for s in ('train','validation') for p in (0,1,2)],flush=True)
    summary={split:{str(p):[sum(r['splits'][split][str(p)]['kl'][w] for r in records)/8 for w in range(nw)] for p in (0,1,2)} for split,nw in (('train',8),('validation',4))}
    paths={'source':Path(__file__),'parent':parent_path,'prior':prior_path,'joint':joint_path,'model':finite.MODEL,'capture':finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz','paid_q':q_path,'paid_k':k_path}
    receipt={'layer':args.layer,'contract':'Fixed trained three-dot base/weight and dynamic query scales, train-key uniform causal-prefix-centered covariance; zero/two cyclic exact conditional coordinate sweeps; original-producer train/inspected validation','groups':records,'aggregate_by_window':summary,'mean':{s:{p:sum(v)/len(v) for p,v in by.items()} for s,by in summary.items()},'sha256':{name:base.digest(path) for name,path in paths.items()}}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(receipt,indent=2)+'\n')
    print('held',receipt['mean']['validation'],flush=True)

if __name__=='__main__':
    main()
