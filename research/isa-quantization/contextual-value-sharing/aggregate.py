"""Aggregate immutable per-window receipts; does not project source tensors."""
import hashlib
import json
from pathlib import Path
from provenance import check as check_source_provenance

here=Path(__file__).resolve().parent
result={'scope':'layer1 CPU projection from original layer0 teacher post-residual; exact full-eight-head record sharing only',
        'panels':{}, 'receipt_sha256':{}, 'source_provenance':check_source_provenance()}
for panel,windows in [('train',8),('validation',4)]:
    records=[json.loads((here/f'{panel}-{i}.json').read_text()) for i in range(windows)]
    assert all(r['panel']==panel and r['window']==i and r['layer']==1 and r['positions']==256 for i,r in enumerate(records))
    for i,r in enumerate(records):
        p=here/f'{panel}-{i}.json'
        result['receipt_sha256'][p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
        for field in ['source_sha256','capture_meta_sha256','capture_producer_sha256_in_metadata']:
            assert r[field]==records[0][field]
        for key in ['captured_residual_bf16','normalized_input_bf16','full8_v_bf16','full8_g32_kivi2_v']:
            assert r[key]['total']==r[key]['unique']==256
        assert r['phases']['after']['first_exceeds_148']==181
        assert r['phases']['before']['first_exceeds_148']==182
    result['panels'][panel]={'windows':windows,'positions':256*windows,
        'repeated_token_occurrences':sum(r['token_ids']['repeated_occurrences'] for r in records),
        'same_token_id_pairs':sum(r['same_token_id_pairs'] for r in records),
        'same_id_and_raw_pairs':sum(r['same_id_and_raw_pairs'] for r in records),
        'same_id_and_v_pairs':sum(r['same_id_and_v_pairs'] for r in records),
        'same_id_and_packed_pairs':sum(r['same_id_and_packed_pairs'] for r in records),
        'duplicate_records':{key:sum(r[key]['repeated_occurrences'] for r in records)
            for key in ['captured_residual_bf16','normalized_input_bf16','full8_v_bf16','full8_g32_kivi2_v']},
        'after_query148slot_first_failure':181,'before_query148slot_first_failure':182}
result['v_final_plain_payload_bytes']=224*384+32*2048
result['v_final_dictionary_with_256_refs_and_5header_bytes']=224*384+32*2048+256+5
(here/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result['panels'],indent=2))
