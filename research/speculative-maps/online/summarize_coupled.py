#!/usr/bin/env python3
"""Summarize the coupled fifth round from immutable runtime receipts."""
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT=Path('/path/to/workspace/data/kelana-speculative/online')
PANELS=('bf16-math','fp32-eight','fp32-policy','fp32-retrieval','fp32-retrieval-reverse','fp32-rollout')


def aggregate(records):
    methods=list(records[0]['results'][0]['arms'])
    result={}
    for method in methods:
        cases=[(r,r['arms'][method]) for record in records for r in record['results']]
        values=[v for _,v in cases]
        cycles=[c for v in values for c in v['cycles']]
        count=sum(len(v['tokens']) for v in values)
        result[method]={'tokens_per_second':count/sum(v['elapsed_s'] for v in values),
                        'emitted_tokens':count,'cycles':len(cycles),
                        'paths_matching_serial':sum(v['matches_serial'] for v in values),'paths':len(values),
                        'next_decisions_matching_serial':sum(v['next_token']==r['arms']['serial']['next_token'] for r,v in cases),
                        'draft_ms_per_cycle':1000*sum(c['draft_s'] for c in cycles)/len(cycles),
                        'policy_actions':dict(Counter(str(c.get('policy_action')) for c in cycles))}
    for row in result.values():row['speedup_vs_serial']=row['tokens_per_second']/result['serial']['tokens_per_second']
    return result


def main():
    records={tag:json.loads((ROOT/(tag+'.json')).read_text()) for tag in PANELS}
    result={'source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'panels':{tag:aggregate([r]) for tag,r in records.items()},
            'retrieval_combined':aggregate([records['fp32-retrieval'],records['fp32-retrieval-reverse']]),
            'forced_runs':{},
            'receipt_sha256':{tag:hashlib.sha256((ROOT/(tag+'.json')).read_bytes()).hexdigest() for tag in PANELS}}
    for mode,tag in [('canonical','forced-runs'),('byte','forced-runs-byte')]:
        source=ROOT/(tag+'.json')
        r=json.loads(source.read_text())
        result['receipt_sha256'][tag]=hashlib.sha256(source.read_bytes()).hexdigest()
        summaries={}
        for length in (1,4,8):
            selected=[row for row in r['rows'] if row['literal_repetitions']==length]
            arms={}
            for method in ('serial','contract'):
                vs=[row['arms'][method] for row in selected]
                arms[method]={'tokens_per_second':sum(len(v['tokens']) for v in vs)/sum(v['elapsed_s'] for v in vs),
                              'tokens_per_output':len(vs[0]['tokens']),'cycles_per_output':len(vs[0]['cycles']),
                              'branch_decisions_per_output':sum(c['branch_decision'] for c in vs[0]['cycles'])}
            summaries[str(length)]={'arms':arms,'speedup':arms['contract']['tokens_per_second']/arms['serial']['tokens_per_second'],
                                    'same_tokens':all(row['arms']['serial']['tokens']==row['arms']['contract']['tokens'] for row in selected),
                                    'same_next_token':all(row['same_next_token'] for row in selected)}
        result['forced_runs'][mode]=summaries
    Path(__file__).with_name('coupled-results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
