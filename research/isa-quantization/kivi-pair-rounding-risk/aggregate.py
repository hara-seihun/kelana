"""Aggregate the sixteen immutable paired-risk receipts; keep every query-level comparison."""
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
pins=json.loads((HERE/'pins.json').read_text())
independent=ROOT/'kivi-value-rounding-risk'
assert hashlib.sha256((independent/'summary.json').read_bytes()).hexdigest()==pins['summary_sha256']
source=json.loads((independent/'summary.json').read_text())
result={'law':'LAW.md','pins':'pins.json','panels':{}}
for panel,count in [('train',8),('validation',4),('held',4)]:
    cases=[]
    allrows=[]
    for w in range(count):
        receipt=json.loads((HERE/f'{panel}-{w}-result.json').read_text())
        original=json.loads((independent/f'{panel}-{w}-result.json').read_text())
        assert hashlib.sha256((independent/f'{panel}-{w}-result.json').read_bytes()).hexdigest()==pins['receipts_sha256'][f'{panel}-{w}']
        assert receipt['source_sha256']==original['source_sha256']
        assert receipt['independent_receipt_sha256']==pins['receipts_sha256'][f'{panel}-{w}']
        assert receipt['direct_four_outcome_cases']==24
        for row,base in zip(receipt['rows'],original['rows'],strict=True):
            assert row['t']==base['t'] and row['independent_expected_sse']==base['expected_sse']
            assert row['paired_expected_sse']<=row['independent_expected_sse']+1e-11*max(1,row['independent_expected_sse'])
        allrows+=receipt['rows']
        cases.append({'window':w,'source_sha256':receipt['source_sha256'],
                      'receipt':f'{panel}-{w}-result.json',
                      'independent_expected_sse':sum(r['independent_expected_sse'] for r in receipt['rows']),
                      'paired_expected_sse':sum(r['paired_expected_sse'] for r in receipt['rows']),
                      'original_fp64_sse':sum(r['original_fp64_sse'] for r in receipt['rows']),
                      'direct_four_outcome_cases':receipt['direct_four_outcome_cases'],
                      'max_direct_analytic_difference':receipt['max_direct_analytic_difference']})
    sums={key:sum(r[key] for r in allrows) for key in ('teacher_sq','original_fp64_sse','original_cpu_sse','independent_expected_sse','pair_covariance_correction','paired_expected_sse')}
    prior=source['panels'][panel]['sums']
    assert abs(sums['independent_expected_sse']-prior['expected_sse'])<1e-10
    assert abs(sums['original_fp64_sse']-prior['deterministic_fp64_sse'])<1e-10
    result['panels'][panel]={'queries':len(allrows),'sums':sums,
                             'paired_over_original_fp64':sums['paired_expected_sse']/sums['original_fp64_sse'],
                             'paired_over_independent':sums['paired_expected_sse']/sums['independent_expected_sse'],
                             'paired_winning_queries_vs_original':sum(r['paired_expected_sse']<r['original_fp64_sse'] for r in allrows),
                             'strictly_improved_vs_independent':sum(r['paired_expected_sse']<r['independent_expected_sse'] for r in allrows),
                             'max_correction':max(r['pair_covariance_correction'] for r in allrows),
                             'max_direct_analytic_difference':max(c['max_direct_analytic_difference'] for c in cases),
                             'direct_four_outcome_cases':sum(c['direct_four_outcome_cases'] for c in cases),
                             'cases':cases}
(HERE/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v['sums'] for k,v in result['panels'].items()}))
