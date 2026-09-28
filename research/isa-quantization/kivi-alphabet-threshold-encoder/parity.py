"""Run the one frozen shared CPU/HIP threshold expression on 16 saved source windows."""
import hashlib,json,subprocess,sys,tempfile
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
CAND=ROOT/'kivi-value-alphabet'
sys.path.insert(0,str(CAND))
from produce import input_source
SHA=lambda b:hashlib.sha256(b).hexdigest()
WINDOWS=[(0,'held',n) for n in range(4)]+[(1,'train',n) for n in range(8)]+[(1,'validation',n) for n in range(4)]

def run(layer,panel,n):
    tag=f'{panel}-{n}-layer{layer}'
    manifest=json.loads((CAND/f'{tag}-manifest.json').read_text())
    table=CAND/f'layer{layer}-alphabet.f32'
    assert SHA(table.read_bytes())==manifest['table_sha256']
    _,v,owner=input_source(layer,panel,n)
    assert v.shape==(256,8,128) and v.dtype==np.dtype('<u2')
    vbytes=np.ascontiguousarray(v,dtype='<u2').tobytes()
    base=ROOT/('kivi-two-bit-causal' if layer==0 else 'contextual-value-feedback')
    donor_prefix=base/(f'{panel}-{n}-head' if layer==0 else f'{panel}-{n}-original-h')
    candidate_prefix=CAND/f'{tag}-h'
    donor_hash=[];candidate_hash=[]
    for h in range(8):
        donor=(base/f'{donor_prefix.name}{h}-events.bin').read_bytes()
        candidate=(CAND/f'{tag}-h{h}-events.bin').read_bytes()
        assert SHA(donor)==manifest['heads'][h]['original_events_sha256']
        assert SHA(candidate)==manifest['heads'][h]['events_sha256']
        donor_hash.append(SHA(donor));candidate_hash.append(SHA(candidate))
    with tempfile.TemporaryDirectory() as temp:
        source=Path(temp)/'v.u16';source.write_bytes(vbytes)
        cmd=[str(HERE/'encoder'),str(table),str(source),str(donor_prefix),str(candidate_prefix)]
        result=subprocess.run(cmd,text=True,capture_output=True,timeout=50,cwd=HERE)
    decoded=json.loads(result.stdout) if result.stdout else None
    row={'window':tag,'layer':layer,'source':owner,'source_v_sha256':SHA(vbytes),
         'candidate_manifest_sha256':SHA((CAND/f'{tag}-manifest.json').read_bytes()),
         'table_sha256':SHA(table.read_bytes()),'original_event_sha256':donor_hash,
         'candidate_event_sha256':candidate_hash,'encoder_exit':result.returncode,
         'encoder_stderr':result.stderr,'encoder_result':decoded}
    (HERE/f'{tag}-parity.json').write_text(json.dumps(row,indent=2)+'\n')
    if result.returncode or not decoded or decoded['mismatches'] or decoded['rounded_decision_disagreements']:
        raise RuntimeError(f'threshold mismatch {tag}: {row}')
    assert decoded['records']==8*224 and decoded['coordinates']==8*224*128
    assert decoded['threshold_checks']==8*224*128*3
    return row

def main():
    if len(sys.argv)==4:
        rows=[run(int(sys.argv[1]),sys.argv[2],int(sys.argv[3]))]
    else:
        rows=[run(*w) for w in WINDOWS]
    print(json.dumps([{'window':x['window'],**x['encoder_result']} for x in rows]))
if __name__=='__main__':main()
