#!/usr/bin/env python3
"""Token-independent real-map projection bounds for static accumulator gauges."""
import hashlib
import json
from pathlib import Path
import sys
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'transformed-weights'))
from gguf_read import Gguf


def run():
    model=Gguf('/path/to/workspace/data/bonsai2/PTQ1_0.gguf')
    records=[]
    for layer in (0,10):
        path=Path(f'/path/to/workspace/data/kelana-ffn/ptq1_0/layer{layer:02}/post_norm_s.f32')
        k=np.fromfile(path,dtype='<f4').astype(float)
        activation_bound=np.max(abs(k))*np.sqrt(len(k))*(1+np.sqrt(128)/14)
        for kind in ('gate','up'):
            name=f'blk.{layer}.ffn_{kind}.weight'
            nrows=model.tensors[name][0][1]
            norms=[]
            for first in range(0,nrows,512):
                count=min(512,nrows-first)
                t,s=model.rows_ptq1_0(name,first,count)
                nnz=np.count_nonzero(t.reshape(count,-1,128),axis=2)
                norms.extend(np.sqrt(np.sum(nnz*s.astype(float)**2,axis=1)))
            b=np.asarray(norms)*activation_bound
            # Illustrative dyadic gauges keep the real bound below30000,
            # leaving headroom; a native rounding contract remains separate.
            exponents=np.ceil(np.log2(b/30000)).astype(int)
            gauge=2.**exponents
            records.append({'layer':layer,'kind':kind,'rows':nrows,
                'norm_diagonal_max':float(np.max(abs(k))),
                'norm_file_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'quantized_activation_l2_bound':float(activation_bound),
                'row_norm_min_median_max':np.quantile(norms,[0,.5,1]).tolist(),
                'projection_bound_min_median_max':np.quantile(b,[0,.5,1]).tolist(),
                'gauge_exponent_histogram':{str(int(e)):int(np.sum(exponents==e)) for e in np.unique(exponents)},
                'gauged_bound_max':float(np.max(b/gauge)),
                'bound_array_sha256':hashlib.sha256(b.astype('<f8').tobytes()).hexdigest()})
    model.f.close()
    return {'scope':'Real arithmetic RMSnorm, diagonal norm, normalized Hadamard, nearest A4 per128 quantizer. All rows ofgate/up inlayers0/10. Not an IEEE rounding/overflow proof.',
            'formula':'||W_row||2 * max|norm_diagonal| * sqrt(D) * (1+sqrt128/(2*7))',
            'records':records}


if __name__=='__main__':
    r=run();r['source_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    Path(__file__).with_name('range-bound.json').write_text(json.dumps(r,indent=2)+'\n')
    for x in r['records']:print(x['layer'],x['kind'],x['projection_bound_min_median_max'],x['gauge_exponent_histogram'])
