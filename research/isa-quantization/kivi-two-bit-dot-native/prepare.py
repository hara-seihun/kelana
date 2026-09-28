"""Freeze eight genuine t128/t256 held causal KIVI2 states, Q, O and CPU targets."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
BASE=ROOT/'kivi-two-bit-causal'
sys.path.insert(0,str(ROOT/'kivi-two-bit-dot-query'))
import map as byte_map
reader=byte_map.original_reader
from source import arrays,FIX_SHA


def sha(data):return hashlib.sha256(data).hexdigest()


def run():
    torch.set_num_threads(1)
    all_snapshots=[];o_sha=None
    for window in range(4):
        src=arrays('held',window)
        original_o=src['o'].to(torch.bfloat16).contiguous().view(torch.uint16).numpy().astype('<u2').tobytes()
        assert len(original_o)==1024*2048*2
        if o_sha is None:
            (HERE/'original-o.bf16').write_bytes(original_o);o_sha=sha(original_o)
        else:assert sha(original_o)==o_sha
        keys=src['krot'].permute(1,0,2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
        values=src['value'].reshape(256,8,128)
        manifest=json.loads((BASE/f'held-{window}-manifest.json').read_text())
        logs=[];offsets=[0]*8
        for h in range(8):
            info=manifest['groups'][f'kv{h}']
            log=(BASE/f'held-{window}-head{h}-events.bin').read_bytes()
            assert sha(log)==info['events_sha256'];logs.append(log)
        kq=[[] for _ in range(8)];vq=[[] for _ in range(8)];kr=[[] for _ in range(8)];vr=[[] for _ in range(8)]
        for t in range(1,257):
            states=[]
            for h in range(8):
                kr[h].append(keys[t-1,h].astype('<u2').tobytes())
                vr[h].append(values[t-1,h].astype('<u2').tobytes())
                state=reader.state(kq[h],vq[h],kr[h],vr[h])
                reader.verify(state,manifest['groups'][f'kv{h}']['prefixes'][t-1]['before_query_flush'],kq[h],vq[h],kr[h],vr[h])
                states.append(state)
            if t in (128,256):
                q=src['qrot'][:,t-1].numpy().astype('<f4')
                fresh=[];control=[];vlist=[]
                for h in range(8):
                    score,*_=byte_map.scores_from_codes(kq[h],kr[h],q[2*h:2*h+2])
                    k,v=reader.decode(states[h],len(kq[h]),len(vq[h]),len(kr[h]),len(vr[h]))
                    fresh.append(torch.from_numpy(score.copy()))
                    control.append(torch.from_numpy(k.copy()))
                    vlist.append(torch.from_numpy(v.copy()))
                changed=torch.cat(fresh)
                k=torch.stack(control).repeat_interleave(2,dim=0)
                v=torch.stack(vlist).repeat_interleave(2,dim=0)
                conventional=torch.bmm(src['qrot'][:,t-1,None,:],k.transpose(1,2)).squeeze(1)/np.sqrt(np.float32(128))
                outputs=[]
                for logits in (conventional,changed):
                    mixed=torch.bmm(logits.softmax(-1)[:,None,:],v).reshape(2048)
                    outputs.append((mixed@src['o'].T).numpy().astype('<f4').copy())
                tag=f'held-{window}-t{t}'
                (HERE/f'{tag}-q.f32').write_bytes(q.tobytes())
                for name,out in zip(('conventional','byte'),outputs):
                    (HERE/f'{tag}-{name}-cpu.f32').write_bytes(out.tobytes())
                teacher=src['teacher'][t-1].numpy().astype('<f4')
                (HERE/f'{tag}-teacher.f32').write_bytes(teacher.tobytes())
                for h,state in enumerate(states):
                    (HERE/f'{tag}-kv{h}.bin').write_bytes(state)
                all_snapshots.append({'window':window,'position':t,'tag':tag,'query_sha256':sha(q.tobytes()),
                                      'original_o_sha256':o_sha,
                                      'state_sha256':[sha(x) for x in states],
                                      'state_bytes':[len(x) for x in states],
                                      'owner_event_sha256':[manifest['groups'][f'kv{h}']['events_sha256'] for h in range(8)],
                                      'cpu_conventional_sha256':sha(outputs[0].tobytes()),
                                      'cpu_byte_sha256':sha(outputs[1].tobytes()),
                                      'teacher_sha256':sha(teacher.tobytes()),
                                      'nchunk':len(kq[0]),'nv':len(vq[0]),'nkr':len(kr[0]),'nvr':len(vr[0]),
                                      'cpu_max_abs_byte_minus_conventional':float(np.max(np.abs(outputs[1]-outputs[0])))})
            for h in range(8):
                def event(tag,n):
                    pos=offsets[h];buf=logs[h]
                    assert buf[pos:pos+1]==tag and int.from_bytes(buf[pos+1:pos+3],'little')==t
                    blob=buf[pos+3:pos+3+n];assert len(blob)==n
                    offsets[h]+=3+n
                    return blob
                if len(kr[h])==32:
                    blob=event(b'K',1536);reader.check_event(blob,'K',keys[t-32:t,h]);kq[h].append(blob);kr[h].clear()
                if len(vr[h])>32:
                    blob=event(b'V',48);reader.check_event(blob,'V',values[t-33,h]);vq[h].append(blob);vr[h].pop(0)
                state=reader.state(kq[h],vq[h],kr[h],vr[h])
                reader.verify(state,manifest['groups'][f'kv{h}']['prefixes'][t-1]['after_query_flush'],kq[h],vq[h],kr[h],vr[h])
        assert all(offsets[h]==len(logs[h]) for h in range(8))
    assert len(all_snapshots)==8
    assert all(x['state_bytes']==[25808]*8 if x['position']==128 else x['state_bytes']==[38096]*8 for x in all_snapshots)
    (HERE/'snapshots.json').write_text(json.dumps({'fixture_sha256':FIX_SHA,'original_o_sha256':o_sha,'states':all_snapshots},indent=2)+'\n')
    print(json.dumps({'snapshots':len(all_snapshots),'o_sha256':o_sha,
                      'max_cpu_o_difference':max(x['cpu_max_abs_byte_minus_conventional'] for x in all_snapshots)}))

if __name__=='__main__':run()
