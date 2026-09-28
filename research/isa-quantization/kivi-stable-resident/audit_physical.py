"""Independent original-event byte oracle for fixed-slot and fixed control GPU frames."""
import hashlib
import json
import struct
import subprocess
import sys
from collections import Counter
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'kivi-stable-records'))
import audit as donor

def sha(b): return hashlib.sha256(b).hexdigest()
def exact(f,n):
    chunks=bytearray()
    while len(chunks)<n:
        piece=f.read(n-len(chunks))
        assert piece,'truncated snapshot'
        chunks.extend(piece)
    return bytes(chunks)

def decode(mode,blob,t,phase,state):
    nq,nr=len(state['vq']),len(state['vr'])
    nchunk=len(state['kq'][0]);nkr=len(state['kr'][0])
    if mode==1:
        assert len(blob)==276428
        kc=18944;offset=8*kc
        for h in range(8):
            assert blob[h*kc:h*kc+nchunk*1536+nkr*256]==b''.join(state['kq'][h]+state['kr'][h])
        qbytes=blob[offset:offset+148*384];offset+=148*384
        rbytes=blob[offset:offset+33*2048];offset+=33*2048
        qrefs=blob[offset:offset+224][:nq];offset+=224
        ring=blob[offset:offset+33];offset+=33
        qcounts=blob[offset:offset+148];offset+=148
        rcounts=blob[offset:offset+33];offset+=33
        stamp,ph,qn,rn,err=struct.unpack_from('<5i',blob,(offset+3)&~3)
        assert (stamp,ph,qn,rn,err)==(t,phase,nq,nr,0)
        rrefs=[ring[(t-nr+j)%33] for j in range(nr)]
        assert Counter(qrefs)=={s:c for s,c in enumerate(qcounts) if c}
        assert Counter(rrefs)=={s:c for s,c in enumerate(rcounts) if c}
        assert sum(bool(c) for c in qcounts)<=148 and sum(bool(c) for c in rcounts)<=33
        assert len({qbytes[s*384:(s+1)*384] for s,c in enumerate(qcounts) if c})==sum(bool(c) for c in qcounts)
        assert len({rbytes[s*2048:(s+1)*2048] for s,c in enumerate(rcounts) if c})==sum(bool(c) for c in rcounts)
        for refs,records,stored,width in ((qrefs,state['vq'],qbytes,384),(rrefs,state['vr'],rbytes,2048)):
            assert len(refs)==len(records)
            for index,record in zip(refs,records):
                assert stored[index*width:(index+1)*width]==b''.join(record)
    else:
        assert len(blob)==305156
        kbase=0;vbase=8*18944;rbase=vbase+8*224*48
        for h in range(8):
            assert blob[kbase+h*18944:kbase+h*18944+nchunk*1536+nkr*256]==b''.join(state['kq'][h]+state['kr'][h])
            assert blob[vbase+h*224*48:vbase+h*224*48+nq*48]==b''.join(record[h] for record in state['vq'])
            for j,record in enumerate(state['vr']):
                at=rbase+h*33*256+((t-nr+j)%33)*256
                assert blob[at:at+256]==record[h]
        assert struct.unpack_from('<i',blob,305152)==(0,)

def verify_frames(f,windows,mode_set):
    state={'kq':[[] for _ in range(8)],'kr':[[] for _ in range(8)],'vq':[],'vr':[],'t':0,'phase':1}
    name=windows
    manifest=json.loads((ROOT/'kivi-value-intern'/f'{name}-manifest.json').read_text())
    original=json.loads((ROOT/'kivi-two-bit-causal'/f'{name}-manifest.json').read_text())
    logs=[(ROOT/'kivi-two-bit-causal'/f'{name}-head{h}-events.bin').read_bytes() for h in range(8)]
    assert [sha(s) for s in logs]==manifest['baseline_events_sha256']
    arrivals=(ROOT/'kivi-value-intern'/f'{name}-events.bin').read_bytes()
    assert sha(arrivals)==manifest['events_sha256'] and len(arrivals)==256*4098
    offsets=[0]*8;checks=0;phases=0
    def frame(t,phase):
        nonlocal checks,phases
        header=exact(f,8);mode,ph,stamp,size=struct.unpack('<BBHI',header)
        assert mode in mode_set and (ph,stamp)==(phase,t)
        blob=exact(f,size)
        state['t'],state['phase']=t,phase
        checks+=donor.baseline_check(state,original)
        decode(mode,blob,t,phase,state)
        phases+=1
    for t in range(1,257):
        event=arrivals[(t-1)*4098:t*4098]
        assert int.from_bytes(event[:2],'little')==t
        kb,vb=event[2:2050],event[2050:]
        for h in range(8):state['kr'][h].append(kb[h*256:(h+1)*256])
        state['vr'].append(tuple(vb[h*256:(h+1)*256] for h in range(8)))
        frame(t,0)
        for h in range(8):
            def consume(tag,size):
                at=offsets[h];stream=logs[h]
                assert stream[at:at+1]==tag and int.from_bytes(stream[at+1:at+3],'little')==t
                payload=stream[at+3:at+3+size]
                assert len(payload)==size
                offsets[h]=at+3+size
                return payload
            if len(state['kr'][h])==32:
                state['kq'][h].append(consume(b'K',1536));state['kr'][h].clear()
            if len(state['vr'])>32:
                if h==0:flushed=[]
                flushed.append(consume(b'V',48))
        if len(state['vr'])>32:state['vq'].append(tuple(flushed));state['vr'].pop(0)
        frame(t,1)
    assert all(offsets[h]==len(logs[h]) for h in range(8))
    return {'phases':phases,'ordered_original_records':checks}

def main(name,source):
    assert name in [f'held-{i}' for i in range(4)]
    if source=='cpu':
        receipt={}
        for mode,label in ((0,'control'),(1,'stable')):
            proc=subprocess.Popen([str(HERE/'cpu'),str(ROOT/'kivi-value-intern'/f'{name}-events.bin'),label],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            try:
                receipt[str(mode)]=verify_frames(proc.stdout,name,{mode})
                assert proc.stdout.read(1)==b'' and proc.wait(timeout=5)==0,proc.stderr.read()
            finally:
                if proc.poll() is None:proc.kill();proc.wait()
    else:
        with open(source,'rb') as stream:
            receipt={str(mode):verify_frames(stream,name,{mode}) for mode in (0,1)}
            assert not stream.read(1)
    output={'name':name,'backend':'cpu' if source=='cpu' else 'device',**receipt}
    if source!='cpu':
        h=hashlib.sha256();size=0
        with open(source,'rb') as stream:
            while part:=stream.read(1024*1024):h.update(part);size+=len(part)
        output['snapshot_sha256']=h.hexdigest();output['snapshot_bytes']=size
    print(json.dumps(output))
if __name__=='__main__':main(sys.argv[1],sys.argv[2])
