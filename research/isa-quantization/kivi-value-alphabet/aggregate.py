"""Immutable receipt aggregation and actual source-diagonal cost, distinct from fitted surrogate."""
import json,sys
import numpy as np
from fit import HERE,ROOT,BASE,CTX,SNAP,sha,checked,donor,original_o,bf16,source
from read import read_log,unpack,decode_value


def train_paid_source(layer):
    diag,_=original_o(layer)
    table=np.frombuffer((HERE/f'layer{layer}-alphabet.f32').read_bytes(),dtype='<f4')
    totals={'candidate_actual':0.,'original_actual':0.,'candidate_zero_step':0.,'original_zero_step':0.}
    for w in range(8):
        v,_=source(layer,w)
        for h in range(8):
            _,original,_=donor(layer,'train',w,h)
            if layer==1:
                m=json.loads((HERE/f'train-{w}-layer1-manifest.json').read_text())
                raw=checked(HERE/f'train-{w}-layer1-h{h}-events.bin',m['heads'][h]['events_sha256'])
                paid=[blob for kind,t,blob in read_log(raw) if kind==b'V']
            else:
                # Training candidate codes are determined by the same frozen table
                # and original fields; compute the actual four-way nearest labels in
                # memory without adding a training inference arm or reader query.
                from produce import encode
                paid=[encode(v[i,h],original[i][1],table) for i in range(224)]
            assert len(paid)==len(original)==224
            x=bf16(v[:224,h]).astype('f8')
            for i in range(224):
                old=original[i][1];new=paid[i]
                stored=np.frombuffer(old[32:],dtype='<f2').astype('f4').reshape(4,2)
                original_decoded=np.add(stored[:,0,None],np.multiply(stored[:,1,None],unpack(old).astype('f4'),dtype='f4'),dtype='f4').reshape(128)
                new_decoded=decode_value([new],[],table)[0]
                weight=diag[h];new_err=weight*np.square(x[i]-new_decoded.astype('f8'))
                old_err=weight*np.square(x[i]-original_decoded.astype('f8'))
                totals['candidate_actual']+=float(new_err.sum());totals['original_actual']+=float(old_err.sum())
                mask=np.repeat(stored[:,1]==0,32)
                totals['candidate_zero_step']+=float(new_err[mask].sum());totals['original_zero_step']+=float(old_err[mask].sum())
    return totals

def aggregate(reuse_source_cost=False):
    control_path=ROOT/'kivi-value-error-feedback/results.json'
    control_bytes=control_path.read_bytes()
    controls0=json.loads(control_bytes)
    retained_bytes=(HERE/'results.json').read_bytes() if reuse_source_cost else None
    retained=json.loads(retained_bytes) if retained_bytes is not None else None
    result={'scope':'one frozen shared four-level FP32 V table per layer, original K2 and full O','layers':{},'feedback_control_sha256':sha(control_bytes)}
    if retained_bytes is not None:result['source_cost_provenance_result_sha256']=sha(retained_bytes)
    for layer in (0,1):
        fit=json.loads((HERE/f'layer{layer}-fit.json').read_text())
        panels={'held':4} if layer==0 else {'train':8,'validation':4}
        if retained is not None:
            old=retained['layers'][str(layer)]
            assert (old['table_sha256'],old['fit_source_count'],old['fit_unique_count'],old['weighted_surrogate_dp'])==(fit['table_sha256'],fit['source_count'],fit['unique_count'],fit['dp_objective'])
            source_cost=old['actual_train_source_diagonal']
        else:source_cost=train_paid_source(layer)
        layer_result={'alphabet_f32':fit['table_f32'],'table_sha256':fit['table_sha256'],'fit_sha256':sha((HERE/f'layer{layer}-fit.json').read_bytes()),'fit_source_count':fit['source_count'],'fit_unique_count':fit['unique_count'],'weighted_surrogate_dp':fit['dp_objective'],'weighted_surrogate_integer_ideal':fit['integer_alphabet_ideal_weighted_objective'],'actual_train_source_diagonal':source_cost,'panels':{},'resident_bytes':{'dynamic_peak':304768,'dynamic_final':249856,'shared_static_table_per_layer':16,'original_dynamic_peak':304768,'original_dynamic_final':249856,'original_static_table':0}}
        for panel,n in panels.items():
            rows=[];candidate=[];baseline=[];feedback=[];moment=[];delay=[];high=[];truth=[]
            for w in range(n):
                path=HERE/f'{panel}-{w}-layer{layer}-result.json';r=json.loads(path.read_text())
                assert r['query_count']==(2 if layer==0 else 256) and r['original_o_sha256']==fit['original_o_sha256'] and r['table_sha256']==fit['table_sha256']
                assert r['verified_k_events']==64 and r['verified_v_events']==1792
                moment_path=ROOT/'kivi-value-error-moment'/f'{panel}-{w}-result.json'
                moment_bytes=moment_path.read_bytes();moment_receipt=json.loads(moment_bytes)
                assert len(moment_receipt['rows'])==len(r['queries'])
                for q,mq in zip(r['queries'],moment_receipt['rows']):
                    assert q['t']==mq['t'] and abs(q['teacher_sq']-mq['teacher_sq'])<1e-5
                    moment.append(mq['sse'])
                if layer==0:
                    for q in r['queries']:
                        control=next(x for x in controls0['per_state'] if x['window']==w and x['t']==q['t'])
                        assert abs(control['teacher_sq']-q['teacher_sq'])<1e-5
                        candidate.append(q['sse']);baseline.append(control['K2V2_sse']);feedback.append(control['feedback_sse']);delay.append(control['delay2_sse']);high.append(control['K2V4_sse']);truth.append(q['teacher_sq'])
                else:
                    owner=json.loads((CTX/f'{panel}-{w}-result.json').read_text())
                    for j,q in enumerate(r['queries']):
                        assert abs(q['teacher_sq']-owner['arms']['original'][j]['teacher_sq'])<1e-8
                        candidate.append(q['sse']);baseline.append(owner['arms']['original'][j]['sse']);feedback.append(owner['arms']['feedback'][j]['sse']);delay.append(owner['arms']['delay2'][j]['sse']);high.append(owner['arms']['k2v4'][j]['sse']);truth.append(q['teacher_sq'])
                rows.append({'window':w,'moment_receipt_sha256':sha(moment_bytes),'reader_result_sha256':sha(path.read_bytes()),'sse':r['sse'],'teacher_sq':r['teacher_sq'],'changed_v_digits_vs_original':r['changed_v_digits_vs_original']})
            pooled={'candidate':sum(candidate),'original_K2V2':sum(baseline),'feedback':sum(feedback),'independent_code_moment':sum(moment),'delay2':sum(delay),'K2V4':sum(high)}
            panel_result={'queries':len(candidate),'teacher_sq':sum(truth),'pooled_sse':pooled,'relative_sq':{k:x/sum(truth) for k,x in pooled.items()},'candidate_query_wins':{'vs_original':sum(a<b for a,b in zip(candidate,baseline)),'vs_feedback':sum(a<b for a,b in zip(candidate,feedback)),'vs_independent_code_moment':sum(a<b for a,b in zip(candidate,moment)),'vs_delay2':sum(a<b for a,b in zip(candidate,delay)),'vs_K2V4':sum(a<b for a,b in zip(candidate,high))},'rows':rows}
            layer_result['panels'][panel]=panel_result
            print(json.dumps({'layer':layer,'panel':panel,'queries':len(candidate),'pooled_sse':pooled,'wins':panel_result['candidate_query_wins']}))
        result['layers'][str(layer)]=layer_result
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':aggregate(reuse_source_cost='--reuse-source-cost' in sys.argv[1:])
