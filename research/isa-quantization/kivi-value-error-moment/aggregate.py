"""Pin immutable comparator receipts and aggregate the complete declared observer."""
import json
from pathlib import Path
from importlib.util import spec_from_file_location,module_from_spec
import hashlib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
CONTEXT=ROOT/'contextual-value-feedback'
HELD=ROOT/'kivi-value-error-feedback'
EXCHANGE=ROOT/'kivi-kv-rate-exchange'
def sha(raw):return hashlib.sha256(raw).hexdigest()
spec=spec_from_file_location('pinned_controls',EXCHANGE/'controls.py')
controls=module_from_spec(spec);spec.loader.exec_module(controls)

def panel(panel,count):
    rows=[];wins={arm:0 for arm in ('original','feedback','delay2','k2v4')}
    sums={key:0.0 for key in ('sse','ordinary_sse','ordinary_error_dot_delta','delta_sq','teacher_sq')}
    baseline={arm:0.0 for arm in wins}
    for w in range(count):
        name=f'{panel}-{w}';path=HERE/f'{name}-result.json';data=json.loads(path.read_text())
        manifest=HERE/f'{name}-manifest.json'
        assert data['manifest_sha256']==sha(manifest.read_bytes()) and data['panel']==panel and data['window']==w
        assert data['query_count']==(2 if panel=='held' else 256)
        reference_path=(HELD/f'{name}-result.json') if panel=='held' else (CONTEXT/f'{name}-result.json')
        ref=json.loads(reference_path.read_text())
        assert [r['t'] for r in data['rows']]==([128,256] if panel=='held' else list(range(1,257)))
        per={key:sum(r[key] for r in data['rows']) for key in sums}
        assert abs(per['sse']-(per['ordinary_sse']+2*per['ordinary_error_dot_delta']+per['delta_sq']))<1e-6
        comparison={key:0.0 for key in wins}
        for row in data['rows']:
            t=row['t'];i=0 if t==128 else 1
            if panel=='held':
                a=ref['controls'][str(t)]
                base={'original':a['K2V2_sse'],'feedback':ref['arms']['feedback']['retained'][i]['sse'],'delay2':ref['arms']['delay2']['retained'][i]['sse'],'k2v4':a['K2V4_sse']}
                assert abs(row['ordinary_sse']-base['original'])<1e-6
                assert abs(row['teacher_sq']-a['teacher_sq'])<1e-5
            else:
                base={arm:ref['arms'][arm][t-1]['sse'] for arm in wins}
                assert row['ordinary_output_sha256']==ref['arms']['original'][t-1]['output_sha256']
                assert abs(row['ordinary_sse']-base['original'])<1e-7
                assert abs(row['teacher_sq']-ref['arms']['original'][t-1]['teacher_sq'])<1e-5
            for arm,sse in base.items():
                comparison[arm]+=sse
                wins[arm]+=row['sse']<sse
        for key in sums:sums[key]+=per[key]
        for key in baseline:baseline[key]+=comparison[key]
        rows.append({'window':w,'result_sha256':sha(path.read_bytes()),'manifest_sha256':sha(manifest.read_bytes()),'baseline_receipt_sha256':sha(reference_path.read_bytes()),'moment_sse':per['sse'],'ordinary_sse':per['ordinary_sse'],'comparators':comparison,'t128_t256':[{key:r[key] for key in ('t','sse','ordinary_sse','ordinary_error_dot_delta','delta_sq','aged_tokens')} for r in data['rows'] if r['t'] in (128,256)]})
    return {'windows':count,'queries':count*(2 if panel=='held' else 256),'sums':sums,'moment_relative_sq':sums['sse']/sums['teacher_sq'],'comparators_sse':baseline,'comparators_relative_sq':{k:v/sums['teacher_sq'] for k,v in baseline.items()},'moment_query_wins':wins,'rows':rows}

def run():
    frozen=controls.read_controls()
    exchange=json.loads(controls.read_results_bytes())
    outcome={p:panel(p,n) for p,n in (('train',8),('validation',4),('held',4))}
    held=outcome['held']
    assert abs(held['comparators_sse']['original']-exchange['pooled']['K2V2']['sse'])<1e-12
    assert abs(held['comparators_sse']['k2v4']-exchange['pooled']['K2V4']['sse'])<1e-12
    for w in range(4):
        assert frozen['records'][str(w)]['kivi2_retained'][0]['control_teacher_sse']==next(x for x in exchange['per_state'] if x['window']==w and x['t']==128)['K2V2_sse']
    summary={'scope':'unchanged independent K2/V2 codes plus chronological FP32 V source-minus-decode moment; 12 contextual full256-query layer1 CPU windows and eight held layer0 states','panels':outcome,'ledger_bytes':{'original_peak':304768,'moment_peak':308864,'moment_final':253952,'moment_state':4096,'delay2_peak':308096,'k2v4_peak':361856},'immutable_receipts_sha256':{'contextual_summary':sha((CONTEXT/'summary.json').read_bytes()),'contextual_v_custody':sha((CONTEXT/'custody.json').read_bytes()),'held_feedback_results':sha((HELD/'results.json').read_bytes()),'exchange_controls':sha((EXCHANGE/'controls.json').read_bytes()),'exchange_results':sha((EXCHANGE/'results.json').read_bytes())}}
    (HERE/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps({p:{'relative_sq':v['moment_relative_sq'],'original_relative_sq':v['comparators_relative_sq']['original'],'wins_original':v['moment_query_wins']['original'],'queries':v['queries'],'dot':v['sums']['ordinary_error_dot_delta'],'delta_sq':v['sums']['delta_sq']} for p,v in outcome.items()}))
if __name__=='__main__':run()
