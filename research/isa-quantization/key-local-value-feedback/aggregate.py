"""SHA-pin immutable controls, screen and 12 independently replayed paid windows."""
import json
from pathlib import Path
import hashlib
HERE=Path(__file__).resolve().parent
OWNER=HERE.parent/'contextual-value-feedback'
SCREEN=HERE.parent/'key-local-value-transport'
def sha(data):return hashlib.sha256(data).hexdigest()
def load(p):return json.loads(p.read_text())
def run():
    panels={}
    for panel,n in (('train',8),('validation',4)):
        rows=[];wins={a:0 for a in ('original','feedback','delay2','k2v4')}
        for w in range(n):
            stem=f'{panel}-{w}'
            source_path=OWNER/f'{stem}-source.npz';source_receipt=load(OWNER/f'{stem}-source.json')
            assert sha(source_path.read_bytes())==source_receipt['source_file_sha256']
            control_path=OWNER/f'{stem}-result.json';control=load(control_path)
            paid_path=HERE/f'{stem}-result.json';paid=load(paid_path)
            manifest_path=HERE/f'{stem}-manifest.json';manifest=load(manifest_path)
            assert paid['manifest_sha256']==sha(manifest_path.read_bytes())
            assert paid['source_sha256']==control['source_sha256']==source_receipt['source_file_sha256']==manifest['source_sha256']
            assert paid['query_count']==256 and len(paid['observations'])==256
            assert all(len(control['arms'][a])==256 for a in wins)
            for t,observation in enumerate(paid['observations'],1):
                assert observation['t']==t
                for a in wins:
                    c=control['arms'][a][t-1]
                    assert c['t']==t and c['teacher_sq']==paid['observations'][t-1]['teacher_sq']
                    wins[a]+=paid['observations'][t-1]['sse']<c['sse']
            if panel=='train':
                screen_path=SCREEN/f'{stem}.json';screen=load(screen_path)
                assert screen['source_sha256']==paid['source_sha256']
                assert all([(r['source'],r['target']) for r in manifest['heads'][h]['routes']]==[(r['source'],r['target']) for r in screen['heads'][h]['routes']] for h in range(8))
                screen_sha=sha(screen_path.read_bytes())
            else:screen_sha=None
            rows.append({'window':w,'source_sha256':paid['source_sha256'],'control_result_sha256':sha(control_path.read_bytes()),'control_manifest_sha256':sha((OWNER/f'{stem}-manifest.json').read_bytes()),'screen_sha256':screen_sha,'manifest_sha256':sha(manifest_path.read_bytes()),'result_sha256':sha(paid_path.read_bytes()),'teacher_sq':sum(x['teacher_sq'] for x in paid['observations']),'sse':{'key_local':sum(x['sse'] for x in paid['observations']),**{a:sum(x['sse'] for x in control['arms'][a]) for a in wins}},'at_t128_t256':{'key_local':[paid['observations'][t-1]['sse'] for t in (128,256)],**{a:[control['arms'][a][t-1]['sse'] for t in (128,256)] for a in wins}},'routes':paid['routes'],'skipped':paid['skipped'],'routing_reads':paid['routing_reads'],'visited_source_error_sq':paid['visited_source_error_sq'],'skipped_source_error_sq':paid['skipped_source_error_sq'],'pending_residual_sq':paid['pending_residual_sq']})
        norm=sum(x['teacher_sq'] for x in rows);keys=('key_local',*wins)
        sums={a:sum(x['sse'][a] for x in rows) for a in keys}
        panels[panel]={'windows':n,'queries':256*n,'teacher_sq':norm,'pooled_sse':sums,'relative_sq':{a:sums[a]/norm for a in keys},'query_wins_key_local':wins,'rows':rows,'routes':sum(x['routes'] for x in rows),'skipped':sum(x['skipped'] for x in rows),'routing_reads':{k:sum(x['routing_reads'][k] for x in rows) for k in ('k2_vectors','bf16_vectors')},'visited_source_error_sq':sum(x['visited_source_error_sq'] for x in rows),'skipped_source_error_sq':sum(x['skipped_source_error_sq'] for x in rows),'pending_residual_sq':sum(x['pending_residual_sq'] for x in rows)}
    result={'rule':'fixed causal key-nearest single residual recipient/head; original V2 for skips, frozen donor arithmetic for visits','parent_source_commit':'ae0395afff62042fb402c8931917cd965e2a359c','screen_source_commit':'d16b32399c944aaa827eeadda00611473f9d5610','state_peak_bytes':{'original':304768,'feedback':308864,'delay2':308096,'k2v4':361856,'key_local':308880},'state_final_bytes':{'original':249856,'feedback':253952,'delay2':253184,'k2v4':307200,'key_local':253968},'original_o_sha256':load(OWNER/'original-o.json'),'control_summary_sha256':sha((OWNER/'summary.json').read_bytes()),'screen_summary_sha256':sha((SCREEN/'summary.json').read_bytes()),'panels':panels}
    (HERE/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({p:{'relative_sq':v['relative_sq'],'wins':v['query_wins_key_local'],'routes':v['routes'],'skipped':v['skipped']} for p,v in panels.items()}))
if __name__=='__main__':run()
