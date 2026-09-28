"""Independent paid BF16 image parser and reciprocal pair exact-field checks."""
from pathlib import Path
import hashlib,json
import numpy as np
import torch
from safetensors import safe_open
HERE=Path(__file__).resolve().parent
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')

def decode():
 r=json.loads((HERE/'prepare.json').read_text())
 blob=(HERE/'replacement-qk-gamma.bf16').read_bytes()
 assert len(blob)==512 and hashlib.sha256(blob).hexdigest()==r['gamma_image_sha256']
 bits=np.frombuffer(blob,dtype='<u2').astype(np.uint32)
 assert np.all((bits&0x7f80)>0) and np.all((bits&0x7f80)<0x7f80)
 values=(bits<<16).view('<f4').copy().reshape(2,128)
 assert np.isfinite(values).all()
 with safe_open(MODEL,framework='pt',device='cpu') as f:
  old=[f.get_tensor('model.layers.0.self_attn.'+name+'_norm.weight').clone() for name in ('q','k')]
 old_bytes=b''.join(z.view(torch.int16).numpy().astype('<i2').tobytes() for z in old)
 assert hashlib.sha256(old_bytes).hexdigest()==r['original_gamma_sha256']
 base=np.stack([z.float().numpy() for z in old])
 assert np.all(base!=0)
 ratio=values[0]/base[0];inverse=base[1]/values[1]
 e=np.rint(np.log2(ratio)).astype(np.int32)
 assert np.array_equal(ratio,inverse) and np.array_equal(ratio,np.exp2(e))
 assert np.array_equal(e[:64],e[64:]) and e[0]==0 and np.array_equal(e[:64],r['integer_e'])
 assert np.array_equal(values[0],np.ldexp(base[0],e))
 assert np.array_equal(values[1],np.ldexp(base[1],-e))
 return values,base,e
