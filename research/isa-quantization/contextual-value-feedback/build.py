"""Frozen four-arm layer1 chronological cache producer, one window per invocation."""
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
from custody import HERE,sha,source

ARMS=('original','feedback','delay2','k2v4')

def f32(bits):return (np.asarray(bits,dtype='<u4')<<16).view('<f4')
def pack(c,bits):
    c=np.asarray(c,dtype='u1').ravel()
    if bits==2:return (c[::4]|(c[1::4]<<2)|(c[2::4]<<4)|(c[3::4]<<6)).tobytes()
    return (c[::2]|(c[1::2]<<4)).tobytes()
def quant(data,bits,target=None):
    lo=float(data.min());step=(float(data.max())-lo)/(2**bits-1)
    values=data if target is None else target
    code=np.zeros(data.size,dtype='u1') if step==0 else np.clip(np.rint((values-lo)/step),0,2**bits-1).astype('u1')
    return code,np.array((lo,step),dtype='<f2').tobytes()
def key(block):
    assert block.shape==(32,128)
    value=f32(block)
    codes=np.empty((32,128),dtype='u1');fields=bytearray()
    for d in range(128):codes[:,d],f=quant(value[:,d],2);fields+=f
    out=pack(codes,2)+fields
    assert len(out)==1536
    return out
def val(src,bits,residual):
    value=f32(src);target=np.add(value,residual,dtype='<f4') if residual is not None else value
    codes=np.empty(128,dtype='u1');fields=bytearray();reconstructed=np.empty(128,dtype='<f4')
    for g in range(4):
        sl=slice(g*32,(g+1)*32)
        codes[sl],f=quant(value[sl],bits,target[sl]);fields+=f
        lo,step=np.frombuffer(f,dtype='<f2').astype('<f4')
        reconstructed[sl]=lo+step*codes[sl].astype('<f4')
    out=pack(codes,bits)+fields
    assert len(out)==(48 if bits==2 else 80)
    return out,(np.subtract(target,reconstructed,dtype='<f4') if residual is not None else None)
def state(kq,vq,kr,vr):return b''.join(kq+vq+kr+vr)

def run(panel,w):
    arrays,record=source(panel,w)
    custody=json.loads((HERE/'custody.json').read_text())
    match=next(r for r in custody['records'] if r['panel']==panel and r['window']==w)
    assert match['source_sha256']==record['source_file_sha256']
    assert sha(arrays['v'].tobytes())==match['v_sha256']
    assert sha(b''.join(val(arrays['v'][t,h],2,None)[0] for t in range(256) for h in range(8)))==match['packed_g32_v_sha256']
    k=arrays['k'];v=arrays['v'];manifest={'panel':panel,'window':w,'source_sha256':record['source_file_sha256'],'source_v_custody':match,'arms':{}}
    for arm in ARMS:
        heads=[]
        for h in range(8):
            kq=[];vq=[];kr=[];vr=[];residual=np.zeros(128,dtype='<f4');logs=bytearray();prefix=[];peak=0
            for t in range(1,257):
                kr.append(k[t-1,h].astype('<u2').tobytes());vr.append(v[t-1,h].astype('<u2').tobytes())
                pre=state(kq,vq,kr,vr);peak=max(peak,len(pre))
                entry={'t':t,'pre_sha256':sha(pre),'pre_bytes':len(pre),'residual_before_sha256':sha(residual.tobytes()),'k_chunks':len(kq),'v_tokens':len(vq),'recent_k':len(kr),'recent_v':len(vr)}
                if t in (128,256):
                    name=f'{panel}-{w}-{arm}-t{t}-h{h}.bin';(HERE/name).write_bytes(pre);entry['image_file']=name
                if len(kr)==32:
                    blob=key(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128))
                    kq.append(blob);logs+=b'K'+t.to_bytes(2,'little')+blob;kr=[]
                threshold=35 if arm=='delay2' else 33
                if len(vr)==threshold:
                    src=np.frombuffer(vr.pop(0),dtype='<u2')
                    blob,updated=val(src,4 if arm=='k2v4' else 2,residual if arm=='feedback' else None)
                    if updated is not None:residual=updated
                    vq.append(blob);logs+=b'V'+t.to_bytes(2,'little')+blob
                post=state(kq,vq,kr,vr)
                entry.update(post_sha256=sha(post),post_bytes=len(post),residual_after_sha256=sha(residual.tobytes()))
                prefix.append(entry)
            image=state(kq,vq,kr,vr)
            stem=f'{panel}-{w}-{arm}-h{h}'
            (HERE/f'{stem}-events.bin').write_bytes(logs)
            (HERE/f'{stem}-final.bin').write_bytes(image)
            heads.append({'h':h,'events_sha256':sha(logs),'final_sha256':sha(image),'final_bytes':len(image),'peak_bytes':peak,'v_flushes':len(vq),'prefix':prefix,'residual_final_sha256':sha(residual.tobytes())})
        extra=4096 if arm=='feedback' else 0
        peak=max(h['peak_bytes'] for h in heads)*8+extra
        final=sum(h['final_bytes'] for h in heads)+extra
        assert (peak,final)=={'original':(304768,249856),'feedback':(308864,253952),'delay2':(308096,253184),'k2v4':(361856,307200)}[arm]
        manifest['arms'][arm]={'heads':heads,'peak_total_bytes':peak,'final_total_bytes':final,'feedback_residual_bytes':extra}
    (HERE/f'{panel}-{w}-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':w,'peaks':{a:manifest['arms'][a]['peak_total_bytes'] for a in ARMS}}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
