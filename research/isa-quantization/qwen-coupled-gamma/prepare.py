"""One train-only coupled norm-product diagonal balance with finite joint rounding."""
import hashlib,json,math,sys
from pathlib import Path
import numpy as np
from scipy.optimize import minimize
import torch
from safetensors import safe_open
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'skvq-global-gqa'))
import source as full
LN4=math.log(4.)

def covariance(panel):
 C=np.zeros((64,64),dtype=np.float64);count=0
 for window in range(8 if panel=='train' else 4):
  src=full.arrays(panel,window)
  q=src['qrot'].numpy().astype(np.float64)
  k=src['krot'].numpy().astype(np.float64)
  q2=(q[:,:,:64]**2+q[:,:,64:]**2)/128.
  k2=(k[:,:,:64]**2+k[:,:,64:]**2)
  kp=np.cumsum(k2,axis=1,dtype=np.float64)
  for h in range(16):C+=q2[h].T@kp[h//2]
  count+=16*256*257//2
 C/=count
 assert np.isfinite(C).all() and (C>0).all()
 return C,count

def objective(x,C):
 x=np.r_[0.,x]
 w=np.exp(LN4*x);iw=1/w
 F=float(w@(C@iw))
 grad=LN4*(w*(C@iw)-iw*(C.T@w))
 return F,grad[1:]

def round_joint(x,C):
 fractions=np.mod(x,1)
 cuts=sorted(set(float(1-f) for f in fractions if f>1e-13 and f<1-1e-13))
 edges=[0.]+cuts+[1.]
 candidates=[]
 for a,b in zip(edges[:-1],edges[1:]):
  u=(a+b)/2
  e=np.floor(x+u).astype(np.int64)
  e-=e[0]
  f,_=objective(e[1:].astype(float),C)
  if not any(z['e']==e.tolist() for z in candidates):candidates.append({'u':float(u),'e':e.tolist(),'F':f})
 assert len(candidates)<=65
 best=min(candidates,key=lambda z:(z['F'],z['u']))
 return best,candidates

def image(e):
 with safe_open(full.original.MODEL,framework='pt',device='cpu') as model:
  q=model.get_tensor('model.layers.0.self_attn.q_norm.weight').contiguous()
  k=model.get_tensor('model.layers.0.self_attn.k_norm.weight').contiguous()
 assert q.shape==k.shape==(128,) and q.dtype==k.dtype==torch.bfloat16
 exp=np.r_[e,e]
 data=[]
 for original,scale in ((q,exp),(k,-exp)):
  orig=original.float().numpy().copy()
  changed=np.ldexp(orig,scale.astype(int)).astype(np.float32)
  packed=torch.from_numpy(changed).to(torch.bfloat16)
  decoded=packed.float().numpy()
  assert np.array_equal(decoded,changed) and np.isfinite(decoded).all() and np.all(decoded!=0)
  bits=packed.view(torch.int16).numpy().view(np.uint16)
  assert np.all((bits&0x7f80)>0) and np.all((bits&0x7f80)<0x7f80)
  data.append(bits.astype('<u2').tobytes())
 result=b''.join(data);assert len(result)==512
 return result,hashlib.sha256(q.view(torch.int16).numpy().astype('<i2').tobytes()+k.view(torch.int16).numpy().astype('<i2').tobytes()).hexdigest()

def run():
 torch.set_num_threads(1)
 C,count=covariance('train')
 assert count==8*16*32896
 np.save(HERE/'train-pair-moment.npy',C)
 result=minimize(objective,np.zeros(63),args=(C,),jac=True,method='BFGS',options={'gtol':1e-7,'maxiter':1000})
 x=np.r_[0.,result.x];F,grad=objective(result.x,C)
 assert np.isfinite(F) and np.isfinite(x).all()
 best,candidates=round_joint(x,C);e=np.asarray(best['e'])
 blob,original_hash=image(e)
 (HERE/'replacement-qk-gamma.bf16').write_bytes(blob)
 r={'policy':'uniform causal pairs across all8 train windows,16 Q heads, every visible i<=t; q includes 1/sqrt128',
    'train_pair_count':count,'C_sha256':hashlib.sha256(C.astype('<f8').tobytes()).hexdigest(),
    'solver':'one scipy BFGS on x1..x63 with x0=0, analytic gradient, convex modulo constant',
    'solver_success':bool(result.success),'solver_message':str(result.message),'iterations':int(result.nit),
    'continuous_x':x.tolist(),'continuous_F':F,'gradient_inf':float(np.max(abs(grad))),
    'gradient_inf_relative':float(np.max(abs(grad))/F),'rounding_candidates':candidates,'chosen_u':best['u'],
    'integer_e':e.tolist(),'integer_F':best['F'],'baseline_F':float(C.sum()),'ratio_rounded_to_continuous':best['F']/F,
    'gamma_image_sha256':hashlib.sha256(blob).hexdigest(),'original_gamma_sha256':original_hash,
    'replacement_bytes':512,'incremental_static_bytes':0,'source_checkpoint_sha256':'f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b'}
 (HERE/'prepare.json').write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps({key:r[key] for key in ('train_pair_count','solver_success','iterations','gradient_inf','continuous_F','integer_F','baseline_F','ratio_rounded_to_continuous','gamma_image_sha256')},indent=2))
if __name__=='__main__':run()
