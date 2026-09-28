#!/usr/bin/env python3
"""Real Qwen MLP one-coordinate response tables, native-description candidates and controls."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'instruction-cells'))
from search import affine_partitions

SOURCE = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
CAPTURE = Path('/path/to/workspace/data/kelana-subbit/full-model/mlp-quantized-producer-capture.npz')
ANCHORS = [('train', 320), ('train', 384), ('validation', 576), ('validation', 640)]
X = np.arange(32, dtype=np.float64)
XN = (X - 15.5) / 15.5
T = np.array([-1.5, -.5, .5, 1.5])
B = np.stack((np.ones(4), T, T*T), axis=1)
PINV = np.linalg.pinv(B)
SQ = (X.astype(int)**2) >> 7
UQ = X.astype(int) >> 2
AFFINE = affine_partitions()
QS = np.array(list(AFFINE), dtype=np.int64)
SPECS = np.array(list(AFFINE.values()), dtype=np.int64)
NPROGRAMS = len(QS)
BIN_IDS = np.arange(NPROGRAMS)[:,None]*8+QS
BIN_COUNTS = np.bincount(BIN_IDS.ravel(), minlength=NPROGRAMS*8).reshape(NPROGRAMS,8)
# Direct scalar arithmetic polynomial, with no lookup and fewer paid fields than cell8.
POLY_POWERS = [(a,b) for a in range(5) for b in range(3)]
POLY = np.stack([(XN[:,None]**a * T[None,:]**b).repeat(1,axis=0).ravel()
                 for a,b in POLY_POWERS],axis=1)
POLY_PINV = np.linalg.pinv(POLY)
POLY8 = POLY[:,[0,1,2,3,4,5,6,9]]  # 1,t,t²,x,xt,xt²,x²,x³
POLY8_PINV = np.linalg.pinv(POLY8)


def file_sha256(path):
    digest=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(4*1024*1024),b''):
            digest.update(block)
    return digest.hexdigest()


def bf16(bits):
    return (bits.astype(np.uint32)<<16).view(np.float32).astype(np.float64)


def silu(v):
    return v/(1+np.exp(-v))


def fit(q,f):
    coefficients = f @ PINV.T
    means = np.stack([coefficients[q==cell].mean(axis=0) for cell in range(int(max(q))+1)])
    labels = means.astype(np.float16).astype(np.float64)
    prediction = np.einsum('xcj,tj->xct',labels[q,None,:],B).reshape(32,4)
    return labels, float(np.sum((prediction-f)**2))


def best_affine(f):
    coeff = f @ PINV.T
    sums = np.stack([np.bincount(BIN_IDS.ravel(),weights=np.broadcast_to(coeff[:,j],QS.shape).ravel(),
                                     minlength=NPROGRAMS*8).reshape(NPROGRAMS,8)
                     for j in range(3)],axis=-1)
    means = np.divide(sums,BIN_COUNTS[:,:,None],out=np.zeros_like(sums),where=BIN_COUNTS[:,:,None]>0)
    means = means.astype(np.float16).astype(np.float64)
    yhat = np.einsum('pxj,tj->pxt',means[np.arange(NPROGRAMS)[:,None],QS],B)
    errors = np.sum((yhat-f[None,:,:])**2,axis=(1,2))
    i=int(np.argmin(errors))
    return float(errors[i]), SPECS[i].tolist(), means[i]


def polynomial_error(f,matrix,pinv):
    coefficients=(pinv@f.ravel()).astype(np.float16).astype(np.float64)
    yhat=matrix@coefficients
    return float(np.sum((yhat-f.ravel())**2))


def build_anchor(index):
    panel,position=ANCHORS[index]
    with np.load(CAPTURE) as cap:
        base=bf16(cap[f'{panel}_teacher_input'][position])
        sample=bf16(cap['train_teacher_input'][:1024])
    deviations=sample.std(axis=0)
    coords=np.argsort(-deviations,kind='stable')[:16]
    second=np.roll(coords,-1)
    with safe_open(SOURCE,framework='pt',device='cpu') as f:
        gate=f.get_slice('model.layers.0.mlp.gate_proj.weight')[:,:].float().numpy().astype(np.float64)
        up=f.get_slice('model.layers.0.mlp.up_proj.weight')[:,:].float().numpy().astype(np.float64)
        down=f.get_slice('model.layers.0.mlp.down_proj.weight')[:16,:].float().numpy().astype(np.float64)
    gate0=gate@base
    up0=up@base
    responses=[]
    for k,h in zip(coords,second):
        dx=XN[:,None]*2*deviations[k]
        dt=T[None,:]*.5*deviations[h]
        dg=dx[:,:,None]*gate[None,None,:,k]+dt[:,:,None]*gate[None,None,:,h]
        du=dx[:,:,None]*up[None,None,:,k]+dt[:,:,None]*up[None,None,:,h]
        hidden=silu(gate0[None,None,:]+dg)*(up0[None,None,:]+du)
        response=(hidden.reshape(128,-1)@down.T).reshape(32,4,16)
        responses.append(response)
    target=np.stack(responses,axis=0).transpose(0,3,1,2).reshape(256,32,4)
    square=[]; errors=[]; specs=[]
    for f in target:
        labels,es=fit(SQ,f)
        _,eu=fit(UQ,f)
        _,ed=fit(np.arange(32),f)
        ea,spec,_=best_affine(f)
        e8=polynomial_error(f,POLY8,POLY8_PINV)
        e15=polynomial_error(f,POLY,POLY_PINV)
        eliteral=float(np.sum((f.astype(np.float16).astype(np.float64)-f)**2))
        square.append(labels)
        errors.append([es,ea,eu,ed,e8,e15,eliteral])
        specs.append(spec)
    square=np.asarray(square)
    errors=np.asarray(errors)
    energy=np.sum((target-target.mean(axis=(1,2),keepdims=True))**2,axis=(1,2))
    out=HERE/f'anchor-{index}.npz'
    np.savez_compressed(out,target=target,square=square.astype(np.float16),
                        errors=errors,energy=energy,specs=np.asarray(specs),
                        coords=coords,other=second,anchor=base[coords],deviations=deviations[coords])
    print(json.dumps(dict(index=index,coords=coords.tolist(),table_count=len(target),
                          square_wins_affine=int(np.sum(errors[:,0]<errors[:,1])),
                          median_relative_rms={name:float(np.median(np.sqrt(errors[:,j]/energy))) for j,name in
                                               enumerate(('square','affine','uniform','direct','poly8','poly15','literal_xy'))},
                          output=str(out))))


def summarize():
    blocks=[np.load(HERE/f'anchor-{i}.npz') for i in range(4)]
    target=np.concatenate([b['target'] for b in blocks]).astype(np.float64)
    square=np.concatenate([b['square'] for b in blocks]).astype(np.float64)
    errs=np.concatenate([b['errors'] for b in blocks])
    energy=np.concatenate([b['energy'] for b in blocks])
    n=len(target)
    result=dict(format='table-diversity/1',model_path=str(SOURCE),
                model_sha256=file_sha256(SOURCE),
                capture_path=str(CAPTURE),capture_sha256=file_sha256(CAPTURE),
                tables=n,table_schema='per anchor,input coordinate,output row: 8 or 32 aligned 8-byte rows of 3 FP16 polynomial coefficients',
                anchors=ANCHORS,coordinate_indices=blocks[0]['coords'].tolist(),
                grid=dict(x_code=list(range(32)),x_deviation='2*input-train-standard-deviations * (x-15.5)/15.5',
                          t=T.tolist(),t_deviation='.5*input-train-standard-deviations*t'),
                static_table_bytes=dict(square=n*64,direct=n*256,literal_xy=n*256,poly8=n*16,poly15=n*30),
                panel={},diversity={})
    for j,name in enumerate(('square','affine','uniform','direct','poly8','poly15','literal_xy')):
        rel=np.sqrt(errs[:,j]/energy)
        result['panel'][name]=dict(median=float(np.median(rel)),p90=float(np.quantile(rel,.9)),
                                   aggregate=float(np.sqrt(errs[:,j].sum()/energy.sum())),
                                   wins_vs_square=int(np.sum(errs[:,j]<errs[:,0])))
    fp16=square.astype(np.float16).view(np.uint16).reshape(n,-1)
    result['diversity']['exact_fp16_unique']=len(np.unique(fp16,axis=0))
    specifications=np.concatenate([b['specs'] for b in blocks])
    unique_specs,counts=np.unique(specifications,axis=0,return_counts=True)
    result['diversity']['affine_unique_programs']=len(unique_specs)
    order=np.argsort(-counts)
    result['diversity']['affine_top_programs']=[dict(program=unique_specs[i].tolist(),tables=int(counts[i])) for i in order[:6]]
    result['diversity']['affine_nonzero_bias_tables']=int(np.sum(specifications[:,1]!=0))
    # The cell labels' scalar mean and gain are reusable per tile, not shared constants.
    expanded=np.einsum('ncj,tj->nct',square[:,SQ,:],B).reshape(n,128)
    mean=expanded.mean(axis=1)
    centered=expanded-mean[:,None]
    length=np.linalg.norm(centered,axis=1)
    assert np.all(length>0)
    normalized=centered/length[:,None]
    train=np.r_[0:512]
    held=np.r_[512:1024]
    cross=normalized[held]@normalized[train].T
    nearest=np.max(np.abs(cross),axis=1)
    result['diversity']['held_best_train_affine_shape_cosine_median']=float(np.median(nearest))
    result['diversity']['held_best_train_affine_shape_cosine_p10']=float(np.quantile(nearest,.1))
    # Dictionary prototypes are actual training tables; fit per-table FP16 affine response correction.
    for K in (8,32,128,512):
        chosen=[0]
        similarity=np.abs(normalized[train]@normalized[train[0]])
        for _ in range(1,K):
            i=int(np.argmin(similarity))
            chosen.append(i)
            similarity=np.maximum(similarity,np.abs(normalized[train]@normalized[train[i]]))
        templates=square[train[chosen]].astype(np.float16).astype(np.float64)
        candidates=np.einsum('kcj,tj->kct',templates[:,SQ,:],B).reshape(K,128)
        candidates_centered=candidates-candidates.mean(axis=1,keepdims=True)
        candidate_norm=np.sum(candidates_centered**2,axis=1)
        held_target=target[held].reshape(-1,128)
        held_mean=held_target.mean(axis=1)
        centered_target=held_target-held_mean[:,None]
        dots=centered_target@candidates_centered.T
        selection=np.argmax(dots*dots/candidate_norm[None,:],axis=1)
        slopes=(dots[np.arange(len(held)),selection]/candidate_norm[selection]).astype(np.float16).astype(np.float64)
        offsets=(held_mean-slopes*candidates.mean(axis=1)[selection]).astype(np.float16).astype(np.float64)
        prediction=offsets[:,None]+slopes[:,None]*candidates[selection]
        e=np.sum((prediction-held_target)**2,axis=1)
        rel=np.sqrt(e/energy[held])
        per_tile_bytes=4+(1 if K<=256 else 2)
        result['diversity'][f'dictionary_{K}']=dict(template_bytes=K*64,per_tile_bytes=per_tile_bytes,
            model_bytes_for_all_tables=K*64+n*per_tile_bytes,
            held_median_relative_rms=float(np.median(rel)),
            held_aggregate_relative_rms=float(np.sqrt(e.sum()/energy[held].sum())),
            held_wins_vs_individual_square=int(np.sum(e<errs[held,0])))
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['panel'],indent=2))
    print(json.dumps(result['diversity'],indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--anchor',type=int,choices=range(4))
    parser.add_argument('--summarize',action='store_true')
    args=parser.parse_args()
    if args.summarize: summarize()
    elif args.anchor is not None: build_anchor(args.anchor)
    else: parser.error('choose --anchor 0..3 or --summarize')
