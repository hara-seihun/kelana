#!/usr/bin/env python3
"""Cross-row low-rank response correction atop directly consumed labels."""
import json
import sys
from pathlib import Path

import numpy as np
import study
import float_model
import kproj
import wire

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')
SEED=78123


def factorize(residual,inputs,rank,rng):
    """Power iteration in train-response space, with input-factor witnesses."""
    rows,cols=residual.shape
    q,_=np.linalg.qr(rng.standard_normal((rows,rank),dtype=np.float32))
    for _ in range(6):
        input_response=inputs@(residual.T@q)
        left,_=np.linalg.qr(input_response)
        q,_=np.linalg.qr(residual@(inputs.T@left))
    candidate=residual.T@q
    left,triangle=np.linalg.qr(inputs@candidate)
    v=candidate@np.linalg.inv(triangle)
    a=residual@(inputs.T@left)
    return v.astype(np.float16).astype(np.float32),a.astype(np.float16).astype(np.float32)


def run(filename):
    manifest=json.loads((DATA/'manifest.json').read_text())
    path=DATA/filename
    if study.sha(path)!=manifest['files'][filename]['sha256']:
        raise ValueError('fixture identity mismatch')
    with np.load(path) as f:
        original=f['weight'].copy();xtrain=f['train'].copy();xval=f['validation'].copy()
    rng=np.random.default_rng(SEED)
    rows,cols=original.shape
    w=original[rng.permutation(rows)]
    ntrain=rows*3//4
    norm,scale=float_model.normalized(w)
    length=16;k=256;segments=cols//length
    study.LENGTH=length
    vectors=norm.reshape(rows,segments,length)
    fit=vectors[:ntrain].reshape(-1,length)
    fit=fit[rng.choice(len(fit),8192,replace=False)]
    centers=study.train_kmeans(fit,k,rng)
    unit=max(1/64,float(np.max(np.abs(centers)))/127)
    codes=np.rint(centers/unit).astype(np.int8)
    labels=np.empty((rows,segments),np.uint8)
    for s in range(segments):
        q=xtrain[:,s*length:(s+1)*length]
        factor=np.linalg.cholesky(q.T@q/len(q))
        labels[:,s]=study.distances(vectors[:,s]@factor,codes.astype(np.float32)*unit@factor).argmin(1)
    approx=float_model.reconstructed(norm,scale,codes,labels,length,unit)
    residual=w-approx
    mean=xtrain.mean(0)
    centered=xtrain-mean
    records={}
    for rank in (0,2,4,6,8):
        if rank:
            v,a=factorize(residual,centered,rank,rng)
            corrected=approx+a@v.T
        else:
            v=np.empty((cols,0));a=np.empty((rows,0));corrected=approx
        for exceptions in (0,1) if rank==2 else (0,):
            candidate,sparse=kproj.add_exceptions(w,corrected,xtrain,exceptions,return_sparse=True) if exceptions else (corrected,None)
            bias=((w-candidate)@mean).astype(np.float16)
            # Labels, low-rank factors and exceptions compose directly as
            # responses. Check against an independent dense matrix product.
            packed=wire.pack_labels(labels[-8:],8)
            base=wire.observe(packed,codes,unit,scale[-8:],xval[:3],bias=bias[-8:],
                              exceptions=None if sparse is None else tuple(item[-8:] for item in sparse))
            direct=base+(xval[:3]@v)@a[-8:].T
            independent=xval[:3].astype(np.float64)@candidate[-8:].astype(np.float64).T+bias[-8:][None,:]
            np.testing.assert_allclose(direct,independent,rtol=4e-4,atol=4e-3)
            label_bytes=segments
            static=rows*(label_bytes+2*(cols//128)+2+3*(cols//128)*exceptions)+codes.nbytes+4+2*rank*(rows+cols)
            key=f'rank{rank}-exceptions{exceptions}'
            records[key]={'total_bits_per_weight':8*static/(rows*cols),
                'dictionary_bytes':codes.nbytes+4,
                'lowrank_factor_bytes':2*rank*(rows+cols),'affine_bias_bytes':2*rows,
                'sparse_exception_bytes':3*(cols//128)*exceptions*rows,
                'table_bytes_per_input':segments*k*4,
                'row_table_lookups':segments,'input_correction_dot_products':rank,
                'row_correction_multiply_adds':rank,
                'train_input_held_rows_relative_rms':kproj.response_error(xtrain,w[ntrain:],candidate[ntrain:],bias[ntrain:]),
                'validation_input_held_rows_relative_rms':kproj.response_error(xval,w[ntrain:],candidate[ntrain:],bias[ntrain:])}
    result={'format':'response-codebooks-lowrank/1','fixture':filename,
        'fixture_sha256':manifest['files'][filename]['sha256'],
        'manifest_sha256':study.sha(DATA/'manifest.json'),
        'source_hashes':{n:study.sha(HERE/n) for n in ('study.py','float_model.py','kproj.py','wire.py','lowrank.py')},
        'weight_row_split':'default_rng(78123).permutation(rows); first floor(.75*rows) train codebook; all row residuals fit low-rank correction using train inputs only',
        'input_split':'2048 WikiText train inputs fit covariance, response rank and bias; 1024 validation inputs held out; test unused',
        'rank_fit':'six block power iterations on centered train-response residual; two FP16 factor matrices; FP16 per-row mean correction',
        'numerical_boundary':'FP32 response of packed labels + FP16 factors + FP16 bias; no downstream model quality',
        'methods':records}
    (HERE/('lowrank-'+filename.replace('.npz','.json'))).write_text(json.dumps(result,indent=2)+'\n')
    print(filename)
    for name,v in records.items():print(name,round(v['total_bits_per_weight'],4),round(v['train_input_held_rows_relative_rms'],4),round(v['validation_input_held_rows_relative_rms'],4))


if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('lowrank.py layer00-self_attn_q_proj.npz')
    run(sys.argv[1])
