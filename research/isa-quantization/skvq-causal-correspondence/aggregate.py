"""Require all twelve frozen source/paid SKVQ windows before panel summaries."""
import json
from source import HERE,BASE
out={'method':'Official-SKVQ-inspired Qwen source transfer; pinned minmax KMeans/clipping/window/sink/pack mathematics, no upstream native runtime claim',
     'descriptors':json.loads((HERE/'source-descriptors.json').read_text()),'panels':{}}
for panel,n in [('train',8),('held',4)]:
 rows=[]
 for i in range(n):
  row=json.loads((HERE/f'{panel}-{i}-result.json').read_text())
  manifest=json.loads((HERE/f'{panel}-{i}-manifest.json').read_text())
  baseline=json.loads((BASE/f'{panel}-{i}-result.json').read_text())
  assert row['panel']==panel and row['window']==i
  assert row['final_image_sha256']==manifest['final_image_sha256']
  assert row['event_log_sha256']==manifest['event_log_sha256']
  assert row['descriptor_sha256']==out['descriptors']['descriptor_sha256']
  assert row['max_pre_aging_cache_plus_descriptors']==54786
  assert row['final_cache_plus_descriptors']==54373
  assert row['uncompressed_original_teacher_score_max_abs']<1e-4
  assert row['uncompressed_original_teacher_o_max_abs']<1e-4
  assert abs(row['gqa_pair']['post_o_ref_sq']-baseline['gqa_pair']['post_o_ref_sq'])<1e-7
  rows.append({'index':i,'pair_o_sse':row['gqa_pair']['post_o_sse'],
               'pair_ref_sq':row['gqa_pair']['post_o_ref_sq'],
               'original_kivi_sse':baseline['gqa_pair']['post_o_sse'],
               'recent_bf16_source_roundtrip_pair_o_sse':row['pre_rope_recent_bf16_roundtrip_pair_o_sse'],
               'recent_bf16_source_k_max_abs':row['pre_rope_recent_bf16_roundtrip_k_max_abs'],
               'head0_kl':row['heads']['head0']['attention_kl'],
               'head1_kl':row['heads']['head1']['attention_kl'],
               'final_image_sha256':row['final_image_sha256'],
               'event_log_sha256':row['event_log_sha256']})
 den=sum(r['pair_ref_sq'] for r in rows)
 out['panels'][panel]={'skvq_pair_o_rel_sq':sum(r['pair_o_sse'] for r in rows)/den,
                       'kivi_original_pair_o_rel_sq':sum(r['original_kivi_sse'] for r in rows)/den,
                       'pre_rope_bf16_uncompressed_roundtrip_pair_o_rel_sq':sum(r['recent_bf16_source_roundtrip_pair_o_sse'] for r in rows)/den,
                       'max_pre_rope_bf16_key_abs':max(r['recent_bf16_source_k_max_abs'] for r in rows),
                       'head0_attention_kl':sum(r['head0_kl'] for r in rows)/n,
                       'head1_attention_kl':sum(r['head1_kl'] for r in rows)/n,
                       'peak_plus_descriptors_bytes':54786,'resident_plus_descriptors_bytes':54373,
                       'windows':rows}
(HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({p:{k:v for k,v in r.items() if k!='windows'} for p,r in out['panels'].items()},indent=2))
