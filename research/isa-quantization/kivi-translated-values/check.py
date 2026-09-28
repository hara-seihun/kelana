"""Independent source, chronology, field, prefix and retained full-O reader."""
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch
from inputs import arrivals as owned_arrivals, exchange as owned_exchange

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
BASE = ROOT/'kivi-two-bit-causal'
NATIVE = ROOT/'kivi-two-bit-dot-native'
ARRIVAL = ROOT/'kivi-value-intern'
EXCHANGE = ROOT/'kivi-kv-rate-exchange'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def bf16(words):
    return (np.asarray(words,dtype=np.uint32)<<16).view('<f4')


def unpack(blob, length):
    z=np.frombuffer(blob,dtype=np.uint8)
    return np.stack((z&3,(z>>2)&3,(z>>4)&3,z>>6),axis=1).reshape(length)


def audit_v(blob,words):
    original=bf16(words).reshape(4,32)
    lo=np.min(original,axis=1)
    step=(np.max(original,axis=1)-lo)/3
    fields=np.frombuffer(blob,dtype='<f2',count=8,offset=32).reshape(4,2)
    assert np.array_equal(fields[:,0],lo.astype('<f2'))
    assert np.array_equal(fields[:,1],step.astype('<f2'))
    expected=np.zeros((4,32),dtype=np.uint8)
    for g in range(4):
        if step[g]>0:
            expected[g]=np.clip(np.rint((original[g]-float(lo[g]))/float(step[g])),0,3).astype(np.uint8)
    assert np.array_equal(unpack(blob[:32],128).reshape(4,32),expected)


def audit_k(blob,words):
    x=bf16(words).reshape(32,128)
    lo=np.min(x,axis=0)
    step=(np.max(x,axis=0)-lo)/3
    fields=np.frombuffer(blob,dtype='<f2',count=256,offset=1024).reshape(128,2)
    assert np.array_equal(fields[:,0],lo.astype('<f2'))
    assert np.array_equal(fields[:,1],step.astype('<f2'))
    expected=np.zeros((32,128),dtype=np.uint8)
    for d in range(128):
        if step[d]>0:
            expected[:,d]=np.clip(np.rint((x[:,d]-float(lo[d]))/float(step[d])),0,3).astype(np.uint8)
    assert np.array_equal(unpack(blob[:1024],4096).reshape(32,128),expected)


def original_events(blob):
    at=0
    records={}
    while at<len(blob):
        kind=blob[at:at+1]
        t=int.from_bytes(blob[at+1:at+3],'little')
        size={b'K':1536,b'V':48}[kind]
        assert (t,kind) not in records
        records[t,kind]=blob[at+3:at+3+size]
        assert len(records[t,kind])==size
        at+=3+size
    assert at==len(blob)
    return records


def image(state):
    return b''.join(part for key in ('kq','vq','kr','vr') for part in state[key])


def decode(state):
    k=[]
    v=[]
    for block in state['kq']:
        digit=unpack(block[:1024],4096).astype(np.float32).reshape(32,128)
        f=np.frombuffer(block,dtype='<f2',count=256,offset=1024).astype(np.float32).reshape(128,2)
        k.append(digit*f[None,:,1]+f[None,:,0])
    for block in state['vq']:
        digit=unpack(block[:32],128).astype(np.float32).reshape(4,32)
        f=np.frombuffer(block,dtype='<f2',count=8,offset=32).astype(np.float32).reshape(4,2)
        v.append((digit*f[:,1,None]+f[:,0,None]).reshape(1,128))
    k.extend(bf16(np.frombuffer(raw,dtype='<u2')).reshape(1,128) for raw in state['kr'])
    v.extend(bf16(np.frombuffer(raw,dtype='<u2')).reshape(1,128) for raw in state['vr'])
    return np.concatenate(k,axis=0),np.concatenate(v,axis=0)


def compare_prefix(state,row,phase):
    data=image(state)
    assert sha(data)==row[phase+'_sha256'] and len(data)==row[phase+'_bytes'], (row['t'],phase,sha(data),row[phase+'_sha256'],len(data),row[phase+'_bytes'])
    assert [len(state[k]) for k in ('kq','vq','kr','vr')]==row[phase+'_counts']
    return data


def retained_output(q,keys,values,o,bias=None):
    k=torch.from_numpy(np.stack(keys).copy()).repeat_interleave(2,dim=0)
    v=torch.from_numpy(np.stack(values).copy()).repeat_interleave(2,dim=0)
    logits=torch.bmm(q[:,None,:],k.transpose(1,2)).squeeze(1)/math.sqrt(128)
    probabilities=logits.softmax(-1)
    mixed=torch.bmm(probabilities[:,None,:],v).reshape(2048)
    output=mixed@o.T
    if bias is not None:
        output=output+bias
    return output,probabilities


def main(window):
    assert window in range(4)
    torch.set_num_threads(1)
    manifest=json.loads((HERE/f'held-{window}-manifest.json').read_text())
    native=json.loads((NATIVE/'snapshots.json').read_text())
    donor=json.loads((BASE/f'held-{window}-manifest.json').read_text())
    arrival_raw=owned_arrivals(window)
    assert len(arrival_raw)==1049088 and sha(arrival_raw)==manifest['arrival_sha256']
    assert sha((BASE/f'held-{window}-manifest.json').read_bytes())==manifest['original_manifest_sha256']
    source_k=np.empty((256,8,128),dtype='<u2')
    source_v=np.empty_like(source_k)
    for i in range(256):
        event=arrival_raw[4098*i:4098*(i+1)]
        assert int.from_bytes(event[:2],'little')==i+1
        source_k[i]=np.frombuffer(event,dtype='<u2',count=1024,offset=2).reshape(8,128)
        source_v[i]=np.frombuffer(event,dtype='<u2',count=1024,offset=2050).reshape(8,128)
    center_raw=(HERE/'center-fp16.bin').read_bytes()
    assert len(center_raw)==2048 and sha(center_raw)==manifest['center_sha256']=='143c78b481c35b7c14699825931e7ef68b8d7edbac4fa75775effdd095c7923c'
    center=np.frombuffer(center_raw,dtype='<f2').astype(np.float32).reshape(8,128)
    source_fp=torch.from_numpy(bf16(source_v).copy())
    centered_bf=(source_fp-torch.from_numpy(center)).to(torch.bfloat16).contiguous()
    centered_fp=centered_bf.float()
    centered_bits=centered_bf.view(torch.uint16).numpy().copy()
    assert np.isfinite(centered_fp.numpy()).all()
    source_delta=(centered_fp+torch.from_numpy(center)-source_fp)
    assert abs(float(source_delta.double().square().sum())-manifest['source_rounding_coordinate_sse'])<1e-8
    assert abs(float(source_delta.abs().max())-manifest['source_rounding_max_abs'])<1e-8
    o_raw=(NATIVE/'original-o.bf16').read_bytes()
    assert len(o_raw)==4194304 and sha(o_raw)==native['original_o_sha256']==manifest['original_o_sha256']
    o=torch.from_numpy(bf16(np.frombuffer(o_raw,dtype='<u2')).reshape(1024,2048).copy())
    with torch.no_grad():
        expected_bias=torch.from_numpy(np.repeat(center,2,axis=0).reshape(2048).copy())@o.T
    bias_raw=(HERE/'bias-fp32.bin').read_bytes()
    assert len(bias_raw)==4096 and sha(bias_raw)==manifest['bias_sha256']
    assert expected_bias.numpy().astype('<f4').tobytes()==bias_raw
    bias=torch.from_numpy(np.frombuffer(bias_raw,dtype='<f4').copy())
    original=[]
    logs={arm:[] for arm in ('translated','v35')}
    actual={arm:[] for arm in logs}
    position={arm:[0]*8 for arm in logs}
    for h in range(8):
        donor_raw=(BASE/f'held-{window}-head{h}-events.bin').read_bytes()
        assert sha(donor_raw)==manifest['original_head_event_sha256'][h]==donor['groups'][f'kv{h}']['events_sha256']
        original.append(original_events(donor_raw))
        for arm in logs:
            label=f'held-{window}-{arm}-head{h}'
            r=manifest['arms'][arm]['heads'][h]
            log=(HERE/f'{label}-events.bin').read_bytes()
            final=(HERE/f'{label}-final.bin').read_bytes()
            assert sha(log)==r['events_sha256'] and sha(final)==r['final_sha256'] and len(final)==r['final_bytes']
            logs[arm].append(log)
            actual[arm].append({'kq':[],'vq':[],'kr':[],'vr':[]})
    saved=[]
    peak={arm:0 for arm in logs}
    for t in range(1,257):
        for h in range(8):
            if t%32==0:
                audit_k(original[h][t,b'K'],source_k[t-32:t,h])
            if t>=33:
                audit_v(original[h][t,b'V'],source_v[t-33,h])
            for arm in logs:
                state=actual[arm][h]
                record=manifest['arms'][arm]['heads'][h]['prefixes'][t-1]
                assert record['t']==t
                state['kr'].append(source_k[t-1,h].astype('<u2').tobytes())
                state['vr'].append((centered_bits if arm=='translated' else source_v)[t-1,h].astype('<u2').tobytes())
                compare_prefix(state,record,'before')
                peak[arm]=max(peak[arm],sum(manifest['arms'][arm]['heads'][a]['prefixes'][t-1]['before_bytes'] for a in range(8)))
                if t%32==0:
                    assert len(state['kr'])==32
                    key=original[h][t,b'K']
                    pos=position[arm][h]
                    assert logs[arm][h][pos:pos+3]==b'K'+t.to_bytes(2,'little')
                    assert logs[arm][h][pos+3:pos+1539]==key
                    position[arm][h]+=1539
                    state['kq'].append(key);state['kr'].clear()
                threshold=32 if arm=='translated' else 35
                if t>threshold:
                    token=state['vr'].pop(0)
                    target=np.frombuffer(token,dtype='<u2')
                    if arm=='translated':
                        original_v=None
                    else:
                        assert np.array_equal(target,source_v[t-threshold-1,h])
                        original_v=original[h][t-3,b'V']
                    pos=position[arm][h]
                    assert logs[arm][h][pos:pos+3]==b'V'+t.to_bytes(2,'little')
                    blob=logs[arm][h][pos+3:pos+51]
                    assert len(blob)==48
                    audit_v(blob,target)
                    if original_v is not None:
                        assert blob==original_v
                    state['vq'].append(blob)
                    position[arm][h]+=51
                compare_prefix(state,record,'after')
        if t not in (128,256):
            continue
        snapshot=next(x for x in native['states'] if x['window']==window and x['position']==t)
        label=f'held-{window}-t{t}'
        q_raw=(NATIVE/f'{label}-q.f32').read_bytes()
        teacher_raw=(NATIVE/f'{label}-teacher.f32').read_bytes()
        assert sha(q_raw)==snapshot['query_sha256'] and sha(teacher_raw)==snapshot['teacher_sha256']
        q=torch.from_numpy(np.frombuffer(q_raw,dtype='<f4').copy().reshape(16,128))
        teacher=torch.from_numpy(np.frombuffer(teacher_raw,dtype='<f4').copy())
        decoded={}
        for arm in logs:
            keys=[];vals=[]
            for h in range(8):
                r=manifest['arms'][arm]['heads'][h]['prefixes'][t-1]
                # The actual before state has already flushed: use the pinned prefix by undoing this step
                state=actual[arm][h]
                chunks=state['kq'][:-1] if t%32==0 else state['kq']
                recent=state['kr'] if t%32 else [source_k[j,h].astype('<u2').tobytes() for j in range(t-32,t)]
                if t> (32 if arm=='translated' else 35):
                    vchunks=state['vq'][:-1]
                    vrecent=[((centered_bits if arm=='translated' else source_v)[j,h]).astype('<u2').tobytes()
                             for j in range(t-(32 if arm=='translated' else 35)-1,t)]
                else:
                    vchunks=state['vq']
                    vrecent=state['vr']
                before={'kq':chunks,'vq':vchunks,'kr':recent,'vr':vrecent}
                compare_prefix(before,r,'before')
                k,v=decode(before)
                keys.append(k);vals.append(v)
                if arm=='translated':
                    orig=(NATIVE/f'{label}-kv{h}.bin').read_bytes()
                    assert sha(orig)==snapshot['state_sha256'][h]
                    expected_key=b''.join(chunks)+b''.join(recent)
                    baseline_kcount=(t-1)//32
                    baseline_vcount=max(0,t-33)
                    assert orig[:baseline_kcount*1536]==b''.join(chunks)
                    recent_start=baseline_kcount*1536+baseline_vcount*48
                    assert orig[recent_start:recent_start+len(b''.join(recent))]==b''.join(recent)
            decoded[arm]=(keys,vals)
        result={ 'window':window,'t':t,'teacher_sq':float(teacher.double().square().sum()),
                'query_sha256':sha(q_raw),'teacher_sha256':sha(teacher_raw)}
        for arm,(keys,vals) in decoded.items():
            out,probs=retained_output(q,keys,vals,o,bias if arm=='translated' else None)
            result[arm+'_sse']=float((out.double()-teacher.double()).square().sum())
            result[arm+'_output_sha256']=sha(out.numpy().astype('<f4').tobytes())
            if arm=='translated':
                uncentered=[bf16(source_v[:t,h]) for h in range(8)]
                ideal,_=retained_output(q,keys,uncentered,o)
                rounded_v=[bf16(centered_bits[:t,h]) for h in range(8)]
                rounded_out,_=retained_output(q,keys,rounded_v,o,bias)
                result['source_boundary_sse_vs_original_bf16_under_k2']=float((rounded_out.double()-ideal.double()).square().sum())
                result['source_boundary_sse_vs_teacher_under_k2']=float((rounded_out.double()-teacher.double()).square().sum())
                result['source_original_bf16_sse_vs_teacher_under_k2']=float((ideal.double()-teacher.double()).square().sum())
                control_raw=(NATIVE/f'{label}-conventional-cpu.f32').read_bytes()
                assert sha(control_raw)==snapshot['cpu_conventional_sha256']
                control=np.frombuffer(control_raw,dtype='<f4')
                # Original K2/V2 control is recomputed independently below from its pinned snapshot.
                original_keys=[];original_values=[]
                for h in range(8):
                    orig=(NATIVE/f'{label}-kv{h}.bin').read_bytes()
                    nk=(t-1)//32; nv=max(0,t-33)
                    kr=t-32*nk; vr=t-nv
                    at=0
                    kq=[orig[at+i*1536:at+(i+1)*1536] for i in range(nk)];at+=nk*1536
                    vq=[orig[at+i*48:at+(i+1)*48] for i in range(nv)];at+=nv*48
                    rk=[orig[at+i*256:at+(i+1)*256] for i in range(kr)];at+=kr*256
                    rv=[orig[at+i*256:at+(i+1)*256] for i in range(vr)];at+=vr*256
                    assert at==len(orig)
                    assert kq==actual['translated'][h]['kq'][:-1] if t%32==0 else kq==actual['translated'][h]['kq']
                    k0,v0=decode({'kq':kq,'vq':vq,'kr':rk,'vr':rv})
                    original_keys.append(k0);original_values.append(v0)
                base_out,_=retained_output(q,original_keys,original_values,o)
                assert np.max(np.abs(base_out.numpy()-control))<1e-5
                result['k2v2_sse']=float((base_out.double()-teacher.double()).square().sum())
        saved.append(result)
    for arm in logs:
        assert peak[arm]==manifest['arms'][arm]['peak_cache_bytes']
        for h in range(8):
            assert position[arm][h]==len(logs[arm][h])
            row=manifest['arms'][arm]['heads'][h]
            assert image(actual[arm][h])==(HERE/f'held-{window}-{arm}-head{h}-final.bin').read_bytes()
            assert len(image(actual[arm][h]))==row['final_bytes']
    exchange_raw=owned_exchange()
    exchange=json.loads(exchange_raw)
    for row in saved:
        matched=next(x for x in exchange['per_state'] if x['window']==window and x['t']==row['t'])
        assert abs(row['teacher_sq']-matched['teacher_sq'])<1e-4
        assert abs(row['k2v2_sse']-matched['K2V2_sse'])<2e-5
        row['k2v4_sse']=matched['K2V4_sse']
    summary={'window':window,'source_arrival_sha256':manifest['arrival_sha256'],
             'source_rounded_v_sha256':sha(centered_bits.tobytes()),
             'bias_sha256':manifest['bias_sha256'],'exchange_result_sha256':sha(exchange_raw),
             'source_coordinate_rounding_sse':manifest['source_rounding_coordinate_sse'],
             'source_coordinate_rounding_max_abs':manifest['source_rounding_max_abs'],
             'states':saved}
    (HERE/f'held-{window}-result.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps({'window':window,'translated_sse':sum(x['translated_sse'] for x in saved),
                      'v35_sse':sum(x['v35_sse'] for x in saved),
                      'source_boundary_sse':sum(x['source_boundary_sse_vs_original_bf16_under_k2'] for x in saved)}))


if __name__=='__main__':
    main(int(sys.argv[1]))
