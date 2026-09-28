#!/usr/bin/env python3
"""Teacher-forced one-row mask diagnosis at identical histories, no draft or KV gather."""
import hashlib
import json
from pathlib import Path
import torch
import experiment as e


@torch.inference_mode()
def main():
    torch.set_num_threads(4)
    tokenizer,model=e.residual.load_target()
    source=e.OUT/'mask-diagnosis.json'
    receipt=json.loads(source.read_text())
    ids=tokenizer((e.residual.CORPUS/'test.txt').read_text(),add_special_tokens=False)['input_ids']
    records=[]
    for row in receipt['results']:
        prompt=torch.tensor([ids[row['context_start']:row['context_start']+64]],device='cuda')
        initial=[model.model(prompt,use_cache=True) for _ in range(3)]
        caches=[x.past_key_values for x in initial]
        modes=['default','positions','mask_and_positions']
        for step,token in enumerate(row['arms']['serial']['tokens']):
            hs=[]
            scores=[]
            for index,mode in enumerate(modes):
                kwargs={}
                length=caches[index].get_seq_length()
                mask,positions=e.mask_and_positions([-1],[0],length,model.dtype)
                if mode!='default':kwargs['position_ids']=positions
                if mode=='mask_and_positions':kwargs['attention_mask']=mask
                out=model.model(torch.tensor([[token]],device='cuda'),past_key_values=caches[index],use_cache=True,**kwargs)
                caches[index]=out.past_key_values
                h=out.last_hidden_state[0,-1]
                logits=model.lm_head(h)
                values,tokens=logits.topk(2)
                scores.append({'choice':int(logits.argmax()),'top2':tokens.cpu().tolist(),'logits':values.float().cpu().tolist()})
                hs.append(h)
            records.append({'context_start':row['context_start'],'consumed_position':step,
                            'modes':dict(zip(modes,scores)),
                            'positions_hidden_max_error':float((hs[0]-hs[1]).abs().max()),
                            'mask_hidden_max_error':float((hs[0]-hs[2]).abs().max())})
    result={'source_sha256':e.sha(__file__),'fixture_sha256':e.sha(source),'records':records,
            'contract':'All three arms consume identical serial reference token IDs. No drafter, tree, or KV gather. BF16 body/head; explicit position IDs separated from additive attention mask.'}
    (e.OUT/'numerics.json').write_text(json.dumps(result,indent=2)+'\n')
    (e.OUT/'sources'/(e.sha(__file__)+'.py')).write_bytes(Path(__file__).read_bytes())
    print(json.dumps([r for r in records if len({v['choice'] for v in r['modes'].values()})>1],indent=2))


if __name__=='__main__':main()
