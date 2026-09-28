"""Independent source/field/grid/chronology check and retained complete-O reader."""
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from inputs import check as check_inputs

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
BASE=ROOT/'kivi-two-bit-causal'
SOURCE=ROOT/'kivi-value-intern'
PAID=ROOT/'kivi-two-bit-dot-native'


def sha(x):return hashlib.sha256(x).hexdigest()
def bf16(x):return (np.asarray(x,dtype=np.uint32)<<16).view('<f4')
def digits(x):
    b=np.frombuffer(x,dtype='u1')
    return np.column_stack((b&3,(b>>2)&3,(b>>4)&3,b>>6)).reshape(-1)

def source_check(raw,old,new,b,g):
    assert len(raw)==256 and len(old)==len(new)==48 and old[32:]==new[32:]
    src=bf16(np.frombuffer(raw,dtype='<u2'))
    field=np.frombuffer(old[32:],dtype='<f2').astype('<f4').reshape(4,2)
    a=src.reshape(4,32)
    lo=a.min(axis=1);step=(a.max(axis=1)-lo)/3
    assert np.array_equal(np.frombuffer(old[32:],dtype='<f2').reshape(4,2)[:,0],lo.astype('<f2'))
    assert np.array_equal(np.frombuffer(old[32:],dtype='<f2').reshape(4,2)[:,1],step.astype('<f2'))
    expected=np.where(step[:,None]>0,np.clip(np.rint((a-lo[:,None])/np.where(step[:,None]>0,step[:,None],1)),0,3),0)
    assert np.array_equal(digits(old[:32]).reshape(4,32),expected)
    origin=np.repeat(field[:,0],32);scale=np.repeat(field[:,1],32)
    old_codes=digits(old[:32]);current=old_codes.copy()
    residual=origin+scale*current-src
    projection=b@residual
    before=float(np.dot(projection,projection))
    gradient=g@residual
    for j in range(128):
        delta=(np.arange(4,dtype='<f4')-current[j])*scale[j]
        scores=2*delta*gradient[j]+delta*delta*g[j,j]
        chosen=int(np.argmin(scores))
        if chosen!=current[j]:
            residual[j]+=delta[chosen];gradient+=delta[chosen]*g[:,j]
            current[j]=chosen
    assert np.array_equal(current,digits(new[:32]))
    after_projection=b@(origin+scale*current-src)
    after=float(np.dot(after_projection,after_projection))
    direct=old_codes.copy(); p=projection.copy(); direct_differences=0
    for j in range(128):
        delta=(np.arange(4,dtype='<f4')-direct[j])*scale[j]
        scores=2*delta*np.dot(p,b[:,j])+delta*delta*np.dot(b[:,j],b[:,j])
        choice=int(np.argmin(scores))
        if choice!=current[j]:direct_differences+=1
        if choice!=direct[j]:p+=delta[choice]*b[:,j];direct[j]=choice
    return before,after,int(np.count_nonzero(current!=old_codes)),direct_differences


def decode(state,nk,nv,nkr,nvr):
    offset=0;k=[];v=[]
    for _ in range(nk):
        d=digits(state[offset:offset+1024]).reshape(32,128).astype('<f4');offset+=1024
        fields=np.frombuffer(state,dtype='<f2',count=256,offset=offset).astype('<f4').reshape(128,2);offset+=512
        k.append(fields[None,:,0]+d*fields[None,:,1])
    for _ in range(nv):
        d=digits(state[offset:offset+32]).reshape(4,32).astype('<f4');offset+=32
        fields=np.frombuffer(state,dtype='<f2',count=8,offset=offset).astype('<f4').reshape(4,2);offset+=16
        v.append((fields[:,0,None]+d*fields[:,1,None]).reshape(1,128))
    rk=np.frombuffer(state,dtype='<u2',count=nkr*128,offset=offset).reshape(nkr,128);offset+=nkr*256
    rv=np.frombuffer(state,dtype='<u2',count=nvr*128,offset=offset).reshape(nvr,128);offset+=nvr*256
    assert offset==len(state)
    return np.concatenate(k+[bf16(rk)]),np.concatenate(v+[bf16(rv)])


def output(states,receipt,q,o):
    mixed=np.zeros(2048,dtype='<f4')
    for h,s in enumerate(states):
        k,v=decode(s,receipt['nchunk'],receipt['nv'],receipt['nkr'],receipt['nvr'])
        for i in range(2):
            score=(k@q[2*h+i])/np.float32(math.sqrt(128))
            weight=np.exp(score-np.max(score));weight/=weight.sum()
            mixed[(2*h+i)*128:(2*h+i+1)*128]=weight@v
    return o@mixed


def run(window):
    input_receipt=check_inputs(window)
    name=f'held-{window}'
    manifest=json.loads((HERE/f'{name}-manifest.json').read_text())
    owner=json.loads((BASE/f'{name}-manifest.json').read_text())
    arrival=(SOURCE/f'{name}-events.bin').read_bytes()
    assert sha(arrival)==manifest['source_arrivals_sha256']
    obytes=(PAID/'original-o.bf16').read_bytes()
    assert sha(obytes)==manifest['original_o_sha256']
    o=bf16(np.frombuffer(obytes,dtype='<u2')).reshape(1024,2048)
    blocks=[np.ascontiguousarray(o[:,h*256:h*256+256].reshape(1024,2,128).transpose(1,0,2).reshape(2048,128)) for h in range(8)]
    matrices=[np.ascontiguousarray(b.T@b) for b in blocks]
    assert [sha(g.astype('<f4').tobytes()) for g in matrices]==manifest['gram_sha256']
    old=[(BASE/f'{name}-head{h}-events.bin').read_bytes() for h in range(8)]
    logs=[(HERE/f'{name}-head{h}-events.bin').read_bytes() for h in range(8)]
    offsets=[0]*8;kq=[[] for _ in range(8)];vq=[[] for _ in range(8)];kr=[[] for _ in range(8)];vr=[[] for _ in range(8)]
    objective=[0.,0.];changed=0;direct_differences=0;increases=[];results=[]
    paid=json.loads((PAID/'snapshots.json').read_text())
    for t in range(1,257):
        entry=arrival[(t-1)*4098:t*4098]
        assert len(entry)==4098 and int.from_bytes(entry[:2],'little')==t
        for h in range(8):
            kr[h].append(entry[2+h*256:2+(h+1)*256]);vr[h].append(entry[2050+h*256:2050+(h+1)*256])
            before=b''.join(kq[h]+vq[h]+kr[h]+vr[h])
            assert sha(before)==manifest['heads'][h]['prefixes'][t-1]['before_sha256']
        if t in (128,256):
            snap=next(x for x in paid['states'] if x['tag']==f'{name}-t{t}')
            qraw=(PAID/f'{name}-t{t}-q.f32').read_bytes()
            assert sha(qraw)==snap['query_sha256']
            q=np.frombuffer(qraw,dtype='<f4').reshape(16,128)
            current=[(HERE/f'{name}-t{t}-kv{h}.bin').read_bytes() for h in range(8)]
            controls=[(PAID/f'{name}-t{t}-kv{h}.bin').read_bytes() for h in range(8)]
            for h in range(8):
                assert current[h]==b''.join(kq[h]+vq[h]+kr[h]+vr[h])
                assert sha(controls[h])==snap['state_sha256'][h]
                assert len(current[h])==snap['state_bytes'][h]
                # The source K area is byte-identical; only V quant records differ.
                assert current[h][:snap['nchunk']*1536]==controls[h][:snap['nchunk']*1536]
            control=output(controls,snap,q,o)
            reference=np.frombuffer((PAID/f'{name}-t{t}-conventional-cpu.f32').read_bytes(),dtype='<f4')
            assert np.max(np.abs(control-reference))<0.001, np.max(np.abs(control-reference))
            candidate=output(current,snap,q,o)
            teacher=np.frombuffer((PAID/f'{name}-t{t}-teacher.f32').read_bytes(),dtype='<f4')
            assert sha(teacher.tobytes())==snap['teacher_sha256']
            results.append({'t':t,'candidate_teacher_sse':float(np.sum((candidate-teacher)**2,dtype=np.float64)),
                            'control_teacher_sse':float(np.sum((control-teacher)**2,dtype=np.float64)),
                            'candidate_control_sse':float(np.sum((candidate-control)**2,dtype=np.float64)),
                            'teacher_sq':float(np.sum(teacher**2,dtype=np.float64)),
                            'candidate_output_sha256':sha(candidate.astype('<f4').tobytes()),
                            'control_max_abs_vs_paid':float(np.max(np.abs(control-reference)))})
        for h in range(8):
            if len(kr[h])==32:
                pos=offsets[h];a=old[h][pos:pos+1539];z=logs[h][pos:pos+1539]
                assert a==z and a[:1]==b'K' and int.from_bytes(a[1:3],'little')==t
                kq[h].append(z[3:]);kr[h].clear();offsets[h]+=1539
            if len(vr[h])>32:
                pos=offsets[h];a=old[h][pos:pos+51];z=logs[h][pos:pos+51]
                assert a[:1]==z[:1]==b'V' and a[1:3]==z[1:3]==t.to_bytes(2,'little')
                try:record=source_check(vr[h].pop(0),a[3:],z[3:],blocks[h],matrices[h])
                except AssertionError as exc:raise AssertionError((window,t,h,str(exc))) from exc
                objective[0]+=record[0];objective[1]+=record[1];changed+=record[2];direct_differences+=record[3]
                if record[1]>record[0]:increases.append({'t':t,'h':h,'delta':record[1]-record[0]})
                vq[h].append(z[3:]);offsets[h]+=51
            after=b''.join(kq[h]+vq[h]+kr[h]+vr[h])
            assert sha(after)==manifest['heads'][h]['prefixes'][t-1]['after_sha256']
    for h in range(8):
        assert offsets[h]==len(old[h])==len(logs[h]) and sha(logs[h])==manifest['heads'][h]['events_sha256']
        assert (HERE/f'{name}-head{h}-final.bin').read_bytes()==b''.join(kq[h]+vq[h]+kr[h]+vr[h])
    assert changed==manifest['changed_digits']
    assert abs(objective[0]-manifest['source_objective_initial_sum'])<.005
    assert abs(objective[1]-manifest['source_objective_final_sum'])<.005
    result={'window':window,'records':224*8,'source_objective_initial':objective[0],
            'source_objective_final':objective[1],'changed_digits':changed,
            'direct_projection_sweep_digit_differences':direct_differences,
            'represented_objective_increases':increases,'retained':results,
            'candidate_event_sha256':[sha(x) for x in logs],
            'input_identity':input_receipt}
    (HERE/f'{name}-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'window':window,'source_final':objective[1],
                      'states':[(r['t'],r['candidate_teacher_sse'],r['control_teacher_sse']) for r in results]}))

if __name__=='__main__':run(int(sys.argv[1]))
