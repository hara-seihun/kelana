#!/usr/bin/env python3
"""Source-derived direct affine atlas of the complete Qwen MLP response."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit/vector-full/capture/isa-response')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')


def load(split):
    panels=[np.load(DATA/f'{split}-{j}.npz') for j in range(4)]
    with np.load(DATA/f'preactivation-{split}.npz') as f:
        g=f['g'].astype(np.float64)
        u=f['u'].astype(np.float64)
    fields={key:np.concatenate([p[key] for p in panels]).astype(np.float64)
            for key in ('inputs','target','q4')}
    assert fields['inputs'].shape==(1024,1024)
    assert g.shape==u.shape==(1024,3072)
    fields.update(g=g,u=u)
    return fields


def weights():
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        return {key:f.get_tensor('model.layers.0.mlp.'+key+'_proj.weight').float().numpy().astype(np.float64)
                for key in ('gate','up','down')}


def silu(g):
    s=1/(1+np.exp(-np.clip(g,-80,80)))
    return g*s,s+g*s*(1-s)


def chart(center,source):
    g0=source['gate']@center
    u0=source['up']@center
    value,derivative=silu(g0)
    return dict(center=center,g0=g0,u0=u0,alpha=derivative*u0,beta=value,
                output=source['down']@(value*u0))


def chart_average(train,route,source):
    ids=np.flatnonzero(route)
    assert len(ids)
    gates=train['g'][ids]
    ups=train['u'][ids]
    values,derivatives=silu(gates)
    return dict(center=train['inputs'][ids].mean(0),
                g0=gates.mean(0),u0=ups.mean(0),
                alpha=np.mean(derivatives*ups,axis=0),
                beta=values.mean(0),
                output=train['target'][ids].mean(0))


def prediction(panel,indices,c,down):
    if len(indices)==0: return np.empty((0,1024))
    delta=((panel['g'][indices]-c['g0'])*c['alpha']+
           (panel['u'][indices]-c['u0'])*c['beta'])
    return c['output'][None,:]+delta@down.T


def router(train):
    x=train['inputs']
    mu=x.mean(0)
    _,s,v=np.linalg.svd(x-mu,full_matrices=False)
    direction=v[0].astype(np.float16).astype(np.float64)
    threshold=float(np.float16(np.median(x@direction)))
    return direction,threshold,s


def relative(pred,target):
    return float(np.linalg.norm(pred-target)/np.linalg.norm(target))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--split',choices=('train','held'),required=True)
    args=parser.parse_args()
    training=load('train')
    panel=training if args.split=='train' else load('held')
    source=weights()
    direction,threshold,spectrum=router(training)
    route_train=(training['inputs']@direction>=threshold)
    route=(panel['inputs']@direction>=threshold)
    charts=[chart(training['inputs'][route_train==r].mean(0),source) for r in (False,True)]
    global_chart=chart(training['inputs'].mean(0),source)
    global_prediction=prediction(panel,np.arange(len(route)),global_chart,source['down'])
    global_average=prediction(panel,np.arange(len(route)),chart_average(training,
        np.ones(len(training['inputs']),dtype=bool),source),source['down'])
    routed_prediction=np.zeros_like(global_prediction)
    routed_average=np.zeros_like(global_prediction)
    for r in (False,True):
        ids=np.flatnonzero(route==r)
        routed_prediction[ids]=prediction(panel,ids,charts[int(r)],source['down'])
        routed_average[ids]=prediction(panel,ids,chart_average(training,route_train==r,source),source['down'])
    target=panel['target']
    q4=panel['q4']
    result=dict(format='response-atlas/1',split=args.split,
        n=len(target),complete_outputs=1024,
        route_train_counts=[int(np.sum(route_train==r)) for r in (False,True)],
        route_panel_counts=[int(np.sum(route==r)) for r in (False,True)],
        route_vector_fp16_sha256=hashlib.sha256(direction.astype('<f2').tobytes()).hexdigest(),
        route_threshold_fp16=threshold,
        route_pc1_train_fraction_of_centered_input_energy=float(spectrum[0]**2/np.sum(spectrum**2)),
        global_source_jacobian_fp64_relative_rms=relative(global_prediction,target),
        routed_source_jacobian_fp64_relative_rms=relative(routed_prediction,target),
        global_source_average_jacobian_fp64_relative_rms=relative(global_average,target),
        routed_source_average_jacobian_fp64_relative_rms=relative(routed_average,target),
        packed_scalar_q4_relative_rms=relative(q4,target),
        global_residual_energy=float(np.sum((global_prediction-target)**2)),
        routed_residual_energy=float(np.sum((routed_prediction-target)**2)),
        routed_average_residual_energy=float(np.sum((routed_average-target)**2)),
        centered_target_energy=float(np.sum((target-target.mean(0))**2)),
        output_target_energy=float(np.sum(target**2)),
        physical_budget=dict(q4_all_three=4866096,
            global_fp16_jacobian_bias=2*1024*1024+2*1024+32,
            routed_two_fp16_jacobians_biases_router=2*(2*1024*1024+2*1024)+2*1024+2+32),
        source_sha256='f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b')
    (HERE/f'screen-{args.split}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
