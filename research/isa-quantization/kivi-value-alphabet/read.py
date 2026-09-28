"""Independent source/event/field/four-way/cache/full-O audit and finite CPU reader."""
import hashlib,io,json,math,sys
from pathlib import Path
import numpy as np
import torch
from fit import HERE,ROOT,BASE,CTX,SNAP,sha,checked,bf16,donor,original_o
from produce import input_source

def unpack(blob):
    a=np.frombuffer(blob[:32],dtype='u1')
    return np.column_stack((a&3,(a>>2)&3,(a>>4)&3,(a>>6)&3)).reshape(4,32)

def check_value(source,blob,old,table):
    assert len(blob)==48 and blob[32:]==old[32:]
    field=np.frombuffer(old[32:],dtype='<f2').astype('f4').reshape(4,2)
    levels=np.empty((4,4),dtype='f4')
    for g in range(4):
        for c in range(4):levels[g,c]=np.float32(field[g,0]+np.float32(field[g,1]*table[c]))
    x32=bf16(np.frombuffer(source,dtype='<u2')).reshape(4,32)
    for g in range(4):
        lo=float(x32[g].min());step=(float(x32[g].max())-lo)/3
        assert old[32+g*4:36+g*4]==np.array((lo,step),dtype='<f2').tobytes()
        original=np.zeros(32,dtype='u1') if step==0 else np.clip(np.rint((x32[g]-lo)/step),0,3).astype('u1')
        assert np.array_equal(unpack(old)[g],original)
    x=x32.astype('f8')
    desired=np.argmin(np.square(x[:,:,None]-levels[:,None,:].astype('f8')),axis=-1)
    assert np.array_equal(unpack(blob),desired)
    assert np.all(unpack(blob)[field[:,1]==0]==0)

def decode_key(blocks,recent):
    if blocks:
        raw=np.frombuffer(b''.join(blocks),dtype='u1').reshape(-1,1536)
        bits=raw[:,:1024].reshape(-1)
        code=np.column_stack((bits&3,(bits>>2)&3,(bits>>4)&3,(bits>>6)&3)).reshape(-1,32,128).astype('f4')
        f=np.frombuffer(raw[:,1024:].copy().tobytes(),dtype='<f2').astype('f4').reshape(-1,128,2)
        old=(f[:,None,:,0]+code*f[:,None,:,1]).reshape(-1,128)
    else:old=np.empty((0,128),dtype='f4')
    return np.concatenate((old,bf16(np.frombuffer(b''.join(recent),dtype='<u2').reshape(-1,128))))

def decode_value(blocks,recent,table):
    if blocks:
        raw=np.frombuffer(b''.join(blocks),dtype='u1').reshape(-1,48)
        bits=raw[:,:32].reshape(-1)
        code=np.column_stack((bits&3,(bits>>2)&3,(bits>>4)&3,(bits>>6)&3)).reshape(-1,4,32)
        f=np.frombuffer(raw[:,32:].copy().tobytes(),dtype='<f2').astype('f4').reshape(-1,4,2)
        # Explicit table lookup and FP32 multiply then FP32 add.
        old=np.add(f[:,:,0,None],np.multiply(f[:,:,1,None],table[code],dtype='f4'),dtype='f4').reshape(-1,128)
    else:old=np.empty((0,128),dtype='f4')
    return np.concatenate((old,bf16(np.frombuffer(b''.join(recent),dtype='<u2').reshape(-1,128))))

def score(q,states,o):
    key=np.stack([s[0] for s in states]);value=np.stack([s[1] for s in states]);t=len(key[0]);assert key.shape==value.shape==(8,t,128)
    k=torch.from_numpy(np.ascontiguousarray(np.repeat(key,2,axis=0)))
    v=torch.from_numpy(np.ascontiguousarray(np.repeat(value,2,axis=0)))
    query=torch.from_numpy(np.ascontiguousarray(q))
    a=torch.bmm(query[:,None,:],k.transpose(1,2)).squeeze(1).div(math.sqrt(128)).softmax(-1)
    return (torch.bmm(a[:,None,:],v).reshape(2048)@o.T).numpy().copy()

def read_log(blob):
    pos=0;out=[]
    while pos<len(blob):
        kind=blob[pos:pos+1];assert kind in (b'K',b'V')
        t=int.from_bytes(blob[pos+1:pos+3],'little');n=1536 if kind==b'K' else 48
        payload=blob[pos+3:pos+3+n];assert len(payload)==n
        out.append((kind,t,payload));pos+=n+3
    assert pos==len(blob)
    return out

def run(layer,panel,w):
    torch.set_num_threads(1)
    manifest=json.loads((HERE/f'{panel}-{w}-layer{layer}-manifest.json').read_text())
    k,v,source=input_source(layer,panel,w);assert source==manifest['source']
    fit=json.loads((HERE/f'layer{layer}-fit.json').read_text())
    table=np.frombuffer(checked(HERE/f'layer{layer}-alphabet.f32',manifest['table_sha256']),dtype='<f4')
    assert manifest['table_sha256']==fit['table_sha256']
    o_array,o_hash=original_o(layer);assert o_hash==manifest['original_o_sha256']
    o_path=(SNAP if layer==0 else CTX)/'original-o.bf16'
    o=torch.from_numpy(bf16(np.frombuffer(checked(o_path,o_hash),dtype='<u2')).copy().reshape(1024,2048))
    queries={};teacher={};source_q_hash=None;source_teacher_hash=None
    if layer==1:
        source_rec=json.loads((CTX/f'{panel}-{w}-source.json').read_text())
        with np.load(io.BytesIO(checked(CTX/f'{panel}-{w}-source.npz',source_rec['source_file_sha256']))) as f:
            q=f['q'].copy();truth=f['teacher'].copy()
        assert sha(q.tobytes())==source_rec['arrays']['q']['sha256'] and sha(truth.tobytes())==source_rec['arrays']['teacher']['sha256']
        source_q_hash=sha(q.tobytes());source_teacher_hash=sha(truth.tobytes())
        queries={t:q[:,t-1,:] for t in range(1,257)};teacher={t:truth[t-1] for t in range(1,257)}
    else:
        snap=json.loads((SNAP/'snapshots.json').read_text());assert o_hash==snap['original_o_sha256']
        for r in snap['states']:
            if r['window']!=w:continue
            t=r['position'];tag=r['tag']
            queries[t]=np.frombuffer(checked(SNAP/f'{tag}-q.f32',r['query_sha256']),dtype='<f4').reshape(16,128).copy()
            teacher[t]=np.frombuffer(checked(SNAP/f'{tag}-teacher.f32',r['teacher_sha256']),dtype='<f4').copy()
    assert len(queries)==(2 if layer==0 else 256)
    heads=[];key_log_equal=0;changed_digits=0;zero_count=0
    for h,info in enumerate(manifest['heads']):
        assert info['h']==h
        orig_k,orig_v,owner=donor(layer,panel,w,h)
        assert owner['events_sha256']==info['original_events_sha256']
        stem=f'{panel}-{w}-layer{layer}-h{h}';raw=checked(HERE/f'{stem}-events.bin',info['events_sha256']);events=read_log(raw)
        kq=[];vq=[];kr=[];vr=[];idx=0;states={};peak=0
        for t in range(1,257):
            kr.append(k[t-1,h].astype('<u2').tobytes());vr.append(v[t-1,h].astype('<u2').tobytes())
            before=b''.join(kq+vq+kr+vr);r=info['prefix'][t-1];peak=max(peak,len(before))
            assert (r['t'],r['before_sha256'],r['before_bytes'])==(t,sha(before),len(before))
            if t in queries:
                states[t]=(decode_key(kq,kr),decode_value(vq,vr,table))
                if 'image_sha256' in r:
                    assert checked(HERE/f'{panel}-{w}-layer{layer}-t{t}-h{h}.bin',r['image_sha256'])==before
                if layer==0:
                    snap_r=next(s for s in snap['states'] if s['window']==w and s['position']==t)
                    orig_before=b''.join([b for _,b in orig_k[:(t-1)//32]]+[b for _,b in orig_v[:max(0,t-33)]]+kr+vr)
                    assert sha(orig_before)==snap_r['state_sha256'][h]
            if len(kr)==32:
                kind,when,blob=events[idx];idx+=1
                assert (kind,when,blob)==(b'K',t,orig_k[len(kq)][1]);key_log_equal+=1;kq.append(blob);kr=[]
            if len(vr)==33:
                source_bytes=vr.pop(0);kind,when,blob=events[idx];idx+=1
                assert kind==b'V' and when==t==orig_v[len(vq)][0]
                old=orig_v[len(vq)][1];check_value(source_bytes,blob,old,table)
                changed_digits+=int(np.count_nonzero(unpack(blob)!=unpack(old)))
                zero_count+=int(np.count_nonzero(np.frombuffer(old[32:],dtype='<f2').reshape(4,2)[:,1]==0))*32
                vq.append(blob)
            after=b''.join(kq+vq+kr+vr)
            assert (r['after_sha256'],r['after_bytes'])==(sha(after),len(after))
        assert idx==len(events)==232 and peak==info['peak_bytes']==38096
        assert after==checked(HERE/f'{stem}-final.bin',info['final_sha256']) and len(after)==info['final_bytes']==31232
        heads.append(states)
    assert key_log_equal==64 and manifest['peak_dynamic_bytes']==304768 and manifest['final_dynamic_bytes']==249856 and manifest['shared_table_bytes']==16
    obs=[]
    for t in sorted(queries):
        out=score(queries[t],[s[t] for s in heads],o)
        tr=teacher[t].astype('f8');diff=out.astype('f8')-tr
        obs.append({'t':t,'sse':float(np.sum(diff*diff)),'teacher_sq':float(np.sum(tr*tr)),'output_sha256':sha(out.astype('<f4').tobytes())})
    result={'layer':layer,'panel':panel,'window':w,'query_count':len(obs),'source':source,'source_q_sha256':source_q_hash,'source_teacher_sha256':source_teacher_hash,'original_o_sha256':o_hash,'table_sha256':fit['table_sha256'],'verified_k_events':key_log_equal,'verified_v_events':8*224,'changed_v_digits_vs_original':changed_digits,'zero_step_coordinates':zero_count,'peak_dynamic_bytes':304768,'final_dynamic_bytes':249856,'shared_static_bytes':16,'sse':sum(x['sse'] for x in obs),'teacher_sq':sum(x['teacher_sq'] for x in obs),'queries':obs}
    (HERE/f'{panel}-{w}-layer{layer}-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'layer':layer,'panel':panel,'window':w,'sse':result['sse'],'teacher_sq':result['teacher_sq']}))
if __name__=='__main__':run(int(sys.argv[1]),sys.argv[2],int(sys.argv[3]))
