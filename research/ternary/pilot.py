#!/usr/bin/env python3
"""Build real packed ternary Qwen images and measure complete-model language loss."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import time
import numpy as np
import torch
from safetensors import safe_open
from transformers import AutoModelForCausalLM
from quantize import quantize, TernaryImage

DATA=Path('/path/to/workspace/data/kelana-subbit')
ROOT=DATA/'ternary'
MODEL=DATA/'models/qwen3-0.6b'
CAPTURE=DATA/'full-model/capture'
GROUPS={'self_attn.q_proj':'qkv','self_attn.k_proj':'qkv','self_attn.v_proj':'qkv',
        'self_attn.o_proj':'attn_out','mlp.gate_proj':'gate_up','mlp.up_proj':'gate_up','mlp.down_proj':'down'}

def sha(p):
    h=hashlib.sha256()
    with Path(p).open('rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return h.hexdigest()

def packed(image,path):
    codes=(image.codes.cpu().numpy().reshape(-1).astype(np.int16)+1)
    codes=np.pad(codes,(0,(-len(codes))%5)).reshape(-1,5)
    payload=(codes*np.array([1,3,9,27,81])).sum(1).astype(np.uint8)
    signs=np.packbits(image.signs.cpu().numpy()>0,bitorder='little') if image.signs is not None else np.empty(0,dtype=np.uint8)
    arrays=dict(codes=payload,scales=image.scales.cpu().numpy(),signs=signs,
                shape=np.asarray(image.codes.shape,dtype=np.int32),rotation_block=np.asarray(image.rotation_block or 0,dtype=np.int32))
    np.savez(path,**arrays)
    return sum(a.nbytes for a in arrays.values())

def unpacked(path,device='cuda'):
    with np.load(path) as f:
        shape=tuple(f['shape']); n=int(np.prod(shape)); block=int(f['rotation_block'])
        digits=((f['codes'][:,None].astype(np.int16)//np.array([1,3,9,27,81]))%3-1).reshape(-1)[:n].reshape(shape)
        codes=torch.tensor(digits,device=device,dtype=torch.int8)
        scales=torch.tensor(f['scales'],device=device)
        signs=torch.tensor(np.unpackbits(f['signs'],bitorder='little')[:shape[1]].astype(np.int8)*2-1,device=device) if block else None
    # Construct through the quantizer's public representation, not a second rotation implementation.
    image=TernaryImage(codes=codes,scales=scales,signs=signs,rotation_block=block or None)
    return image

def expanded(path,device='cuda'):
    return unpacked(path,device).decode()

def fit(a):
    out=ROOT/a.name;out.mkdir(parents=True,exist_ok=True)
    source=MODEL/'model.safetensors'
    with safe_open(source,framework='pt',device='cpu') as f:
        keys=[k for k in f.keys() if k.endswith('.weight') and len(f.get_slice(k).get_shape())==2 and not k.startswith('lm_head.')]
        for key in keys:
            if key.startswith('model.layers.'):
                layer=int(key.split('.')[2])
                if not a.start<=layer<a.end:continue
            elif not a.embedding:continue
            path=out/(key.replace('.','_')+'.npz'); receipt=path.with_suffix('.json')
            if receipt.exists():
                rec=json.loads(receipt.read_text())
                if rec['method']!=a.method or rec['rotation_block']!=a.rotation:raise ValueError('Image settings changed')
                if sha(path)!=rec['sha256']:raise ValueError('Saved image changed')
                continue
            w=f.get_tensor(key).to(device='cuda',dtype=torch.float32)
            method=a.method; x=None; h=None;capture_sha=None
            if method=='gptq':
                if key=='model.embed_tokens.weight':
                    # A mixed head/embedding metric: final-hidden covariance plus a paid-no-bytes isotropic term.
                    headfile=ROOT/'head-hessian.pt'
                    if a.head_gptq:
                        h=torch.load(headfile,weights_only=True).to('cuda');capture_sha=sha(headfile)
                    else:method='rtn'
                else:
                    suffix=key.split('.',3)[3].removesuffix('.weight')
                    cap=CAPTURE/f'layer{layer:02}.npz'
                    with np.load(cap) as z:
                        bits=z['train_'+GROUPS[suffix]].copy().view(np.int16)
                    x=torch.from_numpy(bits).view(torch.bfloat16).to(device='cuda',dtype=torch.float32)
                    capture_sha=sha(cap)
            started=time.time()
            image=quantize(w,method=method,rotation_block=a.rotation or None,X=x,H=h,seed=20260923,damp=a.damp,row_chunk=4096)
            payload=packed(image,path)
            rec=dict(key=key,method=a.method,effective_method=method,rotation_block=a.rotation,damp=a.damp,
                     parameters=w.numel(),shape=list(w.shape),payload_bytes=payload,file_bytes=path.stat().st_size,
                     sha256=sha(path),capture_sha256=capture_sha,source_sha256=sha(Path(__file__)),
                     quantizer_sha256=sha(Path(__file__).with_name('quantize.py')),seconds=time.time()-started)
            receipt.write_text(json.dumps(rec,indent=2)+'\n')
            print(json.dumps(rec),flush=True)
            del w,image,x,h
        norms={k:f.get_tensor(k).view(torch.int16).numpy() for k in f.keys() if len(f.get_slice(k).get_shape())!=2}
    np.savez(out/'norms.npz',**norms)
    records=[json.loads(p.read_text()) for p in out.glob('model*.json')]
    manifest=dict(model_source_sha256=sha(MODEL/'source.json'),matrices=records,matrix_count=len(records),
                  complete=len(records)==197,norm_bytes=sum(v.nbytes for v in norms.values()),
                  payload_bytes=sum(r['payload_bytes'] for r in records)+sum(v.nbytes for v in norms.values()),
                  unique_parameters=596049920,packing='five trits per byte, FP16 scale per128, packed rotation signs; no hidden full-precision matrices')
    manifest['bpw']=8*manifest['payload_bytes']/manifest['unique_parameters']
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

def load_model():
    return AutoModelForCausalLM.from_pretrained(MODEL,local_files_only=True,dtype=torch.bfloat16,attn_implementation='sdpa').eval().to('cuda')

@torch.inference_mode()
def evaluate(a):
    model=load_model()
    out=ROOT/a.name
    if a.name=='scalar4':
        import sys
        sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'quantization-discovery/subbit'))
        from spectral_quant import decode
        accounting=json.loads((DATA/'full-scalar/accounting.json').read_text())
        for entry in accounting['entries']:
            if entry['bits']!=4:continue
            path=DATA/'full-scalar'/(entry['name'].replace('.','_')+'-g128-b4.npz')
            if sha(path)!=entry['sha256']:raise ValueError('scalar control changed')
            with np.load(path) as f:w=decode(f,'weight')
            model.get_parameter(entry['name']).copy_(w)
        manifest={'bpw':4.12635}
    elif a.name!='reference':
        manifest=json.loads((out/'manifest.json').read_text())
        if not manifest['complete']:raise ValueError('Need complete image')
        for r in manifest['matrices']:
            if a.scope=='body' and r['key']=='model.embed_tokens.weight':continue
            if a.scope=='tied' and r['key']!='model.embed_tokens.weight':continue
            path=out/(r['key'].replace('.','_')+'.npz')
            if sha(path)!=r['sha256']:raise ValueError('image hash mismatch')
            model.get_parameter(r['key']).copy_(expanded(path))
        if model.lm_head.weight.data_ptr()!=model.model.embed_tokens.weight.data_ptr():raise ValueError('Expected tied embedding/head')
    else:manifest={'bpw':16}
    with np.load(ROOT/'tokens.npz') as z:tokens=z[a.split][a.offset:a.offset+a.windows].copy()
    result=dict(arm=a.name,scope=a.scope,split=a.split,offset=a.offset,source_sha256=sha(Path(__file__)),
                tokens_sha256=sha(ROOT/'tokens.npz'),model_source_sha256=sha(MODEL/'source.json'),
                image_manifest_sha256=sha(out/'manifest.json') if a.name not in ('reference','scalar4') else None,
                complete_image_bpw=manifest['bpw'],execution='expanded BF16 quality evaluation, not packed runtime speed',windows=[])
    for index,row in enumerate(tokens):
        x=torch.tensor(row,device='cuda',dtype=torch.long)[None]
        logits=model(x,use_cache=False).logits[:,:-1].float()
        loss=torch.nn.functional.cross_entropy(logits.reshape(-1,logits.shape[-1]),x[:,1:].reshape(-1),reduction='sum')
        result['windows'].append(dict(index=a.offset+index,predictions=len(row)-1,nll_sum=float(loss)))
        del logits,loss
    result['nll']=sum(r['nll_sum'] for r in result['windows'])/sum(r['predictions'] for r in result['windows'])
    result['perplexity']=math.exp(result['nll'])
    destination=ROOT/'quality'/f'{a.name}-{a.scope}-{a.split}-{a.offset}-{len(tokens)}.json'
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result),flush=True)

@torch.inference_mode()
def head_hessian(a):
    model=load_model();h=torch.zeros((1024,1024),device='cuda');count=0
    with np.load(ROOT/'tokens.npz') as z:rows=z['train'][:16].copy()
    for row in rows:
        x=torch.tensor(row,device='cuda',dtype=torch.long)[None]
        y=model.model(x,use_cache=False).last_hidden_state.reshape(-1,1024).float()
        h.add_(y.T@y);count+=len(y)
    h/=count
    h+=torch.eye(1024,device='cuda')*(h.diagonal().mean()*.1)
    torch.save(h.cpu(),ROOT/'head-hessian.pt')
    print(json.dumps({'path':str(ROOT/'head-hessian.pt'),'rows':count,'isotropic_fraction':.1}),flush=True)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['fit','evaluate','head-hessian'])
    p.add_argument('--name',default='reference');p.add_argument('--method',choices=['rtn','gptq'],default='rtn')
    p.add_argument('--rotation',type=int,default=0);p.add_argument('--start',type=int,default=0);p.add_argument('--end',type=int,default=28)
    p.add_argument('--embedding',action='store_true');p.add_argument('--head-gptq',action='store_true');p.add_argument('--damp',type=float,default=.01)
    p.add_argument('--split',choices=['train','validation','test'],default='validation');p.add_argument('--windows',type=int,default=8)
    p.add_argument('--offset',type=int,default=0);p.add_argument('--scope',choices=['complete','body','tied'],default='complete')
    a=p.parse_args();torch.set_num_threads(4);torch.backends.cuda.matmul.allow_tf32=False
    if a.action=='fit':fit(a)
    elif a.action=='evaluate':evaluate(a)
    else:head_hessian(a)

if __name__=='__main__':main()
