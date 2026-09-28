#!/usr/bin/env python3
"""Continued greedy generation with ancestor-masked verification and KV adoption."""
import argparse
import contextlib
import hashlib
import heapq
import importlib.util
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch.nn.attention import SDPBackend, sdpa_kernel

HERE = Path(__file__).resolve().parent
DATA = Path('/path/to/workspace/data/kelana-speculative')
OUT = DATA / 'online'
spec = importlib.util.spec_from_file_location('residual', HERE.parent/'residual-drafter/experiment.py')
residual = importlib.util.module_from_spec(spec)
spec.loader.exec_module(residual)


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def sync_time():
    torch.cuda.synchronize()
    return time.perf_counter()


def draft(model, hidden, root, lookup, budget, chain=False):
    base, gate = model.backbone(hidden.float().cpu()[None])
    base, gate = base[0], gate[0]
    pools = base.topk(16, dim=-1).indices
    known = int(lookup[root])
    codes = [(known,)]
    tokens = [root]
    parents = [-1]
    row_cache = {}
    def children(prefix):
        d = len(prefix)-1
        key = (d,prefix[-1])
        if key not in row_cache:
            values = model.logits(base[d],gate[d],torch.tensor(prefix[-1])).log_softmax(-1)
            row_cache[key] = [(int(i),float(values[i])) for i in pools[d]]
        return row_cache[key]
    if chain:
        while len(codes) < min(budget,6):
            token,_ = max(children(codes[-1]),key=lambda v:(v[1],-v[0]))
            parents.append(len(codes)-1)
            codes.append(codes[-1]+(token,))
            tokens.append(int(model.vocabulary[token]))
    elif budget>1:
        heap = [(-p,(known,t),0) for t,p in children(codes[0])]
        heapq.heapify(heap)
        while heap and len(codes)<budget:
            neg,prefix,parent = heapq.heappop(heap)
            idx = len(codes)
            codes.append(prefix)
            tokens.append(int(model.vocabulary[prefix[-1]]))
            parents.append(parent)
            if len(prefix)<6:
                for t,p in children(prefix):
                    heapq.heappush(heap,(neg-p,prefix+(t,),idx))
    return tokens,parents,[len(p)-1 for p in codes],len(row_cache)


def mask_and_positions(parents, depths, length, dtype):
    n = len(parents)
    mask = torch.full((n,length+n),torch.finfo(dtype).min,dtype=dtype)
    mask[:,:length] = 0
    for i in range(n):
        j = i
        while j >= 0:
            mask[i,length+j] = 0
            j = parents[j]
    return mask[None,None].cuda(),torch.tensor([[length+d for d in depths]],device='cuda')


def adopt(cache, length, path):
    indices = torch.tensor(list(range(length))+[length+i for i in path],device='cuda')
    for layer in cache.layers:
        layer.keys = layer.keys.index_select(2,indices)
        layer.values = layer.values.index_select(2,indices)


@torch.inference_mode()
def generate(target, producer, lookup, prompt, count, method, head_rows=False, retrieval=None, allocation=None, proposal_fn=None):
    prefill_start=sync_time()
    initial = target.model(prompt[None].cuda(),use_cache=True)
    hidden,cache = initial.last_hidden_state[0,-1],initial.past_key_values
    pending = int(target.lm_head(hidden).argmax(-1))
    emitted=[]
    bills=[]
    begun=sync_time()
    prefill_s=begun-prefill_start
    while len(emitted)<count:
        start=sync_time()
        length=cache.get_seq_length()
        actual_method=method
        policy_action=None
        if proposal_fn is not None:
            tokens,parents,depths,rows=proposal_fn(hidden,pending,prompt.tolist()+emitted)
            if len(tokens)==1:actual_method='serial'
        elif method in ('serial','serial-mask'):
            tokens,parents,depths,rows=[pending],[-1],[0],0
        elif method=='policy' or method.startswith('fixed'):
            module,policy=allocation
            if method=='policy':
                action,tokens,parents,depths,rows=module.online_draft(producer,hidden,pending,lookup,policy)
            else:
                shape='depth' if method.endswith('depth') else 'breadth' if method.endswith('breadth') else 'mass'
                action=module.Action(int(''.join(c for c in method if c.isdigit())),shape)
                base,gate=producer.backbone(hidden.float().cpu()[None])
                proposed=module.propose(producer,base[0],gate[0],int(lookup[pending]),action)
                tokens=[pending]+[int(producer.vocabulary[p[-1]]) for p in proposed['ordered'][1:]]
                parents,depths,rows=proposed['parents'],[len(p)-1 for p in proposed['ordered']],proposed['rows']
            policy_action={'budget':action.budget,'shape':action.shape}
            if not action.budget:actual_method='serial'
        else:
            budget=6 if method=='chain6' else int(method[5:] if method.startswith('graft') else method[4:])
            tokens,parents,depths,rows=draft(producer,hidden,pending,lookup,budget,method=='chain6')
            if method.startswith('graft'):
                proposals,_=retrieval.propose(prompt.tolist()+emitted,pending)
                if proposals:
                    learned=[]
                    for i,token in enumerate(tokens):
                        learned.append((token,) if parents[i]<0 else learned[parents[i]]+(token,))
                    ordered=[(pending,)]
                    indices={ordered[0]:0}
                    for path in [tuple(proposals[0]['path'][:2])]+learned[1:]:
                        if path in indices:continue
                        assert path[:-1] in indices
                        indices[path]=len(ordered)
                        ordered.append(path)
                        if len(ordered)==budget:break
                    tokens=[p[-1] for p in ordered]
                    parents=[-1]+[indices[p[:-1]] for p in ordered[1:]]
                    depths=[len(p)-1 for p in ordered]
        after_draft=sync_time()
        if actual_method=='serial':
            out=target.model(torch.tensor([tokens],device='cuda'),past_key_values=cache,use_cache=True)
        else:
            mask,positions=mask_and_positions(parents,depths,length,target.dtype)
            out=target.model(torch.tensor([tokens],device='cuda'),attention_mask=mask,
                             position_ids=positions,past_key_values=cache,use_cache=True)
        if head_rows:
            choices=[int(target.lm_head(h).argmax(-1)) for h in out.last_hidden_state[0]]
        else:
            choices=target.lm_head(out.last_hidden_state[0]).argmax(-1).cpu().tolist()
        after_target=sync_time()
        path=[0]
        while len(path)<count-len(emitted):
            wanted=choices[path[-1]]
            match=next((i for i,p in enumerate(parents) if p==path[-1] and tokens[i]==wanted),None)
            if match is None:break
            path.append(match)
        hidden=out.last_hidden_state[0,path[-1]]
        pending=int(choices[path[-1]])
        cache=out.past_key_values
        if actual_method not in ('serial','serial-mask'):adopt(cache,length,path)
        emitted.extend(tokens[i] for i in path)
        end=sync_time()
        assert cache.get_seq_length()==len(prompt)+len(emitted)
        bills.append({'draft_s':after_draft-start,'verify_s':after_target-after_draft,
                      'adopt_s':end-after_target,'cycle_s':end-start,'nodes':len(tokens),
                      'progress':len(path),'corrected_rows':rows,'policy_action':policy_action})
    elapsed=sync_time()-begun
    return {'tokens':emitted,'elapsed_s':elapsed,'prefill_s':prefill_s,'request_s':prefill_s+elapsed,'tokens_per_second':len(emitted)/elapsed,
            'cycles':bills,'next_token':pending,'cache_length':cache.get_seq_length()}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--contexts',type=int,default=2)
    parser.add_argument('--tokens',type=int,default=24)
    parser.add_argument('--methods',default='serial,chain6,tree6,tree18')
    parser.add_argument('--tag',default='panel')
    parser.add_argument('--repeat',type=int,default=1)
    parser.add_argument('--dtype',choices=('bfloat16','float32'),default='bfloat16')
    parser.add_argument('--head-rows',action='store_true')
    parser.add_argument('--producer',choices=('residual','direct','rollout'),default='residual')
    parser.add_argument('--sdpa',choices=('default','math'),default='default')
    args=parser.parse_args()
    torch.set_num_threads(4)
    OUT.mkdir(parents=True,exist_ok=True)
    tokenizer,target=residual.load_target()
    if args.dtype=='float32':target=target.float()
    if args.producer in ('direct','rollout'):
        direct_spec=importlib.util.spec_from_file_location('direct_producer',HERE.parent/'direct-producer/experiment.py')
        direct=importlib.util.module_from_spec(direct_spec)
        direct_spec.loader.exec_module(direct)
        checkpoint=DATA/('rollout-producer/direct-mixed-s160.pt' if args.producer=='rollout' else 'direct-producer/direct-s200.pt')
        producer=direct.Direct().eval()
    else:
        checkpoint=DATA/'residual-drafter/residual-v4096-s200.pt'
        producer=residual.Residual(4096).eval()
    state=torch.load(checkpoint,map_location='cpu',weights_only=True)
    producer.load_state_dict(state)
    lookup=torch.full((151936,),len(state['vocabulary']),dtype=torch.long)
    lookup[state['vocabulary']]=torch.arange(len(state['vocabulary']))
    corpus=residual.CORPUS/'test.txt'
    ids=tokenizer(corpus.read_text(),add_special_tokens=False)['input_ids']
    used=set(json.loads((DATA/'test-greedy.json').read_text())['starts'])
    eligible=[s for s in range(0,len(ids)-128,128) if s not in used]
    starts=np.random.default_rng(2026092321).choice(eligible,args.contexts,replace=False).tolist()
    methods=args.methods.split(',')
    retrieval=None
    allocation=None
    preparation={}
    if any(m.startswith('graft') for m in methods):
        module_spec=importlib.util.spec_from_file_location('retrieved_candidates',HERE.parent/'retrieved-spans/candidates.py')
        module=importlib.util.module_from_spec(module_spec)
        sys.modules[module_spec.name]=module
        module_spec.loader.exec_module(module)
        start=time.perf_counter()
        token_path=DATA/'retrieved-spans/train-token-ids.npy'
        retrieval=module.SpanIndex(np.load(token_path))
        preparation['retrieval']={'seconds':time.perf_counter()-start,'bytes':retrieval.bytes,'token_cache_sha256':sha(token_path),'source_sha256':sha(module_spec.origin)}
    if 'policy' in methods or any(m.startswith('fixed') for m in methods):
        module_spec=importlib.util.spec_from_file_location('measured_policy',HERE.parent/'measured-policy/policy.py')
        module=importlib.util.module_from_spec(module_spec)
        sys.modules[module_spec.name]=module
        module_spec.loader.exec_module(module)
        policy_path=HERE.parent/'measured-policy'/(('residual' if args.producer=='residual' else 'direct')+'-results.json')
        allocation=(module,module.load_policy(policy_path))
        preparation['policy']={'receipt_sha256':sha(policy_path),'source_sha256':sha(module_spec.origin)}
    results=[]
    for repeat in range(args.repeat):
        for index,start in enumerate(starts):
            prompt=torch.tensor(ids[start:start+64])
            arms={}
            rotated=methods[repeat%len(methods):]+methods[:repeat%len(methods)]
            for method in rotated:
                backend=sdpa_kernel(SDPBackend.MATH) if args.sdpa=='math' else contextlib.nullcontext()
                with backend:
                    result=generate(target,producer,lookup,prompt,args.tokens,method,args.head_rows,retrieval,allocation)
                arms[method]=result
                print(json.dumps({'repeat':repeat,'context':index,'method':method,
                                  'tps':result['tokens_per_second'],'cycles':len(result['cycles'])}),flush=True)
            if 'serial' in arms:
                reference=arms['serial']['tokens']
                for method,result in arms.items():
                    result['matches_serial']=result['tokens']==reference
                    result['first_difference']=next((i for i,(a,b) in enumerate(zip(reference,result['tokens'])) if a!=b),None)
            results.append({'repeat':repeat,'context_start':start,'arms':arms})
    record={'source_sha256':sha(__file__),'checkpoint_sha256':sha(checkpoint),'corpus_sha256':sha(corpus),
            'target_revision':json.loads((residual.MODEL/'source.json').read_text())['revision'],
            'producer_source_sha256':sha(HERE.parent/('residual-drafter' if args.producer=='residual' else 'direct-producer')/'experiment.py'),
            'arguments':vars(args),'starts':starts,'results':results,'preparation':preparation,
            'contract':'Declared-dtype greedy continued generation. Ancestor mask and gathered per-layer KV. Batch/serial rounding may differ; equality recorded, not assumed. Each emitted token is consumed, no free terminal bonus. Initial prefill excluded equally. CPU drafter and transfers, mask construction, target full head and KV gathering included in cycle wall time.'}
    (OUT/(args.tag+'.json')).write_text(json.dumps(record,indent=2)+'\n')
    (OUT/'sources').mkdir(exist_ok=True)
    (OUT/'sources'/(sha(__file__)+'.py')).write_bytes(Path(__file__).read_bytes())


if __name__=='__main__':main()
