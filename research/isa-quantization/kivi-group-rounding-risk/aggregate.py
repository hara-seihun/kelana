"""Aggregate exact-law fixed source panels without pooling train and inspection panels."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
OWNER = HERE.parent / 'kivi-value-rounding-risk'


def main():
    panels = {}
    for panel, count in (('train', 8), ('validation', 4), ('held', 4)):
        totals = {key: 0. for key in ('teacher_sq','deterministic_fp64_sse','mean_bias_sse','variance_trace','expected_sse','original_cpu_sse')}
        independent = json.loads((OWNER / 'summary.json').read_text())['panels'][panel]
        cases = []
        winning = 0
        checks = {'max_diagonal_abs':0.,'max_symmetry_abs':0.,'max_marginal_abs':0.,'max_support_projection_delta':0.,'support_records':0,'groups':0}
        for w in range(count):
            path = HERE / f'{panel}-{w}-result.json'
            receipt = json.loads(path.read_text())
            old_path = OWNER / f'{panel}-{w}-result.json'
            old = json.loads(old_path.read_text())
            assert receipt['source_sha256'] == old['source_sha256']
            assert len(receipt['rows']) == len(old['rows']) == (2 if panel == 'held' else 256)
            for row, previous in zip(receipt['rows'], old['rows']):
                for key in ('t','aged_tokens','teacher_sq','mean_bias_sse','deterministic_fp64_sse','original_cpu_sse'):
                    assert row[key] == previous[key]
                assert abs(row['expected_sse'] - row['mean_bias_sse'] - row['variance_trace']) < 1e-10
                for key in totals: totals[key] += row[key]
                winning += row['expected_sse'] < row['deterministic_fp64_sse']
            for item in receipt['checks']:
                if 'records' in item:
                    checks['groups'] += item['records']
                    checks['max_diagonal_abs'] = max(checks['max_diagonal_abs'], item['diagonal_max_abs'])
                    checks['max_symmetry_abs'] = max(checks['max_symmetry_abs'], item['symmetry_max_abs'])
                else:
                    checks['support_records'] += 1
                    checks['max_marginal_abs'] = max(checks['max_marginal_abs'], item['marginal_max_abs'])
                    checks['max_support_projection_delta'] = max(checks['max_support_projection_delta'], item['projection_contraction_abs'])
            cases.append({'window':w,'receipt':path.name,'source_sha256':receipt['source_sha256'],'queries':len(receipt['rows']),'variance_trace':sum(x['variance_trace'] for x in receipt['rows']),'expected_sse':sum(x['expected_sse'] for x in receipt['rows'])})
        old_sums = independent['sums']
        for key in ('teacher_sq','deterministic_fp64_sse','mean_bias_sse','original_cpu_sse'):
            assert abs(totals[key]-old_sums[key]) < 1e-8
        panels[panel] = {'queries':sum(x['queries'] for x in cases),'totals':totals,'relative_expected_sq':totals['expected_sse']/totals['teacher_sq'],'expected_vs_original':totals['expected_sse']/totals['deterministic_fp64_sse'],'independent_variance_trace':old_sums['variance_trace'],'independent_expected_sse':old_sums['expected_sse'],'winning_queries':winning,'checks':checks,'cases':cases}
    result = {'law':'LAW.md','source_owner_commit':'0bed18b2','cost':{'uniforms_per_original_v_record':4,'uniforms_per_32_coordinate_group':1,'original_v_records_per_window':1792,'uniforms_per_window':7168,'uniforms_all_16_windows':114688,'additional_persistent_fields_or_states':0,'decoded_fp32_levels_per_group':4,'probability_and_width_evaluations_per_original_v_record':128,'cumulative_updates_per_original_v_record':128,'digit_decisions_per_original_v_record':128,'source_or_teacher_forward_calls':0,'gpu_calls':0,'sampled_risk_draws':0,'runtime_measured':False},'panels':panels}
    (HERE/'summary.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({name:{'queries':p['queries'],'variance':p['totals']['variance_trace'],'expected':p['totals']['expected_sse'],'expected_vs_original':p['expected_vs_original'],'independent_expected':p['independent_expected_sse'],'wins':p['winning_queries'],'checks':p['checks']} for name,p in panels.items()},indent=2))

if __name__ == '__main__':main()
