#!/usr/bin/env python3
"""Larger-model JSON conversion under a lazy full-byte-language grammar."""
import argparse
import json
import time
from pathlib import Path
import torch
from transformers import AutoTokenizer,AutoModelForCausalLM
from benchmark import module,online,HERE,OUT,MODELS


@torch.inference_mode()
def generate(target,tokenizer,prompt,trie,grammar_module,count,contract):
    prep=time.perf_counter()
    grammar=grammar_module.StructuredRuntime(trie,min_records=count,max_records=count,name_max=8,message_max=24)
    grammar_prep=time.perf_counter()-prep
    started=online.sync_time()
    initial=target.model(prompt[None].cuda(),use_cache=True)
    hidden,cache=initial.last_hidden_state[0,-1],initial.past_key_values
    begun=online.sync_time()
    state=grammar.root
    emitted=[]
    bills=[]
    while not grammar.accepting(state) and len(emitted)<768:
        t0=online.sync_time()
        allowed=grammar.allowed(state)
        if not allowed:raise AssertionError('Live grammar state has no continuation')
        ids=sorted(allowed)
        branch=len(ids)>1
        if branch:
            logits=target.lm_head(hidden)
            token=ids[int(logits[ids].argmax())]
        else:token=ids[0]
        state=allowed[token]
        chunk=[token]
        if contract:
            forced,state=grammar.singleton_run(state)
            chunk.extend(forced)
        t1=online.sync_time()
        output=target.model(torch.tensor([chunk],device='cuda'),past_key_values=cache,use_cache=True)
        hidden,cache=output.last_hidden_state[0,-1],output.past_key_values
        emitted.extend(chunk)
        t2=online.sync_time()
        bills.append({'tokens':len(chunk),'allowed_count':len(ids),'branch':branch,'choose_s':t1-t0,'body_s':t2-t1})
    end=online.sync_time()
    accepted=grammar.accepting(state)
    text=tokenizer.decode(emitted)
    value=json.loads(text) if accepted else None
    next_token=int(target.lm_head(hidden).argmax())
    assert cache.get_seq_length()==len(prompt)+len(emitted)
    return {'tokens':emitted,'text':text,'value':value,'accepted':accepted,'prefill_s':begun-started,
            'decode_s':end-begun,'request_s':end-started,'grammar_prepare_s':grammar_prep,
            'tokens_per_second':len(emitted)/(end-begun),'cycles':bills,'next_token':next_token,
            'grammar_cache':grammar.cache_stats()}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--records',type=int,choices=(2,4),default=2)
    parser.add_argument('--reverse',action='store_true')
    parser.add_argument('--tag',required=True)
    args=parser.parse_args()
    torch.set_num_threads(4)
    OUT.mkdir(parents=True,exist_ok=True)
    model_path=MODELS/'qwen3-1.7b'
    tokenizer=AutoTokenizer.from_pretrained(model_path,local_files_only=True)
    model=AutoModelForCausalLM.from_pretrained(model_path,local_files_only=True,dtype=torch.bfloat16,attn_implementation='sdpa').eval().cuda().float()
    grammar_module=module('structured_grammar',HERE.parent/'structured-runtime/grammar.py')
    tokens_module=module('token_support',HERE.parent/'tokenizer-spans/measure.py')
    prepare=time.perf_counter()
    trie,_=tokens_module.vocabulary(json.loads((model_path/'tokenizer.json').read_text()))
    vocabulary_prepare_s=time.perf_counter()-prepare
    expected=[{'action':'call','name':'build','id':17,'message':'compile package','value':3},
              {'action':'notify','name':'deploy','id':208,'message':'ready for review','value':12},
              {'action':'cancel','name':'backup','id':-9,'message':'disk is full','value':0},
              {'action':'call','name':'check','id':4051,'message':'test quoted "input"','value':-2}][:args.records]
    lines=['action|name|id|message|value']+['|'.join(str(row[k]) for k in ('action','name','id','message','value')) for row in expected]
    instruction='Convert these pipe-separated tool records into a compact JSON array. Preserve every field value and row order. Use exactly the keys action, name, id, message, value in that order. id and value are integers; the other fields are strings. Return only JSON, no explanation.\n\n'+'\n'.join(lines)
    prompt=torch.tensor(tokenizer.apply_chat_template([{'role':'user','content':instruction}],tokenize=True,add_generation_prompt=True,enable_thinking=False))
    results={}
    for arm in (('contract','serial') if args.reverse else ('serial','contract')):
        result=generate(model,tokenizer,prompt,trie,grammar_module,args.records,arm=='contract')
        result['task_exact']=result['value']==expected
        results[arm]=result
        print(json.dumps({'arm':arm,'tokens':len(result['tokens']),'cycles':len(result['cycles']),'tps':result['tokens_per_second'],'task_exact':result['task_exact'],'accepted':result['accepted']}),flush=True)
    receipt={'source_sha256':online.sha(__file__),'grammar_source_sha256':online.sha(HERE.parent/'structured-runtime/grammar.py'),
             'target_revision':json.loads((model_path/'source.json').read_text())['revision'],'arguments':vars(args),
             'prompt':instruction,'prompt_tokens':len(prompt),'expected':expected,'vocabulary_prepare_s':vocabulary_prepare_s,
             'results':results,'tokens_match':results['serial']['tokens']==results['contract']['tokens'],
             'next_match':results['serial']['next_token']==results['contract']['next_token'],
             'contract':'FP32-promoted Qwen1.7B; locally masked greedy over full ordinary-vocabulary byte support of a lazy bounded JSON schema. No enumeration of full outputs. Fresh grammar/cache each arm; lazy support work included in generation time, tokenizer trie preparation separate. Terminal grammar acceptance stops output, no EOS token. JSON syntax and task-exact field equality recorded separately.'}
    (OUT/(args.tag+'.json')).write_text(json.dumps(receipt,indent=2)+'\n')
    (OUT/'sources').mkdir(exist_ok=True)
    (OUT/'sources'/(online.sha(__file__)+'.py')).write_bytes(Path(__file__).read_bytes())


if __name__=='__main__':main()
