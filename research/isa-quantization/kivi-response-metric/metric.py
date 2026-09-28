"""Frozen train-only rank8+diagonal key-error metric, paid 2304-byte FP16 image."""
from pathlib import Path
import hashlib
import json
import math
import sys
import numpy as np
HERE=Path(__file__).resolve().parent
OWNER=HERE.parent/'kivi-causal-cache'
sys.path.insert(0,str(OWNER))
from source import arrays,FIX_SHA

RANK=8
N=128

def sha(blob):return hashlib.sha256(blob).hexdigest()


def window(window):
    src=arrays('train',window)
    q=np.concatenate([src['qrot'][h].numpy().astype(np.float64)/math.sqrt(128) for h in range(2)],axis=0)
    gram=q.T@q
    target=HERE/f'train-{window}-gram.npy'
    np.save(target,gram)
    print(json.dumps({'window':window,'count':len(q),'gram_sha256':sha(target.read_bytes()),'trace':float(np.trace(gram))}))


def finalize():
    grams=[];shas=[]
    for i in range(8):
        path=HERE/f'train-{i}-gram.npy';shas.append(sha(path.read_bytes()))
        gram=np.load(path);assert gram.shape==(N,N)
        grams.append(gram)
    C=sum(grams)/(8*2*256)
    eigenvalues,eigenvectors=np.linalg.eigh(C)
    idx=np.argsort(eigenvalues)[-RANK:][::-1]
    U=eigenvectors[:,idx]*np.sqrt(np.maximum(eigenvalues[idx],0))
    for j in range(RANK):
        k=np.argmax(abs(U[:,j]))
        if U[k,j]<0:U[:,j]*=-1
    floor=1e-6*np.trace(C)/N
    D=np.maximum(np.diag(C)-np.square(U).sum(axis=1),floor)
    fields=np.concatenate((U.astype('<f2').ravel(),D.astype('<f2'))).astype('<f2')
    assert fields.nbytes==2304 and np.isfinite(fields).all() and np.all(fields[-N:]>0)
    blob=fields.tobytes()
    (HERE/'metric-fp16.bin').write_bytes(blob)
    actualU=np.frombuffer(blob,dtype='<f2',count=N*RANK).astype(np.float32).reshape(N,RANK)
    actualD=np.frombuffer(blob,dtype='<f2',count=N,offset=N*RANK*2).astype(np.float32)
    manifest={'source_fixture_sha256':FIX_SHA,'predeclared_rank':RANK,'matrix':'C=mean(qrot qrot^T /128) across both original heads of all 8 train windows',
              'train_gram_sha256':shas,'train_query_count':8*2*256,'rank_eigenvalues':eigenvalues[idx].tolist(),
              'd_floor':float(floor),'metric_image_bytes':len(blob),'metric_image_sha256':sha(blob),
              'metric_fields':'row-major FP16 U[128,8], FP16 D[128] (strictly positive)',
              'actual_fp16_min_d':float(actualD.min()),'actual_fp16_max_u':float(abs(actualU).max()),
              'empirical_q_metric_trace':float(np.trace(C)),
              'empirical_q_metric_error_frobenius_rel':float(np.linalg.norm(C-(actualU@actualU.T+np.diag(actualD)))/np.linalg.norm(C))}
    (HERE/'metric-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))

if __name__=='__main__':
    if sys.argv[1]=='window':window(int(sys.argv[2]))
    elif sys.argv[1]=='finalize':finalize()
    else:raise ValueError(sys.argv)
