"""Aggregate fixed-law risk without pooling probabilities or treating expectation as an implementation."""
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent

def main():
    panels={}
    for panel,count in [('train',8),('validation',4),('held',4)]:
        cases=[];sums={k:0. for k in ('teacher_sq','deterministic_fp64_sse','mean_bias_sse','variance_trace','expected_sse','original_cpu_sse','fp64_minus_cpu')}
        stats={k:0 for k in ('interior','clipped','exact','duplicate_groups')}
        wins=0;max_contract=0.
        for w in range(count):
            path=HERE/f'{panel}-{w}-result.json';case=json.loads(path.read_text());rows=case['rows']
            assert len(rows)==(2 if panel=='held' else 256)
            for r in rows:
                for k in sums:sums[k]+=r[k]
                wins+=r['expected_sse']<r['deterministic_fp64_sse']
                assert r['variance_trace']>=0 and abs(r['expected_sse']-r['mean_bias_sse']-r['variance_trace'])<1e-8
                if r['covariance_direct'] is not None:max_contract=max(max_contract,abs(r['covariance_direct']-r['variance_trace']))
            for s in case['law_statistics']:
                for k in stats:stats[k]+=s[k]
                assert s['min_variance']>=0 and s['max_probability_violation']==0
            cases.append({'window':w,'source_sha256':case['source_sha256'],'receipt':path.name,'queries':len(rows),'deterministic_fp64_sse':sum(r['deterministic_fp64_sse'] for r in rows),'expected_sse':sum(r['expected_sse'] for r in rows),'variance_trace':sum(r['variance_trace'] for r in rows)})
        panels[panel]={'queries':sum(x['queries'] for x in cases),'sums':sums,'relative_sq':{k:v/sums['teacher_sq'] for k,v in sums.items() if k.endswith('sse')},'winning_queries':wins,'max_direct_covariance_delta':max_contract,'level_counts':stats,'cases':cases}
    result={'law':'LAW.md','panels':panels}
    (HERE/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({p:{'queries':v['queries'],'baseline':v['sums']['deterministic_fp64_sse'],'mean_bias':v['sums']['mean_bias_sse'],'variance':v['sums']['variance_trace'],'expected':v['sums']['expected_sse'],'wins':v['winning_queries'],'max_direct_delta':v['max_direct_covariance_delta']} for p,v in panels.items()},indent=2))
if __name__=='__main__':main()
