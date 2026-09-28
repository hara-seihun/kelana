#!/usr/bin/env python3
"""Independent two-dimensional conditional Gaussian quadrature for Stein/Hermite Gram."""
import json
from pathlib import Path

import numpy as np
from numpy.polynomial.hermite import hermgauss
from safetensors import safe_open

from kernel import HERE, MODEL, gram_block, hidden


def conditional_pair(g,u,i,j,order=40):
    gate=np.stack((g[:,i],g[:,j]),axis=1).astype(np.float64)
    up=np.stack((u[:,i],u[:,j]),axis=1).astype(np.float64)
    mg=gate.mean(0)
    mu=up.mean(0)
    covg=np.cov(gate,rowvar=False,bias=True)
    covug=(up-mu).T@(gate-mg)/len(gate)
    covuu=((up-mu).T@(up-mu)/len(gate))[0,1]
    conditioned=covug@np.linalg.inv(covg)
    conditional_cov=covuu-(conditioned@covug.T)[0,1]
    nodes,weights=hermgauss(order)
    z=nodes*np.sqrt(2)
    w=weights/np.sqrt(np.pi)
    t=np.stack(np.meshgrid(z,z,indexing='ij'),axis=-1).reshape(-1,2)
    wg=np.outer(w,w).ravel()
    v=t@np.linalg.cholesky(covg).T+mg
    mean_u=(v-mg)@conditioned.T+mu
    silu=lambda value:value/(1+np.exp(-value))
    return float(wg@(silu(v[:,0])*silu(v[:,1])*(mean_u[:,0]*mean_u[:,1]+conditional_cov)))


def main():
    with np.load(HERE/'preactivation-train.npz') as f:
        g=f['g'];u=f['u']
    train=hidden('train')
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        down=f.get_tensor('model.layers.0.mlp.down_proj.weight').float().numpy().astype(np.float64)
    score=np.linalg.norm(train-train.mean(0),axis=0)*np.linalg.norm(down,axis=0)
    bank=np.argsort(-score,kind='stable')[:128]
    columns=np.arange(256)
    coarse,_,_,_=gram_block(g,u,bank,columns,16,64)
    fine,_,_,_=gram_block(g,u,bank,columns,24,96)
    pairs=[]
    for row in (0,17,35):
        for col in (0,37,73,109,151,199,233):
            if bank[row]==col: continue
            conditional=conditional_pair(g,u,int(bank[row]),int(col))
            pairs.append(dict(bank_row=row,column=col,source_pair=[int(bank[row]),col],
                              conditional_2d=conditional,hermite_16=float(coarse[row,col]),
                              hermite_24=float(fine[row,col])))
    result=dict(max_hermite_order_16_vs_24_relative_frobenius=float(np.linalg.norm(coarse-fine)/np.linalg.norm(fine)),
                conditional_2d_vs_hermite_24_relative_rms=float(np.linalg.norm([p['conditional_2d']-p['hermite_24'] for p in pairs])/
                                                               np.linalg.norm([p['conditional_2d'] for p in pairs])),
                pairs=pairs)
    (HERE/'formula.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='pairs'}))


if __name__=='__main__':main()
