"""One-shot fixed paper MSE+QJL key and MSE value; causal packed images."""
import hashlib,json,sys
import numpy as np
from source import HERE,arrays,FIX_SHA
D=128;BPER=92

def sha(x):return hashlib.sha256(x).hexdigest()

def program():
 meta=json.loads((HERE/'program.json').read_text());blob=(HERE/'program.fp32').read_bytes()
 assert len(blob)==196624 and sha(blob)==meta['sha256']
 raw=np.frombuffer(blob,dtype='<f4')
 return meta,raw[:16384].reshape(D,D),raw[16384:32768].reshape(D,D),raw[32768:49152].reshape(D,D),raw[49152:]

def nearest(z,c):
 # lower-index deterministic ties; order [-outer,-inner,+inner,+outer].
 return np.abs(z[...,None]-c).argmin(axis=-1).astype(np.uint8)

def encode(x,rotation,centroids,gaussian=None):
 x=np.asarray(x,dtype=np.float32).reshape(8,D)
 radius=np.linalg.norm(x,axis=-1).astype('<f4')
 assert np.all(np.isfinite(radius)) and np.all(radius>0)
 unit=x/radius[:,None]
 rotated=unit@rotation.T
 code=nearest(rotated,centroids)
 # Bits 0,2,4,6 of byte carry most significant index bit.
 payload=((code[:,0::4]<<6)|(code[:,1::4]<<4)|(code[:,2::4]<<2)|code[:,3::4]).astype(np.uint8)
 if gaussian is None:
  return [payload[h].tobytes()+radius[h:h+1].tobytes() for h in range(8)]
 mse=centroids[code]@rotation
 residual=unit-mse
 norm=np.linalg.norm(residual,axis=-1).astype('<f4')
 sign=((residual@gaussian.T)>=0).astype(np.uint8)
 signs=np.packbits(sign,axis=-1,bitorder='big')
 return [payload[h].tobytes()+signs[h].tobytes()+radius[h:h+1].tobytes()+norm[h:h+1].tobytes() for h in range(8)]

def run(panel,window):
 src=arrays(panel,window)
 meta,K,V,S,c=program()
 packed=bytearray();receipts=[]
 for t in range(256):
  key=(src['key'][t].astype(np.uint32)<<16).view(np.float32)
  val=(src['value'][t].astype(np.uint32)<<16).view(np.float32)
  kb=encode(key,K,c,S);vb=encode(val,V,c)
  row=b''.join(k+v for k,v in zip(kb,vb))
  assert len(row)==736
  packed+=row
  receipts.append({'position':t,'bytes':len(packed),'sha256':sha(packed),'new_row_sha256':sha(row)})
  if t+1 in (1,32,128,255,256):
   (HERE/f'{panel}-{window}-prefix-{t+1}.bin').write_bytes(packed)
 assert len(packed)==188416
 (HERE/f'{panel}-{window}-final.bin').write_bytes(packed)
 m={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,'program_sha256':meta['sha256'],
    'method':'paper TurboQuant uniform K3=2-bit MSE+1-bit QJL, V2 MSE; post-RoPE BF16 K source',
    'positioned_K_bytes':56,'V_bytes':36,'per_token_all_KV_heads_bytes':736,
    'max_cache_bytes':len(packed),'program_bytes':len((HERE/'program.fp32').read_bytes()),
    'peak_cache_plus_program_bytes':len(packed)+196624,'final_sha256':sha(packed),'prefixes':receipts}
 (HERE/f'{panel}-{window}-manifest.json').write_text(json.dumps(m,indent=2)+'\n')
 print(json.dumps({'panel':panel,'window':window,'cache':len(packed),'total':m['peak_cache_plus_program_bytes'],'sha256':sha(packed)}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
