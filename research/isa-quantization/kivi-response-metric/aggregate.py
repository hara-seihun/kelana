"""Require all eight train and four held causal receipts; aggregate absolute losses."""
from pathlib import Path
import json
HERE=Path(__file__).resolve().parent
manifest=json.loads((HERE/'metric-manifest.json').read_text())
result={'metric_sha256':manifest['metric_image_sha256'],'metric_bytes':manifest['metric_image_bytes'],
        'peak_cache_bytes':52400,'peak_cache_plus_metric_bytes':54704,'panels':{}}
for panel,n in [('train',8),('held',4)]:
    rows=[];checks=[]
    for i in range(n):
        row=json.loads((HERE/f'{panel}-{i}.json').read_text())
        replay=json.loads((HERE/f'{panel}-{i}-replay.json').read_text())
        assert row['metric_fp16_sha256']==manifest['metric_image_sha256']
        assert replay['final_sha256']==row['final_sha256'] and replay['verified_causal_prefixes']==256
        assert replay['verified_k_flushes']==8 and replay['verified_identical_v_flushes']==224
        assert replay['all_key_chunk_metric_nonincreasing']
        assert row['peak_state_plus_metric_bytes']==54704 and replay['peak_state_plus_metric_bytes']==54704
        rows.append(row);checks.append(replay)
    sse=sum(x['gqa_pair']['post_o_sse'] for x in rows)
    base=sum(x['gqa_pair']['control_post_o_sse'] for x in rows)
    reference=sum(x['gqa_pair']['post_o_ref_sq'] for x in rows)
    original=[json.loads((HERE.parent/'kivi-causal-cache'/f'{panel}-{i}-result.json').read_text()) for i in range(n)]
    g={'pair_post_o_rel_sq':sse/reference,'control_pair_post_o_rel_sq':base/reference,
       'relative_pair_sse_change':sse/base-1,'changed_key_digits':sum(x['changed_key_digits'] for x in rows),
       'original_key_digits':n*8*32*128,'before_metric':sum(c['metric_before'] for x in rows for c in x['key_flushes']),
       'after_metric':sum(c['metric_after'] for x in rows for c in x['key_flushes']),
       'head_kl':{},'head_post_o_rel_sq':{},'windows':[]}
    g['metric_relative_decrease']=1-g['after_metric']/g['before_metric']
    for h in range(2):
        k=f'head{h}'
        g['head_kl'][k]={'candidate':sum(x['heads'][k]['attention_kl'] for x in rows)/n,
                          'control':sum(x['heads'][k]['control_attention_kl'] for x in rows)/n}
        denom=sum(x['heads'][k]['post_o_ref_sq'] for x in rows)
        g['head_post_o_rel_sq'][k]={'candidate':sum(x['heads'][k]['post_o_sse'] for x in rows)/denom,
                                   'control':sum(x['heads'][k]['post_o_sse'] for x in original)/denom}
    for i,row in enumerate(rows):
        g['windows'].append({'window':i,'pair_rel_sq':row['gqa_pair']['post_o_rel_sq'],
                             'control_pair_rel_sq':row['gqa_pair']['control_post_o_rel_sq'],
                             'image_sha256':row['final_sha256'],
                             'causal_replay_verified':checks[i]['verified_causal_prefixes']})
    result['panels'][panel]=g
(HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
