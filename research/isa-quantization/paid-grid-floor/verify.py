"""Exact-dyadic paid-grid sidecar; integer DP runs as a foreground one-CPU subprocess."""
import hashlib
import json
import subprocess
import tempfile
from fractions import Fraction
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
CERT=ROOT/'full-pair-covariance/spectral-certificate.npz'
D=ROOT/'input-programs/diagonal-certificate.npz'
SCALE=1<<16

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    assert sha(FIX)=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    with np.load(FIX) as f:
        x=f['train'][:,:128].astype('float64')
        w=f['weight'][:128,:128].astype('float64')
    with np.load(CERT) as f:
        v=f['vector']; m=f['dual_output']
    with np.load(D) as f: d=f['diagonal']
    assert x.shape==(2048,128) and w.shape==(128,128)
    assert v.shape==(128,48) and m.shape==(128,48) and d.shape==(128,)
    assert all(a.dtype==np.int64 for a in (v,m,d)) and np.all(d>0)
    assert np.array_equal(x*2**27,np.rint(x*2**27))
    assert np.array_equal(w*2**28,np.rint(w*2**28))
    xi=np.rint(x*2**27).astype(np.int64)
    wi=np.rint(w*2**28).astype(np.int64)
    p=m.astype(object)@v.astype(object).T
    # z = (16 * w_integer * d + p) / (d * 2^32).
    grid=np.empty((128,128),dtype=np.int64)
    for o in range(128):
        for i in range(128):
            numerator=int(wi[o,i])*int(d[i])*16+int(p[o,i])
            grid[o,i]=(numerator*SCALE)//(int(d[i])*2**32)
    assert np.max(np.abs(grid))<10**8
    text='\n'.join(' '.join(map(str,row)) for row in grid)+'\n'
    with tempfile.TemporaryDirectory() as folder:
        exe=Path(folder)/'trimmed'
        subprocess.run(['cc','-O3','-std=c11','-Wall','-Wextra',str(HERE/'trimmed.c'),'-o',str(exe)],check=True)
        result=subprocess.run([str(exe)],input=text,text=True,capture_output=True,check=True,timeout=50)
        independent=Path(folder)/'check'
        subprocess.run(['cc','-O3','-std=c11','-Wall','-Wextra',str(HERE/'check.c'),'-o',str(independent)],check=True)
        checked=subprocess.run([str(independent)],input=text,text=True,capture_output=True,check=True,timeout=50)
    assert result.stdout==checked.stdout, 'backward and forward integer DPs disagree'
    rows=list(map(int,result.stdout.split()))
    assert len(rows)==128 and min(rows)>=0
    # sqrt(SSE_z) >= sqrt(SSE_grid)/SCALE - sqrt(64)/SCALE.
    # Young: (a-b)^2 >= 63*a^2/64 - 63*b^2. Each row
    # therefore pays >= d_min [63/64 * SSE_grid/SCALE^2 - 63*64/SCALE^2].
    # Each interval SSE was rounded down by < 1 integer; at most 64 intervals.
    raw=sum(rows)
    charge=Fraction(int(d.min()),2**32)*Fraction(63*raw-63*64*128*64,64*SCALE*SCALE)
    # N = tr(W X^T X W^T) exactly, with dyadic input and teacher.
    # int64 matrix products safely hold each elementary dot here; object
    # multiplication for final accumulation avoids integer overflow.
    xo=xi.astype(object); wo=wi.astype(object)
    h=xo.T@xo
    g=wo.T@wo
    norm=int(np.sum(h*g))
    assert norm>0
    normalized=charge*Fraction(2**110,norm)
    parent=json.loads((ROOT/'full-pair-covariance/verified.json').read_text())
    assert parent['certificate_sha256']==sha(CERT) and parent['diagonal_source_sha256']==sha(D)
    original=Fraction(parent['universal_floor_rational'])
    control=json.loads((ROOT/'matched-rate-frontier/results.json').read_text())['images']['refit-mixed-q3q4-6848.bin']['train_error']
    assert original+normalized<control
    receipt={'fixture_sha256':sha(FIX),'certificate_sha256':sha(CERT),
             'diagonal_sha256':sha(D),'source_sha256':sha(HERE/'trimmed.c'),
             'independent_checker_sha256':sha(HERE/'check.c'),
             'grid_scale':SCALE,'retained_coordinates':64,'levels':16,
             'sum_integer_lower_cost':raw,'minimum_diagonal_numerator':int(d.min()),
             'additional_floor_rational':str(normalized),
             'additional_floor':float(normalized),
             'parent_receipt_sha256':sha(ROOT/'full-pair-covariance/verified.json'),
             'linear_plus_paid_grid_floor':float(original+normalized),
             'matched_linear_control':control,
             'remaining_to_control':control-float(original+normalized)}
    (HERE/'verified.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))

if __name__=='__main__': main()
