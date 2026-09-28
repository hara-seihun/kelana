"""Independent K-code/V-donor reader and all16-head asym QJL complete observer."""
import hashlib,json,math,sys
import numpy as np
import torch
from source import HERE,ROOT,arrays,load,FIX_SHA
old=load('pinned_independent_turbo_reader',ROOT/'turboquant-causal/replay.py')
old.HERE=ROOT/'turboquant-causal'

def sha(x):return hashlib.sha256(x).hexdigest()

def run(panel,window):
 torch.set_num_threads(1)
 src=arrays(panel,window)
 meta,K,V,S,c=old.assets()
 gamma=json.loads((ROOT/'qwen-coupled-gamma/prepare.json').read_text())
 observer=json.loads((ROOT/f'qwen-coupled-gamma/{panel}-{window}-observe.json').read_text())
 assert observer['gamma_image_sha256']==gamma['gamma_image_sha256'] and all(observer['bitwise'].values())
 manifest=json.loads((HERE/f'{panel}-{window}-manifest.json').read_text())
 assert manifest['fixture_sha256']==FIX_SHA and manifest['source_gamma_replacement_sha256']==gamma['gamma_image_sha256']
 assert manifest['program_sha256']==meta['sha256']
 image=(HERE/f'{panel}-{window}-final.bin').read_bytes()
 donor=(ROOT/f'turboquant-causal/{panel}-{window}-final.bin').read_bytes()
 assert len(image)==len(donor)==188416 and sha(image)==manifest['final_sha256']
 assert sha(donor)==manifest['donor_image_sha256']
 for t,row in enumerate(manifest['prefixes']):
  assert row['position']==t and row['bytes']==(t+1)*736
  assert sha(image[:(t+1)*736])==row['sha256']
  assert sha(image[t*736:(t+1)*736])==row['new_row_sha256']
  if t+1 in (1,32,128,255,256):assert image[:(t+1)*736]==(HERE/f'{panel}-{window}-prefix-{t+1}.bin').read_bytes()
  for h in range(8):
   assert image[t*736+h*92+56:t*736+(h+1)*92]==donor[t*736+h*92+56:t*736+(h+1)*92]
 candidate_source=dict(src);candidate_source['key']=src['gauged_key']
 kr,rr,vr,mse,signs,vectors=old.parse(image,candidate_source,K,V,S,c)
 q=src['qrot_new'].numpy().astype(np.float32)
 qs=q@S.T
 key_mse=kr[...,None]*mse
 value=vr[...,None]*vectors
 outputs=[];kl=np.zeros(16,dtype=np.float64)
 with torch.no_grad():
  for t in range(256):
   mix=[]
   for h in range(16):
    kv=h//2
    score=(key_mse[:t+1,kv]@q[h,t]
          +(signs[:t+1,kv]@qs[h,t])*(kr[:t+1,kv]*rr[:t+1,kv])*np.float32(np.sqrt(np.pi/2)/128))/math.sqrt(128)
    logp=torch.from_numpy(score.copy()).log_softmax(-1)
    ref=src['teacher_logp'][h,t,:t+1]
    kl[h]+=float((ref.exp()*(ref-logp)).sum())
    mix.append(logp.exp()@torch.from_numpy(value[:t+1,kv].copy()))
   outputs.append(torch.stack(mix).reshape(2048)@src['o'].T)
  out=torch.stack(outputs);target=src['teacher']
  err=float((out-target).square().sum());den=float(target.square().sum())
  # Original teacher differs only in source BF16 insertion. The same gamma
  # map was already proven bitwise identical before quantization in observer.
  record={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,
          'gamma_image_sha256':gamma['gamma_image_sha256'],'program_sha256':meta['sha256'],
          'candidate_image_sha256':manifest['final_sha256'],'donor_image_sha256':manifest['donor_image_sha256'],
          'all_donor_V_bytes_identical':True,'peak_cache_plus_program_bytes':385040,
          'complete_o_sse':err,'complete_o_ref_sq':den,'mean_head_kl':float(kl.mean()/256),
          'zero_output_rel_sq':1.0,'head_kl':(kl/256).tolist()}
 (HERE/f'{panel}-{window}-result.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'full_o_relsq':err/den,'mean_kl':record['mean_head_kl'],'image':manifest['final_sha256']}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
