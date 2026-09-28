"""Aggregate only the eight paid held snapshots; never average per-state ratios."""
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
r=[json.loads((HERE/f'held-{i}-result.json').read_text()) for i in range(4)]
k=[json.loads((HERE/f'held-{i}-kivi4-control.json').read_text()) for i in range(4)]
assert all([x['t'] for x in item['retained']]==[128,256] for item in r+k)
assert all(abs(a['teacher_sq']-b['teacher_sq'])<1e-7 for x,y in zip(r,k) for a,b in zip(x['retained'],y['retained']))
reference=sum(z['teacher_sq'] for x in r for z in x['retained'])
def total(records,key):return sum(z[key] for x in records for z in x['retained'])
summary={'scope':'four held streams × t128/t256 complete 16Q/8KV layer0 retained observer; eight states, no full-panel candidate replay',
 'teacher_sq':reference,'source_objective_initial':sum(x['source_objective_initial'] for x in r),
 'source_objective_final':sum(x['source_objective_final'] for x in r),
 'candidate_sse':total(r,'candidate_teacher_sse'),
 'same_cache_kivi2_sse':total(r,'control_teacher_sse'),
 'smaller_total_state_kivi4_sse':total(k,'kivi4_teacher_sse'),
 'candidate_relative_sq':total(r,'candidate_teacher_sse')/reference,
 'same_cache_kivi2_relative_sq':total(r,'control_teacher_sse')/reference,
 'smaller_total_state_kivi4_relative_sq':total(k,'kivi4_teacher_sse')/reference,
 'changed_digits':sum(x['changed_digits'] for x in r),
 'records':sum(x['records'] for x in r),
 'direct_projection_sweep_digit_differences':sum(x['direct_projection_sweep_digit_differences'] for x in r),
 'represented_objective_increases':[{'window':x['window'],**y} for x in r for y in x['represented_objective_increases']],
 'kivi2_cache_peak_bytes':304768,'additional_prepared_gram_bytes':524288,
 'candidate_cache_plus_prepared_peak_bytes':829056,'kivi4_peak_bytes':419200,
 'per_state':[{'window':x['window'],**a,'kivi4_teacher_sse':b['kivi4_teacher_sse']} for x,y in zip(r,k) for a,b in zip(x['retained'],y['retained'])]}
(HERE/'results.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k.endswith('relative_sq') or k in ('records','changed_digits','direct_projection_sweep_digit_differences')}))
