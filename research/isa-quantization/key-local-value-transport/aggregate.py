"""Summarize the fixed eight-train-window causal routing ledger."""
import hashlib
import json
from collections import Counter
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent


def summarize():
    heads = []
    hashes = []
    for w in range(8):
        path = HERE / f'train-{w}.json'
        data = json.loads(path.read_text())
        assert data['panel'] == 'train' and data['window'] == w and len(data['heads']) == 8
        hashes.append({'window':w, 'source_sha256':data['source_sha256'],
                       'k_sha256':data['k_sha256'], 'manifest_sha256':data['manifest_sha256'],
                       'event_sha256': [h['event_sha256'] for h in data['heads']],
                       'ledger_sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
        heads.extend(data['heads'])
    routes = [r for h in heads for r in h['routes']]
    completed = [r for r in routes if 'distance_at_target_flush' in r]
    original = np.array([r['successor_distance'] for r in routes])
    nearest = np.array([r['chosen_distance'] for r in routes])
    drift = np.array([r['distance_drift'] for r in completed])
    waits = Counter(r['wait'] for r in routes)
    reads = {'packed_vectors':0, 'recent_bf16_vectors':0, 'packed_digits_bytes':0,
             'packed_fields_bytes':0, 'recent_bf16_bytes':0}
    for r in routes:
        t = r['source']+32
        k_flushed = (t//32)*32
        packed = sum(j <= k_flushed for j in range(r['source'], t+1))
        recent = 33-packed
        reads['packed_vectors'] += packed
        reads['recent_bf16_vectors'] += recent
        reads['packed_digits_bytes'] += packed*32
        reads['packed_fields_bytes'] += packed*512
        reads['recent_bf16_bytes'] += recent*256
    reads['total_key_bytes_conservative_fields_per_vector'] = sum(reads[k] for k in ('packed_digits_bytes','packed_fields_bytes','recent_bf16_bytes'))
    reads['source_address_lookups'] = 33*len(routes)
    reads['packed_field_fp16_to_fp32_conversions'] = reads['packed_vectors']*256
    reads['bf16_to_fp32_conversions'] = reads['recent_bf16_vectors']*128
    endpoints = {str(t):[h['endpoint'][str(t)] for h in heads] for t in (128,256)}
    audit = {'packed_vectors':0, 'recent_bf16_vectors':0}
    for r in completed:
        t = r['target']+32
        for j in (r['source'], r['target']):
            audit['packed_vectors' if j <= (t//32)*32 else 'recent_bf16_vectors'] += 1
    for t in (128,256):
        for e in endpoints[str(t)]:
            for j in (e['pending_source'], e['pending_target']):
                audit['packed_vectors' if j <= (t//32)*32 else 'recent_bf16_vectors'] += 1
    audit['read_bytes'] = 544*audit['packed_vectors']+256*audit['recent_bf16_vectors']
    audit['128d_distance_evaluations'] = len(completed)+128
    result = {'rule':'single outstanding residual/head; after current V flush nearest future recent-V token by causal K2-cache squared Euclidean128, earliest token tie',
              'source_identities':hashes,
              'event_count':sum(h['flushes'] for h in heads), 'route_count':len(routes),
              'visited_v_flush_fraction':len(routes)/sum(h['flushes'] for h in heads),
              'skipped_v_flushes':sum(h['skipped'] for h in heads),
              'unique_v_source_tokens_visited':len(routes),
              'eligible_younger_token_appearances':32*len(routes),
              'unique_eligible_younger_tokens_per_head_range':[2,256],
              'wait_counts':dict(sorted(waits.items())), 'mean_wait':float(np.mean([r['wait'] for r in routes])),
              'median_wait':float(np.median([r['wait'] for r in routes])),
              'max_wait':max(r['wait'] for r in routes),
              'paired_distance':{'chosen_sum':float(nearest.sum()), 'successor_sum':float(original.sum()),
                                 'chosen_over_successor':float(nearest.sum()/original.sum()),
                                 'chosen_mean':float(nearest.mean()), 'successor_mean':float(original.mean()),
                                 'non_immediate_count':int(np.sum(nearest < original)),
                                 'ties_at_min_count':sum(r['chosen_distance'] == r['successor_distance'] and r['wait'] != 1 for r in routes)},
              'completed_target_flushes':len(completed), 'pending_unflushed_at_t256':sum(h['unresolved_target'] is not None for h in heads),
              'target_drift':{'key_changed_count':sum(r['key_changed'] for r in completed),
                              'distance_at_target_flush_sum':sum(r['distance_at_target_flush'] for r in completed),
                              'selected_distance_sum':sum(r['chosen_distance'] for r in completed),
                              'drift_mean':float(drift.mean()), 'drift_min':float(drift.min()),
                              'drift_max':float(drift.max()),
                              'nonzero_count':int(np.count_nonzero(drift))},
              'endpoints':{t:{'pending_routes':len(es), 'pending_key_changed':sum(e['key_changed'] for e in es),
                              'targets_flush_now':sum(e['target_flush_now'] for e in es),
                              'current_distance_sum':sum(e['current_distance'] for e in es),
                              'selected_distance_sum':sum(e['selected_distance'] for e in es),
                              'current_minus_selected_sum':sum(e['current_distance']-e['selected_distance'] for e in es),
                              'visited_now':sum('new_target_if_visited' in e for e in es)} for t,es in endpoints.items()},
              'causal_key_reads':reads,
              'additional_audit_only_causal_reads':audit,
              'arithmetic':{'candidate_comparisons':32*len(routes), '128d_subtractions':4096*len(routes),
                            '128d_fp32_squares':4096*len(routes), 'fp64_accumulations_at_most':4096*len(routes)},
              'producer_state':{'existing_fp32_full_layer_residual_bytes':4096,'recipient_u16_bytes':16,
                                'additional_persistent_residual_banks_bytes':0,
                                'streaming_key_decode_fp32_scratch_bytes_per_active_head':1024}}
    (HERE/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('event_count','route_count','visited_v_flush_fraction','paired_distance','target_drift','endpoints','causal_key_reads')}))


if __name__ == '__main__':
    summarize()
