"""Independent ideal-real complete score/causal V/O replay and direct-token-table control."""
import hashlib
import importlib.util
import json
from pathlib import Path
import numpy as np
import torch
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
assert hashlib.sha256((FIX/'layer00-self_attn_q_proj.npz').read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
assert hashlib.sha256((FIX/'tokens.npz').read_bytes()).hexdigest()=='0479292cbee2cfc6cfc5f89e8f85dac85d2c0c275ed2704a59a7006faa7d66a2'
blob=(HERE/'score-image.bin').read_bytes()
assert len(blob)==16464 and hashlib.sha256(blob).hexdigest()=='6aff7977ca2569a77461d53079636fae7a280aba0337351b48697117c8d87454'
ids=np.frombuffer(blob,dtype='<u4',count=2).copy()
gram=np.frombuffer(blob,dtype='<f8',count=9,offset=8).reshape(3,3).copy()
coeff=np.frombuffer(blob,dtype='<f8',count=2*256*4,offset=80).reshape(2,256,2,2).copy()
span_blob=(HERE/'span-qk-image.bin').read_bytes()
assert len(span_blob)==6224 and hashlib.sha256(span_blob).hexdigest()=='c166eaeb4b4ac9a36fc6f1927792c9ce37565b3a71ce7a19b38851500a21be3a'
assert span_blob[:80]==blob[:80]
span_basis=np.frombuffer(span_blob,dtype='<f8',count=3*2*128,offset=80).reshape(3,2,128).copy()
with np.load(FIX/'tokens.npz') as tok,np.load(FIX/'layer00-self_attn_q_proj.npz') as fixture:
    held_ids=tok['validation'].ravel()
    anchors=np.stack([fixture['validation'][np.flatnonzero(held_ids==i)[0]] for i in ids]).astype(np.float64)
with safe_open(MODEL,framework='pt',device='cpu') as model:
    q=model.get_tensor('model.layers.0.self_attn.q_proj.weight')[:256].float().numpy().astype(np.float64)
    k=model.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float().numpy().astype(np.float64)
    v=model.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float().numpy().astype(np.float64)
    o=model.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].float().numpy().astype(np.float64)
    gq=model.get_tensor('model.layers.0.self_attn.q_norm.weight').float().numpy().astype(np.float64)
    gk=model.get_tensor('model.layers.0.self_attn.k_norm.weight').float().numpy().astype(np.float64)

def norm(z,gamma):return z/np.sqrt(np.dot(z,z)/128+1e-6)*gamma

def rotate(z,position):
    theta=position/(1_000_000.**(np.arange(64,dtype=np.float64)/64))
    co=np.cos(theta);si=np.sin(theta)
    return np.r_[z[:64]*co-z[64:]*si,z[:64]*si+z[64:]*co]

def direct_score(h,xa,xb,t,j):
    qh=norm(q[h*128:(h+1)*128]@xa,gq)
    kh=norm(k@xb,gk)
    return float(rotate(qh,t)@rotate(kh,j)/np.sqrt(128))

def factor_score(h,alpha,beta,delta):
    def inv(z,row):
        a,b=z
        norm2=row[0]*a*a+2*row[1]*a*b+row[2]*b*b
        return 1/np.sqrt(norm2/128+1e-6)
    return float(alpha@coeff[h,delta]@beta*inv(alpha,gram[h])*inv(beta,gram[2]))

def span_qk_score(h,alpha,beta,t,j):
    qlabel=alpha@span_basis[h]
    klabel=beta@span_basis[2]
    def inv(z,row):
        a,b=z
        return 1/np.sqrt((row[0]*a*a+2*row[1]*a*b+row[2]*b*b)/128+1e-6)
    qlabel*=inv(alpha,gram[h]);klabel*=inv(beta,gram[2])
    return float(rotate(qlabel,t)@rotate(klabel,j)/np.sqrt(128))

def softmax(x):
    a=np.exp(x-x.max(axis=-1,keepdims=True));return a/a.sum(axis=-1,keepdims=True)

def evaluate(label,labels):
    n=len(labels);assert n<=256
    inputs=labels@anchors
    value=inputs@v.T
    old=np.full((2,n,n),-np.inf)
    fused=np.full_like(old,-np.inf)
    span=np.full_like(old,-np.inf)
    tab=np.full_like(old,-np.inf)
    for h in range(2):
        for t in range(n):
            for j in range(t+1):
                old[h,t,j]=direct_score(h,inputs[t],inputs[j],t,j)
                fused[h,t,j]=factor_score(h,labels[t],labels[j],t-j)
                span[h,t,j]=span_qk_score(h,labels[t],labels[j],t,j)
                if label=='actual_two_token_alphabet':
                    ai=int(np.argmax(labels[t]));bj=int(np.argmax(labels[j]))
                    tab[h,t,j]=direct_table[h,t-j,ai,bj]
    diff=np.max(np.abs(old[np.isfinite(old)]-fused[np.isfinite(fused)]))
    result={'positions':n,'causal_scores':2*n*(n+1)//2,'max_abs_score_direct_vs_factor':float(diff),
            'max_abs_score_direct_vs_span_qk':float(np.max(np.abs(old[np.isfinite(old)]-span[np.isfinite(span)])))}
    outputs=[]
    for scores in (old,fused,span):
        weights=softmax(scores)
        out=(weights[0]@value)@o[:,:128].T+(weights[1]@value)@o[:,128:256].T
        outputs.append(out)
    result['max_abs_complete_post_o_direct_vs_factor']=float(np.max(np.abs(outputs[0]-outputs[1])))
    result['relative_squared_complete_post_o_direct_vs_factor']=float(np.sum((outputs[0]-outputs[1])**2)/np.sum(outputs[0]**2))
    result['max_abs_complete_post_o_direct_vs_span_qk']=float(np.max(np.abs(outputs[0]-outputs[2])))
    if label=='actual_two_token_alphabet':
        result['max_abs_score_direct_vs_direct_table']=float(np.max(np.abs(old[np.isfinite(old)]-tab[np.isfinite(tab)])))
        tt=softmax(tab)
        tabout=(tt[0]@value)@o[:,:128].T+(tt[1]@value)@o[:,128:256].T
        result['max_abs_post_o_direct_vs_direct_table']=float(np.max(np.abs(outputs[0]-tabout)))
    assert diff<1e-10 and result['max_abs_complete_post_o_direct_vs_factor']<1e-10
    assert result['max_abs_score_direct_vs_span_qk']<1e-10 and result['max_abs_complete_post_o_direct_vs_span_qk']<1e-10
    return result

# Strong direct-score control for the two *discrete* tokens, no Q/K vectors at inference.
direct_table=np.empty((2,256,2,2),dtype='<f8')
for h in range(2):
    for delta in range(256):
        for a in range(2):
            for b in range(2):direct_table[h,delta,a,b]=direct_score(h,anchors[a],anchors[b],delta,0)
(HERE/'direct-token-scores.f64').write_bytes(direct_table.tobytes())
real=np.eye(2,dtype=np.float64)[np.arange(32)%2]
# Continuous span test: these signed/mixed source vectors are not actual tokens.
coefficients=np.array([[1,0],[0,1],[.25,.75],[-.3,1.1]],dtype=np.float64)
synthetic=coefficients[np.arange(32)%4]
results={'image_sha256':hashlib.sha256(blob).hexdigest(),
         'span_qk_image_sha256':hashlib.sha256(span_blob).hexdigest(),
         'direct_token_table_sha256':hashlib.sha256(direct_table.tobytes()).hexdigest(),
         'two_token_ids':ids.tolist(),'actual_source_sequence':evaluate('actual_two_token_alphabet',real),
         'continuous_source_span':evaluate('continuous_source_span',synthetic),
         'ideal_real_contract':'FP64 stored BF16 source weights/states and gamma, exact epsilon, FP64 RoPE/causal softmax/V/O; synthetic sequence is not an observed Qwen history'}
# Explicit existing BF16 observer comparison: real relative-RoPE identity is not
# automatically exact for BF16 trigonometric rounding / projection order.
spec=importlib.util.spec_from_file_location('consumer',ROOT/'attention-consumer/measure.py')
consumer=importlib.util.module_from_spec(spec);spec.loader.exec_module(consumer)
torch.set_num_threads(1)
x=torch.from_numpy((real@anchors).astype(np.float32))
bf={}
with torch.no_grad():
    kt=(x@torch.from_numpy(k.astype(np.float32)).T).to(torch.bfloat16).float()
    vt=(x@torch.from_numpy(v.astype(np.float32)).T).to(torch.bfloat16).float()
    for h in range(2):
        qt=(x@torch.from_numpy(q[h*128:(h+1)*128].astype(np.float32)).T).to(torch.bfloat16).float()
        logits=consumer.head(qt,kt,vt,torch.from_numpy(gq.astype(np.float32)),torch.from_numpy(gk.astype(np.float32)),torch.from_numpy(o[:,h*128:(h+1)*128].astype(np.float32)))[2].numpy()
        expected=np.array([[direct_score(h,(real@anchors)[t],(real@anchors)[j],t,j) for j in range(t+1)] for t in range(len(real))],dtype=object)
        allowed=np.tril_indices(len(real))
        bf[f'q_head_{h}_score_max_abs_vs_ideal_real']=float(max(abs(logits[t,j]-expected[t][j]) for t,j in zip(*allowed)))
results['bf16_observer_difference']=bf
(HERE/'results.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
