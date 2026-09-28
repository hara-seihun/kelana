"""One fixed R45 recent-V cache at original KIVI 4/4 G32, original K R32."""
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

K_CHUNK=2560;V_TOKEN=80;V_RECENT=45

def sha(b):return hashlib.sha256(b).hexdigest()

def bf(bits):return (np.asarray(bits,dtype=np.uint32)<<16).view(np.float32)

def unpack(b,count):
    a=np.frombuffer(b,dtype=np.uint8);assert len(a)*2==count
    return np.stack((a&15,a>>4),axis=1).reshape(count).astype(np.float32)

def decode(kq,vq,kr,vr):
    k=[];v=[]
    for b in kq:
        c=unpack(b[:2048],4096).reshape(32,128)
        f=np.frombuffer(b,dtype='<f2',count=256,offset=2048).astype(np.float32).reshape(128,2)
        k.append(f[None,:,0]+f[None,:,1]*c)
    for b in vq:
        c=unpack(b[:64],128).reshape(4,32)
        f=np.frombuffer(b,dtype='<f2',count=8,offset=64).astype(np.float32).reshape(4,2)
        v.append((f[:,0,None]+f[:,1,None]*c).reshape(1,128))
    k.append(bf(np.frombuffer(b''.join(kr),dtype='<u2').reshape(len(kr),128)))
    v.append(bf(np.frombuffer(b''.join(vr),dtype='<u2').reshape(len(vr),128)))
    return np.concatenate(k),np.concatenate(v)

def parse_original_log(data):
    k={};v={};at=0
    while at<len(data):
        kind=data[at:at+1];t=int.from_bytes(data[at+1:at+3],'little')
        size=K_CHUNK if kind==b'K' else V_TOKEN
        assert kind in (b'K',b'V')
        event=data[at+3:at+3+size];assert len(event)==size
        if kind==b'K':assert t%32==0 and t not in k;k[t]=event
        else:assert t>=33 and t not in v;v[t]=event
        at+=size+3
    assert len(k)==8 and len(v)==224
    return k,v

def run(panel,window):
    src=arrays(panel,window)
    original=json.loads((OWNER/f'{panel}-{window}-result.json').read_text())
    manifest=json.loads((OWNER/f'{panel}-{window}-manifest.json').read_text())
    oldlog=(OWNER/f'{panel}-{window}-flush.bin').read_bytes()
    assert sha(oldlog)==manifest['flush_log_sha256']
    oldk,oldv=parse_original_log(oldlog)
    kq=[];vq=[];kr=[];vr=[];log=bytearray();peak=0;receipts=[];scores=[[],[]];outputs=[[],[]]
    for t in range(1,257):
        kr.append(src['key'][t-1].astype('<u2').tobytes())
        vr.append(src['value'][t-1].astype('<u2').tobytes())
        pre=b''.join(kq+vq+kr+vr)
        assert len(kq)*32+len(kr)==len(vq)+len(vr)==t
        expected_k=manifest['prefixes'][t-1]['before_flush']
        assert len(kq)*K_CHUNK+len(kr)*256==expected_k['key_code_and_fields_bytes']+expected_k['key_recent_bytes']
        peak=max(peak,len(pre))
        receipts.append({'position':t-1,'preflush_sha256':sha(pre),'preflush_bytes':len(pre),
                         'key_quant_tokens':len(kq)*32,'key_recent_tokens':len(kr),
                         'value_quant_tokens':len(vq),'value_recent_tokens':len(vr)})
        keys,values=decode(kq,vq,kr,vr)
        kt=torch.from_numpy(keys.copy());vt=torch.from_numpy(values.copy())
        for h in range(2):
            score=src['qrot'][h][t-1]@kt.T/math.sqrt(128)
            out=(score.softmax(-1)@vt)@src['o'][:,h*128:(h+1)*128].T
            scores[h].append(score);outputs[h].append(out)
        if len(kr)==32:
            event=oldk[t]
            kq.append(event);kr=[];log+=b'K'+t.to_bytes(2,'little')+event
        if len(vr)>V_RECENT:
            # The oldest V became available for original KIVI flush 13 queries
            # earlier; same BF16 source and exact same token-wise four groups.
            token=t-V_RECENT-1
            event=oldv[token+33]
            vq.append(event);vr.pop(0);log+=b'V'+t.to_bytes(2,'little')+event
    assert peak==54688 and len(kq)==8 and len(vq)==211 and len(vr)==45
    final=b''.join(kq+vq+kr+vr);assert len(final)==48880
    result={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,
            'original_kivi_final_sha256':manifest['final_sha256'],
            'original_kivi_flush_sha256':manifest['flush_log_sha256'],
            'final_sha256':sha(final),'flush_log_sha256':sha(log),
            'preflush_peak_bytes':peak,'final_postflush_bytes':len(final),
            'method':'original KIVI K4/G32/R32, V4/G32/R45 one fixed residual allocation',
            'key_flushes':8,'value_flushes':211,'heads':{},'gqa_pair':{}}
    changed=[];reference=[]
    for h in range(2):
        out=torch.stack(outputs[h]);ref_logp,refout,_=src['teacher'][h]
        row=torch.full((256,256),-1e9)
        for j,s in enumerate(scores[h]):row[j,:j+1]=s
        kl=float((ref_logp.exp()*(ref_logp-row.log_softmax(-1))).sum(-1).mean())
        result['heads'][f'head{h}']={'attention_kl':kl,'control_attention_kl':original['heads'][f'head{h}']['attention_kl'],
                                   'post_o_sse':float((refout-out).square().sum()),
                                   'post_o_ref_sq':float(refout.square().sum())}
        changed.append(out);reference.append(refout)
    pair=sum(reference);candidate=sum(changed)
    result['gqa_pair']={'post_o_sse':float((pair-candidate).square().sum()),'post_o_ref_sq':float(pair.square().sum()),
                        'control_post_o_sse':original['gqa_pair']['post_o_sse'],
                        'control_post_o_ref_sq':original['gqa_pair']['post_o_ref_sq']}
    result['gqa_pair']['post_o_rel_sq']=result['gqa_pair']['post_o_sse']/result['gqa_pair']['post_o_ref_sq']
    result['gqa_pair']['control_post_o_rel_sq']=result['gqa_pair']['control_post_o_sse']/result['gqa_pair']['control_post_o_ref_sq']
    (HERE/f'{panel}-{window}.json').write_text(json.dumps(result,indent=2)+'\n')
    (HERE/f'{panel}-{window}-final.bin').write_bytes(final)
    (HERE/f'{panel}-{window}-flush.bin').write_bytes(log)
    (HERE/f'{panel}-{window}-prefixes.json').write_text(json.dumps(receipts)+'\n')
    print(json.dumps({'panel':panel,'window':window,'pair':result['gqa_pair']['post_o_rel_sq'],
                      'original':result['gqa_pair']['control_post_o_rel_sq'],
                      'kl':[result['heads'][f'head{h}']['attention_kl'] for h in range(2)],
                      'peak':peak},indent=2))

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
