#!/usr/bin/env python3
"""Apply the strong binary response-coordinate control to complete-model images."""
import argparse
import importlib.util
import json
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from capture import ROOT, MODEL, MODULE_INPUTS, sha
from prepare import floats

REFINER=Path(__file__).resolve().parents[1]/'block-factor/fit.py'
spec=importlib.util.spec_from_file_location('binary_coordinate_fit',REFINER)
refiner=importlib.util.module_from_spec(spec)
spec.loader.exec_module(refiner)


def main(args):
    torch.set_num_threads(args.threads)
    tasks=json.loads((ROOT/'full-model/fit-inputs/manifest.json').read_text())['tasks']
    task=tasks[args.task]
    seed_dir=ROOT/'full-model'/args.series/task['name']
    report=json.loads((seed_dir/'run.json').read_text())
    out=ROOT/'full-model'/args.out_series/task['name'];out.mkdir(parents=True,exist_ok=True)
    entries=[];started=time.monotonic()
    with safe_open(MODEL/'model.safetensors',framework='pt',device='cpu') as model:
        for entry in report['entries']:
            path=Path(entry['image']);stem=Path(entry['input']).stem
            layer_text,suffix=stem.split('-',1);layer=int(layer_text[5:])
            suffix=suffix.replace('self_attn_','self_attn.').replace('mlp_','mlp.')
            group=MODULE_INPUTS[suffix]
            with np.load(ROOT/f'full-model/capture/layer{layer:02}.npz') as f:
                train=torch.from_numpy(floats(f['train_'+group]))
                validation=torch.from_numpy(floats(f['validation_'+group]))
            key=f'model.layers.{layer}.{suffix}.weight'
            weight=model.get_tensor(key).float()
            with np.load(path) as f:
                arrays={k:f[k].copy() for k in f.files}
            n,k,r=arrays['dimensions'].tolist()
            u=torch.from_numpy(np.unpackbits(arrays['U'],axis=1,bitorder='little')[:,:r].astype(np.float32)*2-1)
            v=torch.from_numpy(np.unpackbits(arrays['V'],axis=1,bitorder='little')[:,:k].astype(np.float32)*2-1)
            pre=torch.from_numpy(arrays['scale_pre'].astype(np.float32))
            post=torch.from_numpy(arrays['scale_post'].astype(np.float32))
            begin=time.monotonic()
            mean=train.mean(0)
            fit_train=train-mean if args.affine else train
            if args.sweeps:
                u,post=refiner.refine_u_activations(weight,fit_train,u,v,pre,post,args.sweeps)
            else:
                prediction=((fit_train*pre)@v.T)@u.T
                target=fit_train@weight.T
                post=((target*prediction).sum(0)/prediction.square().sum(0).clamp_min(1e-20)).clamp_min(0).half().float()
            arrays['U']=np.packbits((u.numpy()>0).astype(np.uint8),axis=1,bitorder='little')
            arrays['scale_post']=post.numpy().astype(np.float16)
            bias=(mean@weight.T-(((mean*pre)@v.T)@u.T)*post).half() if args.affine else torch.zeros(n)
            if args.affine:arrays['bias']=bias.numpy()
            destination=out/path.name;np.savez(destination,**arrays)
            prediction=(((validation*pre)@v.T)@u.T)*post+bias.float()
            target=validation@weight.T
            item={**entry,'image':str(destination),'image_sha256':sha(destination),
                  'seed_image':str(path),'seed_image_sha256':sha(path),
                  'payload_bytes':sum(a.nbytes for a in arrays.values()),
                  'validation_relative_squared_error':float((prediction-target).square().sum()/target.square().sum()),
                  'refine_seconds':time.monotonic()-begin}
            entries.append(item)
            current={'method':'fixed binary input factor, train-response output signs and FP16 scales',
                     'affine':args.affine,'sweeps':args.sweeps,'source_sha256':sha(Path(__file__)),'refiner_sha256':sha(REFINER),
                     'seed_run_sha256':sha(seed_dir/'run.json'),'seconds':time.monotonic()-started,
                     'complete':len(entries)==len(report['entries']),'entries':entries}
            (out/'run.json').write_text(json.dumps(current,indent=2)+'\n')
            print(json.dumps({'matrix':stem,'validation_response_error':item['validation_relative_squared_error'],
                              'seconds':item['refine_seconds']}),flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--task',type=int,required=True)
    p.add_argument('--series',default='binary055')
    p.add_argument('--out-series',default='binary055-refined')
    p.add_argument('--sweeps',type=int,default=4)
    p.add_argument('--affine',action='store_true',help='Fit centered responses and pay one FP16 bias per output channel')
    p.add_argument('--threads',type=int,default=4)
    main(p.parse_args())
