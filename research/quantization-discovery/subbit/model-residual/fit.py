#!/usr/bin/env python3
"""Fit a nested rank-8/16 FP16 response-residual factor for each body matrix."""
import argparse
import hashlib
import json
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

BASE = Path('/path/to/workspace/data/kelana-subbit/full-model/image-binary055-refined')
CAPTURE = Path('/path/to/workspace/data/kelana-subbit/full-model/capture')
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
GROUPS = {'self_attn.q_proj': 'qkv', 'self_attn.k_proj': 'qkv', 'self_attn.v_proj': 'qkv',
          'self_attn.o_proj': 'attn_out', 'mlp.gate_proj': 'gate_up',
          'mlp.up_proj': 'gate_up', 'mlp.down_proj': 'down'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bf16_bits(array, device):
    fp32=(array.astype(np.uint32)<<16).view(np.float32)
    return torch.from_numpy(fp32.copy()).to(device)


def binary_map(path, device):
    with np.load(path) as f:
        n,k,r=f['dimensions'].tolist()
        u=np.unpackbits(f['U'],axis=1,bitorder='little')[:,:r].astype(np.float32)*2-1
        v=np.unpackbits(f['V'],axis=1,bitorder='little')[:,:k].astype(np.float32)*2-1
        u*=f['scale_post'].astype(np.float32)[:,None]
        v*=f['scale_pre'].astype(np.float32)[None,:]
    return torch.from_numpy(u).to(device)@torch.from_numpy(v).to(device)


def response_basis(residual, train, seed, rank=16, oversample=16, power=1):
    y=train@residual.T
    generator=torch.Generator(device=train.device)
    generator.manual_seed(seed)
    omega=torch.randn((train.shape[0],rank+oversample),device=train.device,generator=generator)
    q=torch.linalg.qr(y.T@omega,mode='reduced').Q
    for _ in range(power):
        q=torch.linalg.qr(y.T@(y@q),mode='reduced').Q
    b=y@q
    _,s,vh=torch.linalg.svd(b,full_matrices=False)
    basis=q@vh.T[:,:rank]
    return basis,s[:rank]


def measure(train, validation, weight, residual, left, right):
    results={}
    for name,x in (('train',train),('validation',validation)):
        reference=x@weight.T
        remaining=x@residual.T
        denominator=reference.square().sum().item()
        scores={}
        for r in (0,8,16):
            difference=remaining if r==0 else remaining-(x@right[:r].T)@left[:,:r].T
            scores[str(r)]=float(difference.square().sum().item()/denominator)
        results[name]={'rows':len(x),'baseline_binary_relative_squared_error':scores['0'],
                       'rank8_relative_squared_error':scores['8'],
                       'rank16_relative_squared_error':scores['16']}
    return results


def run(args):
    args.out.mkdir(parents=True,exist_ok=True)
    base_manifest=json.loads((args.base/'manifest.json').read_text())
    capture_manifest=json.loads((args.capture/'manifest.json').read_text())
    entries_by_layer={layer:[] for layer in range(args.first,args.last)}
    for e in base_manifest['body']:
        layer=int(e['key'].split('.')[2])
        if layer in entries_by_layer: entries_by_layer[layer].append(e)
    if any(len(v)!=7 for v in entries_by_layer.values()):
        raise ValueError('expected seven distinct body matrices per selected layer')
    device=torch.device('cuda')
    torch.backends.cuda.matmul.allow_tf32=False
    started=time.perf_counter()
    for layer,entries in entries_by_layer.items():
        out=args.out/f'layer{layer:02d}'
        out.mkdir(parents=True,exist_ok=True)
        capture=Path(capture_manifest['layers'][str(layer)]['path'])
        if sha(capture)!=capture_manifest['layers'][str(layer)]['sha256']:
            raise ValueError(f'changed activation capture: {capture}')
        with np.load(capture) as f:
            train={g:bf16_bits(f['train_'+g],device) for g in set(GROUPS.values())}
            validation={g:bf16_bits(f['validation_'+g],device) for g in set(GROUPS.values())}
        records=[]
        with safe_open(args.model,framework='pt',device='cpu') as model:
            for e in entries:
                key=e['key']; path=args.base/e['path']
                if sha(path)!=e['sha256']:
                    raise ValueError(f'changed binary image: {path}')
                name='.'.join(key.split('.')[3:-1]);group=GROUPS[name]
                weight=model.get_tensor(key).float().to(device)
                baseline=binary_map(path,device)
                residual=weight-baseline
                input_train=train[group];input_validation=validation[group]
                seed=int.from_bytes(hashlib.sha256(key.encode()).digest()[:8],'little') % (2**63)
                begin=time.perf_counter()
                left,singular=response_basis(residual,input_train,seed)
                right=left.T@residual
                left=left.half().float()
                right=right.half().float()
                metrics=measure(input_train,input_validation,weight,residual,left,right)
                torch.cuda.synchronize()
                seconds=time.perf_counter()-begin
                arrays={'residual_left':left.half().cpu().numpy(),
                        'residual_right':right.half().cpu().numpy()}
                destination=out/(Path(e['path']).stem+'-residual.npz')
                np.savez(destination,**arrays)
                records.append({'key':key,'base_image':str(path),'base_image_sha256':e['sha256'],
                                'residual_image':str(destination),'residual_image_sha256':sha(destination),
                                'seed':seed,'rank16_singular_values':singular.cpu().tolist(),
                                'train_validation':metrics,'fit_seconds':seconds,
                                'rank8_added_bytes':2*8*(weight.shape[0]+weight.shape[1]),
                                'rank16_added_bytes':sum(a.nbytes for a in arrays.values())})
                print(json.dumps({'layer':layer,'key':key,'seconds':round(seconds,3),
                                  'validation':metrics['validation']}),flush=True)
                del weight,baseline,residual,left,right
        report={'format':'qwen-response-residual-layer/1','source_sha256':sha(Path(__file__)),
                'base_manifest_sha256':sha(args.base/'manifest.json'),
                'capture_manifest_sha256':sha(args.capture/'manifest.json'),
                'model_sha256':sha(args.model) if args.hash_model else base_manifest['model_source_sha256'],
                'layer':layer,'capture_path':str(capture),'capture_sha256':capture_manifest['layers'][str(layer)]['sha256'],
                'train_split':'original BF16 model WikiText train 2048 rows',
                'validation_split':'distinct original BF16 model WikiText validation 1024 rows',
                'method':'randomized right-singular output subspace of train response residual; oversample16, one power iteration, small SVD; rank8 prefix of rank16; FP16 factors evaluated after rounding',
                'records':records,'elapsed_seconds':time.perf_counter()-started}
        (out/'run.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--first',type=int,required=True)
    p.add_argument('--last',type=int,required=True)
    p.add_argument('--base',type=Path,default=BASE)
    p.add_argument('--capture',type=Path,default=CAPTURE)
    p.add_argument('--model',type=Path,default=MODEL)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--hash-model',action='store_true')
    args=p.parse_args()
    if not 0<=args.first<args.last<=28: p.error('layer interval must be within [0,28]')
    run(args)
