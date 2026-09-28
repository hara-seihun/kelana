#!/usr/bin/env python3
"""Measure which hidden-activation errors a real down projection can hide."""
import argparse
import hashlib
import json
from pathlib import Path
import time
import numpy as np
from probe import effective_weight
from gguf_read import Gguf


def rank_mod(matrix, prime=65521):
    a = np.asarray(matrix, dtype=np.int64).copy() % prime
    rank = 0
    pivots = []
    determinant = 1
    for col in range(a.shape[1]):
        hits = np.flatnonzero(a[rank:, col])
        if not len(hits):
            continue
        pivot = rank + int(hits[0])
        if pivot != rank:
            a[[rank, pivot]] = a[[pivot, rank]]
            determinant = -determinant
        value = int(a[rank, col])
        determinant = determinant * value % prime
        a[rank] = a[rank] * pow(value, -1, prime) % prime
        if rank+1 < len(a):
            a[rank+1:] = (a[rank+1:] - a[rank+1:, col, None] * a[rank]) % prime
        pivots.append([col, pivot, value])
        rank += 1
        if rank == len(a):
            break
    return {'rank': rank, 'prime': prime, 'determinant_mod_prime': determinant if rank==len(a)==a.shape[1] else None,
            'elimination_pivots': pivots}


def spectrum(a):
    gram = a.T @ a
    norms = np.sqrt(np.diag(gram))
    normalized = gram / norms[:, None] / norms[None, :]
    eigen = np.linalg.eigvalsh(normalized)
    return {'columns': a.shape[1], 'rows': a.shape[0],
            'normalized_gram_eigen_min': float(eigen[0]), 'normalized_gram_eigen_max': float(eigen[-1]),
            'column_norm_min': float(norms.min()), 'column_norm_max': float(norms.max()),
            'mean_abs_offdiagonal_cosine': float(np.sum(np.abs(normalized-np.eye(len(norms))))/(len(norms)*(len(norms)-1)))}


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--model', default='/path/to/workspace/data/bonsai2/PTQ1_0.gguf')
    p.add_argument('--layer', type=int, default=0)
    p.add_argument('--out', type=Path, required=True)
    args=p.parse_args(); started=time.monotonic()
    model=Gguf(args.model); name=f'blk.{args.layer}.ffn_down.weight'
    shape=model.tensors[name][0]
    trits, scales=model.rows_ptq1_0(name,0,shape[1])
    trits=trits.reshape(shape[1],shape[0]); scales=scales.reshape(shape[1],-1)
    a=trits.astype(np.float64).reshape(shape[1],-1,128)*scales[:,:,None]
    a=a.reshape(shape[1],shape[0])
    records=[]
    for group in (0,1,7,16,32,64,100,135):
        sl=slice(group*128,(group+1)*128)
        certificate=rank_mod(trits[:128,sl])
        certificate['row_scale_nonzero']=bool(np.all(scales[:128,group]!=0))
        certificate['integer_submatrix_sha256']=hashlib.sha256(trits[:128,sl].astype(np.int8).tobytes()).hexdigest()
        records.append({'group':group,'spectrum':spectrum(a[:,sl]),'rank_certificate':certificate})
    rng=np.random.default_rng(7319)
    cross=[]
    for size in (128,512,1024):
        columns=rng.choice(shape[0],size,replace=False)
        cross.append({'column_indices':columns.tolist(),'spectrum':spectrum(a[:,columns])})
    result={'model':args.model,'layer':args.layer,'matrix_shape':list(a.shape),
            'scope':'Down projection in real arithmetic after activation dequantization; sampled supports only. Modular certificates use first128 output rows within one scale block, where nonzero row scales preserve rank. Spectra are numeric, not universal sparse-nullspace bounds.',
            'dimension_nullity_lower_bound':int(a.shape[1]-a.shape[0]),
            'within_scale_groups':records,'cross_group_supports':cross,'seconds':time.monotonic()-started}
    args.out.write_text(json.dumps(result,indent=2)+'\n')
    for r in records: print(r['group'],r['rank_certificate']['rank'],r['spectrum']['normalized_gram_eigen_min'])
    for r in cross: print('cross',r['spectrum']['columns'],r['spectrum']['normalized_gram_eigen_min'])
    print('seconds',result['seconds'])

if __name__=='__main__': main()
