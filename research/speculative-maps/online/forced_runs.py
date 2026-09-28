#!/usr/bin/env python3
"""Causal prefill of token-singleton runs in an explicitly token-level JSON grammar."""
import argparse
import hashlib
import importlib.util
import itertools
import json
import time
from pathlib import Path
import torch
import experiment as online


def grammar(tokenizer,repetitions,byte_support=None):
    literal='fixed protocol text '*repetitions
    strings=[json.dumps({'version':1,'kind':kind,'description':literal,'ok':ok,'value':value},separators=(',',':'))
             for kind,ok,value in itertools.product(('alpha','beta'),(True,False),(0,1))]
    if byte_support is not None:
        module,vocab=byte_support
        raw_nodes,_=module.grammar([(text,()) for text in strings])
        module.product(raw_nodes,vocab)
        indices={id(node):i for i,node in enumerate(raw_nodes)}
        return strings,[{token:indices[id(successor)] for token,successor in node['edges']} for node in raw_nodes]
    nodes=[{}]
    for text in strings:
        seq=tokenizer(text,add_special_tokens=False)['input_ids']
        at=0
        for token in seq:
            if token not in nodes[at]:
                nodes[at][token]=len(nodes)
                nodes.append({})
            at=nodes[at][token]
    return strings,nodes


@torch.inference_mode()
def run(model,prompt,nodes,contract):
    out=model.model(prompt[None].cuda(),use_cache=True)
    hidden,cache=out.last_hidden_state[0,-1],out.past_key_values
    at=0
    emitted=[]
    cycles=[]
    start=online.sync_time()
    while nodes[at]:
        begun=online.sync_time()
        allowed=sorted(nodes[at])
        branching=len(allowed)>1
        if branching:
            logits=model.lm_head(hidden)
            selected=allowed[int(logits[allowed].argmax())]
        else:selected=allowed[0]
        chunk=[selected]
        at=nodes[at][selected]
        if contract:
            while len(nodes[at])==1:
                selected=next(iter(nodes[at]))
                chunk.append(selected)
                at=nodes[at][selected]
        out=model.model(torch.tensor([chunk],device='cuda'),past_key_values=cache,use_cache=True)
        hidden,cache=out.last_hidden_state[0,-1],out.past_key_values
        emitted.extend(chunk)
        cycles.append({'tokens':len(chunk),'branch_decision':branching,'seconds':online.sync_time()-begun})
    elapsed=online.sync_time()-start
    next_token=int(model.lm_head(hidden).argmax())
    assert cache.get_seq_length()==len(prompt)+len(emitted)
    return {'tokens':emitted,'elapsed_s':elapsed,'tokens_per_second':len(emitted)/elapsed,
            'next_token':next_token,'cycles':cycles}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--grammar',choices=('canonical','byte'),default='canonical')
    args=parser.parse_args()
    torch.set_num_threads(4)
    tokenizer,model=online.residual.load_target()
    model=model.float()
    prompt=torch.tensor(tokenizer('Return a JSON protocol record.\n',add_special_tokens=False)['input_ids'])
    rows=[]
    prep=time.perf_counter()
    byte_support=None
    if args.grammar=='byte':
        spec=importlib.util.spec_from_file_location('token_support',online.HERE.parent/'tokenizer-spans/measure.py')
        module=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        vocab,_=module.vocabulary(json.loads(module.MODEL.read_text()))
        byte_support=(module,vocab)
    vocabulary_prepare_s=time.perf_counter()-prep
    for repetitions in (1,4,8):
        prep=time.perf_counter()
        strings,nodes=grammar(tokenizer,repetitions,byte_support)
        grammar_prepare_s=time.perf_counter()-prep
        for repeat in range(2):
            arms={}
            for mode in (('serial','contract') if repeat==0 else ('contract','serial')):
                arms[mode]=run(model,prompt,nodes,mode=='contract')
            assert arms['serial']['tokens']==arms['contract']['tokens']
            assert tokenizer.decode(arms['serial']['tokens']) in strings
            rows.append({'literal_repetitions':repetitions,'repeat':repeat,'grammar_nodes':len(nodes),
                         'grammar_prepare_s':grammar_prepare_s,'grammar_token_edges':sum(map(len,nodes)),
                         'strings':strings,'arms':arms,
                         'same_next_token':arms['serial']['next_token']==arms['contract']['next_token']})
            print(repetitions,repeat,{k:(v['tokens_per_second'],len(v['tokens']),len(v['cycles'])) for k,v in arms.items()},flush=True)
    result={'source_sha256':online.sha(__file__),'grammar':args.grammar,'vocabulary_prepare_s':vocabulary_prepare_s,'target':'Pinned BF16 checkpoint promoted to FP32; default SDPA',
            'contract':'Locally masked greedy over eight explicit JSON strings. Canonical mode restricts token IDs to canonical BPE encodings; byte mode admits every ordinary-vocabulary token whose complete bytes remain a valid output prefix. Both arms omit head selection on singleton edges and consume every emitted token into causal KV. Contracted arm prefills known runs. Initial prompt prefill and offline grammar preparation excluded equally.',
            'rows':rows}
    online.OUT.mkdir(parents=True,exist_ok=True)
    (online.OUT/('forced-runs'+('-byte' if args.grammar=='byte' else '')+'.json')).write_text(json.dumps(result,indent=2)+'\n')
    (online.OUT/'sources').mkdir(exist_ok=True)
    (online.OUT/'sources'/(online.sha(__file__)+'.py')).write_bytes(Path(__file__).read_bytes())


if __name__=='__main__':main()
