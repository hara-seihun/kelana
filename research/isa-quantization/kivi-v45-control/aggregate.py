"""Require all 12 causal replay receipts, aggregate absolute SSE and compare paid controls."""
from pathlib import Path
import json
HERE=Path(__file__).resolve().parent
OWNER=HERE.parent/'kivi-causal-cache'
result={'arm':'original KIVI K G32/R32; V G32/R45 fixed','peak_cache_bytes':54688,
        'final_postflush_bytes':48880,'generic_or_model_static_bytes':0,
        'metric_16B_larger_reference':{'commit':'c31c930c0bfa829af5d7af03a9690da87b9f2008',
                                         'peak_cache_plus_model_metric_bytes':54704,
                                         'train_pair_post_o_rel_sq':0.00013152496578467426,
                                         'held_pair_post_o_rel_sq':0.00013515881533035225},
        'panels':{}}
for panel,n in (('train',8),('held',4)):
    rows=[];owner=[]
    for i in range(n):
        row=json.loads((HERE/f'{panel}-{i}.json').read_text())
        check=json.loads((HERE/f'{panel}-{i}-replay.json').read_text())
        control=json.loads((OWNER/f'{panel}-{i}-result.json').read_text())
        assert check['final_sha256']==row['final_sha256'] and check['verified_preflush_prefixes']==256
        assert check['verified_original_key_event_bytes']==8 and check['verified_original_value_event_bytes']==211
        assert check['verified_value_fields_against_source']==211 and check['peak_bytes']==row['preflush_peak_bytes']==54688
        assert abs(check['pair_post_o_sse']-row['gqa_pair']['post_o_sse'])<1e-6
        assert row['gqa_pair']['control_post_o_sse']==control['gqa_pair']['post_o_sse']
        rows.append(row);owner.append(control)
    sse=sum(r['gqa_pair']['post_o_sse'] for r in rows)
    baseline=sum(r['gqa_pair']['post_o_sse'] for r in owner)
    denom=sum(r['gqa_pair']['post_o_ref_sq'] for r in rows)
    group={'pair_post_o_rel_sq':sse/denom,'kivi_pair_post_o_rel_sq':baseline/denom,
           'relative_pair_sse_change_vs_kivi':sse/baseline-1,
           'head_kl':{},'head_post_o_rel_sq':{},'windows':[]}
    for h in range(2):
        name=f'head{h}'
        group['head_kl'][name]={'candidate':sum(r['heads'][name]['attention_kl'] for r in rows)/n,
                               'kivi':sum(r['heads'][name]['attention_kl'] for r in owner)/n}
        norm=sum(r['heads'][name]['post_o_ref_sq'] for r in rows)
        group['head_post_o_rel_sq'][name]={'candidate':sum(r['heads'][name]['post_o_sse'] for r in rows)/norm,
                                          'kivi':sum(r['heads'][name]['post_o_sse'] for r in owner)/norm}
    for i,row in enumerate(rows):
        group['windows'].append({'window':i,'pair_post_o_rel_sq':row['gqa_pair']['post_o_rel_sq'],
                                 'kivi_pair_post_o_rel_sq':row['gqa_pair']['control_post_o_rel_sq'],
                                 'image_sha256':row['final_sha256'],'causal_prefixes_verified':256})
    result['panels'][panel]=group
(HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
