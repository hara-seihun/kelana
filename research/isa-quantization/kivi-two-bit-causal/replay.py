"""Independent paid-byte causal KIVI2 reader, full original 16-head attention/O."""
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT / 'skvq-global-gqa'))
from source import arrays, FIX_SHA, original

KEY_CHUNK = 1536
VALUE_TOKEN = 48
DONOR = ROOT / 'skvq-global-gqa'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def bf16(data):
    return (np.asarray(data, dtype=np.uint32) << 16).view(np.float32)


def unpack(packed, length):
    data = np.frombuffer(packed, dtype=np.uint8)
    assert len(data) * 4 == length
    return np.stack((data & 3, (data >> 2) & 3, (data >> 4) & 3, data >> 6), axis=1).reshape(length).astype(np.float32)


def decode(state, nk, nv, kr, vr):
    at = 0
    keys, values = [], []
    for _ in range(nk):
        digits = unpack(state[at:at+1024], 4096).reshape(32, 128); at += 1024
        fields = np.frombuffer(state, dtype='<f2', count=256, offset=at).astype(np.float32).reshape(128,2); at += 512
        assert np.isfinite(fields).all() and np.all(fields[:,1] >= 0)
        keys.append(digits * fields[None,:,1] + fields[None,:,0])
    for _ in range(nv):
        digits = unpack(state[at:at+32], 128).reshape(4,32); at += 32
        fields = np.frombuffer(state, dtype='<f2', count=8, offset=at).astype(np.float32).reshape(4,2); at += 16
        assert np.isfinite(fields).all() and np.all(fields[:,1] >= 0)
        values.append((digits * fields[:,1,None] + fields[:,0,None]).reshape(1,128))
    recent_k = np.frombuffer(state, dtype='<u2', count=kr*128, offset=at).reshape(kr,128); at += kr*256
    recent_v = np.frombuffer(state, dtype='<u2', count=vr*128, offset=at).reshape(vr,128); at += vr*256
    assert at == len(state)
    k = np.concatenate(keys + [bf16(recent_k)], axis=0) if nk else bf16(recent_k)
    v = np.concatenate(values + [bf16(recent_v)], axis=0) if nv else bf16(recent_v)
    assert k.shape == (nk*32+kr,128) and v.shape == (nv+vr,128)
    return k,v


def check_event(blob, kind, bits):
    """Verify quantizer from only the source tokens available at this flush."""
    source = bf16(bits)
    if kind == 'K':
        assert source.shape == (32,128) and len(blob) == KEY_CHUNK
        data = source
        lo, hi = source.min(axis=0), source.max(axis=0)
        actual = unpack(blob[:1024],4096).reshape(32,128)
        fields = np.frombuffer(blob, dtype='<f2', count=256, offset=1024).reshape(128,2)
    else:
        assert source.shape == (128,) and len(blob) == VALUE_TOKEN
        data = source.reshape(4,32)
        lo, hi = data.min(axis=1), data.max(axis=1)
        actual = unpack(blob[:32],128).reshape(4,32)
        fields = np.frombuffer(blob, dtype='<f2', count=8, offset=32).reshape(4,2)
    step = (hi-lo)/3
    assert np.array_equal(fields[:,0],lo.astype('<f2'))
    assert np.array_equal(fields[:,1],step.astype('<f2'))
    safe = np.where(step>0,step,1)
    if kind == 'K':
        expected = np.where(step[None,:]>0,np.clip(np.rint((data-lo[None,:])/safe[None,:]),0,3),0)
    else:
        expected = np.where(step[:,None]>0,np.clip(np.rint((data-lo[:,None])/safe[:,None]),0,3),0)
    assert np.array_equal(actual,expected)


def state(kq,vq,kr,vr):
    return b''.join(kq)+b''.join(vq)+b''.join(kr)+b''.join(vr)


def verify(blob, record, kq, vq, kr, vr):
    assert len(blob) == record['bytes'] and sha(blob) == record['sha256']
    assert (len(kq),len(vq),len(kr),len(vr)) == tuple(record[s] for s in (
        'key_quant_chunks','value_quant_tokens','key_recent_tokens','value_recent_tokens'))
    assert (len(kq)*KEY_CHUNK,len(vq)*VALUE_TOKEN,len(kr)*256,len(vr)*256) == tuple(record[s] for s in (
        'key_quant_bytes','value_quant_bytes','key_recent_bytes','value_recent_bytes'))


def run(panel,window):
    torch.set_num_threads(1)
    manifest = json.loads((HERE/f'{panel}-{window}-manifest.json').read_text())
    assert (manifest['panel'],manifest['window'],manifest['fixture_sha256']) == (panel,window,FIX_SHA)
    src = arrays(panel,window)
    keys = src['krot'].permute(1,0,2).to(torch.bfloat16).contiguous().view(torch.uint16).numpy().copy()
    values = src['value'].reshape(256,8,128)
    donor = original.arrays(panel,window)
    assert np.array_equal(keys[:,0],donor['key']) and np.array_equal(values[:,0],donor['value'])
    original_kivi = json.loads((ROOT/'kivi-causal-cache'/f'{panel}-{window}-manifest.json').read_text())
    full_kivi = json.loads((DONOR/f'{panel}-{window}-kivi-result.json').read_text())
    assert full_kivi['donor_group0_sha256'] == original_kivi['final_sha256']
    logs=[];receipts=[];finals=[]
    for h in range(8):
        entry = manifest['groups'][f'kv{h}']
        name = f'{panel}-{window}-head{h}'
        log=(HERE/f'{name}-events.bin').read_bytes()
        final=(HERE/f'{name}-final.bin').read_bytes()
        assert sha(log)==entry['events_sha256'] and len(log)==entry['events_bytes']
        assert sha(final)==entry['final_sha256'] and len(final)==entry['final_bytes']
        logs.append(log);receipts.append(entry['prefixes']);finals.append(final)
    positions=[0]*8
    kq=[[] for _ in range(8)];vq=[[] for _ in range(8)];kr=[[] for _ in range(8)];vr=[[] for _ in range(8)]
    outputs=[];kl=torch.zeros(16);peak=0
    with torch.no_grad():
        for t in range(1,257):
            decoded_k=[];decoded_v=[]
            for h in range(8):
                kr[h].append(keys[t-1,h].astype('<u2').tobytes())
                vr[h].append(values[t-1,h].astype('<u2').tobytes())
                before=state(kq[h],vq[h],kr[h],vr[h])
                verify(before,receipts[h][t-1]['before_query_flush'],kq[h],vq[h],kr[h],vr[h])
                peak=max(peak,len(before)*8)
                k,v=decode(before,len(kq[h]),len(vq[h]),len(kr[h]),len(vr[h]))
                decoded_k.append(torch.from_numpy(k.copy()))
                decoded_v.append(torch.from_numpy(v.copy()))
            key=torch.stack(decoded_k).repeat_interleave(2,dim=0)
            value=torch.stack(decoded_v).repeat_interleave(2,dim=0)
            q=src['qrot'][:,t-1]
            logits=torch.bmm(q[:,None,:],key.transpose(1,2)).squeeze(1)/math.sqrt(128)
            probs=logits.softmax(-1)
            ref=src['teacher_logp'][:,t-1,:t]
            kl+=(ref.exp()*(ref-logits.log_softmax(-1))).sum(-1)
            mixed=torch.bmm(probs[:,None,:],value).reshape(2048)
            outputs.append(mixed@src['o'].T)
            for h in range(8):
                def event(tag,length):
                    pos=positions[h];buf=logs[h]
                    assert buf[pos:pos+1]==tag and int.from_bytes(buf[pos+1:pos+3],'little')==t
                    blob=buf[pos+3:pos+3+length]
                    assert len(blob)==length
                    positions[h]+=3+length
                    return blob
                if len(kr[h])==32:
                    block=event(b'K',KEY_CHUNK)
                    check_event(block,'K',keys[t-32:t,h])
                    kq[h].append(block);kr[h].clear()
                if len(vr[h])>32:
                    block=event(b'V',VALUE_TOKEN)
                    check_event(block,'V',values[t-33,h])
                    vq[h].append(block);vr[h].pop(0)
                after=state(kq[h],vq[h],kr[h],vr[h])
                verify(after,receipts[h][t-1]['after_query_flush'],kq[h],vq[h],kr[h],vr[h])
    assert peak==manifest['peak_full_layer_bytes']==304768
    assert all(positions[h]==len(logs[h]) and state(kq[h],vq[h],kr[h],vr[h])==finals[h] for h in range(8))
    assert sum(len(x) for x in finals)==manifest['final_full_layer_bytes']==249856
    output=torch.stack(outputs);err=float((output-src['teacher']).square().sum());den=float(src['teacher'].square().sum())
    assert abs(den-full_kivi['full_o_ref_sq'])<1e-6
    result={'panel':panel,'window':window,'source_fixture_sha256':FIX_SHA,
            'peak_cache_bytes':peak,'final_cache_bytes':sum(len(x) for x in finals),
            'head_image_sha256':[sha(x) for x in finals],
            'head_events_sha256':[sha(x) for x in logs],
            'original_kivi4_final_group0_sha256':original_kivi['final_sha256'],
            'full_o_sse':err,'full_o_ref_sq':den,'head_kl':(kl/256).tolist()}
    (HERE/f'{panel}-{window}-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'full_o_rel_sq':err/den,
                      'mean_head_kl':float(kl.mean()/256),'peak':peak}))

if __name__=='__main__':
    run(sys.argv[1],int(sys.argv[2]))
