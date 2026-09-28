"""Combine frozen paid controls and all original-window balanced-feature receipts."""
from pathlib import Path
import hashlib
import json
import sys

HERE=Path(__file__).resolve().parent
OLD=HERE.parent/'qwen-positive-kernel/results.json'
CENTERED=HERE.parent/'qwen-centered-positive-kernel/results.json'
KIVI=HERE.parent/'kivi-causal-cache/results.json'
HASHES={'primary':'e99a8f2238ae7540d279a5118697d4e4686eb1d2e3004ad5481b4d2a37adb71d',
        'prior_centered':'17571c2ec9bd9c2821050719d892d9badd328e89b51b1f8876ae6511b16d20d5',
        'kivi':'77a97c453f40593ab8f1f2f3a0d5c8d06cb424ea28b758fbe7b4ec874e8acebf'}
GAMMA_SHA='c8173158c88975e808804bb89a9e59b4cfa485a60f8d854fc4963ad89c830865'
CENTER_SHA='3e9fa69a8942b762f0cd041e6a70bfa0c7833957f0d960a6032b0775058cd6a2'
TABLE_SHA='c79b3d345a0bfc6a1b2e4a6e8f04246e5b7750e885ae17f3eb36ad66d53d86f5'

def pinned(path,sha):
    data=path.read_bytes()
    assert hashlib.sha256(data).hexdigest()==sha,path
    return json.loads(data)

def main(centered=CENTERED,kivi=KIVI):
    primary=pinned(OLD,HASHES['primary'])
    prior=pinned(centered,HASHES['prior_centered'])
    conventional=pinned(kivi,HASHES['kivi'])
    output={'paid_image_sha256':{'gamma_replacement':GAMMA_SHA,'model_specific_center':CENTER_SHA,'shared_table':TABLE_SHA},
            'pinned_control_receipts_sha256':HASHES,'panels':{}}
    for panel,n in (('train',8),('inspected_held',4)):
        prefix='held' if panel=='inspected_held' else 'train'
        records=[json.loads((HERE/f'{prefix}-{i}.json').read_text()) for i in range(n)]
        assert all(r['panel']==prefix and r['window']==i and r['balanced_gamma_image_sha256']==GAMMA_SHA and
            r['balanced_center_image_sha256']==CENTER_SHA and r['table_sha256']==TABLE_SHA and
            r['fixture_sha256']=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f' for i,r in enumerate(records))
        heads={}
        for head in ('head0','head1'):
            row=[r['heads'][head] for r in records]
            heads[head]={'attention_kl':sum(a['attention_kl'] for a in row)/n,
                'post_o_rel_sq':sum(a['output_sse'] for a in row)/sum(a['output_ref_sq'] for a in row),
                'max_abs_prefix_vs_dense':max(a['value_prefix_vs_dense_max_abs'] for a in row)}
        pair=[r['gqa_pair'] for r in records]
        output['panels'][panel]={'balanced_centered':{'heads':heads,
            'gqa_pair_post_o_rel_sq':sum(a['output_sse'] for a in pair)/sum(a['output_ref_sq'] for a in pair)},
            'frozen_uncentered':primary[panel]['positive_feature_rank64'],
            'frozen_old_centered':prior['panels'][panel]['centered'],
            'frozen_affine_kv_q4':primary[panel]['affine_kv_q4'],
            'frozen_affine_kv_q6':primary[panel]['affine_kv_q6'],
            'frozen_kivi_g32_r32_q4':conventional[prefix]['kivi'],
            'kivi_cache_bytes':conventional[prefix]['cache_bytes']}
    (HERE/'results.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({p:r['balanced_centered'] for p,r in output['panels'].items()},indent=2))

if __name__=='__main__':
    main(Path(sys.argv[1]) if len(sys.argv)>1 else CENTERED,
         Path(sys.argv[2]) if len(sys.argv)>2 else KIVI)
