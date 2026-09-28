#!/usr/bin/env python3
"""Compare shorter full codewords and calibration-only label assignment."""
import json
import time
from pathlib import Path

import numpy as np
import study

HERE = Path(__file__).resolve().parent


def run():
    started = time.perf_counter()
    rng = np.random.default_rng(study.SEED)
    with np.load(study.FIXTURE) as z:
        source = z['trits'].astype(np.float32)
        queries = z['queries'].astype(np.float32)
        scales = z['scales_fp16'].astype(np.float64)
    result = {}
    for length, sizes in ((4, (4, 8, 16)), (8, (16, 64)), (16, (16, 64, 256))):
        study.LENGTH = length
        weights = source.reshape(5120, 128//length, length)
        q = queries.reshape(8, 128//length, length)
        train = weights[:4096].reshape(-1,length)
        train = train[rng.choice(len(train), 8192, replace=False)]
        for k in sizes:
            codes = study.quantize(study.train_kmeans(train,k,rng))
            for alpha in (0.0, 0.5):
                with_alpha = lambda query: np.linalg.cholesky(
                    alpha*(query.T@query/len(query)) +
                    (1-alpha)*np.eye(length)*(np.mean(query*query)))
                labels = np.empty((5120,128//length),np.int32)
                for s in range(128//length):
                    projection = with_alpha(q[:4,s])
                    labels[:,s] = study.distances(weights[:,s]@projection,
                        codes.astype(np.float32)/64@projection).argmin(1)
                prediction = study.replay(codes,labels,q.astype(np.int32),scales)
                synthetic = rng.integers(-127,128,size=(32,128//length,length),dtype=np.int16).astype(np.int32)
                payload = 5120*((128//length*int(np.log2(k))+7)//8)
                name=f'length{length}-k{k}-alpha{alpha:g}'
                result[name]={'segment_length':length,'codewords':k,'metric_calibration_fraction':alpha,
                              'dictionary_bytes':codes.nbytes,'label_bytes':payload,
                              'retained_scale_bytes':10240,
                              'total_bits_per_weight':8*(payload+codes.nbytes+10240)/(5120*128),
                              'table_bytes':(128//length)*k*4,
                              'table_integer_products':(128//length)*k*length,
                              'row_lookups':128//length,
                              'train_query_train_row':study.evaluate(prediction[:4],weights,q[:4].astype(np.int32),scales,slice(0,4096)),
                              'held_query_held_row':study.evaluate(prediction[4:],weights,q[4:].astype(np.int32),scales,slice(4096,None)),
                              'synthetic_query_held_row':study.evaluate(study.replay(codes,labels,synthetic,scales),weights,
                                                                    synthetic,scales,slice(4096,None))}
    out={'format':'response-codebooks-short/1','fixture_sha256':study.sha(study.FIXTURE),
         'study_source_sha256':study.sha(Path(study.__file__)), 'script_sha256':study.sha(Path(__file__)),
         'seed':study.SEED,'training_rows':4096,'training_queries':[0,1,2,3],
         'held_rows':[4096,5120], 'held_queries':[4,5,6,7], 'methods':result,
         'elapsed_seconds':time.perf_counter()-started}
    (HERE/'short-results.json').write_text(json.dumps(out,indent=2)+'\n')
    for name, data in result.items():
        print(name, round(data['total_bits_per_weight'],4),round(data['train_query_train_row']['relative_rms'],4),
              round(data['held_query_held_row']['relative_rms'],4),round(data['synthetic_query_held_row']['relative_rms'],4))

if __name__=='__main__':
    run()
