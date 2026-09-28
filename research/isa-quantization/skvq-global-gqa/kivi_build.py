"""Fill seven missing original KIVI KV groups; head0 is immutable canonical donor."""
import hashlib,importlib.util,json,sys
from pathlib import Path
import numpy as np
import torch
from source import HERE,ROOT,arrays
BASE=ROOT/'kivi-causal-cache'
spec=importlib.util.spec_from_file_location('pinned_kivi_builder',BASE/'build.py')
# The pinned module imports source from this study; only its pure group primitives used.
upstream=importlib.util.module_from_spec(spec);spec.loader.exec_module(upstream)

def sha(data):return hashlib.sha256(data).hexdigest()

def run(panel,window):
 src=arrays(panel,window)
 key=src['krot'].permute(1,0,2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
 value=src['value'].reshape(256,8,128)
 assert key.shape==(256,8,128)
 meta={'panel':panel,'window':window,'groups':{},'first_group_donor':str(BASE/f'{panel}-{window}-flush.bin')}
 for h in range(1,8):
  kq=[];vq=[];kr=[];vr=[];events=bytearray();prefixes=[];peak=0
  for t in range(1,257):
   kr.append(key[t-1,h].astype('<u2').tobytes())
   vr.append(value[t-1,h].astype('<u2').tobytes())
   before=upstream.serialize(kq,vq,kr,vr)
   peak=max(peak,len(before))
   receipt={'position':t-1,'before':{'bytes':len(before),'sha256':sha(before)}}
   if len(kr)==32:
    block=upstream.key_chunk(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128))
    kq.append(block);kr=[]
    events+=b'K'+t.to_bytes(2,'little')+block
   if len(vr)>32:
    block=upstream.value_token(np.frombuffer(vr.pop(0),dtype='<u2'))
    vq.append(block);events+=b'V'+t.to_bytes(2,'little')+block
   after=upstream.serialize(kq,vq,kr,vr)
   receipt['after']={'bytes':len(after),'sha256':sha(after)}
   prefixes.append(receipt)
  assert peak==52400 and len(after)==46592
  name=f'{panel}-{window}-kivi-head{h}'
  (HERE/f'{name}-events.bin').write_bytes(events)
  (HERE/f'{name}-final.bin').write_bytes(after)
  meta['groups'][f'kv{h}']={'peak_bytes':peak,'final_bytes':len(after),'event_log_sha256':sha(events),
                           'final_image_sha256':sha(after),'prefixes':prefixes}
 (HERE/f'{panel}-{window}-kivi-manifest.json').write_text(json.dumps(meta,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'original_group0_donor':str(BASE/f'{panel}-{window}-final.bin'),
                   'additional_packed_groups':7,'peak_full_layer':419200,'final_full_layer':372736}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
