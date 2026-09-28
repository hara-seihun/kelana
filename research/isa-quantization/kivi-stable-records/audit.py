"""Independent ordered-byte oracle for the fixed-slot CPU maintainer."""
import hashlib
import json
import struct
import subprocess
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

def sha(blob):
    return hashlib.sha256(blob).hexdigest()

def read_exact(pipe, n):
    blob = bytearray()
    while len(blob) < n:
        part = pipe.read(n-len(blob))
        assert part, 'short native stream'
        blob.extend(part)
    return bytes(blob)

def decode(blob, t, phase, expected):
    assert len(blob)>=7
    stamp, ph, qactive, ractive, kc, kr = struct.unpack_from('<HBBBBB', blob)
    assert (stamp, ph)==(t, phase)
    assert kc==len(expected['kq'][0]) and kr==len(expected['kr'][0])
    nq,nr=len(expected['vq']),len(expected['vr'])
    cursor=7
    for h in range(8):
        for part in expected['kq'][h]+expected['kr'][h]:
            assert blob[cursor:cursor+len(part)]==part
            cursor+=len(part)
    qrefs=list(blob[cursor:cursor+nq]); cursor+=nq
    rrefs=list(blob[cursor:cursor+nr]); cursor+=nr
    qslots={}; rslots={}; qc={}; rc={}
    for count, width, slots, counts, cap in ((qactive,384,qslots,qc,148),(ractive,2048,rslots,rc,33)):
        last=-1
        for _ in range(count):
            slot, refs=blob[cursor:cursor+2]; cursor+=2
            assert last<slot<cap and refs>0
            last=slot
            slots[slot]=blob[cursor:cursor+width]; cursor+=width
            counts[slot]=refs
    assert cursor==len(blob)
    assert Counter(qrefs)==qc and Counter(rrefs)==rc
    assert len(set(qslots.values()))==qactive and len(set(rslots.values()))==ractive
    for refs,slots,records,width in ((qrefs,qslots,expected['vq'],48),(rrefs,rslots,expected['vr'],256)):
        for index,record in zip(refs,records):
            stored=slots[index]
            for h in range(8):
                assert stored[h*width:(h+1)*width]==record[h]
    return len(expected['kq'][0])*8+len(expected['kr'][0])*8+(nq+nr)*8

def baseline_check(state, receipt):
    checked=0
    for h in range(8):
        raw=(b''.join(state['kq'][h])+b''.join(v[h] for v in state['vq'])+
             b''.join(state['kr'][h])+b''.join(v[h] for v in state['vr']))
        name='before_query_flush' if state['phase']==0 else 'after_query_flush'
        record=receipt['groups'][f'kv{h}']['prefixes'][state['t']-1][name]
        assert len(raw)==record['bytes'] and sha(raw)==record['sha256']
        checked+=len(state['kq'][h])+len(state['kr'][h])+len(state['vq'])+len(state['vr'])
    return checked

def run(name):
    panel, window=name.split('-')
    assert panel in ('train','held') and 0<=int(window)<(8 if panel=='train' else 4)
    manifest=json.loads((ROOT/'kivi-value-intern'/f'{name}-manifest.json').read_text())
    original=json.loads((ROOT/'kivi-two-bit-causal'/f'{name}-manifest.json').read_text())
    logs=[(ROOT/'kivi-two-bit-causal'/f'{name}-head{h}-events.bin').read_bytes() for h in range(8)]
    assert [sha(s) for s in logs]==manifest['baseline_events_sha256']
    events=ROOT/'kivi-value-intern'/f'{name}-events.bin'
    arrivals=events.read_bytes()
    assert sha(arrivals)==manifest['events_sha256'] and len(arrivals)==256*4098
    state={'kq':[[] for _ in range(8)], 'kr':[[] for _ in range(8)], 'vq':[], 'vr':[], 't':0, 'phase':1}
    offsets=[0]*8
    proc=subprocess.Popen([str(HERE/'stable'),str(events)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0)
    checked=0; hashes=[]; peak=0
    def frame(t,phase):
        nonlocal checked, peak
        size,=struct.unpack('<I',read_exact(proc.stdout,4))
        blob=read_exact(proc.stdout,size)
        state['t'],state['phase']=t,phase
        checked+=baseline_check(state,original)
        decode(blob,t,phase,state)
        hashes.append(sha(blob)); peak=max(peak,size)
        return blob
    try:
        for t in range(1,257):
            event=arrivals[(t-1)*4098:t*4098]
            assert int.from_bytes(event[:2],'little')==t
            kb,vb=event[2:2050],event[2050:]
            for h in range(8): state['kr'][h].append(kb[h*256:(h+1)*256])
            state['vr'].append(tuple(vb[h*256:(h+1)*256] for h in range(8)))
            frame(t,0)
            for h in range(8):
                def consume(tag,size):
                    at=offsets[h]; stream=logs[h]
                    assert stream[at:at+1]==tag and int.from_bytes(stream[at+1:at+3],'little')==t
                    payload=stream[at+3:at+3+size]
                    assert len(payload)==size
                    offsets[h]=at+3+size
                    return payload
                if len(state['kr'][h])==32:
                    state['kq'][h].append(consume(b'K',1536)); state['kr'][h].clear()
                if len(state['vr'])>32:
                    if h==0: flushed=[]
                    flushed.append(consume(b'V',48))
            if len(state['vr'])>32:
                state['vq'].append(tuple(flushed)); state['vr'].pop(0)
            final=frame(t,1)
        assert proc.stdout.read(1)==b'' and all(offsets[h]==len(logs[h]) for h in range(8))
        assert proc.wait(timeout=5)==0,proc.stderr.read().decode()
        ledger=json.loads(proc.stderr.read())
        assert ledger['snapshots']==512 and ledger['quant_peak']<=148 and ledger['recent_peak']<=33
        (HERE/f'{name}-final.bin').write_bytes(final)
        result={'window':name,'prefixes_verified':512,'original_record_checks':checked,
                'peak_snapshot_bytes':peak,'final_bytes':len(final),'final_sha256':sha(final),
                'arrival_sha256':sha(arrivals),'phase_sha256':hashes,**ledger}
        (HERE/f'{name}-result.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps({k:v for k,v in result.items() if k!='phase_sha256'}))
    finally:
        if proc.poll() is None:
            proc.kill(); proc.wait()

if __name__=='__main__': run(sys.argv[1])
