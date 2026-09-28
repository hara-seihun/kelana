"""Independent full16-Q/8-KV original KIVI replay, first KV group reused."""
import hashlib,importlib.util,json,math,sys
import numpy as np
import torch
from source import HERE,ROOT,arrays,original
BASE=ROOT/'kivi-causal-cache'
spec=importlib.util.spec_from_file_location('pinned_kivi_reader',BASE/'replay.py')
reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)

def sha(b):return hashlib.sha256(b).hexdigest()

def state(kq,vq,kr,vr):return b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)

def run(panel,window):
 torch.set_num_threads(1)
 src=arrays(panel,window)
 bits=src['krot'].permute(1,0,2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
 values=src['value'].reshape(256,8,128)
 donor=original.arrays(panel,window)
 assert np.array_equal(bits[:,0],donor['key']) and np.array_equal(values[:,0],donor['value'])
 extra=json.loads((HERE/f'{panel}-{window}-kivi-manifest.json').read_text())
 pinned=json.loads((BASE/f'{panel}-{window}-manifest.json').read_text())
 logs=[];offset=[0]*8;receipt=[];expected=[]
 for h in range(8):
  if h==0:
   blob=(BASE/f'{panel}-{window}-flush.bin').read_bytes()
   assert sha(blob)==pinned['flush_log_sha256']
   receipts=pinned['prefixes'];final=(BASE/f'{panel}-{window}-final.bin').read_bytes()
   assert sha(final)==pinned['final_sha256']
  else:
   name=f'{panel}-{window}-kivi-head{h}'
   info=extra['groups'][f'kv{h}']
   blob=(HERE/f'{name}-events.bin').read_bytes()
   assert sha(blob)==info['event_log_sha256']
   receipts=info['prefixes'];final=(HERE/f'{name}-final.bin').read_bytes()
   assert sha(final)==info['final_image_sha256']
  logs.append(blob);receipt.append(receipts);expected.append(final)
 kq=[[] for _ in range(8)];vq=[[] for _ in range(8)];kr=[[] for _ in range(8)];vr=[[] for _ in range(8)]
 outputs=[];kl=torch.zeros(16);peak=0
 with torch.no_grad():
  for t in range(1,257):
   decoded_k=[];decoded_v=[]
   for h in range(8):
    kr[h].append(bits[t-1,h].astype('<u2').tobytes())
    vr[h].append(values[t-1,h].astype('<u2').tobytes())
    before=state(kq[h],vq[h],kr[h],vr[h]);entry=receipt[h][t-1]
    check=entry['before_flush'] if h==0 else entry['before']
    assert check['sha256']==sha(before) and (check['live_state_bytes'] if h==0 else check['bytes'])==len(before)
    peak=max(peak,len(before)*8)
    nkey=len(kq[h])*32;nvalue=len(vq[h])
    k,v=reader.decode(before,nkey,nvalue,len(kr[h]),len(vr[h]))
    decoded_k.append(torch.from_numpy(k.copy()))
    decoded_v.append(torch.from_numpy(v.copy()))
   key=torch.stack(decoded_k).repeat_interleave(2,dim=0)
   val=torch.stack(decoded_v).repeat_interleave(2,dim=0)
   q=src['qrot'][:,t-1]
   l=torch.bmm(q[:,None,:],key.transpose(1,2)).squeeze(1)/math.sqrt(128)
   p=l.softmax(-1);logp=l.log_softmax(-1)
   ref=src['teacher_logp'][:,t-1,:t]
   kl+=(ref.exp()*(ref-logp)).sum(-1)
   mix=torch.bmm(p[:,None,:],val).reshape(2048)
   outputs.append(mix@src['o'].T)
   for h in range(8):
    entry=receipt[h][t-1]
    def event(tag,n):
     start=offset[h];buf=logs[h];assert buf[start:start+1]==tag and int.from_bytes(buf[start+1:start+3],'little')==t
     chunk=buf[start+3:start+3+n];assert len(chunk)==n
     offset[h]+=3+n
     return chunk
    if len(kr[h])==32:
     block=event(b'K',2560)
     reader.check_event(block,'K',bits[t-32:t,h])
     kq[h].append(block);kr[h]=[]
    if len(vr[h])>32:
     block=event(b'V',80)
     reader.check_event(block,'V',values[t-33,h])
     vq[h].append(block);vr[h].pop(0)
    after=state(kq[h],vq[h],kr[h],vr[h])
    check=entry['after_flush'] if h==0 else entry['after']
    assert check['sha256']==sha(after) and (check['live_state_bytes'] if h==0 else check['bytes'])==len(after)
 assert peak==419200
 assert all(offset[h]==len(logs[h]) and state(kq[h],vq[h],kr[h],vr[h])==expected[h] for h in range(8))
 out=torch.stack(outputs);err=float((out-src['teacher']).square().sum());den=float(src['teacher'].square().sum())
 result={'panel':panel,'window':window,'source_fixture_sha256':original.FIX_SHA,
         'peak_cache_bytes':peak,'final_cache_bytes':sum(len(w) for w in expected),
         'donor_group0_sha256':sha(expected[0]),
         'other_group_sha256':[sha(expected[h]) for h in range(1,8)],
         'full_o_sse':err,'full_o_ref_sq':den,'head_kl':(kl/256).tolist()}
 assert result['final_cache_bytes']==372736
 (HERE/f'{panel}-{window}-kivi-result.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'full_o_relsq':err/den,'mean_head_kl':float(kl.mean()/256),'peak':peak}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
