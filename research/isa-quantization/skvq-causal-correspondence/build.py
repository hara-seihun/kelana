"""Causal supported SKVQ 2/2 G32 W64 sink5 packed cache; no candidate selection."""
import hashlib,json,sys
import numpy as np
from source import HERE,arrays,FIX_SHA

def sha(data):return hashlib.sha256(data).hexdigest()

def desc():
 meta=json.loads((HERE/'source-descriptors.json').read_text())
 blob=(HERE/'source-descriptors.bin').read_bytes()
 assert len(blob)==532 and sha(blob)==meta['descriptor_sha256']
 return meta

def quantize(bits,group):
 value=np.asarray(bits,dtype=np.uint16)
 # BF16 input converted to FP16 as in upstream's half-input pack kernel.
 half=((value.astype(np.uint32)<<16).view(np.float32)).astype(np.float16)
 p=np.asarray(group['permutation']);b=np.asarray(group['bounds'])
 codes=[];fields=[]
 for begin,end in zip(b[:-1],b[1:]):
  z=half[p[begin:end]]
  lo=np.float16(np.float16(z.min())*np.float16(.92))
  hi=np.float16(np.float16(z.max())*np.float16(.92))
  step=np.maximum(np.float16(np.float16(hi-lo)/np.float16(3)),np.float16(1e-5)).astype(np.float16)
  with np.errstate(over='ignore'):
   scaled=np.float16(np.float16(z-lo)/step)
  c=np.rint(np.clip(scaled,0,3)).astype(np.uint8)
  for offset in range(0,len(c),4):
   part=c[offset:offset+4];packed=0
   for j,code in enumerate(part):packed|=int(code)<<(2*(3-j))
   codes.append(packed)
  fields.extend((lo,step))
 blob=bytes(codes)+np.asarray(fields,dtype='<f2').tobytes()
 assert len(blob)==sum((int(end)-int(begin)+3)//4 for begin,end in zip(b[:-1],b[1:]))+16
 return blob

def serialize(kq,vq,ks,vs,kr,vr):return b''.join(kq)+b''.join(vq)+b''.join(ks)+b''.join(vs)+b''.join(kr)+b''.join(vr)

def run(panel,window):
 src=arrays(panel,window);meta=desc()
 kn=meta['packed_code_bytes_per_token']['k']+16
 vn=meta['packed_code_bytes_per_token']['v']+16
 kq=[];vq=[];ks=[];vs=[];kr=[];vr=[];events=bytearray();receipts=[];peak=0
 for t in range(1,257):
  rowk=src['prekey'][t-1].astype('<u2').tobytes();rowv=src['value'][t-1].astype('<u2').tobytes()
  if t<=5:ks.append(rowk);vs.append(rowv)
  else:kr.append(rowk);vr.append(rowv)
  before=serialize(kq,vq,ks,vs,kr,vr)
  peak=max(peak,len(before)+532)
  record={'position':t-1,'before_aging':{'cache_bytes':len(before),'sha256':sha(before),'old_tokens':len(kq),'sink_tokens':len(ks),'recent_tokens':len(kr)}}
  if len(kr)>64:
   assert len(kr)==65 and len(vr)==65
   oldk=kr.pop(0);oldv=vr.pop(0)
   kb=quantize(np.frombuffer(oldk,dtype='<u2'),meta['groups']['k'])
   vb=quantize(np.frombuffer(oldv,dtype='<u2'),meta['groups']['v'])
   kq.append(kb);vq.append(vb)
   events+=b'K'+t.to_bytes(2,'little')+kb+b'V'+t.to_bytes(2,'little')+vb
  after=serialize(kq,vq,ks,vs,kr,vr)
  record['after_aging']={'cache_bytes':len(after),'sha256':sha(after),'old_tokens':len(kq),'sink_tokens':len(ks),'recent_tokens':len(kr)}
  receipts.append(record)
  if t in (5,6,69,70,255,256):
   (HERE/f'{panel}-{window}-before-{t}.bin').write_bytes(before)
   (HERE/f'{panel}-{window}-after-{t}.bin').write_bytes(after)
 assert len(kq)==len(vq)==187 and len(ks)==len(vs)==5 and len(kr)==len(vr)==64
 assert len(after)+532==meta['post_256_bytes']
 (HERE/f'{panel}-{window}-final.bin').write_bytes(after)
 (HERE/f'{panel}-{window}-events.bin').write_bytes(events)
 result={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,'descriptor_sha256':meta['descriptor_sha256'],
         'code_bytes_per_old_token':{'k':kn,'v':vn},'event_log_sha256':sha(events),'final_image_sha256':sha(after),
         'event_log_bytes':len(events),'final_cache_bytes':len(after),'source_descriptors_bytes':532,
         'max_pre_aging_cache_plus_descriptors':peak,'chronology':receipts}
 (HERE/f'{panel}-{window}-manifest.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'peak':peak,'final_plus_descriptors':len(after)+532,'final_hash':sha(after)}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
