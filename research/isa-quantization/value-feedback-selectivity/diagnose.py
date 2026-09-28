"""Read-only, fixed-program selectivity/encoder diagnostic at the eight held positions."""
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
L0 = ROOT / 'kivi-value-error-feedback'
SNAP = ROOT / 'kivi-two-bit-dot-native'
ARRIVAL = ROOT / 'kivi-value-intern'
L1 = ROOT / 'contextual-value-feedback'


def sha(b): return hashlib.sha256(b).hexdigest()
def pinned(path, digest):
    data = path.read_bytes()
    assert sha(data) == digest, path
    return data

def fp(bits): return (np.asarray(bits, dtype='<u4') << 16).view('<f4')
def digits(raw, n):
    b = np.frombuffer(raw, dtype='u1')
    return np.stack((b & 3, (b >> 2) & 3, (b >> 4) & 3, b >> 6), axis=-1).reshape(n)

def decode(blob, t):
    nk = (t-1)//32
    nv = max(0,t-33)
    rk = t-32*nk
    rv = t-nv
    assert len(blob) == nk*1536+nv*48+(rk+rv)*256
    pos = 0
    ks = []
    for _ in range(nk):
        record = blob[pos:pos+1536]; pos += 1536
        code = digits(record[:1024],4096).reshape(32,128)
        field = np.frombuffer(record[1024:],dtype='<f2').astype('<f4').reshape(128,2)
        ks.append(field[None,:,0]+field[None,:,1]*code)
    vs = []
    for _ in range(nv):
        record = blob[pos:pos+48]; pos += 48
        code = digits(record[:32],128).reshape(4,32)
        field = np.frombuffer(record[32:],dtype='<f2').astype('<f4').reshape(4,2)
        vs.append((field[:,0,None]+field[:,1,None]*code).reshape(128))
    ks.append(fp(np.frombuffer(blob[pos:pos+rk*256],dtype='<u2').reshape(rk,128)));pos+=rk*256
    vs.append(fp(np.frombuffer(blob[pos:pos+rv*256],dtype='<u2').reshape(rv,128)))
    return np.concatenate(ks),np.concatenate((np.asarray(vs[:-1],dtype='<f4'),vs[-1]))

def source(layer,w):
    if layer == 0:
        name=f'held-{w}'
        receipt=json.loads((L0/f'{name}-manifest.json').read_text())
        raw=pinned(ARRIVAL/f'{name}-events.bin',receipt['arrival_sha256'])
        assert len(raw)==256*4098
        data=np.empty((256,8,128),dtype='<u2');keys=np.empty_like(data)
        for i in range(256):
            block=raw[i*4098:(i+1)*4098]
            assert int.from_bytes(block[:2],'little')==i+1
            keys[i]=np.frombuffer(block[2:2050],dtype='<u2').reshape(8,128)
            data[i]=np.frombuffer(block[2050:],dtype='<u2').reshape(8,128)
        snap=json.loads((SNAP/'snapshots.json').read_text())
        o=pinned(SNAP/'original-o.bf16',snap['original_o_sha256'])
        return {'k':keys,'v':data,'o':o,'source_sha256':receipt['arrival_sha256'],'manifest':receipt,'snap':snap}
    name=f'validation-{w}'
    record=json.loads((L1/f'{name}-source.json').read_text())
    path=L1/f'{name}-source.npz'
    pinned(path,record['source_file_sha256'])
    with np.load(path) as archive:
        arrays={k:archive[k].copy() for k in ('q','k','v','teacher')}
    for k,a in arrays.items():assert sha(a.tobytes())==record['arrays'][k]['sha256']
    manifest=json.loads((L1/f'{name}-manifest.json').read_text())
    assert manifest['source_sha256']==record['source_file_sha256']
    o_record=json.loads((L1/'original-o.json').read_text())
    assert o_record['o_sha256']==record['original_o_bf16_sha256']
    o=pinned(L1/'original-o.bf16',o_record['o_sha256'])
    return {**arrays,'o':o,'source_sha256':record['source_file_sha256'],'manifest':manifest}

def stats(a):
    a=np.asarray(a,dtype='f8')
    return {'rms':float(np.sqrt(np.mean(a*a))),'max_abs':float(np.max(np.abs(a))),'min':float(np.min(a)),'max':float(np.max(a))}

def chronology(layer,w,data):
    residual=np.zeros((8,128),dtype='<f4')
    trajectories=np.zeros((8,224,128),dtype='<f4')
    defects=np.zeros((8,224,128),dtype='f8')
    lo=[];step=[];peaks=[];clipped=0;clipped_groups=0;below=0;above=0;residual_over_step=0
    for h in range(8):
        m=data['manifest']['arms']['feedback']['heads'][h]
        logname=(f'held-{w}-feedback-head{h}-events.bin' if layer==0 else f'validation-{w}-feedback-h{h}-events.bin')
        log=pinned((L0 if layer==0 else L1)/logname,m['events_sha256'])
        entries=[];p=0
        while p<len(log):
            kind=log[p:p+1];size=1536 if kind==b'K' else 48
            assert kind in (b'K',b'V')
            entries.append((kind,int.from_bytes(log[p+1:p+3],'little'),log[p+3:p+3+size]));p+=size+3
        assert p==len(log)
        values=[(at,blob) for kind,at,blob in entries if kind==b'V']
        assert len(values)==224
        for j,(at,blob) in enumerate(values):
            assert at==j+33
            meta=m['prefixes'][at-1] if layer==0 else m['prefix'][at-1]
            before=meta['residual_before'] if layer==0 else meta['residual_before_sha256']
            after=meta['residual_after'] if layer==0 else meta['residual_after_sha256']
            assert sha(residual[h].tobytes())==before
            x=fp(data['v'][j,h]); prior=residual[h].copy()
            target=np.add(x,prior,dtype='<f4')
            code=digits(blob[:32],128)
            decoded=np.empty(128,dtype='<f4')
            for g in range(4):
                sl=slice(g*32,(g+1)*32)
                low=float(np.min(x[sl]));delta=(float(np.max(x[sl]))-low)/3
                field=np.array((low,delta),dtype='<f2')
                assert field.tobytes()==blob[32+4*g:36+4*g]
                ideal=np.zeros(32,dtype='u1') if delta==0 else np.clip(np.rint((target[sl]-low)/delta),0,3).astype('u1')
                assert np.array_equal(ideal,code[sl])
                if delta:
                    under=target[sl].astype('f8')<low
                    over=target[sl].astype('f8')>low+3*delta
                    outside=under|over
                    below+=int(np.count_nonzero(under));above+=int(np.count_nonzero(over))
                    clipped+=int(np.count_nonzero(outside));clipped_groups+=int(np.any(outside))
                decoded[sl]=np.float32(field[0])+np.float32(field[1])*code[sl]
                lo.append(low);step.append(delta)
            updated=np.subtract(target,decoded,dtype='<f4')
            defects[h,j]=updated.astype('f8')-prior.astype('f8')-(x.astype('f8')-decoded.astype('f8'))
            residual[h]=updated
            for g in range(4):
                sl=slice(g*32,(g+1)*32)
                residual_over_step+=int(np.count_nonzero(np.abs(updated[sl])>step[-4+g]))
            trajectories[h,j]=updated
            peaks.append(float(np.max(np.abs(updated))))
            assert sha(updated.tobytes())==after
        end=m['residual_final'] if layer==0 else m['residual_final_sha256']
        assert sha(residual[h].tobytes())==end
    coordinate_min=trajectories.min(axis=1);coordinate_max=trajectories.max(axis=1)
    coordinate_rms=np.sqrt(np.mean(trajectories.astype('f8')**2,axis=1))
    return trajectories,defects,{'residual':stats(trajectories),'per_head_peak':[float(np.max(np.abs(a))) for a in trajectories],
       'per_coordinate_range':stats(coordinate_max-coordinate_min),'per_coordinate_rms':stats(coordinate_rms),
       'per_coordinate_min':stats(coordinate_min),'per_coordinate_max':stats(coordinate_max),
       'source_low':stats(lo),'source_step':stats(step),'source_step_min':float(min(step)),
       'clipped_target_coordinates':clipped,'clipped_below':below,'clipped_above':above,
       'clipped_source_groups':clipped_groups,'residual_coordinates_over_source_step':residual_over_step,
       'target_update_defect':stats(defects),'max_residual_at_any_step':max(peaks)}

def observer(layer,w,data,trajectories,defects):
    o=fp(np.frombuffer(data['o'],dtype='<u2')).reshape(1024,2048).astype('f8')
    out=[]
    for t in (128,256):
        states={arm:[] for arm in ('original','feedback')}
        for arm in states:
            for h in range(8):
                if layer==0:
                    name=f'held-{w}'
                    if arm=='original':
                        rec=next(s for s in data['snap']['states'] if s['tag']==f'{name}-t{t}')
                        path=SNAP/f'{name}-t{t}-kv{h}.bin';digest=rec['state_sha256'][h]
                    else:
                        meta=data['manifest']['arms']['feedback']['heads'][h]['prefixes'][t-1]
                        path=L0/f'{name}-feedback-t{t}-kv{h}.bin';digest=meta['before']
                else:
                    rec=data['manifest']['arms'][arm]['heads'][h]['prefix'][t-1]
                    path=L1/f'validation-{w}-{arm}-t{t}-h{h}.bin';digest=rec['pre_sha256']
                states[arm].append(decode(pinned(path,digest),t))
        if layer==0:
            rec=next(s for s in data['snap']['states'] if s['tag']==f'held-{w}-t{t}')
            q=np.frombuffer(pinned(SNAP/f'held-{w}-t{t}-q.f32',rec['query_sha256']),dtype='<f4').reshape(16,128)
            teacher=np.frombuffer(pinned(SNAP/f'held-{w}-t{t}-teacher.f32',rec['teacher_sha256']),dtype='<f4').astype('f8')
        else:q=data['q'][:,t-1];teacher=data['teacher'][t-1].astype('f8')
        assert q.shape==(16,128)
        b=np.zeros(1024,dtype='f8'); result={}
        m=t-33
        for h in range(8):
            original_k=states['original'][h][0]
            feedback_k=states['feedback'][h][0]
            assert np.array_equal(original_k,feedback_k)
            assert np.array_equal(states['original'][h][1][m:],states['feedback'][h][1][m:])
        for arm in states:
            mixed=[];v_terms=[];tel_errors=[];p_stats=[]
            for qh in range(16):
                h=qh//2;k,v=states[arm][h]
                logits=q[qh].astype('f8')@k.astype('f8').T/math.sqrt(128)
                p=np.exp(logits-np.max(logits));p/=p.sum()
                p_stats.append({'max':float(p.max()),'effective_support':float(1/np.sum(p*p))})
                v_source=fp(data['v'][:t,h]).astype('f8')
                ve=v.astype('f8')-v_source
                mixed.append(p@v.astype('f8'))
                v_terms.append({'prob':p,'ve':ve,'source':v_source})
                if arm=='feedback':
                    r=trajectories[h,:m].astype('f8');d=defects[h,:m]
                    telescoped= -np.einsum('i,ij->j',p[:m-1]-p[1:m],r[:-1])-p[m-1]*r[-1]+np.einsum('i,ij->j',p[:m],d)
                    direct=p@ve
                    tel_errors.append(float(np.max(np.abs(direct-telescoped))))
            mixed=np.concatenate(mixed)
            prediction=o@mixed
            result[arm]={'full_sse':float(np.sum((prediction-teacher)**2)),
                'prediction_sha256_fp64':sha(prediction.tobytes()),'mean_effective_support':float(np.mean([s['effective_support'] for s in p_stats])),
                'mean_max_probability':float(np.mean([s['max'] for s in p_stats]))}
            if arm=='feedback':result[arm]['max_telescoping_residual_before_O']=max(tel_errors)
            if arm=='original':original_terms=v_terms
            else:feedback_terms=v_terms
        # All three vectors use one common K2 probability and one common FP64 O.
        b_parts=[];e_parts={arm:[] for arm in states};u_parts={arm:[] for arm in states}
        for arm,terms in (('original',original_terms),('feedback',feedback_terms)):
            for qh,item in enumerate(terms):
                p=item['prob'];ve=item['ve'];src=item['source']
                e_parts[arm].append(p@ve)
                u_parts[arm].append(np.mean(ve,axis=0))
                if arm=='original':b_parts.append(p@src)
        b=o@np.concatenate(b_parts)-teacher
        row={'layer':layer,'window':w,'t':t,'m':m,'teacher_sq':float(teacher@teacher),'key_source_offset_sse':float(b@b),
             'arms':{},'source_sha256':data['source_sha256']}
        for arm in states:
            e=o@np.concatenate(e_parts[arm]);uniform=o@np.concatenate(u_parts[arm]);full=b+e
            row['arms'][arm]={**result[arm],'isolated_v_sse':float(e@e),'uniform_v_sse':float(uniform@uniform),
               'offset_dot_v':float(b@e),'full_decomposed_sse':float(full@full),
               'sse_identity_residual':float(full@full-(b@b+e@e+2*b@e)),
               'max_reconstruction_residual':float(np.max(np.abs(full-(o@np.concatenate([x['prob']@states[arm][qh//2][1].astype('f8') for qh,x in enumerate(original_terms)])-teacher))))}
            assert abs(row['arms'][arm]['full_sse']-row['arms'][arm]['full_decomposed_sse'])<1e-6
            assert row['arms'][arm]['max_reconstruction_residual']<1e-10
        out.append(row)
    return out

def run(layer,w):
    data=source(layer,w)
    residual,defects,encoder=chronology(layer,w,data)
    result={'layer':layer,'window':w,'source_sha256':data['source_sha256'],
            'o_sha256':sha(data['o']),'encoder':encoder,'states':observer(layer,w,data,residual,defects)}
    path=HERE/f'layer{layer}-held-{w}.json'
    path.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'layer':layer,'window':w,'clipped':encoder['clipped_target_coordinates'],
          'states':[{ 't':r['t'],'original':r['arms']['original']['full_sse'],'feedback':r['arms']['feedback']['full_sse']} for r in result['states']]}))

if __name__=='__main__':run(int(sys.argv[1]),int(sys.argv[2]))
