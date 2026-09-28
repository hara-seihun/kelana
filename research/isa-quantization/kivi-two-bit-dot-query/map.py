"""One frozen byte-dot KIVI2 query consumer; original paid events and complete O."""
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
BASE=ROOT/'kivi-two-bit-causal'
sys.path.insert(0,str(ROOT/'skvq-global-gqa'))
from source import arrays,FIX_SHA
sys.path.insert(0,str(BASE))
import replay as original_reader


def sha(data):return hashlib.sha256(data).hexdigest()


def scores_from_codes(kq,recent,q):
    """q: two FP32 128D heads. Compute no expanded real K matrix."""
    result=np.empty((2,len(kq)*32+len(recent)),dtype=np.float32)
    zero=0;range_max=0;scales=[]
    for c,blob in enumerate(kq):
        codes=original_reader.unpack(blob[:1024],4096).astype(np.int32).reshape(32,4,32)
        fields=np.frombuffer(blob,dtype='<f2',count=256,offset=1024).astype(np.float32).reshape(128,2)
        folded=(q*fields[:,1][None,:]).reshape(2,4,32)
        maximum=np.max(np.abs(folded),axis=-1)
        scale=np.where(maximum>0,maximum/np.float32(127),np.float32(1)).astype(np.float32)
        packed=np.clip(np.rint(folded/scale[:,:,None]),-127,127).astype(np.int8)
        assert int(np.max(np.abs(packed)))<=127
        dot=np.einsum('tgd,hgd->htg',codes,packed.astype(np.int32),optimize=True)
        assert dot.dtype==np.int32 and int(np.max(np.abs(dot)))<=12192
        bias=np.sum(q*fields[:,0][None,:],axis=-1,dtype=np.float32)
        result[:,c*32:(c+1)*32]=bias[:,None]+np.sum(dot.astype(np.float32)*scale[:,None,:],axis=-1,dtype=np.float32)
        zero+=int(np.count_nonzero(maximum==0))
        range_max=max(range_max,int(np.max(np.abs(dot))))
        scales.append(scale.copy())
    if recent:
        raw=np.frombuffer(b''.join(recent),dtype='<u2').reshape(len(recent),128)
        k=original_reader.bf16(raw)
        result[:,len(kq)*32:]=q@k.T
    return result * np.float32(1/math.sqrt(128)), zero, range_max, scales


def run(panel,window):
    torch.set_num_threads(1)
    src=arrays(panel,window)
    manifest=json.loads((BASE/f'{panel}-{window}-manifest.json').read_text())
    assert manifest['fixture_sha256']==FIX_SHA
    frozen=json.loads((BASE/f'{panel}-{window}-result.json').read_text())
    keys=src['krot'].permute(1,0,2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
    values=src['value'].reshape(256,8,128)
    logs=[];receipts=[];finals=[]
    for h in range(8):
        info=manifest['groups'][f'kv{h}'];prefix=f'{panel}-{window}-head{h}'
        log=(BASE/f'{prefix}-events.bin').read_bytes();final=(BASE/f'{prefix}-final.bin').read_bytes()
        assert sha(log)==info['events_sha256']==frozen['head_events_sha256'][h]
        assert sha(final)==info['final_sha256']==frozen['head_image_sha256'][h]
        logs.append(log);receipts.append(info['prefixes']);finals.append(final)
    positions=[0]*8
    kq=[[] for _ in range(8)];vq=[[] for _ in range(8)];kr=[[] for _ in range(8)];vr=[[] for _ in range(8)]
    changed=[];conventional=[];kl=torch.zeros(16);control_kl=torch.zeros(16)
    max_logit_diff=0.;max_output_diff=0.;dot_max=0;zero_groups=0;scale_min=float('inf');scale_max=0.;prep_groups=0
    with torch.no_grad():
        for t in range(1,257):
            changed_scores=[];control_k=[];shared_v=[]
            for h in range(8):
                kr[h].append(keys[t-1,h].astype('<u2').tobytes());vr[h].append(values[t-1,h].astype('<u2').tobytes())
                state=original_reader.state(kq[h],vq[h],kr[h],vr[h])
                original_reader.verify(state,receipts[h][t-1]['before_query_flush'],kq[h],vq[h],kr[h],vr[h])
                q=src['qrot'][2*h:2*h+2,t-1].numpy()
                score,zeros,largest,scales=scores_from_codes(kq[h],kr[h],q)
                zero_groups+=zeros;dot_max=max(dot_max,largest)
                for scale in scales:
                    scale_min=min(scale_min,float(scale.min()));scale_max=max(scale_max,float(scale.max()));prep_groups+=scale.size
                changed_scores.append(torch.from_numpy(score.copy()))
                k,v=original_reader.decode(state,len(kq[h]),len(vq[h]),len(kr[h]),len(vr[h]))
                control_k.append(torch.from_numpy(k.copy()));shared_v.append(torch.from_numpy(v.copy()))
            l=torch.cat(changed_scores,dim=0)
            k=torch.stack(control_k).repeat_interleave(2,dim=0)
            v=torch.stack(shared_v).repeat_interleave(2,dim=0)
            lc=torch.bmm(src['qrot'][:,t-1,None,:],k.transpose(1,2)).squeeze(1)/math.sqrt(128)
            max_logit_diff=max(max_logit_diff,float((l-lc).abs().max()))
            p=l.softmax(-1);pc=lc.softmax(-1)
            target=src['teacher_logp'][:,t-1,:t]
            kl+=(target.exp()*(target-l.log_softmax(-1))).sum(-1)
            control_kl+=(target.exp()*(target-lc.log_softmax(-1))).sum(-1)
            out=(torch.bmm(p[:,None,:],v).reshape(2048))@src['o'].T
            outc=(torch.bmm(pc[:,None,:],v).reshape(2048))@src['o'].T
            changed.append(out);conventional.append(outc)
            max_output_diff=max(max_output_diff,float((out-outc).abs().max()))
            for h in range(8):
                def event(tag,size):
                    pos=positions[h];data=logs[h]
                    assert data[pos:pos+1]==tag and int.from_bytes(data[pos+1:pos+3],'little')==t
                    block=data[pos+3:pos+3+size];assert len(block)==size
                    positions[h]+=3+size
                    return block
                if len(kr[h])==32:
                    blob=event(b'K',1536)
                    original_reader.check_event(blob,'K',keys[t-32:t,h]);kq[h].append(blob);kr[h].clear()
                if len(vr[h])>32:
                    blob=event(b'V',48)
                    original_reader.check_event(blob,'V',values[t-33,h]);vq[h].append(blob);vr[h].pop(0)
                post=original_reader.state(kq[h],vq[h],kr[h],vr[h])
                original_reader.verify(post,receipts[h][t-1]['after_query_flush'],kq[h],vq[h],kr[h],vr[h])
    assert all(positions[h]==len(logs[h]) and original_reader.state(kq[h],vq[h],kr[h],vr[h])==finals[h] for h in range(8))
    obs=torch.stack(changed);conv=torch.stack(conventional);teacher=src['teacher']
    changed_sse=float((obs-teacher).square().sum());control_sse=float((conv-teacher).square().sum());den=float(teacher.square().sum())
    assert abs(control_sse-frozen['full_o_sse'])<1e-6 and abs(den-frozen['full_o_ref_sq'])<1e-6
    assert torch.allclose(control_kl/256,torch.tensor(frozen['head_kl']),atol=1e-6,rtol=1e-5)
    result={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,
            'original_paid_head_image_sha256':frozen['head_image_sha256'],
            'original_paid_head_events_sha256':frozen['head_events_sha256'],
            'changed_full_o_sse':changed_sse,'conventional_full_o_sse':control_sse,'teacher_full_o_sq':den,
            'changed_head_kl':(kl/256).tolist(),'conventional_head_kl':(control_kl/256).tolist(),
            'max_abs_logit_difference':max_logit_diff,'max_abs_o_difference':max_output_diff,
            'max_abs_integer_group_dot':dot_max,'zero_folded_groups':zero_groups,
            'min_nonzero_query_scale':scale_min if prep_groups else None,
            'max_query_scale':scale_max,'prepared_query_groups':prep_groups,
            'all_prefix_receipts_checked':256*8,'same_original_value_decode_and_o':True}
    (HERE/f'{panel}-{window}-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'byte_full_o_rel_sq':changed_sse/den,
                      'owner_full_o_rel_sq':control_sse/den,'max_logit_diff':max_logit_diff,'max_o_diff':max_output_diff}))

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
