"""Screen pair-merge input programs with exact full-panel real-readout projection.

The native candidate has 64 singleton lanes and 32 signed two-coordinate lanes:
32 add/sub operations, then a dense 128x96 output map. The response projection
permits all real readout values, so it is a floor for every packed output grid.
"""
import hashlib
import json
import runpy
from pathlib import Path

import numpy as np

FIXTURE = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
OUT = Path(__file__).with_name('results.json')
CONTROL = Path(__file__).resolve().parents[1] / 'producer-screen'


def response_error(y, fit):
    return float(np.sum((y-fit)**2)/np.sum(y*y))


def panel(x, v, w, sign_mode):
    y=x@w.T
    h=x.T@x
    g=w.T@w
    candidates=[]
    for i in range(128):
        for j in range(i+1,128):
            hii,hjj,hij=h[i,i],h[j,j],h[i,j]
            gii,gjj,gij=g[i,i],g[j,j],g[i,j]
            norm=hii*gii+hjj*gjj+2*hij*gij
            signs=(-1.,1.) if sign_mode=='both' else (1.,)
            for sign in signs:
                zi=hii+sign*hij; zj=hij+sign*hjj
                gain=(zi*zi*gii+zj*zj*gjj+2*zi*zj*gij)/(hii+hjj+2*sign*hij)
                candidates.append((float(norm-gain), i,j, int(sign)))
    candidates.sort()
    used=set(); pairs=[]
    for cost,i,j,sign in candidates:
        if i in used or j in used: continue
        pairs.append((i,j,sign,cost)); used.update((i,j))
        if len(pairs)==32: break
    rest=[i for i in range(128) if i not in used]
    mapping=np.zeros((128,96))
    for k,i in enumerate(rest): mapping[i,k]=1
    for k,(i,j,sign,_) in enumerate(pairs,64): mapping[i,k]=1; mapping[j,k]=sign
    z=x@mapping; zheld=v@mapping
    readout=np.linalg.lstsq(z,y,rcond=None)[0]
    raw_train=response_error(y,z@readout)
    raw_held=response_error(v@w.T,zheld@readout)
    return dict(pairs=[[i,j,sign] for i,j,sign,_ in pairs], projected_train_floor=raw_train,
                projected_held_response=raw_held, min_pair_cost=float(pairs[0][3]),
                max_pair_cost=float(pairs[-1][3]), rank=int(np.linalg.matrix_rank(z)))


def main():
    with np.load(FIXTURE) as f:
        w=f['weight'][:128,:128].astype('float64')
        x=f['train'][:,:128].astype('float64')
        v=f['validation'][:,:128].astype('float64')
    q4_decode=runpy.run_path(str(CONTROL/'screen.py'))['decode_q4']
    q4_image=(CONTROL/'affine-q4.bin').read_bytes()
    q4=q4_decode(q4_image)
    y=x@w.T; vy=v@w.T
    eigen_min=float(np.linalg.eigvalsh(x.T@x)[0])
    pair_residuals=sorted(min(np.sum((w[:,i]-w[:,j])**2), np.sum((w[:,i]+w[:,j])**2))/2
                          for i in range(128) for j in range(i+1,128))
    universal_signed_pair_floor=float(eigen_min*sum(pair_residuals[:32])/np.sum(y*y))
    experiment={
        'fixture':str(FIXTURE), 'sha256':hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
        'boundary':'128 input coordinates to all 128 output coordinates of Qwen3-0.6B layer0 q_proj subprojection',
        'scalar_q4_bytes':len(q4_image), 'scalar_q4_sha256':hashlib.sha256(q4_image).hexdigest(),
        'scalar_q4_train_relerr':response_error(y,x@q4.T),
        'scalar_q4_held_relerr':response_error(vy,v@q4.T),
        'program_bytes_if_q4_readout':6144+512+128+4,
        'program_online_adds':32, 'program_online_output_coeff_products':96*128,
        'universal_signed_pair_floor_all_pair_choices':universal_signed_pair_floor,
        'train_gram_smallest_eigenvalue':eigen_min,
        'direct_q4_online_coeff_products':128*128,
        'signed_pairs':panel(x,v,w,'both'),
        'sum_pairs':panel(x,v,w,'plus'),
    }
    OUT.write_text(json.dumps(experiment,indent=2)+'\n')
    print({k:({j:a[j] for j in ('projected_train_floor','projected_held_response')}
              if isinstance(a,dict) else a) for k,a in experiment.items() if k not in ('fixture','sha256')})

if __name__=='__main__': main()
