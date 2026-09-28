"""Independent chronological KIVI2 byte reader for folded V/O image."""
import hashlib,json,math,sys
from pathlib import Path
import numpy as np
import torch
from source import arrays
HERE=Path(__file__).resolve().parent
DONOR=HERE.parent/'kivi-two-bit-causal'

def sha(x):return hashlib.sha256(x).hexdigest()
def bf16(bits):return (np.asarray(bits,dtype=np.uint32)<<16).view(np.float32)
def digits(blob,count):
 d=np.frombuffer(blob,dtype=np.uint8)
 assert len(d)*4==count
 return np.stack((d&3,d>>2&3,d>>4&3,d>>6),axis=1).reshape(count).astype(np.float32)
def decode(state,nk,nv,kr,vr):
 offset=0;keys=[];values=[]
 for _ in range(nk):
  code=digits(state[offset:offset+1024],4096).reshape(32,128);offset+=1024
  fields=np.frombuffer(state,dtype='<f2',count=256,offset=offset).astype(np.float32).reshape(128,2);offset+=512
  assert np.isfinite(fields).all() and np.all(fields[:,1]>=0)
  keys.append(code*fields[None,:,1]+fields[None,:,0])
 for _ in range(nv):
  code=digits(state[offset:offset+32],128).reshape(4,32);offset+=32
  fields=np.frombuffer(state,dtype='<f2',count=8,offset=offset).astype(np.float32).reshape(4,2);offset+=16
  assert np.isfinite(fields).all() and np.all(fields[:,1]>=0)
  values.append((code*fields[:,1,None]+fields[:,0,None]).reshape(1,128))
 recent_k=np.frombuffer(state,dtype='<u2',count=kr*128,offset=offset).reshape(kr,128);offset+=kr*256
 recent_v=np.frombuffer(state,dtype='<u2',count=vr*128,offset=offset).reshape(vr,128);offset+=vr*256
 assert offset==len(state)
 k=np.concatenate(keys+[bf16(recent_k)],axis=0) if nk else bf16(recent_k)
 v=np.concatenate(values+[bf16(recent_v)],axis=0) if nv else bf16(recent_v)
 return k,v

def check_event(blob,source,kind):
 x=bf16(source)
 if kind=='K':
  assert x.shape==(32,128) and len(blob)==1536
  lo=x.min(0);hi=x.max(0)
  actual=digits(blob[:1024],4096).reshape(32,128)
  paid=np.frombuffer(blob,dtype='<f2',count=256,offset=1024).reshape(128,2)
  step=(hi-lo)/3
  expected=np.where(step[None]>0,np.clip(np.rint((x-lo[None])/np.where(step[None]>0,step[None],1)),0,3),0)
 else:
  assert x.shape==(128,) and len(blob)==48
  x=x.reshape(4,32);lo=x.min(1);hi=x.max(1)
  actual=digits(blob[:32],128).reshape(4,32)
  paid=np.frombuffer(blob,dtype='<f2',count=8,offset=32).reshape(4,2)
  step=(hi-lo)/3
  expected=np.where(step[:,None]>0,np.clip(np.rint((x-lo[:,None])/np.where(step[:,None]>0,step[:,None],1)),0,3),0)
 assert np.array_equal(paid[:,0],lo.astype('<f2')) and np.array_equal(paid[:,1],step.astype('<f2'))
 assert np.array_equal(actual,expected)

def state(kq,vq,kr,vr):return b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)

def run(panel,window):
 torch.set_num_threads(1)
 m=json.loads((HERE/f'{panel}-{window}-manifest.json').read_text())
 donor=json.loads((DONOR/f'{panel}-{window}-manifest.json').read_text())
 assert m['fixture_sha256']==donor['fixture_sha256']
 src=arrays(panel,window)
 old=src['original'];keys=old['krot'].permute(1,0,2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
 values=src['value']
 assert torch.equal(src['output'],old['teacher'])
 assert keys.shape==values.shape==(256,8,128)
 logs=[];original_logs=[];finals=[];prefixes=[]
 for h in range(8):
  name=f'{panel}-{window}-head{h}'
  log=(HERE/f'{name}-events.bin').read_bytes()
  original_log=(DONOR/f'{name}-events.bin').read_bytes()
  final=(HERE/f'{name}-final.bin').read_bytes()
  entry=m['groups'][f'kv{h}'];prior=donor['groups'][f'kv{h}']
  assert len(log)==entry['events_bytes'] and sha(log)==entry['events_sha256']
  assert len(final)==entry['final_bytes'] and sha(final)==entry['final_sha256']
  assert sha(original_log)==prior['events_sha256']
  assert final[:8*1536]==(DONOR/f'{name}-final.bin').read_bytes()[:8*1536]
  logs.append(log);original_logs.append(original_log);finals.append(final);prefixes.append(entry['prefixes'])
 kq=[[] for _ in range(8)];vq=[[] for _ in range(8)];kr=[[] for _ in range(8)];vr=[[] for _ in range(8)]
 offsets=[0]*8;old_offsets=[0]*8;outputs=[];kl=torch.zeros(16);peak=0
 with torch.no_grad():
  for t in range(1,257):
   decoded_k=[];decoded_v=[]
   for h in range(8):
    kr[h].append(keys[t-1,h].astype('<u2').tobytes())
    vr[h].append(values[t-1,h].astype('<u2').tobytes())
    before=state(kq[h],vq[h],kr[h],vr[h]);receipt=prefixes[h][t-1]['before_query_flush']
    assert len(before)==receipt['bytes'] and sha(before)==receipt['sha256']
    peak=max(peak,len(before)*8)
    k,v=decode(before,len(kq[h]),len(vq[h]),len(kr[h]),len(vr[h]))
    decoded_k.append(torch.from_numpy(k.copy()));decoded_v.append(torch.from_numpy(v.copy()))
   key=torch.stack(decoded_k).repeat_interleave(2,dim=0)
   value=torch.stack(decoded_v).repeat_interleave(2,dim=0)
   q=old['qrot'][:,t-1]
   logits=torch.bmm(q[:,None,:],key.transpose(1,2)).squeeze(1)/math.sqrt(128)
   probs=logits.softmax(-1)
   ref=old['teacher_logp'][:,t-1,:t]
   kl+=(ref.exp()*(ref-logits.log_softmax(-1))).sum(-1)
   outputs.append(torch.bmm(probs[:,None,:],value).reshape(2048)@src['o'].T)
   for h in range(8):
    def event(tag,length):
     idx=offsets[h];blob=logs[h]
     assert blob[idx:idx+1]==tag and int.from_bytes(blob[idx+1:idx+3],'little')==t
     payload=blob[idx+3:idx+3+length];assert len(payload)==length
     offsets[h]+=3+length
     return payload
    if len(kr[h])==32:
     block=event(b'K',1536)
     old_pos=old_offsets[h]
     assert original_logs[h][old_pos:old_pos+1539]==b'K'+t.to_bytes(2,'little')+block
     old_offsets[h]+=1539
     check_event(block,keys[t-32:t,h],'K')
     kq[h].append(block);kr[h].clear()
    if len(vr[h])>32:
     block=event(b'V',48)
     assert original_logs[h][old_offsets[h]:old_offsets[h]+3]==b'V'+t.to_bytes(2,'little')
     old_offsets[h]+=51
     check_event(block,values[t-33,h],'V')
     vq[h].append(block);vr[h].pop(0)
    after=state(kq[h],vq[h],kr[h],vr[h]);receipt=prefixes[h][t-1]['after_query_flush']
    assert len(after)==receipt['bytes'] and sha(after)==receipt['sha256']
 assert peak==m['peak_full_layer_bytes']==304768
 assert all(offsets[h]==len(logs[h]) and old_offsets[h]==len(original_logs[h]) and
            state(kq[h],vq[h],kr[h],vr[h])==finals[h] for h in range(8))
 output=torch.stack(outputs);error=float((output-old['teacher']).square().sum());den=float(old['teacher'].square().sum())
 previous=json.loads((DONOR/f'{panel}-{window}-result.json').read_text())
 assert abs(den-previous['full_o_ref_sq'])<1e-6
 result={'panel':panel,'window':window,'image_sha256':[sha(x) for x in finals],
         'events_sha256':[sha(x) for x in logs],
         'replacement_v_o_sha256':m['replacement_v_o_sha256'],
         'peak_cache_bytes':peak,'final_cache_bytes':sum(len(x) for x in finals),
         'full_o_sse':error,'full_o_ref_sq':den,'head_kl':(kl/256).tolist(),
         'donor_full_o_sse':previous['full_o_sse'],'donor_head_kl':previous['head_kl']}
 (HERE/f'{panel}-{window}-result.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'full_o_rel_sq':error/den,'donor_full_o_rel_sq':previous['full_o_sse']/den,
                   'head_kl_mean':float(kl.mean()/256),'peak':peak}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
