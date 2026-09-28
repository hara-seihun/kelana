"""Whole two-head KIVI query from packed codes, without a decoded cache matrix."""
from pathlib import Path
import hashlib
import json
import math
import sys
import numpy as np
import torch

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'kivi-causal-cache'))
from source import arrays,FIX_SHA
from replay import decode as conventional_decode,bf16 as bf16_values


def codes(blob,count):
    data=np.frombuffer(blob,dtype='u1')
    assert len(data)*2==count
    result=np.empty(count,dtype=np.float64)
    result[::2]=data&15;result[1::2]=data>>4
    return result


def packed_scores(blob,quant_keys,recent_keys,q):
    """For each quant chunk c, B[h,c]=Σ_d q[h,d]*origin[c,d];
    A[h,c,d]=q[h,d]*step[c,d]; output score=B+Σ_d A*digit.
    Chunk bias must remain: only a *common* query-row score bias cancels softmax.
    """
    assert quant_keys%32==0 and q.shape==(2,128)
    result=np.empty((2,quant_keys+len(recent_keys)),dtype=np.float64)
    q64=q.astype(np.float64)
    for chunk in range(quant_keys//32):
        part=blob[chunk*2560:(chunk+1)*2560]
        digit=codes(part[:2048],4096).reshape(32,128)
        fields=np.frombuffer(part,dtype='<f2',offset=2048,count=256).astype(np.float64).reshape(128,2)
        origin=fields[:,0];step=fields[:,1]
        A=q64*step[None,:]
        B=np.sum(q64*origin[None,:],axis=1)
        result[:,chunk*32:(chunk+1)*32]=(digit@A.T).T+B[:,None]
    if len(recent_keys):
        result[:,quant_keys:]=q64@bf16_values(np.asarray(recent_keys,dtype='<u2')).astype(np.float64).T
    return result/math.sqrt(128)


def packed_value(blob,quant_keys,quant_values,recent_values,probs):
    """For each 32D group: bias[h,g]=Σ_token p[h,t]*origin[t,g],
    factor[h,t,g]=p[h,t]*step[t,g]; then Σ_t factor*digit[t,d].
    Quantized and recent values share the original probability normalization.
    """
    assert probs.shape==(2,quant_values+len(recent_values))
    off=quant_keys//32*2560
    digit=np.empty((quant_values,128),dtype=np.float64)
    fields=np.empty((quant_values,4,2),dtype=np.float64)
    for t in range(quant_values):
        part=blob[off+t*80:off+(t+1)*80]
        digit[t]=codes(part[:64],128)
        fields[t]=np.frombuffer(part,dtype='<f2',offset=64,count=8).astype(np.float64).reshape(4,2)
    result=np.zeros((2,128),dtype=np.float64)
    p=probs[:,:quant_values]
    for g in range(4):
        bias=p@fields[:,g,0]
        factor=p*fields[None,:,g,1]
        result[:,g*32:(g+1)*32]=bias[:,None]+factor@digit[:,g*32:(g+1)*32]
    if len(recent_values):
        result+=probs[:,quant_values:]@bf16_values(np.asarray(recent_values,dtype='<u2')).astype(np.float64)
    return result


def run(panel,window):
    torch.set_num_threads(1)
    src=arrays(panel,window)
    owner=ROOT/'kivi-causal-cache'
    m=json.loads((owner/f'{panel}-{window}-manifest.json').read_text())
    event_data=(owner/f'{panel}-{window}-flush.bin').read_bytes()
    assert hashlib.sha256(event_data).hexdigest()==m['flush_log_sha256']
    kq=[];vq=[];kr=[];vr=[];pos=0
    maxima={'scores_abs':0.,'values_abs':0.,'post_o_abs':0.,'teacher_scores_abs':0.}
    # Full causal KL/O are recomputed for both implementations, not inferred
    # from a single endpoint; the replay's published loss is another control.
    packed_o=[[],[]];packed_logits=[[],[]];ordinary_o=[[],[]]
    with torch.no_grad():
        for i in range(256):
            t=i+1
            kr.append(src['key'][i].astype('<u2').tobytes())
            vr.append(src['value'][i].astype('<u2').tobytes())
            state=b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)
            receipt=m['prefixes'][i]['before_flush']
            assert hashlib.sha256(state).hexdigest()==receipt['sha256']
            nk=receipt['key_quant_tokens'];nv=receipt['value_quant_tokens']
            assert nk+len(kr)==nv+len(vr)==t
            rk=np.frombuffer(b''.join(kr),dtype='<u2').reshape(-1,128)
            rv=np.frombuffer(b''.join(vr),dtype='<u2').reshape(-1,128)
            q=np.stack([src['qrot'][h][i].numpy() for h in range(2)])
            direct=packed_scores(state,nk,rk,q)
            original_k,original_v=conventional_decode(state,nk,nv,len(kr),len(vr))
            qtorch=torch.from_numpy(q)
            old=qtorch@torch.from_numpy(original_k).T/math.sqrt(128)
            maxima['scores_abs']=max(maxima['scores_abs'],float(np.max(abs(direct-old.numpy()))))
            maxima['teacher_scores_abs']=max(maxima['teacher_scores_abs'],float((qtorch@src['krot'][:t].T/math.sqrt(128)-torch.stack([src['teacher'][h][2][i,:t] for h in range(2)])).abs().max()))
            pd=torch.softmax(torch.from_numpy(direct.astype(np.float32)),dim=-1).numpy().astype(np.float64)
            po=torch.softmax(old,dim=-1)
            direct_v=packed_value(state,nk,nv,rv,pd)
            old_v=po@torch.from_numpy(original_v)
            maxima['values_abs']=max(maxima['values_abs'],float(np.max(abs(direct_v-old_v.numpy()))))
            for h in range(2):
                o=src['o'][:,h*128:(h+1)*128]
                yd=torch.from_numpy(direct_v[h].astype(np.float32))@o.T
                yo=old_v[h]@o.T
                maxima['post_o_abs']=max(maxima['post_o_abs'],float((yd-yo).abs().max()))
                packed_o[h].append(yd);ordinary_o[h].append(yo)
                packed_logits[h].append(torch.from_numpy(direct[h].astype(np.float32)))
            if len(kr)==32:
                assert event_data[pos:pos+1]==b'K' and int.from_bytes(event_data[pos+1:pos+3],'little')==t
                kq.append(event_data[pos+3:pos+3+2560]);pos+=2563;kr=[]
            if len(vr)>32:
                assert event_data[pos:pos+1]==b'V' and int.from_bytes(event_data[pos+1:pos+3],'little')==t
                vq.append(event_data[pos+3:pos+3+80]);pos+=83;vr.pop(0)
    assert pos==len(event_data)
    assert b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)==(owner/f'{panel}-{window}-final.bin').read_bytes()
    result={'panel':panel,'window':window,'manifest_sha256':hashlib.sha256((owner/f'{panel}-{window}-manifest.json').read_bytes()).hexdigest(),
            'final_image_sha256':m['final_sha256'],'maxima_vs_conventional':maxima,'heads':{},'gqa_pair':{}}
    r=[];c=[];z=[]
    for h in range(2):
        reference=src['teacher'][h][1]
        candidate=torch.stack(packed_o[h]);ordinary=torch.stack(ordinary_o[h])
        ll=torch.full((256,256),-1e9)
        for j,l in enumerate(packed_logits[h]):ll[j,:j+1]=l
        ref_logp=src['teacher'][h][0]
        result['heads'][f'head{h}']={'attention_kl':float((ref_logp.exp()*(ref_logp-ll.log_softmax(-1))).sum(-1).mean()),
            'post_o_sse':float((reference-candidate).square().sum()),'post_o_ref_sq':float(reference.square().sum()),
            'ordinary_post_o_sse':float((reference-ordinary).square().sum())}
        r.append(reference);c.append(candidate);z.append(ordinary)
    result['gqa_pair']={'post_o_sse':float((sum(r)-sum(c)).square().sum()),
        'ordinary_post_o_sse':float((sum(r)-sum(z)).square().sum()),'post_o_ref_sq':float(sum(r).square().sum())}
    path=HERE/f'{panel}-{window}.json';path.write_text(json.dumps(result,indent=2)+'\n')
    print(panel,window,'max_scores',maxima['scores_abs'],'max_O',maxima['post_o_abs'],
          'pair_rel',result['gqa_pair']['post_o_sse']/result['gqa_pair']['post_o_ref_sq'])

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
