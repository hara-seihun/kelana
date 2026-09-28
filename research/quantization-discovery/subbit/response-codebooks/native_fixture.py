#!/usr/bin/env python3
"""Export identical reconstructed coefficients for packed lookup and VNNI controls."""
import json
import sys
from pathlib import Path

import numpy as np
import study


def export(out):
    study.LENGTH = 8
    out.mkdir(parents=True,exist_ok=True)
    rng = np.random.default_rng(study.SEED)
    with np.load(study.FIXTURE) as z:
        w = z['trits'].reshape(5120,16,8).astype(np.float32)
        q = z['queries'].astype(np.int8)
    train = w[:4096].reshape(-1,8)
    train = train[rng.choice(len(train),8192,replace=False)]
    codes = study.quantize(study.train_kmeans(train,64,rng))
    labels = np.empty((5120,16),np.uint8)
    for s in range(16):
        labels[:,s] = study.distances(w[:,s],codes.astype(np.float32)/64).argmin(1)
    packed = np.empty((5120,12),np.uint8)
    for g in range(4):
        value = sum(labels[:,4*g+j].astype(np.uint32) << (6*j) for j in range(4))
        for byte in range(3):
            packed[:,3*g+byte] = (value >> (8*byte)).astype(np.uint8)
    restored = np.empty_like(labels)
    for g in range(4):
        value = sum(packed[:,3*g+j].astype(np.uint32) << (8*j) for j in range(3))
        for j in range(4):
            restored[:,4*g+j] = ((value >> (6*j))&63).astype(np.uint8)
    assert np.array_equal(labels,restored)
    dense = codes[labels].reshape(5120,128)
    codes.tofile(out/'dictionary.i8')
    packed.tofile(out/'labels.u6')
    dense.tofile(out/'decoded.i8')
    q.tofile(out/'queries.i8')
    oracle = q.astype(np.int32)@dense.astype(np.int32).T
    oracle.astype('<i4').tofile(out/'oracle.i32')
    receipt={'fixture_sha256':study.sha(study.FIXTURE),
             'export_source_sha256':study.sha(Path(__file__)),
             'study_source_sha256':study.sha(Path(study.__file__)),
             'files':{p.name:study.sha(p) for p in out.iterdir() if p.is_file()}}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'oracle_sha256':receipt['files']['oracle.i32'],'rows':5120,'queries':8}))

if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('native_fixture.py OUT_DIR')
    export(Path(sys.argv[1]))
