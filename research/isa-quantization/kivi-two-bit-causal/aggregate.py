"""Require all 8+4 independent full-layer causal receipts and frozen controls."""
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FIX_SHA='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
turbo=json.loads((ROOT/'turboquant-causal/results.json').read_text())
gauge=json.loads((ROOT/'turboquant-coupled-gauge/results.json').read_text())
prior=json.loads((ROOT/'skvq-global-gqa/results.json').read_text())
result={'method':'KIVI 2-bit K/V G32 R32 full original Qwen3-0.6B layer0','fixture_sha256':FIX_SHA,
        'state':{'key_chunk_bytes':1536,'value_token_bytes':48,'recent_vector_bytes':256,
                 'full_layer_peak_bytes':304768,'full_layer_final_bytes':249856,
                 'static_cache_descriptors_bytes':0,'event_log_not_live_state':True},'panels':{}}
for panel,n in (('train',8),('held',4)):
    rows=[]
    for i in range(n):
        label=f'{panel}-{i}'
        observed=json.loads((HERE/f'{label}-result.json').read_text())
        manifest=json.loads((HERE/f'{label}-manifest.json').read_text())
        original=json.loads((ROOT/'skvq-global-gqa'/f'{label}-kivi-result.json').read_text())
        old=prior['panels'][panel]['windows'][i]
        tq=turbo['panels'][panel]['windows'][i]
        gauged=gauge['panels'][panel]['windows'][i]
        assert (manifest['panel'],manifest['window'],manifest['fixture_sha256'])==(panel,i,FIX_SHA)
        assert (observed['panel'],observed['window'],observed['source_fixture_sha256'])==(panel,i,FIX_SHA)
        assert observed['peak_cache_bytes']==manifest['peak_full_layer_bytes']==304768
        assert observed['final_cache_bytes']==manifest['final_full_layer_bytes']==249856
        assert abs(observed['full_o_ref_sq']-original['full_o_ref_sq'])<1e-6
        assert abs(observed['full_o_ref_sq']-tq['reference_sq'])<1e-6
        assert abs(observed['full_o_ref_sq']-gauged['teacher_sq'])<1e-6
        assert original['donor_group0_sha256']==observed['original_kivi4_final_group0_sha256']
        assert original['donor_group0_sha256']==tq['kivi_original_head0_sha256']
        assert abs(original['full_o_sse']-old['kivi_o_sse'])<1e-8
        for h in range(8):
            name=f'{label}-head{h}'
            entry=manifest['groups'][f'kv{h}']
            for suffix,field in (('final','final_sha256'),('events','events_sha256')):
                data=(HERE/f'{name}-{suffix}.bin').read_bytes()
                assert hashlib.sha256(data).hexdigest()==entry[field]
                assert entry[field]==observed[f'head_{"image" if suffix=="final" else "events"}_sha256'][h]
            assert entry['peak_bytes']==38096 and entry['final_bytes']==31232
            assert len(entry['prefixes'])==256
        rows.append({'index':i,'kivi2_full_o_sse':observed['full_o_sse'],
                     'kivi4_full_o_sse':original['full_o_sse'],
                     'turbo_original_full_o_sse':tq['turbo_o_sse'],
                     'turbo_gauged_full_o_sse':gauged['gauged_o_sse'],
                     'reference_sq':observed['full_o_ref_sq'],
                     'kivi2_mean_head_kl':sum(observed['head_kl'])/16,
                     'kivi4_mean_head_kl':sum(original['head_kl'])/16,
                     'kivi2_head_image_sha256':observed['head_image_sha256'],
                     'kivi2_head_events_sha256':observed['head_events_sha256']})
    denominator=sum(row['reference_sq'] for row in rows)
    summary={k+'_full_o_rel_sq':sum(row[field] for row in rows)/denominator for k,field in (
        ('kivi2','kivi2_full_o_sse'),('kivi4','kivi4_full_o_sse'),
        ('turbo_original','turbo_original_full_o_sse'),('turbo_gauged','turbo_gauged_full_o_sse'))}
    summary.update({'kivi2_mean_head_kl':sum(row['kivi2_mean_head_kl'] for row in rows)/n,
                    'kivi4_mean_head_kl':sum(row['kivi4_mean_head_kl'] for row in rows)/n,
                    'reference_sq_sum':denominator,'windows':rows})
    assert abs(summary['kivi4_full_o_rel_sq']-prior['panels'][panel]['kivi_full_o_rel_sq'])<1e-10
    assert abs(summary['turbo_original_full_o_rel_sq']-turbo['panels'][panel]['turbo_full_o_rel_sq'])<1e-10
    assert abs(summary['turbo_gauged_full_o_rel_sq']-gauge['panels'][panel]['gauged_full_o_rel_sq'])<1e-10
    result['panels'][panel]=summary
(HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({name:{k:v for k,v in data.items() if k!='windows'} for name,data in result['panels'].items()},indent=2))
