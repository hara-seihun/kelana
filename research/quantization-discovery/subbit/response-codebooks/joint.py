#!/usr/bin/env python3
"""Share activation-aware codebooks across groups of input segments."""
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


def run(filename):
    path=DATA/filename
    manifest=json.loads((DATA/'manifest.json').read_text())
    if study.sha(path)!=manifest['files'][filename]['sha256']:
        raise ValueError('fixture identity mismatch')
    with np.load(path) as f:
        original=f['weight'].copy();xtrain=f['train'].copy();xval=f['validation'].copy()
    rng=np.random.default_rng(SEED)
    rows,cols=original.shape
    w=original[rng.permutation(rows)]
    ntrain=rows*3//4
    norm,scale=float_model.normalized(w)
    mu=xtrain.mean(0)
    records={}
    for length,k,group_count in ((16,256,1),(16,256,2),(16,256,4),(16,256,8),
                                 (8,64,1),(8,64,2),(8,64,4)):
        study.LENGTH=length
        segments=cols//length
        vectors=norm.reshape(rows,segments,length)
        groups=np.minimum(np.arange(segments)*group_count//segments,group_count-1)
        covariance=[]
        for s in range(segments):
            q=xtrain[:,s*length:(s+1)*length]
            covariance.append(q.T@q/len(q))
        covariance=np.asarray(covariance)
        codes=[]; units=[]
        for group in range(group_count):
            selections=np.flatnonzero(groups==group)
            observations=vectors[:ntrain,selections,:].reshape(-1,length)
            observations=observations[rng.choice(len(observations),min(8192,len(observations)),replace=False)]
            factor=np.linalg.cholesky(covariance[selections].mean(0))
            transformed=study.train_kmeans(observations@factor,k,rng)
            centers=np.linalg.solve(factor.T,transformed.T).T
            unit=max(1/64,float(np.max(np.abs(centers)))/127)
            codes.append(np.rint(centers/unit).astype(np.int8));units.append(unit)
        labels=np.empty((rows,segments),np.uint8)
        approx=np.empty((rows,segments,length),np.float32)
        for s in range(segments):
            g=groups[s]
            factor=np.linalg.cholesky(covariance[s])
            labels[:,s]=study.distances(vectors[:,s]@factor,codes[g].astype(np.float32)*units[g]@factor).argmin(1)
            approx[:,s]=codes[g][labels[:,s]].astype(np.float32)*units[g]*scale[:,s*length//128,None]
        approx=approx.reshape(rows,cols)
        # Validate a real packed response without expanding weight vectors.
        packet=wire.pack_labels(labels[-8:],int(np.log2(k)))
        recovered=wire.unpack_labels(packet,segments,int(np.log2(k)))
        output=np.zeros((3,8),np.float64)
        for s in range(segments):
            g=groups[s]
            table=xval[:3,s*length:(s+1)*length]@codes[g].astype(np.float32).T
            output+=table[:,recovered[:,s]].astype(np.float64)*units[g]*scale[-8:,s*length//128]
        np.testing.assert_allclose(output,xval[:3].astype(np.float64)@approx[-8:].astype(np.float64).T,
                                   rtol=3e-4,atol=3e-3)
        for exceptions in (0,1) if (length,k)==(16,256) else (0,):
            candidate=kproj.add_exceptions(w,approx,xtrain,exceptions) if exceptions else approx
            for affine in (False,True):
                bias=((w-candidate)@mu).astype(np.float16) if affine else None
                label_bytes=(segments*int(np.log2(k))+7)//8
                dictionary_bytes=sum(c.nbytes for c in codes)+4*group_count
                row_bytes=label_bytes+(cols//128)*(2+3*exceptions)+2*affine
                rate=8*(rows*row_bytes+dictionary_bytes)/(rows*cols)
                key=f'length{length}-k{k}-groups{group_count}-exceptions{exceptions}-affine{int(affine)}'
                records[key]={'total_bits_per_weight':rate,'dictionary_bytes':dictionary_bytes,
                    'table_bytes_per_input':segments*k*4,'table_integer_products_if_int8_input':segments*k*length,
                    'row_table_lookups':segments,'exception_gathers_per_row':cols//128*exceptions,
                    'train_input_held_rows_relative_rms':kproj.response_error(xtrain,w[ntrain:],candidate[ntrain:],None if bias is None else bias[ntrain:]),
                    'validation_input_held_rows_relative_rms':kproj.response_error(xval,w[ntrain:],candidate[ntrain:],None if bias is None else bias[ntrain:])}
    feasible={key:v for key,v in records.items() if v['total_bits_per_weight']<=0.9}
    selected=min(feasible,key=lambda n:feasible[n]['train_input_held_rows_relative_rms'])
    result={'format':'response-codebooks-joint/1','fixture':filename,
            'fixture_sha256':manifest['files'][filename]['sha256'],
            'manifest_sha256':study.sha(DATA/'manifest.json'),
            'source_hashes':{n:study.sha(HERE/n) for n in ('study.py','joint.py','wire.py','float_model.py','kproj.py')},
            'grouping':'contiguous equal-sized segments; each group has one shared codebook and one paid FP32 unit',
            'dictionary_training':'Lloyd in average train-input covariance per group; labels minimize their own segment train-input covariance',
            'selection':'smallest held-row train-input response RMS at <=0.9 paid bits/weight',
            'selected_on_train':selected,
            'selected_validation_relative_rms':records[selected]['validation_input_held_rows_relative_rms'],
            'row_split':'numpy default_rng(78123).permutation(rows); first floor(.75*rows) train, rest held',
            'input_split':'WikiText train 2048 inputs, validation 1024 inputs; test unused',
            'numerical_boundary':'FP32 output response, optionally affine; no downstream model quality',
            'methods':records}
    (HERE/('joint-'+filename.replace('.npz','.json'))).write_text(json.dumps(result,indent=2)+'\n')
    print(filename,'selected',selected,round(result['selected_validation_relative_rms'],4))
    for n,v in records.items():
        if 'affine1' in n and 'exceptions0' in n and ('length16' in n or 'groups1' in n):
            print(' ',n,round(v['total_bits_per_weight'],4),round(v['validation_input_held_rows_relative_rms'],4))


if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('joint.py layer00-self_attn_q_proj.npz')
    run(sys.argv[1])
