"""Aggregate all frozen-image attribution receipts without optimizing any candidate."""
import json
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent
METRICS=('frozen_paid_full_o_rel_sq','diagnostic_batched_full_o_rel_sq','K_only_full_o_rel_sq','V_only_full_o_rel_sq','K_V_interaction_rel_sq','coarse_K_only_full_o_rel_sq','coarse_both_full_o_rel_sq')

def main():
    records={}
    for panel,count in (('train',8),('held',4)):
        for arm in ('original','gauged'):
            rows=[json.loads((HERE/f'{arm}-{panel}-{w}.json').read_text()) for w in range(count)]
            assert all(r['arm']==arm and r['panel']==panel and r['window']==w for w,r in enumerate(rows))
            assert len({r['fixture_sha256'] for r in rows})==1
            assert len({r['program_sha256'] for r in rows})==1
            if arm=='gauged': assert len({r['gamma_image_sha256'] for r in rows})==1
            reference=sum(r['teacher_square'] for r in rows)
            def weighted(name):return sum(r[name]*r['teacher_square'] for r in rows)/reference
            gram=sum((np.array(r['effect_gram_rel_sq'])*r['teacher_square'] for r in rows))/reference
            decomposition={'K_energy':float(gram[0,0]),'V_energy':float(gram[1,1]),
                           'KV_interaction_energy':float(gram[2,2]),
                           'twice_K_dot_V':float(2*gram[0,1]),
                           'twice_K_dot_interaction':float(2*gram[0,2]),
                           'twice_V_dot_interaction':float(2*gram[1,2]),
                           'sum':float(gram.sum())}
            entry={'panel':panel,'arm':arm,'windows':count,'teacher_square':reference,
                   'fixture_sha256':rows[0]['fixture_sha256'],
                   'program_sha256':rows[0]['program_sha256'],
                   'gamma_image_sha256':rows[0]['gamma_image_sha256'],
                   'frozen_image_sha256_by_window':[r['image_sha256'] for r in rows],
                   'normalized_effects':{k:weighted(k) for k in METRICS},
                   'effect_gram_rel_sq':gram.tolist(),'decomposition':decomposition,
                   'mean_head_KL_QJL':sum(r['QJL_mean_head_kl'] for r in rows)/count,
                   'mean_head_KL_coarse':sum(r['coarse_mean_head_kl'] for r in rows)/count,
                   'max_abs_batched_minus_frozen':max(abs(r['batched_minus_frozen_full_o_rel_sq']) for r in rows),
                   'max_abs_algebra_gap':max(r['effect_algebra_max_abs'] for r in rows),
                   'coarse_only_storage_projection_bytes':rows[0]['coarse_only_counterfactual_total_bytes'],
                   'coarse_only_serialized_image_exists':False}
            assert abs(entry['decomposition']['sum']-entry['normalized_effects']['diagnostic_batched_full_o_rel_sq'])<2e-7
            records[(panel,arm)]=entry
        assert records[(panel,'original')]['fixture_sha256']==records[(panel,'gauged')]['fixture_sha256']
        assert records[(panel,'original')]['program_sha256']==records[(panel,'gauged')]['program_sha256']
        assert abs(records[(panel,'original')]['normalized_effects']['V_only_full_o_rel_sq']-records[(panel,'gauged')]['normalized_effects']['V_only_full_o_rel_sq'])<1e-12
    (HERE/'aggregate.json').write_text(json.dumps({f'{p}-{a}':r for (p,a),r in records.items()},indent=2)+'\n')
    for (panel,arm),r in records.items():
        print(panel,arm,json.dumps(r['normalized_effects']), 'KL',r['mean_head_KL_QJL'],r['mean_head_KL_coarse'],'terms',r['decomposition'],'batched_drift',r['max_abs_batched_minus_frozen'])
if __name__=='__main__':main()
