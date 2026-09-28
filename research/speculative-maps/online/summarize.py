#!/usr/bin/env python3
"""Aggregate paired panels without averaging per-prompt throughput ratios."""
import hashlib
import json
from pathlib import Path

DATA=Path('/path/to/workspace/data/kelana-speculative/online')
TAGS=('first','head-rows','mask-diagnosis','fp32','fp32-direct','fp32-frontier')
result={}
for tag in TAGS:
    source=DATA/(tag+'.json')
    record=json.loads(source.read_text())
    methods=record['arguments']['methods'].split(',')
    arms={}
    for method in methods:
        values=[r['arms'][method] for r in record['results']]
        cycles=[c for v in values for c in v['cycles']]
        total_tokens=sum(len(v['tokens']) for v in values)
        arms[method]={
            'tokens_per_second':total_tokens/sum(v['elapsed_s'] for v in values),
            'paths_matching_serial':sum(v['matches_serial'] for v in values),
            'paths':len(values),
            'next_decisions_matching_serial':sum(r['arms'][method]['next_token']==r['arms']['serial']['next_token'] for r in record['results']),
            'total_emitted_tokens':total_tokens,'cycles':len(cycles),
            'tokens_per_cycle':total_tokens/len(cycles),
            'mean_cycle_ms':1000*sum(c['cycle_s'] for c in cycles)/len(cycles),
            **{'mean_'+phase+'_ms':1000*sum(c[phase+'_s'] for c in cycles)/len(cycles) for phase in ('draft','verify','adopt')},
        }
    for method in methods:arms[method]['speedup_vs_serial']=arms[method]['tokens_per_second']/arms['serial']['tokens_per_second']
    result[tag]={'receipt_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'arguments':record['arguments'],'arms':arms}
path=Path(__file__).with_name('results.json')
path.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
