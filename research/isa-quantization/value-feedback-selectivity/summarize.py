"""Aggregate only the fixed eight original held positions in each layer."""
import json
from pathlib import Path
from diagnose import HERE,ROOT,sha


def run():
    layers={}
    for layer in (0,1):
        windows=[json.loads((HERE/f'layer{layer}-held-{w}.json').read_text()) for w in range(4)]
        rows=[state for window in windows for state in window['states']]
        provenance={}
        for w,window in enumerate(windows):
            assert window['layer']==layer and window['window']==w
            if layer==0:
                path=ROOT/'kivi-value-error-feedback'/f'held-{w}-result.json'
                owner=json.loads(path.read_text())
                for state,ref in zip(window['states'],owner['arms']['feedback']['retained']):
                    assert state['t']==ref['t'] and abs(state['arms']['feedback']['full_sse']-ref['sse'])<1e-6
                    assert abs(state['arms']['original']['full_sse']-owner['controls'][str(state['t'])]['K2V2_sse'])<1e-6
            else:
                path=ROOT/'contextual-value-feedback'/f'validation-{w}-result.json'
                owner=json.loads(path.read_text())
                assert owner['query_count']==256
                for state in window['states']:
                    t=state['t']
                    for arm in ('original','feedback'):
                        assert abs(state['arms'][arm]['full_sse']-owner['arms'][arm][t-1]['sse'])<1e-6
            provenance[str(w)]={'diagnostic_sha256':sha((HERE/f'layer{layer}-held-{w}.json').read_bytes()),
                                'owner_result_sha256':sha(path.read_bytes()),'source_sha256':window['source_sha256'],
                                'o_sha256':window['o_sha256']}
        measures=('isolated_v_sse','uniform_v_sse','offset_dot_v','full_sse')
        pooled={arm:{k:sum(state['arms'][arm][k] for state in rows) for k in measures} for arm in ('original','feedback')}
        layers[str(layer)]={'provenance':provenance,'teacher_sq':sum(x['teacher_sq'] for x in rows),
           'key_source_offset_sse':sum(x['key_source_offset_sse'] for x in rows),
           'pooled':pooled,'uniform_improves_selective_worsens':[(r['window'],r['t']) for r in rows if r['arms']['feedback']['uniform_v_sse']<r['arms']['original']['uniform_v_sse'] and r['arms']['feedback']['isolated_v_sse']>r['arms']['original']['isolated_v_sse']],
           'uniform_improves_full_worsens':[(r['window'],r['t']) for r in rows if r['arms']['feedback']['uniform_v_sse']<r['arms']['original']['uniform_v_sse'] and r['arms']['feedback']['full_sse']>r['arms']['original']['full_sse']],
           'encoder':{'coordinates':4*8*224*128,'clipped':sum(x['encoder']['clipped_target_coordinates'] for x in windows),
                      'clipped_below':sum(x['encoder']['clipped_below'] for x in windows),
                      'clipped_above':sum(x['encoder']['clipped_above'] for x in windows),
                      'max_abs_residual':max(x['encoder']['residual']['max_abs'] for x in windows),
                      'max_abs_step_defect':max(x['encoder']['target_update_defect']['max_abs'] for x in windows),
                      'source_step_min':min(x['encoder']['source_step']['min'] for x in windows),
                      'source_step_max':max(x['encoder']['source_step']['max'] for x in windows)},
           'max_telescoping_residual_before_o':max(s['arms']['feedback']['max_telescoping_residual_before_O'] for s in rows),
           'max_sse_identity_residual':max(abs(s['arms'][arm]['sse_identity_residual']) for s in rows for arm in ('original','feedback'))}
    result={'scope':'same original held validation windows 0..3, t128/t256; original/feedback V with same actual K2 probabilities; four chronological encoder streams per layer','layers':layers}
    (HERE/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({l:{'pooled':v['pooled'],'encoder':v['encoder'],'uniform_improves_selective_worsens':v['uniform_improves_selective_worsens']} for l,v in layers.items()}))

if __name__=='__main__':run()
