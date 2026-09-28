"""Exact-stage receipt reduction: all 32 matched boundary pairs, no exclusions."""
import hashlib,json,statistics
from pathlib import Path
import stage_receipt
HERE=Path(__file__).resolve().parent
SHA=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
FIELDS=('step_event_us','input_span_us','compute_span_us','step_wall_us')
LIFECYCLE=('arm_allocation_us','replay_256_wall_us','arm_teardown_us','arm_total_wall_us')

def guard_maxima(observations,samples):
    return {'acceptance':{f:max(x[f] for x in observations) for f in ('max_abs','relative_l2')},
            'timing':{arm:{f:max(x[arm][f] for x in samples) for f in ('max_abs','relative_l2')}
                      for arm in ('control','candidate')}}

def main():
    expected=stage_receipt.gate()
    accepted=[];timed=[];samples=[];audits=[]
    for n in range(4):
        tag=f'held-{n}'
        for phase in ('accept','timing'):
            r=json.loads((HERE/f'{phase}-{tag}-receipt.json').read_text())
            assert r['window']==tag and r['phase']==phase
            assert r['source_hash']==expected['source_hash'] and r['binary_sha256']==expected['binary_sha256']
            assert r['trace_sha256']==SHA(HERE/f'{phase}-{tag}.jsonl')
            assert r['attempt_sha256']==SHA(HERE/f'attempt-{phase}-{tag}.txt')
            assert len(r['rows'])==(4 if phase=='accept' else 16)
            (accepted if phase=='accept' else timed).append(r)
        audits.append({'window':tag,**accepted[-1]['audit']})
        output={(x['round'],x['mode'],x['t']):x for x in timed[-1]['timing_actual_outputs']}
        assert len(output)==16
        rows={(x['round'],x['mode'],x['t']):x for x in timed[-1]['rows']}
        assert len(rows)==16
        for round_ in range(4):
            for t in (128,256):
                control=rows[round_,0,t];candidate=rows[round_,1,t]
                pair={'window':tag,'round':round_,'t':t,'first_mode':(n+round_)%2,
                      'control':{k:control[k] for k in FIELDS},
                      'candidate':{k:candidate[k] for k in FIELDS},
                      'paired_event_ratio':candidate['step_event_us']/control['step_event_us']}
                for mode in (0,1):
                    r=output[round_,mode,t]
                    path=HERE/f'{tag}-t{t}-mode{mode}-round{round_}-actual.f32'
                    assert path.stat().st_size==4096 and SHA(path)==r['sha256']
                    pair['candidate' if mode else 'control']['actual_sha256']=r['sha256']
                    pair['candidate' if mode else 'control']['max_abs']=r['max_abs']
                    pair['candidate' if mode else 'control']['relative_l2']=r['relative_l2']
                samples.append(pair)
    assert len(samples)==32 and sum(x['first_mode'] for x in samples)==16
    assert all(a['frames']==1024 and a['ordered_records']==1089536 and a['candidate_codes']==229376 for a in audits)
    assert sum(a['snapshot_bytes'] for a in audits)==4*312487936
    observations=[x for r in accepted for x in r['full_outputs']]
    assert len(observations)==16
    pooled_sse={str(mode):sum(x['teacher_sse'] for x in observations if x['mode']==mode) for mode in (0,1)}
    paired={str(t):{'count':sum(x['t']==t for x in samples),
                     'median_ratio':statistics.median(x['paired_event_ratio'] for x in samples if x['t']==t),
                     'min_ratio':min(x['paired_event_ratio'] for x in samples if x['t']==t),
                     'max_ratio':max(x['paired_event_ratio'] for x in samples if x['t']==t)} for t in (128,256)}
    paired['all']={'count':len(samples),'median_ratio':statistics.median(x['paired_event_ratio'] for x in samples),
                   'min_ratio':min(x['paired_event_ratio'] for x in samples),
                   'max_ratio':max(x['paired_event_ratio'] for x in samples),
                   'candidate_faster_count':sum(x['paired_event_ratio']<1 for x in samples)}
    spans={str(mode):{f:statistics.median(x['candidate' if mode else 'control'][f] for x in samples) for f in FIELDS} for mode in (0,1)}
    lifecycle={str(mode):{f:statistics.median(row[f] for r in timed for row in r['lifecycle'] if row['mode']==mode) for f in LIFECYCLE} for mode in (0,1)}
    receipt={'source_hash':expected['source_hash'],'binary_sha256':expected['binary_sha256'],
             'schedule':expected['schedule'],'allocation_bill':expected['bill'],
             'acceptance_audits':audits,'acceptance_outputs':observations,'guard_maxima':guard_maxima(observations,samples),
             'pooled_actual_teacher_sse':pooled_sse,'pooled_improvement_vs_control':1-pooled_sse['1']/pooled_sse['0'],
             'paired_event_ratio':paired,'median_spans_us':spans,'median_lifecycle_us':lifecycle,
             'timing_shared_setup_us':[r['shared_setup']['wall_us'] for r in timed],
             'timing_shared_teardown_us':[r['shared_teardown']['wall_us'] for r in timed],
             'all_32_matched_pairs':samples,
             'stage_receipts':{phase+'-'+f'held-{n}':SHA(HERE/f'{phase}-held-{n}-receipt.json') for phase in ('accept','timing') for n in range(4)}}
    (HERE/'results.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'actual_teacher_sse':pooled_sse,'paired_event_ratio':paired,'median_spans_us':spans,'median_lifecycle_us':lifecycle}))
if __name__=='__main__':main()
