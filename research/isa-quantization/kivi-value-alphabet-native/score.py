"""Independent complete-O CPU targets reconstructed from pinned per-prefix candidate images."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
import torch
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
CAND=ROOT/'kivi-value-alphabet'
SNAP=ROOT/'kivi-two-bit-dot-native'
sys.path.insert(0,str(CAND))
from read import decode_key,decode_value,score
SHA=lambda b:hashlib.sha256(b).hexdigest()

def candidate(tag,t):
    n=int(tag[-1]);manifest=json.loads((CAND/f'{tag}-layer0-manifest.json').read_text())
    table_bytes=(CAND/'layer0-alphabet.f32').read_bytes()
    assert SHA(table_bytes)==manifest['table_sha256']
    table=np.frombuffer(table_bytes,dtype='<f4')
    arrivals=(ROOT/'kivi-value-intern'/f'{tag}-events.bin').read_bytes()
    assert len(arrivals)==256*4098
    nv=t-33;nk=(t-1)//32
    states=[]
    for h,row in enumerate(manifest['heads']):
        path=CAND/f'{tag}-layer0-t{t}-h{h}.bin'
        image=path.read_bytes();assert SHA(image)==row['prefix'][t-1]['image_sha256']
        key=image[:nk*1536]
        value=image[nk*1536:nk*1536+nv*48]
        kr=[arrivals[(j-1)*4098+2+h*256:(j-1)*4098+2+(h+1)*256] for j in range(nk*32+1,t+1)]
        vr=[arrivals[(j-1)*4098+2050+h*256:(j-1)*4098+2050+(h+1)*256] for j in range(nv+1,t+1)]
        assert image==key+value+b''.join(kr)+b''.join(vr)
        states.append((decode_key([key[i:i+1536] for i in range(0,len(key),1536)],kr),
                       decode_value([value[i:i+48] for i in range(0,len(value),48)],vr,table)))
    snapshots=json.loads((SNAP/'snapshots.json').read_text())
    owner=next(s for s in snapshots['states'] if s['window']==n and s['position']==t)
    qbytes=(SNAP/f'{tag}-t{t}-q.f32').read_bytes();assert SHA(qbytes)==owner['query_sha256']
    ob=(SNAP/'original-o.bf16').read_bytes();assert SHA(ob)==snapshots['original_o_sha256']
    o=torch.from_numpy(((np.frombuffer(ob,dtype='<u2').astype('<u4')<<16).view('<f4').copy()).reshape(1024,2048))
    torch.set_num_threads(1)
    result=score(np.frombuffer(qbytes,dtype='<f4').copy().reshape(16,128),states,o).astype('<f4')
    row=next(q for q in json.loads((CAND/f'{tag}-layer0-result.json').read_text())['queries'] if q['t']==t)
    assert SHA(result.tobytes())==row['output_sha256']
    return result

def prepare(tag):
    for t in (128,256):
        y=candidate(tag,t)
        (HERE/f'{tag}-t{t}-alphabet-cpu.f32').write_bytes(y.tobytes())

def run(tag):
    result=[]
    for t in (128,256):
        cpu=candidate(tag,t)
        assert (HERE/f'{tag}-t{t}-alphabet-cpu.f32').read_bytes()==cpu.tobytes()
        teacher=np.frombuffer((SNAP/f'{tag}-t{t}-teacher.f32').read_bytes(),dtype='<f4')
        for mode in (0,1):
            target=cpu if mode else np.frombuffer((SNAP/f'{tag}-t{t}-conventional-cpu.f32').read_bytes(),dtype='<f4')
            raw=(HERE/f'{tag}-t{t}-mode{mode}-actual.f32').read_bytes()
            actual=np.frombuffer(raw,dtype='<f4')
            assert len(actual)==1024 and np.isfinite(actual).all()
            diff=actual.astype('f8')-target.astype('f8')
            maxabs=float(abs(diff).max());relative=float(np.linalg.norm(diff)/np.linalg.norm(target))
            assert maxabs<=.005 and relative<=.005,(tag,t,mode,maxabs,relative)
            result.append({'t':t,'mode':mode,'actual_sha256':SHA(raw),'reference_sha256':SHA(target.tobytes()),'max_abs':maxabs,'relative_l2':relative,'teacher_sse':float(np.square(actual.astype('f8')-teacher.astype('f8')).sum())})
    return result
if __name__=='__main__':
    if sys.argv[1]=='prepare':
        for n in range(4):prepare(f'held-{n}')
    else:print(json.dumps(run(sys.argv[1])))
