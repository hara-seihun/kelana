#!/usr/bin/env python3
"""Hermite/Stein feature Gram, using only first two moments of captured producer states."""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
PARENT=HERE.parent/'nonlinear-response-bank'
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')


def hidden(split):
    return np.concatenate([np.load(PARENT/f'{split}-{i}.npz')['hidden'] for i in range(4)]).astype(np.float64)


def hermite_moments(mean, sigma, order=16, quadrature=64):
    from numpy.polynomial.hermite import hermgauss
    nodes,weights=hermgauss(quadrature)
    nodes=nodes*np.sqrt(2)
    weights=weights/np.sqrt(np.pi)
    z=mean[:,None]+sigma[:,None]*nodes[None,:]
    z=np.clip(z,-80,80)
    sigmoid=1/(1+np.exp(-z))
    phi=z*sigmoid
    derivative=sigmoid+z*sigmoid*(1-sigmoid)
    second=sigmoid*(1-sigmoid)*(2+z*(1-2*sigmoid))
    fun=np.stack((phi,derivative,second))
    coeff=np.zeros((3,len(mean),order+1))
    h0=np.ones_like(nodes)
    h1=nodes.copy()
    coeff[:,:,0]=np.einsum('fmq,q->fm',fun,weights)
    if order>=1: coeff[:,:,1]=np.einsum('fmq,q->fm',fun,h1*weights)
    for n in range(1,order):
        h2=(nodes*h1-np.sqrt(n)*h0)/np.sqrt(n+1)
        coeff[:,:,n+1]=np.einsum('fmq,q->fm',fun,h2*weights)
        h0,h1=h1,h2
    squared=np.einsum('fmq,q->fm',fun*fun,weights)
    tails=np.maximum(0,squared-np.sum(coeff*coeff,axis=2))
    return coeff,tails


def gram_block(g,u,selected,columns,order,quadrature):
    g=np.asarray(g,dtype=np.float64)
    u=np.asarray(u,dtype=np.float64)
    mg,mu=g.mean(0),u.mean(0)
    gc,uc=g-mg,u-mu
    sg=np.sqrt(np.mean(gc**2,axis=0))
    assert np.all(sg>1e-10)
    cug=np.mean(gc*uc,axis=0)
    coeff,tails=hermite_moments(mg,sg,order,quadrature)
    i,j=selected,columns
    ga,gb=gc[:,i],gc[:,j]
    ua,ub=uc[:,i],uc[:,j]
    ciuigi=cug[i][:,None]
    cjujgj=cug[j][None,:]
    ciuigj=ua.T@gb/len(g)
    cjujgi=ga.T@ub/len(g)
    cuu=ua.T@ub/len(g)
    correlation=(ga.T@gb/len(g))/(sg[i,None]*sg[None,j])
    correlation=np.clip(correlation,-1,1)
    accum=[np.zeros_like(correlation) for _ in range(6)]
    rho=np.ones_like(correlation)
    pairs=((0,0),(1,0),(0,1),(2,0),(1,1),(0,2))
    for n in range(order+1):
        for out,(left,right) in zip(accum,pairs):
            out+=coeff[left,i,n][:,None]*coeff[right,j,n][None,:]*rho
        rho*=correlation
    A,Bi,Bj,Cii,Cij,Cjj=accum
    raw=((mu[i,None]*mu[None,j]+cuu)*A
         +mu[i,None]*(cjujgi*Bi+cjujgj*Bj)
         +mu[None,j]*(ciuigi*Bi+ciuigj*Bj)
         +ciuigi*cjujgi*Cii
         +(ciuigi*cjujgj+ciuigj*cjujgi)*Cij
         +ciuigj*cjujgj*Cjj)
    feature_mean=mu*coeff[0,:,0]+cug*coeff[1,:,0]
    centered=raw-feature_mean[i,None]*feature_mean[None,j]
    return raw,centered,feature_mean,dict(max_phi_tail=float(tails[0].max()),
        max_phi_prime_tail=float(tails[1].max()),max_phi_doubleprime_tail=float(tails[2].max()),
        min_raw_eigen_input_correlation=float(correlation.min()),max_input_correlation=float(correlation.max()))


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--rank',type=int,choices=(64,128,784),default=128)
    p.add_argument('--block',type=int,choices=range(12),default=0)
    p.add_argument('--order',type=int,default=16)
    p.add_argument('--quadrature',type=int,default=64)
    args=p.parse_args()
    with np.load(HERE/'preactivation-train.npz') as f:
        g=f['g'];u=f['u']
    train=hidden('train')
    held=hidden('held')
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        down=f.get_tensor('model.layers.0.mlp.down_proj.weight').float().numpy().astype(np.float64)
    scores=np.linalg.norm(train-train.mean(0),axis=0)*np.linalg.norm(down,axis=0)
    selected=np.argsort(-scores,kind='stable')[:args.rank]
    columns=np.arange(args.block*256,(args.block+1)*256)
    raw,centered,model_mean,diagnostic=gram_block(g,u,selected,columns,args.order,args.quadrature)
    actual_train=train[:,selected].T@train[:,columns]/len(train)
    actual_held=held[:,selected].T@held[:,columns]/len(held)
    actual_centered=(train[:,selected]-train[:,selected].mean(0)).T@(
        train[:,columns]-train[:,columns].mean(0))/len(train)
    actual_held_centered=(held[:,selected]-held[:,selected].mean(0)).T@(
        held[:,columns]-held[:,columns].mean(0))/len(held)
    rel=lambda pred,actual:float(np.linalg.norm(pred-actual)/np.linalg.norm(actual))
    summary=dict(rank=args.rank,block=args.block,order=args.order,quadrature=args.quadrature,
        train_raw_gram_relative_error=rel(raw,actual_train),
        held_raw_gram_relative_error=rel(raw,actual_held),
        train_centered_gram_relative_error=rel(centered,actual_centered),
        held_centered_gram_relative_error=rel(centered,actual_held_centered),
        train_feature_mean_relative_error=rel(model_mean[columns],train[:,columns].mean(0)),
        held_feature_mean_relative_error=rel(model_mean[columns],held[:,columns].mean(0)),
        quadrature_diagnostics=diagnostic)
    if args.rank in (128,784) and args.order==16 and args.quadrature==64:
        np.save(HERE/f'kernel-{args.rank}-{args.block}.npy',centered)
        if args.block==0:
            np.save(HERE/'model-mean.npy',model_mean)
    (HERE/f'witness-{args.rank}-{args.block}.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
