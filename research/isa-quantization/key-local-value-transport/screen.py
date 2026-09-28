"""One frozen causal K-nearest residual routing screen, source geometry only."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
OWNER = HERE.parent / 'contextual-value-feedback'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def bf16(raw):
    return (np.asarray(raw, dtype='<u4') << 16).view('<f4')


def unpack_k_token(blob, token):
    assert len(blob) == 1536 and 0 <= token < 32
    b = np.frombuffer(blob, dtype='u1', count=32, offset=32*token)
    digits = np.stack((b & 3, (b >> 2) & 3, (b >> 4) & 3, b >> 6), axis=-1).reshape(128)
    fields = np.frombuffer(blob, dtype='<f2', count=256, offset=1024).astype('<f4').reshape(128, 2)
    return fields[:, 0] + digits.astype('<f4') * fields[:, 1]


def squared(a, b):
    difference = np.subtract(a, b, dtype='<f4')
    return float(np.sum(difference * difference, dtype='<f8'))


def one(panel, window):
    stem = f'{panel}-{window}'
    src_path = OWNER / f'{stem}-source.npz'
    receipt = json.loads((OWNER / f'{stem}-source.json').read_text())
    assert sha(src_path.read_bytes()) == receipt['source_file_sha256']
    with np.load(src_path) as source:
        keys = source['k'].copy()
    assert keys.shape == (256, 8, 128)
    assert sha(keys.tobytes()) == receipt['arrays']['k']['sha256']
    manifest_path = OWNER / f'{stem}-manifest.json'
    manifest = json.loads(manifest_path.read_text())
    assert manifest['source_sha256'] == receipt['source_file_sha256']
    heads = []
    for h in range(8):
        meta = manifest['arms']['original']['heads'][h]
        event_path = OWNER / f'{stem}-original-h{h}-events.bin'
        log = event_path.read_bytes()
        assert sha(log) == meta['events_sha256']
        events = []
        p = 0
        while p < len(log):
            kind = chr(log[p]); when = int.from_bytes(log[p+1:p+3], 'little')
            assert kind in ('K', 'V')
            size = 1536 if kind == 'K' else 48
            events.append((kind, when, log[p+3:p+3+size])); p += 3+size
        assert p == len(log)
        event_i = 0
        chunks = []
        recent = []
        recipient = None
        chosen = []
        flushes = 0
        skipped = 0
        endpoint = {}
        for t in range(1, 257):
            recent.append(keys[t-1, h].astype('<u2').tobytes())
            assert len(chunks) == meta['prefix'][t-1]['k_chunks']
            assert len(recent) == meta['prefix'][t-1]['recent_k']
            if len(recent) == 32:
                kind, when, blob = events[event_i]; event_i += 1
                assert (kind, when) == ('K', t)
                chunks.append(blob); recent = []
            if t < 33:
                continue
            kind, when, _ = events[event_i]; event_i += 1
            assert (kind, when) == ('V', t)
            i = t-32
            flushes += 1
            if t in (128, 256):
                assert recipient is not None
                now = key_at(recipient['target'], chunks, recent)
                origin = key_at(recipient['source'], chunks, recent)
                endpoint[str(t)] = {'oldest_v':i, 'pending_source':recipient['source'],
                                    'pending_target':recipient['target'],
                                    'target_flush_now':recipient['target'] == i,
                                    'selected_distance':recipient['chosen_distance'],
                                    'current_distance':squared(origin, now),
                                    'key_changed':recipient['chosen_key_sha256'] != sha(now.tobytes())}
            if recipient is not None and i != recipient['target']:
                skipped += 1
                continue
            if recipient is not None:
                actual = key_at(i, chunks, recent)
                current_distance = squared(key_at(recipient['source'], chunks, recent), actual)
                recipient['distance_at_target_flush'] = current_distance
                recipient['distance_drift'] = current_distance-recipient['chosen_distance']
                recipient['key_changed'] = recipient['chosen_key_sha256'] != sha(actual.tobytes())
            base = key_at(i, chunks, recent)
            candidate = [key_at(j, chunks, recent) for j in range(i+1, t+1)]
            distances = [squared(base, k) for k in candidate]
            assert len(distances) == 32 and all(np.isfinite(distances))
            choice = int(np.argmin(distances))
            recipient = {'source':i, 'target':i+1+choice, 'wait':choice+1,
                         'chosen_distance':distances[choice], 'successor_distance':distances[0],
                         'chosen_key_sha256':sha(candidate[choice].tobytes())}
            chosen.append(recipient)
            if t in (128, 256):
                endpoint[str(t)]['new_target_if_visited'] = recipient['target']
        assert event_i == len(events)
        assert sum(k == 'K' for k,_,_ in events) == 8
        assert sum(k == 'V' for k,_,_ in events) == 224
        assert flushes == skipped + len(chosen)
        assert all(r['target'] <= 256 for r in chosen)
        heads.append({'head':h, 'event_sha256':meta['events_sha256'], 'flushes':flushes,
                      'skipped':skipped, 'routes':chosen, 'endpoint':endpoint,
                      'unresolved_target':recipient['target'] if 'distance_at_target_flush' not in recipient else None})
    out = {'panel':panel, 'window':window, 'rule':'K2-cache nearest among 32 younger recent-V, earliest token tie, one pending recipient/head',
           'source_sha256':receipt['source_file_sha256'], 'k_sha256':receipt['arrays']['k']['sha256'],
           'manifest_sha256':sha(manifest_path.read_bytes()), 'heads':heads}
    (HERE / f'{stem}.json').write_text(json.dumps(out, indent=2)+'\n')
    print(json.dumps({'panel':panel, 'window':window, 'routes':sum(len(h['routes']) for h in heads),
                      'skipped':sum(h['skipped'] for h in heads)}))


def key_at(position, chunks, recent):
    idx = position-1
    if idx < len(chunks)*32:
        return unpack_k_token(chunks[idx//32], idx%32)
    assert idx-len(chunks)*32 < len(recent)
    return bf16(np.frombuffer(recent[idx-len(chunks)*32], dtype='<u2'))


if __name__ == '__main__':
    one(sys.argv[1], int(sys.argv[2]))
