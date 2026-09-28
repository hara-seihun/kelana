"""CPU-only compiled source, donor, held-arrival, Q/O and fixed-budget preflight."""
import hashlib
import json
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
SHA=lambda b:hashlib.sha256(b).hexdigest()

def receipt():
    compile=json.loads((HERE/'compile-receipt.json').read_text())
    assert compile['target']=='gfx1151'
    for p,h in compile['source_sha256'].items():assert SHA((HERE/p).read_bytes())==h,p
    assert SHA((HERE/'native').read_bytes())==compile['binary_sha256']
    assert SHA((HERE/'assembly-gfx1151.s').read_bytes())==compile['assembly_sha256']
    assert len(compile['device_kernels'])==10 and all(x['private_scratch']==0 for x in compile['device_kernels'])
    assert 8*18944+8*224*48+8*33*256+4==305156
    spec={'cache':305156,'feedback_residual':4096,'arrival':4096,'q':8192,'o':4194304,'partials':32768,'output':4096,
          'control_total':305156+4096+8192+4194304+32768+4096,
          'feedback_total':305156+4096+4096+8192+4194304+32768+4096,
          'device_code_body_bytes':sum(x['body_bytes'] for x in compile['device_kernels']),
          'device_descriptor_bytes':640}
    states=json.loads((ROOT/'kivi-two-bit-dot-native'/'snapshots.json').read_text())
    s={(x['window'],x['position']):x for x in states['states']}
    assert len(s)==8
    o=(ROOT/'kivi-two-bit-dot-native'/'original-o.bf16').read_bytes()
    assert len(o)==4194304 and SHA(o)==states['original_o_sha256']
    arrivals={};donors={};cpu_audits={}
    for n in range(4):
        tag=f'held-{n}'
        a=(ROOT/'kivi-value-intern'/f'{tag}-events.bin').read_bytes()
        own=json.loads((ROOT/'kivi-value-intern'/f'{tag}-manifest.json').read_text())
        d=(ROOT/'kivi-value-error-feedback'/f'{tag}-manifest.json').read_bytes()
        dm=json.loads(d)
        assert len(a)==256*4098 and SHA(a)==own['events_sha256']==dm['arrival_sha256']
        assert SHA((ROOT/'kivi-two-bit-causal'/f'{tag}-manifest.json').read_bytes())==dm['baseline_manifest_sha256']
        assert SHA((ROOT/'kivi-value-intern'/f'{tag}-manifest.json').read_bytes())==dm['arrival_manifest_sha256']
        q={}
        for t in (128,256):
            r=s[n,t];assert r['tag']==f'{tag}-t{t}'
            q[t]={}
            for kind,length,key in [('q.f32',8192,'query_sha256'),('teacher.f32',4096,'teacher_sha256'),('conventional-cpu.f32',4096,'cpu_conventional_sha256')]:
                raw=(ROOT/'kivi-two-bit-dot-native'/f'{tag}-t{t}-{kind}').read_bytes()
                assert len(raw)==length and SHA(raw)==r[key]
                q[t][kind]=SHA(raw)
        result=json.loads((ROOT/'kivi-value-error-feedback'/f'{tag}-result.json').read_text())
        for t in (128,256):
            expected=next(x for x in result['arms']['feedback']['retained'] if x['t']==t)['output_sha256']
            prepared=(HERE/f'{tag}-t{t}-feedback-cpu.f32').read_bytes()
            assert len(prepared)==4096 and SHA(prepared)==expected
            q[t]['feedback_cpu_sha256']=SHA(prepared)
        arrivals[tag]={'arrival_sha256':SHA(a),'retained':q}
        donors[tag]={'feedback_manifest_sha256':SHA(d),'original_manifest_sha256':dm['baseline_manifest_sha256']}
        cpu_path=HERE/f'cpu-audit-{tag}.json'
        cpu=json.loads(cpu_path.read_text())
        assert cpu['tag']==tag and cpu['frames']==1024 and cpu['feedback_residual_checks']==4096
        assert cpu['ordered_records']==1089536 and cpu['snapshot_bytes']==314585088
        cpu_audits[tag]={'receipt_sha256':SHA(cpu_path.read_bytes()),'synthetic_physical_sha256':cpu['snapshot_sha256']}
    return json.loads(json.dumps({'source_hash':SHA(''.join(f'{p} {h}\n' for p,h in compile['source_sha256'].items()).encode()),
            'binary_sha256':compile['binary_sha256'],'assembly_sha256':compile['assembly_sha256'],
            'input':arrivals,'donors':donors,'cpu_audits':cpu_audits,'original_o_sha256':SHA(o),'bill':spec,'kernels':compile['device_kernels'],
            'schedule':{'accept':{'rounds':1,'order':[0,1],'windows':4},
                        'timing':{'rounds_per_window':4,'first_mode':'(window+round)%2','measured_steps':[128,256],
                                  'fresh_empty_per_arm_round':True,'matched_pairs':32}}}))

def main():
    if len(sys.argv)>1 and sys.argv[1]=='prepare':
        import score
        for n in range(4):score.prepare(f'held-{n}')
    r=receipt()
    if len(sys.argv)>1 and sys.argv[1]=='prepare':
        for n in range(4):score.run(f'held-{n}',False)
        (HERE/'prelaunch-receipt.json').write_text(json.dumps(r,indent=2)+'\n')
    else:assert r==json.loads((HERE/'prelaunch-receipt.json').read_text())
    print(json.dumps({'source_hash':r['source_hash'],'binary_sha256':r['binary_sha256'],'bill':r['bill']}))
if __name__=='__main__':main()
