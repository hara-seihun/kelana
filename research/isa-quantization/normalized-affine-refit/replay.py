"""Independent stored-byte Q2/Q3 decoder and ideal-real fixed-image scores."""
from pathlib import Path
import hashlib
import json
import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
NEW=HERE/'normalized-affine-q2q3-50320.bin'
OLD=ROOT/'quip-root-matched-scalar/refit-group-q2q3-50320.bin'
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
NEW_SHA='18fbba120a75f1788d674099ee82166e3509908c213021196df011ecea66b370'
OLD_SHA='e41d273bd2d5ea7ef497e6c2749bf6ac5b1529124f8e24d2ea2448132dfdfd15'

def decode(image):
    assert len(image)==50320
    modes=np.unpackbits(np.frombuffer(image[:128],dtype='u1'),bitorder='little').reshape(128,8)
    assert modes.sum()==191
    weights=np.empty((128,1024),dtype=np.float64)
    codes=[];index=128
    for row in range(128):
        for group in range(8):
            bits=2 if modes[row,group] else 3
            size=16*bits
            payload=image[index:index+size];index+=size
            assert len(payload)==size
            packed=int.from_bytes(payload,'little')
            digits=np.array([(packed>>(i*bits))&((1<<bits)-1) for i in range(128)],dtype=np.float64)
            codes.append(payload)
            scale,origin=np.frombuffer(image[index:index+4],dtype='<f2').astype(np.float64);index+=4
            assert np.isfinite(scale) and scale>0 and np.isfinite(origin)
            weights[row,group*128:(group+1)*128]=digits*scale+origin
    assert index==len(image)
    return weights,modes,codes

def norm(z,g):
    return z*g/np.sqrt(np.mean(z*z,axis=1,keepdims=True)+1e-6)

def main():
    data=NEW.read_bytes();old=OLD.read_bytes()
    assert hashlib.sha256(data).hexdigest()==NEW_SHA
    assert hashlib.sha256(old).hexdigest()==OLD_SHA
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    weights,modes,codes=decode(data)
    original,oldm,oldcodes=decode(old)
    assert np.array_equal(modes,oldm) and codes==oldcodes
    with np.load(FIX) as f:
        w=f['weight'][:128].astype(np.float64)
        inputs={'train':f['train'].astype(np.float64),'inspected_held':f['validation'].astype(np.float64)}
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        gamma=f.get_tensor('model.layers.0.self_attn.q_norm.weight').float().numpy()[:128].astype(np.float64)
    out={'image_sha256':NEW_SHA,'bytes':len(data),'codes_and_modes_byte_identical':True,'panels':{}}
    for key,x in inputs.items():
        teacher=x@w.T;teacher_n=norm(teacher,gamma)
        output={}
        for label,decoded in (('original_H_scalar',original),('normalized_affine',weights)):
            candidate=x@decoded.T
            output[label]={'raw_q_rel_sq':float(np.sum((candidate-teacher)**2)/np.sum(teacher**2)),
                'normalized_q_ideal_rel_sq':float(np.sum((norm(candidate,gamma)-teacher_n)**2)/np.sum(teacher_n**2))}
        out['panels'][key]=output
    (HERE/'replay-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(out,indent=2))

if __name__=='__main__':main()
