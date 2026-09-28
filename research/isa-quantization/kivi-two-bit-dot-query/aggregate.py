"""Require all twelve immutable KIVI2 image/consumer observations."""
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'kivi-two-bit-causal'
source=json.loads((BASE/'results.json').read_text())
out={'program':'one fixed dynamic int8 query × existing unsigned2 K-code consumer, V unchanged',
     'paid_cache_peak_bytes':304768,'extra_persistent_model_or_cache_bytes':0,'panels':{}}
for panel,n in [('train',8),('held',4)]:
    windows=[]
    for i in range(n):
        r=json.loads((HERE/f'{panel}-{i}-result.json').read_text())
        owner=json.loads((BASE/f'{panel}-{i}-result.json').read_text())
        assert r['panel']==owner['panel']==panel and r['window']==owner['window']==i
        assert r['original_paid_head_image_sha256']==owner['head_image_sha256']
        assert r['original_paid_head_events_sha256']==owner['head_events_sha256']
        assert r['all_prefix_receipts_checked']==2048 and r['same_original_value_decode_and_o']
        assert abs(r['conventional_full_o_sse']-owner['full_o_sse'])<1e-6
        assert abs(r['teacher_full_o_sq']-owner['full_o_ref_sq'])<1e-6
        windows.append({'index':i,'byte_full_o_sse':r['changed_full_o_sse'],
                        'kivi2_full_o_sse':r['conventional_full_o_sse'],
                        'teacher_sq':r['teacher_full_o_sq'],
                        'byte_mean_head_kl':sum(r['changed_head_kl'])/16,
                        'kivi2_mean_head_kl':sum(r['conventional_head_kl'])/16,
                        'max_abs_logit_difference':r['max_abs_logit_difference'],
                        'max_abs_o_difference':r['max_abs_o_difference'],
                        'max_abs_integer_group_dot':r['max_abs_integer_group_dot'],
                        'prepared_query_groups':r['prepared_query_groups'],
                        'head_image_sha256':r['original_paid_head_image_sha256']})
    den=sum(row['teacher_sq'] for row in windows)
    obs={'byte_full_o_rel_sq':sum(row['byte_full_o_sse'] for row in windows)/den,
         'kivi2_full_o_rel_sq':sum(row['kivi2_full_o_sse'] for row in windows)/den,
         'byte_mean_head_kl':sum(row['byte_mean_head_kl'] for row in windows)/n,
         'kivi2_mean_head_kl':sum(row['kivi2_mean_head_kl'] for row in windows)/n,
         'max_abs_logit_difference':max(row['max_abs_logit_difference'] for row in windows),
         'max_abs_o_difference':max(row['max_abs_o_difference'] for row in windows),
         'max_abs_integer_group_dot':max(row['max_abs_integer_group_dot'] for row in windows),
         'prepared_query_groups':sum(row['prepared_query_groups'] for row in windows),
         'windows':windows}
    assert abs(obs['kivi2_full_o_rel_sq']-source['panels'][panel]['kivi2_full_o_rel_sq'])<1e-9
    out['panels'][panel]=obs
(HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({key:{k:v for k,v in data.items() if k!='windows'} for key,data in out['panels'].items()},indent=2))
