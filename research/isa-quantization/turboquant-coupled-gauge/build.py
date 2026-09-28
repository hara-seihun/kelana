"""Only K re-encoded after paid Q/K gamma fold; reuse all V/program bytes."""
import hashlib,importlib.util,json,sys
import numpy as np
from source import HERE,ROOT,arrays,load,FIX_SHA
old=load('pinned_turbo_encoder',ROOT/'turboquant-causal/build.py')
old.HERE=ROOT/'turboquant-causal'

def sha(data):return hashlib.sha256(data).hexdigest()

def run(panel,window):
 src=arrays(panel,window)
 program,K,V,S,c=old.program()
 gamma=json.loads((ROOT/'qwen-coupled-gamma/prepare.json').read_text())
 donor_meta=json.loads((ROOT/f'turboquant-causal/{panel}-{window}-manifest.json').read_text())
 donor=(ROOT/f'turboquant-causal/{panel}-{window}-final.bin').read_bytes()
 assert len(donor)==188416 and sha(donor)==donor_meta['final_sha256']
 assert donor_meta['program_sha256']==program['sha256']
 packed=bytearray();receipts=[]
 for t in range(256):
  key=(src['gauged_key'][t].astype(np.uint32)<<16).view(np.float32)
  kb=old.encode(key,K,c,S)
  row=bytearray()
  for h in range(8):
   v=donor[t*736+h*92+56:t*736+(h+1)*92]
   assert len(kb[h])==56 and len(v)==36
   row+=kb[h]+v
  assert len(row)==736
  packed+=row
  receipts.append({'position':t,'bytes':len(packed),'sha256':sha(packed),'new_row_sha256':sha(row)})
  if t+1 in (1,32,128,255,256):
   (HERE/f'{panel}-{window}-prefix-{t+1}.bin').write_bytes(packed)
 assert len(packed)==188416
 (HERE/f'{panel}-{window}-final.bin').write_bytes(packed)
 result={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,
         'source_gamma_replacement_sha256':gamma['gamma_image_sha256'],
         'program_sha256':program['sha256'],'donor_image_sha256':donor_meta['final_sha256'],
         'all_donor_V_bytes_reused':True,'K_bytes_per_head_token':56,'V_bytes_per_head_token':36,
         'cache_bytes':len(packed),'shared_program_bytes':196624,
         'incremental_gamma_bytes':0,'peak_cache_plus_program_bytes':385040,
         'final_sha256':sha(packed),'prefixes':receipts}
 (HERE/f'{panel}-{window}-manifest.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'candidate_image':sha(packed),'donor_image':donor_meta['final_sha256'],'cache':len(packed)}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
