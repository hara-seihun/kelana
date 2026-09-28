"""SHA-audited donor chronology and one frozen, pending-residual-visible FP32 reader."""
import hashlib
import json
import math
import sys
from pathlib import Path
import numpy as np
import torch

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
CTX=ROOT/'contextual-value-feedback'
HELD=ROOT/'kivi-value-error-feedback'
BASE=ROOT/'kivi-two-bit-causal'
ARR=ROOT/'kivi-value-intern'
SNAP=ROOT/'kivi-two-bit-dot-native'
sys.path.insert(0,str(CTX))
import replay as contextual
from custody import source
from weights import load as load_o

def sha(b): return hashlib.sha256(b).hexdigest()
def checked(path, digest):
    data=path.read_bytes()
    assert sha(data)==digest,path
    return data

def bf16(blob):
    return (np.frombuffer(blob,dtype='<u2').astype('<u4')<<16).view('<f4')

def retain_residual(panel,w,t,residuals,expected):
    blob=b''.join(r.astype('<f4').tobytes() for r in residuals)
    assert len(blob)==4096 and [sha(blob[512*h:512*(h+1)]) for h in range(8)]==expected
    path=HERE/f'{panel}-{w}-t{t}-prequery-residual.f32'
    if path.exists():assert path.read_bytes()==blob
    else:path.write_bytes(blob)
    return {'file':path.name,'sha256':sha(blob),'layout':'KV-head-major, 8 x 128 little-endian FP32, pre-query before any t flush'}

def observe(q,teacher,ks,vs,residuals,wo,m):
    q=torch.from_numpy(np.ascontiguousarray(q,dtype='<f4'))
    k=torch.from_numpy(np.ascontiguousarray(np.repeat(np.stack(ks),2,axis=0)))
    v=torch.from_numpy(np.ascontiguousarray(np.repeat(np.stack(vs),2,axis=0)))
    p=torch.bmm(q[:,None,:],k.transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1)
    ordinary=torch.bmm(p[:,None,:],v).squeeze(1)
    residual=torch.from_numpy(np.ascontiguousarray(np.repeat(np.stack(residuals),2,axis=0)))
    correction=p[:,m-1,None]*residual if m else torch.zeros_like(ordinary)
    corrected=ordinary+correction
    raw=(ordinary.reshape(2048)@wo.T).numpy().copy()
    out=(corrected.reshape(2048)@wo.T).numpy().copy()
    truth=np.asarray(teacher,dtype='f8')
    error=raw.astype('f8')-truth
    delta=out.astype('f8')-raw.astype('f8')
    base=float(np.square(error).sum());new=float(np.square(out.astype('f8')-truth).sum())
    linear=float(2*np.dot(error,delta));quadratic=float(np.square(delta).sum())
    assert abs(new-(base+linear+quadratic))<1e-8
    return {'ordinary_sse':base,'sse':new,'cross':linear,'correction_sq':quadratic,
            'output_sha256':sha(out.astype('<f4').tobytes()),'ordinary_output_sha256':sha(raw.astype('<f4').tobytes()),
            'correction_mixed_sq':float(torch.square(correction).sum().item())}

def contextual_window(panel,w):
    arrays,src=source(panel,w)
    manifest_bytes=(CTX/f'{panel}-{w}-manifest.json').read_bytes();manifest=json.loads(manifest_bytes)
    assert manifest['source_sha256']==src['source_file_sha256']
    owner=json.loads((CTX/'custody.json').read_text())
    assert next(r for r in owner['records'] if r['panel']==panel and r['window']==w)==manifest['source_v_custody']
    old_bytes=(CTX/f'{panel}-{w}-result.json').read_bytes();old=json.loads(old_bytes)
    assert old['source_sha256']==src['source_file_sha256'] and old['query_count']==256
    heads=[];residuals=[];events=[];indices=[]
    for h,info in enumerate(manifest['arms']['feedback']['heads']):
        assert info['h']==h and info['v_flushes']==224
        blob=checked(CTX/f'{panel}-{w}-feedback-h{h}-events.bin',info['events_sha256'])
        parsed=[];i=0
        while i<len(blob):
            kind=chr(blob[i]);t=int.from_bytes(blob[i+1:i+3],'little');size=1536 if kind=='K' else 48
            assert kind in ('K','V') and len(blob[i+3:i+3+size])==size
            parsed.append((kind,t,blob[i+3:i+3+size]));i+=3+size
        assert i==len(blob) and len(parsed)==232
        heads.append(([],[],[],[]));residuals.append(np.zeros(128,dtype='<f4'));events.append(parsed);indices.append(0)
    wo=load_o(src['original_o_bf16_sha256'])
    torch.set_num_threads(1)
    rows=[]
    for t in range(1,257):
        ks=[];vs=[];pre_hash=[];res_hash=[]
        m=max(0,t-33)
        for h,info in enumerate(manifest['arms']['feedback']['heads']):
            kq,vq,kr,vr=heads[h]
            kr.append(arrays['k'][t-1,h].astype('<u2').tobytes());vr.append(arrays['v'][t-1,h].astype('<u2').tobytes())
            p=info['prefix'][t-1]
            image=b''.join(kq+vq+kr+vr);digest=sha(image);rd=sha(residuals[h].tobytes())
            assert (digest,len(image),rd)==(p['pre_sha256'],p['pre_bytes'],p['residual_before_sha256'])
            assert (len(kq),len(vq),len(kr),len(vr))==(p['k_chunks'],p['v_tokens'],p['recent_k'],p['recent_v'])
            assert len(vq)==m
            if 'image_file' in p:assert checked(CTX/p['image_file'],digest)==image
            k,v=contextual.decode((kq,vq,kr,vr),2)
            assert k.shape==v.shape==(t,128)
            ks.append(k);vs.append(v);pre_hash.append(digest);res_hash.append(rd)
        o=observe(arrays['q'][:,t-1,:],arrays['teacher'][t-1],ks,vs,residuals,wo,m)
        original=old['arms']['feedback'][t-1]
        assert o['ordinary_output_sha256']==original['output_sha256'] and abs(o['ordinary_sse']-original['sse'])<1e-9
        saved=retain_residual(panel,w,t,residuals,res_hash) if t in (128,256) else None
        rows.append({'t':t,'m':m,'pre_cache_sha256':pre_hash,'pre_residual_sha256':res_hash,
                     **({'retained_residual':saved} if saved else {}),**o})
        for h,info in enumerate(manifest['arms']['feedback']['heads']):
            kq,vq,kr,vr=heads[h];idx=indices[h]
            if len(kr)==32:
                kind,when,blob=events[h][idx];idx+=1
                assert (kind,when)==('K',t)
                contextual.expect_k(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128),blob)
                kq.append(blob);kr.clear()
            if len(vr)==33:
                kind,when,blob=events[h][idx];idx+=1
                assert (kind,when)==('V',t)
                residuals[h]=contextual.expect_v(np.frombuffer(vr.pop(0),dtype='<u2'),blob,2,residuals[h]);vq.append(blob)
            indices[h]=idx
            post=b''.join(kq+vq+kr+vr)
            p=info['prefix'][t-1]
            assert (sha(post),len(post),sha(residuals[h].tobytes()))==(p['post_sha256'],p['post_bytes'],p['residual_after_sha256'])
    for h,info in enumerate(manifest['arms']['feedback']['heads']):
        assert indices[h]==len(events[h]) and sha(residuals[h].tobytes())==info['residual_final_sha256']
        assert checked(CTX/f'{panel}-{w}-feedback-h{h}-final.bin',info['final_sha256'])==b''.join(heads[h][0]+heads[h][1]+heads[h][2]+heads[h][3])
    result={'panel':panel,'window':w,'donor_manifest_sha256':sha(manifest_bytes),'source_sha256':src['source_file_sha256'],
            'original_o_sha256':src['original_o_bf16_sha256'],'unchanged_result_sha256':sha(old_bytes),'rows':rows}
    (HERE/f'{panel}-{w}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(panel,w,sum(r['sse'] for r in rows),sum(r['ordinary_sse'] for r in rows),flush=True)

def held_window(w):
    name=f'held-{w}';manifest_bytes=(HELD/f'{name}-manifest.json').read_bytes();manifest=json.loads(manifest_bytes)
    old_bytes=(HELD/f'{name}-result.json').read_bytes();old=json.loads(old_bytes)
    base_bytes=checked(BASE/f'{name}-manifest.json',manifest['baseline_manifest_sha256']);base=json.loads(base_bytes)
    arr_bytes=checked(ARR/f'{name}-manifest.json',manifest['arrival_manifest_sha256']);arrival=json.loads(arr_bytes)
    assert arrival['baseline_manifest_sha256']==sha(base_bytes)
    arrival_blob=checked(ARR/f'{name}-events.bin',manifest['arrival_sha256'])
    assert arrival['events_sha256']==manifest['arrival_sha256']
    snapshots=json.loads((SNAP/'snapshots.json').read_text())
    assert snapshots['fixture_sha256']==arrival['source_fixture_sha256']==base['fixture_sha256']
    wo=torch.from_numpy(bf16(checked(SNAP/'original-o.bf16',snapshots['original_o_sha256'])).copy().reshape(1024,2048))
    torch.set_num_threads(1)
    heads=[];residuals=[];events=[];donors=[];indices=[]
    for h,info in enumerate(manifest['arms']['feedback']['heads']):
        assert info['head']==h and info['original_event_sha256']==base['groups'][f'kv{h}']['events_sha256']
        donor_blob=checked(BASE/f'{name}-head{h}-events.bin',info['original_event_sha256'])
        originals={'K':[],'V':[]};i=0
        while i<len(donor_blob):
            kind=chr(donor_blob[i]);t=int.from_bytes(donor_blob[i+1:i+3],'little');size=1536 if kind=='K' else 48
            assert (kind,t)==(('K',32*(len(originals['K'])+1)) if kind=='K' else ('V',33+len(originals['V'])))
            originals[kind].append(donor_blob[i+3:i+3+size]);i+=size+3
        assert len(originals['K'])==8 and len(originals['V'])==224
        checked(BASE/f'{name}-head{h}-final.bin',base['groups'][f'kv{h}']['final_sha256'])
        log=checked(HELD/f'{name}-feedback-head{h}-events.bin',info['events_sha256'])
        parsed=[];i=0
        while i<len(log):
            kind=chr(log[i]);t=int.from_bytes(log[i+1:i+3],'little');size=1536 if kind=='K' else 48
            assert kind in ('K','V') and len(log[i+3:i+3+size])==size
            parsed.append((kind,t,log[i+3:i+3+size]));i+=size+3
        assert i==len(log)==sum(3+(1536 if k=='K' else 48) for k,_,_ in parsed)
        heads.append(([],[],[],[]));residuals.append(np.zeros(128,dtype='<f4'));events.append(parsed);donors.append(originals);indices.append(0)
    rows=[]
    for t in range(1,257):
        chunk=arrival_blob[(t-1)*4098:t*4098];assert len(chunk)==4098 and int.from_bytes(chunk[:2],'little')==t
        ks=[];vs=[];pre_hash=[];res_hash=[];baseline_hash=[];m=max(0,t-33)
        for h,info in enumerate(manifest['arms']['feedback']['heads']):
            kq,vq,kr,vr=heads[h]
            kr.append(chunk[2+256*h:2+256*(h+1)]);vr.append(chunk[2050+256*h:2050+256*(h+1)])
            image=b''.join(kq+vq+kr+vr);p=info['prefixes'][t-1];digest=sha(image);rd=sha(residuals[h].tobytes())
            assert (digest,len(image),rd)==(p['before'],p['before_bytes'],p['residual_before'])
            original=b''.join(donors[h]['K'][:(t-1)//32]+donors[h]['V'][:m]+kr+vr)
            original_sha=sha(original)
            assert original_sha==base['groups'][f'kv{h}']['prefixes'][t-1]['before_query_flush']['sha256']
            baseline_hash.append(original_sha)
            assert len(vq)==m
            if t in (128,256):
                assert checked(HELD/f'{name}-feedback-t{t}-kv{h}.bin',digest)==image
                ks.append(contextual.unpack_records(kq,2,True))
                ks[-1]=np.concatenate((ks[-1],bf16(b''.join(kr)).reshape(-1,128)))
                vs.append(contextual.unpack_records(vq,2,False))
                vs[-1]=np.concatenate((vs[-1],bf16(b''.join(vr)).reshape(-1,128)))
                assert ks[-1].shape==vs[-1].shape==(t,128)
            pre_hash.append(digest);res_hash.append(rd)
        if t in (128,256):
            tag=f'{name}-t{t}';snap=next(x for x in snapshots['states'] if x['tag']==tag)
            assert baseline_hash==snap['state_sha256']
            q=np.frombuffer(checked(SNAP/f'{tag}-q.f32',snap['query_sha256']),dtype='<f4').copy().reshape(16,128)
            truth=np.frombuffer(checked(SNAP/f'{tag}-teacher.f32',snap['teacher_sha256']),dtype='<f4')
            row=observe(q,truth,ks,vs,residuals,wo,m)
            original=next(x for x in old['arms']['feedback']['retained'] if x['t']==t)
            assert row['ordinary_output_sha256']==original['output_sha256'] and abs(row['ordinary_sse']-original['sse'])<1e-9
            saved=retain_residual('held',w,t,residuals,res_hash)
            rows.append({'t':t,'m':m,'pre_cache_sha256':pre_hash,'pre_residual_sha256':res_hash,
                         'baseline_cache_sha256':baseline_hash,'retained_residual':saved,**row})
        for h,info in enumerate(manifest['arms']['feedback']['heads']):
            kq,vq,kr,vr=heads[h];idx=indices[h]
            if len(kr)==32:
                kind,when,blob=events[h][idx];idx+=1
                assert (kind,when,blob)==('K',t,donors[h]['K'][len(kq)])
                kq.append(blob);kr.clear()
            if len(vr)==33:
                kind,when,blob=events[h][idx];idx+=1
                assert (kind,when)==('V',t)
                source=bf16(vr.pop(0))
                # Source extrema determine the stored fields; decoded emitted digits determine recurrence.
                residuals[h]=contextual.expect_v((source.view('<u4')>>16).astype('<u2'),blob,2,residuals[h])
                assert blob[32:]==donors[h]['V'][len(vq)][32:]
                vq.append(blob)
            indices[h]=idx;p=info['prefixes'][t-1]
            after=b''.join(kq+vq+kr+vr)
            assert (sha(after),len(after),sha(residuals[h].tobytes()))==(p['after'],p['after_bytes'],p['residual_after'])
            original=b''.join(donors[h]['K'][:t//32]+donors[h]['V'][:max(0,t-32)]+kr+vr)
            assert sha(original)==base['groups'][f'kv{h}']['prefixes'][t-1]['after_query_flush']['sha256']
    for h,info in enumerate(manifest['arms']['feedback']['heads']):
        assert indices[h]==len(events[h]) and sha(residuals[h].tobytes())==info['residual_final']
        assert checked(HELD/f'{name}-feedback-head{h}-final.bin',info['final_sha256'])==b''.join(heads[h][0]+heads[h][1]+heads[h][2]+heads[h][3])
    result={'window':w,'donor_manifest_sha256':sha(manifest_bytes),'arrival_sha256':manifest['arrival_sha256'],
            'snapshots_sha256':sha((SNAP/'snapshots.json').read_bytes()),'unchanged_result_sha256':sha(old_bytes),'rows':rows}
    (HERE/f'{name}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(name,sum(r['sse'] for r in rows),flush=True)

if __name__=='__main__':
    if sys.argv[1]=='held':held_window(int(sys.argv[2]))
    else:contextual_window(sys.argv[1],int(sys.argv[2]))
