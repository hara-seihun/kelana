"""Timing requires every accepted phase audit for this exact program."""
import hashlib
import json
from pathlib import Path

here=Path(__file__).resolve().parent
accepted=[]
for i in range(4):
    path=here/f'accept-held-{i}-receipt.json'
    r=json.loads(path.read_text())
    assert r['phase']=='accept' and r['window']==f'held-{i}' and r['numerical_guards']==4
    assert r['phase_audit']['backend']=='device' and r['phase_audit']['phases']==1024
    for name,expected in r['program_sha256'].items():
        assert hashlib.sha256((here/name).read_bytes()).hexdigest()==expected,(name,'changed program')
    raw=(here/f'accept-held-{i}.jsonl').read_bytes()
    assert hashlib.sha256(raw).hexdigest()==r['trace_sha256']
    accepted.append(hashlib.sha256(path.read_bytes()).hexdigest())
(here/'acceptance.ready').write_text(json.dumps({'acceptance_receipts_sha256':accepted})+'\n')
print('All4096 phase states and16 output guards accepted for the unchanged program.')
