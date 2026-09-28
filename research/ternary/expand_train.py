#!/usr/bin/env python3
"""Extend the training fixture without changing any validation or test tokens."""
import json
from pathlib import Path
import numpy as np
from transformers import AutoTokenizer
from prepare import DATA, OUT, MODEL, sha


def main():
    destination=OUT/'expanded-tokens.npz'
    if destination.exists():raise ValueError('Expanded fixture already frozen')
    parent=json.loads((OUT/'tokens.json').read_text())
    with np.load(OUT/'tokens.npz') as f:arrays={k:f[k].copy() for k in f.files}
    tokenizer=AutoTokenizer.from_pretrained(MODEL,local_files_only=True)
    tokenizer.model_max_length=10**12
    text=DATA/'corpus/wikitext-2-raw/train.txt'
    ids=np.asarray(tokenizer(text.read_text(),add_special_tokens=False)['input_ids'],dtype=np.int32)
    old=parent['windows']['train']
    occupied=old['excluded']+[(s,s+256) for s in old['starts']]
    eligible=[s for s in range(0,len(ids)-255,256) if not any(s<b and a<s+256 for a,b in occupied)]
    starts=sorted(np.random.default_rng(93821481).choice(eligible,512-len(arrays['train']),replace=False).tolist())
    arrays['train']=np.concatenate([arrays['train'],np.stack([ids[s:s+256] for s in starts])])
    np.savez(destination,**arrays)
    manifest=dict(parent_fixture_sha256=sha(OUT/'tokens.npz'),tokens_sha256=sha(destination),
                  model_source_sha256=sha(MODEL/'source.json'),train_text_sha256=sha(text),
                  train_starts=old['starts']+starts,train_windows=512,train_tokens=512*256,
                  validation_and_test='identical to parent frozen fixture',source_sha256=sha(Path(__file__)))
    (OUT/'expanded-tokens.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest))

if __name__=='__main__':main()
