#!/usr/bin/env python3
"""Split-weight, split-corpus response measurements on captured Qwen inputs."""
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


def main(name):
    manifest=json.loads((DATA/'manifest.json').read_text())
    if name not in manifest['files']:
        raise ValueError('module not in pinned fixture manifest')
    path=DATA/name
    if study.sha(path)!=manifest['files'][name]['sha256']:
        raise ValueError('fixture does not match manifest')
    with np.load(path) as z:
        original=z['weight'].copy()
        xtrain=z['train'].copy()
        xvalidation=z['validation'].copy()
    rows,cols=original.shape
    assert cols%128==0 and xtrain.shape==(2048,cols) and xvalidation.shape==(1024,cols)
    rng=np.random.default_rng(SEED)
    ids=rng.permutation(rows)
    w=original[ids]
    ntrain=rows*3//4
    norm,scale=float_model.normalized(w)
    train_mean=xtrain.mean(axis=0)
    records={}
    for length,k in ((16,64),(16,256),(8,64)):
        study.LENGTH=length
        segments=cols//length
        vector=norm.reshape(rows,segments,length)
        train=vector[:ntrain].reshape(-1,length)
        train=train[rng.choice(len(train),8192,replace=False)]
        centers=study.train_kmeans(train,k,rng)
        unit=max(1/64,float(np.max(np.abs(centers)))/127)
        codes=np.rint(centers/unit).astype(np.int8)
        # Train-input covariance is computed once per segment, without touching
        # validation. The full empirical metric is well supported by 2048 inputs.
        covariance=[]
        for s in range(segments):
            q=xtrain[:,s*length:(s+1)*length]
            covariance.append(q.T@q/len(q))
        for alpha in (0.,0.5,1.):
            labels=np.empty((rows,segments),np.uint8)
            for s in range(segments):
                cov=covariance[s]
                variance=np.trace(cov)/length
                factor=np.linalg.cholesky(alpha*cov + (1-alpha)*variance*np.eye(length))
                labels[:,s]=study.distances(vector[:,s]@factor,codes.astype(np.float32)*unit@factor).argmin(1)
            approx=float_model.reconstructed(norm,scale,codes,labels,length,unit)
            for exceptions in (0,1) if (length,k,alpha)==(16,256,1.) else (0,):
                candidate,sparse=kproj.add_exceptions(w,approx,xtrain,exceptions,return_sparse=True) if exceptions else (approx,None)
                bit_count=segments*int(np.log2(k))
                payload=((bit_count+7)//8)+(cols//128)*(2+3*exceptions)
                for affine in (False,True) if alpha==1. else (False,):
                    bias=((w-candidate)@train_mean).astype(np.float16) if affine else None
                    paid=8*(rows*(payload+2*affine)+codes.nbytes+4)/(rows*cols)
                    key=f'length{length}-k{k}-alpha{alpha:g}-exceptions{exceptions}-affine{int(affine)}'
                    records[key]={'total_bits_per_weight':paid,'label_bytes_per_row':(bit_count+7)//8,
                        'scale_bytes_per_row':cols//128*2,
                        'exception_bytes_per_row':cols//128*3*exceptions,
                        'affine_bias_bytes_per_row':2*affine,
                        'dictionary_bytes':codes.nbytes+4,'codebook_unit':unit,
                        'table_bytes_per_input':segments*k*4,
                        'table_integer_products_if_int8_input':segments*k*length,
                        'row_table_lookups':segments,
                        'row_exception_gathers':cols//128*exceptions,
                        'train_input_held_rows_relative_rms':kproj.response_error(xtrain,w[ntrain:],candidate[ntrain:],None if bias is None else bias[ntrain:]),
                        'validation_input_held_rows_relative_rms':kproj.response_error(xvalidation,w[ntrain:],candidate[ntrain:],None if bias is None else bias[ntrain:]),
                        'held_weight_relative_frobenius':float(np.linalg.norm((w[ntrain:]-candidate[ntrain:]).astype(np.float64))/np.linalg.norm(w[ntrain:].astype(np.float64)))}
                    # Check a packed direct response against an independently
                    # decoded dense matrix. This catches label/scale/exception
                    # address mistakes before any claimed quality result.
                    packet=wire.pack_labels(labels[-8:],int(np.log2(k)))
                    sparse_tail=None if sparse is None else tuple(a[-8:] for a in sparse)
                    direct=wire.observe(packet,codes,unit,scale[-8:],xvalidation[:3],
                                        exceptions=sparse_tail,bias=None if bias is None else bias[-8:])
                    dense=xvalidation[:3].astype(np.float64)@candidate[-8:].astype(np.float64).T
                    if bias is not None:dense+=bias[-8:][None,:]
                    np.testing.assert_allclose(direct,dense,rtol=3e-4,atol=3e-3)
    feasible={name:r for name,r in records.items() if r['total_bits_per_weight']<=0.9}
    selected=min(feasible,key=lambda n:feasible[n]['train_input_held_rows_relative_rms'])
    output={'format':'response-codebooks-real-inputs/1',
        'fixture_manifest_sha256':study.sha(DATA/'manifest.json'),
        'fixture_sha256':manifest['files'][name]['sha256'],
        'model_revision':manifest['model_revision'],
        'module':manifest['files'][name]['module'],'weight_shape':[rows,cols],
        'train_input_shape':list(xtrain.shape),'validation_input_shape':list(xvalidation.shape),
        'train_corpus_window_starts':manifest['window_starts']['train'],
        'validation_corpus_window_starts':manifest['window_starts']['validation'],
        'row_split':'numpy default_rng(78123).permutation(rows); first floor(.75*rows) train dictionary, rest held',
        'train_weight_rows':ntrain,'held_weight_rows':rows-ntrain,
        'numerical_boundary':'FP32 input @ original BF16-origin float32 weights versus reconstructed FP32 weights, optionally plus learned FP16 output mean; no model continuation or deployed BF16 rounding',
        'consumer_check':'every arm checks a packed-label response plus scales, sparse residuals and optional affine output against an independently decoded dense matrix on 3 validation inputs x 8 rows',
        'selection':'minimum held-row training-input relative RMS among candidates with <=0.9 paid bits/weight',
        'selected_on_train':selected,
        'selected_validation_relative_rms':records[selected]['validation_input_held_rows_relative_rms'],
        'source_hashes':{file:study.sha(HERE/file) for file in ('study.py','float_model.py','kproj.py','wire.py','real_inputs.py')},
        'methods':records}
    (HERE/('real-'+name.replace('.npz','.json'))).write_text(json.dumps(output,indent=2)+'\n')
    print(name, selected, 'rate',round(feasible[selected]['total_bits_per_weight'],4),
          'train',round(feasible[selected]['train_input_held_rows_relative_rms'],4),
          'validation',round(output['selected_validation_relative_rms'],4))
    for key,record in records.items():
        if 'alpha1-' in key:
            print(' ',key,round(record['total_bits_per_weight'],4),
                round(record['train_input_held_rows_relative_rms'],4),
                round(record['validation_input_held_rows_relative_rms'],4))


if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('real_inputs.py layer00-mlp_down_proj.npz')
    main(sys.argv[1])
