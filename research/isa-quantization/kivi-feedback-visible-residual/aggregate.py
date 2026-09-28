"""Aggregate unchanged SHA-pinned controls and the sole changed reader without re-encoding."""
import json
from pathlib import Path
from replay import HERE,CTX,HELD,sha,checked

PINS={'contextual_summary':'39901aa0efc1392252bb0f12cfb2f51869c1ffbc03f3a5e099dfb17a5088dfdf',
      'held_results':'24042c36a944e202613be83fffaeb658811cd5ae10b940bc6b2fa8639f04829c'}
def run():
    contextual_summary=json.loads(checked(CTX/'summary.json',PINS['contextual_summary']))
    held_summary=json.loads(checked(HELD/'results.json',PINS['held_results']))
    panels={};source_files=[];donors=[]
    for panel,n in (('train',8),('validation',4),('held',4)):
        rows=[];old=[]
        for w in range(n):
            receipt=json.loads((HERE/f'{panel}-{w}.json').read_text())
            origin=(HELD if panel=='held' else CTX)
            old_blob=checked(origin/f'{panel}-{w}-result.json',receipt['unchanged_result_sha256'])
            original=json.loads(old_blob)
            manifest=checked(origin/f'{panel}-{w}-manifest.json',receipt['donor_manifest_sha256'])
            donors.append({'panel':panel,'window':w,'manifest_sha256':sha(manifest),'original_result_sha256':sha(old_blob)})
            if panel!='held':
                source_files.append({'panel':panel,'window':w,'sha256':receipt['source_sha256']})
                assert original['source_sha256']==receipt['source_sha256']
            for r in receipt['rows']:
                if 'retained_residual' in r:
                    saved=r['retained_residual'];blob=checked(HERE/saved['file'],saved['sha256'])
                    assert len(blob)==4096 and [sha(blob[512*h:512*(h+1)]) for h in range(8)]==r['pre_residual_sha256']
                prior=(next(x for x in original['arms']['feedback']['retained'] if x['t']==r['t']) if panel=='held' else original['arms']['feedback'][r['t']-1])
                assert r['ordinary_output_sha256']==prior['output_sha256'] and abs(r['ordinary_sse']-prior['sse'])<1e-9
                rows.append(r)
            old.append(original)
        score={key:sum(r[key] for r in rows) for key in ('sse','ordinary_sse','cross','correction_sq')}
        score['queries']=len(rows);score['improved_queries']=sum(r['sse']<r['ordinary_sse'] for r in rows)
        score['relative_to_feedback']=score['sse']/score['ordinary_sse']-1
        if panel=='held':
            score['teacher_sq']=sum(x['teacher_sq'] for o in old for x in o['arms']['feedback']['retained'])
            score['controls']={arm:sum(o['controls'][str(t)][f'{arm}_sse'] for o in old for t in (128,256)) for arm in ('K2V2','K2V4')}
            score['states']=[{'window':w,'t':r['t'],'sse':r['sse'],'ordinary_sse':r['ordinary_sse']} for w in range(n) for r in json.loads((HERE/f'held-{w}.json').read_text())['rows']]
        else:
            score['teacher_sq']=sum(o['teacher_sq'] for o in old)
            score['controls']={arm:sum(sum(r['sse'] for r in o['arms'][arm]) for o in old) for arm in ('original','delay2','k2v4')}
        assert abs(score['sse']-(score['ordinary_sse']+score['cross']+score['correction_sq']))<1e-7
        score['relative_squared_error']=score['sse']/score['teacher_sq']
        panels[panel]=score
    result={'program':'frozen FP32 pre-query pending residual visible at source probability; unchanged cache and O',
            'unchanged_summary_sha256':PINS,'source_files':source_files,'donors':donors,'panels':panels}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(panels,indent=2))
if __name__=='__main__':run()
