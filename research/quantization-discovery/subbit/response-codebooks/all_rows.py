#!/usr/bin/env python3
"""Model-specific dictionaries fitted to every known row; validation inputs held out."""
import json
import sys
from pathlib import Path

import numpy as np
import study
import float_model
import kproj
import lowrank
import wire

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')
SEED=78123


def run(filename):
    manifest=json.loads((DATA/'manifest.json').read_text())
    path=DATA/filename
    if study.sha(path)!=manifest['files'][filename]['sha256']:
        raise ValueError('fixture identity mismatch')
    with np.load(path) as f:
        w=f['weight'].copy();xtrain=f['train'].copy();xval=f['validation'].copy()
    rows,cols=w.shape
    norm,scale=float_model.normalized(w)
    mean=xtrain.mean(0)
    centered=xtrain-mean
    records={}
    for length,k in ((16,64),(16,256),(8,64)):
        rng=np.random.default_rng(SEED+length*1000+k)
        study.LENGTH=length
        segments=cols//length
        vectors=norm.reshape(rows,segments,length)
        pool=vectors.reshape(-1,length)
        fit=pool[rng.choice(len(pool),8192,replace=False)]
        centers=study.train_kmeans(fit,k,rng)
        unit=max(1/64,float(np.max(np.abs(centers)))/127)
        codes=np.rint(centers/unit).astype(np.int8)
        for alpha in (0.,1.):
            labels=np.empty((rows,segments),np.uint8)
            for s in range(segments):
                q=xtrain[:,s*length:(s+1)*length]
                cov=q.T@q/len(q)
                variance=np.trace(cov)/length
                factor=np.linalg.cholesky(alpha*cov+(1-alpha)*variance*np.eye(length))
                labels[:,s]=study.distances(vectors[:,s]@factor,codes.astype(np.float32)*unit@factor).argmin(1)
            decoded=float_model.reconstructed(norm,scale,codes,labels,length,unit)
            arms=[(0,0,decoded,None)]
            if alpha==1.:
                candidate,sparse=kproj.add_exceptions(w,decoded,xtrain,1,return_sparse=True) if (length,k)==(16,256) else (None,None)
                if candidate is not None:arms.append((1,0,candidate,sparse))
                if (length,k)==(16,256):
                    residual=w-decoded
                    for rank in (4,8,10):
                        v,a=lowrank.factorize(residual,centered,rank,
                            np.random.default_rng(SEED+length*1000+k+rank*100000))
                        arms.append((0,rank,decoded+a@v.T,(v,a)))
            for exceptions,rank,candidate,metadata in arms:
                bias=((w-candidate)@mean).astype(np.float16)
                static=rows*(((segments*int(np.log2(k))+7)//8)+(cols//128)*(2+3*exceptions)+2)
                static+=codes.nbytes+4+2*rank*(rows+cols)
                rate=8*static/(rows*cols)
                key=f'length{length}-k{k}-alpha{alpha:g}-exceptions{exceptions}-rank{rank}-bias1'
                records[key]={'total_bits_per_weight':rate,
                    'label_bytes_per_row':(segments*int(np.log2(k))+7)//8,
                    'dictionary_bytes':codes.nbytes+4,
                    'scales_bytes_per_row':2*(cols//128),
                    'exception_bytes_per_row':3*exceptions*(cols//128),
                    'lowrank_factor_bytes':2*rank*(rows+cols),
                    'bias_bytes_per_row':2,
                    'table_bytes_per_input':segments*k*4,
                    'row_table_lookups':segments,
                    'row_sparse_gathers':exceptions*(cols//128),
                    'input_correction_dot_products':rank,
                    'train_input_all_rows_relative_rms':kproj.response_error(xtrain,w,candidate,bias),
                    'validation_input_all_rows_relative_rms':kproj.response_error(xval,w,candidate,bias)}
                packet=wire.pack_labels(labels[:8],int(np.log2(k)))
                sparse=metadata if exceptions else None
                table=wire.observe(packet,codes,unit,scale[:8],xval[:3],bias=bias[:8],
                    exceptions=None if sparse is None else tuple(item[:8] for item in sparse))
                if rank:
                    v,a=metadata
                    table+=(xval[:3]@v)@a[:8].T
                dense=xval[:3].astype(np.float64)@candidate[:8].astype(np.float64).T+bias[:8][None,:]
                np.testing.assert_allclose(table,dense,rtol=4e-4,atol=4e-3)
    feasible={k:v for k,v in records.items() if v['total_bits_per_weight']<=0.9}
    selected=min(feasible,key=lambda n:feasible[n]['train_input_all_rows_relative_rms'])
    result={'format':'response-codebooks-all-rows/1','fixture':filename,
        'fixture_sha256':manifest['files'][filename]['sha256'],
        'manifest_sha256':study.sha(DATA/'manifest.json'),
        'model_revision':manifest['model_revision'],
        'weight_shape':[rows,cols],
        'weight_scope':'all model weight rows are known quantizer inputs and all rows are scored',
        'input_split':'2048 separate WikiText train inputs fit codewords/labels/corrections; 1024 validation inputs evaluate; test unused',
        'numerical_boundary':'FP32 response with FP16 block scales/factors/bias/residuals, not deployed BF16 or model quality',
        'selection':'lowest all-row training-input relative RMS under <=0.9 paid bits/weight',
        'selected_on_train':selected,
        'selected_validation_relative_rms':records[selected]['validation_input_all_rows_relative_rms'],
        'source_hashes':{n:study.sha(HERE/n) for n in ('study.py','float_model.py','kproj.py','wire.py','lowrank.py','all_rows.py')},
        'methods':records}
    (HERE/('all-'+filename.replace('.npz','.json'))).write_text(json.dumps(result,indent=2)+'\n')
    print(filename,'selected',selected,'rate',round(records[selected]['total_bits_per_weight'],4),
          'train',round(records[selected]['train_input_all_rows_relative_rms'],4),
          'validation',round(result['selected_validation_relative_rms'],4),
          'validation_squared',round(result['selected_validation_relative_rms']**2,5))
    for key,v in records.items():
        if 'alpha1-' in key:
            print(' ',key,round(v['total_bits_per_weight'],4),round(v['validation_input_all_rows_relative_rms'],4))


if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('all_rows.py layer00-self_attn_q_proj.npz')
    run(sys.argv[1])
