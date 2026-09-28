"""Independent chronological event reader and exhaustive-grid sweep checker."""
from pathlib import Path
import hashlib
import json
import math
import sys
import numpy as np
import torch
from program import HERE,OWNER,arrays,bf,decode,unpack,metric,sha


def check_key(candidate,original,source,U,D):
    assert len(candidate)==len(original)==2560 and candidate[2048:]==original[2048:]
    stored=unpack(candidate[:2048],4096).reshape(32,128)
    start=unpack(original[:2048],4096).reshape(32,128)
    fields=np.frombuffer(original,dtype='<f2',count=256,offset=2048).astype(np.float64).reshape(128,2)
    lo=source.min(0);step=(source.max(0)-lo)/15
    assert np.array_equal(fields[:,0],lo.astype('<f2')) and np.array_equal(fields[:,1],step.astype('<f2'))
    assert np.array_equal(start,np.where(step>0,np.rint((source-lo)/np.where(step>0,step,1)).clip(0,15),0))
    e=fields[None,:,0]+start*fields[None,:,1]-source
    s=e@U
    original_objective=float(np.sum(e*e*D[None,:])+np.sum(s*s))
    nchanged=0
    # This oracle considers *all 16* actual grid points rather than the
    # encoder's closed-form rounded real optimum. Ties use nearest-even from
    # the encoder only if objective values coincide at machine precision.
    alphabet=np.arange(16,dtype=np.float64)[None,:]
    for d in range(128):
        a=D[d]+np.dot(U[d],U[d]);gradient=D[d]*e[:,d]+s@U[d]
        delta=(alphabet-start[:,d,None])*fields[d,1]
        increment=2*delta*gradient[:,None]+delta*delta*a
        chosen=np.argmin(increment,axis=1)
        # Zero step means no change; nonzero exact ties nearest even index.
        ties=np.abs(increment-increment[np.arange(32),chosen,None])<1e-13
        if fields[d,1]==0:chosen=start[:,d].copy()
        elif np.any(ties.sum(1)>1):
            tie_idx=np.where(ties.sum(1)>1)[0]
            for row in tie_idx:
                preferred=np.rint(start[row,d]-gradient[row]/(fields[d,1]*a)).clip(0,15).astype(int)
                if ties[row,preferred]:chosen[row]=preferred
        assert np.array_equal(stored[:,d],chosen)
        shift=(chosen-start[:,d])*fields[d,1]
        e[:,d]+=shift;s+=shift[:,None]*U[d][None,:]
        nchanged+=np.count_nonzero(shift)
        start[:,d]=chosen
    final_error=fields[None,:,0]+stored*fields[None,:,1]-source
    new_objective=float(np.sum(final_error*final_error*D[None,:])+np.sum(np.square(final_error@U)))
    assert new_objective<=original_objective+1e-8*max(1,original_objective)
    return nchanged,original_objective,new_objective


def run(panel,window):
    U,D=metric();src=arrays(panel,window)
    report=json.loads((HERE/f'{panel}-{window}.json').read_text())
    manifest=json.loads((OWNER/f'{panel}-{window}-manifest.json').read_text())
    receipts=json.loads((HERE/f'{panel}-{window}-prefixes.json').read_text())
    own=(OWNER/f'{panel}-{window}-flush.bin').read_bytes()
    log=(HERE/f'{panel}-{window}-flush.bin').read_bytes()
    image=(HERE/f'{panel}-{window}-final.bin').read_bytes()
    assert sha(log)==report['flush_log_sha256'] and sha(image)==report['final_sha256']
    assert sha(own)==manifest['flush_log_sha256']
    kq=[];vq=[];kr=[];vr=[];cur=0;prior=0;head_scores=[[],[]];head_output=[[],[]];peak=0
    changes=[]
    for t in range(1,257):
        kr.append(src['key'][t-1].astype('<u2').tobytes());vr.append(src['value'][t-1].astype('<u2').tobytes())
        state=b''.join(kq+vq+kr+vr)
        assert len(state)==receipts[t-1]['preflush_bytes'] and sha(state)==receipts[t-1]['preflush_sha256']
        assert len(state)==manifest['prefixes'][t-1]['before_flush']['live_state_bytes']
        peak=max(peak,len(state))
        k,v=decode(kq,vq,kr,vr);kt=torch.from_numpy(k.copy());vt=torch.from_numpy(v.copy())
        for h in range(2):
            score=src['qrot'][h][t-1]@kt.T/math.sqrt(128)
            out=(score.softmax(-1)@vt)@src['o'][:,h*128:(h+1)*128].T
            head_scores[h].append(score);head_output[h].append(out)
        if len(kr)==32:
            assert log[cur:cur+3]==own[prior:prior+3]==b'K'+t.to_bytes(2,'little')
            new=log[cur+3:cur+3+2560];original=own[prior+3:prior+3+2560]
            data=bf(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128))
            changes.append(check_key(new,original,data,U,D))
            assert sha(new)==report['key_flushes'][len(changes)-1]['candidate_event_sha256']
            assert sha(original)==report['key_flushes'][len(changes)-1]['source_event_sha256']
            assert changes[-1][0]==report['key_flushes'][len(changes)-1]['changed_digits']
            kq.append(new);kr=[];cur+=2563;prior+=2563
        if len(vr)>32:
            assert log[cur:cur+83]==own[prior:prior+83]
            assert log[cur:cur+3]==b'V'+t.to_bytes(2,'little')
            vq.append(log[cur+3:cur+83]);vr.pop(0);cur+=83;prior+=83
        assert len(b''.join(kq+vq+kr+vr))==manifest['prefixes'][t-1]['after_flush']['live_state_bytes']
    assert cur==len(log) and prior==len(own) and b''.join(kq+vq+kr+vr)==image
    assert peak==52400 and len(changes)==8 and sum(c[0] for c in changes)==report['changed_key_digits']
    outputs=[];refs=[];kl=[];head_sse=[]
    for h in range(2):
        out=torch.stack(head_output[h]);logits=torch.full((256,256),-1e9)
        for t,s in enumerate(head_scores[h]):logits[t,:t+1]=s
        ref_logp,ref,_=src['teacher'][h]
        score_kl=float((ref_logp.exp()*(ref_logp-logits.log_softmax(-1))).sum(-1).mean())
        sse=float((ref-out).square().sum())
        assert abs(score_kl-report['heads'][f'head{h}']['attention_kl'])<1e-7
        assert abs(sse-report['heads'][f'head{h}']['post_o_sse'])<1e-6
        kl.append(score_kl);head_sse.append(sse);outputs.append(out);refs.append(ref)
    pair_sse=float((sum(refs)-sum(outputs)).square().sum())
    assert abs(pair_sse-report['gqa_pair']['post_o_sse'])<1e-6
    result={'panel':panel,'window':window,'verified_causal_prefixes':256,'verified_k_flushes':8,
            'verified_identical_v_flushes':224,'verified_changed_digits':int(sum(c[0] for c in changes)),
            'all_key_chunk_metric_nonincreasing':all(after<=before+1e-8*max(1,before) for _,before,after in changes),
            'final_sha256':sha(image),'peak_state_plus_metric_bytes':peak+2304,
            'head_kl':kl,'head_post_o_sse':head_sse,'pair_post_o_sse':pair_sse}
    (HERE/f'{panel}-{window}-replay.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'pair_post_o_sse':pair_sse,'changed_digits':result['verified_changed_digits']}))

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
