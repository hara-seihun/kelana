#!/usr/bin/env python3
"""Reconcile fresh-text scale recovery with a frozen complete-model held panel."""
import hashlib
import json
from pathlib import Path
import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit/ternary')
OUT = ROOT / 'fresh-recovery'
SOURCE = ROOT / 'scale-extrapolate-1.5'
CANDIDATE = ROOT / 'fresh-scale8'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for part in iter(lambda: f.read(1 << 20), b''):
            h.update(part)
    return h.hexdigest()


def main():
    fixtures = json.loads((OUT / 'tokens.json').read_text())
    assert sha(OUT / 'tokens.npz') == fixtures['tokens_sha256']
    images = {}
    for folder in SOURCE, CANDIDATE:
        manifest = json.loads((folder / 'manifest.json').read_text())
        assert manifest['complete'] and manifest['matrix_count'] == 197
        images[folder.name] = manifest
    before, after = images[SOURCE.name], images[CANDIDATE.name]
    assert before['payload_bytes'] == after['payload_bytes'] == 128678649
    assert sha(SOURCE / 'norms.npz') == sha(CANDIDATE / 'norms.npz')
    old = {r['key']: r for r in before['matrices']}
    changed = 0
    for rec in after['matrices']:
        prev = old[rec['key']]
        left = SOURCE / (rec['key'].replace('.', '_') + '.npz')
        right = CANDIDATE / left.name
        assert sha(left) == prev['sha256'] and sha(right) == rec['sha256']
        with np.load(left) as z:
            a = {k: z[k] for k in z.files}
        with np.load(right) as z:
            b = {k: z[k] for k in z.files}
        assert a.keys() == b.keys()
        for key in a.keys() - {'scales'}:
            assert np.array_equal(a[key], b[key]), (rec['key'], key)
        changed += int(np.count_nonzero(a['scales'].view(np.uint16) != b['scales'].view(np.uint16)))
    assert len(old) == len(after['matrices'])
    arms = {}
    receipts = {}
    for name in SOURCE.name, CANDIDATE.name:
        halves = []
        for offset in 0, 8:
            path = OUT / f'{name}-{offset}-8.json'
            record = json.loads(path.read_text())
            assert record['offset'] == offset and record['windows'] == 8
            assert record['fixture_sha256'] == fixtures['tokens_sha256']
            assert record['image_manifest_sha256'] == sha(ROOT / name / 'manifest.json')
            halves += record['per_window_nll']
            receipts[path.name] = sha(path)
        arms[name] = halves
    delta = np.array(arms[SOURCE.name]) - np.array(arms[CANDIDATE.name])
    training = CANDIDATE / 'training.json'
    train = json.loads(training.read_text())
    receipt = dict(source_image=SOURCE.name, candidate_image=CANDIDATE.name,
                   source_manifest_sha256=sha(SOURCE / 'manifest.json'),
                   candidate_manifest_sha256=sha(CANDIDATE / 'manifest.json'),
                   training_sha256=sha(training), training=train,
                   fixture_sha256=fixtures['tokens_sha256'], evaluation_receipts=receipts,
                   script_sha256=sha(Path(__file__)), changed_fp16_scale_words=changed,
                   unchanged_codes_signs_shapes_norms=True, raw_payload_bytes=before['payload_bytes'],
                   bpw=before['bpw'], new_test_windows=16, predictions=16 * 255,
                   control_nll=float(np.mean(arms[SOURCE.name])),
                   candidate_nll=float(np.mean(arms[CANDIDATE.name])),
                   paired_improvement=float(np.mean(delta)),
                   paired_standard_error=float(np.std(delta, ddof=1) / np.sqrt(len(delta))),
                   improving_windows=int(np.count_nonzero(delta > 0)),
                   per_window_improvement=delta.tolist())
    (OUT / 'summary.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k: receipt[k] for k in ('control_nll', 'candidate_nll', 'paired_improvement',
                                                 'paired_standard_error', 'improving_windows',
                                                 'changed_fp16_scale_words', 'bpw')}))


if __name__ == '__main__':
    main()
