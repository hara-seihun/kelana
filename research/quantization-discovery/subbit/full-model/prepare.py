#!/usr/bin/env python3
"""Prepare all Qwen matrix norms from shared original-model producer captures."""
import argparse
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from capture import ROOT, MODEL, MODULE_INPUTS, sha


def floats(bits):
    return (bits.astype(np.uint32) << 16).view(np.float32)


def main(args):
    torch.set_num_threads(4)
    args.out.mkdir(parents=True, exist_ok=True)
    captures = ROOT / 'full-model/capture'
    groups = {}
    matrices = []
    with safe_open(MODEL / 'model.safetensors', framework='pt', device='cpu') as model:
        for layer in range(28):
            with np.load(captures / f'layer{layer:02}.npz') as data:
                norms = {}
                for group in set(MODULE_INPUTS.values()):
                    x = floats(data[f'train_{group}'])
                    diagonal = np.mean(x*x, axis=0, dtype=np.float64).astype(np.float32)
                    norms[group] = .6*diagonal + .4*diagonal.mean()
            for suffix, group in MODULE_INPUTS.items():
                key = f'model.layers.{layer}.{suffix}.weight'
                weight = model.get_tensor(key).float().numpy()
                n, k = weight.shape
                name = f'layer{layer:02}-' + suffix.replace('.', '_')
                path = args.out / (name+'.npz')
                np.savez(path, weight=weight, i_norm=norms[group], o_norm=np.ones(n, np.float32))
                shape = f'{max(n,k)}x{min(n,k)}'
                groups.setdefault(shape, []).append(str(path))
                matrices.append({'key':key,'name':name,'shape':[n,k],'capture_group':group,
                                 'input':str(path),'input_sha256':sha(path)})
    tasks = []
    for shape, paths in groups.items():
        for start in range(0, len(paths), args.batch):
            tasks.append({'name':f'{shape}-{start//args.batch:02}', 'inputs':paths[start:start+args.batch]})
    receipt = {'format':'qwen-full-model-fit-inputs/1','model_source_sha256':sha(MODEL/'source.json'),
               'capture_manifest_sha256':sha(captures/'manifest.json'),'source_sha256':sha(Path(__file__)),
               'input_norm':'train squared channel mean, 0.4 shrink to mean diagonal; output ones',
               'matrices':matrices,'tasks':tasks}
    (args.out/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'matrices':len(matrices),'tasks':len(tasks),'groups':{k:len(v) for k,v in groups.items()}}))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--batch',type=int,default=16)
    p.add_argument('--out',type=Path,default=ROOT/'full-model/fit-inputs')
    main(p.parse_args())
