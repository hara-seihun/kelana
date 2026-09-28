"""Aggregate the one paid centered program against frozen primary receipts."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys

HERE=Path(__file__).resolve().parent
PRIMARY=HERE.parent/'qwen-positive-kernel/results.json'
PRIMARY_SHA='e99a8f2238ae7540d279a5118697d4e4686eb1d2e3004ad5481b4d2a37adb71d'
CENTER_SHA='7f991ba8b77dc6199ad8ffb3ca5c9d13c14a2997efed7ac7277de9c21f3f99ca'
TABLE_SHA='c79b3d345a0bfc6a1b2e4a6e8f04246e5b7750e885ae17f3eb36ad66d53d86f5'

def main():
    assert hashlib.sha256(PRIMARY.read_bytes()).hexdigest()==PRIMARY_SHA
    baseline=json.loads(PRIMARY.read_text())
    result={'center_image_sha256':CENTER_SHA,'frozen_original_results_sha256':PRIMARY_SHA,'panels':{}}
    for panel,count in (('train',8),('inspected_held',4)):
        p='held' if panel=='inspected_held' else 'train'
        records=[json.loads((HERE/f'{p}-{i}.json').read_text()) for i in range(count)]
        assert all(r['panel']==p and r['window']==i and
            r['shared_key_center_image_sha256']==CENTER_SHA and r['table_sha256']==TABLE_SHA and
            r['source_reader_sha256']=='a9e5ee5de5666759964bc93a619a1c78038eff072f18c81c0f55636c3b953c86'
            for i,r in enumerate(records))
        heads={}
        for head in ('head0','head1'):
            rows=[r['heads'][head] for r in records]
            heads[head]={'attention_kl':sum(r['attention_kl'] for r in rows)/count,
                         'post_o_rel_sq':sum(r['output_sse'] for r in rows)/sum(r['output_ref_sq'] for r in rows),
                         'max_abs_prefix_vs_dense':max(r['value_prefix_vs_dense_max_abs'] for r in rows)}
        pair=[r['gqa_pair'] for r in records]
        result['panels'][panel]={'centered':{'heads':heads,
            'gqa_pair_post_o_rel_sq':sum(r['output_sse'] for r in pair)/sum(r['output_ref_sq'] for r in pair)},
            'frozen_uncentered':baseline[panel]['positive_feature_rank64'],
            'frozen_kv_q4':baseline[panel]['affine_kv_q4'],
            'frozen_kv_q6':baseline[panel]['affine_kv_q6']}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({p:record['centered'] for p,record in result['panels'].items()},indent=2))

if __name__=='__main__':main()
