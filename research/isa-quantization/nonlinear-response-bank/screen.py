#!/usr/bin/env python3
"""Paid nonlinear channel banks screened by a free held FP64 readout floor."""
import json
from pathlib import Path

import numpy as np
import scipy.linalg
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
RANKS=(128,256,384,512,640,768,784,788)


def panels(split):
    arrays=[np.load(HERE/f'{split}-{i}.npz') for i in range(4)]
    return {name:np.concatenate([a[name] for a in arrays]).astype(np.float64)
            for name in ('hidden','target','q4')}


def norm(e,target):
    return float(np.linalg.norm(e)/np.linalg.norm(target))


def floor(features,target):
    # A free real-valued readout is selected AFTER seeing target. Hence an
    # optimistic error floor for this fixed feature bank on that panel.
    a=np.column_stack((np.ones(len(features)),features))
    q,r=scipy.linalg.qr(a,mode='economic',check_finite=False)
    diagonal=np.abs(np.diag(r))
    rank=int(np.count_nonzero(diagonal>diagonal.max()*1e-10))
    coeff=q.T@target
    retained=np.sum(coeff[:rank]**2)
    residual=max(0,float(np.sum(target**2)-retained))
    return float(np.sqrt(residual/np.sum(target**2))),rank


def main():
    train,held=panels('train'),panels('held')
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        down=f.get_tensor('model.layers.0.mlp.down_proj.weight').float().numpy().astype(np.float64)
    h=train['hidden']
    variations=np.linalg.norm(h-h.mean(axis=0),axis=0)
    ranks={
        'teacher_down_weighted_variation': variations*np.linalg.norm(down,axis=0),
        'hidden_variation': variations,
    }
    baseline={key:norm(panel['q4']-panel['target'],panel['target']) for key,panel in [('train',train),('held',held)]}
    mu=train['target'].mean(0)
    _,singular,axes=np.linalg.svd(train['target']-mu,full_matrices=False)
    held_projected=(held['target']-mu)@axes.T
    rank_probe={}
    for k in (256,512,640,768,896,1023):
        train_floor=float(np.sqrt(np.sum(singular[k:]**2)/np.sum(train['target']**2)))
        held_floor=float(np.sqrt(np.maximum(0,np.sum((held['target']-mu)**2)-
                             np.sum(held_projected[:,:k]**2))/np.sum(held['target']**2)))
        rank_probe[str(k)]=dict(train_optimistic_relative_rms=train_floor,
                                held_free_coordinates_on_train_output_subspace=held_floor)
    outcomes={}
    for name,score in ranks.items():
        order=np.argsort(-score,kind='stable')
        outcomes[name]={}
        for K in RANKS:
            selected=order[:K]
            ft,rt=floor(train['hidden'][:,selected],train['target'])
            fv,rv=floor(held['hidden'][:,selected],held['target'])
            physical=2*K*1024*2+1024*K*2+1024*2+2*K+7
            outcomes[name][str(K)]={'train_free_readout_floor':ft,'held_free_readout_floor':fv,
                    'train_feature_rank_with_bias':rt,'held_feature_rank_with_bias':rv,
                    'dense_fp16_image_bytes_including_ids_and_header':physical,
                    'static_and_work_terms':{'fp16_gate_up_coefficients':2*K*1024,
                                             'fp16_readout_coefficients':K*1024,
                                             'fp16_readout_bias':1024,
                                             'forward_projection_fma_per_input':3*K*1024}}
            print(name,K,'train/held optimistic floors',round(ft,5),round(fv,5),
                  'q4 held',round(baseline['held'],5),'bytes',physical,flush=True)
    preparation=json.loads((HERE/'train-0.json').read_text())
    result={'format':'nonlinear-response-bank/1',
            'basis':'actual Qwen3-0.6B layer-0 gate/up/SiLU/down; full 1024 outputs and 3072 hidden channels',
            'producer':'selected ternary-model BF16 captured MLP input; four disjoint 256-token train windows, four disjoint 256-token validation windows',
            'source_sha256':preparation['source_sha256'],
            'capture_train_sha256':json.loads((HERE/'train-0.json').read_text())['capture_sha256'],
            'capture_held_sha256':json.loads((HERE/'held-0.json').read_text())['capture_sha256'],
            'train_states':len(train['target']),'held_states':len(held['target']),
            'output_dimensions':train['target'].shape[1],
            'q4_all_three_payload_bytes':preparation['payload_bytes'],
            'q4_images':preparation['images'],
            'q4_relative_rms':baseline,'unconstrained_train_output_svd':rank_probe,
            'feature_banks':outcomes}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':main()
