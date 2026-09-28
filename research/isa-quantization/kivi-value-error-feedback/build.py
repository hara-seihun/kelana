"""Frozen causal V error feedback and two-token delayed-original control."""
import hashlib
import json
from pathlib import Path
import sys
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SOURCE = ROOT / 'kivi-value-intern'
BASE = ROOT / 'kivi-two-bit-causal'


def sha(b): return hashlib.sha256(b).hexdigest()
def state(kq,vq,kr,vr): return b''.join(kq+vq+kr+vr)
def f32(b): return (np.frombuffer(b,'<u2').astype('<u4')<<16).view('<f4')
def pack(c):
    c=np.asarray(c,dtype='u1')
    return (c[::4]|(c[1::4]<<2)|(c[2::4]<<4)|(c[3::4]<<6)).tobytes()


def feedback(source, prior, original):
    v=f32(source)
    fields=bytearray()
    codes=np.zeros(128,dtype='u1')
    target=np.add(v,prior,dtype='f4')
    reconstructed=np.empty(128,dtype='<f4')
    for g in range(4):
        sl=slice(g*32,(g+1)*32)
        lo=float(v[sl].min()); step=(float(v[sl].max())-lo)/3
        fields.extend(np.asarray((lo,step),dtype='<f2').tobytes())
        if step:
            codes[sl]=np.clip(np.rint((target[sl]-lo)/step),0,3).astype('u1')
        low,delta=np.frombuffer(fields[-4:],dtype='<f2').astype('<f4')
        reconstructed[sl]=low+delta*codes[sl].astype('<f4')
    assert bytes(fields)==original[32:]
    new=np.subtract(target,reconstructed,dtype='<f4')
    return pack(codes)+bytes(fields),new


def run(w):
    name=f'held-{w}'
    audit=json.loads((SOURCE/f'{name}-manifest.json').read_text())
    raw=(SOURCE/f'{name}-events.bin').read_bytes(); assert sha(raw)==audit['events_sha256']
    baseline_bytes=(BASE/f'{name}-manifest.json').read_bytes()
    assert sha(baseline_bytes)==audit['baseline_manifest_sha256']
    base=json.loads(baseline_bytes)
    assert len(raw)==256*4098
    records=[]
    for h in range(8):
        group=base['groups'][f'kv{h}']
        old=(BASE/f'{name}-head{h}-events.bin').read_bytes()
        assert sha(old)==group['events_sha256']
        events={'K':[],'V':[]};p=0
        while p<len(old):
            kind=chr(old[p]); assert kind in events
            n=1536 if kind=='K' else 48
            t=int.from_bytes(old[p+1:p+3],'little')
            assert t==((len(events[kind])+1)*32 if kind=='K' else len(events[kind])+33)
            events[kind].append((t,old[p+3:p+3+n]));p+=n+3
        assert len(events['K'])==8 and len(events['V'])==224
        records.append((events,sha(old)))
    output={'window':w,'arrival_sha256':sha(raw),'arrival_manifest_sha256':sha((SOURCE/f'{name}-manifest.json').read_bytes()),'baseline_manifest_sha256':sha(baseline_bytes),'arms':{}}
    for arm in ('feedback','delay2'):
        heads=[];max_peak=0
        for h,(events,old_sha) in enumerate(records):
            kq=[];vq=[];kr=[];vr=[];journal=bytearray();prefix=[];peak=0
            residual=np.zeros(128,dtype='<f4')
            changes=0
            for t in range(1,257):
                row=raw[(t-1)*4098:t*4098];assert int.from_bytes(row[:2],'little')==t
                kr.append(row[2+h*256:2+(h+1)*256]);vr.append(row[2050+h*256:2050+(h+1)*256])
                before=state(kq,vq,kr,vr)
                if arm=='feedback' and t<=33:
                    assert sha(before)==base['groups'][f'kv{h}']['prefixes'][t-1]['before_query_flush']['sha256']
                peak=max(peak,len(before));entry={'before':sha(before),'before_bytes':len(before),'residual_before':sha(residual.tobytes())}
                if t in (128,256): (HERE/f'{name}-{arm}-t{t}-kv{h}.bin').write_bytes(before)
                if len(kr)==32:
                    pos,k=events['K'][len(kq)];assert pos==t
                    kq.append(k);journal+=b'K'+t.to_bytes(2,'little')+k;kr.clear()
                threshold=33 if arm=='feedback' else 35
                if len(vr)==threshold:
                    source=vr.pop(0)
                    ix=len(vq)
                    if arm=='feedback':
                        pos,old=events['V'][ix];assert pos==t
                        blob,residual=feedback(source,residual,old)
                        changes+=sum(a!=b for a,b in zip(blob[:32],old[:32]))
                    else:
                        pos,blob=events['V'][ix];assert pos==t-2
                    vq.append(blob);journal+=b'V'+t.to_bytes(2,'little')+blob
                after=state(kq,vq,kr,vr)
                entry.update(after=sha(after),after_bytes=len(after),residual_after=sha(residual.tobytes()))
                prefix.append(entry)
            final=state(kq,vq,kr,vr)
            (HERE/f'{name}-{arm}-head{h}-events.bin').write_bytes(journal)
            (HERE/f'{name}-{arm}-head{h}-final.bin').write_bytes(final)
            heads.append({'head':h,'original_event_sha256':old_sha,'events_sha256':sha(journal),'final_sha256':sha(final),'final_bytes':len(final),'peak_bytes':peak,'value_events':len(vq),'changed_code_bytes':changes,'residual_final':sha(residual.tobytes()),'prefixes':prefix})
            max_peak=max(max_peak,peak)
        extra=4096 if arm=='feedback' else 0
        output['arms'][arm]={'heads':heads,'peak_cache_bytes':max_peak*8,'final_cache_bytes':sum(x['final_bytes'] for x in heads),'residual_bytes':extra,'peak_total_bytes':max_peak*8+extra,'final_total_bytes':sum(x['final_bytes'] for x in heads)+extra}
        expected=(308864,253952) if arm=='feedback' else (308096,253184)
        assert (output['arms'][arm]['peak_total_bytes'],output['arms'][arm]['final_total_bytes'])==expected
    (HERE/f'{name}-manifest.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({'window':w,'ledgers':{a:(x['peak_total_bytes'],x['final_total_bytes']) for a,x in output['arms'].items()}}))

if __name__=='__main__':run(int(sys.argv[1]))
