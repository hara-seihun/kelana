"""Independent train-only event-log replay at each causal prefix of the failed gauge."""
from pathlib import Path
import hashlib
import json
import math
import sys
import numpy as np
import torch
from program import HERE,OWNER,arrays,bf,bits,transform,decode_state,unpack,sha


def run(panel='train',window=0):
    assert (panel,window)==('train',0), 'Predeclared train0 gate failed; held data is not opened.'
    src=arrays(panel,window)
    report=json.loads((HERE/f'{panel}-{window}.json').read_text())
    prefixes=json.loads((HERE/f'{panel}-{window}-prefixes.json').read_text())
    log=(HERE/f'{panel}-{window}-flush.bin').read_bytes()
    image=(HERE/f'{panel}-{window}-final.bin').read_bytes()
    frozen=(OWNER/f'{panel}-{window}-flush.bin').read_bytes()
    assert sha(log)==report['flush_log_sha256'] and sha(image)==report['final_image_sha256']
    kq=[];vq=[];kr=[];vr=[];cursor=0;frozen_at=0;pred=[[],[]];scores=[[],[]];peak=0
    q=[transform(x.numpy()) for x in src['qrot']]
    for t in range(1,257):
        kr.append(bits(transform(bf(src['key'][t-1]))).astype('<u2').tobytes())
        vr.append(src['value'][t-1].astype('<u2').tobytes())
        state=b''.join(kq+vq+kr+vr)
        receipt=prefixes[t-1]
        assert receipt['position']==t-1 and receipt['before_flush_bytes']==len(state)
        assert sha(state)==receipt['before_flush_sha256']
        peak=max(peak,len(state))
        k,v=decode_state(kq,vq,kr,vr)
        for h in range(2):
            s=torch.from_numpy(q[h][t-1].copy())@torch.from_numpy(k.copy()).T/math.sqrt(128)
            y=(s.softmax(-1)@torch.from_numpy(v.copy()))@src['o'][:,h*128:(h+1)*128].T
            scores[h].append(s);pred[h].append(y)
        if len(kr)==32:
            assert log[cursor:cursor+3]==b'K'+t.to_bytes(2,'little')
            blob=log[cursor+3:cursor+3+2560];assert len(blob)==2560
            cursor+=3+2560
            source=bf(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128))
            low=source.min(0);step=(source.max(0)-low)/15
            fields=np.frombuffer(blob,dtype='<f2',count=256,offset=2048).reshape(128,2)
            code=unpack(blob[:2048],4096).reshape(32,128)
            assert np.array_equal(fields[:,0],low.astype('<f2'))
            assert np.array_equal(fields[:,1],step.astype('<f2'))
            assert np.array_equal(code,np.where(step>0,np.rint((source-low)/np.where(step>0,step,1)).clip(0,15),0))
            kq.append(blob);kr=[]
            assert frozen[frozen_at:frozen_at+3]==b'K'+t.to_bytes(2,'little')
            frozen_at+=3+2560
        if len(vr)>32:
            assert log[cursor:cursor+3]==b'V'+t.to_bytes(2,'little')
            assert frozen[frozen_at:frozen_at+3+80]==log[cursor:cursor+3+80]
            vq.append(log[cursor+3:cursor+3+80]);cursor+=3+80;frozen_at+=3+80;vr.pop(0)
    assert cursor==len(log) and frozen_at==len(frozen)
    assert b''.join(kq+vq+kr+vr)==image and peak==report['preflush_peak_bytes']==52400
    results={'replayed_all_prefixes':256,'verified_preflush_sha256':256,
             'verified_key_flushes':8,'original_value_flush_bytes_verified':224,
             'final_image_sha256':sha(image),'peak_bytes':peak,'head_kl':[],'head_post_o_sse':[]}
    outputs=[];refs=[]
    for h in range(2):
        predicted=torch.stack(pred[h]);target_logp,reference,_=src['teacher'][h]
        all_scores=torch.full((256,256),-1e9)
        for t,s in enumerate(scores[h]):all_scores[t,:t+1]=s
        kl=float((target_logp.exp()*(target_logp-all_scores.log_softmax(-1))).sum(-1).mean())
        sse=float((reference-predicted).square().sum())
        assert abs(kl-report['heads'][f'head{h}']['attention_kl'])<1e-7
        assert abs(sse-report['heads'][f'head{h}']['post_o_sse'])<1e-6
        results['head_kl'].append(kl);results['head_post_o_sse'].append(sse)
        outputs.append(predicted);refs.append(reference)
    results['pair_post_o_rel_sq']=float((sum(refs)-sum(outputs)).square().sum()/sum(refs).square().sum())
    assert abs(results['pair_post_o_rel_sq']-report['gqa_pair']['post_o_rel_sq'])<1e-8
    (HERE/f'{panel}-{window}-replay.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results,indent=2))

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
