"""Bounded per-group full-covariance compensated Q3/Q4 response fits."""
import importlib.util
import sys
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'matched-rate-frontier/fit.py'
spec=importlib.util.spec_from_file_location('matched_scalar',SOURCE)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

def main(group):
    assert 0<=group<8
    with np.load(mod.FIX) as f:
        x=f['train'][:,128*group:128*(group+1)].astype(np.float64)
        w=f['weight'][:128,128*group:128*(group+1)].astype(np.float64)
    options=[]
    for bits in (3,4):
        rows=mod.response_refit(mod.quantize_rows(w,x,bits),w,x)
        options.append((np.stack([r[1] for r in rows]).astype('u1'),np.array([[r[2],r[3]] for r in rows],dtype='<f2')))
    np.savez(HERE/f'group-{group}.npz',codes3=options[0][0],fields3=options[0][1],codes4=options[1][0],fields4=options[1][1])
    print('group',group,'Q3/Q4 fit stored')

if __name__=='__main__':main(int(sys.argv[1]))
