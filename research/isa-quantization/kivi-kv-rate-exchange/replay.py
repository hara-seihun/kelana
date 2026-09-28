"""Independent event-time replay of the frozen exchange; only retained Q/teacher/O files are scored."""
import hashlib
import json
import math
from pathlib import Path
import sys
import numpy as np
import torch
from controls import read_controls

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SNAP = ROOT / 'kivi-two-bit-dot-native'
TWO = ROOT / 'kivi-two-bit-causal'
FOUR = ROOT / 'skvq-global-gqa'
FIRST = ROOT / 'kivi-causal-cache'
ARRIVAL = ROOT / 'kivi-value-intern'
SIZE = {'2':{'K':1536,'V':48},'4':{'K':2560,'V':80}}
ARMS = {'K2V4':('2','4'),'K4V2':('4','2')}


def sha(b): return hashlib.sha256(b).hexdigest()

def pinned(path, expected):
    b=path.read_bytes(); assert sha(b)==expected, path
    return b

def bf16(bits): return (np.asarray(bits,dtype=np.uint32)<<16).view('<f4')

def digits(payload, bits, kind):
    n=4096 if kind=='K' else 128
    raw=np.frombuffer(payload,dtype='u1',count=n*int(bits)//8)
    if bits=='2':
        a=np.stack((raw&3,(raw>>2)&3,(raw>>4)&3,raw>>6),axis=1)
    else: a=np.stack((raw&15,raw>>4),axis=1)
    return a.reshape((32,128) if kind=='K' else (4,32)).astype('f4')

def field(payload,bits,kind):
    at=1024 if bits=='2' and kind=='K' else 2048 if kind=='K' else 32 if bits=='2' else 64
    return np.frombuffer(payload,dtype='<f2',count=256 if kind=='K' else 8,offset=at).reshape((-1,2)).astype('f4')

def check_payload(payload,bits,kind,source_bits):
    assert len(payload)==SIZE[bits][kind]
    src=bf16(source_bits)
    x=src if kind=='K' else src.reshape(4,32)
    lo,hi=(x.min(0),x.max(0)) if kind=='K' else (x.min(1),x.max(1))
    step=(hi-lo)/(2**int(bits)-1)
    stored=np.frombuffer(payload,dtype='<f2',offset=len(payload)-(512 if kind=='K' else 16)).reshape(-1,2)
    assert np.array_equal(stored[:,0],lo.astype('<f2'))
    assert np.array_equal(stored[:,1],step.astype('<f2'))
    safe=np.where(step>0,step,1)
    expect=np.where((step>0)[None,:] if kind=='K' else (step>0)[:,None],
                    np.clip(np.rint((x-(lo[None,:] if kind=='K' else lo[:,None]))/
                                    (safe[None,:] if kind=='K' else safe[:,None])),0,2**int(bits)-1),0)
    assert np.array_equal(digits(payload,bits,kind),expect)

def decode(chunks,bits,kind,recent):
    rows=[]
    for payload in chunks:
        code=digits(payload,bits,kind); f=field(payload,bits,kind)
        val=code*f[None,:,1]+f[None,:,0] if kind=='K' else code*f[:,1,None]+f[:,0,None]
        rows.append(val.reshape(-1,128))
    rows.append(bf16(np.frombuffer(b''.join(recent),dtype='<u2').reshape(-1,128)))
    return np.concatenate(rows,axis=0)

def donor(window,h,bits):
    name=f'held-{window}'
    if bits=='2':
        info=json.loads((TWO/f'{name}-manifest.json').read_text())['groups'][f'kv{h}']
        folder=TWO; stem=f'{name}-head{h}'; event_sha=info['events_sha256']; final_sha=info['final_sha256']
        receipts=[(p['before_query_flush'],p['after_query_flush']) for p in info['prefixes']]
        log_file=folder/f'{stem}-events.bin'; final_file=folder/f'{stem}-final.bin'
    elif h==0:
        info=json.loads((FIRST/f'{name}-manifest.json').read_text())
        event_sha=info['flush_log_sha256'];final_sha=info['final_sha256']
        receipts=[(p['before_flush'],p['after_flush']) for p in info['prefixes']]
        log_file=FIRST/f'{name}-flush.bin';final_file=FIRST/f'{name}-final.bin'
    else:
        info=json.loads((FOUR/f'{name}-kivi-manifest.json').read_text())['groups'][f'kv{h}']
        event_sha=info['event_log_sha256'];final_sha=info['final_image_sha256']
        receipts=[(p['before'],p['after']) for p in info['prefixes']]
        log_file=FOUR/f'{name}-kivi-head{h}-events.bin';final_file=FOUR/f'{name}-kivi-head{h}-final.bin'
    log=pinned(log_file,event_sha);final=pinned(final_file,final_sha)
    records={'K':[],'V':[]};at=0
    while at<len(log):
        kind=chr(log[at]);assert kind in records
        t=int.from_bytes(log[at+1:at+3],'little');n=SIZE[bits][kind]
        payload=log[at+3:at+3+n];assert len(payload)==n
        assert t==(len(records[kind])+1)*32 if kind=='K' else t==len(records[kind])+33
        records[kind].append((t,payload));at+=3+n
    assert len(records['K'])==8 and len(records['V'])==224
    return records,receipts,final,event_sha,final_sha

def state(kq,vq,kr,vr):return b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)

def verify(blob,record):
    assert len(blob)==record.get('bytes',record.get('live_state_bytes')) and sha(blob)==record['sha256']

def score(window, arm, t, heads, manifest, control, snapshots, o):
    tag=f'held-{window}-t{t}'
    record=snapshots[tag]
    q=torch.from_numpy(np.frombuffer(pinned(SNAP/f'{tag}-q.f32',record['query_sha256']),'<f4').copy()).reshape(16,128)
    teacher=np.frombuffer(pinned(SNAP/f'{tag}-teacher.f32',record['teacher_sha256']),'<f4').copy().astype('f8')
    key=torch.from_numpy(np.repeat(np.stack([x[0] for x in heads]),2,axis=0).copy())
    value=torch.from_numpy(np.repeat(np.stack([x[1] for x in heads]),2,axis=0).copy())
    prob=(torch.bmm(q[:,None,:],key.transpose(1,2)).squeeze(1)/math.sqrt(128)).softmax(-1)
    output=(torch.bmm(prob[:,None,:],value).reshape(2048)@o.T).numpy().astype('f8')
    sse=float(np.sum((output-teacher)**2)); den=float(np.sum(teacher**2))
    baseline=control['receipt']['retained'][0 if t==128 else 1]
    assert abs(den-baseline['teacher_sq'])<1e-6
    assert abs(den-control['kivi2_retained'][0 if t==128 else 1]['teacher_sq'])<1e-6
    return {'t':t,'teacher_sse':sse,'teacher_sq':den,'relative_sq':sse/den,'output_sha256':sha(output.astype('<f4').tobytes())}

def run(window):
    torch.set_num_threads(1)
    name=f'held-{window}'
    manifest=json.loads((HERE/f'{name}-manifest.json').read_text())
    controls=read_controls()['records'][str(window)]
    snap=json.loads((SNAP/'snapshots.json').read_text())
    o_data=pinned(SNAP/'original-o.bf16',snap['original_o_sha256'])
    o=torch.from_numpy(bf16(np.frombuffer(o_data,'<u2').reshape(1024,2048)).copy())
    snapshots={x['tag']:x for x in snap['states'] if x['window']==window}
    arrival=json.loads((ARRIVAL/f'{name}-manifest.json').read_text())
    assert arrival['source_fixture_sha256']==manifest['source']['fixture_sha256']==snap['fixture_sha256']
    raw=np.frombuffer(pinned(ARRIVAL/f'{name}-events.bin',manifest['source']['arrival_events_sha256']),dtype='u1').reshape(256,4098)
    assert sha((ARRIVAL/f'{name}-manifest.json').read_bytes())==manifest['source']['arrival_manifest_sha256']
    assert np.array_equal(raw[:,:2],np.arange(1,257,dtype='<u2').view('u1').reshape(256,2))
    kb=np.ascontiguousarray(raw[:,2:2050]).view('<u2').reshape(256,8,128)
    vb=np.ascontiguousarray(raw[:,2050:]).view('<u2').reshape(256,8,128)
    assert arrival['baseline_manifest_sha256']==sha((TWO/f'{name}-manifest.json').read_bytes())
    donors={(h,b):donor(window,h,b) for h in range(8) for b in SIZE}
    result={'window':window,'arms':{},'fixed_controls':{'K2V2':controls['kivi2_retained'],
             'K4V4':controls['receipt']['retained']},'controls_sha256':{
             'K2V2':controls['kivi2_receipt_sha256'],'K4V4':controls['receipt_sha256']}}
    for arm,(keybits,valuebits) in ARMS.items():
        config=manifest['arms'][arm]
        histories=[]
        for h in range(8):
            kq=[];vq=[];kr=[];vr=[];offset=0;peak=0
            path=HERE/f'{name}-{arm}-head{h}-events.bin'
            log=pinned(path,config['groups'][h]['events_sha256'])
            assert config['groups'][h]['donor_k_sha256']==donors[(h,keybits)][3]
            assert config['groups'][h]['donor_v_sha256']==donors[(h,valuebits)][3]
            held={}
            for t in range(1,257):
                kr.append(kb[t-1,h].tobytes());vr.append(vb[t-1,h].tobytes())
                before=state(kq,vq,kr,vr)
                verify(before,config['groups'][h]['prefixes'][t-1]['before'])
                peak=max(peak,len(before))
                # Independently compare each selected decoded K/V to its donor's decoded field stream.
                for bits in SIZE:
                    events,receipts,_,_,_=donors[(h,bits)]
                    nk=(t-1)//32;nv=max(0,t-33)
                    donor_k=[p for _,p in events['K'][:nk]]
                    donor_v=[p for _,p in events['V'][:nv]]
                    donor_pre=state(donor_k,donor_v,kr,vr)
                    verify(donor_pre,receipts[t-1][0])
                    if t in (128,256):
                        idx=0 if t==128 else 1
                        expected=(snapshots[f'{name}-t{t}']['state_sha256'][h] if bits=='2'
                                  else controls['receipt']['retained'][idx]['state_sha256'][h])
                        assert sha(donor_pre)==expected
                    if bits==keybits:
                        assert kq==donor_k
                        assert np.array_equal(decode(kq,bits,'K',kr),decode(donor_k,bits,'K',kr))
                    if bits==valuebits:
                        assert vq==donor_v
                        assert np.array_equal(decode(vq,bits,'V',vr),decode(donor_v,bits,'V',vr))
                if t in (128,256):
                    paid=pinned(HERE/f'{name}-{arm}-t{t}-kv{h}.bin',config['groups'][h]['prefixes'][t-1]['before']['sha256'])
                    assert paid==before
                    held[t]=(decode(kq,keybits,'K',kr),decode(vq,valuebits,'V',vr))
                for kind,active,bits in (('K',kq,keybits),('V',vq,valuebits)):
                    flush=(kind=='K' and len(kr)==32) or (kind=='V' and len(vr)==33)
                    if not flush:continue
                    pos,blob=donors[(h,bits)][0][kind][len(active)]
                    assert pos==t and log[offset:offset+3+len(blob)]==kind.encode()+t.to_bytes(2,'little')+blob
                    check_payload(blob,bits,kind,kb[t-32:t,h] if kind=='K' else vb[t-33,h])
                    offset+=3+len(blob);active.append(blob)
                    if kind=='K':kr.clear()
                    else:vr.pop(0)
                after=state(kq,vq,kr,vr)
                verify(after,config['groups'][h]['prefixes'][t-1]['after'])
                for bits in SIZE:
                    events,receipts,_,_,_=donors[(h,bits)]
                    nk=t//32;nv=max(0,t-32)
                    donor_post=state([p for _,p in events['K'][:nk]],
                                     [p for _,p in events['V'][:nv]],kr,vr)
                    verify(donor_post,receipts[t-1][1])
            assert offset==len(log) and after==pinned(HERE/f'{name}-{arm}-head{h}-final.bin',config['groups'][h]['final_sha256'])
            assert len(after)==config['groups'][h]['final_bytes']
            histories.append((held,peak))
        assert max(x[1] for x in histories)*8==config['peak_bytes']
        assert sum(config['groups'][h]['final_bytes'] for h in range(8))==config['final_bytes']
        retained=[score(window,arm,t,[x[0][t] for x in histories],manifest,controls,snapshots,o) for t in (128,256)]
        result['arms'][arm]={'peak_bytes':config['peak_bytes'],'final_bytes':config['final_bytes'],
                             'retained':retained}
    (HERE/f'{name}-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'window':window,'sse':{a:sum(x['teacher_sse'] for x in z['retained']) for a,z in result['arms'].items()}}))

if __name__=='__main__':run(int(sys.argv[1]))
