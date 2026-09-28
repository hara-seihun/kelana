"""Frozen contextual layer-1 CPU source and full-attention teacher, one window per call."""
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
CAP = DATA/'full-model/mlp-quantized-producer-capture.npz'
TOK = DATA/'fixtures/qwen3-0.6b-wikitext/tokens.npz'
MODEL = DATA/'models/qwen3-0.6b/model.safetensors'
EXPECTED = {CAP:'aa1e671af9283656efd7a95f2732a27662ce8c658766af5ee88f5e7d27b9e69c', TOK:'0479292cbee2cfc6cfc5f89e8f85dac85d2c0c275ed2704a59a7006faa7d66a2', MODEL:'f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b'}

def sha(data): return hashlib.sha256(data).hexdigest()
def file_sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(4*1024*1024),b''): h.update(b)
    return h.hexdigest()

def norm(x,gamma):
    x=x.float()
    n=(x*torch.rsqrt(x.square().mean(-1,keepdim=True)+1e-6)).to(torch.bfloat16).float()
    return (n*gamma).to(torch.bfloat16).float()

def rope(x):
    p=torch.arange(256,dtype=torch.float32)
    inv=torch.pow(torch.tensor(1_000_000.,dtype=torch.float32),-torch.arange(64,dtype=torch.float32)/64)
    angle=torch.outer(p,inv)
    c=angle.cos().to(torch.bfloat16).float()[:,None,:]
    s=angle.sin().to(torch.bfloat16).float()[:,None,:]
    return torch.cat((x[...,:64]*c-x[...,64:]*s,x[...,64:]*c+x[...,:64]*s),dim=-1)

def bits(x): return x.contiguous().to(torch.bfloat16).view(torch.uint16).numpy().copy()

def run(panel,w):
    assert panel in ('train','validation') and 0<=w<(8 if panel=='train' else 4)
    torch.set_num_threads(1)
    for path,digest in EXPECTED.items(): assert file_sha(path)==digest,path
    meta=json.loads(CAP.with_suffix('.json').read_text())
    assert meta['source_sha256']=='42eae1e97b1a5a609022f62df15770c6f9ffb10505e46dcbc7987c74ffa5883d'
    assert meta['capture_sha256']==EXPECTED[CAP]
    with np.load(CAP) as f: residual=f[f'{panel}_teacher_post'][w*256:(w+1)*256].copy()
    with np.load(TOK) as f: ids=f[panel][w].copy()
    assert residual.shape==(256,1024) and residual.dtype==np.uint16 and ids.shape==(256,)
    x=torch.from_numpy(residual.copy()).view(torch.bfloat16).float()
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        prefix='model.layers.1.'
        weight={k:f.get_tensor(prefix+'self_attn.'+k+'_proj.weight').float().contiguous() for k in ('q','k','v','o')}
        gamma=f.get_tensor(prefix+'input_layernorm.weight').float()
        qg=f.get_tensor(prefix+'self_attn.q_norm.weight').float()
        kg=f.get_tensor(prefix+'self_attn.k_norm.weight').float()
    with torch.no_grad():
        z_torch=norm(x,gamma)
        # Use the prior contextual-value-sharing norm and V BLAS order exactly.
        # Torch and NumPy disagree at rare BF16 ties; all projections share this input.
        def bf16_np(a):
            b=np.ascontiguousarray(a,dtype=np.float32).view(np.uint32)
            return ((b+np.uint32(0x7fff)+((b>>16)&1))>>16).astype('<u2')
        source_fp=(residual.astype('<u4')<<16).view('<f4')
        z_np=bf16_np(source_fp*np.reciprocal(np.sqrt(np.mean(source_fp*source_fp,axis=1,keepdims=True)+np.float32(1e-6))))
        z_np=bf16_np((z_np.astype('<u4')<<16).view('<f4')*gamma.numpy())
        norm_disagreements=int(np.count_nonzero(z_np!=z_torch.contiguous().to(torch.bfloat16).view(torch.uint16).numpy()))
        z=torch.from_numpy(z_np.copy()).view(torch.bfloat16).float()
        raw={k:(z@weight[k].T).to(torch.bfloat16).float() for k in ('q','k')}
        v_np=bf16_np((z_np.astype('<u4')<<16).view('<f4')@weight['v'].numpy().T)
        raw['v']=torch.from_numpy(v_np.copy()).view(torch.bfloat16).float()
        assert raw['q'].shape==(256,2048) and raw['k'].shape==raw['v'].shape==(256,1024)
        q=rope(norm(raw['q'].reshape(256,16,128),qg)).permute(1,0,2).contiguous()
        k=rope(norm(raw['k'].reshape(256,8,128),kg)).permute(1,0,2).contiguous()
        v=raw['v'].reshape(256,8,128).permute(1,0,2).contiguous()
        group=torch.arange(16)//2
        scores=torch.bmm(q,k[group].transpose(1,2))/(128**.5)
        scores.masked_fill_(torch.ones(256,256,dtype=torch.bool).triu(1)[None,:,:],-1e9)
        mixed=torch.bmm(scores.softmax(-1),v[group]).permute(1,0,2).reshape(256,2048)
        teacher=(mixed@weight['o'].T).numpy().copy()
        qb=q.numpy().copy()
        kb=bits(k.permute(1,0,2))
        vb=bits(raw['v'].reshape(256,8,128))
        arrays={'residual':residual,'token_ids':ids,'q':qb,'k':kb,'v':vb,'teacher':teacher}
        target=HERE/f'{panel}-{w}-source.npz'
        np.savez_compressed(target,**arrays)
        receipt={'panel':panel,'window':w,'model_revision':'c1899de289a04d12100db370d81485cdf75e47ca','input_sha256':{str(p):d for p,d in EXPECTED.items()},'capture_meta_sha256':file_sha(CAP.with_suffix('.json')),'capture_source_sha256':meta['source_sha256'],'source_file_sha256':file_sha(target),'arrays':{name:{'shape':list(a.shape),'dtype':str(a.dtype),'sha256':sha(a.tobytes())} for name,a in arrays.items()},'teacher_sq':float(np.sum(teacher.astype(np.float64)**2)),'torch_vs_numpy_input_norm_bf16_differences':norm_disagreements,'contract':'layer1 original weights, BF16 residual/norm/projection/rotated K cache, FP32 rotary Q and teacher K, FP32 causal softmax/V/O; CPU rounding not original GPU layer1 capture'}
        (HERE/f'{panel}-{w}-source.json').write_text(json.dumps(receipt,indent=2)+'\n')
        print(json.dumps({'panel':panel,'window':w,'teacher_sq':receipt['teacher_sq'],'source_sha256':receipt['source_file_sha256']}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
