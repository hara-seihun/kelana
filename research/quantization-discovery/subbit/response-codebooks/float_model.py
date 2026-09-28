#!/usr/bin/env python3
"""Offline shared response codebooks on pinned Qwen floating weights."""
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open
import study

HERE = Path(__file__).resolve().parent
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b')
KEYS = {'down0':'model.layers.0.mlp.down_proj.weight',
        'down14':'model.layers.14.mlp.down_proj.weight',
        'head':'model.embed_tokens.weight'}
SEED = 78123


def weights_for(name):
    key=KEYS[name]
    rng=np.random.default_rng(SEED)
    with safe_open(MODEL/'model.safetensors',framework='pt',device='cpu') as f:
        tensor=f.get_tensor(key)
        total_rows, cols=tensor.shape
        ntrain,nheld=(4096,512) if name=='head' else (768,256)
        ids=rng.choice(total_rows,ntrain+nheld,replace=False)
        selected=tensor.index_select(0,torch.as_tensor(ids.astype(np.int64))).to(torch.float32).numpy().copy()
    return selected,ids,ntrain,total_rows,cols


def normalized(w):
    rows,cols=w.shape
    blocks=w.reshape(rows,cols//128,128)
    scale=np.sqrt(np.mean(blocks*blocks,axis=2))*3.5
    scale=np.maximum(scale,1.e-7).astype(np.float16).astype(np.float32)
    return (blocks/scale[:,:,None]).reshape(rows,cols),scale


def reconstructed(normal,scale,codes,labels,length,unit):
    rows,cols=normal.shape
    result=(codes[labels].reshape(rows,cols).astype(np.float32)*unit)
    return (result.reshape(rows,cols//128,128)*scale[:,:,None]).reshape(rows,cols)


def metric(w,predicted,ntrain,q):
    true=w[ntrain:]
    approx=predicted[ntrain:]
    error=true-approx
    # Isotropic probe is a check on all coordinates, not an activation claim.
    relative=np.linalg.norm(error.astype(np.float64))/np.linalg.norm(true.astype(np.float64))
    target=q@true.T
    output=q@approx.T
    response=np.linalg.norm((output-target).astype(np.float64))/np.linalg.norm(target.astype(np.float64))
    return {'held_weight_relative_frobenius':float(relative),
            'held_gaussian_response_relative_rms':float(response),
            'held_weights':int(true.size)}


def main(name):
    begin=time.perf_counter()
    w,ids,ntrain,all_rows,cols=weights_for(name)
    rng=np.random.default_rng(SEED)
    probe=np.random.default_rng(SEED+1).standard_normal((16,cols),dtype=np.float32)
    normal,scale=normalized(w)
    records={}
    for length,k in ((16,64),(16,256),(8,16),(8,64)):
        study.LENGTH=length
        segments=cols//length
        vector=normal.reshape(len(w),segments,length)
        train=vector[:ntrain].reshape(-1,length)
        train=train[rng.choice(len(train),8192,replace=False)]
        centers=study.train_kmeans(train,k,rng)
        unit=max(1/64,float(np.max(np.abs(centers)))/127)
        codes=np.rint(centers/unit).astype(np.int8)
        labels=np.empty((len(w),segments),np.uint8)
        for s in range(segments):
            labels[:,s]=study.distances(vector[:,s],codes.astype(np.float32)*unit).argmin(1)
        decoded=reconstructed(normal,scale,codes,labels,length,unit)
        for exceptions in (0,1,2) if (length,k)==(16,64) else (0,1) if (length,k)==(16,256) else (0,):
            approx=decoded.copy()
            if exceptions:
                residual=(w-approx).reshape(len(w),cols//128,128)
                pick=np.argpartition(abs(residual),-exceptions,axis=2)[:,:,-exceptions:]
                values=np.take_along_axis(residual,pick,axis=2).astype(np.float16).astype(np.float32)
                np.put_along_axis(approx.reshape(len(w),cols//128,128),pick,
                                  np.take_along_axis(approx.reshape(len(w),cols//128,128),pick,axis=2)+values,axis=2)
            b=int(np.log2(k))
            payload_per_row=(segments*b+7)//8 + cols//128*(2+exceptions*3)
            dictionary_bytes=codes.nbytes+4
            key=f'length{length}-k{k}-exceptions{exceptions}'
            records[key]={'length':length,'codes':k,'exceptions_per_128':exceptions,
                'label_bits_per_row':segments*b,'dictionary_bytes':dictionary_bytes,
                'codebook_unit_fp32':unit,
                'scales_bytes_per_row':cols//128*2,'exception_bytes_per_row':cols//128*exceptions*3,
                'packed_bytes_per_row':payload_per_row,
                'bits_per_weight_full_matrix':8*(all_rows*payload_per_row+dictionary_bytes)/(all_rows*cols),
                'bits_per_weight_sample':8*(len(w)*payload_per_row+dictionary_bytes)/(len(w)*cols),
                'table_bytes_per_query':segments*k*4,
                'row_table_lookups':segments,
                'online_table_integer_products_if_int8_query':segments*k*length,
                **metric(w,approx,ntrain,probe)}
    manifest=json.loads((MODEL/'source.json').read_text())
    result={'format':'response-codebooks-float/1', 'model_repository':manifest['repository'],
            'model_revision':manifest['revision'],
            'model_safetensors_sha256':manifest['files']['model.safetensors']['sha256'],
            'source_manifest_sha256':study.sha(MODEL/'source.json'),
            'script_sha256':study.sha(Path(__file__)),
            'study_source_sha256':study.sha(Path(study.__file__)),
            'tensor':KEYS[name],'tensor_shape':[all_rows,cols],
            'sample_row_ids_sha256':__import__('hashlib').sha256(ids.tobytes()).hexdigest(),
            'row_selection':'numpy default_rng(seed).choice(all_rows, train+held, replace=False); first train rows fit dictionary',
            'train_rows':ntrain,'held_rows':len(w)-ntrain,
            'seed':SEED,'scale':'FP16 per row/128; 3.5 times row-block RMS',
            'dictionary':'one shared int8 codebook and FP32 coefficient unit per tensor and method; unit at least 1/64',
            'probe':'16 synthetic standard-normal inputs; not model activations',
            'methods':records,'elapsed_seconds':time.perf_counter()-begin}
    output=HERE/f'float-{name}.json'
    output.write_text(json.dumps(result,indent=2)+'\n')
    for k,v in records.items():
        print(k,round(v['bits_per_weight_full_matrix'],4),
              round(v['held_gaussian_response_relative_rms'],4),
              round(v['held_weight_relative_frobenius'],4))
    print('elapsed',result['elapsed_seconds'])


if __name__=='__main__':
    if len(sys.argv)!=2 or sys.argv[1] not in KEYS:
        raise SystemExit('float_model.py down0 | down14 | head')
    main(sys.argv[1])
