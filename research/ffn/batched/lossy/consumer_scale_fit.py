#!/usr/bin/env python3
"""Fit grouped weight scales in the metric of their actual linear consumer.

All fitting is offline. Test inputs come from a different document. This isolates
weight-scale fitting on a fixed grouped-A4 activation representation; it is not
full-FFN or full-model acceptance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time
import numpy as np
from probe import Gguf, hadamard
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'grouped-scales'))
from scale_fit import fit_group


def inputs(directory, tokens):
    paths=sorted(directory.glob('c*/x_in.f32'))
    x=np.concatenate([np.fromfile(p,dtype='<f4').reshape(-1,5120) for p in paths])[:tokens].astype(np.float64)
    if len(x)!=tokens:raise ValueError('insufficient input rows')
    norm=np.fromfile(directory/'post_norm_s.f32',dtype='<f4').astype(np.float64)
    u=hadamard(x/np.sqrt(np.mean(x*x,axis=1,keepdims=True)+1e-5)*norm)
    groups=u.reshape(tokens,-1,1024)
    step=np.max(np.abs(groups),axis=2,keepdims=True)*(.8/7)
    step=np.where(step>0,step,1)
    return (np.clip(np.rint(groups/step),-7,7)*step).reshape(tokens,40,128)


def partials(x,trits):
    # Each output is a list of five 8-block groups, each observed over tokens.
    z=np.einsum('tbk,obk->otb',x,trits,optimize=True)
    return z.reshape(len(trits),len(x),5,8).transpose(0,2,1,3).reshape(-1,len(x),8)


def metric_fit(lam,initial_m,cov,passes=4):
    m=initial_m.astype(np.float64).copy()
    b=np.einsum('nij,nj->ni',cov,lam)
    def scale(mm):
        cm=np.einsum('nij,nj->ni',cov,mm)
        den=np.sum(mm*cm,axis=1)
        num=np.sum(mm*b,axis=1)
        return np.maximum(num,0)/np.maximum(den,1e-300)
    for _ in range(passes):
        for j in range(8):
            cm=np.einsum('nij,nj->ni',cov,m)
            den=np.sum(m*cm,axis=1);num=np.sum(m*b,axis=1)
            delta=np.arange(1,8)[None,:]-m[:,j,None]
            newden=den[:,None]+2*delta*cm[:,j,None]+delta**2*cov[:,j,j,None]
            newnum=num[:,None]+delta*b[:,j,None]
            score=-np.maximum(newnum,0)**2/np.maximum(newden,1e-300)
            m[:,j]=1+np.argmin(score,axis=1)
    return m,scale(m)


def joint_fit(z,lam,initial_m,initial_L,rows,passes=4):
    zz=z.reshape(rows,5,z.shape[1],8)
    m=initial_m.reshape(rows,5,8).astype(np.float64).copy()
    prior=initial_L.reshape(rows,5)
    L=prior.copy()
    target=np.einsum('ogtb,ogb->ot',zz,lam.reshape(rows,5,8))
    for _ in range(passes):
        p=np.einsum('ogtb,ogb->ogt',zz,m)
        gram=p@p.transpose(0,2,1)
        diagonal=np.diagonal(gram,axis1=1,axis2=2).copy()
        gram[:,np.arange(5),np.arange(5)]+=.1*diagonal
        rhs=np.einsum('ogt,ot->og',p,target)+.1*diagonal*prior
        L=np.linalg.solve(gram,rhs[...,None])[...,0]
        if np.any(L<=0):raise ValueError('joint fit left positive scale domain')
        error=np.einsum('ogt,og->ot',p,L)-target
        for g in range(5):
            for b in range(8):
                v=zz[:,g,:,b]*L[:,g,None]
                dot=np.sum(error*v,axis=1);energy=np.sum(v*v,axis=1)
                deltas=np.arange(1,8)[None,:]-m[:,g,b,None]
                score=2*deltas*dot[:,None]+deltas*deltas*energy[:,None]
                choice=np.argmin(score,axis=1)
                delta=deltas[np.arange(rows),choice]
                m[:,g,b]+=delta
                error+=delta[:,None]*v
    return m.reshape(-1,8),L.reshape(-1)


def measure(z,lam,approx,rows):
    exact=np.einsum('ntb,nb->nt',z,lam).reshape(rows,5,-1).sum(axis=1)
    error=np.einsum('ntb,nb->nt',z,approx-lam).reshape(rows,5,-1).sum(axis=1)
    return {'relative_rms':float(np.linalg.norm(error)/np.linalg.norm(exact)),
            'bias':float(error.mean()),'max_abs':float(np.abs(error).max())}


def main():
    p=argparse.ArgumentParser();p.add_argument('--outputs',type=int,default=512)
    p.add_argument('--tokens',type=int,default=256);p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();start=time.monotonic()
    root=Path('/path/to/workspace/data/kelana-ffn/ptq1_0-batch')
    calibration=root/'calib/layer00';test=root/'bench/layer00'
    xc,xt=inputs(calibration,a.tokens),inputs(test,a.tokens)
    model=Gguf('/path/to/workspace/data/bonsai2/PTQ1_0.gguf');records=[]
    for name in ('gate','up'):
        trits,scales=model.rows_ptq1_0(f'blk.0.ffn_{name}.weight',0,a.outputs)
        trits=trits.reshape(a.outputs,40,128).astype(np.float64)
        lam=scales.reshape(-1,8).astype(np.float64)
        zc,zt=partials(xc,trits),partials(xt,trits)
        covariance=zc.transpose(0,2,1)@zc/a.tokens
        _,m,L=fit_group(lam,7)
        variants=[('relative_scale_fit',m,L)]
        for shrink in (0.,.1,1.):
            diagonal=np.zeros_like(covariance)
            diagonal[:,np.arange(8),np.arange(8)]=np.diagonal(covariance,axis1=1,axis2=2)
            cov=(1-shrink)*covariance+shrink*diagonal
            mm,ll=metric_fit(lam,m,cov)
            variants.append((f'consumer_metric_shrink_{shrink}',mm,ll))
        mm,ll=joint_fit(zc,lam,m,L,a.outputs)
        variants.append(('joint_consumer_metric_ridge_0.1',mm,ll))
        for label,mm,ll in variants:
            approx=mm*ll.astype(np.float16).astype(np.float64)[:,None]
            entry={'matrix':name,'fit':label,'calibration':measure(zc,lam,approx,a.outputs),
                   'test':measure(zt,lam,approx,a.outputs),
                   'relative_scale_rms':float(np.sqrt(np.mean(((approx-lam)/lam)**2))),
                   'changed_multiplier_fraction':float(np.mean(mm!=m))}
            records.append(entry);print(name,label,'cal',entry['calibration']['relative_rms'],
                                         'test',entry['test']['relative_rms'],'scales',entry['relative_scale_rms'])
    result={'scope':'First output rows of gate/up in layer0. Error from grouped weight-scale approximation only, on fixed grouped-A4 inputs. Float64 CPU model. No GPU candidate or quality acceptance.',
            'outputs_per_matrix':a.outputs,'tokens_per_document':a.tokens,'activation_group':1024,
            'activation_clip':.8,'stored_scale_dtype':'fp16','calibration_directory':str(calibration),'test_directory':str(test),
            'manifest_sha256':{str(d):hashlib.sha256((d/'manifest.json').read_bytes()).hexdigest() for d in (calibration,test)},
            'seconds':time.monotonic()-start,'results':records}
    a.out.write_text(json.dumps(result,indent=2)+'\n');print('seconds',result['seconds'])

if __name__=='__main__':main()
