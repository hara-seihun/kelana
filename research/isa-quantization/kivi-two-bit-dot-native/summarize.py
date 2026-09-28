"""Parse one complete admitted native run; refuse partial/denied timing as evidence."""
import json
import math
import statistics
from pathlib import Path

here=Path(__file__).resolve().parent
records=[json.loads(line) for line in (here/'timing.jsonl').read_text().splitlines()]
numerics=[r for r in records if r['type']=='numerical']
samples=[r for r in records if r['type']=='sample']
assert len(numerics)==16 and len(samples)==64
assert {(r['window'],r['t'],r['mode']) for r in numerics}=={(w,t,m) for w in range(4) for t in (128,256) for m in (0,1)}
assert {(r['window'],r['t'],r['round'],r['mode']) for r in samples}=={(w,t,k,m) for w in range(4) for t in (128,256) for k in range(4) for m in (0,1)}
assert all(all(math.isfinite(r[k]) and r[k]>=0 for k in ('max_abs','relative_l2','native_vs_teacher_rel_sq')) and r['max_abs']<=0.005 and r['relative_l2']<=0.005 for r in numerics)
assert all(all(math.isfinite(r[k]) and r[k]>0 for k in ('event_us','wall_us')) for r in samples)
out={'admission':'accepted','guard_max_abs':0.005,'guard_relative_l2':0.005,
     'numerical':numerics,'raw_samples':samples,'modes':{}}
for mode in (0,1):
    group=[r for r in samples if r['mode']==mode]
    assert len(group)==32
    out['modes']['conventional' if mode==0 else 'byte_dot']={
        'event_us_median':statistics.median(r['event_us'] for r in group),
        'wall_us_median':statistics.median(r['wall_us'] for r in group),
        'event_us_by_t':{str(t):statistics.median(r['event_us'] for r in group if r['t']==t) for t in (128,256)},
        'wall_us_by_t':{str(t):statistics.median(r['wall_us'] for r in group if r['t']==t) for t in (128,256)},
        'max_abs_vs_cpu':max(r['max_abs'] for r in numerics if r['mode']==mode),
        'max_relative_l2_vs_cpu':max(r['relative_l2'] for r in numerics if r['mode']==mode)}
(here/'timing-results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out['modes'],indent=2))
