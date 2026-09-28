"""Independent donor-byte/source/code/moment replay and complete original-O CPU observer."""
import hashlib
import json
import math
import sys
from pathlib import Path
import numpy as np
import torch

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
CONTEXT=ROOT/'contextual-value-feedback'
BASE=ROOT/'kivi-two-bit-causal'
ARRIVAL=ROOT/'kivi-value-intern'
SNAP=ROOT/'kivi-two-bit-dot-native'
sys.path.insert(0,str(CONTEXT))
from custody import source,sha
from importlib.util import spec_from_file_location,module_from_spec
spec=spec_from_file_location('contextual_reader',CONTEXT/'replay.py')
contextual_reader=module_from_spec(spec);spec.loader.exec_module(contextual_reader)
decode=contextual_reader.decode
expect_k=contextual_reader.expect_k
expect_v=contextual_reader.expect_v
from weights import load as load_o

def fp(words):return (np.asarray(words,dtype='<u4')<<16).view('<f4')
def checked(path,hash_value):
    data=path.read_bytes();assert sha(data)==hash_value,(path,hash_value)
    return data
def split_events(raw):
    events=[];i=0
    while i<len(raw):
        kind=raw[i:i+1];assert kind in (b'K',b'V')
        size=1536 if kind==b'K' else 48
        t=int.from_bytes(raw[i+1:i+3],'little');blob=raw[i+3:i+3+size]
        assert len(blob)==size
        events.append((kind,t,blob));i+=3+size
    assert i==len(raw)
    return events

def held_source(w):
    name=f'held-{w}'
    audit=json.loads((ARRIVAL/f'{name}-manifest.json').read_text())
    raw=checked(ARRIVAL/f'{name}-events.bin',audit['events_sha256'])
    k=np.empty((256,8,128),dtype='<u2');v=np.empty_like(k)
    for t in range(1,257):
        row=raw[(t-1)*4098:t*4098];assert int.from_bytes(row[:2],'little')==t
        k[t-1]=np.frombuffer(row[2:2050],dtype='<u2').reshape(8,128)
        v[t-1]=np.frombuffer(row[2050:],dtype='<u2').reshape(8,128)
    donor_path=BASE/f'{name}-manifest.json';donor_bytes=donor_path.read_bytes()
    assert audit['baseline_manifest_sha256']==sha(donor_bytes)
    return {'k':k,'v':v},json.loads(donor_bytes),sha(donor_bytes),sha(raw)

def observe(q,teacher,states,moments,o):
    heads=[decode(s,2) for s in states]
    assert all(k.shape==v.shape==(len(states[0][2])+32*len(states[0][0]),128) for k,v in heads)
    t=heads[0][0].shape[0]
    ks=torch.from_numpy(np.ascontiguousarray(np.stack([x[0] for x in heads])))
    vs=torch.from_numpy(np.ascontiguousarray(np.stack([x[1] for x in heads])))
    qt=torch.from_numpy(np.ascontiguousarray(q))
    a=torch.bmm(qt[:,None,:],ks[torch.arange(16)//2].transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1)
    mixed=torch.bmm(a[:,None,:],vs[torch.arange(16)//2]).squeeze(1)
    normal=(mixed.reshape(2048)@o.T).numpy().copy()
    n=max(0,t-33)
    assert all(len(s[1])==n for s in states)
    corrected=mixed.clone()
    mass=[]
    if n:
        for head in range(16):
            p=np.float32(0)
            for weight in a[head,:n].numpy():p=np.float32(p+np.float32(weight))
            alpha=np.float32(p/np.float32(n));mass.append(float(p))
            moment=torch.from_numpy(moments[head//2].copy())
            corrected[head]=torch.add(corrected[head],torch.mul(moment,alpha))
    else:mass=[0.0]*16
    out=(corrected.reshape(2048)@o.T).numpy().copy()
    baseline=normal.astype('f8')-teacher.astype('f8');delta=out.astype('f8')-normal.astype('f8')
    ordinary=float(np.dot(baseline,baseline));cross=float(np.dot(baseline,delta));delta_sq=float(np.dot(delta,delta))
    sse=float(np.square(out.astype('f8')-teacher.astype('f8')).sum())
    assert abs(sse-(ordinary+2*cross+delta_sq))<1e-8
    return {'sse':sse,'ordinary_sse':ordinary,'ordinary_error_dot_delta':cross,'delta_sq':delta_sq,'teacher_sq':float(np.square(teacher.astype('f8')).sum()),'ordinary_output_sha256':sha(normal.astype('<f4').tobytes()),'output_sha256':sha(out.astype('<f4').tobytes()),'aged_mass':mass,'aged_tokens':n}

def run(panel,w):
    torch.set_num_threads(1)
    name=f'{panel}-{w}';receipt=json.loads((HERE/f'{name}-manifest.json').read_text())
    if panel=='held':
        arrays,donor,donor_sha,source_sha=held_source(w)
        snaps=json.loads((SNAP/'snapshots.json').read_text())
        snapshot={s['tag']:s for s in snaps['states'] if s['window']==w}
        o=torch.from_numpy(fp(np.frombuffer(checked(SNAP/'original-o.bf16',snaps['original_o_sha256']),dtype='<u2')).copy().reshape(1024,2048))
        query_times=(128,256)
    else:
        arrays,src=source(panel,w)
        source_sha=src['source_file_sha256'];donor_path=CONTEXT/f'{name}-manifest.json'
        donor_bytes=donor_path.read_bytes();donor=json.loads(donor_bytes);donor_sha=sha(donor_bytes)
        assert donor['source_sha256']==source_sha
        o=load_o(src['original_o_bf16_sha256'])
        existing=json.loads((CONTEXT/f'{name}-result.json').read_text())
        assert existing['source_sha256']==source_sha and existing['query_count']==256
        query_times=range(1,257)
    assert receipt['source_sha256']==source_sha and receipt['donor_manifest_sha256']==donor_sha
    assert receipt['peak_bytes']==308864 and receipt['final_bytes']==253952
    caches={t:[None]*8 for t in query_times};moments={t:[None]*8 for t in query_times};finals=[]
    for h,meta in enumerate(receipt['heads']):
        owner=donor['groups'][f'kv{h}'] if panel=='held' else donor['arms']['original']['heads'][h]
        prefix=owner['prefixes'] if panel=='held' else owner['prefix']
        log_path=(BASE/f'{name}-head{h}-events.bin') if panel=='held' else CONTEXT/f'{name}-original-h{h}-events.bin'
        events=split_events(checked(log_path,owner['events_sha256']))
        assert meta['donor_log_sha256']==owner['events_sha256'] and meta['value_flushes']==224
        kq=[];vq=[];kr=[];vr=[];s=np.zeros(128,dtype='<f4');ix=0;peak=0
        for t in range(1,257):
            kr.append(arrays['k'][t-1,h].tobytes());vr.append(arrays['v'][t-1,h].tobytes())
            pre=b''.join(kq+vq+kr+vr);before=s.tobytes();r=meta['trace'][t-1]
            assert sha(before)==r['before']
            old=prefix[t-1]['before_query_flush'] if panel=='held' else prefix[t-1]
            assert (sha(pre),len(pre))==((old['sha256'],old['bytes']) if panel=='held' else (old['pre_sha256'],old['pre_bytes']))
            peak=max(peak,len(pre))
            if t in query_times:
                caches[t][h]=(kq.copy(),vq.copy(),kr.copy(),vr.copy());moments[t][h]=s.copy()
            if t in (128,256):
                image=receipt['snapshots'][str(t)][h]
                assert checked(HERE/image['file'],image['sha256'])==before and image['bytes']==512
                if panel=='held':assert sha(pre)==snapshot[f'{name}-t{t}']['state_sha256'][h]
                else:assert checked(CONTEXT/f'{name}-original-t{t}-h{h}.bin',old['pre_sha256'])==pre
            if len(kr)==32:
                kind,at,blob=events[ix];ix+=1;assert kind==b'K' and at==t
                expect_k(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128),blob)
                kq.append(blob);kr=[]
            if len(vr)==33:
                kind,at,blob=events[ix];ix+=1;assert kind==b'V' and at==t
                raw=vr.pop(0);src=np.frombuffer(raw,dtype='<u2')
                assert np.array_equal(src,arrays['v'][t-33,h])
                expect_v(src,blob,2,None)
                code=np.frombuffer(blob[:32],dtype='u1')
                digits=np.column_stack((code&3,(code>>2)&3,(code>>4)&3,code>>6)).reshape(4,32).astype('<f4')
                fields=np.frombuffer(blob[32:],dtype='<f2').astype('<f4').reshape(4,2)
                decoded=np.empty((4,32),dtype='<f4')
                for group in range(4):
                    for col in range(32):
                        product=np.float32(fields[group,1]*digits[group,col])
                        decoded[group,col]=np.float32(fields[group,0]+product)
                error=np.subtract(fp(src),decoded.reshape(128),dtype='<f4')
                for col in range(128):s[col]=np.float32(s[col]+error[col])
                vq.append(blob)
            post=b''.join(kq+vq+kr+vr)
            old_post=prefix[t-1]['after_query_flush'] if panel=='held' else prefix[t-1]
            assert (sha(post),len(post))==((old_post['sha256'],old_post['bytes']) if panel=='held' else (old_post['post_sha256'],old_post['post_bytes']))
            assert sha(s.tobytes())==r['after']
        assert ix==len(events)==232 and peak==owner['peak_bytes']
        final_path=(BASE/f'{name}-head{h}-final.bin') if panel=='held' else CONTEXT/f'{name}-original-h{h}-final.bin'
        assert checked(final_path,owner['final_sha256'])==post
        assert checked(HERE/meta['final']['file'],meta['final']['sha256'])==s.tobytes()
        finals.append(len(post))
    assert sum(finals)+4096==receipt['final_bytes']
    rows=[]
    for t in query_times:
        if panel=='held':
            tag=f'{name}-t{t}';snap=snapshot[tag]
            q=np.frombuffer(checked(SNAP/f'{tag}-q.f32',snap['query_sha256']),dtype='<f4').copy().reshape(16,128)
            teacher=np.frombuffer(checked(SNAP/f'{tag}-teacher.f32',snap['teacher_sha256']),dtype='<f4').copy()
        else:q=arrays['q'][:,t-1,:];teacher=arrays['teacher'][t-1]
        row=observe(q,teacher,caches[t],moments[t],o);row['t']=t
        if panel!='held':
            prior=existing['arms']['original'][t-1]
            assert row['ordinary_output_sha256']==prior['output_sha256']
            assert abs(row['ordinary_sse']-prior['sse'])<1e-7
        else:
            assert row['teacher_sq']>0
        rows.append(row)
    result={'panel':panel,'window':w,'manifest_sha256':sha((HERE/f'{name}-manifest.json').read_bytes()),'source_sha256':source_sha,'query_count':len(rows),'rows':rows}
    (HERE/f'{name}-result.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    print(json.dumps({'name':name,'queries':len(rows),'moment_sse':sum(r['sse'] for r in rows),'ordinary_sse':sum(r['ordinary_sse'] for r in rows)}))

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
