"""Complete CPU O targets from original donor cache and retained moment images."""
import hashlib
import json
import math
import sys
from pathlib import Path
import numpy as np
import torch
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
MOMENT=ROOT/'kivi-value-error-moment'
BASE=ROOT/'kivi-two-bit-causal'
SNAP=ROOT/'kivi-two-bit-dot-native'
sys.path.insert(0,str(ROOT/'contextual-value-feedback'))
from replay import decode
SHA=lambda x:hashlib.sha256(x).hexdigest()

def build_reference(tag,t):
    receipt=json.loads((MOMENT/f'{tag}-manifest.json').read_text())
    row=next(x for x in json.loads((MOMENT/f'{tag}-result.json').read_text())['rows'] if x['t']==t)
    snapshots=json.loads((SNAP/'snapshots.json').read_text())
    snap=next(x for x in snapshots['states'] if x['tag']==f'{tag}-t{t}')
    qraw=(SNAP/f'{tag}-t{t}-q.f32').read_bytes();assert SHA(qraw)==snap['query_sha256']
    q=np.frombuffer(qraw,dtype='<f4').copy().reshape(16,128)
    ob=(SNAP/'original-o.bf16').read_bytes();assert SHA(ob)==snapshots['original_o_sha256']
    o=((np.frombuffer(ob,dtype='<u2').astype('<u4')<<16).view('<f4').copy()).reshape(1024,2048)
    heads=[];moments=[];nk=(t-1)//32;nrk=t-nk*32;nv=t-33;nrv=t-nv
    for h in range(8):
        path=BASE/f'{tag}-head{h}-events.bin';raw=path.read_bytes()
        assert SHA(raw)==receipt['heads'][h]['donor_log_sha256']
        k=[];v=[];offset=0
        while offset<len(raw):
            kind=raw[offset:offset+1];width=1536 if kind==b'K' else 48
            (k if kind==b'K' else v).append(raw[offset+3:offset+3+width]);offset+=3+width
        arrivals=(ROOT/'kivi-value-intern'/f'{tag}-events.bin').read_bytes()
        kr=[arrivals[(j-1)*4098+2+h*256:(j-1)*4098+2+(h+1)*256] for j in range(nk*32+1,t+1)]
        vr=[arrivals[(j-1)*4098+2050+h*256:(j-1)*4098+2050+(h+1)*256] for j in range(nv+1,t+1)]
        assert len(kr)==nrk and len(vr)==nrv
        heads.append(decode((k[:nk],v[:nv],kr,vr),2))
        image=receipt['snapshots'][str(t)][h];m=(MOMENT/image['file']).read_bytes()
        assert SHA(m)==image['sha256'] and len(m)==512
        moments.append(np.frombuffer(m,dtype='<f4').copy())
    torch.set_num_threads(1)
    keys=torch.from_numpy(np.ascontiguousarray(np.stack([a[0] for a in heads])))
    vals=torch.from_numpy(np.ascontiguousarray(np.stack([a[1] for a in heads])))
    qt=torch.from_numpy(q)
    prob=torch.bmm(qt[:,None,:],keys[torch.arange(16)//2].transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1)
    mixed=torch.bmm(prob[:,None,:],vals[torch.arange(16)//2]).squeeze(1)
    for head in range(16):
        mass=np.float32(0)
        for weight in prob[head,:nv].numpy():mass=np.float32(mass+np.float32(weight))
        alpha=np.float32(mass/np.float32(nv))
        mixed[head]=torch.add(mixed[head],torch.mul(torch.from_numpy(moments[head//2]),alpha))
    result=(mixed.reshape(2048)@torch.from_numpy(o).T).numpy().astype('<f4')
    assert SHA(result.tobytes())==row['output_sha256'],(tag,t,'complete donor CPU O')
    return result,row

def prepare(tag):
    for t in (128,256):
        y,_=build_reference(tag,t)
        (HERE/f'{tag}-t{t}-moment-cpu.f32').write_bytes(y.tobytes())

def run(tag,accept):
    answer=[]
    for t in (128,256):
        row=next(x for x in json.loads((MOMENT/f'{tag}-result.json').read_text())['rows'] if x['t']==t)
        y=np.frombuffer((HERE/f'{tag}-t{t}-moment-cpu.f32').read_bytes(),dtype='<f4')
        assert len(y)==1024 and SHA(y.tobytes())==row['output_sha256']
        if not accept:continue
        teacher=np.frombuffer((SNAP/f'{tag}-t{t}-teacher.f32').read_bytes(),dtype='<f4')
        for mode in (0,1):
            actual=np.frombuffer((HERE/f'{tag}-t{t}-mode{mode}-actual.f32').read_bytes(),dtype='<f4')
            assert len(actual)==1024 and np.isfinite(actual).all()
            target=y if mode else np.frombuffer((SNAP/f'{tag}-t{t}-conventional-cpu.f32').read_bytes(),dtype='<f4')
            error=actual.astype('f8')-target.astype('f8')
            maxabs=float(abs(error).max());rel=float(np.linalg.norm(error)/np.linalg.norm(target))
            assert maxabs<=.005 and rel<=.005,(tag,t,mode,maxabs,rel)
            sse=float(np.square(actual.astype('f8')-teacher.astype('f8')).sum())
            answer.append({'t':t,'mode':mode,'actual_sha256':SHA(actual.tobytes()),'reference_sha256':SHA(target.tobytes()),'max_abs':maxabs,'relative_l2':rel,'teacher_sse':sse,'donor_teacher_sse':row['sse'] if mode else None})
    return answer
if __name__=='__main__':
    if sys.argv[1]=='prepare':
        for n in range(4):prepare(f'held-{n}')
    else:print(json.dumps(run(sys.argv[1],len(sys.argv)>2)))
