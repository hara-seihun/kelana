"""Require matched 8+4 source windows, global SKVQ and full-layer KIVI paid receipts."""
import json
from source import HERE,ROOT,FIX_SHA
BASE=ROOT/'kivi-causal-cache'
meta=json.loads((HERE/'global-descriptors.json').read_text())
out={'calibration':meta,'panels':{}}
for panel,n in [('train',8),('held',4)]:
 rows=[]
 for i in range(n):
  sk=json.loads((HERE/f'{panel}-{i}-result.json').read_text())
  ki=json.loads((HERE/f'{panel}-{i}-kivi-result.json').read_text())
  sm=json.loads((HERE/f'{panel}-{i}-manifest.json').read_text())
  km=json.loads((HERE/f'{panel}-{i}-kivi-manifest.json').read_text())
  donor=json.loads((BASE/f'{panel}-{i}-manifest.json').read_text())
  assert sk['panel']==ki['panel']==panel and sk['window']==ki['window']==i
  assert sk['fixture_sha256']==ki['source_fixture_sha256']==FIX_SHA
  assert sk['descriptor_sha256']==sm['descriptor_sha256']==meta['descriptor_sha256']
  assert sk['final_image_sha256']==sm['final_image_sha256'] and sk['event_log_sha256']==sm['event_log_sha256']
  assert ki['donor_group0_sha256']==donor['final_sha256']
  assert all(ki['other_group_sha256'][h-1]==km['groups'][f'kv{h}']['final_image_sha256'] for h in range(1,8))
  assert sk['peak_plus_descriptors_bytes']==meta['peak_256_bytes']==439934
  assert sk['resident_plus_descriptors_bytes']==meta['resident_256_bytes']==436639
  assert ki['peak_cache_bytes']==419200 and ki['final_cache_bytes']==372736
  assert abs(sk['whole_layer_o_ref_sq']-ki['full_o_ref_sq'])<1e-6
  rows.append({'index':i,'skvq_o_sse':sk['whole_layer_o_sse'],'kivi_o_sse':ki['full_o_sse'],
               'reference_sq':sk['whole_layer_o_ref_sq'],'source_roundtrip_sse':sk['uncompressed_source_roundtrip_o_sse'],
               'skvq_mean_kl':sum(sk['head_kl'])/16,'kivi_mean_kl':sum(ki['head_kl'])/16,
               'skvq_image_sha256':sk['final_image_sha256'],'skvq_events_sha256':sk['event_log_sha256'],
               'kivi_source_group0_sha256':ki['donor_group0_sha256'],
               'kivi_source_other_groups_sha256':ki['other_group_sha256']})
 den=sum(r['reference_sq'] for r in rows)
 out['panels'][panel]={'skvq_full_o_rel_sq':sum(r['skvq_o_sse'] for r in rows)/den,
                       'kivi_full_o_rel_sq':sum(r['kivi_o_sse'] for r in rows)/den,
                       'skvq_source_bf16_roundtrip_full_o_rel_sq':sum(r['source_roundtrip_sse'] for r in rows)/den,
                       'skvq_mean_head_kl':sum(r['skvq_mean_kl'] for r in rows)/n,
                       'kivi_mean_head_kl':sum(r['kivi_mean_kl'] for r in rows)/n,
                       'skvq_cache_peak_bytes_including_descriptors':439934,
                       'skvq_cache_final_bytes_including_descriptors':436639,
                       'kivi_cache_peak_bytes':419200,'kivi_cache_final_bytes':372736,
                       'windows':rows}
(HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({p:{k:v for k,v in r.items() if k!='windows'} for p,r in out['panels'].items()},indent=2))
