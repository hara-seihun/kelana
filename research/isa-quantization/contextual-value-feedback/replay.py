"""Independent chronological replay, source/field/residual audit and full-O CPU observer."""
import hashlib
import json
import math
import sys
from pathlib import Path
import numpy as np
import torch
from custody import HERE,sha,source
from weights import load as load_original_o

ARMS=('original','feedback','delay2','k2v4')
def f32(raw):return (np.asarray(raw,dtype='<u4')<<16).view('<f4')
def packed_digits(blob,bits,count):
    b=np.frombuffer(blob,dtype='u1')
    if bits==2:return np.stack((b&3,(b>>2)&3,(b>>4)&3,b>>6),axis=-1).reshape(count)
    return np.stack((b&15,b>>4),axis=-1).reshape(count)
def fields(data,bits):
    lo=float(data.min());step=(float(data.max())-lo)/(2**bits-1)
    return np.array((lo,step),dtype='<f2').tobytes()
def expect_k(raw,blob):
    assert len(blob)==1536 and raw.shape==(32,128)
    x=f32(raw)
    digits=packed_digits(blob[:1024],2,4096).reshape(32,128)
    for d in range(128):
        col=x[:,d];field=fields(col,2)
        assert blob[1024+d*4:1028+d*4]==field
        lo=float(col.min());step=(float(col.max())-lo)/3
        code=np.zeros(32,dtype='u1') if step==0 else np.clip(np.rint((col-lo)/step),0,3).astype('u1')
        assert np.array_equal(code,digits[:,d])
def expect_v(raw,blob,bits,prior):
    assert len(blob)==(48 if bits==2 else 80)
    x=f32(raw);target=np.add(x,prior,dtype='<f4') if prior is not None else x
    codes=packed_digits(blob[:128*bits//8],bits,128)
    decoded=np.empty(128,dtype='<f4')
    for g in range(4):
        sl=slice(g*32,(g+1)*32)
        field=fields(x[sl],bits)
        assert blob[128*bits//8+g*4:128*bits//8+g*4+4]==field
        lo=float(x[sl].min());step=(float(x[sl].max())-lo)/(2**bits-1)
        code=np.zeros(32,dtype='u1') if step==0 else np.clip(np.rint((target[sl]-lo)/step),0,2**bits-1).astype('u1')
        assert np.array_equal(codes[sl],code)
        stored=np.frombuffer(field,dtype='<f2').astype('<f4')
        decoded[sl]=stored[0]+stored[1]*codes[sl].astype('<f4')
    return np.subtract(target,decoded,dtype='<f4') if prior is not None else prior

def unpack_records(records,bits,key):
    if not records:return np.empty((0,128),dtype='<f4')
    data=np.frombuffer(b''.join(records),dtype='u1')
    if key:
        n=len(records);s=1536
        codes=packed_digits(data.reshape(n,s)[:,:1024].tobytes(),2,n*4096).reshape(n,32,128).astype('<f4')
        ft=np.frombuffer(data.reshape(n,s)[:,1024:].copy().tobytes(),dtype='<f2').astype('<f4').reshape(n,128,2)
        return (ft[:,None,:,0]+codes*ft[:,None,:,1]).reshape(-1,128)
    n=len(records);s=48 if bits==2 else 80;codebytes=128*bits//8
    codes=packed_digits(data.reshape(n,s)[:,:codebytes].tobytes(),bits,n*128).reshape(n,4,32).astype('<f4')
    ft=np.frombuffer(data.reshape(n,s)[:,codebytes:].copy().tobytes(),dtype='<f2').astype('<f4').reshape(n,4,2)
    return (ft[:,:,None,0]+codes*ft[:,:,None,1]).reshape(n,128)

def decode(cache,bits):
    kq,vq,kr,vr=cache
    k=np.concatenate((unpack_records(kq,2,True),f32(np.frombuffer(b''.join(kr),dtype='<u2').reshape(-1,128))))
    v=np.concatenate((unpack_records(vq,bits,False),f32(np.frombuffer(b''.join(vr),dtype='<u2').reshape(-1,128))))
    assert k.shape==v.shape and len(k)>0
    return k,v

def score(q,ks,vs,wo):
    k=torch.from_numpy(np.ascontiguousarray(np.stack(ks)))
    v=torch.from_numpy(np.ascontiguousarray(np.stack(vs)))
    query=torch.from_numpy(np.ascontiguousarray(q))
    a=torch.bmm(query[:,None,:],k[torch.arange(16)//2].transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1)
    mixed=torch.bmm(a[:,None,:],v[torch.arange(16)//2]).squeeze(1).reshape(2048)
    return (mixed@wo.T).numpy().copy()

def run(panel,w,full=False):
    torch.set_num_threads(1)
    arrays,source_rec=source(panel,w)
    m=json.loads((HERE/f'{panel}-{w}-manifest.json').read_text())
    assert m['source_sha256']==source_rec['source_file_sha256']
    custody=json.loads((HERE/'custody.json').read_text())
    owner=next(r for r in custody['records'] if r['panel']==panel and r['window']==w)
    assert m['source_v_custody']==owner and owner['v_sha256']==sha(arrays['v'].tobytes())
    # Every event is independently checked against source available at its actual timestamp.
    per_arm={}; all_pre={}
    for arm in ARMS:
        heads=[];pre_by_t={}
        for h in range(8):
            meta=m['arms'][arm]['heads'][h]
            stem=f'{panel}-{w}-{arm}-h{h}'
            log=(HERE/f'{stem}-events.bin').read_bytes()
            assert sha(log)==meta['events_sha256']
            events=[];p=0
            while p<len(log):
                kind=chr(log[p]);t=int.from_bytes(log[p+1:p+3],'little')
                size=1536 if kind=='K' else (80 if arm=='k2v4' else 48)
                assert kind in ('K','V') and t in range(1,257)
                events.append((kind,t,log[p+3:p+3+size]));p+=3+size
            assert p==len(log)
            kq=[];vq=[];kr=[];vr=[];residual=np.zeros(128,dtype='<f4');ix=0
            for t in range(1,257):
                kr.append(arrays['k'][t-1,h].astype('<u2').tobytes())
                vr.append(arrays['v'][t-1,h].astype('<u2').tobytes())
                pre=b''.join(kq+vq+kr+vr);r=meta['prefix'][t-1]
                assert (sha(pre),len(pre),sha(residual.tobytes()))==(r['pre_sha256'],r['pre_bytes'],r['residual_before_sha256'])
                assert (len(kq),len(vq),len(kr),len(vr))==(r['k_chunks'],r['v_tokens'],r['recent_k'],r['recent_v'])
                if t in (128,256) or full:
                    pre_by_t.setdefault(t,[None]*8)[h]=([b for b in kq],[b for b in vq],[b for b in kr],[b for b in vr])
                if 'image_file' in r: assert (HERE/r['image_file']).read_bytes()==pre
                if len(kr)==32:
                    kind,when,blob=events[ix];ix+=1
                    assert kind=='K' and when==t
                    expect_k(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128),blob)
                    kq.append(blob);kr=[]
                threshold=35 if arm=='delay2' else 33
                if len(vr)==threshold:
                    kind,when,blob=events[ix];ix+=1
                    assert kind=='V' and when==t
                    src=np.frombuffer(vr.pop(0),dtype='<u2')
                    updated=expect_v(src,blob,4 if arm=='k2v4' else 2,residual if arm=='feedback' else None)
                    if arm=='feedback':residual=updated
                    vq.append(blob)
                post=b''.join(kq+vq+kr+vr)
                assert (sha(post),len(post),sha(residual.tobytes()))==(r['post_sha256'],r['post_bytes'],r['residual_after_sha256'])
            assert ix==len(events)==8+meta['v_flushes']
            assert sha(post)==meta['final_sha256']==sha((HERE/f'{stem}-final.bin').read_bytes())
            assert sha(residual.tobytes())==meta['residual_final_sha256']
            heads.append(meta)
        assert sum(h['final_bytes'] for h in heads)+(4096 if arm=='feedback' else 0)==m['arms'][arm]['final_total_bytes']
        all_pre[arm]=pre_by_t
    wo=load_original_o(source_rec['original_o_bf16_sha256'])
    observations={a:[] for a in ARMS};sensitivity=[]
    for t in (range(1,257) if full else (128,256)):
        q=arrays['q'][:,t-1,:]
        teacher=arrays['teacher'][t-1].astype('f8')
        k_source=f32(arrays['k'][:t]).transpose(1,0,2).copy()
        v_source=f32(arrays['v'][:t]).transpose(1,0,2).copy()
        boundary=score(q,k_source,v_source,wo).astype('f8')
        sensitivity.append({'t':t,'bf16_post_rope_k_sse':float(np.square(boundary-teacher).sum()),'teacher_sq':float(np.square(teacher).sum())})
        for arm in ARMS:
            states=all_pre[arm][t]
            decoded=[decode(s,4 if arm=='k2v4' else 2) for s in states]
            assert all(a.shape==(t,128) and b.shape==(t,128) for a,b in decoded)
            out=score(q,[x[0] for x in decoded],[x[1] for x in decoded],wo).astype('f8')
            observations[arm].append({'t':t,'sse':float(np.square(out-teacher).sum()),'teacher_sq':float(np.square(teacher).sum()),'output_sha256':sha(out.astype('<f4').tobytes())})
    result={'panel':panel,'window':w,'query_count':len(sensitivity),'source_sha256':source_rec['source_file_sha256'],'teacher_sq':float(sum(r['teacher_sq'] for r in sensitivity)),'source_bf16_key_boundary':sensitivity,'arms':observations}
    (HERE/f'{panel}-{w}-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':w,'queries':len(sensitivity),'sse':{a:sum(x['sse'] for x in observations[a]) for a in ARMS}}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]),len(sys.argv)>3 and sys.argv[3]=='--full')
