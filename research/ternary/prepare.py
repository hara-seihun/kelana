#!/usr/bin/env python3
"""Freeze new WikiText windows outside the two previous pilot fixtures."""
import hashlib
import json
from pathlib import Path
import numpy as np
from transformers import AutoTokenizer

DATA = Path('/path/to/workspace/data/kelana-subbit')
OUT = DATA / 'ternary'
MODEL = DATA / 'models/qwen3-0.6b'

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    OUT.mkdir(exist_ok=True)
    if (OUT/'tokens.npz').exists():
        raise ValueError('Frozen tokens already exist')
    previous=json.loads((DATA/'fixtures/qwen3-0.6b-wikitext/manifest.json').read_text())
    fresh=json.loads((DATA/'fresh-evaluation/manifest.json').read_text())
    tokenizer=AutoTokenizer.from_pretrained(MODEL,local_files_only=True)
    tokenizer.model_max_length=10**12
    arrays={}; manifest={'model_source_sha256':sha(MODEL/'source.json'),'length':256,'windows':{}}
    for split,count in [('train',32),('validation',16),('test',32)]:
        text=DATA/f'corpus/wikitext-2-raw/{split}.txt'
        ids=np.asarray(tokenizer(text.read_text(),add_special_tokens=False)['input_ids'],dtype=np.int32)
        occupied=[(s,s+previous['length']) for s in previous['window_starts'][split]]
        for key,record in fresh['windows'].items():
            if key.startswith(split+'_'):
                occupied.extend((s,s+record['length']) for s in record['starts'])
        eligible=[s for s in range(0,len(ids)-255,256) if not any(s<b and a<s+256 for a,b in occupied)]
        starts=sorted(np.random.default_rng(93821+len(split)).choice(eligible,count,replace=False).tolist())
        arrays[split]=np.stack([ids[s:s+256] for s in starts])
        manifest['windows'][split]={'starts':starts,'text_sha256':sha(text),'excluded':occupied}
    np.savez(OUT/'tokens.npz',**arrays)
    manifest['tokens_sha256']=sha(OUT/'tokens.npz')
    (OUT/'tokens.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'out':str(OUT),'shapes':{k:list(v.shape) for k,v in arrays.items()}}))

if __name__=='__main__':main()
