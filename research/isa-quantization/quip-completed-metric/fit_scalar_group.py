"""Mixed Q2/Q3 group controls supplied the identical completed covariance."""
from pathlib import Path
import importlib.util
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'matched-rate-frontier/fit.py'
spec=importlib.util.spec_from_file_location('matched_scalar',SOURCE)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

def main(group):
    assert 0<=group<8
    M=np.load('/path/to/workspace/data/kelana-subbit/isa-source-law/qwen3-0.6b-layer00-q-input/conditional-completed-train-metric.npy',mmap_mode='r')
    lo=128*group;hi=lo+128
    x=np.linalg.cholesky(np.asarray(M[lo:hi,lo:hi])).T*np.sqrt(128)
    with np.load(mod.FIX) as f:w=f['weight'][:128,lo:hi].astype(float)
    options=[]
    for bits in (2,3):
        rows=mod.response_refit(mod.quantize_rows(w,x,bits),w,x)
        options.append((np.stack([r[1] for r in rows]).astype('u1'),np.array([[r[2],r[3]] for r in rows],dtype='<f2')))
    np.savez(HERE/f'group-{group}.npz',codes2=options[0][0],fields2=options[0][1],codes3=options[1][0],fields3=options[1][1])
    print('M group',group,'Q2/Q3 fitted')

if __name__=='__main__':main(int(sys.argv[1]))
