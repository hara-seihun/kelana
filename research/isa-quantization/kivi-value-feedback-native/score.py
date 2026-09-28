"""Build retained donor complete-O maps, then compare actual device outputs and teacher receipts."""
import hashlib
import json
import math
import sys
from pathlib import Path
import numpy as np
import torch
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
sys.path.insert(0,str(ROOT/'kivi-value-error-feedback'))
import replay as donor
SHA=lambda b:hashlib.sha256(b).hexdigest()

def build_reference(tag,t):
    source=ROOT/'kivi-value-error-feedback'
    retained=json.loads((source/f'{tag}-result.json').read_text())['arms']['feedback']['retained']
    receipt=next(x for x in retained if x['t']==t)
    q=torch.from_numpy(np.frombuffer((ROOT/'kivi-two-bit-dot-native'/f'{tag}-t{t}-q.f32').read_bytes(),dtype='<f4').copy().reshape(16,128))
    o=(donor.bf16(np.frombuffer((ROOT/'kivi-two-bit-dot-native'/'original-o.bf16').read_bytes(),dtype='<u2')).copy().reshape(1024,2048))
    heads=[];nk=(t-1)//32;nrk=t-nk*32;nv=t-33;nrv=t-nv
    for h in range(8):
        image=(source/f'{tag}-feedback-t{t}-kv{h}.bin').read_bytes()
        assert SHA(image)==json.loads((source/f'{tag}-manifest.json').read_text())['arms']['feedback']['heads'][h]['prefixes'][t-1]['before']
        at=0;kq=[image[at+i*1536:at+(i+1)*1536] for i in range(nk)];at+=nk*1536
        vq=[image[at+i*48:at+(i+1)*48] for i in range(nv)];at+=nv*48
        kr=[image[at+i*256:at+(i+1)*256] for i in range(nrk)];at+=nrk*256
        vr=[image[at+i*256:at+(i+1)*256] for i in range(nrv)];at+=nrv*256
        assert at==len(image)
        heads.append((donor.expand(kq,kr,'K'),donor.expand(vq,vr,'V')))
    k=torch.from_numpy(np.repeat(np.stack([x[0] for x in heads]),2,axis=0).copy())
    v=torch.from_numpy(np.repeat(np.stack([x[1] for x in heads]),2,axis=0).copy())
    a=torch.bmm(q[:,None,:],k.transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1)
    y=(torch.bmm(a[:,None,:],v).reshape(2048)@torch.from_numpy(o).T).numpy().astype('<f4')
    assert SHA(y.tobytes())==receipt['output_sha256'],(tag,t,'donor O map hash')
    return y,receipt

def prepare(tag):
    torch.set_num_threads(1)
    for t in (128,256):
        y,receipt=build_reference(tag,t)
        p=HERE/f'{tag}-t{t}-feedback-cpu.f32'
        p.write_bytes(y.tobytes())
        assert SHA(p.read_bytes())==receipt['output_sha256']

def run(tag,accept):
    answer=[]
    for t in (128,256):
        receipt=next(x for x in json.loads((ROOT/'kivi-value-error-feedback'/f'{tag}-result.json').read_text())['arms']['feedback']['retained'] if x['t']==t)
        y=np.frombuffer((HERE/f'{tag}-t{t}-feedback-cpu.f32').read_bytes(),dtype='<f4')
        assert len(y)==1024 and SHA(y.tobytes())==receipt['output_sha256']
        teacher=np.frombuffer((ROOT/'kivi-two-bit-dot-native'/f'{tag}-t{t}-teacher.f32').read_bytes(),dtype='<f4')
        for mode in (0,1):
            actual_path=HERE/f'{tag}-t{t}-mode{mode}-actual.f32'
            if not accept:continue
            actual=np.frombuffer(actual_path.read_bytes(),dtype='<f4')
            assert len(actual)==1024 and np.isfinite(actual).all()
            target=y if mode else np.frombuffer((ROOT/'kivi-two-bit-dot-native'/f'{tag}-t{t}-conventional-cpu.f32').read_bytes(),dtype='<f4')
            err=actual.astype('f8')-target.astype('f8')
            maxabs=float(abs(err).max());rel=float(np.linalg.norm(err)/np.linalg.norm(target))
            assert maxabs<=.005 and rel<=.005,(tag,t,mode,maxabs,rel)
            sse=float(np.square(actual.astype('f8')-teacher.astype('f8')).sum())
            if mode==1:assert abs(sse-receipt['sse'])<.00001,(tag,t,sse,receipt['sse'])
            answer.append({'t':t,'mode':mode,'actual_sha256':SHA(actual.tobytes()),'reference_sha256':SHA(target.tobytes()),'max_abs':maxabs,'relative_l2':rel,'teacher_sse':sse,'donor_teacher_sse':receipt['sse'] if mode else None})
    return answer
if __name__=='__main__':
    if sys.argv[1]=='prepare':
        for n in range(4):prepare(f'held-{n}')
    else:print(json.dumps(run(sys.argv[1],len(sys.argv)>2)))
