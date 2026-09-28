"""Chronological unchanged-code V error moment; source and donor receipts are immutable inputs."""
import hashlib
import json
import sys
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
CONTEXT=ROOT/'contextual-value-feedback'
HELD=ROOT/'kivi-value-error-feedback'
BASE=ROOT/'kivi-two-bit-causal'
ARRIVAL=ROOT/'kivi-value-intern'

def sha(b): return hashlib.sha256(b).hexdigest()
def fp(raw): return (np.frombuffer(raw,dtype='<u2').astype('<u4')<<16).view('<f4')
def unpack(blob):
    b=np.frombuffer(blob[:32],dtype='u1')
    return np.column_stack((b&3,(b>>2)&3,(b>>4)&3,b>>6)).reshape(4,32).astype('<f4')
def decoded(blob):
    fields=np.frombuffer(blob[32:],dtype='<f2').astype('<f4').reshape(4,2)
    return np.add(np.multiply(fields[:,1,None],unpack(blob),dtype='<f4'),fields[:,0,None],dtype='<f4').reshape(128)
def records(log):
    entries=[];p=0
    while p<len(log):
        kind=log[p:p+1];assert kind in (b'K',b'V')
        n=1536 if kind==b'K' else 48
        t=int.from_bytes(log[p+1:p+3],'little');blob=log[p+3:p+3+n]
        assert len(blob)==n
        entries.append((kind,t,blob));p+=n+3
    assert p==len(log)
    return entries

def contextual(panel,w):
    name=f'{panel}-{w}'
    source_path=CONTEXT/f'{name}-source.npz';source_rec=json.loads((CONTEXT/f'{name}-source.json').read_text())
    assert sha(source_path.read_bytes())==source_rec['source_file_sha256']
    with np.load(source_path) as data: v=data['v'].copy()
    assert sha(v.tobytes())==source_rec['arrays']['v']['sha256']
    donor_path=CONTEXT/f'{name}-manifest.json';donor=json.loads(donor_path.read_text())
    assert donor['source_sha256']==source_rec['source_file_sha256']
    return name,v,donor,sha(donor_path.read_bytes()),source_rec['source_file_sha256']

def held(w):
    name=f'held-{w}'
    path=ARRIVAL/f'{name}-events.bin';audit_path=ARRIVAL/f'{name}-manifest.json'
    audit=json.loads(audit_path.read_text());raw=path.read_bytes();assert sha(raw)==audit['events_sha256']
    v=np.empty((256,8,128),dtype='<u2')
    for t in range(256):
        row=raw[t*4098:(t+1)*4098];assert int.from_bytes(row[:2],'little')==t+1
        v[t]=np.frombuffer(row[2050:],dtype='<u2').reshape(8,128)
    donor_path=BASE/f'{name}-manifest.json';donor=json.loads(donor_path.read_text())
    assert audit['baseline_manifest_sha256']==sha(donor_path.read_bytes())
    return name,v,donor,sha(donor_path.read_bytes()),sha(raw)

def run(panel,w):
    is_held=panel=='held'
    name,v,donor,donor_sha,source_sha=held(w) if is_held else contextual(panel,w)
    snapshots={};heads=[];peak=0
    for h in range(8):
        info=donor['groups'][f'kv{h}'] if is_held else donor['arms']['original']['heads'][h]
        log_path=(BASE/f'{name}-head{h}-events.bin') if is_held else (CONTEXT/f'{name}-original-h{h}-events.bin')
        log=log_path.read_bytes(); assert sha(log)==info['events_sha256']
        events=records(log);vs=[(t,blob) for k,t,blob in events if k==b'V']
        assert len(vs)==224 and all(t==i+33 for i,(t,_) in enumerate(vs))
        s=np.zeros(128,dtype='<f4');trace=[]
        for t in range(1,257):
            before=s.tobytes()
            if t in (128,256):
                path=HERE/f'{name}-t{t}-h{h}.moment.f32';path.write_bytes(before)
                snapshots[str(t)]=snapshots.get(str(t),[])+[{'file':path.name,'sha256':sha(before),'bytes':len(before)}]
            if t>=33:
                original=vs[t-33][1];src=fp(v[t-33,h].tobytes())
                error=np.subtract(src,decoded(original),dtype='<f4')
                s=np.add(s,error,dtype='<f4')
            trace.append({'before':sha(before),'after':sha(s.tobytes())})
        final=s.tobytes();path=HERE/f'{name}-final-h{h}.moment.f32';path.write_bytes(final)
        heads.append({'donor_log_sha256':sha(log),'value_flushes':len(vs),'trace':trace,'final':{'file':path.name,'sha256':sha(final),'bytes':len(final)}})
        peak=max(peak,info['peak_bytes'])
    assert peak*8==304768
    assert sum((donor['groups'][f'kv{h}']['final_bytes'] if is_held else donor['arms']['original']['heads'][h]['final_bytes']) for h in range(8))==249856
    result={'panel':panel,'window':w,'source_sha256':source_sha,'donor_manifest_sha256':donor_sha,'donor':'original independent K2/V2','heads':heads,'snapshots':snapshots,'peak_bytes':308864,'final_bytes':253952,'moment_bytes':4096,'contract':'FP32 source minus separate-multiply-add stored-field decode; FP32 accumulator add at each original after-query V33 flush'}
    (HERE/f'{name}-manifest.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    print(json.dumps({'name':name,'flushes':sum(x['value_flushes'] for x in heads),'peak_bytes':result['peak_bytes']}))

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
