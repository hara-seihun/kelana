#!/usr/bin/env python3
"""Frozen public prompts, longer continuations and a larger target, complete cycle cost."""
import argparse
import importlib.util
import json
import sys
import time
from pathlib import Path
import numpy as np
import torch
from transformers import AutoModelForCausalLM,AutoTokenizer

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-speculative')
OUT=DATA/'realistic-runtime'
MODELS=Path('/path/to/workspace/data/kelana-subbit/models')


def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    value=importlib.util.module_from_spec(spec)
    sys.modules[name]=value
    spec.loader.exec_module(value)
    return value


online=module('speculative_online',HERE.parent/'online/experiment.py')
copy=module('retrieved_candidates',HERE.parent/'retrieved-spans/candidates.py')


def copy_proposal(index,hidden,pending,visible,budget=18):
    candidates,_=index.propose(visible,pending)
    paths=copy.copy_tree(pending,candidates,budget)
    lookup={p:i for i,p in enumerate(paths)}
    return [p[-1] for p in paths],[-1]+[lookup[p[:-1]] for p in paths[1:]],[len(p)-1 for p in paths],0


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--manifest',type=Path,required=True)
    parser.add_argument('--model',choices=('qwen3-0.6b','qwen3-1.7b'),default='qwen3-1.7b')
    parser.add_argument('--offset',type=int,default=0)
    parser.add_argument('--count',type=int,default=2)
    parser.add_argument('--stride',type=int,default=1)
    parser.add_argument('--tokens',type=int,default=64)
    parser.add_argument('--methods',default='serial,copy18')
    parser.add_argument('--reverse',action='store_true')
    parser.add_argument('--dtype',choices=('float32','bfloat16'),default='float32')
    parser.add_argument('--tag',required=True)
    args=parser.parse_args()
    torch.set_num_threads(4)
    OUT.mkdir(parents=True,exist_ok=True)
    manifest=json.loads(args.manifest.read_text())
    cases=manifest['cases'][args.offset:args.offset+args.count*args.stride:args.stride]
    model_path=MODELS/args.model
    target=AutoModelForCausalLM.from_pretrained(model_path,local_files_only=True,dtype=torch.bfloat16,attn_implementation='sdpa').eval().cuda()
    if args.dtype=='float32':target=target.float()
    index_start=time.perf_counter()
    corpus=DATA/'retrieved-spans/train-token-ids.npy'
    index=copy.SpanIndex(np.load(corpus))
    index_prep=time.perf_counter()-index_start
    producer=lookup=None
    checkpoint=None
    if any(m in args.methods for m in ('tree','graft')):
        if args.model!='qwen3-0.6b':raise ValueError('Learned checkpoint belongs to Qwen0.6B hidden coordinates')
        direct=module('direct_producer',HERE.parent/'direct-producer/experiment.py')
        producer=direct.Direct().eval()
        checkpoint=DATA/'rollout-producer/direct-mixed-s160.pt'
        producer.load_state_dict(torch.load(checkpoint,weights_only=True,map_location='cpu'))
        lookup=torch.full((151936,),4096,dtype=torch.long)
        lookup[producer.vocabulary]=torch.arange(4096)
    methods=args.methods.split(',')
    if args.reverse:methods.reverse()
    records=[]
    progress_path=OUT/(args.tag+'.progress.json')
    for case in cases:
        tokens=case['token_ids']
        prompt=torch.tensor(tokens,dtype=torch.long)
        arms={}
        for method in methods:
            proposal=(lambda hidden,root,visible:copy_proposal(index,hidden,root,visible,int(method[4:]))) if method.startswith('copy') else None
            result=online.generate(target,producer,lookup,prompt,args.tokens,method,retrieval=index,proposal_fn=proposal)
            arms[method]=result
            print(json.dumps({'case':case['id'],'context_tokens':len(tokens),'model':args.model,'method':method,
                              'decode_tps':result['tokens_per_second'],'prefill_s':result['prefill_s'],'cycles':len(result['cycles'])}),flush=True)
        reference=arms['serial']['tokens']
        for method,result in arms.items():
            result['matches_serial']=result['tokens']==reference
            result['next_matches_serial']=result['next_token']==arms['serial']['next_token']
            result['first_difference']=next((i for i,(a,b) in enumerate(zip(reference,result['tokens'])) if a!=b),None)
        records.append({'case_id':case['id'],'family':case['family'],'context_tokens':len(tokens),'arms':arms})
        progress_path.write_text(json.dumps({'source_sha256':online.sha(__file__),'manifest_sha256':online.sha(args.manifest),'model':args.model,'records':records},indent=2)+'\n')
    receipt={'source_sha256':online.sha(__file__),'online_source_sha256':online.sha(HERE.parent/'online/experiment.py'),
             'retrieval_source_sha256':online.sha(HERE.parent/'retrieved-spans/candidates.py'),
             'manifest_sha256':online.sha(args.manifest),'model_source_sha256':online.sha(model_path/'source.json'),
             'target_revision':json.loads((model_path/'source.json').read_text())['revision'],
             'unique_parameters':sum(p.numel() for p in target.parameters()),'arguments':vars(args)|{'manifest':str(args.manifest)},
             'index':{'preparation_s':index_prep,'bytes':index.bytes,'tokens_sha256':online.sha(corpus)},
             'producer_checkpoint':None if checkpoint is None else {'path':str(checkpoint),'sha256':online.sha(checkpoint)},
             'records':records,
             'contract':'Fixed output token count, greedy target. Prompt prefill/first pending decision measured separately and included in request_s. Complete draft, verification and KV adoption timed. Dtype promoted from pinned BF16 checkpoint when float32. No target labels used by proposal. Observed serial and next-decision equality reported, not assumed.'}
    (OUT/(args.tag+'.json')).write_text(json.dumps(receipt,indent=2)+'\n')
    progress_path.unlink(missing_ok=True)
    (OUT/'sources').mkdir(exist_ok=True)
    for path in [Path(__file__),HERE.parent/'online/experiment.py']:
        (OUT/'sources'/(online.sha(path)+'.py')).write_bytes(path.read_bytes())


if __name__=='__main__':main()
