"""Once-only Qwen train-only adaptation of official SKVQ min/max KMeans calibration."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
import torch
from sklearn.cluster import KMeans
from safetensors import safe_open
HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'kivi-causal-cache'
sys.path.insert(0,str(BASE))
import source as original

def run():
 torch.set_num_threads(1)
 with np.load(original.FIX) as f:x=torch.from_numpy(f['train'].astype(np.float32))
 assert x.shape==(2048,1024) and hashlib.sha256(original.FIX.read_bytes()).hexdigest()==original.FIX_SHA
 with safe_open(original.MODEL,framework='pt',device='cpu') as model:
  k=model.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float()
  v=model.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
  g=model.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
 with torch.no_grad():
  rawk=(x@k.T).to(torch.bfloat16).float()
  # Qwen-specific post-K RMSNorm+gamma, BEFORE RoPE; originals are canonical.
  kval=original.consumer.normalized(rawk,g).to(torch.bfloat16).float().numpy()
  vval=(x@v.T).to(torch.bfloat16).float().numpy()
 words=[];receipt={'official_source_commit':'fdfc7ec315c16293f68dd771850b47f5199787fc','fixture_sha256':original.FIX_SHA,
 'ntrain':2048,'kmeans':'minmax 2D, four clusters per128, n_init=10, random_state=0','features':{},'groups':{},'packed_code_bytes_per_token':{}}
 for kind,val in [('k',kval),('v',vval)]:
  feat=np.stack([val.min(0),val.max(0)],axis=1)
  labels=KMeans(n_clusters=4,n_init=10,random_state=0).fit_predict(feat)
  p=np.argsort(labels,kind='stable').astype('<i2')
  bounds=np.r_[0,np.cumsum(np.bincount(labels,minlength=4))].astype('<i2')
  widths=np.diff(bounds)
  assert sorted(p.tolist())==list(range(128)) and (widths>0).all()
  receipt['features'][kind]={'sha256':hashlib.sha256(feat.astype('<f4').tobytes()).hexdigest(),
                            'min_max_extrema':[float(feat.min()),float(feat.max())]}
  receipt['groups'][kind]={'permutation':p.tolist(),'bounds':bounds.tolist(),'widths':widths.tolist()}
  receipt['packed_code_bytes_per_token'][kind]=int(np.ceil(widths/4).sum())
  words.extend((p.tobytes(),bounds.tobytes()))
 descriptor=b''.join(words);assert len(descriptor)==532
 (HERE/'source-descriptors.bin').write_bytes(descriptor)
 receipt['descriptor_bytes']=532;receipt['descriptor_sha256']=hashlib.sha256(descriptor).hexdigest()
 receipt['packed_old_token_bytes']=sum(receipt['packed_code_bytes_per_token'].values())+32
 receipt['peak_256_bytes']=69*512+187*receipt['packed_old_token_bytes']+532
 receipt['post_256_bytes']=receipt['peak_256_bytes']
 (HERE/'source-descriptors.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({'groups':{s:{'widths':d['widths'],'bounds':d['bounds']} for s,d in receipt['groups'].items()},
 'codes':receipt['packed_code_bytes_per_token'],'state_256':receipt['peak_256_bytes'],'sha256':receipt['descriptor_sha256']},indent=2))
if __name__=='__main__':run()
