"""Pin existing source/control inputs without recomputing an attention output."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent


def check(window):
    assert window in range(4)
    seen = {}

    def read(path, expected=None):
        raw = path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if expected is not None:
            assert digest == expected, path
        seen[str(path.relative_to(ROOT))] = digest
        return raw

    def document(path, expected=None):
        return json.loads(read(path, expected))

    tag = f'held-{window}'
    paid = ROOT / 'kivi-two-bit-dot-native'
    attribution = document(ROOT / 'kivi-two-bit-error-directions/results.json')
    snapshots = document(paid / 'snapshots.json', attribution['snapshot_manifest_sha256'])
    read(paid / 'original-o.bf16', snapshots['original_o_sha256'])
    arrival = document(ROOT / f'kivi-value-intern/{tag}-manifest.json')
    read(ROOT / f'kivi-value-intern/{tag}-events.bin', arrival['events_sha256'])
    base = document(ROOT / f'kivi-two-bit-causal/{tag}-manifest.json', arrival['baseline_manifest_sha256'])
    assert base['fixture_sha256'] == arrival['source_fixture_sha256'] == snapshots['fixture_sha256']
    for h in range(8):
        read(ROOT / f'kivi-two-bit-causal/{tag}-head{h}-events.bin', base['groups'][f'kv{h}']['events_sha256'])
    states = [s for s in snapshots['states'] if s['window'] == window]
    assert sorted(s['position'] for s in states) == [128, 256]
    for state in states:
        label = state['tag']
        for suffix, key in [('q', 'query_sha256'), ('teacher', 'teacher_sha256'),
                            ('conventional-cpu', 'cpu_conventional_sha256')]:
            read(paid / f'{label}-{suffix}.f32', state[key])
        for h, digest in enumerate(state['state_sha256']):
            read(paid / f'{label}-kv{h}.bin', digest)
    group0 = document(ROOT / f'kivi-causal-cache/{tag}-manifest.json')
    assert group0['fixture_sha256'] == snapshots['fixture_sha256']
    read(ROOT / f'kivi-causal-cache/{tag}-flush.bin', group0['flush_log_sha256'])
    read(ROOT / f'kivi-causal-cache/{tag}-final.bin', group0['final_sha256'])
    others = document(ROOT / f'skvq-global-gqa/{tag}-kivi-manifest.json')
    for h in range(1, 8):
        info = others['groups'][f'kv{h}']
        read(ROOT / f'skvq-global-gqa/{tag}-kivi-head{h}-events.bin', info['event_log_sha256'])
        read(ROOT / f'skvq-global-gqa/{tag}-kivi-head{h}-final.bin', info['final_image_sha256'])
    return {'window': window, 'input_sha256': seen,
            'scope': 'Hash correspondence of unchanged paid inputs; no encoding, projection or observer replay'}


if __name__ == '__main__':
    results = [check(w) for w in range(4)]
    (HERE / 'inputs.json').write_text(json.dumps(results, indent=2) + '\n')
    print(f'Pinned {sum(len(r["input_sha256"]) for r in results)} input identities across four streams')
