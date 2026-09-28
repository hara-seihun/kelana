"""Chronological independent read of paid R45 V cache, original K/V event controls."""
from pathlib import Path
import json
import math
import sys
import numpy as np
import torch
from program import HERE,OWNER,arrays,bf,decode,parse_original_log,sha,unpack


def check_value(event,source_bits):
    assert len(event)==80
    x=bf(np.asarray(source_bits,dtype='<u2')).reshape(4,32)
    lo=x.min(axis=1);step=(x.max(axis=1)-lo)/15
    fields=np.frombuffer(event,dtype='<f2',count=8,offset=64).reshape(4,2)
    code=unpack(event[:64],128).reshape(4,32)
    assert np.array_equal(fields[:,0],lo.astype('<f2'))
    assert np.array_equal(fields[:,1],step.astype('<f2'))
    assert np.array_equal(code,np.where(step[:,None]>0,np.rint((x-lo[:,None])/np.where(step[:,None]>0,step[:,None],1)).clip(0,15),0))


def run(panel,window):
    src=arrays(panel,window)
    result=json.loads((HERE/f'{panel}-{window}.json').read_text())
    receipts=json.loads((HERE/f'{panel}-{window}-prefixes.json').read_text())
    manifest=json.loads((OWNER/f'{panel}-{window}-manifest.json').read_text())
    oldlog=(OWNER/f'{panel}-{window}-flush.bin').read_bytes()
    assert sha(oldlog)==manifest['flush_log_sha256']
    oldk,oldv=parse_original_log(oldlog)
    image=(HERE/f'{panel}-{window}-final.bin').read_bytes();log=(HERE/f'{panel}-{window}-flush.bin').read_bytes()
    assert sha(image)==result['final_sha256'] and sha(log)==result['flush_log_sha256']
    kq=[];vq=[];kr=[];vr=[];offset=0;peak=0;head_scores=[[],[]];head_outputs=[[],[]];nk=nv=0
    for t in range(1,257):
        kr.append(src['key'][t-1].astype('<u2').tobytes());vr.append(src['value'][t-1].astype('<u2').tobytes())
        state=b''.join(kq+vq+kr+vr)
        receipt=receipts[t-1]
        assert receipt=={'position':t-1,'preflush_sha256':sha(state),'preflush_bytes':len(state),
                         'key_quant_tokens':len(kq)*32,'key_recent_tokens':len(kr),
                         'value_quant_tokens':len(vq),'value_recent_tokens':len(vr)}
        assert len(kq)*32+len(kr)==len(vq)+len(vr)==t
        peak=max(peak,len(state))
        key,value=decode(kq,vq,kr,vr)
        kt=torch.from_numpy(key.copy());vt=torch.from_numpy(value.copy())
        for h in range(2):
            score=src['qrot'][h][t-1]@kt.T/math.sqrt(128)
            out=(score.softmax(-1)@vt)@src['o'][:,h*128:(h+1)*128].T
            head_scores[h].append(score);head_outputs[h].append(out)
        if len(kr)==32:
            assert log[offset:offset+3]==b'K'+t.to_bytes(2,'little')
            event=log[offset+3:offset+3+2560]
            assert event==oldk[t]
            # Original K event itself is independently checked by its owner.
            kq.append(event);kr=[];offset+=2563;nk+=1
        if len(vr)>45:
            assert log[offset:offset+3]==b'V'+t.to_bytes(2,'little')
            event=log[offset+3:offset+3+80]
            token=t-46
            assert event==oldv[token+33] and token==len(vq)
            check_value(event,src['value'][token])
            vq.append(event);vr.pop(0);offset+=83;nv+=1
    assert offset==len(log) and b''.join(kq+vq+kr+vr)==image
    assert peak==result['preflush_peak_bytes']==54688
    assert nk==8 and nv==211
    outputs=[];refs=[];head_kl=[];head_sse=[]
    for h in range(2):
        logits=torch.full((256,256),-1e9)
        for t,s in enumerate(head_scores[h]):logits[t,:t+1]=s
        ref_logp,ref,_=src['teacher'][h]
        out=torch.stack(head_outputs[h]);kl=float((ref_logp.exp()*(ref_logp-logits.log_softmax(-1))).sum(-1).mean())
        sse=float((ref-out).square().sum())
        assert abs(kl-result['heads'][f'head{h}']['attention_kl'])<1e-7
        assert abs(kl-result['heads'][f'head{h}']['control_attention_kl'])<1e-7
        assert abs(sse-result['heads'][f'head{h}']['post_o_sse'])<1e-6
        outputs.append(out);refs.append(ref);head_kl.append(kl);head_sse.append(sse)
    pair_sse=float((sum(refs)-sum(outputs)).square().sum())
    assert abs(pair_sse-result['gqa_pair']['post_o_sse'])<1e-6
    report={'panel':panel,'window':window,'verified_preflush_prefixes':256,
            'verified_original_key_event_bytes':nk,'verified_original_value_event_bytes':nv,
            'verified_value_fields_against_source':nv,'peak_bytes':peak,
            'final_sha256':sha(image),'head_kl':head_kl,'head_post_o_sse':head_sse,'pair_post_o_sse':pair_sse}
    (HERE/f'{panel}-{window}-replay.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'pair_post_o_sse':pair_sse,'verified_v':nv}))

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
