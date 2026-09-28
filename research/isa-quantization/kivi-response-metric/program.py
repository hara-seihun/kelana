"""One causal KIVI K-code sweep in a fixed paid FP16 D+UU^T query metric."""
from pathlib import Path
import hashlib
import json
import math
import sys
import numpy as np
import torch
HERE=Path(__file__).resolve().parent
OWNER=HERE.parent/'kivi-causal-cache'
sys.path.insert(0,str(OWNER))
from source import arrays,FIX_SHA


def sha(b):return hashlib.sha256(b).hexdigest()

def bf(bits):return (np.asarray(bits,dtype=np.uint32)<<16).view(np.float32)

def unpack(blob,n):
    b=np.frombuffer(blob,dtype=np.uint8);assert len(b)*2==n
    return np.stack((b&15,b>>4),axis=1).reshape(n).astype(np.int32)

def pack(code):
    c=np.asarray(code,dtype=np.uint8).ravel();assert c.size%2==0 and np.all(c<16)
    return (c[::2]|(c[1::2]<<4)).tobytes()

def metric():
    blob=(HERE/'metric-fp16.bin').read_bytes()
    assert len(blob)==2304 and sha(blob)==json.loads((HERE/'metric-manifest.json').read_text())['metric_image_sha256']
    U=np.frombuffer(blob,dtype='<f2',count=1024).astype(np.float64).reshape(128,8)
    D=np.frombuffer(blob,dtype='<f2',count=128,offset=2048).astype(np.float64)
    assert np.isfinite(U).all() and np.all(D>0)
    return U,D

def assign_k(event,source,U,D):
    """One forward d0..127 sweep; actual stored FP16 fields, original code start."""
    assert len(event)==2560 and source.shape==(32,128)
    code=unpack(event[:2048],4096).reshape(32,128)
    fields=np.frombuffer(event,dtype='<f2',count=256,offset=2048).astype(np.float64).reshape(128,2)
    lo=source.min(axis=0);step=(source.max(axis=0)-lo)/15
    assert np.array_equal(fields[:,0],lo.astype('<f2'))
    assert np.array_equal(fields[:,1],step.astype('<f2'))
    actual=np.where(step>0,np.rint((source-lo)/np.where(step>0,step,1)).clip(0,15),0).astype(np.int32)
    assert np.array_equal(code,actual)
    e=fields[None,:,0]+code*fields[None,:,1]-source
    s=e@U
    before=float(np.sum(np.sum(e*e*D[None,:],axis=1)+np.sum(s*s,axis=1)))
    nchange=0
    for d in range(128):
        scale=fields[d,1]
        if scale==0:continue
        a=D[d]+U[d]@U[d]
        grad=D[d]*e[:,d]+s@U[d]
        nearest=np.rint(code[:,d]-grad/(scale*a)).clip(0,15).astype(np.int32)
        delta=(nearest-code[:,d])*scale
        e[:,d]+=delta
        s+=delta[:,None]*U[d][None,:]
        nchange+=int(np.count_nonzero(delta))
        code[:,d]=nearest
    after=float(np.sum(np.sum(e*e*D[None,:],axis=1)+np.sum(s*s,axis=1)))
    assert after<=before+1e-8*max(1,before)
    # Explicit per-source-token second evaluation protects the incremental
    # s update and the identity of the actual packed FP16 reconstruction.
    final=fields[None,:,0]+code*fields[None,:,1]-source
    independent=float(np.sum(np.sum(final*final*D[None,:],axis=1)+np.sum(np.square(final@U),axis=1)))
    assert abs(independent-after)<1e-8*max(1,after)
    return pack(code)+event[2048:],{'changed_digits':nchange,'metric_before':before,'metric_after':after}


def decode(kq,vq,kr,vr):
    key=[];value=[]
    for b in kq:
        c=unpack(b[:2048],4096).reshape(32,128).astype(np.float32)
        f=np.frombuffer(b,dtype='<f2',count=256,offset=2048).astype(np.float32).reshape(128,2)
        key.append(c*f[None,:,1]+f[None,:,0])
    for b in vq:
        c=unpack(b[:64],128).reshape(4,32).astype(np.float32)
        f=np.frombuffer(b,dtype='<f2',count=8,offset=64).astype(np.float32).reshape(4,2)
        value.append((c*f[:,1,None]+f[:,0,None]).reshape(1,128))
    key.append(bf(np.frombuffer(b''.join(kr),dtype='<u2').reshape(len(kr),128)))
    value.append(bf(np.frombuffer(b''.join(vr),dtype='<u2').reshape(len(vr),128)))
    return np.concatenate(key),np.concatenate(value)


def run(panel,window):
    U,D=metric()
    src=arrays(panel,window)
    original=json.loads((OWNER/f'{panel}-{window}-result.json').read_text())
    manifest=json.loads((OWNER/f'{panel}-{window}-manifest.json').read_text())
    owner_log=(OWNER/f'{panel}-{window}-flush.bin').read_bytes()
    assert sha(owner_log)==manifest['flush_log_sha256']
    kq=[];vq=[];kr=[];vr=[];events=bytearray();cursor=0;prefixes=[];changes=[];outputs=[[],[]];scores=[[],[]];peak=0
    for t in range(1,257):
        kr.append(src['key'][t-1].astype('<u2').tobytes())
        vr.append(src['value'][t-1].astype('<u2').tobytes())
        state=b''.join(kq+vq+kr+vr);assert len(state)==manifest['prefixes'][t-1]['before_flush']['live_state_bytes']
        prefixes.append({'position':t-1,'preflush_sha256':sha(state),'preflush_bytes':len(state)})
        peak=max(peak,len(state))
        key,value=decode(kq,vq,kr,vr)
        keyt=torch.from_numpy(key.copy());valuet=torch.from_numpy(value.copy())
        for h in range(2):
            q=src['qrot'][h][t-1]
            score=q@keyt.T/math.sqrt(128)
            pred=(score.softmax(-1)@valuet)@src['o'][:,h*128:(h+1)*128].T
            outputs[h].append(pred);scores[h].append(score)
        if len(kr)==32:
            assert owner_log[cursor:cursor+3]==b'K'+t.to_bytes(2,'little')
            source=bf(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128))
            old=owner_log[cursor+3:cursor+3+2560];assert len(old)==2560
            new,change=assign_k(old,source,U,D)
            kq.append(new);kr=[]
            changes.append({'position':t,'source_event_sha256':sha(old),'candidate_event_sha256':sha(new),**change})
            events+=b'K'+t.to_bytes(2,'little')+new
            cursor+=3+2560
        if len(vr)>32:
            assert owner_log[cursor:cursor+3]==b'V'+t.to_bytes(2,'little')
            blob=owner_log[cursor+3:cursor+3+80];assert len(blob)==80
            vq.append(blob);vr.pop(0)
            events+=b'V'+t.to_bytes(2,'little')+blob
            cursor+=3+80
        assert len(b''.join(kq+vq+kr+vr))==manifest['prefixes'][t-1]['after_flush']['live_state_bytes']
    assert cursor==len(owner_log) and peak==52400
    final=b''.join(kq+vq+kr+vr)
    report={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,'metric_fp16_sha256':sha((HERE/'metric-fp16.bin').read_bytes()),
            'original_kivi_final_sha256':manifest['final_sha256'],'final_sha256':sha(final),
            'flush_log_sha256':sha(events),'peak_state_bytes':peak,'static_metric_bytes':2304,
            'peak_state_plus_metric_bytes':peak+2304,'postflush_bytes':len(final),
            'key_flushes':changes,'changed_key_digits':sum(c['changed_digits'] for c in changes),
            'gqa_pair':{},'heads':{}}
    predgroups=[];refgroups=[]
    for h in range(2):
        out=torch.stack(outputs[h]);ref_logp,refout,_=src['teacher'][h]
        dense=torch.full((256,256),-1e9)
        for t,score in enumerate(scores[h]):dense[t,:t+1]=score
        kl=float((ref_logp.exp()*(ref_logp-dense.log_softmax(-1))).sum(-1).mean())
        report['heads'][f'head{h}']={'attention_kl':kl,'control_attention_kl':original['heads'][f'head{h}']['attention_kl'],
                                    'post_o_sse':float((refout-out).square().sum()),'post_o_ref_sq':float(refout.square().sum())}
        predgroups.append(out);refgroups.append(refout)
    pair=sum(refgroups);candidate=sum(predgroups)
    report['gqa_pair']={'post_o_sse':float((pair-candidate).square().sum()),'post_o_ref_sq':float(pair.square().sum()),
                        'control_post_o_sse':original['gqa_pair']['post_o_sse'],
                        'control_post_o_ref_sq':original['gqa_pair']['post_o_ref_sq']}
    report['gqa_pair']['post_o_rel_sq']=report['gqa_pair']['post_o_sse']/report['gqa_pair']['post_o_ref_sq']
    report['gqa_pair']['control_post_o_rel_sq']=report['gqa_pair']['control_post_o_sse']/report['gqa_pair']['control_post_o_ref_sq']
    (HERE/f'{panel}-{window}.json').write_text(json.dumps(report,indent=2)+'\n')
    (HERE/f'{panel}-{window}-final.bin').write_bytes(final)
    (HERE/f'{panel}-{window}-flush.bin').write_bytes(events)
    (HERE/f'{panel}-{window}-prefixes.json').write_text(json.dumps(prefixes)+'\n')
    print(json.dumps({'panel':panel,'window':window,'pair':report['gqa_pair']['post_o_rel_sq'],
                      'control':report['gqa_pair']['control_post_o_rel_sq'],
                      'kl':[report['heads'][f'head{h}']['attention_kl'] for h in range(2)],
                      'control_kl':[report['heads'][f'head{h}']['control_attention_kl'] for h in range(2)],
                      'changed_digits':report['changed_key_digits'],'peak_paid':peak+2304},indent=2))
    return report

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
