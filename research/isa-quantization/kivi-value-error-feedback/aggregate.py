"""Aggregate only the four held pairs and verify copied successful control receipts."""
import hashlib
import json
from pathlib import Path
from importlib.util import spec_from_file_location, module_from_spec

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
CONTROLS=ROOT/'kivi-kv-rate-exchange'
spec=spec_from_file_location('pinned_controls',CONTROLS/'controls.py')
module=module_from_spec(spec);spec.loader.exec_module(module)


def sha(b):return hashlib.sha256(b).hexdigest()

def run():
    pinned=module.read_controls()
    exchange=json.loads(module.read_results_bytes())
    rows=[]
    for w in range(4):
        b=(HERE/f'held-{w}-result.json').read_bytes();r=json.loads(b)
        assert r['window']==w
        control=pinned['records'][str(w)]
        for i,t in enumerate((128,256)):
            x=next(s for s in exchange['per_state'] if s['window']==w and s['t']==t)
            assert r['controls'][str(t)]['K2V2_sse']==x['K2V2_sse']
            assert r['controls'][str(t)]['K2V4_sse']==x['K2V4_sse']
            assert r['controls'][str(t)]['K4V4_sse']==x['K4V4_sse']
            assert r['controls'][str(t)]['K2V2_sse']==control['kivi2_retained'][i]['control_teacher_sse']
            row={'window':w,'t':t,'teacher_sq':x['teacher_sq']}
            for arm in ('feedback','delay2'):
                s=r['arms'][arm]['retained'][i]
                row[arm+'_sse']=s['sse']
                row[arm+'_output_sha256']=s['output_sha256']
            for arm in ('K2V2','K2V4','K4V4'):row[arm+'_sse']=x[arm+'_sse']
            rows.append(row)
    den=sum(x['teacher_sq'] for x in rows)
    assert abs(den-exchange['teacher_sq'])<1e-8
    arms=('feedback','delay2','K2V2','K2V4','K4V4')
    pooled={arm:{'sse':sum(x[arm+'_sse'] for x in rows),'relative_sq':sum(x[arm+'_sse'] for x in rows)/den} for arm in arms}
    assert abs(pooled['K2V2']['sse']-exchange['pooled']['K2V2']['sse'])<1e-12
    assert abs(pooled['K2V4']['sse']-exchange['pooled']['K2V4']['sse'])<1e-12
    ledger={arm:{'peak_bytes':peak,'final_bytes':final} for arm,peak,final in (('feedback',308864,253952),('delay2',308096,253184),('K2V2',304768,249856))}
    result={'scope':'frozen chronological V2 error feedback versus two-token original-retention control; eight held original-Q/teacher/O states','denominator_teacher_sq':den,'per_state':rows,'pooled':pooled,'ledger':ledger,'source_receipts':{'control_sha256':sha((CONTROLS/'controls.json').read_bytes()),'exchange_results_sha256':sha((CONTROLS/'results.json').read_bytes()),'per_window_results_sha256':[sha((HERE/f'held-{w}-result.json').read_bytes()) for w in range(4)]}}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(pooled,indent=2))

if __name__=='__main__':run()
