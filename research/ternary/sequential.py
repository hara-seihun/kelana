#!/usr/bin/env python3
"""Fit each Qwen layer against its actual quantized producer, then carry it forward."""
import argparse
import json
from pathlib import Path
import time
import numpy as np
import torch
from pilot import ROOT, MODEL, GROUPS, sha, packed, unpacked, expanded, load_model
from quantize import quantize

@torch.no_grad()
def run(a):
    torch.set_num_threads(4);torch.backends.cuda.matmul.allow_tf32=False
    out=ROOT/a.name;out.mkdir(exist_ok=True)
    model=load_model()
    with np.load(ROOT/'tokens.npz') as z:rows=torch.tensor(z['train'][:a.windows],device='cuda',dtype=torch.long)
    embedding='model.embed_tokens.weight'
    path=out/(embedding.replace('.','_')+'.npz')
    if not path.exists():
        image=quantize(model.model.embed_tokens.weight.float(),rotation_block=a.rotation or None)
        payload=packed(image,path)
        rec=dict(key=embedding,parameters=image.codes.numel(),payload_bytes=payload,file_bytes=path.stat().st_size,sha256=sha(path))
        path.with_suffix('.json').write_text(json.dumps(rec,indent=2)+'\n')
    model.model.embed_tokens.weight.copy_(expanded(path))
    x=model.model.embed_tokens(rows)
    positions=torch.arange(x.shape[1],device='cuda');pos=positions[None]
    rope=model.model.rotary_emb(x[:1],pos)
    kwargs=dict(position_ids=pos,cache_position=positions,position_embeddings=rope,use_cache=False,attention_mask=None)
    groups=[['self_attn.q_proj','self_attn.k_proj','self_attn.v_proj'],['self_attn.o_proj'],['mlp.gate_proj','mlp.up_proj'],['mlp.down_proj']]
    for index,layer in enumerate(model.model.layers):
        began=time.time()
        if index>=a.end:break
        original={name:p.detach().clone() for name,p in layer.named_parameters()} if a.steps else {}
        for members in groups:
            paths={m:out/f'model_layers_{index}_{m.replace(".","_")}_weight.npz' for m in members}
            if not all(p.exists() for p in paths.values()):
                cap=[]
                def hook(module,values):cap.append(values[0].detach().reshape(-1,values[0].shape[-1]).float())
                handle=layer.get_submodule(members[0]).register_forward_pre_hook(hook)
                for batch in x.split(1):layer(batch,**kwargs)
                handle.remove();inputs=torch.cat(cap)
                for m in members:
                    path=paths[m]
                    if path.exists():continue
                    module=layer.get_submodule(m)
                    image=quantize(module.weight.float(),method='gptq',rotation_block=a.rotation or None,X=inputs,seed=20260923,damp=a.damp)
                    payload=packed(image,path)
                    rec=dict(key=f'model.layers.{index}.{m}.weight',parameters=image.codes.numel(),payload_bytes=payload,
                             file_bytes=path.stat().st_size,sha256=sha(path),method='sequential-gptq',calibration_rows=len(inputs),
                             source_sha256=sha(Path(__file__)),quantizer_sha256=sha(Path(__file__).with_name('quantize.py')),
                             tokens_sha256=sha(ROOT/'tokens.npz'),damp=a.damp)
                    path.with_suffix('.json').write_text(json.dumps(rec,indent=2)+'\n')
                del inputs,cap
            for m,path in paths.items():layer.get_submodule(m).weight.copy_(expanded(path))
        reconstruction_path=out/f'layer{index:02}-reconstruction.json'
        if a.steps and not reconstruction_path.exists():
            from reconstruct import reconstruct_block, BlockBatch, PROJECTIONS
            images={name:unpacked(out/f'model_layers_{index}_{name.replace(".","_")}.npz') for name in PROJECTIONS}
            for name,p in layer.named_parameters():p.copy_(original[name])
            batches=[BlockBatch(batch,kwargs) for batch in x[:a.reconstruction_windows].split(1)]
            result=reconstruct_block(layer,images,batches,steps=a.steps,evaluate_every=8,
                                     lr_codes=a.lr_codes,lr_scales=a.lr_scales)
            for name,image in result.images.items():
                path=out/f'model_layers_{index}_{name.replace(".","_")}.npz'
                payload=packed(image,path)
                rec=json.loads(path.with_suffix('.json').read_text())
                rec.update(payload_bytes=payload,file_bytes=path.stat().st_size,sha256=sha(path),reconstruction_steps=a.steps)
                path.with_suffix('.json').write_text(json.dumps(rec,indent=2)+'\n')
                layer.get_parameter(name).copy_(image.decode())
            reconstruction_path.write_text(json.dumps(dict(initial_loss=result.initial_loss,best_loss=result.best_loss,
                history=result.history,windows=len(batches),lr_codes=a.lr_codes,lr_scales=a.lr_scales,
                source_sha256=sha(Path(__file__).with_name('reconstruct.py'))),indent=2)+'\n')
            print(json.dumps({'layer':index,'reconstruction_initial':result.initial_loss,'reconstruction_best':result.best_loss}),flush=True)
            del images,result,batches
        del original
        x=torch.cat([layer(batch,**kwargs) for batch in x.split(1)])
        print(json.dumps({'layer':index,'seconds':time.time()-began}),flush=True)
    records=[json.loads(p.read_text()) for p in out.glob('model*.json')]
    from safetensors import safe_open
    with safe_open(MODEL/'model.safetensors',framework='pt',device='cpu') as f:
        norms={k:f.get_tensor(k).view(torch.int16).numpy() for k in f.keys() if len(f.get_slice(k).get_shape())!=2}
    np.savez(out/'norms.npz',**norms)
    payload=sum(r['payload_bytes'] for r in records)+sum(v.nbytes for v in norms.values())
    manifest=dict(complete=len(records)==197,matrices=records,matrix_count=len(records),payload_bytes=payload,bpw=8*payload/596049920,
                  unique_parameters=596049920,model_source_sha256=sha(MODEL/'source.json'),
                  calibration='fresh train, quantized embedding and upstream layers; qkv then o then gate/up then down')
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--name',default='sequential-gptq');p.add_argument('--windows',type=int,default=16)
    p.add_argument('--end',type=int,default=28);p.add_argument('--damp',type=float,default=.01)
    p.add_argument('--steps',type=int,default=0);p.add_argument('--reconstruction-windows',type=int,default=4)
    p.add_argument('--lr-codes',type=float,default=.001);p.add_argument('--lr-scales',type=float,default=.001)
    p.add_argument('--rotation',type=int,choices=[0,128,1024],default=1024)
    run(p.parse_args())
