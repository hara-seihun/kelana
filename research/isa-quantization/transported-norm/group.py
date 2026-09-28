#!/usr/bin/env python3
"""Full affected Q/K GQA group: matched Q4 versus transported Q4 at identical bytes."""
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from embedded import deserialize
from observer import FIX, MODEL, compare, head
from replay import fit, full_transform, transported_head

HERE=Path(__file__).resolve().parent
ROWS=384
GROUPS=8
BLOCK=128
RECORD=68
TOTAL=ROWS*GROUPS*RECORD


def fast_grid(rows, h):
    rows=np.asarray(rows,dtype=np.float64)
    ones=np.ones(BLOCK)
    hones=h@ones
    hsum=ones@hones
    rhs0=rows@hones
    best_loss=np.full(len(rows),np.inf)
    best_codes=np.empty((len(rows),BLOCK),dtype=np.uint8)
    best_origin=np.empty(len(rows),dtype=np.float16)
    best_step=np.empty(len(rows),dtype=np.float16)
    for lower,upper in ((0,100),(3,97),(8,92)):
        lo,hi=np.percentile(rows,(lower,upper),axis=1)
        origin=lo
        step=np.maximum((hi-lo)/15,1e-8)
        for _ in range(3):
            codes=np.clip(np.rint((rows-origin[:,None])/step[:,None]),0,15)
            hc=codes@h
            c0=hc@ones
            c1=(hc*codes).sum(1)
            rhs1=(hc*rows).sum(1)
            det=hsum*c1-c0*c0
            det=np.where(det>1e-20,det,np.inf)
            origin=(rhs0*c1-rhs1*c0)/det
            step=np.maximum((rhs1*hsum-rhs0*c0)/det,1e-8)
        origin=origin.astype(np.float16)
        step=step.astype(np.float16)
        codes=np.clip(np.rint((rows-origin[:,None])/step[:,None]),0,15).astype(np.uint8)
        delta=(origin[:,None].astype(np.float64)+step[:,None].astype(np.float64)*codes)-rows
        loss=((delta@h)*delta).sum(1)
        selected=loss<best_loss
        best_loss[selected]=loss[selected]
        best_codes[selected]=codes[selected]
        best_origin[selected]=origin[selected]
        best_step[selected]=step[selected]
    return best_codes,best_origin,best_step


def encoded_record(codes,origin,step):
    return (codes[0::2] | (codes[1::2]<<4)).tobytes()+np.asarray([origin,step],dtype='<f2').tobytes()


def assemble(source,train,first_tile=None):
    if source.shape!=(ROWS,GROUPS*BLOCK):
        raise ValueError('Expected both Q heads and their shared K head')
    tiles=[bytearray(ROWS*RECORD) for _ in range(GROUPS)]
    for group in range(GROUPS):
        x=np.concatenate([panel[:,group*BLOCK:(group+1)*BLOCK] for panel in train]).astype(np.float64)
        h=x.T@x
        data=source[:,group*BLOCK:(group+1)*BLOCK]
        codes,origins,steps=fast_grid(data,h)
        for row in range(ROWS):
            begin=row*RECORD
            tiles[group][begin:begin+RECORD]=encoded_record(codes[row],origins[row],steps[row])
    if first_tile is not None:
        if len(first_tile)!=128*RECORD:
            raise ValueError('First Q tile is not 8,704 bytes')
        for row in range(128):
            at=row*RECORD
            tiles[0][at:at+RECORD]=first_tile[at:at+RECORD]
    image=b''.join(bytes(tiles[group][row*RECORD:(row+1)*RECORD])
                   for row in range(ROWS) for group in range(GROUPS))
    assert len(image)==TOTAL
    return image


def extract_first(image):
    return b''.join(image[row*GROUPS*RECORD:row*GROUPS*RECORD+RECORD] for row in range(128))


def decode(image,embedded=False):
    if len(image)!=TOTAL:
        raise ValueError('Full Q/K Q4 group must have 384×8×68 bytes')
    mutable=bytearray(image)
    choices=None
    if embedded:
        first=extract_first(image)
        _,choices,restored=deserialize(first)
        for row in range(128):
            at=row*GROUPS*RECORD
            mutable[at:at+RECORD]=restored[row*RECORD:(row+1)*RECORD]
    records=np.frombuffer(mutable,dtype=np.uint8).reshape(ROWS,GROUPS,RECORD)
    codes=np.empty((ROWS,GROUPS,BLOCK),dtype=np.float32)
    codes[:,: ,0::2]=records[:,:,:64]&15
    codes[:,: ,1::2]=records[:,:,:64]>>4
    fields=np.frombuffer(mutable,dtype='<f2').reshape(ROWS,GROUPS,34)[:,:,32:].astype(np.float32)
    weights=fields[:,:,0,None]+fields[:,:,1,None]*codes
    return weights.reshape(ROWS,1024),choices


def main():
    torch.set_num_threads(1)
    with np.load(FIX) as f:
        train=f['train'].reshape(8,256,1024)[:2].copy()
        held=f['validation'].reshape(4,256,1024)[:2].copy()
        q=f['weight'][:256].astype(np.float32).copy()
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        k=f.get_tensor('model.layers.0.self_attn.k_proj.weight')[:128].float().numpy()
        v=f.get_tensor('model.layers.0.self_attn.v_proj.weight')[:128].float()
        o=f.get_tensor('model.layers.0.self_attn.o_proj.weight')[:,:256].float()
        qgamma=f.get_tensor('model.layers.0.self_attn.q_norm.weight').float().numpy()
        kgamma=f.get_tensor('model.layers.0.self_attn.k_norm.weight').float().numpy()
    _,_,zero_image=fit(q[:128],qgamma,train,force_zero=True)
    zero_tile=zero_image[:128*RECORD]
    embedded=(HERE/'q4-coordinate-embedded.bin').read_bytes()
    _,choices,_=deserialize(embedded)
    teacher=np.concatenate((q,k),axis=0)
    altered=np.concatenate((full_transform(q,qgamma,choices),full_transform(k,kgamma,choices)),axis=0)
    scalar_path=HERE/'q4-gqa-scalar.bin'
    coord_path=HERE/'q4-gqa-coordinate.bin'
    scalar_path.write_bytes(assemble(teacher,train,zero_tile))
    coord_path.write_bytes(assemble(altered,train,embedded))
    scalar,none=decode(scalar_path.read_bytes())
    coordinate,decoded_choices=decode(coord_path.read_bytes(),embedded=True)
    assert none is None and np.array_equal(choices,decoded_choices)
    assert extract_first(coord_path.read_bytes())==embedded
    panels={}
    with torch.no_grad():
        for label,inputs in (('train',train),('held',held)):
            records={'scalar':[],'coordinate':[]}
            for window in inputs:
                x=torch.from_numpy(window.astype(np.float32))
                original=(x@torch.from_numpy(teacher).T).to(torch.bfloat16).float()
                baseline=(x@torch.from_numpy(scalar).T).to(torch.bfloat16).float()
                changed=(x@torch.from_numpy(coordinate).T).to(torch.bfloat16).float()
                value=(x@v.T).to(torch.bfloat16).float()
                reference=[]
                for h in range(2):
                    subset=slice(128*h,128*(h+1))
                    reference.append(head(original[:,subset],original[:,256:],value,
                                          torch.from_numpy(qgamma),torch.from_numpy(kgamma),o[:,subset]))
                for name,result in (('scalar',baseline),('coordinate',changed)):
                    consumed=[]
                    for h in range(2):
                        subset=slice(128*h,128*(h+1))
                        if name=='scalar':
                            consumed.append(head(result[:,subset],result[:,256:],value,
                                                 torch.from_numpy(qgamma),torch.from_numpy(kgamma),o[:,subset]))
                        else:
                            consumed.append(transported_head(result[:,subset],result[:,256:],value,
                                                             qgamma,kgamma,decoded_choices,o[:,subset]))
                    ref_out=reference[0][1]+reference[1][1]
                    actual_out=consumed[0][1]+consumed[1][1]
                    records[name].append({'head0_kl':compare(reference[0],consumed[0])['attention_kl'],
                                          'head1_kl':compare(reference[1],consumed[1])['attention_kl'],
                                          'gqa_post_o_rel_sq':float((ref_out-actual_out).square().sum()/ref_out.square().sum())})
            panels[label]={name:{metric:float(np.mean([s[metric] for s in samples])) for metric in samples[0]}
                           for name,samples in records.items()}
            for name in panels[label]:
                p=panels[label][name]
                p['gqa_mean_kl']=(p['head0_kl']+p['head1_kl'])/2
    report={'group_shape':[3,128,1024], 'payload_bytes_each':TOTAL,
            'payload_sha256':{name:hashlib.sha256(path.read_bytes()).hexdigest()
                              for name,path in [('scalar',scalar_path),('coordinate',coord_path)]},
            'labels':decoded_choices.tolist(),'panels':panels,
            'fixture_sha256':hashlib.sha256(FIX.read_bytes()).hexdigest()}
    (HERE/'results-group.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report['panels'],indent=2))

if __name__=='__main__':
    main()
