#!/usr/bin/env python3
"""Capture shared BF16 producer inputs for every Qwen layer without duplicating Q/K/V inputs."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

ROOT = Path('/path/to/workspace/data/kelana-subbit')
MODEL = ROOT / 'models/qwen3-0.6b'
TOKENS = ROOT / 'fixtures/qwen3-0.6b-wikitext/tokens.npz'
GROUPS = {'qkv': 'self_attn.q_proj', 'attn_out': 'self_attn.o_proj',
          'gate_up': 'mlp.up_proj', 'down': 'mlp.down_proj'}
MODULE_INPUTS = {'self_attn.q_proj':'qkv','self_attn.k_proj':'qkv','self_attn.v_proj':'qkv',
                 'self_attn.o_proj':'attn_out','mlp.gate_proj':'gate_up',
                 'mlp.up_proj':'gate_up','mlp.down_proj':'down'}


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1<<20),b''):h.update(chunk)
    return h.hexdigest()


def run(args):
    torch.set_num_threads(4)
    torch.manual_seed(42)
    torch.backends.cuda.matmul.allow_tf32=False
    model=AutoModelForCausalLM.from_pretrained(MODEL,local_files_only=True,dtype=torch.bfloat16,
                                              attn_implementation='sdpa').eval().to('cuda')
    layers=list(range(model.config.num_hidden_layers)) if args.layers is None else args.layers
    with np.load(TOKENS) as f:
        batches={s:f[s].copy() for s in ('train','validation')}
    captures={};handles=[];split_now=''
    for layer in layers:
        for group,suffix in GROUPS.items():
            name=f'model.layers.{layer}.{suffix}'
            def hook(module, values, layer=layer, group=group):
                value=values[0].detach().reshape(-1,values[0].shape[-1])
                bits=value.view(torch.int16).cpu().numpy().view(np.uint16).copy()
                captures.setdefault((layer,group,split_now),[]).append(bits)
            handles.append(model.get_submodule(name).register_forward_pre_hook(hook))
    with torch.inference_mode():
        for split,batch in batches.items():
            split_now=split
            for row in batch:
                ids=torch.tensor(row,device='cuda',dtype=torch.long).unsqueeze(0)
                model.model(ids,use_cache=False)
            print(json.dumps({'captured_split':split,'windows':len(batch),'layers':layers}),flush=True)
    for handle in handles:handle.remove()
    args.out.mkdir(parents=True,exist_ok=True)
    records={}
    for layer in layers:
        arrays={f'{split}_{group}':np.concatenate(captures[layer,group,split])
                for split in batches for group in GROUPS}
        path=args.out/f'layer{layer:02}.npz'
        np.savez(path,**arrays)
        records[str(layer)]={'path':str(path),'sha256':sha(path),
                             'arrays':{name:list(a.shape) for name,a in arrays.items()}}
    manifest={'format':'qwen-full-model-producers/1','model':str(MODEL),
              'model_source_sha256':sha(MODEL/'source.json'),
              'model_revision':json.loads((MODEL/'source.json').read_text())['revision'],
              'tokens':str(TOKENS),'tokens_sha256':sha(TOKENS),'source_sha256':sha(Path(__file__)),
              'producer':'original BF16 model, SDPA, cache disabled; no output head needed for capture',
              'array_encoding':'uint16 bit patterns of actual BF16 tensors; reinterpret, do not integer-cast',
              'module_input_groups':MODULE_INPUTS,'layers':records,
              'train_rows':int(np.prod(batches['train'].shape)),
              'validation_rows':int(np.prod(batches['validation'].shape)),
              'torch':torch.__version__,'hip':torch.version.hip,'device':torch.cuda.get_device_name()}
    destination=args.out/('manifest.json' if args.layers is None else 'manifest-'+','.join(map(str,layers))+'.json')
    destination.write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'manifest':str(destination),'layer_count':len(records)}),flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--layers',type=int,nargs='+')
    p.add_argument('--out',type=Path,default=ROOT/'full-model/capture')
    run(p.parse_args())
