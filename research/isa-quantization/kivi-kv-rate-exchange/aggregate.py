"""Aggregate the frozen retained-state exchange with one common teacher denominator."""
import json
from pathlib import Path
from controls import read_controls

HERE=Path(__file__).resolve().parent
runs=[json.loads((HERE/f'held-{i}-result.json').read_text()) for i in range(4)]
plans=[json.loads((HERE/f'held-{i}-manifest.json').read_text()) for i in range(4)]
assert [r['window'] for r in runs]==[0,1,2,3]
assert [m['window'] for m in plans]==[0,1,2,3]
controls=read_controls()
per=[]
for w,(r,m) in enumerate(zip(runs,plans)):
    for index,t in enumerate((128,256)):
        reference=r['arms']['K2V4']['retained'][index]['teacher_sq']
        assert abs(reference-r['arms']['K4V2']['retained'][index]['teacher_sq'])<1e-7
        original=controls['records'][str(w)]
        two=original['kivi2_retained'][index]
        four=original['receipt']['retained'][index]
        assert abs(reference-two['teacher_sq'])<1e-6 and abs(reference-four['teacher_sq'])<1e-6
        per.append({'window':w,'t':t,'teacher_sq':four['teacher_sq'],
                    'K2V4_sse':r['arms']['K2V4']['retained'][index]['teacher_sse'],
                    'K4V2_sse':r['arms']['K4V2']['retained'][index]['teacher_sse'],
                    'K2V2_sse':two['control_teacher_sse'],
                    'K4V4_sse':four['kivi4_teacher_sse']})
reference=sum(x['teacher_sq'] for x in per)
pooled={a:{'sse':sum(x[f'{a}_sse'] for x in per),
           'relative_sq':sum(x[f'{a}_sse'] for x in per)/reference} for a in ('K2V4','K4V2','K2V2','K4V4')}
ledger={}
for arm,(kb,vb) in {'K2V4':(2,4),'K4V2':(4,2)}.items():
    kcode=32*128*kb//8;vcode=128*vb//8
    points={}
    for t in (128,256):
        nk=(t-1)//32;nv=t-33;kr=32;vr=33
        perhead={'key_code':nk*kcode,'key_fields':nk*512,'value_code':nv*vcode,
                 'value_fields':nv*16,'key_recent_bf16':kr*256,'value_recent_bf16':vr*256}
        points[str(t)]={**{k:8*v for k,v in perhead.items()},'total_bytes':8*sum(perhead.values())}
        assert points[str(t)]['total_bytes']==plans[0]['arms'][arm]['groups'][0]['prefixes'][t-1]['before']['bytes']*8
    final={'key_code':8*kcode*8,'key_fields':8*512*8,'value_code':224*vcode*8,
           'value_fields':224*16*8,'key_recent_bf16':0,'value_recent_bf16':32*256*8}
    assert sum(final.values())==plans[0]['arms'][arm]['final_bytes']
    assert points['256']['total_bytes']==plans[0]['arms'][arm]['peak_bytes']
    ledger[arm]={'before_query':points,'after_query_t256':{**final,'total_bytes':sum(final.values())},
                 'flush_events_per_256_window':{'key_chunks':64,'value_tokens':1792}}
result={'scope':'frozen K2V4 versus K4V2 event exchange; complete full-O at four held streams × t128/t256 only',
        'source_control_commit':controls['source_commit'],'teacher_sq':reference,
        'per_state':per,'pooled':pooled,'ledgers':ledger,
        'peak_difference_K4V2_minus_K2V4_bytes':ledger['K4V2']['before_query']['256']['total_bytes']-ledger['K2V4']['before_query']['256']['total_bytes'],
        'source_manifest_sha256':[r['controls_sha256'] for r in runs]}
(HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'teacher_sq':reference,'pooled':pooled,'peak_difference_bytes':result['peak_difference_K4V2_minus_K2V4_bytes']}))
