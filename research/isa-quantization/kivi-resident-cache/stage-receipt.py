"""Validate one completed frozen trace and retain its exact source identity."""
import hashlib
import json
import math
from pathlib import Path
import sys

here=Path(__file__).resolve().parent
phase,window=sys.argv[1:]
assert phase in ('accept','timing') and window in [f'held-{i}' for i in range(4)]
raw=(here/f'{phase}-{window}.jsonl').read_bytes()
rows=[json.loads(line) for line in raw.splitlines()]
assert len(rows)==4 and {(r['mode'],r['t']) for r in rows}=={(m,t) for m in (0,1) for t in (128,256)}
for row in rows:
    assert row['window']==window and row['pass']==('acceptance' if phase=='accept' else 'timing')
    for key in ('max_abs','relative_l2'):
        assert math.isfinite(row[key]) and 0<=row[key]<=.005
    for key in ('step_event_us','input_span_us','compute_span_us','step_wall_us'):
        assert math.isfinite(row[key]) and row[key]>0
sha=lambda b:hashlib.sha256(b).hexdigest()
source_files=['native','native.hip','state.hip','step_bits.hpp','grouped-generated.hip','control-generated.hip']
result={'phase':phase,'window':window,'numerical_guards':4,'rows':rows,
        'trace_sha256':sha(raw),'program_sha256':{f:sha((here/f).read_bytes()) for f in source_files}}
if phase=='accept':
    audit=json.loads((here/f'audit-{window}.json').read_text())
    assert audit['backend']=='device' and audit['phases']==1024 and audit['window']==window
    result['phase_audit']=audit
(here/f'{phase}-{window}-receipt.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'completed':phase,'window':window,'guards':4}))
