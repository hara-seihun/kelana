"""Independent paid byte reader; real asymmetric QJL query correction, complete16-head O."""
import hashlib,json,math,sys
import numpy as np
import torch
from source import HERE,arrays,FIX_SHA
D=128

def sha(x):return hashlib.sha256(x).hexdigest()

def assets():
 meta=json.loads((HERE/'program.json').read_text());blob=(HERE/'program.fp32').read_bytes()
 assert len(blob)==meta['total_program_bytes']==196624 and sha(blob)==meta['sha256']
 raw=np.frombuffer(blob,dtype='<f4')
 k=raw[:16384].reshape(128,128);v=raw[16384:32768].reshape(128,128)
 s=raw[32768:49152].reshape(128,128);c=raw[49152:]
 assert len(c)==4 and np.isfinite(raw).all() and np.all(np.diff(c)>0)
 return meta,k,v,s,c

def parse(raw,source,K,V,S,c):
 assert len(raw)==256*736
 kcode=np.empty((256,8,128),dtype=np.uint8)
 vcode=np.empty_like(kcode)
 signs=np.empty((256,8,128),dtype=np.float32)
 kr=np.empty((256,8),dtype='<f4');rr=np.empty_like(kr);vr=np.empty_like(kr)
 for t in range(256):
  row=raw[t*736:(t+1)*736];assert len(row)==736
  for h in range(8):
   payload=row[h*92:(h+1)*92];assert len(payload)==92
   kd=np.frombuffer(payload,dtype='u1',count=32)
   vd=np.frombuffer(payload,dtype='u1',count=32,offset=56)
   kcode[t,h]=np.stack([kd>>6,(kd>>4)&3,(kd>>2)&3,kd&3],axis=-1).reshape(128)
   vcode[t,h]=np.stack([vd>>6,(vd>>4)&3,(vd>>2)&3,vd&3],axis=-1).reshape(128)
   signs[t,h]=np.unpackbits(np.frombuffer(payload,dtype='u1',count=16,offset=32),bitorder='big').astype(np.float32)*2-1
   kr[t,h],rr[t,h]=np.frombuffer(payload,dtype='<f4',count=2,offset=48)
   vr[t,h]=np.frombuffer(payload,dtype='<f4',count=1,offset=88)[0]
 assert np.isfinite(kr).all() and np.isfinite(rr).all() and np.isfinite(vr).all()
 assert (kr>0).all() and (rr>=0).all() and (vr>0).all()
 # Recalculate insertion decisions independently from the source and finite prepared matrices.
 x=(source['key'].astype(np.uint32)<<16).view(np.float32).reshape(256,8,128)
 y=(source['value'].astype(np.uint32)<<16).view(np.float32).reshape(256,8,128)
 assert np.array_equal(np.linalg.norm(x,axis=-1).astype('<f4'),kr)
 assert np.array_equal(np.linalg.norm(y,axis=-1).astype('<f4'),vr)
 ux=x/kr[...,None];uy=y/vr[...,None]
 wantk=np.abs((ux@K.T)[...,None]-c).argmin(-1)
 wantv=np.abs((uy@V.T)[...,None]-c).argmin(-1)
 assert np.array_equal(wantk,kcode) and np.array_equal(wantv,vcode)
 mse=c[kcode]@K
 residual=ux-mse
 assert np.array_equal(np.linalg.norm(residual,axis=-1).astype('<f4'),rr)
 assert np.array_equal(np.where((residual@S.T)>=0,1.,-1.),signs)
 return kr,rr,vr,mse,signs,c[vcode]@V

def run(panel,window):
 torch.set_num_threads(1)
 source=arrays(panel,window);meta,K,V,S,c=assets()
 manifest=json.loads((HERE/f'{panel}-{window}-manifest.json').read_text())
 assert manifest['program_sha256']==meta['sha256'] and manifest['fixture_sha256']==FIX_SHA
 data=(HERE/f'{panel}-{window}-final.bin').read_bytes()
 assert len(data)==manifest['max_cache_bytes']==188416 and sha(data)==manifest['final_sha256']
 for t,record in enumerate(manifest['prefixes']):
  assert record['position']==t and record['bytes']==(t+1)*736
  assert sha(data[:(t+1)*736])==record['sha256']
  assert sha(data[t*736:(t+1)*736])==record['new_row_sha256']
  if t+1 in (1,32,128,255,256):assert data[:(t+1)*736]==(HERE/f'{panel}-{window}-prefix-{t+1}.bin').read_bytes()
 kr,rr,vr,mse,signs,vectors=parse(data,source,K,V,S,c)
 # Query transformations once per Q head and position, shared across all prior keys.
 q=source['qrot'].numpy().astype(np.float32)
 qs=q@S.T
 key_mse=kr[...,None]*mse
 value=vr[...,None]*vectors
 outputs=[];kl=np.zeros(16,dtype=np.float64)
 with torch.no_grad():
  for t in range(256):
   mix=[]
   for h in range(16):
    kv=h//2
    approximate=(key_mse[:t+1,kv]@q[h,t]
      +(signs[:t+1,kv]@qs[h,t])*(kr[:t+1,kv]*rr[:t+1,kv])*np.float32(np.sqrt(np.pi/2)/128)) / math.sqrt(128)
    logp=torch.from_numpy(approximate.copy()).log_softmax(-1)
    ref=source['teacher_logp'][h,t,:t+1]
    kl[h]+=float((ref.exp()*(ref-logp)).sum())
    mix.append(logp.exp()@torch.from_numpy(value[:t+1,kv].copy()))
   out=torch.stack(mix).reshape(2048)@source['o'].T
   outputs.append(out)
  outputs=torch.stack(outputs)
  target=source['teacher']
  diff=outputs-target
  # Original post-RoPE K was FP32; BF16 cache input rounding independent of quantization.
  original_key=source['krot'].numpy()
  rounded=(source['key'].astype(np.uint32)<<16).view(np.float32).reshape(256,8,128).transpose(1,0,2)
  logits=np.einsum('htd,hsd->hts',q,rounded.repeat(2,axis=0))/math.sqrt(128)
  masked=torch.from_numpy(logits.copy()).masked_fill(torch.ones(256,256,dtype=torch.bool).triu(1)[None],-1e9)
  p=masked.softmax(-1)
  pure=torch.bmm(p,source['vraw'].repeat_interleave(2,dim=0)).permute(1,0,2).reshape(256,2048)@source['o'].T
  rounding=float((pure-target).square().sum())
  assert float((source['teacher_logits'].tril()-torch.from_numpy(np.einsum('htd,hsd->hts',q,original_key.repeat(2,axis=0))/math.sqrt(128)).tril()).abs().max())<1e-4
  result={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,'program_sha256':meta['sha256'],
          'final_image_sha256':manifest['final_sha256'],'peak_cache_plus_program_bytes':len(data)+196624,
          'complete_o_sse':float(diff.square().sum()),'complete_o_ref_sq':float(target.square().sum()),
          'post_rope_bf16_source_rounding_o_sse':rounding,
          'post_rope_bf16_source_key_max_abs':float(np.max(abs(rounded-original_key))),
          'head_kl':(kl/256).tolist()}
 (HERE/f'{panel}-{window}-result.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'full_o_rel_sq':result['complete_o_sse']/result['complete_o_ref_sq'],
                   'rounding_o_rel_sq':rounding/result['complete_o_ref_sq'],'mean_kl':float(kl.mean()/256)}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
