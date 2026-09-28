"""Require all twelve windows and aggregate complete GQA outputs and paid controls."""
from pathlib import Path
import json

HERE=Path(__file__).resolve().parent
TABLE_SHA='c79b3d345a0bfc6a1b2e4a6e8f04246e5b7750e885ae17f3eb36ad66d53d86f5'

def combine(records):
    heads={}
    for h in ('head0','head1'):
        rows=[r['heads'][h] for r in records]
        heads[h]={'attention_kl':sum(v['attention_kl'] for v in rows)/len(rows),
            'post_o_rel_sq':sum(v['output_sse'] for v in rows)/sum(v['output_ref_sq'] for v in rows)}
    pair=[r['gqa_pair'] for r in records]
    return {'heads':heads,
        'gqa_pair_post_o_rel_sq':sum(v['output_sse'] for v in pair)/sum(v['output_ref_sq'] for v in pair),
        'per_window_head0_kl':[r['heads']['head0']['attention_kl'] for r in records],
        'per_window_pair_post_o':[r['gqa_pair']['post_o_rel_sq'] for r in records]}

def main():
    output={}
    for panel,n in (('train',8),('inspected_held',4)):
        prefix='held' if panel=='inspected_held' else 'train'
        kernel=[json.loads((HERE/f'{prefix}-{i}.json').read_text()) for i in range(n)]
        controls=[json.loads((HERE/f'{prefix}-{i}-control.json').read_text()) for i in range(n)]
        for i,(a,b) in enumerate(zip(kernel,controls)):
            assert a['panel']==b['panel']==prefix and a['window']==b['window']==i
            assert a['rows']==[256*i,256*(i+1)] and a['table_sha256']==TABLE_SHA
            assert a['fixture_sha256']==b['fixture_sha256'] and a['capture_model_q_exact']
            assert b['modes']['q4']['bytes']==34816 and b['modes']['q6']['bytes']==51200
        output[panel]={'positive_feature_rank64':combine(kernel),
            'affine_kv_q4':combine([c['modes']['q4'] for c in controls]),
            'affine_kv_q6':combine([c['modes']['q6'] for c in controls]),
            'feature_log_ranges':{
                'shared_key':[min(a['shared_log_feature_min_max'][0] for a in kernel),max(a['shared_log_feature_min_max'][1] for a in kernel)],
                'head0_query':[min(a['heads']['head0']['log_feature_min_max'][0] for a in kernel),max(a['heads']['head0']['log_feature_min_max'][1] for a in kernel)],
                'head1_query':[min(a['heads']['head1']['log_feature_min_max'][0] for a in kernel),max(a['heads']['head1']['log_feature_min_max'][1] for a in kernel)]}}
    (HERE/'results.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps(output,indent=2))

if __name__=='__main__':main()
