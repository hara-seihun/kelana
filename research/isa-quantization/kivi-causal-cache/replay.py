"""Independent causal byte reader: consumes each emitted flush event only after its query."""
from pathlib import Path
import hashlib
import json
import math
import sys
import numpy as np
import torch
from source import HERE,arrays,FIX_SHA

K_BYTES=2560;V_BYTES=80


def bf16(bits):
    return (np.asarray(bits,dtype=np.uint32)<<16).view(np.float32)


def unpack(blob,count):
    x=np.frombuffer(blob,dtype='u1');assert len(x)*2==count
    return np.stack((x&15,x>>4),axis=1).reshape(count).astype(np.float32)


def decode(blob,nk,nv,kr,vr):
    at=0;keys=[];values=[]
    assert nk%32==0
    for _ in range(nk//32):
        codes=unpack(blob[at:at+2048],4096).reshape(32,128);at+=2048
        fields=np.frombuffer(blob,dtype='<f2',count=256,offset=at).astype(np.float32).reshape(128,2);at+=512
        assert np.isfinite(fields).all() and np.all(fields[:,1]>=0)
        keys.append(codes*fields[None,:,1]+fields[None,:,0])
    for _ in range(nv):
        codes=unpack(blob[at:at+64],128).reshape(4,32);at+=64
        fields=np.frombuffer(blob,dtype='<f2',count=8,offset=at).astype(np.float32).reshape(4,2);at+=16
        assert np.isfinite(fields).all() and np.all(fields[:,1]>=0)
        values.append((codes*fields[:,1,None]+fields[:,0,None]).reshape(1,128))
    rawk=np.frombuffer(blob,dtype='<u2',count=kr*128,offset=at).reshape(kr,128);at+=kr*256
    rawv=np.frombuffer(blob,dtype='<u2',count=vr*128,offset=at).reshape(vr,128);at+=vr*256
    assert at==len(blob)
    k=np.concatenate(keys+[bf16(rawk)],axis=0) if keys else bf16(rawk)
    v=np.concatenate(values+[bf16(rawv)],axis=0) if values else bf16(rawv)
    assert k.shape==(nk+kr,128) and v.shape==(nv+vr,128)
    return k,v


def check_event(blob,which,source_bits):
    """Check stored paid fields and digits against only source tokens available at flush."""
    source=bf16(source_bits).astype(np.float32)
    if which=='K':
        assert source.shape==(32,128)
        lo=source.min(axis=0);hi=source.max(axis=0)
        data=source
        stored=unpack(blob[:2048],4096).reshape(32,128)
        fields=np.frombuffer(blob[2048:],dtype='<f2').reshape(128,2)
    else:
        assert source.shape==(128,)
        data=source.reshape(4,32)
        lo=data.min(axis=1);hi=data.max(axis=1)
        stored=unpack(blob[:64],128).reshape(4,32)
        fields=np.frombuffer(blob[64:],dtype='<f2').reshape(4,2)
    step=(hi-lo)/15
    assert np.array_equal(fields[:,0],lo.astype('<f2'))
    assert np.array_equal(fields[:,1],step.astype('<f2'))
    safe=np.where(step>0,step,1)
    if which=='K':expected=np.where(step[None,:]>0,np.clip(np.rint((data-lo[None,:])/safe[None,:]),0,15),0)
    else:expected=np.where(step[:,None]>0,np.clip(np.rint((data-lo[:,None])/safe[:,None]),0,15),0)
    assert np.array_equal(stored,expected)


def verify_state(blob,receipt,t,stage):
    assert hashlib.sha256(blob).hexdigest()==receipt['sha256']
    assert len(blob)==receipt['live_state_bytes']
    if t in (31,32,33,255,256):
        assert blob==(HERE/f'{PANEL}-{WINDOW}-{stage}-{t}.bin').read_bytes()
    return receipt['key_quant_tokens'],receipt['value_quant_tokens'],receipt['key_recent_tokens'],receipt['value_recent_tokens']


def run(panel,window):
    global PANEL,WINDOW
    PANEL,WINDOW=panel,window
    src=arrays(panel,window)
    manifest=json.loads((HERE/f'{panel}-{window}-manifest.json').read_text())
    assert manifest['fixture_sha256']==FIX_SHA and manifest['panel']==panel and manifest['window']==window
    log=(HERE/f'{panel}-{window}-flush.bin').read_bytes()
    assert hashlib.sha256(log).hexdigest()==manifest['flush_log_sha256']
    assert len(log)==manifest['flush_log_bytes']
    image=(HERE/f'{panel}-{window}-final.bin').read_bytes()
    assert hashlib.sha256(image).hexdigest()==manifest['final_sha256']
    kq=[];vq=[];kr=[];vr=[];position=0;peak=0
    outputs=[[],[]];logits=[[],[]];sensitivity=[[],[]];sens_logits=[[],[]]
    max_source_difference=0.;max_teacher_score_diff=0.;max_teacher_output_diff=0.
    event_count={'K':0,'V':0}
    def event(kind,t,size):
        nonlocal position
        assert log[position:position+1]==kind.encode() and int.from_bytes(log[position+1:position+3],'little')==t
        b=log[position+3:position+3+size];assert len(b)==size
        position+=3+size;event_count[kind]+=1
        return b
    with torch.no_grad():
        for t in range(1,257):
            kr.append(src['key'][t-1].astype('<u2').tobytes())
            vr.append(src['value'][t-1].astype('<u2').tobytes())
            pre=b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)
            receipt=manifest['prefixes'][t-1]
            assert receipt['position']==t-1
            nk,nv,nkr,nvr=verify_state(pre,receipt['before_flush'],t,'pre')
            assert nk+nkr==nv+nvr==t
            peak=max(peak,len(pre))
            key,value=decode(pre,nk,nv,nkr,nvr)
            keyt=torch.from_numpy(key.copy());valuet=torch.from_numpy(value.copy())
            # Qwen-source control: same paid cache, but recent K in its original
            # FP32 rotary form. This prices 2 extra bytes per recent key element.
            float_recent=key.copy();float_recent[nk:]=src['krot'][nk:t].numpy()
            max_source_difference=max(max_source_difference,float(np.max(abs(float_recent-key))))
            for head in range(2):
                q=src['qrot'][head][t-1]
                ref_l=q@src['krot'][:t].T/math.sqrt(128)
                ref_out=(ref_l.softmax(-1)@src['vraw'][:t])@src['o'][:,head*128:(head+1)*128].T
                max_teacher_score_diff=max(max_teacher_score_diff,float((ref_l-src['teacher'][head][2][t-1,:t]).abs().max()))
                max_teacher_output_diff=max(max_teacher_output_diff,float((ref_out-src['teacher'][head][1][t-1]).abs().max()))
                l=q@keyt.T/math.sqrt(128)
                prob=l.softmax(-1)
                out=(prob@valuet)@src['o'][:,head*128:(head+1)*128].T
                ls=q@torch.from_numpy(float_recent).T/math.sqrt(128)
                os=(ls.softmax(-1)@valuet)@src['o'][:,head*128:(head+1)*128].T
                outputs[head].append(out)
                sensitivity[head].append(os)
                logits[head].append(l);sens_logits[head].append(ls)
            if len(kr)==32:
                blob=event('K',t,K_BYTES)
                available=src['key'][t-32:t]
                check_event(blob,'K',available)
                kq.append(blob);kr=[]
            if len(vr)>32:
                blob=event('V',t,V_BYTES)
                available=src['value'][t-33]
                check_event(blob,'V',available)
                vq.append(blob);vr.pop(0)
            post=b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)
            verify_state(post,receipt['after_flush'],t,'post')
    assert position==len(log) and event_count=={'K':8,'V':224}
    assert max_teacher_score_diff<1e-4 and max_teacher_output_diff<1e-4
    assert post==image and peak==manifest['max_live_state_bytes']==52400
    assert len(post)==manifest['final_postflush_bytes']==46592
    teacher=src['teacher'];record={'panel':panel,'window':window,
        'fixture_sha256':FIX_SHA,'final_image_sha256':manifest['final_sha256'],
        'flush_log_sha256':manifest['flush_log_sha256'],'preflush_peak_bytes':peak,
        'postflush_final_bytes':len(post),'event_count':event_count,
        'recent_bf16_vs_source_fp32_k_max_abs':max_source_difference,
        'uncompressed_online_vs_teacher_max_score_abs':max_teacher_score_diff,
        'uncompressed_online_vs_teacher_max_output_abs':max_teacher_output_diff,
        'heads':{},'gqa_pair':{}}
    out_groups=[];reference_groups=[];sens_groups=[]
    for h in range(2):
        out=torch.stack(outputs[h]);sen=torch.stack(sensitivity[h])
        target_logp,reference,_=teacher[h]
        row_logits=torch.full((256,256),-1e9,dtype=torch.float32)
        for j,row in enumerate(logits[h]):row_logits[j,:j+1]=row
        logp=row_logits.log_softmax(-1)
        row_sens=torch.full((256,256),-1e9,dtype=torch.float32)
        for j,row in enumerate(sens_logits[h]):row_sens[j,:j+1]=row
        logp_sens=row_sens.log_softmax(-1)
        diff=reference-out;d2=reference-sen
        record['heads'][f'head{h}']={
            'attention_kl':float((target_logp.exp()*(target_logp-logp)).sum(-1).mean()),
            'post_o_sse':float(diff.square().sum()),'post_o_ref_sq':float(reference.square().sum()),
            'recent_fp32_k_sensitivity_post_o_sse':float(d2.square().sum()),
            'recent_fp32_k_sensitivity_attention_kl':float((target_logp.exp()*(target_logp-logp_sens)).sum(-1).mean()),
        }
        out_groups.append(out);reference_groups.append(reference);sens_groups.append(sen)
    pair=sum(reference_groups);changed=sum(out_groups);control=sum(sens_groups)
    record['gqa_pair']={'post_o_sse':float((pair-changed).square().sum()),
        'post_o_ref_sq':float(pair.square().sum()),
        'recent_fp32_k_sensitivity_post_o_sse':float((pair-control).square().sum())}
    path=HERE/f'{panel}-{window}-result.json';path.write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'pair_post_o_rel_sq':record['gqa_pair']['post_o_sse']/record['gqa_pair']['post_o_ref_sq'],
                      'head0_kl':record['heads']['head0']['attention_kl'],'peak':peak},indent=2))

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
