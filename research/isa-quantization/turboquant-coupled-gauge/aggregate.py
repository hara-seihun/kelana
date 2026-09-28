"""Require all12 frozen gamma/K paid images and source/legacy readers unchanged."""
import json
from source import HERE,ROOT,FIX_SHA
G=json.loads((ROOT/'qwen-coupled-gamma/prepare.json').read_text())
P=json.loads((ROOT/'turboquant-causal/program.json').read_text())
out={'gamma_image_sha256':G['gamma_image_sha256'],'program_sha256':P['sha256'],
     'one_gamma_replacement_bytes':512,'incremental_gamma_bytes':0,
     'paid_cache_bytes':188416,'shared_program_bytes':196624,
     'cache_plus_program_bytes':385040,'panels':{}}
for panel,n in [('train',8),('held',4)]:
 rows=[]
 for i in range(n):
  rec=json.loads((HERE/f'{panel}-{i}-result.json').read_text())
  m=json.loads((HERE/f'{panel}-{i}-manifest.json').read_text())
  original=json.loads((ROOT/f'turboquant-causal/{panel}-{i}-result.json').read_text())
  kivi=json.loads((ROOT/f'skvq-global-gqa/{panel}-{i}-kivi-result.json').read_text())
  src=json.loads((ROOT/f'qwen-coupled-gamma/{panel}-{i}-observe.json').read_text())
  assert rec['panel']==m['panel']==original['panel']==kivi['panel']==panel
  assert rec['window']==m['window']==original['window']==kivi['window']==i
  assert rec['fixture_sha256']==m['fixture_sha256']==original['fixture_sha256']==kivi['source_fixture_sha256']==FIX_SHA
  assert rec['gamma_image_sha256']==m['source_gamma_replacement_sha256']==src['gamma_image_sha256']==G['gamma_image_sha256']
  assert all(src['bitwise'].values()) and src['complete_o_sse']==0
  assert rec['program_sha256']==m['program_sha256']==original['program_sha256']==P['sha256']
  assert rec['candidate_image_sha256']==m['final_sha256']
  assert rec['donor_image_sha256']==m['donor_image_sha256']==original['final_image_sha256']
  assert rec['all_donor_V_bytes_identical'] and m['all_donor_V_bytes_reused']
  assert rec['peak_cache_plus_program_bytes']==m['peak_cache_plus_program_bytes']==original['peak_cache_plus_program_bytes']==385040
  assert abs(rec['complete_o_ref_sq']-original['complete_o_ref_sq'])<1e-6
  assert abs(rec['complete_o_ref_sq']-kivi['full_o_ref_sq'])<1e-6
  assert rec['zero_output_rel_sq']==1
  rows.append({'index':i,'gauged_o_sse':rec['complete_o_sse'],'original_o_sse':original['complete_o_sse'],
               'kivi_o_sse':kivi['full_o_sse'],'teacher_sq':rec['complete_o_ref_sq'],
               'gauged_mean_kl':rec['mean_head_kl'],'original_mean_kl':sum(original['head_kl'])/16,
               'kivi_mean_kl':sum(kivi['head_kl'])/16,
               'gauged_image_sha256':rec['candidate_image_sha256'],
               'original_image_sha256':rec['donor_image_sha256']})
 den=sum(r['teacher_sq'] for r in rows)
 out['panels'][panel]={'gauged_full_o_rel_sq':sum(r['gauged_o_sse'] for r in rows)/den,
                       'original_full_o_rel_sq':sum(r['original_o_sse'] for r in rows)/den,
                       'kivi_full_o_rel_sq':sum(r['kivi_o_sse'] for r in rows)/den,
                       'zero_output_full_o_rel_sq':1.,
                       'gauged_vs_original_error_ratio':sum(r['gauged_o_sse'] for r in rows)/sum(r['original_o_sse'] for r in rows),
                       'gauged_mean_head_kl':sum(r['gauged_mean_kl'] for r in rows)/n,
                       'original_mean_head_kl':sum(r['original_mean_kl'] for r in rows)/n,
                       'kivi_mean_head_kl':sum(r['kivi_mean_kl'] for r in rows)/n,
                       'windows':rows}
(HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({p:{k:v for k,v in r.items() if k!='windows'} for p,r in out['panels'].items()},indent=2))
