"""One train-only max-envelope, exact BF16 V/O row/column power-of-two fold."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
import torch
from safetensors import safe_open
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'skvq-global-gqa'))
from source import arrays,original

def sha(b):return hashlib.sha256(b).hexdigest()

def source_weights():
 with safe_open(original.MODEL,framework='pt',device='cpu') as model:
  v=model.get_tensor('model.layers.0.self_attn.v_proj.weight').contiguous()
  o=model.get_tensor('model.layers.0.self_attn.o_proj.weight').contiguous()
 assert v.shape==(1024,1024) and o.shape==(1024,2048) and v.dtype==o.dtype==torch.bfloat16
 return v,o

def main():
 torch.set_num_threads(1)
 maxima=np.zeros((8,128),dtype=np.float64)
 for i in range(8):
  vbits=arrays('train',i)['value'].reshape(256,8,128)
  vr=(vbits.astype(np.uint32)<<16).view(np.float32)
  maxima=np.maximum(maxima,abs(vr).max(0).astype(np.float64))
 exponents=np.zeros((8,128),dtype=np.int16)
 groups=[]
 for h in range(8):
  for g in range(4):
   group=maxima[h,g*32:(g+1)*32]
   top=float(group.max());assert np.isfinite(top)
   for j,mag in enumerate(group):
    if mag==0:continue
    exponent=0
    while mag*(2.0**(exponent+1))<=top:
     exponent+=1
    assert mag*(2.0**exponent)<=top and mag*(2.0**(exponent+1))>top
    exponents[h,g*32+j]=exponent
   groups.append(top)
 v,o=source_weights()
 vf=v.float().numpy();of=o.float().numpy()
 outv=np.ldexp(vf,exponents.reshape(1024)[:,None].astype(np.int32)).astype(np.float32)
 outo=of.copy()
 for q in range(16):
  h=q//2
  outo[:,q*128:(q+1)*128]=np.ldexp(of[:,q*128:(q+1)*128],-exponents[h].astype(np.int32)[None,:])
 assert np.isfinite(outv).all() and np.isfinite(outo).all()
 vb=torch.from_numpy(outv.copy()).to(torch.bfloat16).contiguous()
 ob=torch.from_numpy(outo.copy()).to(torch.bfloat16).contiguous()
 # BF16 dyadic products must have survived exactly in both physical tensors.
 assert np.array_equal(vb.float().numpy(),outv) and np.array_equal(ob.float().numpy(),outo)
 assert np.array_equal(np.ldexp(vb.float().numpy(),-exponents.reshape(1024).astype(np.int32)[:,None]),vf)
 for q in range(16):
  h=q//2
  assert np.array_equal(np.ldexp(ob.float().numpy()[:,q*128:(q+1)*128],exponents[h].astype(np.int32)[None,:]),of[:,q*128:(q+1)*128])
 raw=vb.view(torch.uint16).numpy().astype('<u2').tobytes()+ob.view(torch.uint16).numpy().astype('<u2').tobytes()
 assert len(raw)==6291456
 (HERE/'replacement-v-o.bf16').write_bytes(raw)
 record={'fixture_sha256':original.FIX_SHA,'original_model_file_sha256':'f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b',
         'replacement_image_sha256':sha(raw),'replacement_image_bytes':len(raw),
         'original_v_sha256':sha(v.view(torch.uint16).numpy().astype('<u2').tobytes()),
         'original_o_sha256':sha(o.view(torch.uint16).numpy().astype('<u2').tobytes()),
         'train_maxima':maxima.tolist(),'group_maxima':groups,'exponents':exponents.tolist(),
         'exponent_histogram':{str(int(k)):int(c) for k,c in zip(*np.unique(exponents,return_counts=True))},
         'zero_source_channels':int(np.count_nonzero(maxima==0)),
         'max_transformed_train_channel':float(np.max(np.ldexp(maxima,exponents.astype(np.int32))))}
 (HERE/'source-fields.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps({k:record[k] for k in ('replacement_image_sha256','exponent_histogram','zero_source_channels','max_transformed_train_channel')}))
if __name__=='__main__':main()
