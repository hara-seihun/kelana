#!/usr/bin/env python3
"""Capture on-trajectory training anchors from FP32 target-generated continuations."""
import argparse
import json
import time
from pathlib import Path
import numpy as np
import torch
import experiment as online


@torch.inference_mode()
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--windows',type=int,default=512)
    parser.add_argument('--steps',type=int,default=16)
    parser.add_argument('--batch',type=int,default=16)
    args=parser.parse_args()
    torch.set_num_threads(4)
    tokenizer,model=online.residual.load_target()
    model=model.float()
    text=online.residual.CORPUS/'train.txt'
    ids=np.asarray(tokenizer(text.read_text(),add_special_tokens=False)['input_ids'])
    excluded=set(json.loads((online.DATA/'train.json').read_text())['starts'])
    excluded.update(json.loads((online.DATA/'residual-drafter/train-target.json').read_text())['starts'])
    starts=np.random.default_rng(2026092341).choice([p for p in range(0,len(ids)-128,128) if p not in excluded],args.windows,replace=False).tolist()
    features=[]
    futures=[]
    begun=time.perf_counter()
    for offset in range(0,len(starts),args.batch):
        contexts=torch.tensor(np.stack([ids[s:s+64] for s in starts[offset:offset+args.batch]]),device='cuda')
        out=model.model(contexts,use_cache=True)
        h,cache=out.last_hidden_state[:,-1],out.past_key_values
        hs=[]
        ys=[]
        for step in range(args.steps):
            hs.append(h.half().cpu())
            token=model.lm_head(h).argmax(-1)
            ys.append(token.cpu())
            if step+1<args.steps:
                out=model.model(token[:,None],past_key_values=cache,use_cache=True)
                h,cache=out.last_hidden_state[:,-1],out.past_key_values
        hidden=torch.stack(hs,1)
        target=torch.stack(ys,1)
        for j in range(args.steps-5):
            features.append(hidden[:,j])
            futures.append(target[:,j:j+6])
    root=online.DATA/'rollout-producer'
    root.mkdir(parents=True,exist_ok=True)
    artifact=root/'train.pt'
    payload={'hidden':torch.cat(features),'future':torch.cat(futures)}
    torch.save(payload,artifact)
    receipt={'source_sha256':online.sha(__file__),'corpus_sha256':online.sha(text),'artifact_sha256':online.sha(artifact),
             'rows':len(payload['hidden']),'starts':starts,'arguments':vars(args),'capture_seconds':time.perf_counter()-begun,
             'numerics':'Pinned BF16 checkpoint promoted to FP32; FP16 saved causal normalized hidden; batched target greedy labels. Draft training fixture, not a serial target equivalence claim.',
             'contract':'Train corpus only, initial512 contexts exclude both prior train start sets. Each of11 causal positions per16-step target continuation yields retained root plus5 residual labels. Neighboring rows share trajectories and are not independent examples.'}
    (root/'train.json').write_text(json.dumps(receipt,indent=2)+'\n')
    (root/'sources').mkdir(exist_ok=True)
    (root/'sources'/(online.sha(__file__)+'.py')).write_bytes(Path(__file__).read_bytes())
    print(json.dumps({k:v for k,v in receipt.items() if k!='starts'}),flush=True)


if __name__=='__main__':main()
