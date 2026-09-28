"""Canonical Qwen observer with post-Knorm/pre-RoPE key for SKVQ Qwen transfer."""
import importlib.util,sys
from pathlib import Path
import numpy as np
import torch
from safetensors import safe_open
HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'kivi-causal-cache'
spec=importlib.util.spec_from_file_location('skvq_original_qwen',BASE/'source.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
FIX_SHA=original.FIX_SHA

def arrays(panel,window):
 src=original.arrays(panel,window)
 with np.load(original.FIX) as f:
  x=torch.from_numpy(f['train' if panel=='train' else 'validation'][window*256:(window+1)*256].astype(np.float32).copy())
 with safe_open(original.MODEL,framework='pt',device='cpu') as model:
  wk=model.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
  gamma=model.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
 with torch.no_grad():
  raw=(x@wk.T).to(torch.bfloat16).float()
  normalized=original.consumer.normalized(raw,gamma)
  roundtrip=original.consumer.rope(normalized)
  assert torch.equal(roundtrip,src['krot'])
  pre=normalized.to(torch.bfloat16).contiguous()
 src['prekey']=pre.view(torch.uint16).numpy().copy()
 src['prekey_float']=pre.float()
 src['value_float']=torch.from_numpy((src['value'].astype(np.uint32)<<16).view(np.float32).copy())
 return src
