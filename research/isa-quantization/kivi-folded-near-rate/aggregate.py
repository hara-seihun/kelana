"""All twelve fixed compositions: ratio of summed SSE to summed teacher energy."""
from pathlib import Path
import json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
OWNERS={'folded':ROOT/'kivi-v-channel-fold','metric':ROOT/'kivi-response-metric',
        'v45':ROOT/'kivi-v45-control','original':ROOT/'kivi-causal-cache'}
summary={'panels':{},'peak_A_bytes':54704,'peak_B_bytes':54688,
         'shared_folded_v_o_source_replacement_bytes':786432,'shared_folded_v_o_source_extra_bytes':0}
for panel,n in (('train',8),('held',4)):
    records={arm:[] for arm in ('A','B')}
    controls={k:[] for k in OWNERS}
    for i in range(n):
        for arm in ('A','B'):
            row=json.loads((HERE/f'{panel}-{i}-{arm}-result.json').read_text())
            image=json.loads((HERE/f'{panel}-{i}-{arm}-manifest.json').read_text())
            assert row['verified_preflush_hashes']==256
            assert row['verified_identical_key_donor_events']==8
            assert row['verified_identical_folded_value_donor_events']==image['v_events']==(224 if arm=='A' else 211)
            assert row['verified_folded_value_source_grids']==image['v_events']
            assert row['final_sha256']==image['final_sha256']
            assert row['complete_peak_bytes']==image['complete_peak_bytes']==(54704 if arm=='A' else 54688)
            records[arm].append(row)
        controls['folded'].append(json.loads((OWNERS['folded']/f'{panel}-{i}-result.json').read_text()))
        controls['metric'].append(json.loads((OWNERS['metric']/f'{panel}-{i}.json').read_text()))
        controls['v45'].append(json.loads((OWNERS['v45']/f'{panel}-{i}.json').read_text()))
        controls['original'].append(json.loads((OWNERS['original']/f'{panel}-{i}-result.json').read_text()))
    panel_summary={'arms':{},'controls':{},'windows':[]}
    for arm,rows in records.items():
        numerator=sum(r['gqa_pair']['post_o_sse'] for r in rows)
        denom=sum(r['gqa_pair']['post_o_ref_sq'] for r in rows)
        head={}
        for h in (0,1):
            label=f'head{h}';energy=sum(r['heads'][label]['post_o_ref_sq'] for r in rows)
            head[label]={'attention_kl':sum(r['heads'][label]['attention_kl'] for r in rows)/n,
                         'post_o_rel_sq':sum(r['heads'][label]['post_o_sse'] for r in rows)/energy}
        panel_summary['arms'][arm]={'pair_post_o_rel_sq':numerator/denom,'pair_post_o_sse':numerator,
                                    'pair_post_o_ref_sq':denom,'heads':head,
                                    'image_sha256':[r['final_sha256'] for r in rows]}
    for name,rows in controls.items():
        panel_summary['controls'][name]={'pair_post_o_rel_sq':sum(r['gqa_pair']['post_o_sse'] for r in rows)/sum(r['gqa_pair']['post_o_ref_sq'] for r in rows)}
    A=panel_summary['arms']['A'];B=panel_summary['arms']['B']
    panel_summary['A_pair_error_change_from_B']=A['pair_post_o_sse']/B['pair_post_o_sse']-1
    for i in range(n):
        panel_summary['windows'].append({'window':i,'A_pair_rel_sq':records['A'][i]['gqa_pair']['post_o_rel_sq'],
                                         'B_pair_rel_sq':records['B'][i]['gqa_pair']['post_o_rel_sq']})
    summary['panels'][panel]=panel_summary
(HERE/'results.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
