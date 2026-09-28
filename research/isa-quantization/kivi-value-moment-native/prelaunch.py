"""CPU-only source/host-state/map preflight and fixed physical-budget accounting."""
import hashlib
import json
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
SHA=lambda x:hashlib.sha256(x).hexdigest()

def receipt():
    c=json.loads((HERE/'compile-receipt.json').read_text())
    assert c['target']=='gfx1151' and len(c['device_kernels'])==11
    for path,digest in c['source_sha256'].items():assert SHA((HERE/path).read_bytes())==digest,path
    assert SHA((HERE/'native').read_bytes())==c['binary_sha256']
    assert SHA((HERE/'assembly-gfx1151.s').read_bytes())==c['assembly_sha256']
    assert all(k['private_scratch']==0 for k in c['device_kernels'])
    assert 8*18944+8*224*48+8*33*256+4==305156
    bill={'control_cache':305156,'moment_fp32':4096,'arrival':4096,'q':8192,'original_o':4194304,'partial_o':32768,'output':4096,
          'control_allocated':305156+4096+8192+4194304+32768+4096,
          'moment_allocated':305156+4096+4096+8192+4194304+32768+4096,
          'device_code_body_including_unused':sum(k['body_bytes'] for k in c['device_kernels']),
          'device_code_descriptors_including_unused':sum(k['descriptor_bytes'] for k in c['device_kernels']),
          'maximum_lds_per_cta':max(k['lds'] for k in c['device_kernels']),
          'private_scratch_per_thread':max(k['private_scratch'] for k in c['device_kernels']),
          'host_snapshot_buffer_max':305156+4096,'host_arrival_buffer':256*4098,'host_o_buffer':4194304,
          'host_measured_q':8192,'host_measured_reference':4096,'host_measured_output':4096,
          'cpu_audit_streamed_snapshot_bytes_per_window':314585088}
    snapshots=json.loads((ROOT/'kivi-two-bit-dot-native'/'snapshots.json').read_text())
    states={(x['window'],x['position']):x for x in snapshots['states']};assert len(states)==8
    o=(ROOT/'kivi-two-bit-dot-native'/'original-o.bf16').read_bytes()
    assert len(o)==4194304 and SHA(o)==snapshots['original_o_sha256']
    inputs={};donors={};audits={}
    for n in range(4):
        tag=f'held-{n}'
        arrivals=(ROOT/'kivi-value-intern'/f'{tag}-events.bin').read_bytes()
        own=json.loads((ROOT/'kivi-value-intern'/f'{tag}-manifest.json').read_text())
        manifest_path=ROOT/'kivi-value-error-moment'/f'{tag}-manifest.json'
        m=json.loads(manifest_path.read_text()); result=json.loads((ROOT/'kivi-value-error-moment'/f'{tag}-result.json').read_text())
        base=(ROOT/'kivi-two-bit-causal'/f'{tag}-manifest.json').read_bytes()
        assert len(arrivals)==256*4098 and SHA(arrivals)==own['events_sha256']==m['source_sha256']
        assert SHA(base)==m['donor_manifest_sha256']
        assert result['manifest_sha256']==SHA(manifest_path.read_bytes())
        assert m['peak_bytes']==308864 and m['final_bytes']==253952 and m['moment_bytes']==4096
        refs={}
        for t in (128,256):
            r=states[n,t];assert r['tag']==f'{tag}-t{t}'
            refs[str(t)]={}
            for ext,length,key in [('q.f32',8192,'query_sha256'),('teacher.f32',4096,'teacher_sha256'),('conventional-cpu.f32',4096,'cpu_conventional_sha256')]:
                raw=(ROOT/'kivi-two-bit-dot-native'/f'{tag}-t{t}-{ext}').read_bytes()
                assert len(raw)==length and SHA(raw)==r[key]
                refs[str(t)][ext]=SHA(raw)
            target=(HERE/f'{tag}-t{t}-moment-cpu.f32').read_bytes()
            row=next(x for x in result['rows'] if x['t']==t)
            assert len(target)==4096 and SHA(target)==row['output_sha256']
            refs[str(t)]['moment_cpu_sha256']=SHA(target)
            for h in range(8):
                image=m['snapshots'][str(t)][h];raw=(ROOT/'kivi-value-error-moment'/image['file']).read_bytes()
                assert len(raw)==512 and SHA(raw)==image['sha256']==m['heads'][h]['trace'][t-1]['before']
        cpu_path=HERE/f'cpu-audit-{tag}.json';audit=json.loads(cpu_path.read_text())
        assert audit['tag']==tag and audit['frames']==1024 and audit['moment_checks']==4096
        assert audit['ordered_records']==1089536 and audit['snapshot_bytes']==314585088
        inputs[tag]={'arrival_sha256':SHA(arrivals),'retained':refs}
        donors[tag]={'original_manifest_sha256':SHA(base),'moment_manifest_sha256':SHA(manifest_path.read_bytes()),
                     'moment_result_sha256':SHA((ROOT/'kivi-value-error-moment'/f'{tag}-result.json').read_bytes())}
        audits[tag]={'receipt_sha256':SHA(cpu_path.read_bytes()),'physical_snapshot_sha256':audit['snapshot_sha256']}
    return {'source_hash':SHA(''.join(f'{p} {h}\n' for p,h in c['source_sha256'].items()).encode()),
        'binary_sha256':c['binary_sha256'],'assembly_sha256':c['assembly_sha256'],
        'cpu_reference_sha256':SHA((HERE/'cpu-reference').read_bytes()),
        'cpu_reference_source_sha256':SHA((ROOT/'kivi-stable-resident'/'cpu.cpp').read_bytes()),
        'original_o_sha256':SHA(o),'inputs':inputs,'donors':donors,'cpu_audits':audits,'bill':bill,
        'kernels':c['device_kernels'],
        'schedule':{'accept':{'rounds':1,'order':[0,1],'windows':4,'audited_phases_per_arm':512},
                    'timing':{'rounds_per_window':4,'first_mode':'(window+round)%2','measured_steps':[128,256],
                              'fresh_empty_per_arm_round':True,'matched_pairs':32}}}

def main():
    if len(sys.argv)>1 and sys.argv[1]=='prepare':
        import score
        for n in range(4):score.prepare(f'held-{n}')
    r=receipt()
    if len(sys.argv)>1 and sys.argv[1]=='prepare':
        (HERE/'prelaunch-receipt.json').write_text(json.dumps(r,indent=2)+'\n')
    else:assert r==json.loads((HERE/'prelaunch-receipt.json').read_text())
    print(json.dumps({'source_hash':r['source_hash'],'binary_sha256':r['binary_sha256'],'bill':r['bill']}))
if __name__=='__main__':main()
