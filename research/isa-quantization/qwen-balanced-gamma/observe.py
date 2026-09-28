"""One original versus paid-gamma complete source observer window."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);sys.modules[name]=module;spec.loader.exec_module(module)
    return module

def main(panel,window):
    torch.set_num_threads(1)
    assert panel in ('train','held')
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    reader=load('balanced_gamma_image_reader',HERE/'reader.py')
    replacement,original,exponent=reader.decode()
    with np.load(FIX) as f:
        x=f['train' if panel=='train' else 'validation']
        assert window in range(len(x)//256)
        x=torch.from_numpy(x[window*256:(window+1)*256].copy().astype(np.float32))
        w=f['weight'][:128].astype(np.float32)
    with safe_open(MODEL,framework='pt',device='cpu') as checkpoint:
        q=checkpoint.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float()
        k=checkpoint.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        v=checkpoint.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        o=checkpoint.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].float()
    assert np.array_equal(w,q[:128].numpy())
    consumer=load('canonical_qwen_attention',ROOT/'attention-consumer/measure.py')
    go=[torch.from_numpy(original[h]) for h in range(2)]
    gn=[torch.from_numpy(replacement[h]) for h in range(2)]
    factor=torch.from_numpy(np.exp2(exponent).astype(np.float32))
    mask=torch.ones((256,256),dtype=torch.bool).triu(1)
    result={'panel':panel,'window':window,'gamma_image_sha256':reader.SHA,
        'fixture_sha256':'389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f',
        'capture_model_q_exact':True,'head':{}}
    with torch.no_grad():
        qraw=[(x@q[h*128:(h+1)*128].T).to(torch.bfloat16).float() for h in range(2)]
        kraw=(x@k.T).to(torch.bfloat16).float()
        vraw=(x@v.T).to(torch.bfloat16).float()
        k0=consumer.rope(consumer.normalized(kraw,go[1]))
        k1=consumer.rope(consumer.normalized(kraw,gn[1]))
        kdiff=(k1-k0/factor).abs()
        result['key_rotated_max_abs_scaling_difference']=float(kdiff.max())
        result['key_rotated_bitwise_equal_to_scaled_original']=bool(torch.equal(k1,k0/factor))
        reference_pair=torch.zeros((256,1024),dtype=torch.float32)
        changed_pair=torch.zeros_like(reference_pair)
        for h in range(2):
            columns=o[:,h*128:(h+1)*128]
            source=consumer.head(qraw[h],kraw,vraw,go[0],go[1],columns)
            changed=consumer.head(qraw[h],kraw,vraw,gn[0],gn[1],columns)
            rq0=consumer.rope(consumer.normalized(qraw[h],go[0]))
            rq1=consumer.rope(consumer.normalized(qraw[h],gn[0]))
            score_diff=(source[2]-changed[2]).masked_fill(mask,0)
            qdiff=(rq1-rq0*factor).abs()
            p_diff=(source[0].exp()-changed[0].exp()).abs()
            o_diff=(source[1]-changed[1]).abs()
            result['head'][f'head{h}']={
                'query_rotated_max_abs_scaling_difference':float(qdiff.max()),
                'query_rotated_bitwise_equal_to_scaled_original':bool(torch.equal(rq1,rq0*factor)),
                'causal_score_max_abs_difference':float(score_diff.abs().max()),
                'causal_score_bitwise_equal':bool(torch.equal(source[2],changed[2])),
                'attention_probability_max_abs_difference':float(p_diff.max()),
                'post_o_max_abs_difference':float(o_diff.max()),
                'post_o_rel_sq':float(o_diff.square().sum()/source[1].square().sum()),
                'post_o_sse':float(o_diff.square().sum()),
                'post_o_ref_sq':float(source[1].square().sum())}
            reference_pair+=source[1]
            changed_pair+=changed[1]
        pair=(reference_pair-changed_pair).abs()
        result['gqa_pair']={'post_o_max_abs_difference':float(pair.max()),
            'post_o_rel_sq':float(pair.square().sum()/reference_pair.square().sum()),
            'post_o_sse':float(pair.square().sum()),
            'post_o_ref_sq':float(reference_pair.square().sum())}
    (HERE/f'{panel}-{window}-observer.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]))
