"""Independent paid SKVQ global code reader and complete 16-Q/8-KV O observer."""
import hashlib,json,math,sys
import numpy as np
import torch
from source import HERE,arrays,rope,FIX_SHA

def sha(data):return hashlib.sha256(data).hexdigest()
def bf16(blob):return torch.from_numpy((np.frombuffer(blob,dtype='<u2').astype(np.uint32)<<16).view(np.float32).copy())

def descriptor():
 r=json.loads((HERE/'global-descriptors.json').read_text());blob=(HERE/'global-descriptors.bin').read_bytes()
 assert len(blob)==4228 and sha(blob)==r['descriptor_sha256']
 at=0;out={}
 for kind in ('k','v'):
  p=np.frombuffer(blob,dtype='<i2',count=1024,offset=at).astype(np.int64);at+=2048
  b=np.frombuffer(blob,dtype='<i2',count=33,offset=at).astype(np.int64);at+=66
  assert sorted(p.tolist())==list(range(1024)) and b[0]==0 and b[-1]==1024 and np.all(np.diff(b)>0)
  assert p.tolist()==r['groups'][kind]['permutation'] and b.tolist()==r['groups'][kind]['bounds']
  ncode=int(sum((int(w)+3)//4 for w in np.diff(b)))
  assert ncode==r['code_bytes'][kind]
  out[kind]=(p,b,ncode)
 assert at==len(blob)
 return r,out

def decode(blob,descriptor,source_bits):
 p,b,ncode=descriptor;assert len(blob)==ncode+128
 codes=np.frombuffer(blob,dtype='u1',count=ncode)
 fields=np.frombuffer(blob,dtype='<f2',count=64,offset=ncode).reshape(32,2)
 assert np.isfinite(fields).all() and np.all(fields[:,1]>=np.float16(1e-5))
 half=(np.asarray(source_bits,dtype=np.uint16).astype(np.uint32)<<16).view(np.float32).astype(np.float16)
 actual=np.empty(1024,dtype=np.float32);at=0
 for g,(lo,hi) in enumerate(zip(b[:-1],b[1:])):
  vals=half[p[lo:hi]]
  origin=np.float16(vals.min()*np.float16(.92));maximum=np.float16(vals.max()*np.float16(.92))
  scale=np.maximum(np.float16(np.float16(maximum-origin)/np.float16(3)),np.float16(1e-5))
  assert np.array_equal(fields[g],np.asarray([origin,scale],dtype='<f2'))
  length=int(hi-lo);n=(length+3)//4
  stored=np.empty(length,dtype=np.uint8)
  for j in range(length):stored[j]=(codes[at+j//4]>>(2*(3-j%4)))&3
  with np.errstate(over='ignore'):
   expected=np.rint(np.clip(np.float16(np.float16(vals-origin)/scale),0,3)).astype(np.uint8)
  assert np.array_equal(stored,expected)
  actual[p[lo:hi]]=np.float16(np.float16(stored.astype(np.float16)*fields[g,1])+fields[g,0]).astype(np.float32)
  at+=n
 assert at==ncode
 return torch.from_numpy(actual)

def image(kq,vq,ks,vs,kr,vr):return b''.join(kq)+b''.join(vq)+b''.join(ks)+b''.join(vs)+b''.join(kr)+b''.join(vr)

def checked(raw,receipt,when,panel,window,t):
 assert len(raw)==receipt['bytes'] and sha(raw)==receipt['sha256']
 if t in (5,6,69,70,255,256):assert raw==(HERE/f'{panel}-{window}-{when}-{t}.bin').read_bytes()

def source_roundtrip(src):
 # Qwen BF16 post-Knorm pre-RoPE cache source compared with FP32 teacher
 pre=(src['prekey'].astype(np.uint32)<<16).view(np.float32).reshape(256,8,128)
 k=rope(torch.from_numpy(pre.copy())).permute(1,0,2)
 diff=float((src['krot']-k).abs().max())
 logits=torch.bmm(src['qrot'],k.repeat_interleave(2,dim=0).transpose(1,2))/math.sqrt(128)
 logits=logits.masked_fill(torch.ones(256,256,dtype=torch.bool).triu(1)[None],-1e9)
 mix=torch.bmm(logits.softmax(-1),src['vraw'].repeat_interleave(2,dim=0))
 out=mix.permute(1,0,2).reshape(256,2048)@src['o'].T
 return diff,float((out-src['teacher']).square().sum()),float((out-src['teacher']).abs().max())

def run(panel,window):
 torch.set_num_threads(1)
 src=arrays(panel,window);meta,group=descriptor()
 manifest=json.loads((HERE/f'{panel}-{window}-manifest.json').read_text())
 assert manifest['fixture_sha256']==FIX_SHA and manifest['descriptor_sha256']==meta['descriptor_sha256']
 events=(HERE/f'{panel}-{window}-events.bin').read_bytes()
 assert len(events)==manifest['event_log_bytes'] and sha(events)==manifest['event_log_sha256']
 final=(HERE/f'{panel}-{window}-final.bin').read_bytes()
 assert sha(final)==manifest['final_image_sha256']
 key_diff,source_sse,source_max=source_roundtrip(src)
 kq=[];vq=[];kd=[];vd=[];ks=[];vs=[];kr=[];vr=[];at=0;peak=0;outputs=[];kl=torch.zeros(16)
 with torch.no_grad():
  for t in range(1,257):
   k=src['prekey'][t-1].astype('<u2').tobytes();v=src['value'][t-1].astype('<u2').tobytes()
   if t<=5:ks.append(k);vs.append(v)
   else:kr.append(k);vr.append(v)
   receipt=manifest['prefixes'][t-1]
   assert receipt['position']==t-1
   pre=image(kq,vq,ks,vs,kr,vr)
   checked(pre,receipt['before_aging'],'before',panel,window,t)
   peak=max(peak,len(pre)+4228)
   if len(kr)>64:
    assert len(kr)==len(vr)==65
    for kind,pieces,decoded,srcbits in [('k',kq,kd,src['prekey'][t-65]),('v',vq,vd,src['value'][t-65])]:
     size=group[kind][2]+128
     assert events[at:at+1]==kind.upper().encode() and int.from_bytes(events[at+1:at+3],'little')==t
     block=events[at+3:at+3+size];assert len(block)==size
     decoded.append(decode(block,group[kind],srcbits));pieces.append(block)
     at+=3+size
    assert kr.pop(0)==src['prekey'][t-65].astype('<u2').tobytes()
    assert vr.pop(0)==src['value'][t-65].astype('<u2').tobytes()
   post=image(kq,vq,ks,vs,kr,vr)
   checked(post,receipt['after_aging'],'after',panel,window,t)
   kk=torch.stack([bf16(s) for s in ks]+kd+[bf16(s) for s in kr]).reshape(t,8,128)
   vv=torch.stack([bf16(s) for s in vs]+vd+[bf16(s) for s in vr]).reshape(t,8,128)
   assert kk.shape==vv.shape==(t,8,128)
   krot=rope(kk).permute(1,0,2).repeat_interleave(2,dim=0)
   logits=torch.bmm(src['qrot'][:,t-1].unsqueeze(1),krot.transpose(1,2)).squeeze(1)/math.sqrt(128)
   logp=logits.log_softmax(-1)
   ref=src['teacher_logp'][:,t-1,:t]
   kl+=(ref.exp()*(ref-logp)).sum(-1)
   val=vv.permute(1,0,2).repeat_interleave(2,dim=0)
   mix=torch.bmm(logp.exp().unsqueeze(1),val).reshape(2048)
   outputs.append(mix@src['o'].T)
 assert at==len(events) and post==final
 assert peak==meta['peak_256_bytes']==manifest['max_live_plus_descriptors']
 assert len(post)+4228==meta['resident_256_bytes']==manifest['final_live_plus_descriptors']
 out=torch.stack(outputs);err=float((out-src['teacher']).square().sum());den=float(src['teacher'].square().sum())
 record={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,'descriptor_sha256':meta['descriptor_sha256'],
         'final_image_sha256':manifest['final_image_sha256'],'event_log_sha256':manifest['event_log_sha256'],
         'peak_plus_descriptors_bytes':peak,'resident_plus_descriptors_bytes':len(post)+4228,
         'uncompressed_source_roundtrip_key_max_abs':key_diff,'uncompressed_source_roundtrip_o_sse':source_sse,
         'uncompressed_source_roundtrip_o_max_abs':source_max,'whole_layer_o_sse':err,'whole_layer_o_ref_sq':den,
         'head_kl':(kl/256).tolist()}
 (HERE/f'{panel}-{window}-result.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'o_rel_sq':err/den,'source_o_rel_sq':source_sse/den,
                   'mean_head_kl':float(kl.mean()/256),'peak':peak}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
