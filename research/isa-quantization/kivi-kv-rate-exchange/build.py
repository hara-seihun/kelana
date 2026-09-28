"""Freeze two chronological K/V exchanges by copying donor events, never quantizing."""
import hashlib
import json
from pathlib import Path
import sys
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
TWO = ROOT / 'kivi-two-bit-causal'
FOUR = ROOT / 'skvq-global-gqa'
FIRST = ROOT / 'kivi-causal-cache'
ARRIVAL = ROOT / 'kivi-value-intern'
SPEC = {'2': (1536, 48), '4': (2560, 80)}
ARMS = {'K2V4': ('2', '4'), 'K4V2': ('4', '2')}


def sha(blob):
    return hashlib.sha256(blob).hexdigest()


def checked(path, expected):
    blob = path.read_bytes()
    assert sha(blob) == expected, path
    return blob


def source(window):
    name = f'held-{window}'
    audit_bytes = (ARRIVAL / f'{name}-manifest.json').read_bytes()
    audit = json.loads(audit_bytes)
    stream = checked(ARRIVAL / f'{name}-events.bin', audit['events_sha256'])
    assert len(stream) == 256 * 4098
    raw = np.frombuffer(stream, dtype=np.uint8).reshape(256, 4098)
    assert np.array_equal(raw[:, :2], np.arange(1, 257, dtype='<u2').view(np.uint8).reshape(256, 2))
    k = np.ascontiguousarray(raw[:, 2:2050]).view('<u2').reshape(256, 8, 128)
    v = np.ascontiguousarray(raw[:, 2050:]).view('<u2').reshape(256, 8, 128)
    two_manifest = json.loads((TWO / f'{name}-manifest.json').read_bytes())
    four_manifest = json.loads((FIRST / f'{name}-manifest.json').read_bytes())
    assert audit['baseline_manifest_sha256'] == sha((TWO / f'{name}-manifest.json').read_bytes())
    assert audit['source_fixture_sha256'] == two_manifest['fixture_sha256'] == four_manifest['fixture_sha256']
    return k, v, {'arrival_events_sha256': audit['events_sha256'],
                  'arrival_manifest_sha256': sha(audit_bytes), 'fixture_sha256': audit['source_fixture_sha256']}


def events(blob, bits):
    ksize, vsize = SPEC[bits]
    entries = {'K': [], 'V': []}
    offset = 0
    while offset < len(blob):
        kind = chr(blob[offset]); assert kind in entries
        t = int.from_bytes(blob[offset+1:offset+3], 'little')
        size = ksize if kind == 'K' else vsize
        payload = blob[offset+3:offset+3+size]
        assert len(payload) == size
        assert t == ((len(entries['K'])+1)*32 if kind == 'K' else len(entries['V'])+33)
        entries[kind].append((t, payload))
        offset += size+3
    assert len(entries['K']) == 8 and len(entries['V']) == 224
    return entries


def donor(window, head, bits):
    name = f'held-{window}'
    if bits == '2':
        manifest = json.loads((TWO / f'{name}-manifest.json').read_bytes())
        info = manifest['groups'][f'kv{head}']
        log = checked(TWO / f'{name}-head{head}-events.bin', info['events_sha256'])
        final = checked(TWO / f'{name}-head{head}-final.bin', info['final_sha256'])
        receipts = [(x['before_query_flush'], x['after_query_flush']) for x in info['prefixes']]
    elif head == 0:
        manifest = json.loads((FIRST / f'{name}-manifest.json').read_bytes())
        log = checked(FIRST / f'{name}-flush.bin', manifest['flush_log_sha256'])
        final = checked(FIRST / f'{name}-final.bin', manifest['final_sha256'])
        receipts = [(x['before_flush'], x['after_flush']) for x in manifest['prefixes']]
    else:
        manifest = json.loads((FOUR / f'{name}-kivi-manifest.json').read_bytes())
        info = manifest['groups'][f'kv{head}']
        log = checked(FOUR / f'{name}-kivi-head{head}-events.bin', info['event_log_sha256'])
        final = checked(FOUR / f'{name}-kivi-head{head}-final.bin', info['final_image_sha256'])
        receipts = [(x['before'], x['after']) for x in info['prefixes']]
    return {'events': events(log, bits), 'log_sha256': sha(log), 'final': final,
            'final_sha256': sha(final), 'receipts': receipts}


def image(kq, vq, kr, vr):
    return b''.join(kq) + b''.join(vq) + b''.join(kr) + b''.join(vr)


def counts(t, after):
    nk = t//32 if after else (t-1)//32
    nv = max(0, t-32) if after else max(0, t-33)
    return nk, nv, t-32*nk, t-nv


def donor_match(d, pre, post, t):
    for blob, receipt in ((pre, d['receipts'][t-1][0]), (post, d['receipts'][t-1][1])):
        assert sha(blob) == receipt['sha256']
        assert len(blob) == receipt.get('bytes', receipt.get('live_state_bytes'))


def run(window):
    k, v, provenance = source(window)
    donors = {(h, b): donor(window, h, b) for h in range(8) for b in SPEC}
    assert len({donors[(h, '2')]['final'] for h in range(8)}) == 8
    result = {'window': window, 'source': provenance, 'arms': {},
              'donors': {str(h): {b: {'events_sha256': donors[(h,b)]['log_sha256'],
                         'final_sha256': donors[(h,b)]['final_sha256']} for b in SPEC} for h in range(8)}}
    for arm, (kb, vb) in ARMS.items():
        group = []
        peak = 0
        for h in range(8):
            kd, vd = donors[(h,kb)], donors[(h,vb)]
            kq, vq, kr, vr = [], [], [], []
            journal = bytearray()
            prefixes = []
            for t in range(1,257):
                kr.append(k[t-1,h].tobytes()); vr.append(v[t-1,h].tobytes())
                before = image(kq,vq,kr,vr)
                # Correspondence is checked separately for both complete donor states at every prefix.
                for b in SPEC:
                    d = donors[(h,b)]; dk, dv = d['events']['K'], d['events']['V']
                    nk,nv,nkr,nvr = counts(t,False)
                    donor_pre = image([x[1] for x in dk[:nk]], [x[1] for x in dv[:nv]],kr,vr)
                    nk2,nv2,nkr2,nvr2 = counts(t,True)
                    donor_post = image([x[1] for x in dk[:nk2]], [x[1] for x in dv[:nv2]],
                                       [] if t%32==0 else kr, vr[1:] if t>32 else vr)
                    donor_match(d, donor_pre, donor_post, t)
                peak = max(peak, len(before))
                entry = {'t':t,'before':{'sha256':sha(before),'bytes':len(before)}}
                if len(kr)==32:
                    position, blob = kd['events']['K'][len(kq)]
                    assert position == t
                    journal.extend(b'K'+t.to_bytes(2,'little')+blob)
                    kq.append(blob);kr.clear()
                if len(vr)==33:
                    position, blob = vd['events']['V'][len(vq)]
                    assert position == t
                    journal.extend(b'V'+t.to_bytes(2,'little')+blob)
                    vq.append(blob);vr.pop(0)
                after = image(kq,vq,kr,vr)
                entry['after']={'sha256':sha(after),'bytes':len(after)}
                if t in (128,256):
                    (HERE/f'held-{window}-{arm}-t{t}-kv{h}.bin').write_bytes(before)
                prefixes.append(entry)
            final = image(kq,vq,kr,vr)
            assert final == after and len(kq)==8 and len(vq)==224
            (HERE/f'held-{window}-{arm}-head{h}-events.bin').write_bytes(journal)
            (HERE/f'held-{window}-{arm}-head{h}-final.bin').write_bytes(final)
            group.append({'head':h,'events_sha256':sha(journal),'final_sha256':sha(final),
                          'final_bytes':len(final),'prefixes':prefixes,
                          'donor_k_sha256':kd['log_sha256'],'donor_v_sha256':vd['log_sha256']})
        result['arms'][arm]={'k_bits':kb,'v_bits':vb,'groups':group,'peak_bytes':peak*8,
                             'final_bytes':sum(x['final_bytes'] for x in group)}
    assert result['arms']['K2V4']['peak_bytes']==361856
    assert result['arms']['K4V2']['peak_bytes']==362112
    (HERE/f'held-{window}-manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'window':window,'peaks':{a:x['peak_bytes'] for a,x in result['arms'].items()}}))

if __name__=='__main__':
    run(int(sys.argv[1]))
