#!/usr/bin/env python3
"""Fit existing output-factor FP16 scales against an original-model final-hidden teacher."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

ROOT=Path('/path/to/workspace/data/kelana-subbit')
DATA=ROOT/'model-tuning'
SOURCE=ROOT/'models/qwen3-0.6b'
TOKENS=ROOT/'fixtures/qwen3-0.6b-wikitext/tokens.npz'
SEED=ROOT/'full-model/image-binary055-refined'
HERE=Path(__file__).resolve().parent


def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
    return h.hexdigest()


def load_model():
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32=False
    return AutoModelForCausalLM.from_pretrained(SOURCE,local_files_only=True,dtype=torch.bfloat16,
                                                attn_implementation='sdpa').eval().to('cuda')


def teacher():
    DATA.mkdir(parents=True,exist_ok=True)
    torch.manual_seed(7542)
    model=load_model()
    with np.load(TOKENS) as z:ids=z['train'].copy()
    observations=[];gold=[]
    with torch.inference_mode():
        for row in ids:
            x=torch.from_numpy(row.astype(np.int64)).to('cuda')[None]
            hidden=model.model(x,use_cache=False).last_hidden_state[0].cpu().view(torch.int16).numpy().view(np.uint16).copy()
            observations.append(hidden)
            gold.append(row[1:])
    image=DATA/'teacher.npz'
    np.savez_compressed(image,hidden=np.stack(observations),next_token=np.stack(gold))
    record={'format':'qwen-full-model-final-hidden-teacher/1','model_source_sha256':sha(SOURCE/'source.json'),
            'model_weights_sha256':sha(SOURCE/'model.safetensors'),
            'tokens_sha256':sha(TOKENS),'source_sha256':sha(HERE/'fit.py'),
            'seed':7542,'train_windows':len(ids),'positions_per_window':len(ids[0]),
            'hidden_bits':'uint16 BF16 bit patterns from original model.model, all eight train windows, no held inputs',
            'image_sha256':sha(image),'torch':torch.__version__,'hip':torch.version.hip,
            'device':torch.cuda.get_device_name()}
    (DATA/'teacher.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({'train_windows':len(ids),'hidden_sha256':record['image_sha256']}),flush=True)


def binary_weight(image):
    with np.load(image) as z:
        n,k,r=z['dimensions'].tolist()
        u=np.unpackbits(z['U'],axis=1,bitorder='little')[:,:r].astype(np.float32)*2-1
        v=np.unpackbits(z['V'],axis=1,bitorder='little')[:,:k].astype(np.float32)*2-1
        u*=z['scale_post'].astype(np.float32)[:,None]
        v*=z['scale_pre'].astype(np.float32)[None,:]
    return torch.from_numpy(u).to('cuda')@torch.from_numpy(v).to('cuda')


def install_body(model,manifest):
    params=[];handles=[];spec=[]
    with torch.no_grad():
        for entry in manifest['body']:
            path=SEED/entry['path']
            if sha(path)!=entry['sha256']:raise ValueError(f'changed binary image: {path}')
            module=model.get_submodule(entry['key'].rsplit('.',1)[0])
            model.get_parameter(entry['key']).copy_(binary_weight(path))
            p=torch.nn.Parameter(torch.ones(module.out_features,device='cuda',dtype=torch.float32))
            def scale_hook(_,__,output,gain=p):
                return (output.float()*gain).to(output.dtype)
            handles.append(module.register_forward_hook(scale_hook))
            params.append(p);spec.append(entry)
    return params,handles,spec


def fit(args):
    DATA.mkdir(parents=True,exist_ok=True)
    manifest_path=SEED/'manifest.json';manifest=json.loads(manifest_path.read_text())
    teacher_receipt=json.loads((DATA/'teacher.json').read_text())
    if teacher_receipt['image_sha256']!=sha(DATA/'teacher.npz') or teacher_receipt['tokens_sha256']!=sha(TOKENS):
        raise ValueError('teacher source mismatch')
    torch.manual_seed(7542)
    model=load_model()
    for p in model.parameters():p.requires_grad_(False)
    params,handles,entries=install_body(model,manifest)
    optimizer=torch.optim.Adam(params,lr=args.lr)
    with np.load(DATA/'teacher.npz') as z:
        desired=z['hidden'].view(np.int16).copy().view(np.uint16)
    with np.load(TOKENS) as z:ids=z['train'].copy()
    if args.start:
        prior=DATA/f'checkpoint{args.start:02}.npz'
        r=json.loads((DATA/f'checkpoint{args.start:02}.json').read_text())
        if r['image_sha256']!=sha(prior) or r['seed_manifest_sha256']!=sha(manifest_path):
            raise ValueError('checkpoint changed')
        with np.load(prior) as z:
            for i,p in enumerate(params):p.data.copy_(torch.from_numpy(z[f'g{i}'].copy()).to('cuda'))
    losses=[]
    for j in range(args.start,args.start+args.count):
        x=torch.from_numpy(ids[j].astype(np.int64)).to('cuda')[None]
        target=torch.from_numpy(desired[j].view(np.int16).copy()).view(torch.bfloat16).to('cuda').float()
        model.zero_grad(set_to_none=True);optimizer.zero_grad(set_to_none=True)
        out=model.model(x,use_cache=False).last_hidden_state[0].float()
        # Squared error and angle of the final normalized activations, plus a
        # strong anchor against a one-window scale solution.
        mse=(out-target).square().mean()
        angular=1-torch.nn.functional.cosine_similarity(out,target,dim=-1).mean()
        regularizer=torch.stack([(g-1.).square().mean() for g in params]).mean()
        loss=mse+0.1*angular+0.01*regularizer
        loss.backward()
        torch.nn.utils.clip_grad_norm_(params,10.)
        optimizer.step()
        with torch.no_grad():
            for p in params:p.clamp_(0.5,2.)
        item={'window':j,'mse':float(mse.detach()),'angular':float(angular.detach()),
              'gain_min':float(min(p.min() for p in params)),'gain_max':float(max(p.max() for p in params))}
        losses.append(item)
        print(json.dumps(item),flush=True)
    last=args.start+args.count
    if last>8:raise ValueError('training contains only eight windows')
    image=DATA/f'checkpoint{last:02}.npz'
    np.savez_compressed(image,**{f'g{i}':p.detach().cpu().numpy().astype(np.float32) for i,p in enumerate(params)})
    receipt={'format':'qwen-full-model-scale-gain-checkpoint/1','image_sha256':sha(image),
             'source_sha256':sha(HERE/'fit.py'),'teacher_sha256':sha(DATA/'teacher.npz'),
             'seed_manifest_sha256':sha(manifest_path),'start':args.start,'count':args.count,
             'learning_rate':args.lr,'seed':7542,'losses':losses,
             'loss':'final normalized hidden MSE + 0.1 cosine gap + 0.01 mean scale-gain deviation square',
             'optimization':'Adam one train window per update; output-channel multiplier after frozen linear; merge into existing FP16 factor scale_post before inference',
             'gain_parameters':int(sum(p.numel() for p in params)),
             'added_runtime_payload_bytes':0}
    (DATA/f'checkpoint{last:02}.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'checkpoint':str(image),'sha256':receipt['image_sha256']}),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('phase',choices=('teacher','fit'))
    p.add_argument('--start',type=int,default=0)
    p.add_argument('--count',type=int,default=1)
    p.add_argument('--lr',type=float,default=0.005)
    a=p.parse_args()
    teacher() if a.phase=='teacher' else fit(a)
