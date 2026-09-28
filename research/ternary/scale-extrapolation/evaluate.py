#!/usr/bin/env python3
"""Score a frozen complete ternary image on a new disjoint held test panel."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import numpy as np
import torch
import torch.nn.functional as F
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from pilot import expanded, load_model

ROOT=Path('/path/to/workspace/data/kelana-subbit/ternary')
OUT=ROOT/'scale-extrapolation'

def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return h.hexdigest()

@torch.inference_mode()
def main():
    p=argparse.ArgumentParser()
    p.add_argument('--name',choices=('expanded-scale384','scale-extrapolate-1.5','scale-extrapolate-2'))
    p.add_argument('--offset',type=int,default=0)
    p.add_argument('--windows',type=int,default=8)
    args=p.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32=False
    image=ROOT/args.name
    manifest=json.loads((image/'manifest.json').read_text())
    assert manifest['complete'] and manifest['matrix_count']==197
    model=load_model()
    for r in manifest['matrices']:
        path=image/(r['key'].replace('.','_')+'.npz')
        assert sha(path)==r['sha256']
        model.get_parameter(r['key']).copy_(expanded(path))
    assert model.lm_head.weight.data_ptr()==model.model.embed_tokens.weight.data_ptr()
    fixture=OUT/'tokens.npz'
    with np.load(fixture) as z: rows=z['test'][args.offset:args.offset+args.windows].copy()
    assert len(rows)==args.windows
    losses=[]
    for i,row in enumerate(rows):
        x=torch.tensor(row,dtype=torch.long,device='cuda')[None]
        logits=model(x,use_cache=False).logits[:,:-1].float()
        nll=F.cross_entropy(logits.reshape(-1,logits.shape[-1]),x[:,1:].reshape(-1),reduction='sum')
        losses.append(float(nll)/255)
    receipt=dict(name=args.name,offset=args.offset,windows=args.windows,mean_nll=float(np.mean(losses)),per_window_nll=losses,source_sha256=sha(Path(__file__)),image_manifest_sha256=sha(image/'manifest.json'),fixture_sha256=sha(fixture),model_source_sha256=sha(ROOT.parent/'models/qwen3-0.6b/source.json'),bpw=manifest['bpw'],observation='expanded BF16 complete-model 255 next-token predictions/window; no packed GPU timing')
    dst=OUT/f'{args.name}-{args.offset}-{args.windows}.json'
    dst.write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt),flush=True)

if __name__=='__main__':main()
