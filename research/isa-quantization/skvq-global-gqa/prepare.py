"""Single train-only official global KV-channel KMeans, adapted to Qwen head_dim."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
import torch
from sklearn.cluster import KMeans
from safetensors import safe_open
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'kivi-causal-cache'))
import source as original

def run():
 torch.set_num_threads(1)
 with np.load(original.FIX) as f:x=torch.from_numpy(f['train'].astype(np.float32))
 assert x.shape==(2048,1024) and hashlib.sha256(original.FIX.read_bytes()).hexdigest()==original.FIX_SHA
 with safe_open(original.MODEL,framework='pt',device='cpu') as model:
  k=model.get_tensor('model.layers.0.self_attn.k_proj.weight').float()
  v=model.get_tensor('model.layers.0.self_attn.v_proj.weight').float()
  kg=model.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
 assert k.shape==v.shape==(1024,1024) and kg.shape==(128,)
 with torch.no_grad():
  raw=(x@k.T).to(torch.bfloat16).float().reshape(-1,8,128)
  normalized=original.consumer.normalized(raw,kg).to(torch.bfloat16).float().reshape(-1,1024).numpy()
  values=(x@v.T).to(torch.bfloat16).float().numpy()
 receipt={'upstream_commit':'fdfc7ec315c16293f68dd771850b47f5199787fc','fixture_sha256':original.FIX_SHA,
 'calibration':'global 1024-channel post-Knorm/pre-RoPE K + projected V; minmax 2D, KMeans32 n_init10 random_state0, train2048','groups':{},'feature_hash':{},'code_bytes':{}}
 words=[]
 for kind,data in [('k',normalized),('v',values)]:
  feat=np.stack((data.min(0),data.max(0)),axis=1)
  labels=KMeans(n_clusters=32,n_init=10,random_state=0).fit_predict(feat)
  # Official labels.argsort() with deterministic stable within-cluster order.
  p=np.argsort(labels,kind='stable').astype('<i2')
  b=np.r_[0,np.cumsum(np.bincount(labels,minlength=32))].astype('<i2')
  widths=np.diff(b)
  assert (widths>0).all() and sorted(p.tolist())==list(range(1024))
  receipt['groups'][kind]={'permutation':p.tolist(),'bounds':b.tolist(),'widths':widths.tolist()}
  receipt['feature_hash'][kind]=hashlib.sha256(feat.astype('<f4').tobytes()).hexdigest()
  receipt['code_bytes'][kind]=int(((widths+3)//4).sum())
  words.extend((p.tobytes(),b.tobytes()))
 blob=b''.join(words)
 assert len(blob)==4228
 (HERE/'global-descriptors.bin').write_bytes(blob)
 receipt['descriptor_sha256']=hashlib.sha256(blob).hexdigest()
 receipt['descriptor_bytes']=len(blob)
 receipt['old_token_bytes']=receipt['code_bytes']['k']+receipt['code_bytes']['v']+32*2*2*2
 receipt['resident_256_bytes']=69*4096+187*receipt['old_token_bytes']+len(blob)
 receipt['peak_256_bytes']=70*4096+186*receipt['old_token_bytes']+len(blob)
 (HERE/'global-descriptors.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({k:receipt[k] for k in ('code_bytes','old_token_bytes','resident_256_bytes','peak_256_bytes','descriptor_sha256')},indent=2))
 print('cross_head_cluster_counts', {k:sum(len(set((np.asarray(x['permutation'])[start:end]//128).tolist()))>1 for start,end in zip(x['bounds'][:-1],x['bounds'][1:])) for k,x in receipt['groups'].items()})
if __name__=='__main__':run()
