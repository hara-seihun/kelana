"""Combine all 12×256 oracle hull diagnostics with frozen endpoints."""
from pathlib import Path
import hashlib
import json
import numpy as np

HERE=Path(__file__).resolve().parent
BALANCED=HERE.parent/'qwen-balanced-feature-reader/results.json'
BALANCED_SHA='d24b099c3454172dbce5a51b63deb9e4a4ea2c080eb745dabb8524e7d68a6174'
KIVI=HERE.parent/'kivi-causal-cache/results.json'
KIVI_SHA='77a97c453f40593ab8f1f2f3a0d5c8d06cb424ea28b758fbe7b4ec874e8acebf'
GAMMA='c8173158c88975e808804bb89a9e59b4cfa485a60f8d854fc4963ad89c830865'
CENTER='3e9fa69a8942b762f0cd041e6a70bfa0c7833957f0d960a6032b0775058cd6a2'
TABLE='c79b3d345a0bfc6a1b2e4a6e8f04246e5b7750e885ae17f3eb36ad66d53d86f5'

def summary(rows,denominator):
    result={}
    for state in ('fp32_prefix_state','fp64_finite_table_state'):
        item={}
        for cutoff in ('float64_cutoff','float32_resolved_cutoff'):
            values=[r[state][cutoff] for r in rows]
            ranks=np.array([v['numerical_rank'] for v in values])
            conditions=np.array([v['condition_of_kept_span'] for v in values])
            item[cutoff]={
                'relative_squared_floor':sum(v['sse'] for v in values)/denominator,
                'absolute_sse':sum(v['sse'] for v in values),
                'rank_min_median_max':[int(ranks.min()),float(np.median(ranks)),int(ranks.max())],
                'retained_condition_median_max':[float(np.median(conditions)),float(np.max(conditions))],
                'ranks_exceed_algebraic_cap':int(sum(v['numerical_rank']>r['theoretical_affine_rank_cap'] for r,v in zip(rows,values)))}
        result[state]=item
    result['mean_max_abs_fp32_vs_fp64_feature_value']=float(np.mean([r['fp32_prefix_means_vs_fp64_max_abs'] for r in rows]))
    result['max_abs_fp32_vs_fp64_feature_value']=max(r['fp32_prefix_means_vs_fp64_max_abs'] for r in rows)
    return result

def main():
    assert hashlib.sha256(BALANCED.read_bytes()).hexdigest()==BALANCED_SHA
    assert hashlib.sha256(KIVI.read_bytes()).hexdigest()==KIVI_SHA
    balanced=json.loads(BALANCED.read_text())
    kivi=json.loads(KIVI.read_text())
    output={'frozen_sha256':{'balanced_reader_results':BALANCED_SHA,'kivi_results':KIVI_SHA},'panels':{}}
    for panel,n in (('train',8),('inspected_held',4)):
        prefix='held' if panel=='inspected_held' else 'train'
        rows=[]
        for window in range(n):
            for chunk in range(4):
                r=json.loads((HERE/f'{prefix}-{window}-chunk{chunk}.json').read_text())
                assert r['panel']==prefix and r['window']==window and r['chunk']==chunk
                assert r['image_sha256']=={'gamma':GAMMA,'center':CENTER,'generic_table':TABLE}
                assert [a['position'] for a in r['rows']]==list(range(chunk*64,(chunk+1)*64))
                rows.extend(r['rows'])
        denominator=sum(r['teacher_pair_o_ref_sq'] for r in rows)
        assert denominator>0
        output['panels'][panel]={'positions':len(rows),'teacher_pair_o_ref_sq':denominator,
            'all_positions':summary(rows,denominator),
            'short_positions_1_to_64':summary([r for r in rows if r['position']<64],sum(r['teacher_pair_o_ref_sq'] for r in rows if r['position']<64)),
            'later_positions_65_to_256':summary([r for r in rows if r['position']>=64],sum(r['teacher_pair_o_ref_sq'] for r in rows if r['position']>=64)),
            'frozen_actual_balanced_pair_o_rel_sq':balanced['panels'][panel]['balanced_centered']['gqa_pair_post_o_rel_sq'],
            'frozen_kivi_pair_o_rel_sq':kivi[prefix]['kivi']['gqa_pair']['post_o_rel_sq']}
    (HERE/'results.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({p:{'all_positions':{s:{c:v['relative_squared_floor'] for c,v in d.items()} for s,d in r['all_positions'].items() if s in ('fp32_prefix_state','fp64_finite_table_state')},
        'balanced':r['frozen_actual_balanced_pair_o_rel_sq'],'kivi':r['frozen_kivi_pair_o_rel_sq']} for p,r in output['panels'].items()},indent=2))

if __name__=='__main__':main()
