"""Require all 12 frozen windows, matching source KIVI and packed map."""
from pathlib import Path
import json

HERE=Path(__file__).resolve().parent
OWNER=HERE.parent/'kivi-causal-cache'
out={}
for panel,n in (('train',8),('held',4)):
    rows=[json.loads((HERE/f'{panel}-{i}.json').read_text()) for i in range(n)]
    old=[json.loads((OWNER/f'{panel}-{i}-result.json').read_text()) for i in range(n)]
    assert all(r['window']==o['window']==i and r['final_image_sha256']==o['final_image_sha256'] for i,(r,o) in enumerate(zip(rows,old)))
    out[panel]={}
    for h in range(2):
        group=[r['heads'][f'head{h}'] for r in rows]
        prior=[r['heads'][f'head{h}'] for r in old]
        out[panel][f'head{h}']={
            'packed_kl':sum(g['attention_kl'] for g in group)/n,
            'packed_post_o_rel_sq':sum(g['post_o_sse'] for g in group)/sum(g['post_o_ref_sq'] for g in group),
            'conventional_post_o_rel_sq':sum(g['ordinary_post_o_sse'] for g in group)/sum(g['post_o_ref_sq'] for g in group),
            'original_kivi_kl':sum(g['attention_kl'] for g in prior)/n,
            'original_kivi_post_o_rel_sq':sum(g['post_o_sse'] for g in prior)/sum(g['post_o_ref_sq'] for g in prior),
        }
        assert abs(out[panel][f'head{h}']['packed_kl']-out[panel][f'head{h}']['original_kivi_kl'])<2e-6
    group=[r['gqa_pair'] for r in rows];prior=[r['gqa_pair'] for r in old]
    denominator=sum(g['post_o_ref_sq'] for g in group)
    out[panel]['pair']={
        'packed_post_o_rel_sq':sum(g['post_o_sse'] for g in group)/denominator,
        'conventional_post_o_rel_sq':sum(g['ordinary_post_o_sse'] for g in group)/denominator,
        'original_kivi_post_o_rel_sq':sum(g['post_o_sse'] for g in prior)/sum(g['post_o_ref_sq'] for g in prior),
    }
    assert abs(out[panel]['pair']['packed_post_o_rel_sq']-out[panel]['pair']['original_kivi_post_o_rel_sq'])<1e-7
    out[panel]['max_abs_direct_vs_conventional']={key:max(r['maxima_vs_conventional'][key] for r in rows) for key in rows[0]['maxima_vs_conventional']}
(HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
