"""Validate recovered producer custody without rerunning its model capture."""
import hashlib
import json
from pathlib import Path

META=Path('/path/to/workspace/data/kelana-subbit/full-model/mlp-quantized-producer-capture.json')
ORIGINAL_META='b5b944ed8604761d2e55a52bbe708e7de375b755f63c15596a863fe37c66e304'
SOURCE='42eae1e97b1a5a609022f62df15770c6f9ffb10505e46dcbc7987c74ffa5883d'
CAPTURE='aa1e671af9283656efd7a95f2732a27662ce8c658766af5ee88f5e7d27b9e69c'

def check():
    raw=META.read_bytes()
    meta=json.loads(raw)
    snapshot=meta['source_snapshot']
    body=Path(snapshot['path']).read_bytes()
    assert snapshot['sha256']==meta['source_sha256']==SOURCE
    assert hashlib.sha256(body).hexdigest()==SOURCE and len(body)==9628
    assert meta['capture_sha256']==CAPTURE
    original={k:v for k,v in meta.items() if k!='source_snapshot'}
    assert hashlib.sha256((json.dumps(original,indent=2)+'\n').encode()).hexdigest()==ORIGINAL_META
    return {'metadata_path':str(META),'metadata_sha256':hashlib.sha256(raw).hexdigest(),
            'pre_snapshot_metadata_sha256':ORIGINAL_META,'capture_sha256_in_metadata':CAPTURE,
            'source_snapshot_path':snapshot['path'],'source_snapshot_sha256':SOURCE,
            'source_snapshot_bytes':len(body),'recovery_provenance':snapshot['provenance'],
            'scope':'Recovered exact original capture producer and additive metadata identity; no capture/projection rerun or new native layer1 claim'}

if __name__=='__main__':
    result=check()
    Path(__file__).with_name('provenance.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
