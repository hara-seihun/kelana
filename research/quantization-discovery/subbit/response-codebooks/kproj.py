#!/usr/bin/env python3
"""Activation-aware response codebooks on Qwen layer-0 K projection."""
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open
import study
import float_model

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit/binary-factors/activations')
KEY='model.layers.0.self_attn.k_proj.weight'
SEED=78123


def response_error(input_vectors, target, approximation, bias=None):
    reference=input_vectors@target.T
    error=input_vectors@(approximation-target).T
    if bias is not None:
        error=error+bias[None,:]
    return float(np.linalg.norm(error.astype(np.float64))/np.linalg.norm(reference.astype(np.float64)))


def add_exceptions(w,approx,xtrain,count,return_sparse=False):
    """Greedy block residual correction under train-input covariance only."""
    blocks=w.shape[1]//128
    revised=approx.copy().reshape(len(w),blocks,128)
    original=w.reshape(len(w),blocks,128)
    indices=np.empty((len(w),blocks,count),np.uint8)
    values=np.empty((len(w),blocks,count),np.float16)
    for block in range(blocks):
        x=xtrain[:,block*128:(block+1)*128]
        covariance=x.T@x/len(x)
        diagonal=np.diag(covariance)
        for j in range(count):
            residual=original[:,block]-revised[:,block]
            gain=2*residual*(residual@covariance)-residual*residual*diagonal
            index=gain.argmax(1)
            value=residual[np.arange(len(w)),index].astype(np.float16)
            indices[:,block,j]=index
            values[:,block,j]=value
            revised[np.arange(len(w)),block,index]+=value.astype(np.float32)
    result=revised.reshape(w.shape)
    return (result,(indices,values)) if return_sparse else result


def main():
    xtrain=np.load(DATA/'layer0_k_proj_train.npy')
    xtest=np.load(DATA/'layer0_k_proj_test.npy')
    rng=np.random.default_rng(SEED)
    with safe_open(float_model.MODEL/'model.safetensors',framework='pt',device='cpu') as f:
        tensor=f.get_tensor(KEY)
        ids=rng.permutation(tensor.shape[0])
        w=tensor.index_select(0,torch.as_tensor(ids)).to(torch.float32).numpy().copy()
    ntrain=768
    assert len(w)==1024
    norm,scale=float_model.normalized(w)
    records={}
    for length,k in ((16,64),(16,256),(8,16),(8,64)):
        study.LENGTH=length
        segments=1024//length
        vectors=norm.reshape(len(w),segments,length)
        fit=vectors[:ntrain].reshape(-1,length)
        fit=fit[rng.choice(len(fit),8192,replace=False)]
        centers=study.train_kmeans(fit,k,rng)
        unit=max(1/64,float(np.max(np.abs(centers)))/127)
        codes=np.rint(centers/unit).astype(np.int8)
        for alpha in (0.,0.25,0.5,0.75,1.0):
            labels=np.empty((len(w),segments),np.uint8)
            for s in range(segments):
                q=xtrain[:,s*length:(s+1)*length]
                covariance=q.T@q/len(q)
                variance=np.trace(covariance)/length
                factor=np.linalg.cholesky(alpha*covariance + (1-alpha)*variance*np.eye(length))
                labels[:,s]=study.distances(vectors[:,s]@factor,codes.astype(np.float32)*unit@factor).argmin(1)
            approximated=float_model.reconstructed(norm,scale,codes,labels,length,unit)
            key=f'length{length}-k{k}-alpha{alpha:g}'
            rate=8*((1024//length*int(np.log2(k))+7)//8+1024//128*2)/1024+8*(codes.nbytes+4)/(len(w)*1024)
            for exceptions in ((0,1,2) if (length,k,alpha)==(16,64,1.) else
                               (0,1) if (length,k,alpha)==(16,256,1.) else (0,)):
                candidate=add_exceptions(w,approximated,xtrain,exceptions) if exceptions else approximated
                suffix=f'-exceptions{exceptions}' if exceptions else ''
                records[key+suffix]={'bits_per_weight':rate+exceptions*8*3/128,
                    'codebook_unit':unit,'dictionary_bytes':codes.nbytes+4,
                    'exceptions_per_128':exceptions,'exception_bytes_per_row':exceptions*3*8,
                    'train_input_held_rows_relative_rms':response_error(xtrain,w[ntrain:],candidate[ntrain:]),
                    'test_input_held_rows_relative_rms':response_error(xtest,w[ntrain:],candidate[ntrain:]),
                    'held_weight_relative_frobenius':float(np.linalg.norm((w[ntrain:]-candidate[ntrain:]).astype(np.float64))/np.linalg.norm(w[ntrain:].astype(np.float64))),
                    'table_bytes_per_query':segments*k*4,'row_table_lookups':segments}
    source=json.loads((float_model.MODEL/'source.json').read_text())
    result={'format':'response-codebooks-kproj/1','tensor':KEY,
        'model_revision':source['revision'],'model_safetensors_sha256':source['files']['model.safetensors']['sha256'],
        'train_activations_sha256':study.sha(DATA/'layer0_k_proj_train.npy'),
        'test_activations_sha256':study.sha(DATA/'layer0_k_proj_test.npy'),
        'train_metadata_sha256':study.sha(DATA/'layer0_k_proj_train.json'),
        'test_metadata_sha256':study.sha(DATA/'layer0_k_proj_test.json'),
        'study_source_sha256':study.sha(Path(study.__file__)),
        'float_source_sha256':study.sha(Path(float_model.__file__)),
        'script_sha256':study.sha(Path(__file__)),
        'row_split':'numpy default_rng(78123).permutation(1024); first 768 dictionary train, last 256 held',
        'train_input':'first 512 WikiText raw train tokens, embedding then layer0 input RMSNorm',
        'test_input':'first 512 WikiText raw test tokens, embedding then layer0 input RMSNorm',
        'numerical_boundary':'FP32 X @ BF16-source W.T versus FP32 X @ quantized W.T; no downstream attention or model quality',
        'exception_selection':'greedy residual correction under train-input covariance per 128-column block; fixed index u8 and residual f16 paid per exception',
        'methods':records}
    (HERE/'kproj-results.json').write_text(json.dumps(result,indent=2)+'\n')
    for name,v in records.items():print(name,round(v['bits_per_weight'],4),round(v['train_input_held_rows_relative_rms'],4),round(v['test_input_held_rows_relative_rms'],4))

if __name__=='__main__':
    main()
