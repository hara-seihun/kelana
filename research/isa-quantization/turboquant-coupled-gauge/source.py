"""Paid Q/K gamma source for one frozen TurboQuant re-encoding; V unchanged."""
import importlib.util
from pathlib import Path
import numpy as np
import torch
from safetensors import safe_open
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent

def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path)
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 return module
old=load('original_turbo_source',ROOT/'turboquant-causal/source.py')
full=old.full
reader=load('coupled_gamma_reader',ROOT/'qwen-coupled-gamma/reader.py')
FIX_SHA=full.FIX_SHA

def arrays(panel,window):
 torch.set_num_threads(1)
 src=old.arrays(panel,window)
 replacement,baseline,e=reader.decode()
 with np.load(full.original.FIX) as f:
  x=torch.from_numpy(f['train' if panel=='train' else 'validation'][window*256:(window+1)*256].astype(np.float32).copy())
 with safe_open(full.original.MODEL,framework='pt',device='cpu') as model:
  q=model.get_tensor('model.layers.0.self_attn.q_proj.weight').float()
  k=model.get_tensor('model.layers.0.self_attn.k_proj.weight').float()
 with torch.no_grad():
  qr=(x@q.T).to(torch.bfloat16).float().reshape(256,16,128)
  kr=(x@k.T).to(torch.bfloat16).float().reshape(256,8,128)
  changed_q=full.rope(full.original.consumer.normalized(qr,torch.from_numpy(replacement[0]))).permute(1,0,2)
  changed_k=full.rope(full.original.consumer.normalized(kr,torch.from_numpy(replacement[1]))).permute(1,0,2)
  factor=torch.from_numpy(np.exp2(np.r_[e[:64],e[:64]]).astype(np.float32))
  assert torch.equal(changed_q,src['qrot']*factor) and torch.equal(changed_k,src['krot']/factor)
  src['qrot_new']=changed_q
  src['gauged_key']=changed_k.permute(1,0,2).to(torch.bfloat16).contiguous().view(torch.uint16).reshape(256,1024).numpy().copy()
 return src
