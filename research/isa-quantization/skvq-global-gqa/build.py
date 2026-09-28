"""One pinned global-SKVQ K/V cache; chronological packed images all heads jointly."""
import hashlib,json,sys
import numpy as np
from source import HERE,arrays,FIX_SHA

def sha(data):return hashlib.sha256(data).hexdigest()

def descriptor():
 meta=json.loads((HERE/'global-descriptors.json').read_text())
 blob=(HERE/'global-descriptors.bin').read_bytes()
 assert len(blob)==4228 and sha(blob)==meta['descriptor_sha256']
 return meta

def quantize(bits,group):
 half=(np.asarray(bits,dtype=np.uint16).astype(np.uint32)<<16).view(np.float32).astype(np.float16)
 p=np.asarray(group['permutation']);b=np.asarray(group['bounds']);codes=[];fields=[]
 for begin,end in zip(b[:-1],b[1:]):
  z=half[p[begin:end]]
  lo=np.float16(z.min()*np.float16(.92))
  hi=np.float16(z.max()*np.float16(.92))
  scale=np.maximum(np.float16(np.float16(hi-lo)/np.float16(3)),np.float16(1e-5))
  with np.errstate(over='ignore'): c=np.rint(np.clip(np.float16(np.float16(z-lo)/scale),0,3)).astype(np.uint8)
  for off in range(0,len(c),4):
   byte=0
   for j,num in enumerate(c[off:off+4]):byte|=int(num)<<(2*(3-j))
   codes.append(byte)
  fields.extend((lo,scale))
 result=bytes(codes)+np.asarray(fields,dtype='<f2').tobytes()
 assert len(result)==sum((int(end)-int(begin)+3)//4 for begin,end in zip(b[:-1],b[1:]))+128
 return result

def image(kq,vq,ks,vs,kr,vr):return b''.join(kq)+b''.join(vq)+b''.join(ks)+b''.join(vs)+b''.join(kr)+b''.join(vr)

def run(panel,window):
 src=arrays(panel,window);meta=descriptor()
 sz={kind:meta['code_bytes'][kind]+128 for kind in ('k','v')}
 kq=[];vq=[];ks=[];vs=[];kr=[];vr=[];events=bytearray();receipts=[];peak=0
 for t in range(1,257):
  k=src['prekey'][t-1].astype('<u2').tobytes()
  v=src['value'][t-1].astype('<u2').tobytes()
  assert len(k)==len(v)==2048
  if t<=5:ks.append(k);vs.append(v)
  else:kr.append(k);vr.append(v)
  pre=image(kq,vq,ks,vs,kr,vr)
  peak=max(peak,len(pre)+4228)
  rec={'position':t-1,'before_aging':{'bytes':len(pre),'sha256':sha(pre),'old_tokens':len(kq),'sink_tokens':len(ks),'recent_tokens':len(kr)}}
  if len(kr)>64:
   assert len(kr)==len(vr)==65
   a=quantize(np.frombuffer(kr.pop(0),dtype='<u2'),meta['groups']['k'])
   b=quantize(np.frombuffer(vr.pop(0),dtype='<u2'),meta['groups']['v'])
   assert len(a)==sz['k'] and len(b)==sz['v']
   kq.append(a);vq.append(b)
   events+=b'K'+t.to_bytes(2,'little')+a+b'V'+t.to_bytes(2,'little')+b
  post=image(kq,vq,ks,vs,kr,vr)
  rec['after_aging']={'bytes':len(post),'sha256':sha(post),'old_tokens':len(kq),'sink_tokens':len(ks),'recent_tokens':len(kr)}
  receipts.append(rec)
  if t in (5,6,69,70,255,256):
   (HERE/f'{panel}-{window}-before-{t}.bin').write_bytes(pre)
   (HERE/f'{panel}-{window}-after-{t}.bin').write_bytes(post)
 assert len(kq)==len(vq)==187 and len(ks)==len(vs)==5 and len(kr)==len(vr)==64
 assert len(post)+4228==meta['resident_256_bytes'] and peak==meta['peak_256_bytes']
 (HERE/f'{panel}-{window}-final.bin').write_bytes(post)
 (HERE/f'{panel}-{window}-events.bin').write_bytes(events)
 manifest={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,'descriptor_sha256':meta['descriptor_sha256'],
           'K_old_token_bytes':sz['k'],'V_old_token_bytes':sz['v'],'max_live_plus_descriptors':peak,
           'final_live_plus_descriptors':len(post)+4228,'final_image_sha256':sha(post),
           'event_log_sha256':sha(events),'event_log_bytes':len(events),'prefixes':receipts}
 (HERE/f'{panel}-{window}-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'peak':peak,'final':len(post)+4228,'image':sha(post)}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
