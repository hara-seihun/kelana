"""Independent prefix reader: parses composed image/events, source V grids, full Q/K/softmax/V/O."""
from pathlib import Path
import hashlib
import json
import math
import sys
import numpy as np
import torch

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FOLD=ROOT/'kivi-v-channel-fold'
METRIC=ROOT/'kivi-response-metric'
ORIGINAL=ROOT/'kivi-causal-cache'
sys.path.insert(0,str(FOLD))
from source import arrays


def sha(data):return hashlib.sha256(data).hexdigest()

def bf(bits):return (np.asarray(bits,dtype=np.uint32)<<16).view(np.float32)

def nibbles(b,n):
    a=np.frombuffer(b,dtype=np.uint8);assert len(a)*2==n
    return np.stack((a&15,a>>4),axis=1).reshape(n).astype(np.float32)

def decode(kq,vq,kr,vr):
    k=[];v=[]
    for blob in kq:
        c=nibbles(blob[:2048],4096).reshape(32,128)
        f=np.frombuffer(blob,dtype='<f2',count=256,offset=2048).astype(np.float32).reshape(128,2)
        assert np.isfinite(f).all() and np.all(f[:,1]>=0)
        k.append(c*f[None,:,1]+f[None,:,0])
    for blob in vq:
        c=nibbles(blob[:64],128).reshape(4,32)
        f=np.frombuffer(blob,dtype='<f2',count=8,offset=64).astype(np.float32).reshape(4,2)
        assert np.isfinite(f).all() and np.all(f[:,1]>=0)
        v.append((c*f[:,1,None]+f[:,0,None]).reshape(1,128))
    k.append(bf(np.frombuffer(b''.join(kr),dtype='<u2').reshape(len(kr),128)))
    v.append(bf(np.frombuffer(b''.join(vr),dtype='<u2').reshape(len(vr),128)))
    return np.concatenate(k),np.concatenate(v)

def load_donor(log,expected_sha):
    data=log.read_bytes();assert sha(data)==expected_sha
    k={};v={};at=0
    while at<len(data):
        kind=data[at:at+1];t=int.from_bytes(data[at+1:at+3],'little')
        size=2560 if kind==b'K' else 80
        assert kind in (b'K',b'V')
        p=data[at+3:at+3+size];assert len(p)==size
        target=k if kind==b'K' else v
        assert t not in target;target[t]=p
        at+=3+size
    assert len(k)==8 and len(v)==224
    return k,v

def check_v(event,source):
    x=bf(source).reshape(4,32)
    minimum=x.min(axis=1);step=(x.max(axis=1)-minimum)/15
    stored=np.frombuffer(event,dtype='<f2',count=8,offset=64).reshape(4,2)
    code=nibbles(event[:64],128).reshape(4,32)
    assert np.array_equal(stored[:,0],minimum.astype('<f2'))
    assert np.array_equal(stored[:,1],step.astype('<f2'))
    expected=np.where(step[:,None]>0,np.rint((x-minimum[:,None])/np.where(step[:,None]>0,step[:,None],1)).clip(0,15),0)
    assert np.array_equal(code,expected)

def replay(panel,window):
    src=arrays(panel,window)
    fold_result=json.loads((FOLD/f'{panel}-{window}-result.json').read_text())
    metric_result=json.loads((METRIC/f'{panel}-{window}.json').read_text())
    original_result=json.loads((ORIGINAL/f'{panel}-{window}-result.json').read_text())
    source_image=json.loads((FOLD/'source-image.json').read_text())
    results={}
    for arm in ('A','B'):
        receipt=json.loads((HERE/f'{panel}-{window}-{arm}-manifest.json').read_text())
        prefix=json.loads((HERE/f'{panel}-{window}-{arm}-prefixes.json').read_text())
        source=receipt['donors']
        assert len(prefix)==256 and receipt['panel']==panel and receipt['window']==window
        assert sha((FOLD/'v-replacement.bf16').read_bytes())==source['folded_v_source_sha256']==source_image['v_sha256']
        assert sha((FOLD/'o-replacement.bf16').read_bytes())==source['folded_o_source_sha256']==source_image['o_sha256']
        assert sha((METRIC/'metric-fp16.bin').read_bytes())==source['metric_image_sha256']
        assert fold_result['final_image_sha256']==source['folded_final_sha256']
        assert metric_result['final_sha256']==source['metric_k_original_v_final_sha256']
        assert original_result['flush_log_sha256']==source['original_kivi_log_sha256']
        fk,fv=load_donor(FOLD/f'{panel}-{window}-flush.bin',source['folded_log_sha256'])
        mk,_=load_donor(METRIC/f'{panel}-{window}-flush.bin',source['metric_k_original_v_log_sha256'])
        key_donor=mk if arm=='A' else fk
        residual=32 if arm=='A' else 45
        log=(HERE/f'{panel}-{window}-{arm}-flush.bin').read_bytes()
        image=(HERE/f'{panel}-{window}-{arm}-final.bin').read_bytes()
        assert sha(log)==receipt['flush_log_sha256'] and sha(image)==receipt['final_sha256']
        kq=[];vq=[];kr=[];vr=[];cursor=0;peak=0;out=[[],[]];scores=[[],[]];verified_key=verified_value=0
        for t in range(1,257):
            kr.append(src['key'][t-1].astype('<u2').tobytes())
            vr.append(src['value'][t-1].astype('<u2').tobytes())
            state=b''.join(kq+vq+kr+vr)
            saved=prefix[t-1]
            assert saved=={'position':t-1,'preflush_sha256':sha(state),'preflush_bytes':len(state),
                           'quant_k':len(kq)*32,'recent_k':len(kr),'quant_v':len(vq),'recent_v':len(vr)}
            assert len(kq)*32+len(kr)==len(vq)+len(vr)==t
            peak=max(peak,len(state))
            keys,values=decode(kq,vq,kr,vr)
            kt=torch.from_numpy(keys.copy());vt=torch.from_numpy(values.copy())
            for h in range(2):
                score=src['qrot'][h][t-1]@kt.T/math.sqrt(128)
                product=(score.softmax(-1)@vt)@src['o'][:,h*128:(h+1)*128].T
                out[h].append(product);scores[h].append(score)
            if len(kr)==32:
                assert log[cursor:cursor+3]==b'K'+t.to_bytes(2,'little')
                p=log[cursor+3:cursor+3+2560];assert p==key_donor[t]
                if arm=='A':assert p[2048:]==fk[t][2048:]
                kq.append(p);kr=[];cursor+=2563;verified_key+=1
            if len(vr)>residual:
                token=t-residual-1
                assert token==len(vq)
                assert log[cursor:cursor+3]==b'V'+t.to_bytes(2,'little')
                p=log[cursor+3:cursor+3+80]
                assert p==fv[token+33]
                check_v(p,src['value'][token])
                vq.append(p);vr.pop(0);cursor+=83;verified_value+=1
        assert cursor==len(log) and image==b''.join(kq+vq+kr+vr)
        assert verified_key==receipt['k_events']==8 and verified_value==receipt['v_events']
        assert peak==receipt['state_peak_bytes']
        head={};groups=[];targets=[];max_teacher_score=0.
        for h in range(2):
            predicted=torch.stack(out[h]);ref_logp,refout,teacher_scores=src['teacher'][h]
            masked=torch.full((256,256),-1e9,dtype=torch.float32)
            for j,s in enumerate(scores[h]):masked[j,:j+1]=s
            logp=masked.log_softmax(-1)
            sse=float((refout-predicted).square().sum())
            kl=float((ref_logp.exp()*(ref_logp-logp)).sum(-1).mean())
            head[f'head{h}']={'attention_kl':kl,'post_o_sse':sse,'post_o_ref_sq':float(refout.square().sum())}
            groups.append(predicted);targets.append(refout)
            # The non-cache source teacher score check is shared by arms.
            for j in (0,31,127,255):
                truth=(src['qrot'][h][j]@src['krot'][:j+1].T)/math.sqrt(128)
                max_teacher_score=max(max_teacher_score,float((truth-teacher_scores[j,:j+1]).abs().max()))
        assert max_teacher_score<1e-4
        target=sum(targets);prediction=sum(groups)
        pair={'post_o_sse':float((target-prediction).square().sum()),'post_o_ref_sq':float(target.square().sum())}
        pair['post_o_rel_sq']=pair['post_o_sse']/pair['post_o_ref_sq']
        results[arm]={'panel':panel,'window':window,'arm':arm,'manifest_sha256':sha((HERE/f'{panel}-{window}-{arm}-manifest.json').read_bytes()),
                      'final_sha256':sha(image),'flush_log_sha256':sha(log),
                      'verified_preflush_hashes':256,'verified_identical_key_donor_events':verified_key,
                      'verified_identical_folded_value_donor_events':verified_value,
                      'verified_folded_value_source_grids':verified_value,
                      'complete_peak_bytes':receipt['complete_peak_bytes'],
                      'original_teacher_score_max_abs':max_teacher_score,
                      'heads':head,'gqa_pair':pair,
                      'folded_v32_control_pair_post_o_sse':fold_result['gqa_pair']['post_o_sse'],
                      'metric_k_original_v32_control_pair_post_o_sse':metric_result['gqa_pair']['post_o_sse'],
                      'original_kivi_control_pair_post_o_sse':original_result['gqa_pair']['post_o_sse']}
        (HERE/f'{panel}-{window}-{arm}-result.json').write_text(json.dumps(results[arm],indent=2)+'\n')
    assert results['A']['heads']['head0']['attention_kl']==metric_result['heads']['head0']['attention_kl']
    assert results['A']['heads']['head1']['attention_kl']==metric_result['heads']['head1']['attention_kl']
    for h in range(2):
        assert results['B']['heads'][f'head{h}']['attention_kl']==fold_result['heads'][f'head{h}']['attention_kl']
    print(json.dumps({'panel':panel,'window':window,'pair':{a:r['gqa_pair']['post_o_rel_sq'] for a,r in results.items()},
                      'head_kl':{a:[r['heads'][f'head{h}']['attention_kl'] for h in range(2)] for a,r in results.items()}}))

if __name__=='__main__':replay(sys.argv[1],int(sys.argv[2]))
