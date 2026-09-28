#!/usr/bin/env python3
"""Two five-element pair-coordinate families, selected by full-GQA train KL.

Each candidate quantizes both complete Q heads and their shared K head, with
exactly the same group Q4 fitter. The held panel is evaluated only for the
candidate selected from saved train results.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from embedded import constrained_fields, serialize
from group import assemble, decode, extract_first, GROUPS, RECORD
from observer import FIX, MODEL, compare, head
from replay import full_transform, transported_head

HERE=Path(__file__).resolve().parent


def load():
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
    return train,held,np.concatenate((q,k)),v,o,qgamma,kgamma


def make_image(teacher,train,qgamma,kgamma,index,family):
    choices=np.full(64,index,dtype=np.uint8)
    if family=='balanced':
        qratio=np.abs(np.log(np.abs(qgamma[64:]/qgamma[:64])))
        kratio=np.abs(np.log(np.abs(kgamma[64:]/kgamma[:64])))
        choices[np.maximum(qratio,kratio)>=0.5]=0
    q=full_transform(teacher[:256],qgamma,choices)
    k=full_transform(teacher[256:],kgamma,choices)
    image=bytearray(assemble(np.concatenate((q,k)),train))
    first=extract_first(image)
    field_ranges=constrained_fields(first)
    labeled=serialize(first,choices)
    for row in range(128):
        at=row*GROUPS*RECORD
        image[at:at+RECORD]=labeled[row*RECORD:(row+1)*RECORD]
    return bytes(image),field_ranges


def evaluate(image,inputs,teacher,v,o,qgamma,kgamma):
    decoded,choices=decode(image,embedded=True)
    outputs=[]
    with torch.no_grad():
        for block in inputs:
            x=torch.from_numpy(block.astype(np.float32))
            raw=(x@torch.from_numpy(teacher).T).to(torch.bfloat16).float()
            modified=(x@torch.from_numpy(decoded).T).to(torch.bfloat16).float()
            value=(x@v.T).to(torch.bfloat16).float()
            original_heads=[];new_heads=[]
            for h in range(2):
                sel=slice(h*128,(h+1)*128)
                original_heads.append(head(raw[:,sel],raw[:,256:],value,
                                           torch.from_numpy(qgamma),torch.from_numpy(kgamma),o[:,sel]))
                if not np.any(choices):
                    new_heads.append(head(modified[:,sel],modified[:,256:],value,
                                          torch.from_numpy(qgamma),torch.from_numpy(kgamma),o[:,sel]))
                else:
                    new_heads.append(transported_head(modified[:,sel],modified[:,256:],value,
                                                      qgamma,kgamma,choices,o[:,sel]))
            ref_output=original_heads[0][1]+original_heads[1][1]
            new_output=new_heads[0][1]+new_heads[1][1]
            outputs.append({'head0_kl':compare(original_heads[0],new_heads[0])['attention_kl'],
                            'head1_kl':compare(original_heads[1],new_heads[1])['attention_kl'],
                            'gqa_post_o_rel_sq':float((ref_output-new_output).square().sum()/ref_output.square().sum())})
    report={key:float(np.mean([sample[key] for sample in outputs])) for key in outputs[0]}
    report['gqa_mean_kl']=(report['head0_kl']+report['head1_kl'])/2
    return report


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--candidate',type=int,choices=range(5))
    parser.add_argument('--family',choices=('global','balanced'),default='global')
    parser.add_argument('--select',action='store_true')
    args=parser.parse_args()
    if (args.candidate is None)==(not args.select):
        parser.error('choose exactly one of --candidate or --select')
    if args.select:
        candidates=[json.loads((HERE/f'{args.family}-angle-{i}.json').read_text()) for i in range(5)]
        winner=min(candidates,key=lambda row:(row['train']['gqa_mean_kl'],row['train']['gqa_post_o_rel_sq']))['index']
        print('selected by train mean KL:',winner)
        train,held,teacher,v,o,qgamma,kgamma=load()
        image,ranges=make_image(teacher,train,qgamma,kgamma,winner,args.family)
        destination=HERE/f'q4-gqa-{args.family}.bin'
        destination.write_bytes(image)
        report={'selection':'minimum train GQA mean attention KL among five structurally defined coordinate programs; held never entered selection',
                'family':args.family,'winner':winner,'candidates_train':candidates,
                'winner_image_bytes':len(image),
                'winner_image_sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),
                'winner_first_tile_ranges':ranges,
                'winner_held':evaluate(destination.read_bytes(),held,teacher,v,o,qgamma,kgamma)}
        (HERE/f'results-{args.family}.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report['winner_held'],indent=2))
        return
    train,_,teacher,v,o,qgamma,kgamma=load()
    image,ranges=make_image(teacher,train,qgamma,kgamma,args.candidate,args.family)
    report={'family':args.family,'index':args.candidate,'nonzero_angles':int(args.candidate!=0)*(64 if args.family=='global' else int(sum(np.maximum(np.abs(np.log(np.abs(qgamma[64:]/qgamma[:64]))),np.abs(np.log(np.abs(kgamma[64:]/kgamma[:64]))))<0.5))),
            'train':evaluate(image,train,teacher,v,o,qgamma,kgamma),
            'first_tile_ranges':ranges,'image_bytes':len(image),'image_sha256':hashlib.sha256(image).hexdigest()}
    (HERE/f'{args.family}-angle-{args.candidate}.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':
    main()
