"""One predeclared, cross-output GN step on fixed-code scalar affine fields."""
from pathlib import Path
import hashlib
import json
import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
OLD=ROOT/'quip-root-matched-scalar/refit-group-q2q3-50320.bin'
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
EPS=1e-6
DAMP=.01

def parse_fields(blob):
    bits=np.unpackbits(np.frombuffer(blob[:128],dtype='u1'),bitorder='little').reshape(128,8)
    assert len(blob)==50320 and bits.sum()==191
    cursor=128; fields=[]
    for row in range(128):
        offsets=[]
        for group in range(8):
            cursor+=16*(2 if bits[row,group] else 3)
            offsets.append(cursor)
            cursor+=4
        fields.append(offsets)
    assert cursor==len(blob)
    return fields

def normalized(z,g):
    return g*z/np.sqrt(np.mean(z*z,axis=1,keepdims=True)+EPS)

def main():
    old=OLD.read_bytes()
    assert hashlib.sha256(old).hexdigest()=='e41d273bd2d5ea7ef497e6c2749bf6ac5b1529124f8e24d2ea2448132dfdfd15'
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    from importlib.util import spec_from_file_location,module_from_spec
    spec=spec_from_file_location('original_scalar_reader',ROOT/'quip-root-matched-scalar/replay.py')
    module=module_from_spec(spec);spec.loader.exec_module(module)
    base=module.scalar().astype(np.float64)
    with np.load(FIX) as fixture:
        x=fixture['train'].astype(np.float64)
        w=fixture['weight'][:128].astype(np.float64)
    with safe_open(MODEL,framework='pt',device='cpu') as model:
        gamma=model.get_tensor('model.layers.0.self_attn.q_norm.weight').float().numpy()[:128].astype(np.float64)
    assert x.shape==(2048,1024) and base.shape==(128,1024) and w.shape==(128,1024)
    target=x@w.T
    z=x@base.T
    reference=normalized(target,gamma)
    e=normalized(z,gamma)-reference
    s=np.mean(z*z,axis=1)+EPS
    source_sum=np.sum(x,axis=1)
    features=np.stack((z,np.broadcast_to(source_sum[:,None],z.shape)),axis=-1)
    d=128
    gz2=np.sum((gamma[None,:]*z)**2,axis=1)
    ge=gamma[None,:]*e
    jacres=(ge-z*np.sum(z*ge,axis=1)[:,None]/(d*s[:,None]))/np.sqrt(s[:,None])
    gradient=np.einsum('trk,tr->rk',features,jacres,optimize=True).reshape(-1)
    # J^T J=diag(gamma²/s) - uz^T - zu^T + vv^T; this retains every
    # cross-output RMSNorm coupling, unlike 128 separate field regressions.
    diagonal=np.einsum('tr,trk,trl->rkl',gamma[None,:]**2/s[:,None],features,features,optimize=True)
    u=(features*z[:,:,None]).reshape(len(x),256)
    v=(features*(gamma[None,:]**2*z/(d*s[:,None]**2))[:,:,None]).reshape(len(x),256)
    a=(features*(z*np.sqrt(gz2)[:,None]/(d*s[:,None]**1.5))[:,:,None]).reshape(len(x),256)
    h=-(u.T@v)-(v.T@u)+(a.T@a)
    for r in range(128):h[2*r:2*r+2,2*r:2*r+2]+=diagonal[r]
    h=(h+h.T)/2
    assert np.min(np.diag(h))>0
    step=np.linalg.solve(h+DAMP*np.diag(np.diag(h)),-gradient).reshape(128,2)
    gain=1+step[:,0];origin_shift=step[:,1]
    fields=parse_fields(old)
    new=bytearray(old)
    for row in range(128):
        for pos in fields[row]:
            scale,origin=np.frombuffer(old[pos:pos+4],dtype='<f2').astype(np.float64)
            updated=np.array([scale*gain[row],origin*gain[row]+origin_shift[row]],dtype='<f2')
            assert np.isfinite(updated).all() and updated[0]>0
            new[pos:pos+4]=updated.tobytes()
    image=HERE/'normalized-affine-q2q3-50320.bin'
    image.write_bytes(new)
    decoded=np.empty_like(base)
    for r in range(128):
        for k in range(8):
            pos=fields[r][k]
            scale,origin=np.frombuffer(new[pos:pos+4],dtype='<f2').astype(float)
            oldscale,oldorigin=np.frombuffer(old[pos:pos+4],dtype='<f2').astype(float)
            digits=np.rint((base[r,k*128:(k+1)*128]-oldorigin)/oldscale)
            decoded[r,k*128:(k+1)*128]=digits*scale+origin
    actual=x@decoded.T
    denominator=float(np.sum(reference**2))
    result={'source_image_sha256':hashlib.sha256(old).hexdigest(),
            'new_image_sha256':hashlib.sha256(new).hexdigest(),
            'image_bytes':len(new),'changed_bytes':sum(a!=b for a,b in zip(old,new)),
            'gain_min_max':[float(np.min(gain)),float(np.max(gain))],
            'origin_shift_min_max':[float(np.min(origin_shift)),float(np.max(origin_shift))],
            'damping_diagonal_fraction':DAMP,
            'training_normalized_ideal_before':float(np.sum(e*e)/denominator),
            'training_normalized_ideal_after_fp16':float(np.sum((normalized(actual,gamma)-reference)**2)/denominator)}
    (HERE/'fit-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
