#!/usr/bin/env python3
"""Reforward paid body/head/embedding images through Qwen for model quality, not speed."""
import argparse
import json
import math
import shutil
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from capture import ROOT, MODEL, TOKENS, sha
from image import binary_weight, head_weight


@torch.inference_mode()
def run(args):
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32=False
    model=AutoModelForCausalLM.from_pretrained(MODEL,local_files_only=True,dtype=torch.bfloat16,
                                              attn_implementation='sdpa').eval().to('cuda')
    unique=sum(p.numel() for p in model.parameters())
    original={name:p.detach().cpu().clone() for name,p in model.named_parameters()}
    original_tied=original['model.embed_tokens.weight']
    model.lm_head.weight=torch.nn.Parameter(model.lm_head.weight.detach().clone(),requires_grad=False)
    head_record=json.loads((args.image/'head.json').read_text())
    if sha(args.image/head_record['path'])!=head_record['sha256']:raise ValueError('head image identity changed')
    head,rare,correction=head_weight(args.image/head_record['path'])
    manifest_path=args.image/'manifest.json'
    manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else None
    if any(a in ('body','complete') for a in args.arms) and manifest is None:
        raise ValueError('body arms require a complete image manifest')
    with np.load(args.tokens) as f: tokens={s:f[s].copy()[:args.windows] for s in args.splits}
    with np.load(ROOT/'tied-head/frequency.npz') as f:
        frequency=torch.from_numpy(f['train'].copy()).to('cuda')
    reference={};result={'format':'qwen-complete-image-quality/1','model_source_sha256':sha(MODEL/'source.json'),
        'tokens':str(args.tokens),'tokens_sha256':sha(args.tokens),'unique_parameters':unique,
        'image':str(args.image),'body_scope':args.body_scope,'head_receipt_sha256':sha(args.image/'head.json'),
        'manifest_sha256':sha(manifest_path) if manifest else None,
        'source_hashes':{p.name:sha(p) for p in (Path(__file__),Path(__file__).with_name('image.py'))},
        'torch':torch.__version__,'hip':torch.version.hip,'device':torch.cuda.get_device_name(),
        'execution':'expanded BF16 weights for quality only; quantized embeddings actually enter every forward; no compressed-runtime timing',
        'arm_semantics':{'head':'original embeddings, quantized head plus rare correction; separate images paid',
                         'embedding':'quantized embeddings, original head; separate images paid',
                         'tied':'one quantized image used for embedding and head, plus rare head correction',
                         'body':'196 quantized body matrices, original tied embedding/head',
                         'complete':'196 quantized body matrices and shared quantized embedding/head'},'arms':[]}
    args.out.parent.mkdir(parents=True,exist_ok=True)
    source_dir=args.out.parent/'sources';source_dir.mkdir(exist_ok=True)
    for name,digest in result['source_hashes'].items():
        shutil.copy2(Path(__file__).with_name(name),source_dir/(digest+'-'+name))
    for arm in args.arms:
        if manifest:
            for entry in manifest['body']:
                module=model.get_submodule(entry['key'].rsplit('.',1)[0])
                if entry['key'].rsplit('.',1)[0]+'.bias' not in original:module.bias=None
        for name,p in model.named_parameters():
            p.copy_(original_tied if name=='lm_head.weight' else original[name])
        body_active=arm in ('body','complete')
        head_active=arm in ('head','tied','complete')
        embedding_active=arm in ('embedding','tied','complete')
        payload=2*unique
        if body_active:
            for entry in manifest['body']:
                if args.body_scope=='attention' and '.self_attn.' not in entry['key']:continue
                if args.body_scope=='mlp' and '.mlp.' not in entry['key']:continue
                if args.body_scope=='query-key' and not any('.self_attn.'+p in entry['key'] for p in ('q_proj','k_proj')):continue
                if args.body_scope=='value-output' and not any('.self_attn.'+p in entry['key'] for p in ('v_proj','o_proj')):continue
                path=args.image/entry['path']
                if sha(path)!=entry['sha256']:raise ValueError(f'changed image {path}')
                model.get_parameter(entry['key']).copy_(binary_weight(path))
                with np.load(path) as f:
                    if 'bias' in f.files:
                        module=model.get_submodule(entry['key'].rsplit('.',1)[0])
                        module.bias=torch.nn.Parameter(torch.from_numpy(f['bias'].copy()).to(device='cuda',dtype=torch.bfloat16),requires_grad=False)
                payload+=entry['payload_bytes']-2*entry['parameters']
            with np.load(args.image/manifest['norms']['path']) as f:
                for name in f.files:
                    value=torch.from_numpy(f[name].view(np.int16).copy()).view(torch.bfloat16)
                    model.get_parameter(name).copy_(value)
        if embedding_active:model.model.embed_tokens.weight.copy_(head)
        if head_active:model.lm_head.weight.copy_(head)
        if head_active and embedding_active:
            payload+=head_record['payload_bytes']-2*head_record['parameters']
        elif head_active or embedding_active:
            payload+=head_record['payload_bytes']-(0 if head_active else 8)
        record={'arm':arm,'payload_bytes':payload,'all_unique_parameter_bpw':8*payload/unique,'splits':{}}
        for split,batch in tokens.items():
            rows=[]
            for index,row in enumerate(batch):
                x=torch.tensor(row,device='cuda',dtype=torch.long).unsqueeze(0)
                logits=model(x,use_cache=False).logits[0,:-1].float()
                if head_active:logits[:,rare]=logits[:,rare]*float(correction[0])+float(correction[1])
                logp=logits.log_softmax(-1);targets=x[0,1:]
                nll=-logp.gather(1,targets[:,None]).squeeze(1)
                if arm=='reference':reference[split,index]=logp.cpu()
                teacher=reference[split,index].to('cuda')
                kl=(teacher.exp()*(teacher-logp)).sum(-1)
                counts=frequency[targets]
                masks={'unseen':counts==0,'1_to_9':(counts>0)&(counts<10),
                       '10_to_99':(counts>=10)&(counts<100),'100_plus':counts>=100}
                buckets={key:{'predictions':int(mask.sum()),'nll_sum':float(nll[mask].sum())}
                         for key,mask in masks.items()}
                rows.append({'window':index,'predictions':len(targets),'nll_sum':float(nll.sum()),
                             'teacher_kl_sum':float(kl.sum()),'argmax_agreements':int((teacher.argmax(-1)==logp.argmax(-1)).sum()),
                             'target_train_frequency':buckets})
                del logits,logp,teacher
            predictions=sum(r['predictions'] for r in rows)
            nll=sum(r['nll_sum'] for r in rows)/predictions
            record['splits'][split]={'predictions':predictions,'nll':nll,'perplexity':math.exp(nll),
                'teacher_kl':sum(r['teacher_kl_sum'] for r in rows)/predictions,
                'argmax_agreement':sum(r['argmax_agreements'] for r in rows)/predictions,'windows':rows}
        result['arms'].append(record)
        args.out.write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps({'arm':arm,'bpw':record['all_unique_parameter_bpw'],
                          'splits':{s:{k:v for k,v in metrics.items() if k!='windows'} for s,metrics in record['splits'].items()}}),flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--image',type=Path,required=True)
    p.add_argument('--body-scope',choices=['all','attention','mlp','query-key','value-output'],default='all')
    p.add_argument('--tokens',type=Path,default=TOKENS)
    p.add_argument('--splits',nargs='+',default=['validation','test'])
    p.add_argument('--windows',type=int,default=4)
    p.add_argument('--arms',nargs='+',choices=['reference','head','embedding','tied','body','complete'],
                   default=['reference','head','embedding','tied'])
    p.add_argument('--out',type=Path,required=True)
    args=p.parse_args()
    if not args.arms or args.arms[0]!='reference':p.error('reference must be the first arm')
    run(args)
