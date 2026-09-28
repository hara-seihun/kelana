#!/usr/bin/env python3
"""Plain group-128 scalar RTN control at the same tied-head observation."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import evaluate

HERE=Path(__file__).resolve().parent
DATA=evaluate.DATA
MODEL=evaluate.MODEL
ROWS=evaluate.ROWS
COLS=evaluate.COLS


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def run(bits):
    hidden,original,gold,_train,valcounts,w,_raw=evaluate.load()
    blocks=w.reshape(ROWS,8,128)
    top=2**(bits-1)-0.5
    scale=(blocks.__abs__().max(axis=2)/top).clip(min=1e-20).astype(np.float16)
    if (scale<=0).any() or not np.isfinite(scale).all():raise ValueError('invalid RTN scale')
    levels=(w.reshape(ROWS,8,128)/scale[:,:,None].astype(np.float32)+top).round().clip(0,2**bits-1).astype(np.uint8)
    codes=levels.reshape(ROWS,COLS)
    packed=np.zeros((ROWS,COLS*bits//8),np.uint8)
    per=8//bits
    for i in range(per):packed |= (codes[:,i::per] << (bits*i))
    decoded=np.empty_like(codes)
    for i in range(per):decoded[:,i::per]=(packed>>(bits*i)) & ((1<<bits)-1)
    if not np.array_equal(decoded,codes):raise ValueError('scalar packet round trip')
    reconstruction=((decoded.reshape(ROWS,8,128).astype(np.float32)-top)*scale[:,:,None].astype(np.float32)).reshape(ROWS,COLS)
    scores=hidden@reconstruction.T
    valid=np.flatnonzero(valcounts)
    diff=(reconstruction[valid]-w[valid]).astype(np.float64)
    source=w[valid].astype(np.float64)
    weighted=float(np.sqrt((valcounts[valid]*(diff*diff).sum(1)).sum() /
                           (valcounts[valid]*(source*source).sum(1)).sum()))
    image=DATA/f'rtn{bits}.npz'
    np.savez_compressed(image,packed=packed,scales=scale)
    payload=packed.nbytes+scale.nbytes
    model_source=json.loads((MODEL/'source.json').read_text())
    result={'format':'qwen3-tied-scalar-control/1','method':f'group128-RTN{bits}-symmetric-midrise',
        'model_revision':model_source['revision'],
        'model_safetensors_sha256':model_source['files']['model.safetensors']['sha256'],
        'source_sha256':sha(Path(__file__)),'evaluate_source_sha256':sha(Path(evaluate.__file__)),
        'capture_sha256':sha(DATA/'final-head.npz'),
        'frequency_sha256':sha(DATA/'frequency.npz'),
        'paid_bytes':int(payload),'bits_per_tied_weight':8*payload/(ROWS*COLS),
        'packed_codes_bytes':int(packed.nbytes),'fp16_group_scales_bytes':int(scale.nbytes),
        'image_sha256':sha(image),
        'validation_frequency_weighted_embedding_relative_rms':weighted,
        'numerical_boundary':'group128 scalar RTN quantized tied matrix expanded to FP32 for output evaluation on fixed original-model final inputs; input embedding changes not propagated',
        'head':evaluate.quality(original,scores,gold)}
    (DATA/f'rtn{bits}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'method':result['method'],'bits':result['bits_per_tied_weight'],
         'embedding_rms':weighted,'head':result['head']}))


if __name__=='__main__':
    if len(sys.argv)!=2 or int(sys.argv[1]) not in (2,4):raise SystemExit('scalar.py 2 | 4')
    run(int(sys.argv[1]))
