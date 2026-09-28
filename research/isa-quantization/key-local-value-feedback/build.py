"""Fixed chronological key-local residual encoder; one paid window per invocation."""
import json,sys
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent
OWNER=HERE.parent/'contextual-value-feedback'
sys.path.insert(0,str(OWNER))
from custody import source,sha
from build import val,state
import importlib.util
spec=importlib.util.spec_from_file_location('key_local_screen',HERE.parent/'key-local-value-transport'/'screen.py')
geometry=importlib.util.module_from_spec(spec);spec.loader.exec_module(geometry)
key_at,squared=geometry.key_at,geometry.squared

def events(blob):
    p=0;out=[]
    while p<len(blob):
        kind=chr(blob[p]);size=1536 if kind=='K' else 48
        assert kind in ('K','V') and p+3+size<=len(blob)
        out.append((kind,int.from_bytes(blob[p+1:p+3],'little'),blob[p+3:p+3+size]));p+=3+size
    return out

def run(panel,w):
    arrays,src=source(panel,w);stem=f'{panel}-{w}'
    original=json.loads((OWNER/f'{stem}-manifest.json').read_text())
    assert original['source_sha256']==src['source_file_sha256']
    heads=[];encoder_images={128:bytearray(),256:bytearray(),'final':bytearray()}
    for h in range(8):
        original_log=(OWNER/f'{stem}-original-h{h}-events.bin').read_bytes()
        om=original['arms']['original']['heads'][h]
        assert sha(original_log)==om['events_sha256']
        reference=events(original_log);idx=0
        kq=[];vq=[];kr=[];vr=[];residual=np.zeros(128,dtype='<f4');recipient=1
        log=bytearray();prefix=[];routes=[];peak=0;skipped=0
        for t in range(1,257):
            kr.append(arrays['k'][t-1,h].astype('<u2').tobytes())
            vr.append(arrays['v'][t-1,h].astype('<u2').tobytes())
            pre=state(kq,vq,kr,vr);peak=max(peak,len(pre))
            r={'t':t,'pre_sha256':sha(pre),'pre_bytes':len(pre),'residual_before_sha256':sha(residual.tobytes()),'recipient_before':recipient}
            if t in (128,256):
                name=f'{stem}-t{t}-h{h}.bin';(HERE/name).write_bytes(pre);r['image_file']=name
                encoder_images[t]+=residual.tobytes()+recipient.to_bytes(2,'little')
            if len(kr)==32:
                kind,when,blob=reference[idx];idx+=1;assert(kind,when)==('K',t)
                kq.append(blob);kr=[];log+=b'K'+t.to_bytes(2,'little')+blob
            if len(vr)==33:
                kind,when,base=reference[idx];idx+=1;assert(kind,when)==('V',t)
                i=t-32;raw=np.frombuffer(vr.pop(0),dtype='<u2')
                if i==recipient:
                    blob,residual=val(raw,2,residual)
                    origin=key_at(i,kq,kr)
                    choices=[squared(origin,key_at(j,kq,kr)) for j in range(i+1,t+1)]
                    assert len(choices)==32 and all(np.isfinite(choices))
                    recipient=i+1+int(np.argmin(choices))
                    routes.append({'source':i,'target':recipient,'distance':choices[recipient-i-1]})
                else:
                    blob=base;skipped+=1
                vq.append(blob);log+=b'V'+t.to_bytes(2,'little')+blob
            post=state(kq,vq,kr,vr)
            r.update(post_sha256=sha(post),post_bytes=len(post),residual_after_sha256=sha(residual.tobytes()),recipient_after=recipient)
            prefix.append(r)
        assert idx==len(reference)==232 and len(routes)+skipped==224
        encoder_images['final']+=residual.tobytes()+recipient.to_bytes(2,'little')
        final=state(kq,vq,kr,vr);name=f'{stem}-h{h}'
        (HERE/f'{name}-events.bin').write_bytes(log)
        (HERE/f'{name}-final.bin').write_bytes(final)
        heads.append({'h':h,'original_event_sha256':om['events_sha256'],'events_sha256':sha(log),'final_sha256':sha(final),'final_bytes':len(final),'peak_bytes':peak,'residual_final_sha256':sha(residual.tobytes()),'recipient_final':recipient,'routes':routes,'skipped':skipped,'prefix':prefix})
    assert max(x['peak_bytes'] for x in heads)*8+4112==308880
    assert sum(x['final_bytes'] for x in heads)+4112==253968
    manifest={'panel':panel,'window':w,'source_sha256':src['source_file_sha256'],'original_manifest_sha256':sha((OWNER/f'{stem}-manifest.json').read_bytes()),'peak_total_bytes':308880,'final_total_bytes':253968,'heads':heads}
    for phase,blob in encoder_images.items():
        assert len(blob)==4112
        suffix=f't{phase}' if isinstance(phase,int) else phase
        (HERE/f'{stem}-{suffix}-encoder.bin').write_bytes(blob)
    (HERE/f'{stem}-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':w,'routes':sum(len(x['routes']) for x in heads),'skipped':sum(x['skipped'] for x in heads)}))
if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
