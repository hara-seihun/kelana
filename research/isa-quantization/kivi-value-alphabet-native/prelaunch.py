"""CPU-only pinned source/input, physical replay and allocation gate; no GPU call."""
import hashlib,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
SHA=lambda x:hashlib.sha256(x).hexdigest()

def receipt():
    c=json.loads((HERE/'compile-receipt.json').read_text())
    assert c['target']=='gfx1151' and len(c['device_kernels'])==7
    for path,digest in c['source_sha256'].items():assert SHA((HERE/path).read_bytes())==digest,path
    assert SHA((HERE/'native').read_bytes())==c['binary_sha256']
    assert SHA((HERE/'assembly-gfx1151.s').read_bytes())==c['assembly_sha256']
    assert all(k['private_scratch']==0 for k in c['device_kernels'])
    assert 8*18944+8*224*48+8*33*256+4==305156
    bill={'control_cache':305156,'candidate_cache':305156,'shared_static_table':16,
          'arrival':4096,'q':8192,'original_o':4194304,'partial_o':32768,'output':4096,
          'shared_explicit_globals':4243456,'control_active_globals':4548612,'candidate_active_globals':4548628,
          'device_code_body_all_loaded':sum(k['body_bytes'] for k in c['device_kernels']),
          'device_code_descriptors_all_loaded':sum(k['descriptor_bytes'] for k in c['device_kernels']),
          'maximum_lds_per_cta':max(k['lds'] for k in c['device_kernels']),
          'private_scratch_per_thread':max(k['private_scratch'] for k in c['device_kernels']),
          'host_snapshot_buffer':305156,'host_arrival_buffer':256*4098,'host_o_buffer':4194304,
          'host_table_buffer':16,'host_measured_q':8192,'host_measured_reference':4096,'host_measured_output':4096,
          'cpu_audit_streamed_snapshot_bytes_per_window':312487936}
    immutable=json.loads((ROOT/'kivi-two-bit-dot-native'/'snapshots.json').read_text())
    states={(x['window'],x['position']):x for x in immutable['states']}
    assert set(states)=={(n,t) for n in range(4) for t in (128,256)}
    o=(ROOT/'kivi-two-bit-dot-native'/'original-o.bf16').read_bytes()
    assert len(o)==4194304 and SHA(o)==immutable['original_o_sha256']
    table=(ROOT/'kivi-value-alphabet'/'layer0-alphabet.f32').read_bytes()
    fit=json.loads((ROOT/'kivi-value-alphabet'/'layer0-fit.json').read_text())
    assert len(table)==16 and SHA(table)==fit['table_sha256']
    inputs={};donors={};audits={}
    for n in range(4):
        tag=f'held-{n}'
        arrivals=(ROOT/'kivi-value-intern'/f'{tag}-events.bin').read_bytes()
        own=json.loads((ROOT/'kivi-value-intern'/f'{tag}-manifest.json').read_text())
        cpath=ROOT/'kivi-value-alphabet'/f'{tag}-layer0-manifest.json'
        cm=json.loads(cpath.read_text())
        result_path=ROOT/'kivi-value-alphabet'/f'{tag}-layer0-result.json'
        cr=json.loads(result_path.read_text())
        assert len(arrivals)==256*4098 and SHA(arrivals)==own['events_sha256']
        from audit import source
        checked_arrival,_=source(tag)
        assert checked_arrival==arrivals
        assert cm['table_sha256']==SHA(table) and cm['original_o_sha256']==SHA(o)
        assert cr['query_count']==2 and cr['table_sha256']==SHA(table)
        refs={}
        for t in (128,256):
            r=states[n,t];assert r['tag']==f'{tag}-t{t}'
            refs[str(t)]={}
            for ext,length,key in [('q.f32',8192,'query_sha256'),('teacher.f32',4096,'teacher_sha256'),('conventional-cpu.f32',4096,'cpu_conventional_sha256')]:
                raw=(ROOT/'kivi-two-bit-dot-native'/f'{tag}-t{t}-{ext}').read_bytes()
                assert len(raw)==length and SHA(raw)==r[key]
                refs[str(t)][ext]=SHA(raw)
            target=(HERE/f'{tag}-t{t}-alphabet-cpu.f32').read_bytes()
            row=next(x for x in cr['queries'] if x['t']==t)
            assert len(target)==4096 and SHA(target)==row['output_sha256']
            refs[str(t)]['alphabet_cpu_sha256']=SHA(target)
            for h in range(8):
                p=cm['heads'][h]['prefix'][t-1]
                image=(ROOT/'kivi-value-alphabet'/f'{tag}-layer0-t{t}-h{h}.bin').read_bytes()
                assert len(image)==p['before_bytes'] and SHA(image)==p['image_sha256']==p['before_sha256']
        audit_path=HERE/f'cpu-audit-{tag}.json'
        audit=json.loads(audit_path.read_text())
        assert audit['tag']==tag and audit['frames']==1024 and audit['candidate_codes']==8*224*128
        assert audit['ordered_records']==1089536 and audit['snapshot_bytes']==312487936
        inputs[tag]={'arrival_sha256':SHA(arrivals),'retained':refs}
        donors[tag]={'original_manifest_sha256':SHA((ROOT/'kivi-two-bit-causal'/f'{tag}-manifest.json').read_bytes()),
                     'candidate_manifest_sha256':SHA(cpath.read_bytes()),'candidate_result_sha256':SHA(result_path.read_bytes()),
                     'candidate_events_sha256':[x['events_sha256'] for x in cm['heads']]}
        audits[tag]={'receipt_sha256':SHA(audit_path.read_bytes()),'physical_snapshot_sha256':audit['snapshot_sha256']}
    sources=c['source_sha256']
    return {'source_hash':SHA(''.join(f'{p} {h}\n' for p,h in sources.items()).encode()),
        'binary_sha256':c['binary_sha256'],'assembly_sha256':c['assembly_sha256'],
        'cpu_reference_sha256':SHA((HERE/'cpu-reference').read_bytes()),
        'cpu_reference_source_sha256':SHA((ROOT/'kivi-stable-resident'/'cpu.cpp').read_bytes()),
        'table_sha256':SHA(table),'fit_sha256':SHA((ROOT/'kivi-value-alphabet'/'layer0-fit.json').read_bytes()),
        'original_o_sha256':SHA(o),'inputs':inputs,'donors':donors,'cpu_audits':audits,'bill':bill,
        'kernels':c['device_kernels'],
        'schedule':{'accept':{'rounds':1,'order':[0,1],'windows':4,'audited_phases_per_arm':512},
                    'timing':{'rounds_per_window':4,'first_mode':'(window+round)%2','measured_steps':[128,256],
                              'fresh_empty_per_arm_round':True,'matched_pairs':32}}}

def main():
    r=receipt()
    if len(sys.argv)>1 and sys.argv[1]=='prepare':
        (HERE/'prelaunch-receipt.json').write_text(json.dumps(r,indent=2)+'\n')
    else:assert r==json.loads((HERE/'prelaunch-receipt.json').read_text())
    print(json.dumps({'source_hash':r['source_hash'],'binary_sha256':r['binary_sha256'],'bill':r['bill']}))
if __name__=='__main__':main()
