"""Hash raw acceptance, verify all actual full-O maps, and gate fresh paired timings."""
import hashlib
import json
import numpy as np
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
    assert r['frames']==1024 and r['candidate_codes']==8*224*128
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
        assert score.run(tag)==old['full_outputs']
    return expected

def result(phase,tag):
    from prelaunch import receipt
    expected=receipt();assert expected==json.loads((HERE/'prelaunch-receipt.json').read_text())
    raw=(HERE/f'{phase}-{tag}.jsonl').read_bytes()
    entries=[json.loads(line) for line in raw.splitlines()]
    rounds=1 if phase=='accept' else 4
    assert [e['kind'] for e in entries].count('shared_setup')==1
    assert [e['kind'] for e in entries].count('shared_teardown')==1
    lifecycle=[e for e in entries if e['kind']=='lifecycle']
    rows=[e for e in entries if e['kind']=='step']
    assert len(entries)==2+2*rounds+4*rounds and len(lifecycle)==2*rounds and len(rows)==4*rounds
    assert entries[0]['kind']=='shared_setup' and entries[-1]['kind']=='shared_teardown'
    assert entries[0]['allocated_bytes']==4243456 and entries[0]['original_o_h2d_bytes']==4194304
    assert {(r['round'],r['mode']) for r in lifecycle}=={(i,m) for i in range(rounds) for m in (0,1)}
    assert all(r['arm_allocated_bytes']==305156+r['mode']*16 and r['arrival_h2d_bytes']==1048576 and r['query_h2d_bytes']==16384 for r in lifecycle)
    assert {(r['round'],r['mode'],r['t']) for r in rows}=={(i,m,t) for i in range(rounds) for m in (0,1) for t in (128,256)}
    assert all(r['pass']==phase and r['window']==tag for r in rows)
    for i in range(rounds):
        sequence=[r for r in rows if r['round']==i]
        first=0 if phase=='accept' else (int(tag[-1])+i)%2
        assert [(r['order'],r['mode'],r['t']) for r in sequence]==[(order,mode,t) for order,mode in enumerate((first,1-first)) for t in (128,256)]
    common={'window':tag,'phase':phase,'source_hash':expected['source_hash'],'binary_sha256':expected['binary_sha256'],
            'trace_sha256':SHA(raw),'attempt_sha256':SHA((HERE/f'attempt-{phase}-{tag}.txt').read_bytes()),
            'shared_setup':entries[0],'lifecycle':lifecycle,'shared_teardown':entries[-1],'rows':rows}
    if phase=='accept':
        audit=snapshot(tag)
        import score
        common.update({'audit':audit,'full_outputs':score.run(tag)})
    else:
        gate()
        output=[]
        for row in rows:
            t,mode,round_=row['t'],row['mode'],row['round']
            raw=(HERE/f'{tag}-t{t}-mode{mode}-round{round_}-actual.f32').read_bytes()
            actual=np.frombuffer(raw,dtype='<f4')
            target=np.frombuffer((HERE/f'{tag}-t{t}-alphabet-cpu.f32').read_bytes() if mode else
                (HERE.parent/'kivi-two-bit-dot-native'/f'{tag}-t{t}-conventional-cpu.f32').read_bytes(),dtype='<f4')
            assert len(actual)==len(target)==1024 and np.isfinite(actual).all()
            diff=actual.astype('f8')-target.astype('f8')
            maxabs=float(abs(diff).max());rel=float(np.linalg.norm(diff)/np.linalg.norm(target))
            assert maxabs<=.005 and rel<=.005
            output.append({'t':t,'mode':mode,'round':round_,'sha256':SHA(raw),'max_abs':maxabs,'relative_l2':rel})
        common['timing_actual_outputs']=output
    p=HERE/f'{phase}-{tag}-receipt.json';assert not p.exists()
    p.write_text(json.dumps(common,indent=2)+'\n')

if __name__=='__main__':
    if sys.argv[1]=='gate':gate();print('all four device acceptances audited and pinned')
    else:result(sys.argv[1],sys.argv[2])
