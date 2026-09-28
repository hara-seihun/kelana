"""Frozen paid images: input-only raw Q versus joint local and exact norm response."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
PARENT=HERE.parent/'quip-complete-head-observer/measure.py'
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
EPS=1e-6


def normalize(z,gamma):
    return gamma*z/np.sqrt(np.mean(z*z,axis=-1,keepdims=True)+EPS)


def main(panel):
    assert panel in ('train','held')
    spec=importlib.util.spec_from_file_location('frozen_head_loader',PARENT)
    loader=importlib.util.module_from_spec(spec);sys.modules[spec.name]=loader;spec.loader.exec_module(loader)
    images=loader.load_images()
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    with np.load(FIX) as f:
        x=f['train' if panel=='train' else 'validation'].astype(float)
        w=f['weight'][:128].astype(float)
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        gamma=f.get_tensor('model.layers.0.self_attn.q_norm.weight').float().numpy()[:128].astype(float)
    z=x@w.T;s=np.mean(z*z,axis=-1)+EPS
    teacher=normalize(z,gamma)
    denom=float(np.sum(teacher*teacher))
    result={'panel':panel,'positions':len(x),'epsilon':EPS,'images':{}}
    for key,img in images.items():
        dz=x@(img.astype(float)-w).T
        jac=(dz-z*np.sum(z*dz,axis=-1,keepdims=True)/(128*s[:,None]))*gamma/np.sqrt(s[:,None])
        actual=normalize(z+dz,gamma)-teacher
        result['images'][key]={
            'raw_q_relative_squared':float(np.sum(dz*dz)/np.sum(z*z)),
            'jacobian_joint_relative_squared':float(np.sum(jac*jac)/denom),
            'ideal_real_normalized_relative_squared':float(np.sum(actual*actual)/denom),
            'jacobian_to_exact_ratio':float(np.sum(jac*jac)/np.sum(actual*actual))}
    (HERE/f'frozen-{panel}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main(sys.argv[1])
