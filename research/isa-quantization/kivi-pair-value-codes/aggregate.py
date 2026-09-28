"""Static metric witness and pooled receipts; reuse unchanged K2/V4/moment evidence."""
import json
import numpy as np
from common import HERE,CONTEXT,SNAP,PAIR,sha,checked,pairs,metrics,o_matrix

def run():
    for layer in range(2):
        o=o_matrix(layer).astype('<f8');edges=pairs(layer);actual=metrics(layer)
        for h in range(8):
            for p,(i,j) in enumerate(edges[h]):
                a=o[:,2*h*128+i];b=o[:,(2*h+1)*128+i]
                c=o[:,2*h*128+j];d=o[:,(2*h+1)*128+j]
                expected=np.asarray((np.sum(a*a,dtype='<f8')+np.sum(b*b,dtype='<f8'),np.sum(a*c,dtype='<f8')+np.sum(b*d,dtype='<f8'),np.sum(c*c,dtype='<f8')+np.sum(d*d,dtype='<f8')),dtype='<f4')
                assert np.array_equal(expected,actual[h,p]),(layer,h,p)
    controls=HERE.parent/'kivi-value-error-moment'
    exchange_path=HERE.parent/'kivi-kv-rate-exchange/results.json'
    exchange_bytes=checked(exchange_path,'cb4154bab21c49f80dc10ea60ac0aa248f8535f8e5287a2b64540dc2b0aab6cc')
    exchange=json.loads(exchange_bytes)
    summary={'metric_sha256':sha((HERE/'metric.bin').read_bytes()),'pair_sha256':sha((PAIR/'pair-map.bin').read_bytes()),'o_sha256':[sha(((SNAP if i==0 else CONTEXT)/'original-o.bf16').read_bytes()) for i in range(2)],'program_sha256':{p:sha((HERE/p).read_bytes()) for p in ('common.py','build.py','audit.py','aggregate.py')},'panels':{}}
    for panel,count in (('train',8),('validation',4),('held',4)):
        totals={arm:0. for arm in ('original','candidate','delay4','k2v4','moment')};total_teacher=0.;represented=np.zeros(2,dtype='<f8');wins={'candidate':0,'delay4':0};changed=0;windows=[]
        for w in range(count):
            name=f'{panel}-{w}';path=HERE/f'{name}-result.json';r=json.loads(path.read_text());m=checked(HERE/f'{name}-manifest.json',r['manifest_sha256']);manifest=json.loads(m)
            assert r['query_count']==(2 if panel=='held' else 256) and r['audited_prefixes']==2048
            other=controls/f'{name}-result.json';moment=json.loads(other.read_text())
            contextual=json.loads((CONTEXT/f'{name}-result.json').read_text()) if panel!='held' else None
            for index,row in enumerate(r['rows']):
                total_teacher+=row['teacher_sq']
                for arm in ('original','candidate','delay4'):totals[arm]+=row[arm]['sse']
                for arm in wins:wins[arm]+=row[arm]['sse']<row['original']['sse']
                totals['moment']+=moment['rows'][index]['sse']
                if contextual:totals['k2v4']+=contextual['arms']['k2v4'][index]['sse']
                else:
                    prior=next(p for p in exchange['per_state'] if (p['window'],p['t'])==(w,row['t']))
                    assert abs(prior['teacher_sq']-row['teacher_sq'])<1e-6
                    assert abs(prior['K2V2_sse']-row['original']['sse'])<1e-6
                    totals['k2v4']+=prior['K2V4_sse']
            represented+=r['represented_metric_energy'];changed+=r['changed_code_bytes']
            windows.append({'window':w,'result_sha256':sha(path.read_bytes()),'manifest_sha256':r['manifest_sha256'],'source_sha256':r['source_sha256'],'moment_receipt_sha256':sha(other.read_bytes()),'unchanged_control_sha256':sha((CONTEXT/f'{name}-result.json').read_bytes()) if contextual else None,'queries':len(r['rows']),'sse':{arm:sum(row[arm]['sse'] for row in r['rows']) for arm in ('original','candidate','delay4')}})
        if panel=='held':summary['held_rate_control_sha256']=sha(exchange_bytes)
        summary['panels'][panel]={'query_count':sum(x['queries'] for x in windows),'teacher_sq':total_teacher,'sse':totals,'relative_sq':{arm:(value/total_teacher if value is not None else None) for arm,value in totals.items()},'wins_over_original':wins,'represented_metric_energy':represented.tolist(),'changed_code_bytes':changed,'windows':windows}
    (HERE/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    for panel,r in summary['panels'].items():print(panel,r['query_count'],r['relative_sq'],r['represented_metric_energy'])
if __name__=='__main__':run()
