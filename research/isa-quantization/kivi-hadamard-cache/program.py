"""Fixed orthonormal Q/K cache gauge, causal encoder and independent packed reader.

No train-derived parameters, no candidate selection and no use of future tokens at a query.
The original KIVI V flush bytes are retained verbatim, at their original causal time.
"""
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

N=128
K_BYTES=2560
V_BYTES=80


def sha(data):return hashlib.sha256(data).hexdigest()


def bf(bits):return (np.asarray(bits,dtype=np.uint32)<<16).view(np.float32)


def bits(a):return torch.from_numpy(np.asarray(a,dtype=np.float32).copy()).to(torch.bfloat16).view(torch.uint16).numpy().copy()


def transform(x):
    """Fixed Sylvester H_128/sqrt(128); same program for Q and K."""
    y=np.asarray(x,dtype=np.float32).copy()
    assert y.shape[-1]==128
    for stride in (1,2,4,8,16,32,64):
        z=y.reshape(*y.shape[:-1],-1,2,stride)
        lo=z[... ,0,:].copy();hi=z[...,1,:].copy()
        z[...,0,:]=lo+hi;z[...,1,:]=lo-hi
    return y*np.float32(1/math.sqrt(128))


def pack_nibbles(c):
    x=np.asarray(c,dtype=np.uint8).ravel();assert x.size%2==0 and np.max(x)<16
    return (x[::2]|(x[1::2]<<4)).tobytes()


def quantized_key(source32):
    assert source32.shape==(32,128)
    low=source32.min(axis=0);high=source32.max(axis=0);step=(high-low)/15
    safe=np.where(step>0,step,1)
    code=np.where(step>0,np.clip(np.rint((source32-low)/safe),0,15),0).astype(np.uint8)
    fields=np.stack([low,step],axis=-1).astype('<f2')
    assert np.isfinite(fields).all() and np.all(fields[:,1]>=0)
    return pack_nibbles(code)+fields.tobytes()


def unpack(blob,count):
    a=np.frombuffer(blob,dtype=np.uint8);assert len(a)*2==count
    return np.stack([a&15,a>>4],axis=1).reshape(count).astype(np.float32)


def decode_state(kq,vq,kr,vr):
    k=[];v=[]
    for b in kq:
        codes=unpack(b[:2048],4096).reshape(32,128)
        fields=np.frombuffer(b,dtype='<f2',count=256,offset=2048).astype(np.float32).reshape(128,2)
        k.append(fields[None,:,0]+codes*fields[None,:,1])
    for b in vq:
        codes=unpack(b[:64],128).reshape(4,32)
        fields=np.frombuffer(b,dtype='<f2',count=8,offset=64).astype(np.float32).reshape(4,2)
        v.append((fields[:,0,None]+codes*fields[:,1,None]).reshape(1,128))
    k.append(bf(np.frombuffer(b''.join(kr),dtype='<u2').reshape(len(kr),128)))
    v.append(bf(np.frombuffer(b''.join(vr),dtype='<u2').reshape(len(vr),128)))
    return np.concatenate(k),np.concatenate(v)


def run(panel,window,write_artifacts=True):
    src=arrays(panel,window)
    control=json.loads((OWNER/f'{panel}-{window}-result.json').read_text())
    manifest=json.loads((OWNER/f'{panel}-{window}-manifest.json').read_text())
    frozen_log=(OWNER/f'{panel}-{window}-flush.bin').read_bytes()
    assert sha(frozen_log)==manifest['flush_log_sha256']
    # Source KIVI first BF16-rounds rotary K; our rotation follows exactly
    # that source boundary, then rounds the transformed vector to recent BF16.
    transformed_k=bits(transform(bf(src['key'])))
    q=[transform(head.numpy()) for head in src['qrot']]
    # Arithmetic-only invariant for the unquantized source boundary.
    max_invariance=0.
    for h in range(2):
        original=src['qrot'][h].numpy()@bf(src['key']).T
        gauged=q[h]@transform(bf(src['key'])).T
        max_invariance=max(max_invariance,float(abs(original-gauged).max()))
    # These two unquantized full-window controls are diagnostic scratch only:
    # (a) original FP32 rotary K transformed in FP32, (b) source K rounded
    # to BF16, transformed, rounded to recent-cache BF16, with no 4bit flush.
    # Both retain the unchanged source BF16 V and complete original O.
    unquantized=[]
    for h in range(2):
        head_controls={}
        for name,whole_key in (('fp32_orthogonal',transform(src['krot'].numpy())),
                               ('bf16_recent_orthogonal',bf(transformed_k))):
            score=(torch.from_numpy(q[h].copy())@torch.from_numpy(whole_key.copy()).T)/math.sqrt(128)
            causal=torch.triu(torch.ones((256,256),dtype=torch.bool),diagonal=1)
            score=score.masked_fill(causal,-1e9)
            prob=score.softmax(-1)
            output=(prob@src['vraw'])@src['o'][:,h*128:(h+1)*128].T
            ref_logp,ref_output,_=src['teacher'][h]
            logp=score.log_softmax(-1)
            head_controls[name]={'attention_kl':float((ref_logp.exp()*(ref_logp-logp)).sum(-1).mean()),
                                 'post_o_sse':float((ref_output-output).square().sum()),
                                 'max_causal_score_abs':float((score.masked_fill(causal,0)-src['teacher'][h][2].masked_fill(causal,0)).abs().max())}
        unquantized.append(head_controls)
    kq=[];vq=[];kr=[];vr=[];log=bytearray();frozen_pos=0;receipts=[];peak=0
    outputs=[[],[]];logits=[[],[]]
    key_quant_sse=0.;key_quant_ref_sq=0.;max_source_score=0.
    for t in range(1,257):
        kr.append(transformed_k[t-1].astype('<u2').tobytes())
        vr.append(src['value'][t-1].astype('<u2').tobytes())
        image=b''.join(kq+vq+kr+vr)
        orig=manifest['prefixes'][t-1]['before_flush']
        assert len(image)==orig['live_state_bytes']
        peak=max(peak,len(image));receipts.append({'position':t-1,'before_flush_sha256':sha(image),'before_flush_bytes':len(image)})
        keys,values=decode_state(kq,vq,kr,vr)
        key_truth=transform(bf(src['key'][:t]))
        key_quant_sse+=float(np.square(keys-key_truth,dtype=np.float64).sum())
        key_quant_ref_sq+=float(np.square(key_truth,dtype=np.float64).sum())
        kt=torch.from_numpy(keys.copy());vt=torch.from_numpy(values.copy())
        for h in range(2):
            query=torch.from_numpy(q[h][t-1].copy())
            score=(query@kt.T)/math.sqrt(128)
            prob=score.softmax(-1)
            out=(prob@vt)@src['o'][:,h*128:(h+1)*128].T
            outputs[h].append(out);logits[h].append(score)
            score_ref=src['qrot'][h][t-1]@src['krot'][:t].T/math.sqrt(128)
            max_source_score=max(max_source_score,float((score_ref-src['teacher'][h][2][t-1,:t]).abs().max()))
        if len(kr)==32:
            block=bf(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128))
            event=quantized_key(block)
            assert len(event)==K_BYTES
            # A reference check independently parses codes and paid FP16 fields.
            c=unpack(event[:2048],4096).reshape(32,128)
            f=np.frombuffer(event[2048:],dtype='<f2').reshape(128,2)
            lo=block.min(0);step=(block.max(0)-lo)/15
            assert np.array_equal(f[:,0],lo.astype('<f2')) and np.array_equal(f[:,1],step.astype('<f2'))
            assert np.array_equal(c,np.where(step>0,np.rint((block-lo)/np.where(step>0,step,1)).clip(0,15),0))
            kq.append(event);kr=[];log+=b'K'+t.to_bytes(2,'little')+event
            assert frozen_log[frozen_pos:frozen_pos+3]==b'K'+t.to_bytes(2,'little')
            frozen_pos+=3+K_BYTES
        if len(vr)>32:
            assert frozen_log[frozen_pos:frozen_pos+3]==b'V'+t.to_bytes(2,'little')
            event=frozen_log[frozen_pos+3:frozen_pos+3+V_BYTES]
            assert len(event)==V_BYTES
            frozen_pos+=3+V_BYTES
            vq.append(event);vr.pop(0)
            log+=b'V'+t.to_bytes(2,'little')+event
        # Original V fields are byte-identical; the cache layout and schedule
        # cannot silently profit from a different buffer length.
        assert len(b''.join(kq+vq+kr+vr))==manifest['prefixes'][t-1]['after_flush']['live_state_bytes']
    assert frozen_pos==len(frozen_log) and peak==52400
    result={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,
            'method':'fixed Sylvester H128 Q/K post-RoPE gauge, frozen KIVI V and 4bit G32 R32',
            'preflush_peak_bytes':peak,'postflush_final_bytes':len(b''.join(kq+vq+kr+vr)),
            'final_image_sha256':sha(b''.join(kq+vq+kr+vr)),'flush_log_sha256':sha(log),
            'frozen_original_kivi_final_sha256':manifest['final_sha256'],
            'source_unrounded_rotation_score_max_abs':max_invariance/math.sqrt(128),
            'uncompressed_online_vs_teacher_max_score_abs':max_source_score,
            'key_coordinate_prefix_weighted_rel_sq':key_quant_sse/key_quant_ref_sq,
            'unquantized_transform_controls':unquantized,
            'gqa_pair':{},'heads':{}}
    teacher=src['teacher'];changed=[];reference=[]
    for h in range(2):
        pred=torch.stack(outputs[h]); ref_logp,ref_out,_=teacher[h]
        all_scores=torch.full((256,256),-1e9)
        for t,score in enumerate(logits[h]):all_scores[t,:t+1]=score
        logp=all_scores.log_softmax(-1)
        difference=ref_out-pred
        result['heads'][f'head{h}']={'attention_kl':float((ref_logp.exp()*(ref_logp-logp)).sum(-1).mean()),
                                  'post_o_sse':float(difference.square().sum()),'post_o_ref_sq':float(ref_out.square().sum()),
                                  'control_attention_kl':control['heads'][f'head{h}']['attention_kl']}
        changed.append(pred);reference.append(ref_out)
    pair=sum(reference);candidate=sum(changed)
    result['gqa_pair']={'post_o_sse':float((pair-candidate).square().sum()),
                        'post_o_ref_sq':float(pair.square().sum()),
                        'control_post_o_sse':control['gqa_pair']['post_o_sse'],
                        'control_post_o_ref_sq':control['gqa_pair']['post_o_ref_sq']}
    result['gqa_pair']['post_o_rel_sq']=result['gqa_pair']['post_o_sse']/result['gqa_pair']['post_o_ref_sq']
    result['gqa_pair']['control_post_o_rel_sq']=result['gqa_pair']['control_post_o_sse']/result['gqa_pair']['control_post_o_ref_sq']
    if write_artifacts:
        (HERE/f'{panel}-{window}.json').write_text(json.dumps(result,indent=2)+'\n')
        (HERE/f'{panel}-{window}-final.bin').write_bytes(b''.join(kq+vq+kr+vr))
        (HERE/f'{panel}-{window}-flush.bin').write_bytes(log)
        (HERE/f'{panel}-{window}-prefixes.json').write_text(json.dumps(receipts)+'\n')
    print(json.dumps({'panel':panel,'window':window,'pair':result['gqa_pair']['post_o_rel_sq'],
                     'control':result['gqa_pair']['control_post_o_rel_sq'],
                     'kl':[result['heads'][f'head{h}']['attention_kl'] for h in range(2)],
                     'control_kl':[result['heads'][f'head{h}']['control_attention_kl'] for h in range(2)],
                     'peak':peak},indent=2))
    return result

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
