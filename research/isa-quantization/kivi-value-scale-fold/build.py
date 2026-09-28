"""Emit one causal KIVI2 V2 fold; copy original K flush bytes verbatim."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
import torch
from source import arrays
HERE=Path(__file__).resolve().parent
DONOR=HERE.parent/'kivi-two-bit-causal'

def sha(data):return hashlib.sha256(data).hexdigest()

def bf16(bits):return (np.asarray(bits,dtype=np.uint32)<<16).view(np.float32)

def pack(digits):
 d=np.asarray(digits,dtype=np.uint8).ravel()
 assert len(d)%4==0 and np.all(d<4)
 return (d[::4]|d[1::4]<<2|d[2::4]<<4|d[3::4]<<6).tobytes()

def value_token(bits):
 values=bf16(bits).reshape(4,32)
 fields=[];codes=[]
 for group in values:
  lo=float(group.min());step=(float(group.max())-lo)/3
  digits=np.zeros(32,dtype=np.uint8) if step==0 else np.clip(np.rint((group-lo)/step),0,3).astype(np.uint8)
  codes.extend(digits);fields.extend((lo,step))
 tail=np.asarray(fields,dtype='<f2').tobytes()
 blob=pack(codes)+tail
 assert len(blob)==48 and np.isfinite(np.frombuffer(tail,dtype='<f2')).all()
 return blob

def state(kq,vq,kr,vr):return b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)

def receipt(kq,vq,kr,vr):
 blob=state(kq,vq,kr,vr)
 return {'bytes':len(blob),'sha256':sha(blob),'key_quant_chunks':len(kq),'value_quant_tokens':len(vq),
         'key_recent_tokens':len(kr),'value_recent_tokens':len(vr),
         'key_quant_bytes':len(kq)*1536,'value_quant_bytes':len(vq)*48,
         'key_recent_bytes':len(kr)*256,'value_recent_bytes':len(vr)*256}

def run(panel,window):
 torch.set_num_threads(1)
 src=arrays(panel,window)
 original=src['original']
 keys=original['krot'].permute(1,0,2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
 values=src['value']
 assert keys.shape==values.shape==(256,8,128)
 donor=json.loads((DONOR/f'{panel}-{window}-manifest.json').read_text())
 groups={}
 for h in range(8):
  name=f'{panel}-{window}-head{h}'
  old_log=(DONOR/f'{name}-events.bin').read_bytes()
  old_image=(DONOR/f'{name}-final.bin').read_bytes()
  assert sha(old_log)==donor['groups'][f'kv{h}']['events_sha256']
  assert sha(old_image)==donor['groups'][f'kv{h}']['final_sha256']
  kq=[];vq=[];kr=[];vr=[];log=bytearray();prefixes=[];peak=0;pos=0
  for t in range(1,257):
   kr.append(keys[t-1,h].astype('<u2').tobytes())
   vr.append(values[t-1,h].astype('<u2').tobytes())
   before=receipt(kq,vq,kr,vr)
   peak=max(peak,before['bytes'])
   if len(kr)==32:
    assert old_log[pos:pos+1]==b'K' and int.from_bytes(old_log[pos+1:pos+3],'little')==t
    block=old_log[pos+3:pos+3+1536]
    assert len(block)==1536
    event=old_log[pos:pos+1539]
    log+=event;pos+=1539;kq.append(block);kr.clear()
   if len(vr)>32:
    assert old_log[pos:pos+1]==b'V' and int.from_bytes(old_log[pos+1:pos+3],'little')==t
    pos+=51
    token=value_token(np.frombuffer(vr.pop(0),dtype='<u2'))
    log+=b'V'+t.to_bytes(2,'little')+token
    vq.append(token)
   prefixes.append({'position':t-1,'before_query_flush':before,'after_query_flush':receipt(kq,vq,kr,vr)})
  final=state(kq,vq,kr,vr)
  assert pos==len(old_log) and peak==38096 and len(final)==31232
  assert b''.join(kq)==old_image[:8*1536]
  (HERE/f'{name}-events.bin').write_bytes(log)
  (HERE/f'{name}-final.bin').write_bytes(final)
  groups[f'kv{h}']={'peak_bytes':peak,'final_bytes':len(final),'events_bytes':len(log),
                      'events_sha256':sha(log),'final_sha256':sha(final),
                      'original_key_quant_sha256':sha(b''.join(kq)),
                      'original_key_recent_sha256':sha(b''.join(kr)),
                      'prefixes':prefixes}
 manifest={'panel':panel,'window':window,'fixture_sha256':donor['fixture_sha256'],
           'replacement_v_o_sha256':json.loads((HERE/'source-fields.json').read_text())['replacement_image_sha256'],
           'donor':str(DONOR.relative_to(HERE.parent)),
           'peak_full_layer_bytes':304768,'final_full_layer_bytes':249856,'groups':groups,
           'events_are_audit_evidence_not_simultaneous_cache':True}
 (HERE/f'{panel}-{window}-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'peak':304768,'final':249856,
                   'folded_source_bitwise_teacher':bool(torch.equal(src['output'],original['teacher']))}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
