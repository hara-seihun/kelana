"""Aggregate frozen 12 full-window contextual source/observer receipts."""
import json
from pathlib import Path
from custody import HERE,sha,source

ARMS=('original','feedback','delay2','k2v4')
def run():
    panels={}
    for panel,n in (('train',8),('validation',4)):
        rows=[]
        for w in range(n):
            arrays,record=source(panel,w)
            receipt_path=HERE/f'{panel}-{w}-result.json'
            result=json.loads(receipt_path.read_text())
            assert result['query_count']==256 and len(result['source_bf16_key_boundary'])==256
            assert result['source_sha256']==record['source_file_sha256']
            assert all(len(result['arms'][arm])==256 and [r['t'] for r in result['arms'][arm]]==list(range(1,257)) for arm in ARMS)
            assert all(abs(result['arms'][arm][t-1]['teacher_sq']-result['source_bf16_key_boundary'][t-1]['teacher_sq'])<1e-5 for arm in ARMS for t in range(1,257))
            rows.append({'window':w,'result_sha256':sha(receipt_path.read_bytes()),'source_sha256':record['source_file_sha256'],'teacher_sq':result['teacher_sq'],'boundary_sse':sum(r['bf16_post_rope_k_sse'] for r in result['source_bf16_key_boundary']),'sse':{a:sum(r['sse'] for r in result['arms'][a]) for a in ARMS},'at_t128_t256':{a:[result['arms'][a][t-1]['sse'] for t in (128,256)] for a in ARMS}})
        teacher=sum(row['teacher_sq'] for row in rows)
        pooled={a:sum(row['sse'][a] for row in rows) for a in ARMS}
        wins={'feedback_vs_original':0,'feedback_vs_delay2':0,'feedback_vs_k2v4':0}
        for w in range(n):
            states=json.loads((HERE/f'{panel}-{w}-result.json').read_text())['arms']
            for t in range(256):
                wins['feedback_vs_original']+=states['feedback'][t]['sse']<states['original'][t]['sse']
                wins['feedback_vs_delay2']+=states['feedback'][t]['sse']<states['delay2'][t]['sse']
                wins['feedback_vs_k2v4']+=states['feedback'][t]['sse']<states['k2v4'][t]['sse']
        panels[panel]={'windows':n,'queries':n*256,'teacher_sq':teacher,'source_only_bf16_k_sse':sum(row['boundary_sse'] for row in rows),'pooled_sse':pooled,'relative_sq':{a:pooled[a]/teacher for a in ARMS},'feedback_query_wins':wins,'rows':rows}
    result={'scope':'Original layer0 teacher residual drives newly declared CPU layer1 source: teacher-forced contextual transfer, not feedback rollout or native GPU capture','panels':panels,'state_peak_bytes':{'original':304768,'feedback':308864,'delay2':308096,'k2v4':361856},'source_v_custody_sha256':sha((HERE/'custody.json').read_bytes())}
    (HERE/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({p:{'relative_sq':x['relative_sq'],'boundary_sse':x['source_only_bf16_k_sse'],'feedback_vs_original_percent':100*(x['pooled_sse']['feedback']/x['pooled_sse']['original']-1)} for p,x in panels.items()}))
if __name__=='__main__':run()
