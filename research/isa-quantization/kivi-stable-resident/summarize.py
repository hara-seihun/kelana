"""Recompute the bounded resident-cache result from immutable audited stage receipts."""
import json
import math
import statistics
from pathlib import Path
HERE=Path(__file__).resolve().parent
read=lambda p:json.loads((HERE/p).read_text())
pre=read('prelaunch-receipt.json');compile=read('compile-receipt.json')
assert compile['binary_sha256']==pre['binary_sha256']
accept=[read(f'accept-held-{i}-receipt.json') for i in range(4)]
timing=[read(f'timing-held-{i}-receipt.json') for i in range(4)]
for phase,receipts in (('accept',accept),('timing',timing)):
    for i,r in enumerate(receipts):
        assert (r['phase'],r['window'],r['guards'],r['source_hash'],r['binary_sha256'])==(phase,f'held-{i}',4,pre['source_hash'],pre['binary_sha256'])
        assert len(r['rows'])==4 and {(row['mode'],row['t']) for row in r['rows']}=={(m,t) for m in (0,1) for t in (128,256)}
        assert all(math.isfinite(row['max_abs']) and row['max_abs']<=.005 and math.isfinite(row['relative_l2']) and row['relative_l2']<=.005 for row in r['rows'])
for r in accept:
    assert r['audit']['backend']=='device' and r['audit']['0']['phases']==r['audit']['1']['phases']==512
    assert r['audit']['0']['ordered_original_records']==r['audit']['1']['ordered_original_records']==606272
rows={(i,mode,t):next(row for row in timing[i]['rows'] if row['mode']==mode and row['t']==t) for i in range(4) for mode in (0,1) for t in (128,256)}
fields=('step_event_us','input_span_us','compute_span_us','step_wall_us')
metric=lambda subset:{field:statistics.median(x[field] for x in subset) for field in fields}
by_step={}
for t in (128,256):
    control=[rows[(i,0,t)] for i in range(4)]
    stable=[rows[(i,1,t)] for i in range(4)]
    ratios=[stable[i]['step_event_us']/control[i]['step_event_us'] for i in range(4)]
    by_step[str(t)]={'control_medians_us':metric(control),'stable_medians_us':metric(stable),'matched_event_ratios':ratios,'median_matched_event_ratio':statistics.median(ratios)}
ratios=[rows[(i,1,t)]['step_event_us']/rows[(i,0,t)]['step_event_us'] for i in range(4) for t in (128,256)]
kernels=compile['device_kernels']
result={
 'scope':'layer-0, four held streams, original two retained Q per stream; t128/t256 K32 and V33 flush-boundary steps, one measurement/arm/state control first',
 'source_hash':pre['source_hash'],'binary_sha256':pre['binary_sha256'],
 'device_acceptance':{'phases':4096,'original_ordered_record_checks':sum(r['audit'][str(mode)]['ordered_original_records'] for r in accept for mode in (0,1)),
   'full_output_guards':16,'max_abs':max(row['max_abs'] for r in accept for row in r['rows']),
   'max_relative_l2':max(row['relative_l2'] for r in accept for row in r['rows']),
   'max_arm_difference':max(max(r['arm_max_abs'].values()) for r in accept),
   'teacher_sse_by_arm':{str(mode):sum(r['teacher_sse'][f't{t}-mode{mode}'] for r in accept for t in (128,256)) for mode in (0,1)},
   'snapshot_sha256':{f'held-{i}':r['audit']['snapshot_sha256'] for i,r in enumerate(accept)},
   'snapshot_zst_sha256':{f'held-{i}':r['snapshot_zst_sha256'] for i,r in enumerate(accept)}},
 'timing':{'by_step':by_step,'all_control_medians_us':metric([rows[(i,0,t)] for i in range(4) for t in (128,256)]),
           'all_stable_medians_us':metric([rows[(i,1,t)] for i in range(4) for t in (128,256)]),
           'all_matched_event_ratios':ratios,'median_matched_event_ratio':statistics.median(ratios)},
 'resources':{'device_global_bytes':pre['device_bytes'],'module_body_bytes':sum(k['body_bytes'] for k in kernels),
              'module_descriptor_bytes':64*len(kernels),'kernels':kernels,
              'query_lds_bytes_per_cta':{'stable':next(k['lds'] for k in kernels if 'query_groupILi1' in k['symbol']),
                                         'control':next(k['lds'] for k in kernels if 'query_groupILi0' in k['symbol'])},
              'host_empty_candidate_staging_and_h2d_bytes':276428,'immutable_o_preparation_h2d_bytes':4194304},
 'stage_receipts':{f'{phase}-held-{i}':r['trace_sha256'] for phase,receipts in (('accept',accept),('timing',timing)) for i,r in enumerate(receipts)}
}
(HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'acceptance':result['device_acceptance'],'timing':result['timing']},indent=2))
