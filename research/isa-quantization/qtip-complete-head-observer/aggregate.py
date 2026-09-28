"""Combine every source window; sum squared-error numerators/denominators before division."""
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
out={}
for panel,count in [('train',8),('held',4)]:
    records=[json.loads((HERE/f'{panel}-{i}.json').read_text()) for i in range(count)]
    assert all(r['panel']==panel and r['window']==i and r['source_rows']==[256*i,256*(i+1)] and r['capture_model_q_exact'] for i,r in enumerate(records))
    assert len({tuple(sorted(r['images_sha256'].items())) for r in records})==1
    out[panel]={}
    for mode in records[0]['modes']:
        assert all(mode in r['modes'] for r in records)
        group=[r['modes'][mode] for r in records]
        assert all(g['counts']['query_tokens']==256 and g['counts']['visible_causal_pairs']==32896 for g in group)
        totals={key:sum(g['counts'][key] for g in group) for key in group[0]['counts']}
        out[panel][mode]={
            'attention_kl':sum(g['attention_kl'] for g in group)/count,
            'gqa_pair_mean_attention_kl':sum(g['gqa_pair_mean_attention_kl'] for g in group)/count,
            'post_o_rel_sq':totals['head0_post_o_sse']/totals['head0_post_o_ref_sq'],
            'gqa_pair_post_o_rel_sq':totals['gqa_pair_post_o_sse']/totals['gqa_pair_post_o_ref_sq'],
            'raw_q_rel_sq_bf16':totals['raw_q_sse']/totals['raw_q_ref_sq'],
            'normalized_q_rel_sq':totals['normalized_q_sse']/totals['normalized_q_ref_sq'],
            'centered_score_rel_sq':totals['centered_score_sse']/totals['centered_score_ref_sq'],
            'teacher_score_variance_mean':sum(g['teacher_score_variance_mean'] for g in group)/count,
            'score_oscillation_mean':sum(g['score_oscillation_mean'] for g in group)/count,
            'score_oscillation_max':max(g['score_oscillation_max'] for g in group),
            'certified_kl_lower_mean':sum(g['certified_kl_lower_mean'] for g in group)/count,
            'certified_kl_upper_mean':sum(g['certified_kl_upper_mean'] for g in group)/count,
            'counts':totals,
            'per_window':[{key:g[key] for key in ('attention_kl','post_o_rel_sq','gqa_pair_post_o_rel_sq','raw_q_rel_sq','normalized_q_rel_sq','teacher_score_variance_mean')} for g in group],
        }
(HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
