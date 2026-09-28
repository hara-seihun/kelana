"""One paid alphabet per layer, original chronology and donor fields, one window/call."""
import json,sys,io
from pathlib import Path
import numpy as np
from fit import HERE,ROOT,BASE,CTX,ARR,sha,checked,bf16,donor

def input_source(layer,panel,w):
    if layer==0:
        assert panel=='held'
        m=json.loads((ARR/f'{panel}-{w}-manifest.json').read_text())
        raw=checked(ARR/f'{panel}-{w}-events.bin',m['events_sha256'])
        records=np.frombuffer(raw,dtype='u1').reshape(256,4098)
        assert np.array_equal(records[:,:2].copy().view('<u2').ravel(),np.arange(1,257))
        assert sha((BASE/f'{panel}-{w}-manifest.json').read_bytes())==m['baseline_manifest_sha256']
        return records[:,2:2050].copy().view('<u2').reshape(256,8,128),records[:,2050:].copy().view('<u2').reshape(256,8,128),{'source_sha256':m['events_sha256'],'source_owner':'kivi-value-intern'}
    assert panel in ('train','validation')
    r=json.loads((CTX/f'{panel}-{w}-source.json').read_text())
    raw=checked(CTX/f'{panel}-{w}-source.npz',r['source_file_sha256'])
    with np.load(io.BytesIO(raw)) as f:k=f['k'].copy();v=f['v'].copy()
    assert k.shape==v.shape==(256,8,128)
    assert sha(k.tobytes())==r['arrays']['k']['sha256'] and sha(v.tobytes())==r['arrays']['v']['sha256']
    return k,v,{'source_sha256':r['source_file_sha256'],'source_owner':'contextual-value-feedback','k_sha256':sha(k.tobytes()),'v_sha256':sha(v.tobytes())}

def actual_values(field,table):
    f=np.frombuffer(field,dtype='<f2').astype('<f4').reshape(4,2)
    return np.add(f[:,0,None],np.multiply(f[:,1,None],table[None,:],dtype='<f4'),dtype='<f4')

def encode(src,old,table):
    levels=actual_values(old[32:],table)
    x=bf16(src).astype('f8').reshape(4,32)
    err=np.square(x[:,:,None]-levels[:,None,:].astype('f8'))
    codes=np.argmin(err,axis=-1).reshape(128).astype('u1')
    packed=codes[::4]|(codes[1::4]<<2)|(codes[2::4]<<4)|(codes[3::4]<<6)
    blob=packed.tobytes()+old[32:]
    assert len(blob)==48
    return blob

def state(kq,vq,kr,vr):return b''.join(kq+vq+kr+vr)

def run(layer,panel,w):
    k,v,source=input_source(layer,panel,w)
    fit=json.loads((HERE/f'layer{layer}-fit.json').read_text())
    table=np.frombuffer(checked(HERE/f'layer{layer}-alphabet.f32',fit['table_sha256']),dtype='<f4')
    heads=[]
    for h in range(8):
        orig_k,orig_v,owner=donor(layer,panel,w,h)
        log=bytearray();kq=[];vq=[];kr=[];vr=[];prefix=[];peak=0
        for t in range(1,257):
            kr.append(k[t-1,h].astype('<u2').tobytes());vr.append(v[t-1,h].astype('<u2').tobytes())
            pre=state(kq,vq,kr,vr);peak=max(peak,len(pre))
            receipt={'t':t,'before_sha256':sha(pre),'before_bytes':len(pre)}
            if t in (128,256):
                p=HERE/f'{panel}-{w}-layer{layer}-t{t}-h{h}.bin';p.write_bytes(pre);receipt['image_sha256']=sha(pre)
            if len(kr)==32:
                blob=orig_k[len(kq)][1];log+=b'K'+t.to_bytes(2,'little')+blob;kq.append(blob);kr=[]
            if len(vr)==33:
                src=np.frombuffer(vr.pop(0),dtype='<u2');blob=encode(src,orig_v[len(vq)][1],table)
                log+=b'V'+t.to_bytes(2,'little')+blob;vq.append(blob)
            post=state(kq,vq,kr,vr)
            receipt.update(after_sha256=sha(post),after_bytes=len(post));prefix.append(receipt)
        final=state(kq,vq,kr,vr);stem=f'{panel}-{w}-layer{layer}-h{h}'
        (HERE/f'{stem}-events.bin').write_bytes(log);(HERE/f'{stem}-final.bin').write_bytes(final)
        assert len(vq)==224 and len(kq)==8 and peak==38096 and len(final)==31232
        heads.append({'h':h,'original_events_sha256':owner['events_sha256'],'events_sha256':sha(log),'final_sha256':sha(final),'peak_bytes':peak,'final_bytes':len(final),'prefix':prefix})
    receipt={'layer':layer,'panel':panel,'window':w,'source':source,'table_sha256':fit['table_sha256'],'original_o_sha256':fit['original_o_sha256'],'peak_dynamic_bytes':304768,'final_dynamic_bytes':249856,'shared_table_bytes':16,'heads':heads}
    (HERE/f'{panel}-{w}-layer{layer}-manifest.json').write_text(json.dumps(receipt,separators=(',',':'))+'\n')
    print(json.dumps({'layer':layer,'panel':panel,'window':w,'event_sha256':[h['events_sha256'] for h in heads]}))
if __name__=='__main__':run(int(sys.argv[1]),sys.argv[2],int(sys.argv[3]))
