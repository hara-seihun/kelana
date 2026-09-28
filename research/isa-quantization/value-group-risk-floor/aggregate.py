"""Aggregate pinned one-window fixed-law risk-floor receipts without rescoring."""
import gzip
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    certificates=[]
    for layer in range(2):
        for h in range(8):
            path=HERE/f'cert-{layer}-{h}.json.gz'
            doc=json.load(gzip.open(path))
            assert doc['layer']==layer and doc['head']==h and len(doc['groups'])==4
            certificates.append({'layer':layer,'head':h,'sha256':sha(path),'bytes':path.stat().st_size,
                                 'groups':[{'group':g['group'],'eigmin_fp64':g['eigmin_fp64'],
                                            'lambda_numerator':g['lambda_numerator'],
                                            'source_zero_words':g['source_zero_words']} for g in doc['groups']]})
    panels={}
    for panel,count in [('train',8),('validation',4),('held',4)]:
        total={'queries':0,'deterministic_fp64_sse':0.,'mean_bias_sse':0.,'independent_variance':0.,
               'variance_floor':0.,'expected_risk_lower':0.,'floor_above_deterministic_queries':0}
        receipts=[]
        for w in range(count):
            path=HERE/f'{panel}-{w}.json'; data=json.loads(path.read_text())
            assert (data['panel'],data['window'])==(panel,w)
            layer=0 if panel=='held' else 1
            assert data['certificate_sha256']==[certificates[layer*8+h]['sha256'] for h in range(8)]
            assert len(data['rows'])==(2 if panel=='held' else 256)
            assert len(data['event_head_q0_q1_coefficients'])==224
            receipts.append({'window':w,'sha256':sha(path),'source_result_sha256':data['source_result_sha256'],
                             'source_sha256':data['source_sha256'],'donor_manifest_sha256':data['donor_manifest_sha256'],
                             'events_sha256':data['events_sha256'],'fields_sha256':data['fields_sha256']})
            for r in data['rows']:
                total['queries']+=1
                for key in ('deterministic_fp64_sse','mean_bias_sse','independent_variance','variance_floor','expected_risk_lower'):
                    total[key]+=r[key]
                total['floor_above_deterministic_queries']+=r['expected_risk_lower']>r['deterministic_fp64_sse']
        total['floor_minus_deterministic']=total['expected_risk_lower']-total['deterministic_fp64_sse']
        total['floor_over_deterministic']=total['expected_risk_lower']/total['deterministic_fp64_sse']
        panels[panel]={'totals':total,'receipts':receipts}
    summary={'certificates':certificates,'panels':panels,
             'minimum_lambda_numerator':min(g['lambda_numerator'] for c in certificates for g in c['groups']),
             'maximum_lambda_numerator':max(g['lambda_numerator'] for c in certificates for g in c['groups']),
             'source_zero_words':sum(g['source_zero_words'] for c in certificates for g in c['groups'])}
    (HERE/'summary.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
    print(json.dumps({k:v['totals'] for k,v in panels.items()},indent=2))

if __name__=='__main__':main()
