"""Independent chronological SKVQ packed reader against unchanged two-head Qwen teacher."""
import hashlib,json,math,sys
from pathlib import Path
import numpy as np
import torch
from source import HERE,arrays,original,FIX_SHA

def sha(data):return hashlib.sha256(data).hexdigest()

def bf16(blob):return torch.from_numpy((np.frombuffer(blob,dtype='<u2').astype(np.uint32)<<16).view(np.float32).copy())

def descriptor():
 receipt=json.loads((HERE/'source-descriptors.json').read_text());blob=(HERE/'source-descriptors.bin').read_bytes()
 assert len(blob)==532 and sha(blob)==receipt['descriptor_sha256']
 out={};i=0
 for kind in ('k','v'):
  p=np.frombuffer(blob,dtype='<i2',count=128,offset=i).astype(np.int64);i+=256
  bounds=np.frombuffer(blob,dtype='<i2',count=5,offset=i).astype(np.int64);i+=10
  assert sorted(p.tolist())==list(range(128)) and bounds[0]==0 and bounds[-1]==128
  assert np.all(np.diff(bounds)>0)
  assert p.tolist()==receipt['groups'][kind]['permutation'] and bounds.tolist()==receipt['groups'][kind]['bounds']
  out[kind]=(p,bounds,int(sum((int(w)+3)//4 for w in np.diff(bounds))))
 assert i==len(blob)
 return out,receipt

def decode(blob,kind,descriptor,source_bits):
 p,bounds,ncode=descriptor;assert len(blob)==ncode+16
 stored=np.frombuffer(blob,dtype='u1',count=ncode)
 fields=np.frombuffer(blob,dtype='<f2',count=8,offset=ncode).reshape(4,2)
 assert np.isfinite(fields).all() and (fields[:,1]>=np.float16(1e-5)).all()
 z=np.asarray(source_bits,dtype=np.uint16)
 half=(z.astype(np.uint32)<<16).view(np.float32).astype(np.float16)
 actual=np.empty(128,dtype=np.float32);at=0
 for g,(begin,end) in enumerate(zip(bounds[:-1],bounds[1:])):
  lo=np.float16(np.float16(half[p[begin:end]].min())*np.float16(.92))
  hi=np.float16(np.float16(half[p[begin:end]].max())*np.float16(.92))
  step=np.maximum(np.float16(np.float16(hi-lo)/np.float16(3)),np.float16(1e-5))
  assert np.array_equal(fields[g],np.asarray([lo,step],dtype='<f2'))
  length=int(end-begin);n=(length+3)//4
  c=np.empty(length,dtype=np.uint8)
  for a in range(length):c[a]=(stored[at+a//4]>>(2*(3-a%4)))&3
  # The official CUDA half kernel rounds the subtraction, division,
  # FP16 dequant multiplication and addition at their respective boundaries.
  with np.errstate(over='ignore'):
   expected=np.rint(np.clip(np.float16(np.float16(half[p[begin:end]]-lo)/step),0,3)).astype(np.uint8)
  assert np.array_equal(c,expected)
  unpacked=np.float16(np.float16(c.astype(np.float16)*fields[g,1])+fields[g,0])
  actual[p[begin:end]]=unpacked.astype(np.float32)
  at+=n
 assert at==ncode
 return torch.from_numpy(actual)

def state(kq,vq,ks,vs,kr,vr):return b''.join(kq)+b''.join(vq)+b''.join(ks)+b''.join(vs)+b''.join(kr)+b''.join(vr)

def check_state(raw,entry,tag,panel,window,t):
 assert len(raw)==entry['cache_bytes'] and sha(raw)==entry['sha256']
 if t in (5,6,69,70,255,256):assert raw==(HERE/f'{panel}-{window}-{tag}-{t}.bin').read_bytes()

def run(panel,window):
 torch.set_num_threads(1)
 src=arrays(panel,window);groups,meta=descriptor()
 manifest=json.loads((HERE/f'{panel}-{window}-manifest.json').read_text())
 assert manifest['fixture_sha256']==FIX_SHA and manifest['descriptor_sha256']==meta['descriptor_sha256']
 events=(HERE/f'{panel}-{window}-events.bin').read_bytes()
 assert sha(events)==manifest['event_log_sha256'] and len(events)==manifest['event_log_bytes']
 image=(HERE/f'{panel}-{window}-final.bin').read_bytes()
 assert sha(image)==manifest['final_image_sha256']
 kq=[];vq=[];kd=[];vd=[];ks=[];vs=[];kr=[];vr=[];offset=0;peak=0
 outs=[[],[]];logps=[[],[]];src_diffs=[[],[]]
 score_max=0.;out_max=0.;source_roundtrip=0.
 with torch.no_grad():
  for t in range(1,257):
   kb=src['prekey'][t-1].astype('<u2').tobytes();vb=src['value'][t-1].astype('<u2').tobytes()
   if t<=5:ks.append(kb);vs.append(vb)
   else:kr.append(kb);vr.append(vb)
   receipt=manifest['chronology'][t-1]
   before=state(kq,vq,ks,vs,kr,vr)
   assert receipt['position']==t-1
   check_state(before,receipt['before_aging'],'before',panel,window,t)
   peak=max(peak,len(before)+532)
   if len(kr)>64:
    assert len(kr)==len(vr)==65
    for kind,pieces,decoded,source_bits in [('k',kq,kd,src['prekey'][t-65]),('v',vq,vd,src['value'][t-65])]:

     ncode=groups[kind][2];length=ncode+16
     assert events[offset:offset+1]==kind.upper().encode() and int.from_bytes(events[offset+1:offset+3],'little')==t
     block=events[offset+3:offset+3+length];assert len(block)==length
     decoded.append(decode(block,kind,groups[kind],source_bits))
     pieces.append(block);offset+=3+length
    assert kr.pop(0)==src['prekey'][t-65].astype('<u2').tobytes()
    assert vr.pop(0)==src['value'][t-65].astype('<u2').tobytes()
   after=state(kq,vq,ks,vs,kr,vr)
   check_state(after,receipt['after_aging'],'after',panel,window,t)
   kk=torch.stack([bf16(w) for w in ks]+kd+[bf16(w) for w in kr])
   vv=torch.stack([bf16(w) for w in vs]+vd+[bf16(w) for w in vr])
   assert kk.shape==vv.shape==(t,128)
   # Pre-RoPE cache: every old decoded key is re-rotated at its original position.
   krot=original.consumer.rope(kk)
   recent_source=original.consumer.rope(src['prekey_float'][:t])
   source_roundtrip=max(source_roundtrip,float((recent_source-src['krot'][:t]).abs().max()))
   for h in range(2):
    q=src['qrot'][h][t-1]
    ref_l=q@src['krot'][:t].T/math.sqrt(128)
    ref_o=(ref_l.softmax(-1)@src['vraw'][:t])@src['o'][:,h*128:(h+1)*128].T
    score_max=max(score_max,float((ref_l-src['teacher'][h][2][t-1,:t]).abs().max()))
    out_max=max(out_max,float((ref_o-src['teacher'][h][1][t-1]).abs().max()))
    bare=q@recent_source.T/math.sqrt(128)
    bare_o=(bare.softmax(-1)@src['vraw'][:t])@src['o'][:,h*128:(h+1)*128].T
    src_diffs[h].append(bare_o)
    l=q@krot.T/math.sqrt(128)
    outs[h].append((l.softmax(-1)@vv)@src['o'][:,h*128:(h+1)*128].T)
    logps[h].append(l.log_softmax(-1))
 assert offset==len(events) and after==image and peak==manifest['max_pre_aging_cache_plus_descriptors']==54786
 assert len(after)+532==manifest['final_cache_bytes']+532==meta['post_256_bytes']==54373
 assert score_max<1e-4 and out_max<1e-4
 hs=[];ref=[];candidate=[];bare=[]
 for h in range(2):
  changed=torch.stack(outs[h]);target_logp,target,_=src['teacher'][h]
  kl=torch.stack([(target_logp[t,:t+1].exp()*(target_logp[t,:t+1]-logps[h][t])).sum() for t in range(256)]).mean()
  hs.append({'attention_kl':float(kl),'post_o_sse':float((target-changed).square().sum()),'post_o_ref_sq':float(target.square().sum())})
  candidate.append(changed);ref.append(target);bare.append(torch.stack(src_diffs[h]))
 pair_ref=sum(ref);pair_new=sum(candidate);pair_bare=sum(bare)
 result={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,'final_image_sha256':manifest['final_image_sha256'],
 'descriptor_sha256':meta['descriptor_sha256'],'event_log_sha256':manifest['event_log_sha256'],
 'max_pre_aging_cache_plus_descriptors':peak,'final_cache_plus_descriptors':len(after)+532,
 'uncompressed_original_teacher_score_max_abs':score_max,'uncompressed_original_teacher_o_max_abs':out_max,
 'pre_rope_recent_bf16_roundtrip_k_max_abs':source_roundtrip,
 'pre_rope_recent_bf16_roundtrip_pair_o_sse':float((pair_ref-pair_bare).square().sum()),
 'heads':{'head0':hs[0],'head1':hs[1]},
 'gqa_pair':{'post_o_sse':float((pair_ref-pair_new).square().sum()),'post_o_ref_sq':float(pair_ref.square().sum())}}
 (HERE/f'{panel}-{window}-result.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'pair_o_relsq':result['gqa_pair']['post_o_sse']/result['gqa_pair']['post_o_ref_sq'],
 'kl': [x['attention_kl'] for x in hs],'peak':peak,'roundtrip_K':source_roundtrip}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
