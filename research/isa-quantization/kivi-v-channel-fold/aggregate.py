"""Aggregate frozen original and physically folded KIVI over all 8+4 windows."""
import hashlib
import json
from source import HERE,BASE
from check import k_events

out={'source_image':json.loads((HERE/'source-image.json').read_text()),'admission':json.loads((HERE/'gate.json').read_text()),'panels':{}}
assert out['admission']['admitted']
for panel,n in [('train',8),('held',4)]:
    records=[]
    for i in range(n):
        new=json.loads((HERE/f'{panel}-{i}-result.json').read_text())
        old=json.loads((BASE/f'{panel}-{i}-result.json').read_text())
        manifest=json.loads((HERE/f'{panel}-{i}-manifest.json').read_text())
        assert new['final_image_sha256']==manifest['final_sha256']
        assert new['flush_log_sha256']==manifest['flush_log_sha256']
        assert new['preflush_peak_bytes']==old['preflush_peak_bytes']==52400
        assert new['postflush_final_bytes']==old['postflush_final_bytes']==46592
        assert k_events(HERE/f'{panel}-{i}-flush.bin')==k_events(BASE/f'{panel}-{i}-flush.bin')
        assert new['uncompressed_online_vs_teacher_max_output_abs']<1e-4
        assert abs(new['gqa_pair']['post_o_ref_sq']-old['gqa_pair']['post_o_ref_sq'])<1e-7
        records.append({'index':i,'new_pair_sse':new['gqa_pair']['post_o_sse'],
                        'original_pair_sse':old['gqa_pair']['post_o_sse'],
                        'pair_ref_sq':new['gqa_pair']['post_o_ref_sq'],
                        'new_head0_kl':new['heads']['head0']['attention_kl'],
                        'original_head0_kl':old['heads']['head0']['attention_kl'],
                        'new_head1_kl':new['heads']['head1']['attention_kl'],
                        'original_head1_kl':old['heads']['head1']['attention_kl'],
                        'uncompressed_online_vs_teacher_max_output_abs':new['uncompressed_online_vs_teacher_max_output_abs'],
                        'image_sha256':new['final_image_sha256'],'flush_sha256':new['flush_log_sha256'],
                        'k_flush_events_equal_original':True})
    ref=sum(r['pair_ref_sq'] for r in records)
    new=sum(r['new_pair_sse'] for r in records)/ref
    old=sum(r['original_pair_sse'] for r in records)/ref
    out['panels'][panel]={'folded_pair_o_rel_sq':new,'original_pair_o_rel_sq':old,
                          'relative_change':new/old-1,'peak_cache_bytes':52400,'final_cache_bytes':46592,
                          'max_uncompressed_o_abs':max(r['uncompressed_online_vs_teacher_max_output_abs'] for r in records),
                          'head0_kl_folded':sum(r['new_head0_kl'] for r in records)/n,
                          'head0_kl_original':sum(r['original_head0_kl'] for r in records)/n,
                          'head1_kl_folded':sum(r['new_head1_kl'] for r in records)/n,
                          'head1_kl_original':sum(r['original_head1_kl'] for r in records)/n,
                          'windows':records}
(HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({p:{k:v for k,v in r.items() if k!='windows'} for p,r in out['panels'].items()},indent=2))
