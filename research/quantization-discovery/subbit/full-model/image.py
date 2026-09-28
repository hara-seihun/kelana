#!/usr/bin/env python3
"""Assemble paid Qwen images, retaining the tied matrix only once."""
import argparse
import json
import shutil
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from capture import ROOT, MODEL, sha


def packed_bytes(path):
    with np.load(path) as f:
        return sum(f[name].nbytes for name in f.files)


def make_head(destination,variant='exact'):
    if variant=='exact':
        source=ROOT/'tied-head'
        inputs=[source/'codebook256.npz',source/'common256.npz',source/'tune256-2560.json']
        with np.load(inputs[0]) as f: arrays={k:f[k] for k in f.files}
        with np.load(inputs[1]) as f:
            arrays.update(common_ids=f['ids'],common_bf16=f['bf16_bits'])
        correction=json.loads(inputs[2].read_text())
        arrays['head_correction']=np.array([correction['temperature_rare'],correction['offset_rare']],np.float32)
    elif variant=='mixed':
        inputs=[ROOT/'tied-factors/mixed256.npz',ROOT/'tied-factors/mixed-quality.json']
        with np.load(inputs[0]) as f:arrays={k:f[k] for k in f.files}
        arrays['common_ids']=arrays.pop('exact_ids');arrays['common_bf16']=arrays.pop('exact_bf16')
        correction=json.loads(inputs[1].read_text())
        arrays['head_correction']=np.array([correction['train_rare_temperature'],correction['train_rare_offset']],np.float32)
    else:raise ValueError(f'unknown head variant {variant}')
    destination.mkdir(parents=True,exist_ok=True)
    path=destination/'tied.npz'
    np.savez(path,**arrays)
    record={'kind':'shared-response-codebook-with-exact-rows','path':path.name,'sha256':sha(path),
            'payload_bytes':sum(a.nbytes for a in arrays.values()),'container_bytes':path.stat().st_size,
            'parameters':151936*1024,'sources':{str(p):sha(p) for p in inputs},'variant':variant,
            'map':'shared 16-vector K256 codebook with block128 scales, exact BF16 and optional RTN4 rows; FP32 head multiply/add only on remaining codebook rows'}
    (destination/'head.json').write_text(json.dumps(record,indent=2)+'\n')
    return record


def assemble(args):
    torch.set_num_threads(4)
    args.out.mkdir(parents=True,exist_ok=True)
    head=make_head(args.out,args.head_variant)
    if args.series is None:
        print(json.dumps(head));return
    inputs=json.loads((ROOT/'full-model/fit-inputs/manifest.json').read_text())
    by_stem={m['name']:m for m in inputs['matrices']}
    entries=[];sources={}
    for path in sorted(args.series.glob('*/run.json')):
        report=json.loads(path.read_text());sources[str(path)]=sha(path)
        for entry in report['entries']:
            matrix=by_stem[Path(entry['input']).stem]
            image=Path(entry['image'])
            if sha(image)!=entry['image_sha256']:raise ValueError(f'changed fitted image: {image}')
            destination=args.out/(matrix['name']+'.npz')
            shutil.copy2(image,destination)
            entries.append({'key':matrix['key'],'path':destination.name,'sha256':sha(destination),
                            'parameters':int(np.prod(matrix['shape'])),'rank':entry['rank'],
                            'payload_bytes':packed_bytes(destination),'container_bytes':destination.stat().st_size})
    if len(entries)!=196 or len({e['key'] for e in entries})!=196:
        raise ValueError(f'need all 196 unique matrices, found {len(entries)}')
    body_keys={e['key'] for e in entries}
    norms={};norm_parameters=0
    with safe_open(MODEL/'model.safetensors',framework='pt',device='cpu') as model:
        for key in model.keys():
            if key in body_keys or key in ('model.embed_tokens.weight','lm_head.weight'):continue
            weight=model.get_tensor(key)
            if weight.dtype!=torch.bfloat16:raise ValueError(f'unpriced dtype {key} {weight.dtype}')
            norms[key]=weight.view(torch.int16).numpy().view(np.uint16)
            norm_parameters+=weight.numel()
    np.savez(args.out/'norms.npz',**norms)
    shutil.copy2(MODEL/'config.json',args.out/'config.json')
    unique=sum(e['parameters'] for e in entries)+head['parameters']+norm_parameters
    payload=sum(e['payload_bytes'] for e in entries)+head['payload_bytes']+sum(a.nbytes for a in norms.values())
    report={'format':'qwen-subbit-complete-image/1','source_sha256':sha(Path(__file__)),
            'model_source_sha256':sha(MODEL/'source.json'),'fit_receipts':sources,
            'body':entries,'tied':head,'norms':{'path':'norms.npz','sha256':sha(args.out/'norms.npz'),
                                             'parameters':norm_parameters,'payload_bytes':2*norm_parameters},
            'config_sha256':sha(args.out/'config.json'),'unique_parameters':unique,
            'payload_bytes':payload,'payload_bpw':8*payload/unique,
            'container_bytes_without_manifest':sum(p.stat().st_size for p in args.out.iterdir() if p.is_file() and p.name!='manifest.json')}
    (args.out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ('unique_parameters','payload_bytes','payload_bpw','container_bytes_without_manifest')}))


def binary_weight(path,device='cuda'):
    with np.load(path) as f:
        n,k,r=f['dimensions'].tolist()
        u=np.unpackbits(f['U'],axis=1,bitorder='little')[:,:r].astype(np.float32)*2-1
        v=np.unpackbits(f['V'],axis=1,bitorder='little')[:,:k].astype(np.float32)*2-1
        u*=f['scale_post'].astype(np.float32)[:,None]
        v*=f['scale_pre'].astype(np.float32)[None,:]
        residual=(f['residual_left'].astype(np.float32),f['residual_right'].astype(np.float32)) if 'residual_left' in f.files else None
    weight=torch.from_numpy(u).to(device)@torch.from_numpy(v).to(device)
    if residual is not None:
        weight+=torch.from_numpy(residual[0]).to(device)@torch.from_numpy(residual[1]).to(device)
    return weight


def head_weight(path,device='cuda'):
    with np.load(path) as f:
        code=torch.from_numpy(f['code'].astype(np.float32)).to(device)*float(f['unit'])
        output=torch.empty((len(f['labels']),1024),device=device,dtype=torch.bfloat16)
        labels=f['labels'];scales=f['scales']
        for start in range(0,len(labels),4096):
            ids=torch.from_numpy(labels[start:start+4096].astype(np.int64)).to(device)
            scale=torch.from_numpy(scales[start:start+4096].astype(np.float32)).to(device)
            weight=code[ids].reshape(len(ids),8,128)*scale[:,:,None]
            output[start:start+len(ids)].copy_(weight.reshape(len(ids),1024))
        ids=torch.from_numpy(f['common_ids'].astype(np.int64)).to(device)
        exact=torch.from_numpy(f['common_bf16'].view(np.int16).copy()).view(torch.bfloat16).to(device)
        output[ids]=exact
        rare=torch.ones(len(output),dtype=torch.bool,device=device);rare[ids]=False
        if 'rare_packed' in f.files:
            packed=f['rare_packed'];codes=np.empty((len(packed),1024),np.uint8)
            codes[:,0::2]=packed&15;codes[:,1::2]=packed>>4
            weight=(codes.reshape(-1,8,128).astype(np.float32)-7.5)*f['rare_scales'].astype(np.float32)[:,:,None]
            row_ids=torch.from_numpy(f['rare_ids'].astype(np.int64)).to(device)
            output[row_ids]=torch.from_numpy(weight.reshape(-1,1024)).to(device=device,dtype=output.dtype)
            rare[row_ids]=False
        correction=f['head_correction'].copy()
    return output,rare,correction


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--series',type=Path)
    p.add_argument('--head-variant',choices=['exact','mixed'],default='exact')
    p.add_argument('--out',type=Path,required=True)
    assemble(p.parse_args())
