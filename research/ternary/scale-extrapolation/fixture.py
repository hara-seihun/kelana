#!/usr/bin/env python3
"""Freeze a new, disjoint WikiText test panel before evaluating any arm."""
import hashlib
import json
from pathlib import Path
import numpy as np
from transformers import AutoTokenizer

DATA=Path('/path/to/workspace/data/kelana-subbit')
ROOT=DATA/'ternary'
OUT=ROOT/'scale-extrapolation'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    OUT.mkdir(exist_ok=True)
    assert not (OUT/'tokens.npz').exists()
    source=DATA/'corpus/wikitext-2-raw/test.txt'
    tokenizer=AutoTokenizer.from_pretrained(DATA/'models/qwen3-0.6b',local_files_only=True)
    tokenizer.model_max_length=10**12
    ids=np.array(tokenizer(source.read_text(),add_special_tokens=False)['input_ids'],dtype=np.int32)
    previous=json.loads((DATA/'fixtures/qwen3-0.6b-wikitext/manifest.json').read_text())
    fresh=json.loads((DATA/'fresh-evaluation/manifest.json').read_text())
    ternary=json.loads((ROOT/'tokens.json').read_text())
    occupied=[(s,s+previous['length']) for s in previous['window_starts']['test']]
    for key,r in fresh['windows'].items():
        if key.startswith('test_'):occupied.extend((s,s+r['length']) for s in r['starts'])
    occupied.extend((s,s+ternary['length']) for s in ternary['windows']['test']['starts'])
    eligible=[s for s in range(0,len(ids)-255,256) if all(s>=b or s+256<=a for a,b in occupied)]
    starts=sorted(np.random.default_rng(2026092413).choice(eligible,16,replace=False).tolist())
    np.savez(OUT/'tokens.npz',test=np.stack([ids[s:s+256] for s in starts]))
    rec=dict(starts=starts,length=256,source_sha256=sha(source),tokens_sha256=sha(OUT/'tokens.npz'),model_source_sha256=sha(DATA/'models/qwen3-0.6b/source.json'),excluded=occupied,selection='seed 2026092413 on nonoverlapping aligned 256-token test windows')
    (OUT/'tokens.json').write_text(json.dumps(rec,indent=2)+'\n')
    print(json.dumps(dict(eligible=len(eligible),starts=starts,tokens_sha256=rec['tokens_sha256'])))

if __name__=='__main__':main()
