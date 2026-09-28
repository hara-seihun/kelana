"""Validate one bounded device trace; timing gate requires all four completed audits."""
import hashlib
import json
import math
import struct
import subprocess
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
phase,window=sys.argv[1:]
assert phase in ('accept','timing','gate') and window in [f'held-{i}' for i in range(4)]
pre=json.loads((HERE/'prelaunch-receipt.json').read_text())
source=pre['source_hash']
def sha(blob):return hashlib.sha256(blob).hexdigest()
def snapshot_fingerprint(window):
    compressed=HERE/f'{window}-snapshots.bin.zst'
    assert compressed.is_file()
    proc=subprocess.Popen(['zstd','-dc',str(compressed)],stdout=subprocess.PIPE)
    h=hashlib.sha256();size=0
    while part:=proc.stdout.read(1024*1024):h.update(part);size+=len(part)
    assert proc.wait(timeout=5)==0
    return h.hexdigest(),size,sha(compressed.read_bytes())
def check(phase,window):
    result=json.loads((HERE/f'{phase}-{window}-receipt.json').read_text())
    assert result['source_hash']==source and result['binary_sha256']==pre['binary_sha256']
    assert result['window']==window and result['phase']==phase and result['guards']==4
    if phase=='accept':
        assert result['audit']['backend']=='device'
        assert result['audit']['0']['phases']==result['audit']['1']['phases']==512
        decoded,size,compressed=snapshot_fingerprint(window)
        assert (decoded,size,compressed)==(result['audit']['snapshot_sha256'],result['audit']['snapshot_bytes'],result['snapshot_zst_sha256'])
        for filename,digest in result['actual_sha256'].items():
            assert sha((HERE/filename).read_bytes())==digest
    return result
if phase in ('timing','gate'):
    for i in range(4):check('accept',f'held-{i}')
    if phase=='gate':
        (HERE/'acceptance.ready').write_text(source+'\n')
        print('four complete native acceptance/audit receipts admitted timing')
        sys.exit(0)
raw=(HERE/f'{phase}-{window}.jsonl').read_bytes()
rows=[json.loads(line) for line in raw.splitlines()]
assert len(rows)==4 and {(r['mode'],r['t']) for r in rows}=={(m,t) for m in (0,1) for t in (128,256)}
for row in rows:
    assert row['window']==window and row['pass']==phase
    for key in ('max_abs','relative_l2'):
        assert math.isfinite(row[key]) and 0<=row[key]<=.005
    for key in ('step_event_us','input_span_us','compute_span_us','step_wall_us'):
        assert math.isfinite(row[key]) and row[key]>0
receipt={'phase':phase,'window':window,'source_hash':source,'binary_sha256':pre['binary_sha256'],
         'guards':4,'rows':rows,'trace_sha256':sha(raw)}
if phase=='accept':
    audit=json.loads((HERE/f'audit-{window}.json').read_text())
    assert audit['backend']=='device' and audit['0']['phases']==audit['1']['phases']==512
    decoded,size,compressed=snapshot_fingerprint(window)
    assert (decoded,size)==(audit['snapshot_sha256'],audit['snapshot_bytes'])
    receipt['snapshot_zst_sha256']=compressed
    receipt['audit']=audit
    receipt['actual_sha256']={}
    receipt['teacher_sse']={}
    receipt['arm_max_abs']={}
    for t in (128,256):
        teacher=struct.unpack('<1024f',(HERE/f'../kivi-two-bit-dot-native/{window}-t{t}-teacher.f32').read_bytes())
        actual=[]
        for mode in (0,1):
            name=f'{window}-t{t}-mode{mode}-actual.f32'
            data=(HERE/name).read_bytes()
            assert len(data)==4096
            receipt['actual_sha256'][name]=sha(data)
            values=struct.unpack('<1024f',data)
            assert all(math.isfinite(v) for v in values)
            receipt['teacher_sse'][f't{t}-mode{mode}']=sum((a-b)**2 for a,b in zip(values,teacher))
            actual.append(values)
        receipt['arm_max_abs'][f't{t}']=max(abs(a-b) for a,b in zip(*actual))
(HERE/f'{phase}-{window}-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'phase':phase,'window':window,'guards':4}))
