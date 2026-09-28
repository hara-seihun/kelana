"""One fixed positive-feature online Qwen GQA-group experiment, no fitting."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
TABLE=HERE/'gaussian-features-64x128-f16.bin'
TABLE_SHA='c79b3d345a0bfc6a1b2e4a6e8f04246e5b7750e885ae17f3eb36ad66d53d86f5'
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')

def log_features(rot,omega):
    # E exp[omega·q - ||q||²/2] exp[omega·k - ||k||²/2] = exp(q·k).
    # Both rotary Q/K are divided by d^(1/4), so q·k is the source logit.
    scale=128**-.25
    a=rot*scale
    return (a@omega.T-.5*np.sum(a*a,axis=-1,keepdims=True)).astype(np.float32)

def main(panel,window):
    torch.set_num_threads(1)
    assert panel in ('train','held')
    assert hashlib.sha256(TABLE.read_bytes()).hexdigest()==TABLE_SHA
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    omega=np.frombuffer(TABLE.read_bytes(),dtype='<f2').astype(np.float32).reshape(64,128)
    with np.load(FIX) as fixture:
        inputs=fixture['train' if panel=='train' else 'validation']
        assert window in range(len(inputs)//256)
        source=inputs[window*256:(window+1)*256].copy()
        original=fixture['weight'][:128].astype(np.float32)
    with safe_open(MODEL,framework='pt',device='cpu') as checkpoint:
        q=checkpoint.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float()
        k=checkpoint.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        v=checkpoint.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        o=checkpoint.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].float()
        qgamma=checkpoint.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma=checkpoint.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    assert np.array_equal(original,q[:128].numpy())
    spec=importlib.util.spec_from_file_location('qwen_source_causal',ROOT/'attention-consumer/measure.py')
    consumer=importlib.util.module_from_spec(spec);sys.modules[spec.name]=consumer;spec.loader.exec_module(consumer)
    x=torch.from_numpy(source.astype(np.float32))
    with torch.no_grad():
        q0=(x@q[:128].T).to(torch.bfloat16).float()
        q1=(x@q[128:256].T).to(torch.bfloat16).float()
        kt=(x@k.T).to(torch.bfloat16).float()
        vt=(x@v.T).to(torch.bfloat16).float()
        teacher0=consumer.head(q0,kt,vt,qgamma,kgamma,o[:,:128])
        teacher1=consumer.head(q1,kt,vt,qgamma,kgamma,o[:,128:256])
        rq0=consumer.rope(consumer.normalized(q0,qgamma)).numpy()
        rq1=consumer.rope(consumer.normalized(q1,qgamma)).numpy()
        rk=consumer.rope(consumer.normalized(kt,kgamma)).numpy()
        value=vt.numpy()
    klog=log_features(rk,omega)
    qlog=[log_features(rq0,omega),log_features(rq1,omega)]
    z=np.zeros((64,),dtype=np.float32)
    numerator=np.zeros((64,128),dtype=np.float32)
    log_scale=np.full((64,),-np.inf,dtype=np.float32)
    output=np.zeros((2,256,128),dtype=np.float32)
    denominators=np.zeros((2,256),dtype=np.float32)
    for i in range(256):
        newer=np.maximum(log_scale,klog[i])
        decay=np.exp(log_scale-newer)
        current=np.exp(klog[i]-newer)
        z=z*decay+current
        numerator=numerator*decay[:,None]+current[:,None]*value[i,None,:]
        log_scale=newer
        for head in range(2):
            combined=qlog[head][i]+log_scale
            weights=np.exp(combined-np.max(combined))
            denom=np.dot(weights,z)
            assert np.isfinite(denom) and denom>0
            denominators[head,i]=denom
            output[head,i]=weights@numerator/denom
    # Dense attention matrix is a diagnostic *only*. Inference uses the 64×129
    # moment state above, never retained keys, values, probabilities or scores.
    heads={}
    projected=[]
    for head,teacher in enumerate((teacher0,teacher1)):
        log_kernel=np.full((256,256),-1e9,dtype=np.float32)
        for i in range(256):
            pair=qlog[head][i,None,:]+klog[:i+1]
            pivot=np.max(pair,axis=1)
            log_kernel[i,:i+1]=pivot+np.log(np.sum(np.exp(pair-pivot[:,None]),axis=1))
            valid=log_kernel[i,:i+1]
            peak=np.max(valid)
            log_kernel[i,:i+1]=valid-(peak+np.log(np.sum(np.exp(valid-peak))))
        probability=np.exp(log_kernel)
        direct=probability@value
        dense_gap=float(np.max(np.abs(direct-output[head])))
        assert dense_gap<2e-3,dense_gap
        approximate=torch.from_numpy(output[head])@o[:,head*128:(head+1)*128].T
        projected.append(approximate)
        true_logp=teacher[0].numpy()
        kl=float(np.mean(np.sum(np.exp(true_logp)*(true_logp-log_kernel),axis=1)))
        true_output=teacher[1]
        heads[f'head{head}']={'attention_kl':kl,
            'post_o_rel_sq':float((true_output-approximate).square().sum()/true_output.square().sum()),
            'value_prefix_vs_dense_max_abs':dense_gap,
            'log_feature_min_max':[float(np.min(qlog[head])),float(np.max(qlog[head]))],
            'denominator_min_max':[float(np.min(denominators[head])),float(np.max(denominators[head]))],
            'output_sse':float((true_output-approximate).square().sum()),
            'output_ref_sq':float(true_output.square().sum())}
    true_pair=teacher0[1]+teacher1[1]
    candidate_pair=projected[0]+projected[1]
    result={'panel':panel,'window':window,'table_sha256':TABLE_SHA,
        'fixture_sha256':'389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f',
        'capture_model_q_exact':True,'rows':[256*window,256*(window+1)],
        'shared_log_feature_min_max':[float(np.min(klog)),float(np.max(klog))],
        'final_per_feature_log_scale_min_max':[float(np.min(log_scale)),float(np.max(log_scale))],
        'heads':heads,'gqa_pair':{'post_o_rel_sq':float((true_pair-candidate_pair).square().sum()/true_pair.square().sum()),
            'output_sse':float((true_pair-candidate_pair).square().sum()),
            'output_ref_sq':float(true_pair.square().sum())}}
    (HERE/f'{panel}-{window}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'heads':heads,'gqa_pair':result['gqa_pair']},indent=2))

if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]))
