#!/usr/bin/env python3
"""Joint Q/K pre-RoPE coordinate search and paid causal GQA replay."""
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from observer import FIX, MODEL, Q4, compare, head, q4_decode, rope

HERE = Path(__file__).resolve().parent
ANGLES = np.array([0, -math.pi/8, math.pi/8, -math.pi/4, math.pi/4], np.float64)


def transform(gamma, angle):
    c, s = math.cos(angle), math.sin(angle)
    a, b = float(gamma[0]), float(gamma[1])
    return np.array([[c, -s*b/a], [s*a/b, c]], dtype=np.float64)


def grid(row, h):
    best = None
    for lo_percent, hi_percent in ((0,100),(1,99),(2,98),(3,97),(4,96),(5,95),(8,92)):
        lo,hi = np.percentile(row,(lo_percent,hi_percent))
        origin,step = lo,(hi-lo)/15
        for _ in range(5):
            codes = np.clip(np.rint((row-origin)/step),0,15)
            design = np.stack((np.ones(128),codes),axis=-1)
            hd = h @ design
            origin,step = np.linalg.solve(design.T @ hd, hd.T @ row)
            step = max(float(step),1e-8)
        origin,step = np.float16(origin).item(),np.float16(step).item()
        codes = np.clip(np.rint((row-origin)/step),0,15).astype(np.uint8)
        decoded = origin+step*codes
        delta = decoded-row
        loss = float(delta @ h @ delta)
        if best is None or loss < best[0]:
            best = (loss, decoded, codes, origin, step)
    return best


def fit(wq, qgamma, train, force_zero=False):
    h = np.zeros((128,128),np.float64)
    for x in train:
        panel=x[:,:128].astype(np.float64)
        h += panel.T @ panel
    choices=np.zeros(64,np.uint8)
    rows=np.zeros((128,128),np.float32)
    payload=[None]*128
    for pair in range(64):
        index=(pair,pair+64)
        source=wq[list(index),:128].astype(np.float64)
        options=[]
        for code,angle in enumerate(ANGLES[:1] if force_zero else ANGLES):
            t=transform(qgamma[list(index)],angle)
            target=t @ source
            fitted=[grid(target[j],h) for j in range(2)]
            recovered=np.linalg.solve(t,np.stack([f[1] for f in fitted]))
            error=recovered-source
            objective=float(sum(delta @ h @ delta for delta in error))
            options.append((objective,code,fitted))
        _,code,fitted=min(options,key=lambda x:x[0])
        choices[pair]=code
        for i,record in zip(index,fitted):
            _,rows[i],codes,origin,step=record
            payload[i]=(codes[0::2] | (codes[1::2]<<4)).tobytes()+np.asarray([origin,step],dtype='<f2').tobytes()
    image=b''.join(payload)+choices.tobytes()
    assert len(image)==8768
    if not force_zero:
        HERE.joinpath('q4-coordinate.bin').write_bytes(image)
    decoded=q4_decode(image[:8704])
    assert np.array_equal(rows,decoded)
    return decoded,choices,image


def full_transform(weights,gamma,choices):
    transformed=np.array(weights,dtype=np.float32,copy=True)
    for start in range(0,len(transformed),128):
        for pair,code in enumerate(choices):
            indices=[start+pair,start+pair+64]
            pair_indices=[pair,pair+64]
            transformed[indices]=(transform(gamma[pair_indices],ANGLES[code]) @ transformed[indices]).astype(np.float32)
    return transformed


def metric_norm(raw,gamma,choices):
    z=raw.to(torch.bfloat16).float()
    squared=torch.zeros((len(z),),dtype=torch.float32)
    for pair,code in enumerate(choices):
        inv=np.linalg.inv(transform(gamma[[pair,pair+64]],ANGLES[code]))
        a,b,d=float(inv[0,0]),float(inv[0,1]),float(inv[1,0])
        e=float(inv[1,1])
        u,v=z[:,pair],z[:,pair+64]
        squared += (a*a+d*d)*u*u+2*(a*b+d*e)*u*v+(b*b+e*e)*v*v
    normalized=(z*torch.rsqrt(squared[:,None]/128+1e-6)).to(torch.bfloat16).float()
    return normalized*torch.from_numpy(gamma.astype(np.float32)).to(torch.bfloat16).float()


def transported_head(q,k,v,qgamma,kgamma,choices,wo):
    q=rope(metric_norm(q,qgamma,choices))
    k=rope(metric_norm(k,kgamma,choices))
    logits=q@k.T/math.sqrt(128)
    logits=logits.masked_fill(torch.ones_like(logits,dtype=torch.bool).triu(1),-1e9)
    logp=logits.log_softmax(-1)
    return logp,(logp.exp()@v)@wo.T,logits


def main(codec=None):
    torch.set_num_threads(1)
    with np.load(FIX) as f:
        train=f['train'].reshape(8,256,1024)[:2].copy()
        held=f['validation'].reshape(4,256,1024)[:2].copy()
        wq=f['weight'][:256].astype(np.float32).copy()
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        wk=f.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float().numpy()
        wv=f.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        wo=f.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].float()
        qgamma=f.get_tensor('model.layers.0.self_attn.q_norm.weight').float().numpy()
        kgamma=f.get_tensor('model.layers.0.self_attn.k_norm.weight').float().numpy()
    fitted,choices,image=fit(wq[:128],qgamma,train)
    codec_metadata=None
    if codec is not None:
        fitted,choices,codec_metadata=codec(image[:8704],choices)
    matched_zero,_,_=fit(wq[:128],qgamma,train,force_zero=True)
    # The changed full-row Q/K storage is billed as BF16. Round the stored
    # weights before projection, rather than only rounding their outputs.
    qtrans=torch.from_numpy(full_transform(wq,qgamma,choices)).to(torch.bfloat16).float().numpy()
    ktrans=torch.from_numpy(full_transform(wk,kgamma,choices)).to(torch.bfloat16).float().numpy()
    no_q4=qtrans.copy()
    qtrans[:128,:128]=fitted
    qcontrol=wq[:128].copy();qcontrol[:,:128]=q4_decode(Q4.read_bytes())
    qmatched=wq[:128].copy();qmatched[:,:128]=matched_zero
    outcomes={}
    with torch.no_grad():
        for label,panels in [('train',train),('held',held)]:
            records={name:[] for name in ('coordinate','coordinate_no_q4','q4','matched_zero_q4')}
            for block in panels:
                x=torch.from_numpy(block.astype(np.float32))
                key=(x@torch.from_numpy(wk).T).to(torch.bfloat16).float()
                kt=(x@torch.from_numpy(ktrans).T).to(torch.bfloat16).float()
                value=(x@wv.T).to(torch.bfloat16).float()
                original=(x@torch.from_numpy(wq).T).to(torch.bfloat16).float()
                changed=(x@torch.from_numpy(qtrans).T).to(torch.bfloat16).float()
                exact=(x@torch.from_numpy(no_q4).T).to(torch.bfloat16).float()
                q4raw=(x@torch.from_numpy(qcontrol).T).to(torch.bfloat16).float()
                matched_raw=(x@torch.from_numpy(qmatched).T).to(torch.bfloat16).float()
                refs=[];candidate=[];unquant=[];scalar=[];matched=[]
                for i in range(2):
                    sel=slice(i*128,(i+1)*128)
                    refs.append(head(original[:,sel],key,value,qgamma=torch.from_numpy(qgamma),kgamma=torch.from_numpy(kgamma),wo=wo[:,sel]))
                    candidate.append(transported_head(changed[:,sel],kt,value,qgamma,kgamma,choices,wo[:,sel]))
                    unquant.append(transported_head(exact[:,sel],kt,value,qgamma,kgamma,choices,wo[:,sel]))
                    scalar.append(head(q4raw if i==0 else original[:,sel],key,value,torch.from_numpy(qgamma),torch.from_numpy(kgamma),wo[:,sel]))
                    matched.append(head(matched_raw if i==0 else original[:,sel],key,value,torch.from_numpy(qgamma),torch.from_numpy(kgamma),wo[:,sel]))
                for name,heads in [('coordinate',candidate),('coordinate_no_q4',unquant),('q4',scalar),('matched_zero_q4',matched)]:
                    rec={}
                    for i in range(2):
                        rec[f'head{i}_kl']=compare(refs[i],heads[i])['attention_kl']
                    rec['gqa_mean_kl']=(rec['head0_kl']+rec['head1_kl'])/2
                    reference_output=refs[0][1]+refs[1][1]
                    modified_output=heads[0][1]+heads[1][1]
                    rec['gqa_post_o_rel_sq']=float((reference_output-modified_output).square().sum()/reference_output.square().sum())
                    records[name].append(rec)
            outcomes[label]={name:{metric:float(np.mean([r[metric] for r in samples])) for metric in samples[0]} for name,samples in records.items()}
    report=dict(image_sha256=hashlib.sha256(image).hexdigest(),image_bytes=len(image),angles=choices.tolist(),nonzero_angles=int(np.count_nonzero(choices)),panels=outcomes,fixture_sha256=hashlib.sha256(FIX.read_bytes()).hexdigest(),q4_sha256=hashlib.sha256(Q4.read_bytes()).hexdigest())
    if codec is not None:
        report['embedded_reader']=codec_metadata
    HERE.joinpath('results-embedded.json' if codec is not None else 'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':
    main()
