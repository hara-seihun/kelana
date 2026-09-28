"""Pinned Qwen layer0 all 16 Q / 8 shared KV producer and full O consumer."""
import hashlib,importlib.util,math
from pathlib import Path
import numpy as np
import torch
from safetensors import safe_open
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
spec=importlib.util.spec_from_file_location('kivi_source',ROOT/'kivi-causal-cache/source.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
FIX_SHA=original.FIX_SHA

def rope(z):
 # Input [tokens,heads,128], canonical bf16 sine/cosine geometry.
 pos=torch.arange(z.shape[0],dtype=torch.float32)
 inv=1/(1_000_000.**(torch.arange(64,dtype=torch.float32)/64))
 theta=torch.outer(pos,inv)
 cos=torch.cat((theta.cos(),theta.cos()),dim=-1).to(torch.bfloat16).float()[:,None,:]
 sin=torch.cat((theta.sin(),theta.sin()),dim=-1).to(torch.bfloat16).float()[:,None,:]
 return z*cos+torch.cat((-z[...,64:],z[...,:64]),dim=-1)*sin

def arrays(panel,window):
 torch.set_num_threads(1)
 assert panel in ('train','held') and hashlib.sha256(original.FIX.read_bytes()).hexdigest()==FIX_SHA
 with np.load(original.FIX) as f:
  data=f['train' if panel=='train' else 'validation']
  assert 0<=window<len(data)//256
  x=torch.from_numpy(data[window*256:(window+1)*256].astype(np.float32).copy())
 with safe_open(original.MODEL,framework='pt',device='cpu') as model:
  q=model.get_tensor('model.layers.0.self_attn.q_proj.weight').float()
  k=model.get_tensor('model.layers.0.self_attn.k_proj.weight').float()
  v=model.get_tensor('model.layers.0.self_attn.v_proj.weight').float()
  o=model.get_tensor('model.layers.0.self_attn.o_proj.weight').float()
  qg=model.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
  kg=model.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
 assert q.shape==(2048,1024) and k.shape==v.shape==(1024,1024) and o.shape==(1024,2048)
 assert qg.shape==kg.shape==(128,)
 with torch.no_grad():
  qr=(x@q.T).to(torch.bfloat16).float().reshape(256,16,128)
  kr=(x@k.T).to(torch.bfloat16).float().reshape(256,8,128)
  vr=(x@v.T).to(torch.bfloat16).float().reshape(256,8,128)
  qrot=rope(original.consumer.normalized(qr,qg)).permute(1,0,2).contiguous()
  pre=original.consumer.normalized(kr,kg)
  krot=rope(pre).permute(1,0,2).contiguous()
  # Qwen BF16 pre-RoPE recent adaptation; canonical target keeps FP32 pre-RoPE gamma product.
  prebits=pre.to(torch.bfloat16).contiguous().view(torch.uint16).reshape(256,1024).numpy().copy()
  vbits=vr.to(torch.bfloat16).contiguous().view(torch.uint16).reshape(256,1024).numpy().copy()
  logits=torch.bmm(qrot,krot.repeat_interleave(2,dim=0).transpose(1,2))/math.sqrt(128)
  mask=torch.ones(256,256,dtype=torch.bool).triu(1)
  logits=logits.masked_fill(mask[None],-1e9)
  logp=logits.log_softmax(-1)
  mix=torch.bmm(logp.exp(),vr.permute(1,0,2).repeat_interleave(2,dim=0))
  teacher=mix.permute(1,0,2).reshape(256,2048)@o.T
 return {'prekey':prebits,'value':vbits,'qrot':qrot,'krot':krot,'vraw':vr.permute(1,0,2).contiguous(),
         'o':o,'teacher':teacher,'teacher_logp':logp,'teacher_logits':logits}
