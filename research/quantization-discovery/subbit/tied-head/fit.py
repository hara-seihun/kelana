#!/usr/bin/env python3
"""Learn a shared short-vector head dictionary and encode all tied rows."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
import codec

DATA=Path('/path/to/workspace/data/kelana-subbit/tied-head')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b')
LENGTH=16
ROWS=151936
COLS=1024
SEED=32133


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def source_weights():
    with safe_open(MODEL/'model.safetensors',framework='pt',device='cpu') as f:
        embedding=f.get_tensor('model.embed_tokens.weight')
        head=f.get_tensor('lm_head.weight')
        if not torch.equal(embedding.view(torch.int16),head.view(torch.int16)):
            raise ValueError('head and embedding are not bitwise tied')
        w=embedding.float().numpy().copy()
    if w.shape!=(ROWS,COLS):raise ValueError('tied matrix shape changed')
    return w


def fit(k):
    model=json.loads((MODEL/'source.json').read_text())
    if sha(MODEL/'model.safetensors')!=model['files']['model.safetensors']['sha256']:
        raise ValueError('model bytes differ from pinned revision')
    with np.load(DATA/'final-head.npz') as capture:
        train=capture['train_hidden'].copy()
    rng=np.random.default_rng(SEED+k)
    w=source_weights()
    blocks=w.reshape(ROWS,COLS//128,128)
    scales=(3.5*np.sqrt(np.mean(blocks*blocks,axis=2))).astype(np.float16)
    if not np.isfinite(scales).all() or (scales<=0).any():raise ValueError('invalid FP16 block scale')
    scale_f=scales.astype(np.float32)
    segments=COLS//LENGTH
    cov=[]
    for s in range(segments):
        x=train[:,s*LENGTH:(s+1)*LENGTH]
        cov.append(x.T@x/len(x))
    cov=np.asarray(cov)
    average=np.linalg.cholesky(cov.mean(0))
    picked_rows=rng.integers(0,ROWS,size=8192)
    picked_segments=rng.integers(0,segments,size=8192)
    sample=np.empty((8192,LENGTH),np.float32)
    for i,(r,s) in enumerate(zip(picked_rows,picked_segments)):
        sample[i]=w[r,s*LENGTH:(s+1)*LENGTH]/scale_f[r,s*LENGTH//128]
    centers_metric=codec.train_kmeans(sample@average,k,rng,steps=18)
    centers=np.linalg.solve(average.T,centers_metric.T).T
    unit=max(1/64,float(np.max(np.abs(centers)))/127)
    code=np.rint(centers/unit).astype(np.int8)
    labels=np.empty((ROWS,segments),np.uint8)
    centers_f=code.astype(np.float32)*unit
    for s in range(segments):
        factor=np.linalg.cholesky(cov[s])
        transformed=centers_f@factor
        block=s*LENGTH//128
        for start in range(0,ROWS,8192):
            stop=min(start+8192,ROWS)
            part=w[start:stop,s*LENGTH:(s+1)*LENGTH]/scale_f[start:stop,block,None]
            labels[start:stop,s]=codec.distances(part@factor,transformed).argmin(1)
    bits=int(np.log2(k))
    packed=codec.pack(labels,bits)
    restored=codec.unpack(packed,segments,bits)
    if not np.array_equal(restored,labels):raise ValueError('packed address round trip failed')
    image=DATA/f'codebook{k}.npz'
    np.savez_compressed(image,labels=packed,scales=scales,code=code,unit=np.asarray(unit,np.float32))
    receipt={'format':'qwen3-tied-codebook/1','k':k,'length':LENGTH,
        'tied_head_embedding_bitwise_equal':True,
        'model_revision':model['revision'],'model_safetensors_sha256':model['files']['model.safetensors']['sha256'],
        'capture_sha256':sha(DATA/'final-head.npz'),
        'frequency_sha256':sha(DATA/'frequency.npz'),
        'fit_source_sha256':sha(Path(__file__)),
        'codec_source_sha256':sha(Path(codec.__file__)),
        'seed':SEED+k,'dictionary_train_vectors':8192,
        'dictionary_metric':'mean of 64 position-specific train-hidden second moments; labels use each position full train moment',
        'scale':'FP16 per row/128, 3.5 times row-block RMS',
        'code_unit_fp32':unit,'labels_bytes':int(packed.nbytes),
        'scales_bytes':int(scales.nbytes),'codebook_bytes':int(code.nbytes+4),
        'total_payload_bytes':int(packed.nbytes+scales.nbytes+code.nbytes+4),
        'total_bits_per_tied_weight':8*(packed.nbytes+scales.nbytes+code.nbytes+4)/(ROWS*COLS),
        'transient_table_bytes_per_query':segments*k*4,
        'online_float_products_per_query_table':segments*k*LENGTH,
        'row_lookups_per_query':segments,
        'image_sha256':sha(image),
        'arrays':{name:{'shape':list(array.shape),'dtype':str(array.dtype),
                        'sha256':hashlib.sha256(array.tobytes()).hexdigest()} for name,array in
                  (('labels',packed),('scales',scales),('code',code))}}
    (DATA/f'codebook{k}.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'k':k,'rate':receipt['total_bits_per_tied_weight'],
        'image_sha256':receipt['image_sha256'],'image_bytes':image.stat().st_size}))


if __name__=='__main__':
    if len(sys.argv)!=2 or int(sys.argv[1]) not in (64,256):raise SystemExit('fit.py 64 | 256')
    fit(int(sys.argv[1]))
