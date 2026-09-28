"""Require 8+4 paid TurboQuant images and original complete-layer KIVI controls."""
import json
from source import HERE,ROOT,FIX_SHA
BASE=ROOT/'skvq-global-gqa'
program=json.loads((HERE/'program.json').read_text())
out={'program':program,'panels':{}}
for panel,n in [('train',8),('held',4)]:
 rows=[]
 for i in range(n):
  r=json.loads((HERE/f'{panel}-{i}-result.json').read_text())
  m=json.loads((HERE/f'{panel}-{i}-manifest.json').read_text())
  ki=json.loads((BASE/f'{panel}-{i}-kivi-result.json').read_text())
  assert r['panel']==m['panel']==ki['panel']==panel and r['window']==m['window']==ki['window']==i
  assert r['fixture_sha256']==m['fixture_sha256']==ki['source_fixture_sha256']==FIX_SHA
  assert r['program_sha256']==m['program_sha256']==program['sha256']
  assert r['final_image_sha256']==m['final_sha256']
  assert r['peak_cache_plus_program_bytes']==m['peak_cache_plus_program_bytes']==385040
  assert abs(r['complete_o_ref_sq']-ki['full_o_ref_sq'])<1e-5
  rows.append({'index':i,'turbo_o_sse':r['complete_o_sse'],'kivi_o_sse':ki['full_o_sse'],
               'reference_sq':r['complete_o_ref_sq'],'bf16_k_rounding_o_sse':r['post_rope_bf16_source_rounding_o_sse'],
               'mean_turbo_head_kl':sum(r['head_kl'])/16,'mean_kivi_head_kl':sum(ki['head_kl'])/16,
               'image_sha256':r['final_image_sha256'],'kivi_original_head0_sha256':ki['donor_group0_sha256']})
 den=sum(x['reference_sq'] for x in rows)
 out['panels'][panel]={'turbo_full_o_rel_sq':sum(x['turbo_o_sse'] for x in rows)/den,
                       'kivi_full_o_rel_sq':sum(x['kivi_o_sse'] for x in rows)/den,
                       'bf16_post_rope_k_rounding_full_o_rel_sq':sum(x['bf16_k_rounding_o_sse'] for x in rows)/den,
                       'turbo_mean_head_kl':sum(x['mean_turbo_head_kl'] for x in rows)/n,
                       'kivi_mean_head_kl':sum(x['mean_kivi_head_kl'] for x in rows)/n,
                       'turbo_cache_bytes':188416,'turbo_shared_program_bytes':196624,
                       'turbo_total_bytes':385040,'kivi_cache_peak_bytes':419200,
                       'windows':rows}
(HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({p:{k:v for k,v in r.items() if k!='windows'} for p,r in out['panels'].items()},indent=2))
