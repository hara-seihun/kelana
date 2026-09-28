"""Require all12 independently decoded gamma source observers, no held choice."""
import json,sys
from reader import HERE,decode
sys.path.insert(0,str(HERE.parent/'skvq-global-gqa'))
from source import FIX_SHA
policy=json.loads((HERE/'prepare.json').read_text())
geometry=json.loads((HERE/'geometry.json').read_text())
replacement,original,e=decode()
assert e[:64].tolist()==policy['integer_e']
out={'gamma_image_sha256':policy['gamma_image_sha256'],'replacement_bytes':512,
     'incremental_static_bytes':0,'train_policy':policy,'geometry':geometry,'panels':{}}
for panel,n in [('train',8),('held',4)]:
 rows=[json.loads((HERE/f'{panel}-{i}-observe.json').read_text()) for i in range(n)]
 for i,r in enumerate(rows):
  assert r['panel']==panel and r['window']==i and r['fixture_sha256']==FIX_SHA
  assert r['gamma_image_sha256']==policy['gamma_image_sha256']
  assert all(r['bitwise'].values())
  assert r['q_pairwise_max_abs']==r['k_pairwise_max_abs']==0
  assert r['score_max_abs']==r['prob_max_abs']==r['complete_o_max_abs']==r['complete_o_sse']==0
 den=sum(r['complete_o_ref_sq'] for r in rows)
 out['panels'][panel]={'windows':rows,'complete_o_rel_sq':sum(r['complete_o_sse'] for r in rows)/den,
                       'all_source_bits_identical':True,
                       'norm_product_baseline_F':geometry['panels'][panel]['baseline_F'],
                       'train_chosen_norm_product_F':geometry['panels'][panel]['train_integer_e_F']}
(HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({p:{k:v for k,v in d.items() if k!='windows'} for p,d in out['panels'].items()},indent=2))
