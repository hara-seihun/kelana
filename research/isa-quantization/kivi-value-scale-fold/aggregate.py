"""Require one frozen paid V/O source and twelve independent causal byte receipts."""
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
DONOR=HERE.parent/'kivi-two-bit-causal'

def main():
 fields=json.loads((HERE/'source-fields.json').read_text())
 out={}
 for panel,n in (('train',8),('held',4)):
  rows=[json.loads((HERE/f'{panel}-{i}-result.json').read_text()) for i in range(n)]
  sources=[json.loads((HERE/f'{panel}-{i}-source.json').read_text()) for i in range(n)]
  original=[json.loads((DONOR/f'{panel}-{i}-result.json').read_text()) for i in range(n)]
  for i,(r,s,o) in enumerate(zip(rows,sources,original)):
   assert r['panel']==s['panel']==o['panel']==panel and r['window']==s['window']==o['window']==i
   assert r['replacement_v_o_sha256']==fields['replacement_image_sha256']
   assert len(r['image_sha256'])==len(r['events_sha256'])==8
   assert r['peak_cache_bytes']==o['peak_cache_bytes']==304768
   assert r['final_cache_bytes']==o['final_cache_bytes']==249856
   assert r['full_o_ref_sq']==o['full_o_ref_sq']==s['source_teacher_square']
   assert r['donor_full_o_sse']==o['full_o_sse'] and r['donor_head_kl']==o['head_kl']
   assert s['full_uncompressed_o_bitwise_equal'] and s['exact_bf16_v_coordinate_equivalence']
  den=sum(r['full_o_ref_sq'] for r in rows)
  data={'windows':n,'replacement_v_o_sha256':fields['replacement_image_sha256'],
        'folded_full_o_sse':sum(r['full_o_sse'] for r in rows),
        'original_full_o_sse':sum(r['donor_full_o_sse'] for r in rows),
        'common_teacher_square':den,
        'folded_full_o_rel_sq':sum(r['full_o_sse'] for r in rows)/den,
        'original_full_o_rel_sq':sum(r['donor_full_o_sse'] for r in rows)/den,
        'folded_mean_head_kl':sum(sum(r['head_kl'])/16 for r in rows)/n,
        'original_mean_head_kl':sum(sum(r['donor_head_kl'])/16 for r in rows)/n,
        'peak_cache_bytes':304768,'final_cache_bytes':249856,
        'source_replacement_bytes':6291456,'incremental_source_bytes':0}
  out[panel]=data
 (HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
 print(json.dumps(out,indent=2))
if __name__=='__main__':main()
