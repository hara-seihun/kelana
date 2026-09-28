"""Physical study inventory and provenance; excludes this self-referential receipt."""
import json
from fit import HERE,sha

def run():
    files=[]
    for p in sorted(HERE.iterdir()):
        if not p.is_file() or p.name in ('ledger.json',):continue
        b=p.read_bytes();files.append({'path':p.name,'bytes':len(b),'sha256':sha(b)})
    named=lambda suffix:[x for x in files if x['path'].endswith(suffix)]
    receipt={'owner':'kivi-value-alphabet','files':files,'total_artifact_bytes_excluding_ledger':sum(x['bytes'] for x in files),'table':named('-alphabet.f32'),'events':named('-events.bin'),'final_images':named('-final.bin'),'retained_preflush_images':[x for x in files if '-t128-' in x['path'] or '-t256-' in x['path']],'window_manifests':named('-manifest.json'),'reader_results':named('-result.json')}
    (HERE/'ledger.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({k:len(receipt[k]) for k in ('files','table','events','final_images','retained_preflush_images','window_manifests','reader_results')}))
if __name__=='__main__':run()
