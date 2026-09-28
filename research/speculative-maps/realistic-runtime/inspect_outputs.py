#!/usr/bin/env python3
"""Keep readable target continuations and repetition/EOS diagnostics with the timing panel."""
import hashlib
import json
from pathlib import Path
from transformers import AutoTokenizer

ROOT=Path('/path/to/workspace/data/kelana-speculative/realistic-runtime')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-1.7b')
tokenizer=AutoTokenizer.from_pretrained(MODEL,local_files_only=True)
rows=[]
for offset in range(0,24,4):
    source=ROOT/f'q17-{offset:02d}.json'
    receipt=json.loads(source.read_text())
    for case in receipt['records']:
        tokens=case['arms']['serial']['tokens']
        ngrams=[tuple(tokens[i:i+4]) for i in range(len(tokens)-3)]
        rows.append({'case':case['case_id'],'family':case['family'],'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                     'text':tokenizer.decode(tokens),'special_token_positions':[(i,x) for i,x in enumerate(tokens) if x in tokenizer.all_special_ids],
                     'duplicate_fourgram_fraction':1-len(set(ngrams))/len(ngrams) if ngrams else 0,
                     'meaning':'Timing preserves the target continuation, not semantic correctness. Repetition is a property of the serial target too.'})
result={'source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'outputs':rows}
(ROOT/'outputs.json').write_text(json.dumps(result,indent=2)+'\n')
print('cases',len(rows),'special-token cases',sum(bool(r['special_token_positions']) for r in rows),
      'cases with repeated fourgrams',sum(r['duplicate_fourgram_fraction']>0 for r in rows))
