"""Bounded full-covariance Q2 group128 alternative to the retained canonical Q3 images."""
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
    rows=mod.response_refit(mod.quantize_rows(w,x,2),w,x)
    codes=np.stack([r[1] for r in rows]).astype('u1')
    fields=np.array([[r[2],r[3]] for r in rows],dtype='<f2')
    assert codes.shape==(128,128) and fields.shape==(128,2)
    np.savez(HERE/f'group-q2-{group}.npz',codes=codes,fields=fields)
    print('Q2 fitted group',group)

if __name__=='__main__':main(int(sys.argv[1]))
