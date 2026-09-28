"""Reject incomplete native receipts; retain all raw adjacent samples."""
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path
HERE=Path(__file__).resolve().parent
lines=[json.loads(s) for s in (HERE/'timing.jsonl').read_text().splitlines()]
numeric=[x for x in lines if x['type']=='numerical']
samples=[x for x in lines if x['type']=='sample']
keys={(w,t,m) for w in range(4) for t in (128,256) for m in range(3)}
assert len(numeric)==24 and {(x['window'],x['t'],x['mode']) for x in numeric}==keys
assert all(x['type']=='numerical' for x in lines[:24]) and all(x['type']=='sample' for x in lines[24:])
assert all(math.isfinite(x['max_abs']) and math.isfinite(x['relative_l2']) and x['max_abs']>=0 and x['relative_l2']>=0 and x['max_abs']<=.005 and x['relative_l2']<=.005 for x in numeric)
assert len(samples)==96
expected={(w,t,r,o,(2*w+(t==256)+r+o)%3) for w in range(4) for t in (128,256) for r in range(4) for o in range(3)}
assert {(x['window'],x['t'],x['round'],x['order'],x['mode']) for x in samples}==expected
assert all(math.isfinite(x['event_us']) and math.isfinite(x['wall_us']) and x['event_us']>0 and x['wall_us']>0 for x in samples)
summary={}
for mode,name in enumerate(('original','direct','grouped')):
    subset=[x for x in samples if x['mode']==mode]
    assert len(subset)==32
    summary[name]={'max_abs':max(x['max_abs'] for x in numeric if x['mode']==mode),'max_relative_l2':max(x['relative_l2'] for x in numeric if x['mode']==mode)}
    for t in ('all',128,256):
        sl=subset if t=='all' else [x for x in subset if x['t']==t]
        summary[name][str(t)]={'count':len(sl),'event_median_us':statistics.median(x['event_us'] for x in sl),'wall_median_us':statistics.median(x['wall_us'] for x in sl)}
per_state=[]
for w in range(4):
    for t in (128,256):
        medians={name:statistics.median(x['event_us'] for x in samples
                  if x['window']==w and x['t']==t and x['mode']==mode)
                 for mode,name in enumerate(('original','direct','grouped'))}
        per_state.append({'window':w,'t':t,'event_medians_us':medians})
paired={}
for candidate,control,name in ((1,0,'direct_over_original'),(2,0,'grouped_over_original'),(2,1,'grouped_over_direct')):
    ratios=[];differences=[]
    for w in range(4):
        for t in (128,256):
            for r in range(4):
                adjacent={x['mode']:x['event_us'] for x in samples
                          if (x['window'],x['t'],x['round'])==(w,t,r)}
                ratios.append(adjacent[candidate]/adjacent[control])
                differences.append(adjacent[candidate]-adjacent[control])
    paired[name]={'pairs':len(ratios),'candidate_faster_pairs':sum(v<1 for v in ratios),
                  'event_ratio_median':statistics.median(ratios),
                  'event_difference_median_us':statistics.median(differences),
                  'event_ratios':ratios,'event_differences_us':differences}
result={'guard':'all 24 passed before timing','samples_per_arm':32,'numerical':numeric,'samples':samples,'summary':summary,
        'per_state':per_state,'paired':paired}
(HERE/'timing-results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(summary,indent=2))
