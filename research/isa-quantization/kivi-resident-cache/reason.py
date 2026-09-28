"""CPU-only capacity and event-availability preflight; no source/model or GPU call."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
BASE=ROOT/'kivi-two-bit-causal'
INTERN=ROOT/'kivi-value-intern'
NATIVE=ROOT/'kivi-two-bit-dot-native'

def run():
    panel=[]
    for name in [*(f'train-{i}' for i in range(8)),*(f'held-{i}' for i in range(4))]:
        manifest=json.loads((INTERN/f'{name}-manifest.json').read_text())
        original=json.loads((BASE/f'{name}-manifest.json').read_text())
        arrivals=(INTERN/f'{name}-events.bin').read_bytes()
        assert len(arrivals)==256*4098
        assert hashlib.sha256(arrivals).hexdigest()==manifest['events_sha256']
        for t in range(1,257):
            assert int.from_bytes(arrivals[(t-1)*4098:(t-1)*4098+2],'little')==t
            b,a=manifest['prefixes'][t-1]['before'],manifest['prefixes'][t-1]['after']
            assert b['bytes']<=266240 and a['bytes']<=266240
            chunks=(t-1)//32
            quant=max(0,t-33)
            control=8*(chunks*1536+quant*48+(t-32*chunks)*256+(t-quant)*256)
            assert control==original['groups']['kv0']['prefixes'][t-1]['before_query_flush']['bytes']*8
            assert control<=304768
        panel.append({'window':name,'arrival_sha256':manifest['events_sha256'],
                      'dictionary_peak':manifest['peak_bytes'],'dictionary_final':manifest['final_bytes'],
                      'control_peak':original['peak_full_layer_bytes']})
    snapshots=json.loads((NATIVE/'snapshots.json').read_text())
    o=(NATIVE/'original-o.bf16').read_bytes()
    assert len(o)==4194304 and hashlib.sha256(o).hexdigest()==snapshots['original_o_sha256']
    assert len(snapshots['states'])==8
    for receipt in snapshots['states']:
        tag=NATIVE/receipt['tag']
        for suffix,expected_size,identity in (
            ('-q.f32',8192,'query_sha256'),('-teacher.f32',4096,'teacher_sha256'),
            ('-conventional-cpu.f32',4096,'cpu_conventional_sha256')):
            blob=tag.with_name(tag.name+suffix).read_bytes()
            assert len(blob)==expected_size and hashlib.sha256(blob).hexdigest()==receipt[identity]
        assert receipt['original_o_sha256']==snapshots['original_o_sha256']
    print(json.dumps({'windows':panel,'retained_query_states':8,'original_o_sha256':snapshots['original_o_sha256'],
                      'other_queries_available':False},indent=2))
if __name__=='__main__':run()
