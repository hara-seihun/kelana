"""Hash raw acceptance, verify all actual full-O maps, and gate fresh paired timings."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
SHA=lambda b:hashlib.sha256(b).hexdigest()

def snapshot(tag):
    r=json.loads((HERE/f'audit-{tag}.json').read_text())
    p=HERE/f'{tag}-snapshots.bin.zst'
    assert SHA(p.read_bytes())==r['compressed_sha256']
    h=hashlib.sha256();length=0
    process=subprocess.Popen(['zstd','-dc',str(p)],stdout=subprocess.PIPE)
    while chunk:=process.stdout.read(1048576):h.update(chunk);length+=len(chunk)
    assert process.wait()==0 and h.hexdigest()==r['snapshot_sha256'] and length==r['snapshot_bytes']
    assert r['frames']==1024 and r['feedback_residual_checks']==4096
    return r

def gate():
    from prelaunch import receipt
    expected=receipt()
    assert expected==json.loads((HERE/'prelaunch-receipt.json').read_text())
    for n in range(4):
        tag=f'held-{n}'
        snapshot(tag)
        old=json.loads((HERE/f'accept-{tag}-receipt.json').read_text())
        assert old['source_hash']==expected['source_hash'] and old['binary_sha256']==expected['binary_sha256']
        import score
        assert score.run(tag,True)==old['full_outputs']
    return expected

def result(phase,tag):
    from prelaunch import receipt
    expected=receipt();assert expected==json.loads((HERE/'prelaunch-receipt.json').read_text())
    raw=(HERE/f'{phase}-{tag}.jsonl').read_bytes()
    rows=[json.loads(line) for line in raw.splitlines()]
    rounds=1 if phase=='accept' else 4
    assert len(rows)==4*rounds
    assert {(r['round'],r['mode'],r['t']) for r in rows}=={(i,m,t) for i in range(rounds) for m in (0,1) for t in (128,256)}
    assert all(r['pass']==phase and r['window']==tag for r in rows)
    for i in range(rounds):
        sequence=[r for r in rows if r['round']==i]
        first=0 if phase=='accept' else (int(tag[-1])+i)%2
        assert [(r['order'],r['mode'],r['t']) for r in sequence]==[(order,mode,t) for order,mode in enumerate((first,1-first)) for t in (128,256)]
    common={'window':tag,'phase':phase,'source_hash':expected['source_hash'],'binary_sha256':expected['binary_sha256'],
            'trace_sha256':SHA(raw),'attempt_sha256':SHA((HERE/f'attempt-{phase}-{tag}.txt').read_bytes()),'rows':rows}
    if phase=='accept':
        audit=snapshot(tag)
        import score
        common.update({'audit':audit,'full_outputs':score.run(tag,True)})
    else:gate()
    p=HERE/f'{phase}-{tag}-receipt.json';assert not p.exists()
    p.write_text(json.dumps(common,indent=2)+'\n')

if __name__=='__main__':
    if sys.argv[1]=='gate':gate();print('all four device acceptances audited and pinned')
    else:result(sys.argv[1],sys.argv[2])
