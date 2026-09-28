#!/usr/bin/env python3
"""Give packed multilevel output factors the same coordinate response fit as binary factors."""
import argparse
import json
import time
from pathlib import Path

import numpy as np
import torch

from spectral_quant import decode, pack_codes, sha


def refine(arrays, x, target, sweeps):
    rows, rank, bits, group = arrays['left_shape'].tolist()
    top = 2**bits-1
    packed = np.unpackbits(arrays['left_codes'],axis=1,bitorder='little')[:,:rank*bits]
    codes = (packed.reshape(rows,rank,bits).astype(np.int16) << np.arange(bits)).sum(-1)
    codes = torch.from_numpy(2*codes-top).float()
    scales = torch.from_numpy(arrays['left_scales'].astype(np.float32))
    right = decode(arrays,'right')
    features = x@right.T
    gram = features.T@features/len(x)
    cross = target.T@features/len(x)
    left = codes*scales.repeat_interleave(group,dim=1)[:,:rank]
    for _ in range(sweeps):
        current = left@gram
        for r in range(rank):
            s = scales[:,r//group]
            optimum = (cross[:,r]-current[:,r]+left[:,r]*gram[r,r])/gram[r,r].clamp_min(1e-20)
            new = (((optimum/s.clamp_min(1e-20)+top)/2).round().clamp(0,top)*2-top)
            actual = new*s
            delta = actual-left[:,r]
            codes[:,r] = new
            left[:,r] = actual
            current += delta[:,None]*gram[r][None,:]
        prediction = features@left.T
        for g in range(scales.shape[1]):
            a,b = g*group,min((g+1)*group,rank)
            component = features[:,a:b]@codes[:,a:b].T
            residual = target-prediction+component*scales[:,g]
            updated = ((residual*component).sum(0)/component.square().sum(0).clamp_min(1e-20)).clamp_min(0).half().float()
            prediction += component*(updated-scales[:,g])
            scales[:,g] = updated
        left = codes*scales.repeat_interleave(group,dim=1)[:,:rank]
    arrays['left_codes'] = pack_codes(((codes.numpy()+top)/2).astype(np.uint8),bits)
    arrays['left_scales'] = scales.numpy().astype(np.float16)
    return arrays


def main(args):
    torch.set_num_threads(8)
    report = json.loads(args.report.read_text())
    fixture = Path(report['fixture'])
    with np.load(fixture) as f:
        weight = torch.from_numpy(f['weight'].copy()).float()
        train = torch.from_numpy(f['train'].copy()).float()
        validation = torch.from_numpy(f['validation'].copy()).float()
    target = train@weight.T
    target_v = validation@weight.T
    entries=[]
    for e in report['entries']:
        if e['target_bpw'] > args.max_bpw or e['left_bits']>4 or e['right_bits']>4:
            continue
        source = Path(e['artifact'])
        with np.load(source) as f:
            arrays={k:f[k] for k in f.files}
        start=time.monotonic()
        arrays=refine(arrays,train,target,args.sweeps)
        left,right=decode(arrays,'left'),decode(arrays,'right')
        pred=(validation@right.T)@left.T
        pred_t=(train@right.T)@left.T
        seconds=time.monotonic()-start
        path=args.out/(source.stem+f'-sweeps{args.sweeps}.npz')
        np.savez(path,**arrays)
        entry={**e,'before_validation_error':e['validation_relative_squared_error'],
               'before_train_error':e['train_relative_squared_error'],
               'train_relative_squared_error':((pred_t-target).square().sum()/target.square().sum()).item(),
               'validation_relative_squared_error':((pred-target_v).square().sum()/target_v.square().sum()).item(),
               'source_image':str(source),'source_image_sha256':sha(source),'artifact':str(path),
               'artifact_sha256':sha(path),'activation_output_sweeps':args.sweeps,'refinement_seconds':seconds}
        entries.append(entry)
    result={'fixture':str(fixture),'fixture_sha256':sha(fixture),'input_report':str(args.report),
            'input_report_sha256':sha(args.report),'sources':{p.name:sha(p) for p in (Path(__file__),Path(__file__).with_name('spectral_quant.py'))},
            'method':'conditional multilevel output-coordinate and FP16 group-scale response fit; input factor fixed',
            'entries':entries}
    path=args.out/(args.report.stem+f'-sweeps{args.sweeps}.json')
    path.write_text(json.dumps(result,indent=2)+'\n')
    selected=min(entries,key=lambda e:e['train_relative_squared_error'])
    print(json.dumps({'train_selected':selected}),flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--report',type=Path,required=True)
    p.add_argument('--sweeps',type=int,default=4)
    p.add_argument('--max-bpw',type=float,default=.55)
    p.add_argument('--out',type=Path,default=Path('/path/to/workspace/data/kelana-subbit/spectral-refine'))
    args=p.parse_args();args.out.mkdir(parents=True,exist_ok=True);main(args)
