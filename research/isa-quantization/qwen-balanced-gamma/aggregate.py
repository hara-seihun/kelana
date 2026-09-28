"""Aggregate paid-source gamma equivalence and train-only balanced geometry."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'qwen-kernel-gauge-screen/aggregate.py'
SOURCE_SHA='613f199f1a401f70cb879eb9fa3bbbab45ce0318481273953ca7631c5c1b3fca'
OLD=HERE.parent/'qwen-kernel-gauge-screen/results.json'
OLD_SHA='a1504c3f347010679f116ca814da491e7a18898b7657757051487428e52b5ddd'
IMAGE_SHA='c8173158c88975e808804bb89a9e59b4cfa485a60f8d854fc4963ad89c830865'

def main():
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==SOURCE_SHA
    assert hashlib.sha256(OLD.read_bytes()).hexdigest()==OLD_SHA
    spec=importlib.util.spec_from_file_location('pinned_geometry_aggregation',SOURCE)
    module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
    center=json.loads((HERE/'center.json').read_text())
    assert hashlib.sha256((HERE/'train-balanced-center-f64.npy').read_bytes()).hexdigest()==center['center_sha256']
    result={'center':center,'panels':{}}
    old=json.loads(OLD.read_text())
    for panel,count in (('train',8),('inspected_held',4)):
        stem='held' if panel=='inspected_held' else 'train'
        scores=[json.loads((HERE/f'{stem}-{i}-observer.json').read_text()) for i in range(count)]
        geometry=[json.loads((HERE/f'{stem}-{i}.json').read_text()) for i in range(count)]
        assert all(s['window']==g['window']==i and s['panel']==g['panel']==stem and
            s['gamma_image_sha256']==g['gamma_image_sha256']==IMAGE_SHA for i,(s,g) in enumerate(zip(scores,geometry)))
        result['panels'][panel]={'original_key_squared_norm':module.pool([g['key_squared_norm'] for g in geometry]),
            'shifted_key_squared_norm':module.pool([g['centered_key_squared_norm'] for g in geometry]),'heads':{}}
        for head in ('head0','head1'):
            result['panels'][panel]['heads'][head]={
                'uncentered_exponent':module.pool([g['heads'][head]['uncentered_exponent'] for g in geometry]),
                'shifted_exponent':module.pool([g['heads'][head]['train_centered_exponent'] for g in geometry])}
        result['panels'][panel]['mean_exponent_reduction_both_heads']=sum(
            result['panels'][panel]['heads'][h]['uncentered_exponent']['equal_pair_mean']-
            result['panels'][panel]['heads'][h]['shifted_exponent']['equal_pair_mean']
            for h in ('head0','head1'))/2
        if panel=='train':
            assert abs(result['panels'][panel]['mean_exponent_reduction_both_heads']-center['center_squared_norm'])<1e-7
        heads={}
        for head in ('head0','head1'):
            rows=[s['head'][head] for s in scores]
            heads[head]={
                'max_causal_score_abs_difference':max(r['causal_score_max_abs_difference'] for r in rows),
                'all_causal_scores_bitwise_identical':all(r['causal_score_bitwise_equal'] for r in rows),
                'max_attention_probability_abs_difference':max(r['attention_probability_max_abs_difference'] for r in rows),
                'max_post_o_abs_difference':max(r['post_o_max_abs_difference'] for r in rows),
                'post_o_rel_sq':sum(r['post_o_sse'] for r in rows)/sum(r['post_o_ref_sq'] for r in rows),
                'all_rotated_queries_bitwise_power_two':all(r['query_rotated_bitwise_equal_to_scaled_original'] for r in rows)}
        pair=[s['gqa_pair'] for s in scores]
        result['panels'][panel]['gamma_source_equivalence']={'heads':heads,
            'all_rotated_keys_bitwise_reciprocal_power_two':all(s['key_rotated_bitwise_equal_to_scaled_original'] for s in scores),
            'gqa_pair_post_o_rel_sq':sum(s['post_o_sse'] for s in pair)/sum(s['post_o_ref_sq'] for s in pair),
            'max_gqa_pair_post_o_abs_difference':max(s['post_o_max_abs_difference'] for s in pair)}
        result['panels'][panel]['original_unbalanced_centered_mean_exponent']=sum(
            old['panels'][panel]['heads'][h]['shifted_exponent']['equal_pair_mean'] for h in ('head0','head1'))/2
    result['gamma_image_sha256']=IMAGE_SHA
    result['baseline_geometry_results_sha256']=OLD_SHA
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({p:{'mean_balanced_exponent':sum(r['heads'][h]['shifted_exponent']['equal_pair_mean'] for h in ('head0','head1'))/2,
        'mean_old_centered_exponent':r['original_unbalanced_centered_mean_exponent'],
        'source_equivalence':r['gamma_source_equivalence']} for p,r in result['panels'].items()},indent=2))

if __name__=='__main__':main()
