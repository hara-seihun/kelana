"""Require all original source windows and aggregate paid causal KIVI control."""
from pathlib import Path
import json

HERE=Path(__file__).resolve().parent
out={}
for panel,n in [('train',8),('held',4)]:
    receipts=[json.loads((HERE/f'{panel}-{i}-result.json').read_text()) for i in range(n)]
    manifests=[json.loads((HERE/f'{panel}-{i}-manifest.json').read_text()) for i in range(n)]
    assert all(r['panel']==m['panel']==panel and r['window']==m['window']==i for i,(r,m) in enumerate(zip(receipts,manifests)))
    assert all(r['final_image_sha256']==m['final_sha256'] and r['flush_log_sha256']==m['flush_log_sha256'] for r,m in zip(receipts,manifests))
    assert all(m['max_live_state_bytes']==r['preflush_peak_bytes']==52400 and m['final_postflush_bytes']==r['postflush_final_bytes']==46592 for r,m in zip(receipts,manifests))
    h={}
    for j in range(2):
        group=[r['heads'][f'head{j}'] for r in receipts]
        h[f'head{j}']={
            'attention_kl':sum(g['attention_kl'] for g in group)/n,
            'post_o_rel_sq':sum(g['post_o_sse'] for g in group)/sum(g['post_o_ref_sq'] for g in group),
            'recent_fp32_k_sensitivity_attention_kl':sum(g['recent_fp32_k_sensitivity_attention_kl'] for g in group)/n,
            'recent_fp32_k_sensitivity_post_o_rel_sq':sum(g['recent_fp32_k_sensitivity_post_o_sse'] for g in group)/sum(g['post_o_ref_sq'] for g in group),
        }
    pair=[r['gqa_pair'] for r in receipts]
    h['gqa_pair']={
        'post_o_rel_sq':sum(g['post_o_sse'] for g in pair)/sum(g['post_o_ref_sq'] for g in pair),
        'recent_fp32_k_sensitivity_post_o_rel_sq':sum(g['recent_fp32_k_sensitivity_post_o_sse'] for g in pair)/sum(g['post_o_ref_sq'] for g in pair),
    }
    out[panel]={'kivi':h,'cache_bytes':{'peak_live':52400,'postflush_final':46592,
        'recent_fp32_k_sensitivity_peak_live':60592},
        'windows':[{'index':r['window'],'final_sha256':r['final_image_sha256'],
                    'flush_log_sha256':r['flush_log_sha256'],
                    'head0_kl':r['heads']['head0']['attention_kl'],
                    'head1_kl':r['heads']['head1']['attention_kl'],
                    'pair_o_rel_sq':r['gqa_pair']['post_o_sse']/r['gqa_pair']['post_o_ref_sq']} for r in receipts]}
(HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({p:v['kivi'] for p,v in out.items()},indent=2))
