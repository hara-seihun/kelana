#!/usr/bin/env python3
"""Aggregate all frozen cases, including mismatches and unhelpful proposals."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-speculative/realistic-runtime')


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def aggregate(cases):
    methods=list(cases[0]['arms'])
    result={}
    for method in methods:
        rows=[c['arms'][method] for c in cases]
        n=sum(len(r['tokens']) for r in rows)
        cycles=[cy for row in rows for cy in row['cycles']]
        result[method]={'cases':len(rows),'tokens':n,'decode_tps':n/sum(r['elapsed_s'] for r in rows),
                        'request_tps':n/sum(r['request_s'] for r in rows),'prefill_s':sum(r['prefill_s'] for r in rows),
                        'decode_s':sum(r['elapsed_s'] for r in rows),'request_s':sum(r['request_s'] for r in rows),
                        'matched_paths':sum(r['matches_serial'] for r in rows),
                        'matched_next':sum(r['next_matches_serial'] for r in rows),'cycles':len(cycles),
                        'tokens_per_cycle':n/len(cycles),
                        'mean_verified_nodes':sum(c['nodes'] for c in cycles)/len(cycles),
                        'phase_seconds':{phase:sum(c[phase+'_s'] for c in cycles) for phase in ('draft','verify','adopt')}}
    for value in result.values():
        value['decode_speedup']=value['decode_tps']/result['serial']['decode_tps']
        value['request_speedup']=value['request_tps']/result['serial']['request_tps']
    return result


def panel(paths):
    receipts=[json.loads(p.read_text()) for p in paths]
    cases=[c for r in receipts for c in r['records']]
    assert len({c['case_id'] for c in cases})==len(cases)
    methods=list(cases[0]['arms'])
    rng=np.random.default_rng(2026092361)
    boot={}
    for method in methods:
        if method=='serial':continue
        ratios=[]
        for _ in range(2000):
            selection=rng.integers(len(cases),size=len(cases))
            ratios.append(sum(cases[i]['arms']['serial']['elapsed_s'] for i in selection)/sum(cases[i]['arms'][method]['elapsed_s'] for i in selection))
        boot[method]=np.quantile(ratios,[.025,.5,.975]).tolist()
    return {'receipt_hashes':{p.name:sha(p) for p in paths},'all':aggregate(cases),
            'model_parameters':receipts[0]['unique_parameters'],
            'by_family':{f:aggregate([c for c in cases if c['family']==f]) for f in sorted({c['family'] for c in cases})},
            'by_context':{str(n):aggregate([c for c in cases if c['context_tokens']==n]) for n in sorted({c['context_tokens'] for c in cases})},
            'paired_case_resampling_decode_ratio_025_50_975':boot,
            'resampling_contract':'Descriptive paired-case bootstrap on this fixed manifest, not a population-confidence guarantee or timing-repeat interval.',
            'cases':[{'id':c['case_id'],'family':c['family'],'context':c['context_tokens'],
                      'methods':{m:{'decode_speedup':c['arms']['serial']['elapsed_s']/c['arms'][m]['elapsed_s'],
                                    'matches':c['arms'][m]['matches_serial'],'next_matches':c['arms'][m]['next_matches_serial'],
                                    'first_difference':c['arms'][m]['first_difference']} for m in methods}} for c in cases]}


def structured_panel(paths):
    cases=[]
    for path in paths:
        receipt=json.loads(path.read_text())
        methods={}
        for name,arm in receipt['results'].items():
            methods[name]={k:arm[k] for k in ('accepted','task_exact','prefill_s','decode_s','request_s')}
            methods[name].update(tokens=len(arm['tokens']),cycles=len(arm['cycles']),
                                 forced_tokens=sum(c['tokens'] for c in arm['cycles'] if not c['branch']))
        cases.append({'receipt':path.name,'sha256':sha(path),'records':receipt['arguments']['records'],
                      'tokens_match':receipt['tokens_match'],'next_match':receipt['next_match'],'methods':methods})
    total={m:sum(c['methods'][m]['decode_s'] for c in cases) for m in ('serial','contract')}
    return {'cases':cases,'decode_speedup':total['serial']/total['contract'],
            'contract':'Two fixed conversion tasks, all ordinary-token byte support; no singleton target-call savings.'}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--controls',action='store_true')
    args=parser.parse_args()
    primary=[DATA/f'q17-{offset:02d}.json' for offset in range(0,24,4)]
    result={'source_sha256':sha(__file__),'primary':panel(primary)}
    assert result['primary']['all']['serial']['cases']==24
    if args.controls:
        result['small_controls']=panel([DATA/f'q06-{offset:02d}.json' for offset in (0,8,16)])
        assert result['small_controls']['all']['serial']['cases']==12
    result['first_stage_original']=panel([primary[0]])
    result['first_stage_reversed']=panel([DATA/'q17-00-repeat.json'])
    result['structured']=structured_panel([DATA/'schema-2.json',DATA/'schema-4.json'])
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v['all'] for k,v in result.items() if isinstance(v,dict) and 'all' in v},indent=2))


if __name__=='__main__':main()
