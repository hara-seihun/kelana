"""Aggregate immutable per-query certificates without evaluating another rounding law."""
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    panels={}
    for panel,count in (('train',8),('validation',4),('held',4)):
        windows=[];rows=[]
        for w in range(count):
            path=HERE/f'{panel}-{w}.json';record=json.loads(path.read_text())
            assert record['panel']==panel and record['window']==w
            assert len(record['rows'])==(2 if panel=='held' else 256)
            assert len(record['bound_constants_per_event_head'])==224
            windows.append({'window':w,'certificate_sha256':sha(path),'source_sha256':record['source_sha256'],'event_sha256':record['events_sha256'],'field_sha256':record['fields_sha256']})
            rows+=record['rows']
        fields=('mean_bias_sse','independent_variance','deterministic_fp64_sse','benefit_upper','variance_floor','expected_risk_lower')
        totals={field:sum(row[field] for row in rows) for field in fields}
        totals['benefit_components_A_B_D']=[sum(row['benefit_components_A_B_D'][k] for row in rows) for k in range(3)]
        assert abs(sum(totals['benefit_components_A_B_D'])-totals['benefit_upper'])<1e-10
        assert all(row['variance_floor']>=0 for row in rows)
        assert all(row['expected_risk_lower']<=row['mean_bias_sse']+row['independent_variance']+1e-12 for row in rows)
        panels[panel]={'queries':len(rows),'windows':windows,'totals':totals,'lower_over_deterministic':totals['expected_risk_lower']/totals['deterministic_fp64_sse'],'lower_beats_deterministic_queries':sum(r['expected_risk_lower']<r['deterministic_fp64_sse'] for r in rows),'variance_floor_zero_queries':sum(r['variance_floor']==0 for r in rows),'bounded_queries':[{'window':w,'t':r['t'],'direct_row_envelope':r['direct_row_envelope'],'all_pair_edge_gain_sum_not_a_matching':r['all_pair_edge_gain_sum_not_a_matching'],'fixed_map_reduction':r['certified_fixed_map_reduction'],'upper':r['benefit_upper']} for w in range(count) for r in json.loads((HERE/f'{panel}-{w}.json').read_text())['rows'] if r['t'] in (128,256)]}
    output={'method':'per-event G32 vertexwise triangle relaxation, independent pairs and singletons','source_coefficients_sha256':json.loads((HERE/'train-0.json').read_text())['coefficients_sha256'],'source_matching_sha256':json.loads((HERE/'train-0.json').read_text())['matching_sha256'],'panels':panels}
    (HERE/'summary.json').write_text(json.dumps(output,indent=2)+'\n')
    for name,p in panels.items():print(name,p['queries'],p['totals'],'ratio',p['lower_over_deterministic'],'wins',p['lower_beats_deterministic_queries'],'zeros',p['variance_floor_zero_queries'])

if __name__=='__main__':main()
