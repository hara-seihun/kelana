"""CPU-only immutable-input and compiled-resource gate; never launches a device kernel."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
SOURCES=('state.hip','reader.hip','native.hip','../kivi-resident-cache/step_bits.hpp')
def sha(blob):return hashlib.sha256(blob).hexdigest()
def source_hash():return sha(''.join(f'{p} {sha((HERE/p).read_bytes())}\n' for p in SOURCES).encode())
def main():
    compile=json.loads((HERE/'compile-receipt.json').read_text())
    assert compile['target']=='gfx1151'
    assert compile['source_sha256']=={p:sha((HERE/p).read_bytes()) for p in SOURCES}
    assert compile['binary_sha256']==sha((HERE/'native').read_bytes())
    assert compile['assembly_sha256']==sha((HERE/'assembly-gfx1151.s').read_bytes())
    assert len(compile['device_kernels'])==9
    assert all(k['private_scratch']==0 for k in compile['device_kernels'])
    assert 8*18944+148*384+33*2048+224+33+148+33+2+5*4==276428
    assert 8*18944+8*224*48+8*33*256+4==305156
    immutable=json.loads((ROOT/'kivi-two-bit-dot-native'/'snapshots.json').read_text())
    assert len(immutable['states'])==8
    states={(s['window'],s['position']):s for s in immutable['states']}
    assert set(states)=={(n,t) for n in range(4) for t in (128,256)}
    inputs={}
    for n in range(4):
        tag=f'held-{n}'
        manifest=json.loads((ROOT/'kivi-value-intern'/f'{tag}-manifest.json').read_text())
        arrival=(ROOT/'kivi-value-intern'/f'{tag}-events.bin').read_bytes()
        assert len(arrival)==256*4098 and sha(arrival)==manifest['events_sha256']
        snapshots={}
        for t in (128,256):
            prefix=ROOT/'kivi-two-bit-dot-native'/f'{tag}-t{t}'
            snapshots[t]={}
            owner=states[(n,t)]
            assert owner['tag']==f'{tag}-t{t}' and owner['original_o_sha256']==immutable['original_o_sha256']
            for kind,size,key in [('q.f32',8192,'query_sha256'),('conventional-cpu.f32',4096,'cpu_conventional_sha256'),('teacher.f32',4096,'teacher_sha256')]:
                b=Path(f'{prefix}-{kind}').read_bytes();assert len(b)==size and sha(b)==owner[key]
                snapshots[t][kind]=sha(b)
        inputs[tag]={'arrival_sha256':sha(arrival),'held_shapes_and_hashes':snapshots}
    ob=(ROOT/'kivi-two-bit-dot-native'/'original-o.bf16').read_bytes();assert len(ob)==4194304 and sha(ob)==immutable['original_o_sha256']
    receipt={'source_hash':source_hash(),'binary_sha256':compile['binary_sha256'],'original_o_sha256':sha(ob),
             'device_bytes':{'stable_state':276428,'control_state':305156,'value_stage':384,'arrival':4096,'q':8192,'o':4194304,'partial':32768,'output':4096,'stable_total':4520268,'control_total':4548996},
             'inputs':inputs,'kernels':compile['device_kernels']}
    if len(sys.argv)>1 and sys.argv[1]=='prepare':
        for tag in inputs:
            p=subprocess.run([sys.executable,str(HERE/'audit_physical.py'),tag,'cpu'],capture_output=True,text=True,timeout=45,check=True,cwd=HERE)
            audit=json.loads(p.stdout)
            assert audit['0']['phases']==audit['1']['phases']==512
            inputs[tag]['cpu_acceptance']=audit
        (HERE/'prelaunch-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    else:
        saved=json.loads((HERE/'prelaunch-receipt.json').read_text())
        for tag in inputs:saved['inputs'][tag].pop('cpu_acceptance')
        assert json.loads(json.dumps(receipt))==saved
    print(json.dumps({'source_hash':receipt['source_hash'],'binary_sha256':receipt['binary_sha256'],'cpu_phases':4096,'stable_device_bytes':4520268,'control_device_bytes':4548996}))
if __name__=='__main__':main()
