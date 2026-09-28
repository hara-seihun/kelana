"""Source geometry for the predeclared Gaussian positive-feature estimator."""
from pathlib import Path
import importlib.util
import json
import math
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')

def summary(values):
    return [float(np.min(values)),float(np.median(values)),float(np.max(values))]

def main():
    torch.set_num_threads(1)
    with np.load(FIX) as f:
        train=f['train'][:256].copy();held=f['validation'][:256].copy()
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        q=f.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float()
        k=f.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        qgamma=f.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma=f.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    spec=importlib.util.spec_from_file_location('source_kernel_geometry',ROOT/'attention-consumer/measure.py')
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    output={}
    for name,source in (('train_first_window',train),('held_first_window',held)):
        x=torch.from_numpy(source.astype(np.float32))
        with torch.no_grad():
            keys=mod.rope(mod.normalized((x@k.T).to(torch.bfloat16).float(),kgamma)).numpy()*128**-.25
            queries=[mod.rope(mod.normalized((x@q[i*128:(i+1)*128].T).to(torch.bfloat16).float(),qgamma)).numpy()*128**-.25 for i in range(2)]
        info={'key_squared_norm':summary(np.sum(keys**2,axis=1)),'heads':{}}
        for head,query in enumerate(queries):
            qnorm=np.sum(query**2,axis=1)
            dot=query@keys.T
            causal=np.tril(np.ones((256,256),bool))
            variance_exponent=qnorm[:,None]+np.sum(keys**2,axis=1)[None,:]+2*dot
            info['heads'][f'head{head}']={'query_squared_norm':summary(qnorm),
                'teacher_score_causal':summary(dot[causal]),
                'iid_gaussian_feature_relative_variance_log_exponent_causal':summary(variance_exponent[causal]),
                'iid_gaussian_feature_log_variance_per_64_causal_min':float(np.min(variance_exponent[causal])-math.log(64))}
        output[name]=info
    (HERE/'geometry.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps(output,indent=2))

if __name__=='__main__':main()
