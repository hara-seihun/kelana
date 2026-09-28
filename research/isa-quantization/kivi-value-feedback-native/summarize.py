"""Reduce frozen alternating fresh-trace pairs without discarding the raw timings."""
import hashlib
import json
import statistics
from pathlib import Path
HERE=Path(__file__).resolve().parent
SHA=lambda b:hashlib.sha256(b).hexdigest()

def main():
    from stage_receipt import gate
    pre=gate()
    pairs=[];accept=[];files={}
    for n in range(4):
        tag=f'held-{n}'
        for phase in ('accept','timing'):
            p=HERE/f'{phase}-{tag}-receipt.json'
            blob=p.read_bytes();files[p.name]=SHA(blob);r=json.loads(blob)
            assert r['source_hash']==pre['source_hash'] and r['binary_sha256']==pre['binary_sha256']
            if phase=='accept':accept.extend(r['full_outputs'])
            else:
                for round in range(4):
                    for t in (128,256):
                        rows={row['mode']:row for row in r['rows'] if row['round']==round and row['t']==t}
                        assert set(rows)=={0,1}
                        pairs.append({'window':n,'round':round,'t':t,'first_mode':(n+round)%2,
                                      'control':rows[0],'feedback':rows[1]})
    assert len(pairs)==32 and len(accept)==16
    metrics=['step_event_us','input_span_us','compute_span_us','step_wall_us']
    summary={}
    for t in (128,256,'all'):
        sample=[p for p in pairs if t=='all' or p['t']==t]
        summary[str(t)]={metric:{'control_median':statistics.median(p['control'][metric] for p in sample),
                                  'feedback_median':statistics.median(p['feedback'][metric] for p in sample),
                                  'median_paired_ratio':statistics.median(p['feedback'][metric]/p['control'][metric] for p in sample),
                                  'feedback_faster_pairs':sum(p['feedback'][metric]<p['control'][metric] for p in sample),
                                  'pairs':len(sample)} for metric in metrics}
    output={'source_hash':pre['source_hash'],'binary_sha256':pre['binary_sha256'],'bill':pre['bill'],'kernel_resources':pre['kernels'],
            'receipt_sha256':files,'audited_device_frames':4096,'feedback_residual_phase_checks':16384,
            'complete_o_guards':accept,'pooled_teacher_sse':{str(m):sum(row['teacher_sse'] for row in accept if row['mode']==m) for m in (0,1)},
            'paired_event_summary':summary,'pairs':pairs}
    (HERE/'results.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({'paired_event_summary':summary,'pooled_teacher_sse':output['pooled_teacher_sse']}))
if __name__=='__main__':main()
