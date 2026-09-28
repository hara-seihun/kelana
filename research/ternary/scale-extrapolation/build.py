#!/usr/bin/env python3
"""Extrapolate a complete paid ternary image in its FP16 scale coordinate.

The two endpoints have identical packed trits and rotation signs. No held
example is used to fit the coefficient; this generates fixed 1.5/2.0 arms.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit/ternary')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for part in iter(lambda: f.read(1 << 20), b''):
            h.update(part)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--alpha', type=float, choices=(1.5, 2.0), required=True)
    a = p.parse_args()
    early, late = ROOT/'expanded-scale128', ROOT/'expanded-scale384'
    out = ROOT/f'scale-extrapolate-{a.alpha:g}'
    out.mkdir(exist_ok=True)
    old = json.loads((early/'manifest.json').read_text())
    current = json.loads((late/'manifest.json').read_text())
    assert old['complete'] and current['complete'] and old['payload_bytes'] == current['payload_bytes']
    assert len(old['matrices']) == len(current['matrices']) == 197
    records = []
    changed = clipped = 0
    earlier_by_key = {r['key']: r for r in old['matrices']}
    assert set(earlier_by_key) == {r['key'] for r in current['matrices']}
    for after in current['matrices']:
        before = earlier_by_key[after['key']]
        name = before['key'].replace('.', '_') + '.npz'
        b, c = early/name, late/name
        assert digest(b) == before['sha256'] and digest(c) == after['sha256']
        with np.load(b) as z: first = {k:z[k] for k in z.files}
        with np.load(c) as z: last = {k:z[k] for k in z.files}
        for k in ('codes', 'signs', 'shape', 'rotation_block'):
            assert np.array_equal(first[k], last[k]), (name, k)
        v = last['scales'].astype(np.float32) + (a.alpha-1)*(last['scales'].astype(np.float32)-first['scales'].astype(np.float32))
        assert np.isfinite(v).all()
        changed += np.count_nonzero(first['scales'].view(np.uint16) != last['scales'].view(np.uint16))
        clipped += np.count_nonzero(np.abs(v) > np.finfo(np.float16).max)
        last['scales'] = v.astype(np.float16)
        np.savez(out/name, **last)
        record = dict(after, sha256=digest(out/name), payload_bytes=sum(x.nbytes for x in last.values()), file_bytes=(out/name).stat().st_size)
        (out/name).with_suffix('.json').write_text(json.dumps(record, indent=2)+'\n')
        records.append(record)
    assert clipped == 0
    (out/'norms.npz').write_bytes((late/'norms.npz').read_bytes())
    manifest = dict(current, matrices=records)
    assert manifest['payload_bytes'] == sum(r['payload_bytes'] for r in records) + (current['payload_bytes'] - sum(r['payload_bytes'] for r in current['matrices']))
    (out/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    receipt = dict(alpha=a.alpha, early_manifest_sha256=digest(early/'manifest.json'), late_manifest_sha256=digest(late/'manifest.json'), image_manifest_sha256=digest(out/'manifest.json'), source_sha256=digest(Path(__file__)), payload_bytes=manifest['payload_bytes'], bpw=manifest['bpw'], source_changed_scale_words=int(changed), clipped_scale_words=int(clipped), matrix_count=len(records))
    (out/'construction.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps(receipt))


if __name__ == '__main__': main()
