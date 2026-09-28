#!/usr/bin/env sage -python
"""Independent exact source/Gram/factor congruence and projection check, one head."""
import gzip
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from sage.all import ZZ, matrix, vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
SOURCES=(('kivi-two-bit-dot-native/original-o.bf16','803995a9d5abb24c72d3ddabd50f4e656fc5eff26efaf3b626f175fc706ab499'),
         ('contextual-value-feedback/original-o.bf16','677e1de44f3a28a51b2e75e806a8ec68807ed96dfadc169729c1993181418f48'))


def main(layer,head,group):
    path=HERE/f'cert-{layer}-{head}.json.gz'
    data=json.load(gzip.open(path))
    rel,digest=SOURCES[layer]
    assert (data['source'],data['source_sha256'],data['layer'],data['head'])==(rel,digest,layer,head)
    raw=(ROOT/rel).read_bytes()
    assert hashlib.sha256(raw).hexdigest()==digest and len(raw)==4194304
    words=np.frombuffer(raw,dtype='<u2').reshape(1024,16,128)
    values=(words.astype('<u4')<<16).view('<f4').astype(np.float64)
    scaled=values*2.**35
    assert np.isfinite(scaled).all() and np.array_equal(scaled,np.rint(scaled))
    for g in (group,):
        item=data['groups'][g]
        assert item['group']==g
        sl=slice(g*32,(g+1)*32)
        cols=np.concatenate((scaled[:,2*head,sl],scaled[:,2*head+1,sl]),axis=1)
        B=matrix(ZZ,cols.astype(np.int64).tolist())
        G=B.transpose()*B
        assert [int(G[i,j]) for i in range(64) for j in range(i,64)]==item['gram_upper']
        assert [int(G[i,i]) for i in range(64)]==item['diagonal']
        assert int(np.count_nonzero(cols==0))==item['source_zero_words']
        c=4096*G-item['lambda_numerator']*matrix(ZZ,64,64,{(i,i):G[i,i] for i in range(64)})
        P,L,D=c.block_ldlt()
        assert P*c*P.T==L*D*L.T or P.T*c*P==L*D*L.T
        assert [[int(P[i,j]) for j in range(64)] for i in range(64)]==item['ldlt_permutation']
        assert all(D[i,j]==0 for i in range(64) for j in range(64) if i!=j)
        assert [str(D[i,i]) for i in range(64)]==item['ldlt_positive_pivots']
        assert all(D[i,i]>0 for i in range(64))
        # Independently evaluate the actual 1024-row projection for a deterministic
        # mixed-head error and compare it against the exact Gram and frame floor.
        e=vector(ZZ, [(i*17+g*11+head)%7-3 for i in range(32)])
        u,v=ZZ(2),ZZ(3)
        x=vector(ZZ,list(u*e)+list(v*e))
        projection=B*x
        norm=projection.dot_product(projection)
        assert norm==x.dot_product(G*x)
        rhs=sum(G[i,i]*(u*u if i<32 else v*v)*e[i%32]**2 for i in range(64))
        assert 4096*norm>=item['lambda_numerator']*rhs
    print(json.dumps({'layer':layer,'head':head,'group':group,'exact_congruences':1,
                      'projection_checks':1,'certificate_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}))

if __name__=='__main__':main(int(sys.argv[1]),int(sys.argv[2]),int(sys.argv[3]))
