"""One frozen BF16-boundary translated V2 arm and one unchanged-code V35 control."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from inputs import arrivals as owned_arrivals

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
BASE = ROOT / 'kivi-two-bit-causal'
ARRIVALS = ROOT / 'kivi-value-intern'
NATIVE = ROOT / 'kivi-two-bit-dot-native'
CENTER_SHA = '143c78b481c35b7c14699825931e7ef68b8d7edbac4fa75775effdd095c7923c'


def sha(b):
    return hashlib.sha256(b).hexdigest()


def bf16(bits):
    return (np.asarray(bits, dtype=np.uint32) << 16).view('<f4')


def round_bf16(data):
    assert data.dtype == np.float32 and np.all(np.isfinite(data))
    words = data.view('<u4')
    return ((words + np.uint32(0x7fff) + ((words >> 16)&1)) >> 16).astype('<u2')


def v2(bits):
    data = bf16(bits).reshape(4,32)
    codes = np.empty((4,32), dtype=np.uint8)
    fields = bytearray()
    for group in range(4):
        lo = float(data[group].min())
        step = (float(data[group].max())-lo)/3
        codes[group] = 0 if step == 0 else np.clip(np.rint((data[group]-lo)/step),0,3).astype(np.uint8)
        fields += np.asarray((lo,step),dtype='<f2').tobytes()
    flat = codes.ravel()
    blob = (flat[::4] | (flat[1::4]<<2) | (flat[2::4]<<4) | (flat[3::4]<<6)).tobytes()+fields
    assert len(blob)==48
    return blob


def split_original(log):
    out = {}
    at = 0
    while at < len(log):
        tag = log[at:at+1]
        t = int.from_bytes(log[at+1:at+3], 'little')
        length = 1536 if tag == b'K' else 48
        assert tag in (b'K',b'V') and (t,tag) not in out
        out[t,tag] = log[at+3:at+3+length]
        assert len(out[t,tag]) == length
        at += length+3
    return out


def image(kq,vq,kr,vr):
    return b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)


def main(window):
    assert window in range(4)
    center_image = (HERE/'center-fp16.bin').read_bytes()
    assert len(center_image)==2048 and sha(center_image)==CENTER_SHA
    center = np.frombuffer(center_image,dtype='<f2').astype(np.float32).reshape(8,128)
    o_image = (NATIVE/'original-o.bf16').read_bytes()
    assert len(o_image)==4194304 and sha(o_image)=='803995a9d5abb24c72d3ddabd50f4e656fc5eff26efaf3b626f175fc706ab499'
    o = torch.from_numpy(bf16(np.frombuffer(o_image,dtype='<u2')).reshape(1024,2048).copy())
    torch.set_num_threads(1)
    with torch.no_grad():
        bias = torch.from_numpy(np.repeat(center,2,axis=0).reshape(2048).copy()) @ o.T
    bias_image = bias.numpy().astype('<f4').tobytes()
    assert len(bias_image)==4096
    (HERE/'bias-fp32.bin').write_bytes(bias_image)
    arrivals = owned_arrivals(window)
    original_manifest_bytes = (BASE/f'held-{window}-manifest.json').read_bytes()
    original_manifest = json.loads(original_manifest_bytes)
    streams = []
    hashes = []
    for h in range(8):
        raw = (BASE/f'held-{window}-head{h}-events.bin').read_bytes()
        assert sha(raw)==original_manifest['groups'][f'kv{h}']['events_sha256']
        streams.append(split_original(raw))
        hashes.append(sha(raw))
    arms = {name: [{'kq':[],'vq':[],'kr':[],'vr':[],'events':bytearray(),'prefixes':[],'peak':0} for h in range(8)]
            for name in ('translated','v35')}
    source_sq = 0.0
    source_max = 0.0
    for t in range(1,257):
        record = arrivals[(t-1)*4098:t*4098]
        assert int.from_bytes(record[:2],'little')==t
        kraw = np.frombuffer(record,dtype='<u2',count=1024,offset=2).reshape(8,128)
        vraw = np.frombuffer(record,dtype='<u2',count=1024,offset=2050).reshape(8,128)
        source = bf16(vraw)
        centered = round_bf16((source-center).astype(np.float32))
        residual = bf16(centered)+center-source
        source_sq += float(np.square(residual.astype(np.float64)).sum())
        source_max = max(source_max,float(np.max(np.abs(residual))))
        for h in range(8):
            for name, states in arms.items():
                s=states[h]
                s['kr'].append(kraw[h].astype('<u2').tobytes())
                s['vr'].append((centered if name=='translated' else vraw)[h].astype('<u2').tobytes())
                before=image(s['kq'],s['vq'],s['kr'],s['vr'])
                s['peak']=max(s['peak'],len(before))
                row={'t':t,'before_sha256':sha(before),'before_bytes':len(before),
                     'before_counts':[len(s[x]) for x in ('kq','vq','kr','vr')]}
                if len(s['kr'])==32:
                    key=streams[h][t,b'K']
                    s['kq'].append(key);s['kr'].clear()
                    s['events']+=b'K'+t.to_bytes(2,'little')+key
                threshold=32 if name=='translated' else 35
                if len(s['vr'])>threshold:
                    source_t=t-threshold
                    token=s['vr'].pop(0)
                    if name=='translated':
                        val=v2(np.frombuffer(token,dtype='<u2'))
                    else:
                        val=streams[h][source_t+32,b'V']
                    s['vq'].append(val)
                    s['events']+=b'V'+t.to_bytes(2,'little')+val
                after=image(s['kq'],s['vq'],s['kr'],s['vr'])
                row.update(after_sha256=sha(after),after_bytes=len(after),
                           after_counts=[len(s[x]) for x in ('kq','vq','kr','vr')])
                s['prefixes'].append(row)
    records = {}
    for name, states in arms.items():
        receipts=[]
        for h,s in enumerate(states):
            path=f'held-{window}-{name}-head{h}'
            final=image(s['kq'],s['vq'],s['kr'],s['vr'])
            (HERE/f'{path}-events.bin').write_bytes(s['events'])
            (HERE/f'{path}-final.bin').write_bytes(final)
            receipts.append({'head':h,'peak_bytes':s['peak'],'final_bytes':len(final),
                             'events_sha256':sha(s['events']),'final_sha256':sha(final),
                             'prefixes':s['prefixes']})
        peak=sum(r['peak_bytes'] for r in receipts)
        final=sum(r['final_bytes'] for r in receipts)
        assert (peak,final)==((304768,249856) if name=='translated' else (309760,254848))
        records[name]={'peak_cache_bytes':peak,'final_cache_bytes':final,'heads':receipts}
    manifest={'window':window,'arrival_sha256':sha(arrivals),'original_manifest_sha256':sha(original_manifest_bytes),
              'original_head_event_sha256':hashes,'center_sha256':CENTER_SHA,
              'original_o_sha256':sha(o_image),'bias_sha256':sha(bias_image),
              'source_rounding_coordinate_sse':source_sq,'source_rounding_max_abs':source_max,
              'fixed_fields_bytes':6144,'arms':records}
    (HERE/f'held-{window}-manifest.json').write_text(json.dumps(manifest,separators=(',',':'))+'\n')
    print(json.dumps({'window':window,'translated_peak':304768,'v35_peak':309760,'source_rounding_coordinate_sse':source_sq}))


if __name__=='__main__':
    main(int(sys.argv[1]))
