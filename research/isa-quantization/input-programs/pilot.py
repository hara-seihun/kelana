import json
import numpy as np
from pathlib import Path
from scipy.linalg import qr

FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')

def hadamard(n):
    h=np.array([[1.]])
    while len(h)<n: h=np.block([[h,h],[h,-h]])
    return h/np.sqrt(n)

with np.load(FIX) as f:
    x=f['train'][:,:128].astype('float64'); v=f['validation'][:,:128].astype('float64'); w=f['weight'][:128,:128].astype('float64')
y=x@w.T; vy=v@w.T
results={}
for name,t in [('direct',np.eye(128)),('hadamard',hadamard(128))]:
    z=x@t; vz=v@t
    # Select useful input features for explaining the full consumer, not just variance of X.
    # Whitening by a 128-output response Gram gives a deterministic pivoted QR heuristic.
    weighted=z.T@y
    _,_,order=qr(weighted.T,pivoting=True)
    entries=[]
    for r in (96,):
        chosen=order[:r]; a=z[:,chosen]; b=np.linalg.lstsq(a,y,rcond=None)[0]
        train=float(np.sum((a@b-y)**2)/np.sum(y*y))
        held=float(np.sum((vz[:,chosen]@b-vy)**2)/np.sum(vy*vy))
        entries.append(dict(rank=r, train_projection_floor=train, held_projected_response=held,
                            q4_payload_bytes=64*r+512+(128 if name=='direct' else 128)))
    results[name]=entries
Path(__file__).with_name('coordinate-results.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
