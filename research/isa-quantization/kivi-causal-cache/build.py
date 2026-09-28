"""Online KIVI 4/4-bit G32 R32 cache state, source-only insertion and flush."""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from source import HERE,arrays,FIX_SHA

GROUP=32
RESIDUAL=32
K_CHUNK=32*128//2+128*4  # nibble codes + 128 FP16 origin/scale pairs
V_TOKEN=128//2+4*4       # nibble codes + four FP16 origin/scale pairs


def from_bf16(bits):
    return (np.asarray(bits,dtype=np.uint32)<<16).view(np.float32)


def packed_nibbles(code):
    flat=np.asarray(code,dtype=np.uint8).ravel()
    assert len(flat)%2==0 and np.all(flat<16)
    return (flat[::2]|(flat[1::2]<<4)).tobytes()


def quantize(data):
    """One group: source min/max, unsigned 0..15, nearest-even, paid FP16 fields."""
    data=np.asarray(data,dtype=np.float32)
    origin=float(data.min());maximum=float(data.max())
    step=(maximum-origin)/15
    if step==0:codes=np.zeros(len(data),dtype=np.uint8)
    else:codes=np.clip(np.rint((data-origin)/step),0,15).astype(np.uint8)
    fields=np.array([origin,step],dtype='<f2')
    assert np.isfinite(fields).all() and fields[1]>=0
    return codes,fields.tobytes()


def key_chunk(bits):
    assert np.asarray(bits).shape==(32,128)
    data=from_bf16(bits)
    code=np.empty((32,128),dtype=np.uint8);fields=bytearray()
    for d in range(128):
        code[:,d],field=quantize(data[:,d]);fields+=field
    blob=packed_nibbles(code)+fields
    assert len(blob)==K_CHUNK
    return blob


def value_token(bits):
    assert np.asarray(bits).shape==(128,)
    data=from_bf16(bits)
    code=np.empty(128,dtype=np.uint8);fields=bytearray()
    for group in range(4):
        code[group*32:(group+1)*32],field=quantize(data[group*32:(group+1)*32]);fields+=field
    blob=packed_nibbles(code)+fields
    assert len(blob)==V_TOKEN
    return blob


def serialize(kq,vq,kr,vr):
    return b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)


def sizes(kq,vq,kr,vr):
    return {'key_quant_tokens':len(kq)*32,'value_quant_tokens':len(vq),
            'key_recent_tokens':len(kr),'value_recent_tokens':len(vr),
            'key_code_and_fields_bytes':len(kq)*K_CHUNK,
            'value_code_and_fields_bytes':len(vq)*V_TOKEN,
            'key_recent_bytes':len(kr)*256,'value_recent_bytes':len(vr)*256,
            'live_state_bytes':len(kq)*K_CHUNK+len(vq)*V_TOKEN+(len(kr)+len(vr))*256}


def run(panel,window):
    src=arrays(panel,window)
    kq=[];vq=[];kr=[];vr=[];receipts=[];peak=0;events=bytearray()
    for t in range(1,257):
        kr.append(src['key'][t-1].astype('<u2').tobytes())
        vr.append(src['value'][t-1].astype('<u2').tobytes())
        pre=serialize(kq,vq,kr,vr);size=sizes(kq,vq,kr,vr)
        assert len(pre)==size['live_state_bytes']
        peak=max(peak,len(pre))
        row={'position':t-1,'before_flush':{**size,'sha256':hashlib.sha256(pre).hexdigest()}}
        if t in (31,32,33,255,256):(HERE/f'{panel}-{window}-pre-{t}.bin').write_bytes(pre)
        if len(kr)==RESIDUAL:
            slab=np.frombuffer(b''.join(kr),dtype='<u2').reshape(32,128)
            blob=key_chunk(slab);kq.append(blob);kr=[]
            events+=b'K'+t.to_bytes(2,'little')+blob
        if len(vr)>RESIDUAL:
            blob=value_token(np.frombuffer(vr.pop(0),dtype='<u2'))
            vq.append(blob);events+=b'V'+t.to_bytes(2,'little')+blob
        post=serialize(kq,vq,kr,vr)
        row['after_flush']={**sizes(kq,vq,kr,vr),'sha256':hashlib.sha256(post).hexdigest()}
        if t in (31,32,33,255,256):(HERE/f'{panel}-{window}-post-{t}.bin').write_bytes(post)
        receipts.append(row)
    final=serialize(kq,vq,kr,vr)
    (HERE/f'{panel}-{window}-final.bin').write_bytes(final)
    (HERE/f'{panel}-{window}-flush.bin').write_bytes(events)
    result={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,
            'source_checkpoint':'qwen3-0.6b BF16 c1899de289a04d12100db370d81485cdf75e47ca',
            'method':'KIVI 4-bit K/V, channel-token32 K, token-coordinate32 V, recent32',
            'field_dtype':'FP16 min and step','recent_dtype':'Qwen BF16',
            'max_live_state_bytes':peak,'final_postflush_bytes':len(final),
            'final_sha256':hashlib.sha256(final).hexdigest(),
            'flush_log_sha256':hashlib.sha256(events).hexdigest(),
            'flush_log_bytes':len(events),'flush_log_is_evidence_not_live_state':True,
            'prefixes':receipts}
    (HERE/f'{panel}-{window}-manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'peak':peak,'final':len(final),
                      'final_sha256':result['final_sha256']},indent=2))

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
