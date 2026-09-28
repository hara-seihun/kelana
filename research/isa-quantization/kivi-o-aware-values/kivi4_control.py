"""Unchanged KIVI4 packed-event control on the identical eight retained states."""
import json
import sys
from pathlib import Path
import numpy as np
from verify import sha,bf16
from inputs import check as check_inputs

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
BASE=ROOT/'kivi-causal-cache'
OTHER=ROOT/'skvq-global-gqa'
PAID=ROOT/'kivi-two-bit-dot-native'
SOURCE=ROOT/'kivi-value-intern'


def decode4(blob,nk,nv,kr,vr):
    pos=0;keys=[];values=[]
    def unpack(data):
        a=np.frombuffer(data,dtype='u1')
        return np.column_stack((a&15,a>>4)).reshape(-1).astype('<f4')
    for _ in range(nk):
        d=unpack(blob[pos:pos+2048]).reshape(32,128);pos+=2048
        f=np.frombuffer(blob,dtype='<f2',count=256,offset=pos).astype('<f4').reshape(128,2);pos+=512
        keys.append(d*f[None,:,1]+f[None,:,0])
    for _ in range(nv):
        d=unpack(blob[pos:pos+64]).reshape(4,32);pos+=64
        f=np.frombuffer(blob,dtype='<f2',count=8,offset=pos).astype('<f4').reshape(4,2);pos+=16
        values.append((d*f[:,1,None]+f[:,0,None]).reshape(1,128))
    rk=np.frombuffer(blob,dtype='<u2',count=kr*128,offset=pos).reshape(kr,128);pos+=kr*256
    rv=np.frombuffer(blob,dtype='<u2',count=vr*128,offset=pos).reshape(vr,128);pos+=vr*256
    assert pos==len(blob)
    return np.concatenate(keys+[bf16(rk)]),np.concatenate(values+[bf16(rv)])


def run(window):
    input_receipt=check_inputs(window)
    tag=f'held-{window}'
    originals=json.loads((BASE/f'{tag}-manifest.json').read_text())
    other=json.loads((OTHER/f'{tag}-kivi-manifest.json').read_text())
    arrival=(SOURCE/f'{tag}-events.bin').read_bytes()
    logs=[];receipts=[];finals=[]
    for h in range(8):
        if h==0:
            log=(BASE/f'{tag}-flush.bin').read_bytes()
            assert sha(log)==originals['flush_log_sha256']
            receipt=originals['prefixes'];final=(BASE/f'{tag}-final.bin').read_bytes()
            assert sha(final)==originals['final_sha256']
        else:
            info=other['groups'][f'kv{h}']
            log=(OTHER/f'{tag}-kivi-head{h}-events.bin').read_bytes()
            assert sha(log)==info['event_log_sha256']
            receipt=info['prefixes'];final=(OTHER/f'{tag}-kivi-head{h}-final.bin').read_bytes()
            assert sha(final)==info['final_image_sha256']
        logs.append(log);receipts.append(receipt);finals.append(final)
    kq=[[] for _ in range(8)];vq=[[] for _ in range(8)];kr=[[] for _ in range(8)];vr=[[] for _ in range(8)];offsets=[0]*8
    obytes=(PAID/'original-o.bf16').read_bytes()
    o=bf16(np.frombuffer(obytes,dtype='<u2')).reshape(1024,2048)
    result=[];peak=0
    for t in range(1,257):
        entry=arrival[(t-1)*4098:t*4098]
        assert len(entry)==4098 and int.from_bytes(entry[:2],'little')==t
        states=[]
        for h in range(8):
            kr[h].append(entry[2+h*256:2+(h+1)*256]);vr[h].append(entry[2050+h*256:2050+(h+1)*256])
            before=b''.join(kq[h]+vq[h]+kr[h]+vr[h]);states.append(before)
            receipt=receipts[h][t-1]['before_flush' if h==0 else 'before']
            assert sha(before)==receipt['sha256'] and len(before)==(receipt['live_state_bytes'] if h==0 else receipt['bytes'])
            peak=max(peak,len(before)*8)
        if t in (128,256):
            q=np.frombuffer((PAID/f'{tag}-t{t}-q.f32').read_bytes(),dtype='<f4').reshape(16,128)
            mixed=np.zeros(2048,dtype='<f4')
            for h,s in enumerate(states):
                k,v=decode4(s,len(kq[h]),len(vq[h]),len(kr[h]),len(vr[h]))
                for i in range(2):
                    score=(k@q[2*h+i])/np.sqrt(np.float32(128));p=np.exp(score-score.max());p/=p.sum()
                    mixed[(2*h+i)*128:(2*h+i+1)*128]=p@v
            output=o@mixed
            teacher=np.frombuffer((PAID/f'{tag}-t{t}-teacher.f32').read_bytes(),dtype='<f4')
            result.append({'t':t,'kivi4_teacher_sse':float(np.sum((output-teacher)**2,dtype=np.float64)),
                           'kivi4_output_sha256':sha(output.astype('<f4').tobytes()),'teacher_sq':float(np.sum(teacher**2,dtype=np.float64)),
                           'state_sha256':[sha(x) for x in states]})
        for h in range(8):
            def consume(kind,size):
                offset=offsets[h];piece=logs[h][offset:offset+3+size]
                assert piece[:1]==kind and int.from_bytes(piece[1:3],'little')==t and len(piece)==3+size
                offsets[h]+=3+size
                return piece[3:]
            if len(kr[h])==32:kq[h].append(consume(b'K',2560));kr[h].clear()
            if len(vr[h])>32:vq[h].append(consume(b'V',80));vr[h].pop(0)
            after=b''.join(kq[h]+vq[h]+kr[h]+vr[h])
            receipt=receipts[h][t-1]['after_flush' if h==0 else 'after']
            assert sha(after)==receipt['sha256'] and len(after)==(receipt['live_state_bytes'] if h==0 else receipt['bytes'])
    assert peak==419200
    assert all(offsets[h]==len(logs[h]) and b''.join(kq[h]+vq[h]+kr[h]+vr[h])==finals[h] for h in range(8))
    (HERE/f'{tag}-kivi4-control.json').write_text(json.dumps({'window':window,'peak_cache_bytes':peak,'retained':result,
       'owner_event_sha256':[sha(x) for x in logs],'owner_final_sha256':[sha(x) for x in finals],
       'input_identity':input_receipt},indent=2)+'\n')
    print(json.dumps({'window':window,'states':[(x['t'],x['kivi4_teacher_sse']) for x in result]}))

if __name__=='__main__':run(int(sys.argv[1]))
