"""Frozen event-byte composition: metric-K/folded-V R32 or original-K/folded-V R45.

No encoder, quantizer or fitted parameter is invoked here. Each event payload
comes from the named frozen donor for that same source token and available time.
"""
from pathlib import Path
import hashlib
import json
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
FOLD=ROOT/'kivi-v-channel-fold'
METRIC=ROOT/'kivi-response-metric'
ORIGINAL=ROOT/'kivi-causal-cache'
K_BYTES=2560;V_BYTES=80
sys.path.insert(0,str(FOLD))
from source import arrays


def sha(b):return hashlib.sha256(b).hexdigest()


def events(path,manifest):
    blob=path.read_bytes()
    assert sha(blob)==manifest['flush_log_sha256']
    k={};v={};at=0
    while at<len(blob):
        letter=blob[at:at+1];t=int.from_bytes(blob[at+1:at+3],'little')
        size=K_BYTES if letter==b'K' else V_BYTES
        assert letter in (b'K',b'V')
        payload=blob[at+3:at+3+size];assert len(payload)==size
        if letter==b'K':assert t not in k;k[t]=payload
        else:assert t not in v;v[t]=payload
        at+=3+size
    assert len(k)==8 and len(v)==224
    return k,v


def donors(panel,window):
    folded=json.loads((FOLD/f'{panel}-{window}-manifest.json').read_text())
    metric=json.loads((METRIC/f'{panel}-{window}.json').read_text())
    original=json.loads((ORIGINAL/f'{panel}-{window}-manifest.json').read_text())
    f_k,f_v=events(FOLD/f'{panel}-{window}-flush.bin',folded)
    m_k,_=events(METRIC/f'{panel}-{window}-flush.bin',metric)
    o_k,_=events(ORIGINAL/f'{panel}-{window}-flush.bin',original)
    assert f_k==o_k  # Physical V/O reordering changes no source K byte.
    assert all(m_k[t][2048:]==f_k[t][2048:] for t in f_k)
    assert metric['metric_fp16_sha256']==json.loads((METRIC/'metric-manifest.json').read_text())['metric_image_sha256']
    return f_k,f_v,m_k,{
        'folded_source_receipt_sha256':sha((FOLD/'source-image.json').read_bytes()),
        'folded_v_source_sha256':sha((FOLD/'v-replacement.bf16').read_bytes()),
        'folded_o_source_sha256':sha((FOLD/'o-replacement.bf16').read_bytes()),
        'metric_image_sha256':sha((METRIC/'metric-fp16.bin').read_bytes()),
        'folded_final_sha256':folded['final_sha256'],
        'folded_log_sha256':folded['flush_log_sha256'],
        'metric_k_original_v_final_sha256':metric['final_sha256'],
        'metric_k_original_v_log_sha256':metric['flush_log_sha256'],
        'original_kivi_log_sha256':original['flush_log_sha256']}


def build(panel,window):
    src=arrays(panel,window)
    original_k,folded_v,metric_k,receipt=donors(panel,window)
    assert len(src['key'])==len(src['value'])==256
    for arm in ('A','B'):
        k_events=metric_k if arm=='A' else original_k
        residual=32 if arm=='A' else 45
        kq=[];vq=[];kr=[];vr=[];log=bytearray();prefix=[];peak=0
        for t in range(1,257):
            kr.append(src['key'][t-1].astype('<u2').tobytes())
            vr.append(src['value'][t-1].astype('<u2').tobytes())
            state=b''.join(kq+vq+kr+vr)
            assert len(kq)*32+len(kr)==len(vq)+len(vr)==t
            peak=max(peak,len(state))
            prefix.append({'position':t-1,'preflush_sha256':sha(state),'preflush_bytes':len(state),
                           'quant_k':len(kq)*32,'recent_k':len(kr),'quant_v':len(vq),'recent_v':len(vr)})
            if len(kr)==32:
                payload=k_events[t];kq.append(payload);kr=[]
                log+=b'K'+t.to_bytes(2,'little')+payload
            if len(vr)>residual:
                # Same original folded V token was generated at source flush
                # token+33; later retention changes only event timing.
                token=t-residual-1
                payload=folded_v[token+33]
                assert token==len(vq)
                vq.append(payload);vr.pop(0)
                log+=b'V'+t.to_bytes(2,'little')+payload
        final=b''.join(kq+vq+kr+vr)
        expected_peak=52400 if arm=='A' else 54688
        expected_final=46592 if arm=='A' else 48880
        assert peak==expected_peak and len(final)==expected_final
        assert len(kq)==8 and len(vq)==(224 if arm=='A' else 211)
        result={'panel':panel,'window':window,'arm':arm,'donors':receipt,
                'state_peak_bytes':peak,'metric_model_bytes':2304 if arm=='A' else 0,
                'complete_peak_bytes':peak+(2304 if arm=='A' else 0),
                'state_final_bytes':len(final),'complete_final_bytes':len(final)+(2304 if arm=='A' else 0),
                'k_events':8,'v_events':len(vq),
                'final_sha256':sha(final),'flush_log_sha256':sha(log)}
        (HERE/f'{panel}-{window}-{arm}-final.bin').write_bytes(final)
        (HERE/f'{panel}-{window}-{arm}-flush.bin').write_bytes(log)
        (HERE/f'{panel}-{window}-{arm}-prefixes.json').write_text(json.dumps(prefix)+'\n')
        (HERE/f'{panel}-{window}-{arm}-manifest.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps({'panel':panel,'window':window,'arm':arm,'peak':result['complete_peak_bytes'],
                          'image_sha256':result['final_sha256']}))

if __name__=='__main__':build(sys.argv[1],int(sys.argv[2]))
