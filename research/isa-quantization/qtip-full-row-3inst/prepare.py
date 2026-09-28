"""Prepare the captured full-input Q-head for the official QTIP block-LDLQ trellis."""
import argparse
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
FIX = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')

def had(a):
    a=np.asarray(a,dtype=np.float64).copy()
    n=a.shape[-1]
    for width in (2**i for i in range(n.bit_length()-1)):
        v=a.reshape(-1,n//(2*width),2,width)
        x=v[:,:,0,:].copy();y=v[:,:,1,:].copy()
        v[:,:,0,:]=x+y;v[:,:,1,:]=x-y
    return a/np.sqrt(n)

def main():
    p=argparse.ArgumentParser();p.add_argument('stage',choices=['transform','ldl']);p.add_argument('--arm',choices=['3inst','hyb'],default='3inst'); a=p.parse_args()
    prepared=HERE/('prepared-hyb' if a.arm=='hyb' else 'prepared')
    if a.stage=='transform':
        with np.load(FIX) as f:
            x=f['train'].astype(np.float64);w=f['weight'][:128].astype(np.float64)
        h=x.T@x; h=(h+h.T)*.5
        h=h/np.diag(h).mean();h.flat[::1025]+=.01
        rng=np.random.default_rng(20260924)
        su=rng.choice(np.array([-1,1],dtype=np.int8),1024)
        sv=rng.choice(np.array([-1,1],dtype=np.int8),128)
        wr=had(had(w.T*sv).T*su)
        hr=had(had(h*su).T*su)
        # The published 2-bit 3INST example uses scale_override=.9. Fix it before inspecting held.
        # LUT second moment is computed by the independent codebook decoder, not from responses.
        lut=np.fromfile(HERE/('hyb-lut-f32.bin' if a.arm=='hyb' else 'lut-f32.bin'),dtype='<f4')
        scale=np.sqrt(np.mean(wr*wr))/(np.sqrt(np.mean(lut.astype(np.float64)**2))*.9)
        prepared.mkdir(exist_ok=True)
        (prepared/'wr-f32.bin').write_bytes((wr/scale).astype('<f4').tobytes())
        (prepared/'hr-f64.bin').write_bytes(hr.astype('<f8').tobytes())
        np.savez(prepared/'meta.npz',su=su,sv=sv,scale=scale)
        print('scale',scale,'lut rms',np.sqrt(np.mean(lut*lut)))
    else:
        h=np.fromfile(prepared/'hr-f64.bin',dtype='<f8').reshape(1024,1024)
        c=np.linalg.cholesky(h)
        for k in range(0,1024,16):
            c[:,k:k+16]=np.linalg.solve(c[k:k+16,k:k+16],c[:,k:k+16].T).T
            c[k:k+16,k:k+16]=np.eye(16)
        (prepared/'ldl-f32.bin').write_bytes(c.astype('<f4').tobytes())
        print('block LDL completed')
if __name__=='__main__':main()
