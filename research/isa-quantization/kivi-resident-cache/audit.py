"""Audit native snapshots against immutable arrivals and original KIVI2 event bytes.

Never calls the source model, GPU, or the native transition implementation.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
BASE=ROOT/'kivi-two-bit-causal'
INTERN=ROOT/'kivi-value-intern'
sys.path.insert(0,str(INTERN))
from verify import decode,baseline_check


def digest(blob):return hashlib.sha256(blob).hexdigest()


def state_at(state,t,phase):
    state['t'],state['phase']=t,phase
    return state


def expected_control(state):
    return b''.join(b''.join(state['kq'][h])+b''.join(v[h] for v in state['vq'])+
        b''.join(state['kr'][h])+b''.join(v[h] for v in state['vr']) for h in range(8))


def audit(name,path,backend='device'):
    assert backend in ('device','host-shim')
    manifest=json.loads((INTERN/f'{name}-manifest.json').read_text())
    original=json.loads((BASE/f'{name}-manifest.json').read_text())
    arrivals=(INTERN/f'{name}-events.bin').read_bytes()
    assert digest(arrivals)==manifest['events_sha256'] and len(arrivals)==256*4098
    logs=[(BASE/f'{name}-head{h}-events.bin').read_bytes() for h in range(8)]
    assert [digest(x) for x in logs]==manifest['baseline_events_sha256']
    snapshots=path.read_bytes();cursor=0;offsets=[0]*8;count=0
    state={'kq':[[] for _ in range(8)],'kr':[[] for _ in range(8)],'vq':[],'vr':[],'t':0,'phase':1}
    def take(mode,t,phase):
        nonlocal cursor,count
        header=snapshots[cursor:cursor+8];assert len(header)==8
        actual_mode,actual_phase,actual_t,n=struct.unpack('<BBHI',header)
        assert (actual_mode,actual_t,actual_phase)==(mode,t,phase)
        cursor+=8;blob=snapshots[cursor:cursor+n];assert len(blob)==n;cursor+=n
        baseline_check(state,original)
        if mode:
            receipt=manifest['prefixes'][t-1]['before' if phase==0 else 'after']
            decode(blob,t,phase,state,receipt)
        else:
            expected=expected_control(state)
            assert blob==expected,(mode,t,phase,'control logical bytes')
            assert len(blob)==original['peak_full_layer_bytes'] if t==256 and phase==0 else True
        count+=1
    for mode in range(2):
        offsets[:]=[0]*8
        state={'kq':[[] for _ in range(8)],'kr':[[] for _ in range(8)],'vq':[],'vr':[],'t':0,'phase':1}
        for t in range(1,257):
            frame=arrivals[(t-1)*4098:t*4098]
            assert int.from_bytes(frame[:2],'little')==t
            keys=frame[2:2050];values=frame[2050:4098]
            for h in range(8):state['kr'][h].append(keys[h*256:(h+1)*256])
            state['vr'].append(tuple(values[h*256:(h+1)*256] for h in range(8)))
            state_at(state,t,0);take(mode,t,0)
            for h in range(8):
                def event(tag,length):
                    pos=offsets[h];payload=logs[h][pos+3:pos+3+length]
                    assert logs[h][pos:pos+1]==tag and int.from_bytes(logs[h][pos+1:pos+3],'little')==t
                    assert len(payload)==length;offsets[h]=pos+3+length
                    return payload
                if len(state['kr'][h])==32:
                    state['kq'][h].append(event(b'K',1536));state['kr'][h].clear()
                if len(state['vr'])==33:
                    if h==0:flushed=[]
                    flushed.append(event(b'V',48))
            if len(state['vr'])==33:
                state['vq'].append(tuple(flushed));state['vr'].pop(0)
            state_at(state,t,1);take(mode,t,1)
        assert all(offsets[h]==len(logs[h]) for h in range(8))
    assert cursor==len(snapshots) and count==1024
    print(json.dumps({'backend':backend,'window':name,'phases':count,'snapshots_sha256':digest(snapshots),
                      'arrival_sha256':digest(arrivals),'source_events_sha256':[digest(x) for x in logs]}))


if __name__=='__main__':audit(sys.argv[1],Path(sys.argv[2]),sys.argv[3] if len(sys.argv)>3 else 'device')
