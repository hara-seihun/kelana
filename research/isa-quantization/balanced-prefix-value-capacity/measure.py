"""Oracle affine-value-hull post-O projection for one 64-query chunk."""
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
TABLE=ROOT/'qwen-positive-kernel/gaussian-features-64x128-f16.bin'
TABLE_SHA='c79b3d345a0bfc6a1b2e4a6e8f04246e5b7750e885ae17f3eb36ad66d53d86f5'
GAMMA_SHA='c8173158c88975e808804bb89a9e59b4cfa485a60f8d854fc4963ad89c830865'
CENTER_SHA='3e9fa69a8942b762f0cd041e6a70bfa0c7833957f0d960a6032b0775058cd6a2'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);sys.modules[name]=m;spec.loader.exec_module(m)
    return m

def update(logkey,value,maximum,denominator,numerator):
    newmax=np.maximum(maximum,logkey)
    decay=np.exp(maximum-newmax)
    current=np.exp(logkey-newmax)
    denominator=denominator*decay+current
    numerator=numerator*decay[:,None]+current[:,None]*value[None,:]
    return newmax,denominator,numerator

def project(means,R,Q,teacher):
    # Two independent affine mixtures of the *same* 64 value means, projected
    # through the actual two 1024×128 O blocks. No query positivity/softmax.
    anchor=means[0]
    delta=(means[1:]-anchor).T
    matrix=np.concatenate((R[:,:128]@delta,R[:,128:]@delta),axis=1)
    y=teacher.astype(np.float64)
    reduced=Q.T@y
    residual=reduced-(R[:,:128]+R[:,128:])@anchor
    outside=float(np.sum((y-Q@reduced)**2))
    U,s,_=np.linalg.svd(matrix,full_matrices=False)
    reference=float(s[0]) if len(s) else 0.
    result={}
    for label,epsilon in (('float64_cutoff',np.finfo(np.float64).eps),
                           ('float32_resolved_cutoff',np.finfo(np.float32).eps)):
        keep=s>epsilon*max(matrix.shape)*reference if reference>0 else np.zeros(len(s),dtype=bool)
        rank=int(keep.sum())
        projected=U[:,keep]@(U[:,keep].T@residual) if rank else np.zeros_like(residual)
        result[label]={'sse':outside+float(np.sum((residual-projected)**2)),
                       'numerical_rank':rank,
                       'largest_singular_value':reference,
                       'smallest_kept_singular_value':float(s[keep][-1]) if rank else 0.,
                       'condition_of_kept_span':float(reference/s[keep][-1]) if rank else 0.}
    return result,outside

def main(panel,window,chunk):
    torch.set_num_threads(1)
    assert panel in ('train','held') and chunk in range(4)
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    assert hashlib.sha256(TABLE.read_bytes()).hexdigest()==TABLE_SHA
    gamma_reader=load('capacity_paid_gamma',ROOT/'qwen-balanced-gamma/reader.py')
    center_reader=load('capacity_paid_center',ROOT/'qwen-balanced-feature-reader/center_reader.py')
    gamma,_,_=gamma_reader.decode()
    center=center_reader.decode()
    assert gamma_reader.SHA==GAMMA_SHA and center_reader.SHA==CENTER_SHA
    consumer=load('canonical_qwen_consumer_for_hull',ROOT/'attention-consumer/measure.py')
    with np.load(FIX) as f:
        positions=f['train' if panel=='train' else 'validation']
        assert window in range(len(positions)//256)
        x=torch.from_numpy(positions[window*256:(window+1)*256].copy().astype(np.float32))
        original=f['weight'][:128].astype(np.float32)
    with safe_open(MODEL,framework='pt',device='cpu') as checkpoint:
        q=checkpoint.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float()
        k=checkpoint.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
        v=checkpoint.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        o=checkpoint.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].float()
        original_qgamma=checkpoint.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        original_kgamma=checkpoint.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    assert np.array_equal(original,q[:128].numpy())
    with torch.no_grad():
        qraw=[(x@q[h*128:(h+1)*128].T).to(torch.bfloat16).float() for h in range(2)]
        kraw=(x@k.T).to(torch.bfloat16).float()
        value=(x@v.T).to(torch.bfloat16).float()
        kgamma=torch.from_numpy(gamma[1])
        rotary_key=consumer.rope(consumer.normalized(kraw,kgamma)).numpy()
        teacher=[consumer.head(qa,kraw,value,original_qgamma,original_kgamma,o[:,h*128:(h+1)*128]) for h,qa in enumerate(qraw)]
        teacher_pair=(teacher[0][1]+teacher[1][1]).numpy().astype(np.float64)
    omega=np.frombuffer(TABLE.read_bytes(),dtype='<f2').astype(np.float32).reshape(64,128)
    key=rotary_key*128**-.25-center[None,:]
    log32=(key@omega.T-.5*np.sum(key*key,axis=1,keepdims=True)).astype(np.float32)
    key64=rotary_key.astype(np.float64)*128**-.25-center.astype(np.float64)[None,:]
    omega64=omega.astype(np.float64)
    log64=key64@omega64.T-.5*np.sum(key64*key64,axis=1,keepdims=True)
    V=value.numpy()
    O=o.numpy().astype(np.float64)
    Q,R=np.linalg.qr(O,mode='reduced')
    assert Q.shape==(1024,256) and R.shape==(256,256)
    state=[(np.full(64,-np.inf,dtype=np.float32),np.zeros(64,dtype=np.float32),np.zeros((64,128),dtype=np.float32)),
           (np.full(64,-np.inf,dtype=np.float64),np.zeros(64,dtype=np.float64),np.zeros((64,128),dtype=np.float64))]
    rows=[]
    for i in range(256):
        state[0]=update(log32[i],V[i],*state[0])
        state[1]=update(log64[i],V[i].astype(np.float64),*state[1])
        if not (chunk*64<=i<(chunk+1)*64):continue
        means32=(state[0][2]/state[0][1][:,None]).astype(np.float64)
        means64=state[1][2]/state[1][1][:,None]
        assert np.isfinite(means32).all() and np.isfinite(means64).all()
        observed,out32=project(means32,R,Q,teacher_pair[i])
        ideal,out64=project(means64,R,Q,teacher_pair[i])
        rows.append({'position':i,'theoretical_affine_rank_cap':2*min(63,i),
            'teacher_pair_o_ref_sq':float(np.sum(teacher_pair[i]**2)),
            'fp32_prefix_means_vs_fp64_max_abs':float(np.max(np.abs(means32-means64))),
            'fp32_prefix_state':observed,'fp64_finite_table_state':ideal,
            'original_O_columnspace_sse':out64})
    result={'panel':panel,'window':window,'chunk':chunk,'source_rows':[window*256,(window+1)*256],
        'fixture_sha256':'389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f',
        'image_sha256':{'gamma':GAMMA_SHA,'center':CENTER_SHA,'generic_table':TABLE_SHA},
        'rows':rows}
    (HERE/f'{panel}-{window}-chunk{chunk}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'chunk':chunk,'count':len(rows),
        'fp32_oracle_sse':sum(r['fp32_prefix_state']['float64_cutoff']['sse'] for r in rows),
        'fp64_oracle_sse':sum(r['fp64_finite_table_state']['float64_cutoff']['sse'] for r in rows)},indent=2))

if __name__=='__main__':main(sys.argv[1],int(sys.argv[2]),int(sys.argv[3]))
