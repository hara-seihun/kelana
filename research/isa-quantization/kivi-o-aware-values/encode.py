"""Frozen one-pass O-aware V digits; original paid KIVI2 source arrivals, no model replay."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from inputs import check as check_inputs

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
BASE = ROOT / 'kivi-two-bit-causal'
SOURCE = ROOT / 'kivi-value-intern'
PAID = ROOT / 'kivi-two-bit-dot-native'


def sha(b):
    return hashlib.sha256(b).hexdigest()


def bf16(b):
    return (np.asarray(b, dtype=np.uint32) << 16).view('<f4')


def o_blocks():
    data = (PAID / 'original-o.bf16').read_bytes()
    assert sha(data) == json.loads((PAID / 'snapshots.json').read_text())['original_o_sha256']
    o = bf16(np.frombuffer(data, dtype='<u2')).reshape(1024, 2048)
    return [np.ascontiguousarray(o[:, 256*h:256*(h+1)].reshape(1024, 2, 128).transpose(1, 0, 2).reshape(2048, 128)) for h in range(8)]


def gram(blocks):
    return [np.ascontiguousarray(b.T @ b) for b in blocks]


def codes(b):
    p = np.frombuffer(b, dtype=np.uint8)
    return np.stack((p & 3, (p >> 2) & 3, (p >> 4) & 3, p >> 6), axis=1).reshape(-1)


def pack(c):
    c = np.asarray(c, dtype=np.uint8)
    return (c[::4] | (c[1::4] << 2) | (c[2::4] << 4) | (c[3::4] << 6)).tobytes()


def token(source, baseline, g):
    assert len(source) == 256 and len(baseline) == 48
    fields = baseline[32:]
    pair = np.frombuffer(fields, dtype='<f2').astype('<f4').reshape(4, 2)
    origin, step = np.repeat(pair[:, 0], 32), np.repeat(pair[:, 1], 32)
    v = bf16(np.frombuffer(source, dtype='<u2'))
    c = codes(baseline[:32]).copy()
    assert np.array_equal(np.frombuffer(fields, dtype='<f2').reshape(4,2)[:,0], v.reshape(4,32).min(1).astype('<f2'))
    assert np.array_equal(np.frombuffer(fields, dtype='<f2').reshape(4,2)[:,1], ((v.reshape(4,32).max(1)-v.reshape(4,32).min(1))/3).astype('<f2'))
    e = (origin + step*c.astype('<f4') - v).astype('<f4')
    before = float(np.dot(e, g @ e))
    r = g @ e
    changed = 0
    for j in range(128):
        old = int(c[j]); d = (np.arange(4, dtype='<f4') - old) * step[j]
        # Every possible represented candidate, with ascending-code tie breaking.
        scores = 2*d*r[j] + d*d*g[j,j]
        winner = int(np.argmin(scores))
        if winner != old:
            delta = float(d[winner]); e[j] += delta; r += delta*g[:,j]; c[j] = winner; changed += 1
    blob = pack(c) + fields
    assert blob[32:] == baseline[32:] and len(blob) == 48
    return blob, before, float(np.dot(e, g @ e)), changed


def run(window):
    check_inputs(window)
    matrices = gram(o_blocks())
    name = f'held-{window}'
    arrivals = (SOURCE / f'{name}-events.bin').read_bytes()
    assert sha(arrivals) == json.loads((SOURCE / f'{name}-manifest.json').read_text())['events_sha256']
    owner = json.loads((BASE / f'{name}-manifest.json').read_text())
    old = [(BASE / f'{name}-head{h}-events.bin').read_bytes() for h in range(8)]
    for h in range(8):
        assert sha(old[h]) == owner['groups'][f'kv{h}']['events_sha256']
    offsets = [0]*8
    logs = [bytearray() for _ in range(8)]
    kq=[[] for _ in range(8)];vq=[[] for _ in range(8)];kr=[[] for _ in range(8)];vr=[[] for _ in range(8)]
    receipts=[[] for _ in range(8)];starts=[];ends=[];changes=0
    snapshots={}
    for t in range(1,257):
        arrival=arrivals[(t-1)*4098:t*4098]
        assert len(arrival)==4098 and int.from_bytes(arrival[:2],'little')==t
        k=arrival[2:2050];v=arrival[2050:]
        for h in range(8):
            kr[h].append(k[h*256:(h+1)*256]);vr[h].append(v[h*256:(h+1)*256])
            before=b''.join(kq[h]+vq[h]+kr[h]+vr[h])
            ref_before=owner['groups'][f'kv{h}']['prefixes'][t-1]['before_query_flush']
            assert len(before)==ref_before['bytes']
            if t<=33:assert sha(before)==ref_before['sha256']
            if t in (128,256):snapshots[(t,h)]=before
            if len(kr[h])==32:
                at=offsets[h];event=old[h][at:at+1539]
                assert event[:1]==b'K' and int.from_bytes(event[1:3],'little')==t and len(event)==1539
                kq[h].append(event[3:]);logs[h]+=event;offsets[h]+=1539;kr[h].clear()
            if len(vr[h])>32:
                at=offsets[h];event=old[h][at:at+51]
                assert event[:1]==b'V' and int.from_bytes(event[1:3],'little')==t and len(event)==51
                source=vr[h].pop(0)
                token_bytes,before_obj,after_obj,nchange=token(source,event[3:],matrices[h])
                vq[h].append(token_bytes);logs[h]+=b'V'+event[1:3]+token_bytes;offsets[h]+=51
                starts.append(before_obj);ends.append(after_obj);changes+=nchange
            after=b''.join(kq[h]+vq[h]+kr[h]+vr[h])
            ref=owner['groups'][f'kv{h}']['prefixes'][t-1]['after_query_flush']
            assert len(after)==ref['bytes']
            receipts[h].append({'before_sha256':sha(before),'after_sha256':sha(after)})
    assert all(offsets[h]==len(old[h]) for h in range(8))
    records=[]
    for h in range(8):
        final=b''.join(kq[h]+vq[h]+kr[h]+vr[h])
        assert len(final)==31232 and len(logs[h])==len(old[h])
        prefix=f'{name}-head{h}'
        (HERE/f'{prefix}-events.bin').write_bytes(logs[h])
        (HERE/f'{prefix}-final.bin').write_bytes(final)
        records.append({'events_sha256':sha(logs[h]),'final_sha256':sha(final),'original_events_sha256':sha(old[h]),'prefixes':receipts[h]})
    for (t,h),data in snapshots.items():
        (HERE/f'{name}-t{t}-kv{h}.bin').write_bytes(data)
    result={'window':window,'source_arrivals_sha256':sha(arrivals),'original_o_sha256':json.loads((PAID/'snapshots.json').read_text())['original_o_sha256'],
            'gram_sha256':[sha(x.astype('<f4').tobytes()) for x in matrices],
            'source_objective_initial_sum':sum(starts),'source_objective_final_sum':sum(ends),
            'changed_digits':changes,'records':len(starts),'heads':records,
            'peak_cache_bytes':304768,'final_cache_bytes':249856}
    (HERE/f'{name}-manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'window':window,'source_initial':sum(starts),'source_final':sum(ends),'changed':changes}))

if __name__=='__main__':run(int(sys.argv[1]))
