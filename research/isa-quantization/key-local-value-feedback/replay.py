"""Independent source- and field-checked arrival replay and complete CPU O observer."""
import json,sys,math
from pathlib import Path
import numpy as np
import torch
HERE=Path(__file__).resolve().parent
OWNER=HERE.parent/'contextual-value-feedback'
sys.path.insert(0,str(OWNER))
from custody import source,sha
from replay import expect_k,expect_v,decode,score,unpack_records
from weights import load as load_o

def parse(blob):
    p=0;out=[]
    while p<len(blob):
        kind=chr(blob[p]);assert kind in ('K','V')
        size=1536 if kind=='K' else 48
        assert p+3+size<=len(blob)
        out.append((kind,int.from_bytes(blob[p+1:p+3],'little'),blob[p+3:p+3+size]));p+=3+size
    return out

def bf16(raw):return (np.asarray(raw,dtype='<u4')<<16).view('<f4')
def causal_key(j,chunks,recent):
    q=j-1
    if q<32*len(chunks):
        blob=chunks[q//32];offset=(q%32)*32
        b=np.frombuffer(blob,dtype='u1',count=32,offset=offset)
        digit=np.empty(128,dtype='<f4');digit[0::4]=b&3;digit[1::4]=(b>>2)&3;digit[2::4]=(b>>4)&3;digit[3::4]=b>>6
        f=np.frombuffer(blob,dtype='<f2',count=256,offset=1024).astype('<f4').reshape(128,2)
        return f[:,0]+digit*f[:,1]
    assert q-32*len(chunks)<len(recent)
    return bf16(np.frombuffer(recent[q-32*len(chunks)],dtype='<u2'))

def select(i,t,chunks,recent):
    base=causal_key(i,chunks,recent);best=None;target=None
    for j in range(i+1,t+1):
        diff=np.subtract(base,causal_key(j,chunks,recent),dtype='<f4')
        d=float(np.sum(np.multiply(diff,diff,dtype='<f4'),dtype='<f8'))
        assert math.isfinite(d)
        if best is None or d<best:best=d;target=j
    return target,best

def run(panel,w,materialize_state=False):
    torch.set_num_threads(1)
    arrays,src=source(panel,w);stem=f'{panel}-{w}'
    manifest_path=HERE/f'{stem}-manifest.json';m=json.loads(manifest_path.read_text())
    ownpath=OWNER/f'{stem}-manifest.json';original=json.loads(ownpath.read_text())
    assert m['original_manifest_sha256']==sha(ownpath.read_bytes()) and m['source_sha256']==src['source_file_sha256']
    heads=[];pre_states={};encoder_images={128:bytearray(),256:bytearray(),'final':bytearray()}
    skipped_error=0.;visited_error=0.;pending_norm=0.;routes=0;skips=0;reads_k2=0;reads_bf16=0
    for h in range(8):
        meta=m['heads'][h];reference=(OWNER/f'{stem}-original-h{h}-events.bin').read_bytes();om=original['arms']['original']['heads'][h]
        assert sha(reference)==meta['original_event_sha256']==om['events_sha256']
        orig=parse(reference);log=(HERE/f'{stem}-h{h}-events.bin').read_bytes()
        assert sha(log)==meta['events_sha256'];actual=parse(log);assert len(actual)==len(orig)==232
        kq=[];vq=[];kr=[];vr=[];res=np.zeros(128,dtype='<f4');recipient=1;idx=0;route=[];skip=0
        for t in range(1,257):
            kr.append(arrays['k'][t-1,h].astype('<u2').tobytes());vr.append(arrays['v'][t-1,h].astype('<u2').tobytes())
            pre=b''.join(kq+vq+kr+vr);r=meta['prefix'][t-1]
            assert (r['t'],r['pre_sha256'],r['pre_bytes'],r['residual_before_sha256'],r['recipient_before'])==(t,sha(pre),len(pre),sha(res.tobytes()),recipient)
            pre_states.setdefault(t,[None]*8)[h]=([*kq],[*vq],[*kr],[*vr])
            if 'image_file' in r:
                assert (HERE/r['image_file']).read_bytes()==pre
                encoder_images[t]+=res.tobytes()+recipient.to_bytes(2,'little')
            if len(kr)==32:
                kind,when,blob=actual[idx];assert (kind,when)==('K',t) and actual[idx]==orig[idx]
                expect_k(np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128),blob)
                idx+=1;kq.append(blob);kr=[]
            if len(vr)==33:
                kind,when,blob=actual[idx];assert (kind,when)==('V',t)
                assert orig[idx][:2]==(kind,when)
                i=t-32;raw=np.frombuffer(vr.pop(0),dtype='<u2')
                if i==recipient:
                    res=expect_v(raw,blob,2,res)
                    recipient,d=select(i,t,kq,kr)
                    assert (i,recipient,d)==(meta['routes'][len(route)]['source'],meta['routes'][len(route)]['target'],meta['routes'][len(route)]['distance'])
                    route.append(recipient);routes+=1;reads_k2+=sum(j<=len(kq)*32 for j in range(i,t+1));reads_bf16+=sum(j>len(kq)*32 for j in range(i,t+1))
                    visited_error+=float(np.square(bf16(raw)-unpack_records([blob],2,False)[0],dtype='<f8').sum())
                else:
                    assert blob==orig[idx][2]
                    expect_v(raw,blob,2,None)
                    skip+=1;skips+=1
                    skipped_error+=float(np.square(bf16(raw)-unpack_records([blob],2,False)[0],dtype='<f8').sum())
                idx+=1;vq.append(blob)
            post=b''.join(kq+vq+kr+vr)
            assert (r['post_sha256'],r['post_bytes'],r['residual_after_sha256'],r['recipient_after'])==(sha(post),len(post),sha(res.tobytes()),recipient)
        assert idx==232 and len(route)==len(meta['routes']) and skip==meta['skipped']
        assert sha(log)==meta['events_sha256'] and sha(post)==meta['final_sha256']==sha((HERE/f'{stem}-h{h}-final.bin').read_bytes())
        assert sha(res.tobytes())==meta['residual_final_sha256'] and recipient==meta['recipient_final'] and recipient>224
        encoder_images['final']+=res.tobytes()+recipient.to_bytes(2,'little')
        pending_norm+=float(np.square(res.astype('<f8')).sum())
        heads.append(meta)
    assert sum(x['final_bytes'] for x in heads)+4112==m['final_total_bytes']==253968 and max(x['peak_bytes'] for x in heads)*8+4112==m['peak_total_bytes']==308880
    paid={}
    for phase,blob in encoder_images.items():
        assert len(blob)==4112
        suffix=f't{phase}' if isinstance(phase,int) else phase
        path=HERE/f'{stem}-{suffix}-encoder.bin'
        if materialize_state:path.write_bytes(blob)
        assert path.read_bytes()==blob
        paid[suffix]={'file':path.name,'bytes':len(blob),'sha256':sha(blob)}
    if materialize_state:
        (HERE/f'{stem}-encoder-images.json').write_text(json.dumps({'manifest_sha256':sha(manifest_path.read_bytes()),'layout':'eight head-major (128 little-endian FP32 residual, little-endian u16 recipient)','images':paid},indent=2)+'\n')
        print(json.dumps({'panel':panel,'window':w,'encoder_bytes':4112,'query_replayed':False}))
        return
    wo=load_o(src['original_o_bf16_sha256']);observations=[]
    for t in range(1,257):
        decoded=[decode(c,2) for c in pre_states[t]]
        assert all(k.shape==v.shape==(t,128) for k,v in decoded)
        output=score(arrays['q'][:,t-1,:],[x[0] for x in decoded],[x[1] for x in decoded],wo)
        teacher=arrays['teacher'][t-1].astype('<f8')
        observations.append({'t':t,'sse':float(np.square(output.astype('<f8')-teacher).sum()),'teacher_sq':float(np.square(teacher).sum()),'output_sha256':sha(output.astype('<f4').tobytes())})
    receipt={'panel':panel,'window':w,'source_sha256':src['source_file_sha256'],'manifest_sha256':sha(manifest_path.read_bytes()),'query_count':256,'observations':observations,'routes':routes,'skipped':skips,'routing_reads':{'k2_vectors':reads_k2,'bf16_vectors':reads_bf16},'visited_source_error_sq':visited_error,'skipped_source_error_sq':skipped_error,'pending_residual_sq':pending_norm}
    (HERE/f'{stem}-result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':w,'sse':sum(x['sse'] for x in observations),'routes':routes,'skips':skips}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]),'--materialize-state' in sys.argv[3:])
