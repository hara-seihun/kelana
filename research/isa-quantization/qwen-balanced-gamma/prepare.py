"""Analytic 64-pair power-of-two reciprocal Q/K gamma balance, train only."""
from pathlib import Path
import hashlib
import importlib.util
import json
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
IMAGE=HERE/'balanced-qk-gamma-bf16.bin'

def load_source():
    torch.set_num_threads(1)
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        q=f.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float()
        k=f.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        gq=f.get_tensor('model.layers.0.self_attn.q_norm.weight').clone()
        gk=f.get_tensor('model.layers.0.self_attn.k_norm.weight').clone()
    spec=importlib.util.spec_from_file_location('source_qwen_rope',ROOT/'attention-consumer/measure.py')
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    return q,k,gq,gk,mod

def projected(window,source):
    q,k,gq,gk,mod=source
    x=torch.from_numpy(window.astype(np.float32))
    with torch.no_grad():
        query=[(mod.rope(mod.normalized((x@q[h*128:(h+1)*128].T).to(torch.bfloat16).float(),gq)).numpy()*128**-.25).astype(np.float64) for h in range(2)]
        key=(mod.rope(mod.normalized((x@k.T).to(torch.bfloat16).float(),gk)).numpy()*128**-.25).astype(np.float64)
    return query,key

def power_two_gamma(gamma,exponents):
    assert gamma.dtype==torch.bfloat16 and tuple(gamma.shape)==(128,)
    original=gamma.float().numpy().astype(np.float32)
    target=np.ldexp(original,exponents.astype(np.int32))
    assert np.isfinite(target).all() and np.all(target[original!=0]!=0)
    roundtrip=torch.from_numpy(target.copy()).to(torch.bfloat16).float().numpy()
    assert np.array_equal(roundtrip,target),'power-of-two scaling did not remain exactly BF16-representable'
    word=torch.from_numpy(target.copy()).to(torch.bfloat16).view(torch.int16).numpy().astype('<i2')
    exponent_bits=word.view('<u2')&0x7f80
    assert np.all((exponent_bits!=0)&(exponent_bits!=0x7f80)),'BF16 underflow or overflow'
    return word.tobytes()

def main():
    source=load_source()
    with np.load(FIX) as f:
        train=f['train'].reshape(8,256,1024)
        assert np.array_equal(f['weight'][:128].astype(np.float32),source[0][:128].numpy())
    counts=np.arange(1,257,dtype=np.float64)
    reverse=np.arange(256,0,-1,dtype=np.float64)
    qsum=np.zeros(128);ksum=np.zeros(128)
    q2=np.zeros(128);k2=np.zeros(128);cross=np.zeros(128)
    for window in train:
        queries,key=projected(window,source)
        ksum+=2*np.sum(key*reverse[:,None],axis=0)
        k2+=2*np.sum(key*key*reverse[:,None],axis=0)
        prefix=np.cumsum(key,axis=0)
        for q in queries:
            qsum+=np.sum(q*counts[:,None],axis=0)
            q2+=np.sum(q*q*counts[:,None],axis=0)
            cross+=np.sum(q*prefix,axis=0)
    n=8*2*(256*257//2)
    mq=qsum/n;mk=ksum/n
    va=q2/n-mq*mq;vb=k2/n-mk*mk
    covariance=cross/n-mq*mk
    a=va[:64]+va[64:];b=vb[:64]+vb[64:]
    assert np.all(a>0) and np.all(b>0)
    ideal=.25*np.log2(b/a)
    lower=np.floor(ideal).astype(np.int32);upper=np.ceil(ideal).astype(np.int32)
    low=a*np.exp2(2*lower)+b*np.exp2(-2*lower)
    high=a*np.exp2(2*upper)+b*np.exp2(-2*upper)
    e=np.where(low<=high,lower,upper)
    full=np.r_[e,e]
    qdata=power_two_gamma(source[2],full)
    kdata=power_two_gamma(source[3],-full)
    image=qdata+kdata
    assert len(image)==512
    IMAGE.write_bytes(image)
    original_mean=float(np.sum(va+vb+2*covariance))
    balanced_mean=float(np.sum(np.ldexp(va,2*full)+np.ldexp(vb,-2*full)+2*covariance))
    result={'image_sha256':hashlib.sha256(image).hexdigest(),'image_bytes':len(image),
        'original_gamma_sha256':hashlib.sha256(source[2].view(torch.int16).numpy().astype('<i2').tobytes()+source[3].view(torch.int16).numpy().astype('<i2').tobytes()).hexdigest(),
        'pair_exponents':e.tolist(),'exponent_min_max':[int(e.min()),int(e.max())],
        'positive_pair_covariance_trace_min_max':{'query':[float(a.min()),float(a.max())],
            'key':[float(b.min()),float(b.max())]},
        'train_uncentered_original_mean_exponent':original_mean+float(np.sum((mq+mk)**2)),
        'train_centered_original_mean_exponent':original_mean,
        'train_centered_balanced_mean_exponent':balanced_mean,
        'all_gamma_fields_exact_bf16_power_two':True}
    (HERE/'prepare.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
