"""Exact finite-field minor of dyadic BF16-produced input rows.

Float32 values are interpreted exactly as dyadic rationals, all multiplied by
2^149 before reduction modulo prime p. A nonzero minor modulo p certifies
linear independence of the original real rows.
"""
from pathlib import Path
import json
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')
P=65521


def dyadic_mod(x):
    bits=np.asarray(x,dtype='<f4').view('<u4')
    e=(bits>>23)&255
    m=bits&((1<<23)-1)
    assert not np.any(e==255)
    integer=m.astype(np.int64)+((e>0).astype(np.int64)<<23)
    factors=np.array([pow(2,max(0,k-1),P) for k in range(256)],dtype=np.int64)
    integer=integer*factors[e]
    integer=np.where((bits>>31)!=0,-integer,integer)%P
    return integer


def first_seen_positions(ids):
    seen=set();positions=[]
    for i,key in enumerate(ids):
        if int(key) not in seen:
            seen.add(int(key));positions.append(i)
    return positions


def eliminate(matrix,columns=None):
    a=matrix.copy();rows,n=a.shape
    pivots=[];det=1;sign=1
    colset=range(n) if columns is None else columns
    for col in colset:
        i=len(pivots)
        if i==rows:break
        candidates=np.flatnonzero(a[i:,col])
        if not len(candidates):
            if columns is not None:return pivots,0
            continue
        chosen=i+int(candidates[0])
        if chosen!=i:
            a[[i,chosen]]=a[[chosen,i]];sign=-sign
        pivot=int(a[i,col]);pivots.append(int(col));det=det*pivot%P
        factor=a[i+1:,col]*pow(pivot,-1,P)%P
        a[i+1:,col:]=(a[i+1:,col:]-factor[:,None]*a[i,col:])%P
    return pivots,det*sign%P


def main(mode):
    with np.load(FIX/'tokens.npz') as t, np.load(FIX/'layer00-self_attn_q_proj.npz') as f:
        ids=t['train'].ravel();positions=first_seen_positions(ids)
        assert len(positions)==896
        trainids=set(map(int,ids))
        heldids=t['validation'].ravel()
        heldpos=next(i for i,key in enumerate(heldids) if int(key) not in trainids)
        rows=np.concatenate([f['train'][positions],f['validation'][heldpos:heldpos+1]],axis=0)
    if mode=='find':
        pivots,det=eliminate(dyadic_mod(rows))
        receipt={'prime':P,'dyadic_scale_exponent':149,'train_positions':positions,
                 'added_held_position':heldpos,'added_token_id':int(heldids[heldpos]),
                 'pivot_columns':pivots,'determinant_mod_prime':det,'certified_rank':len(pivots)}
        assert len(pivots)==897 and det!=0
        (HERE/'rank-witness.json').write_text(json.dumps(receipt,indent=2)+'\n')
    else:
        receipt=json.loads((HERE/'rank-witness.json').read_text())
        assert receipt['train_positions']==positions and receipt['added_held_position']==heldpos
        pivots,det=eliminate(dyadic_mod(rows[:,receipt['pivot_columns']]),range(897))
        assert len(pivots)==897 and det==receipt['determinant_mod_prime']!=0
    print('exact rational row rank lower bound',897,'minor determinant mod',P,det,'held token',int(heldids[heldpos]))

if __name__=='__main__':main(sys.argv[1])
