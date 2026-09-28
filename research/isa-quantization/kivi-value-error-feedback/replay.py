"""Independent chronological source/field/digit/state verification and retained full-O replay."""
import hashlib
import json
import math
from pathlib import Path
import sys
import numpy as np
import torch
from importlib.util import spec_from_file_location, module_from_spec

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
BASE=ROOT/'kivi-two-bit-causal'
SOURCE=ROOT/'kivi-value-intern'
SNAP=ROOT/'kivi-two-bit-dot-native'
EXCHANGE=ROOT/'kivi-kv-rate-exchange'
spec=spec_from_file_location('exchange_controls',EXCHANGE/'controls.py')
control_owner=module_from_spec(spec);spec.loader.exec_module(control_owner)


def sha(b): return hashlib.sha256(b).hexdigest()
def checked(p,d):
    b=p.read_bytes();assert sha(b)==d,p
    return b
def bf16(b):return (np.asarray(b,dtype='<u2').astype('<u4')<<16).view('<f4')
def unpack(payload):
    a=np.frombuffer(payload[:32],dtype='u1')
    return np.column_stack((a&3,a>>2&3,a>>4&3,a>>6)).reshape(128)
def image(kq,vq,kr,vr):return b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)

def donors(w,h,info):
    name=f'held-{w}'
    log=checked(BASE/f'{name}-head{h}-events.bin',info['events_sha256'])
    k=[];v=[];i=0
    while i<len(log):
        kind=log[i:i+1];n=1536 if kind==b'K' else 48
        assert kind in (b'K',b'V')
        at=int.from_bytes(log[i+1:i+3],'little');blob=log[i+3:i+3+n];assert len(blob)==n
        if kind==b'K': assert at==32*(len(k)+1);k.append(blob)
        else:assert at==33+len(v);v.append(blob)
        i+=n+3
    assert len(k)==8 and len(v)==224
    checked(BASE/f'{name}-head{h}-final.bin',info['final_sha256'])
    return k,v

def independent_value(source,previous,old):
    x=bf16(np.frombuffer(source,dtype='<u2'))
    target=np.asarray(x+previous,dtype='<f4')
    initial=np.zeros(128,dtype='u1');candidate=np.zeros(128,dtype='u1');decoded=np.empty(128,dtype='<f4')
    stored=np.frombuffer(old,dtype='<f2',count=8,offset=32).reshape(4,2)
    for g in range(4):
        sl=slice(32*g,32*(g+1))
        low=np.min(x[sl]);step=(np.max(x[sl])-low)/np.float32(3)
        assert stored[g,0].tobytes()==np.float16(low).tobytes()
        assert stored[g,1].tobytes()==np.float16(step).tobytes()
        if step>0:
            initial[sl]=np.clip(np.rint((x[sl]-low)/step),0,3).astype('u1')
            candidate[sl]=np.clip(np.rint((target[sl]-low)/step),0,3).astype('u1')
        decoded[sl]=np.float32(stored[g,0])+np.float32(stored[g,1])*candidate[sl]
    assert np.array_equal(initial,unpack(old))
    out=bytearray(32)
    for i in range(32):
        j=i*4;out[i]=int(candidate[j])|(int(candidate[j+1])<<2)|(int(candidate[j+2])<<4)|(int(candidate[j+3])<<6)
    return bytes(out)+old[32:],np.asarray(target-decoded,dtype='<f4')

def expand(chunks,recent,kind):
    rows=[]
    for blob in chunks:
        if kind=='K':
            p=np.frombuffer(blob,dtype='u1',count=1024)
            c=np.column_stack((p&3,p>>2&3,p>>4&3,p>>6)).reshape(32,128)
            fields=np.frombuffer(blob,dtype='<f2',offset=1024).reshape(128,2).astype('<f4')
            rows.append(fields[:,0][None,:]+fields[:,1][None,:]*c)
        else:
            c=unpack(blob).reshape(4,32)
            fields=np.frombuffer(blob,dtype='<f2',offset=32).reshape(4,2).astype('<f4')
            rows.append((fields[:,0,None]+fields[:,1,None]*c).reshape(1,128))
    rows.append(bf16(np.frombuffer(b''.join(recent),dtype='<u2').reshape(-1,128)))
    return np.concatenate(rows,axis=0).astype('<f4')

def output(w,t,heads,snap,o):
    tag=f'held-{w}-t{t}';record=snap[tag]
    q=torch.from_numpy(np.frombuffer(checked(SNAP/f'{tag}-q.f32',record['query_sha256']),dtype='<f4').copy().reshape(16,128))
    truth=np.frombuffer(checked(SNAP/f'{tag}-teacher.f32',record['teacher_sha256']),dtype='<f4').astype('f8')
    k=torch.from_numpy(np.repeat(np.stack([x[0] for x in heads]),2,axis=0).copy())
    v=torch.from_numpy(np.repeat(np.stack([x[1] for x in heads]),2,axis=0).copy())
    a=torch.bmm(q[:,None,:],k.transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1)
    y=(torch.bmm(a[:,None,:],v).reshape(2048)@o.T).numpy().astype('f8')
    return {'t':t,'sse':float(np.square(y-truth).sum()),'teacher_sq':float(np.square(truth).sum()),'output_sha256':sha(y.astype('<f4').tobytes())}

def run(w):
    torch.set_num_threads(1)
    name=f'held-{w}'
    receipt=json.loads((HERE/f'{name}-manifest.json').read_text())
    arrival_audit=(SOURCE/f'{name}-manifest.json').read_bytes()
    assert sha(arrival_audit)==receipt['arrival_manifest_sha256']
    arrival=json.loads(arrival_audit)
    raw=checked(SOURCE/f'{name}-events.bin',receipt['arrival_sha256'])
    assert receipt['arrival_sha256']==arrival['events_sha256']
    baseline_bytes=(BASE/f'{name}-manifest.json').read_bytes()
    assert sha(baseline_bytes)==arrival['baseline_manifest_sha256']==receipt['baseline_manifest_sha256']
    baseline=json.loads(baseline_bytes)
    snap_record=json.loads((SNAP/'snapshots.json').read_text())
    assert snap_record['fixture_sha256']==arrival['source_fixture_sha256']==baseline['fixture_sha256']
    snapshots={s['tag']:s for s in snap_record['states'] if s['window']==w}
    o=torch.from_numpy(bf16(np.frombuffer(checked(SNAP/'original-o.bf16',snap_record['original_o_sha256']),dtype='<u2')).copy().reshape(1024,2048))
    controls=json.loads(control_owner.read_results_bytes())
    results={'window':w,'arms':{},'controls':{}}
    for t in (128,256):
        row=next(s for s in controls['per_state'] if s['window']==w and s['t']==t)
        results['controls'][str(t)]={k:row[k] for k in ('K2V2_sse','K2V4_sse','K4V4_sse','teacher_sq')}
    for arm in ('feedback','delay2'):
        config=receipt['arms'][arm];retained={128:[],256:[]};peak=0;changed=0
        for h,info in enumerate(config['heads']):
            assert info['head']==h
            old_info=baseline['groups'][f'kv{h}']
            assert info['original_event_sha256']==old_info['events_sha256']
            original_k,original_v=donors(w,h,old_info)
            log=checked(HERE/f'{name}-{arm}-head{h}-events.bin',info['events_sha256'])
            pos=0;kq=[];vq=[];kr=[];vr=[];residual=np.zeros(128,dtype='<f4');local_peak=0
            for t in range(1,257):
                chunk=raw[(t-1)*4098:t*4098];assert len(chunk)==4098 and int.from_bytes(chunk[:2],'little')==t
                kr.append(chunk[2+256*h:2+256*(h+1)]);vr.append(chunk[2050+256*h:2050+256*(h+1)])
                now=image(kq,vq,kr,vr);p=info['prefixes'][t-1]
                assert len(now)==p['before_bytes'] and sha(now)==p['before'] and sha(residual.tobytes())==p['residual_before']
                local_peak=max(local_peak,len(now))
                if t in (128,256):
                    paid=checked(HERE/f'{name}-{arm}-t{t}-kv{h}.bin',p['before'])
                    assert paid==now
                    retained[t].append((expand(kq,kr,'K'),expand(vq,vr,'V')))
                if arm=='feedback':
                    original=image(original_k[:(t-1)//32],original_v[:max(0,t-33)],kr,vr)
                    assert sha(original)==old_info['prefixes'][t-1]['before_query_flush']['sha256']
                    if t in (128,256):assert sha(original)==snapshots[f'{name}-t{t}']['state_sha256'][h]
                if len(kr)==32:
                    code=original_k[len(kq)];entry=b'K'+t.to_bytes(2,'little')+code
                    assert log[pos:pos+len(entry)]==entry
                    pos+=len(entry);kq.append(code);kr.clear()
                if len(vr)==(33 if arm=='feedback' else 35):
                    source=vr.pop(0);idx=len(vq);original=original_v[idx]
                    if arm=='feedback':
                        code,next_residual=independent_value(source,residual,original)
                        changed+=sum(a!=b for a,b in zip(code[:32],original[:32]))
                        residual=next_residual
                    else:
                        code=original
                        assert t==idx+35
                    entry=b'V'+t.to_bytes(2,'little')+code
                    assert log[pos:pos+len(entry)]==entry
                    pos+=len(entry);vq.append(code)
                after=image(kq,vq,kr,vr)
                assert len(after)==p['after_bytes'] and sha(after)==p['after'] and sha(residual.tobytes())==p['residual_after']
                if arm=='feedback':
                    original=image(original_k[:t//32],original_v[:max(0,t-32)],kr,vr)
                    assert sha(original)==old_info['prefixes'][t-1]['after_query_flush']['sha256']
            assert pos==len(log) and after==checked(HERE/f'{name}-{arm}-head{h}-final.bin',info['final_sha256'])
            assert len(after)==info['final_bytes'] and local_peak==info['peak_bytes']
            assert sha(residual.tobytes())==info['residual_final']
            assert len(vq)==info['value_events']
            peak=max(peak,local_peak)
        assert changed==sum(x['changed_code_bytes'] for x in config['heads'])
        assert 8*peak==config['peak_cache_bytes'] and sum(x['final_bytes'] for x in config['heads'])==config['final_cache_bytes']
        assert config['peak_total_bytes']==config['peak_cache_bytes']+config['residual_bytes']
        assert config['final_total_bytes']==config['final_cache_bytes']+config['residual_bytes']
        states=[output(w,t,retained[t],snapshots,o) for t in (128,256)]
        for s in states:assert abs(s['teacher_sq']-results['controls'][str(s['t'])]['teacher_sq'])<1e-6
        results['arms'][arm]={'retained':states,'peak_total_bytes':config['peak_total_bytes'],'final_total_bytes':config['final_total_bytes'],'changed_code_bytes':changed}
    (HERE/f'{name}-result.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps({'window':w,'sse':{arm:sum(s['sse'] for s in x['retained']) for arm,x in results['arms'].items()}}))

if __name__=='__main__':run(int(sys.argv[1]))
