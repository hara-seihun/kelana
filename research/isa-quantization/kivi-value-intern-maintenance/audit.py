"""Independent per-prefix decoded-record acceptance of the native in-place maintainer."""
import hashlib
import json
import struct
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT / 'kivi-value-intern'))
from verify import decode, baseline_check, construct_from_independent_state


def sha(data):
    return hashlib.sha256(data).hexdigest()


def run(name):
    panel, window = name.split('-')
    assert panel in ('train', 'held') and int(window) < (8 if panel == 'train' else 4)
    original = json.loads((ROOT / 'kivi-two-bit-causal' / f'{name}-manifest.json').read_text())
    donor_dir = ROOT / 'kivi-value-intern'
    manifest = json.loads((donor_dir / f'{name}-manifest.json').read_text())
    logs = [(ROOT / 'kivi-two-bit-causal' / f'{name}-head{h}-events.bin').read_bytes() for h in range(8)]
    assert [sha(x) for x in logs] == manifest['baseline_events_sha256']
    arrivals_path = donor_dir / f'{name}-events.bin'
    arrivals = arrivals_path.read_bytes()
    assert sha(arrivals) == manifest['events_sha256'] and len(arrivals) == 256*4098
    state = {'kq': [[] for _ in range(8)], 'kr': [[] for _ in range(8)], 'vq': [], 'vr': [], 't': 0, 'phase': 1}
    offsets = [0]*8
    checked = 0
    process = subprocess.Popen([str(HERE/'maintain'), str(arrivals_path)], stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, bufsize=0)

    def exact(size):
        data = bytearray()
        while len(data) < size:
            part = process.stdout.read(size-len(data))
            assert part, f'premature native exit: {process.poll()}'
            data.extend(part)
        return bytes(data)

    def frame(t, phase, receipt):
        nonlocal checked
        size, = struct.unpack('<I', exact(4))
        blob = exact(size)
        state['t'], state['phase'] = t, phase
        checked += baseline_check(state, original)
        decode(blob, t, phase, state, receipt)
        assert blob == construct_from_independent_state(state)
        return blob

    try:
        for t in range(1,257):
            event = arrivals[(t-1)*4098:t*4098]
            assert int.from_bytes(event[:2], 'little') == t
            kb, vb = event[2:2050], event[2050:]
            for h in range(8):
                state['kr'][h].append(kb[h*256:(h+1)*256])
            state['vr'].append(tuple(vb[h*256:(h+1)*256] for h in range(8)))
            frame(t, 0, manifest['prefixes'][t-1]['before'])
            for h in range(8):
                def consume(tag, size):
                    at = offsets[h]
                    s = logs[h]
                    assert s[at:at+1] == tag and int.from_bytes(s[at+1:at+3], 'little') == t
                    payload = s[at+3:at+3+size]
                    assert len(payload) == size
                    offsets[h] = at+3+size
                    return payload
                if len(state['kr'][h]) == 32:
                    state['kq'][h].append(consume(b'K',1536))
                    state['kr'][h].clear()
                if len(state['vr']) > 32:
                    if h == 0:
                        flushed = []
                    flushed.append(consume(b'V',48))
            if len(state['vr']) > 32:
                state['vq'].append(tuple(flushed))
                state['vr'].pop(0)
            final = frame(t, 1, manifest['prefixes'][t-1]['after'])
        assert process.stdout.read(1) == b''
        assert all(offsets[h] == len(logs[h]) for h in range(8))
        assert final == (donor_dir/f'{name}-final.bin').read_bytes()
        assert process.wait(timeout=5) == 0
        ledger = json.loads(process.stderr.read())
        assert ledger['arena_used_peak'] == manifest['peak_bytes']
        assert ledger['final_bytes'] == len(final)
        result = {'window':name, 'prefixes_verified':512, 'original_record_checks':checked,
                  'final_sha256':sha(final), 'source_arrivals_sha256':sha(arrivals), **ledger}
        (HERE/f'{name}-result.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result))
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


if __name__ == '__main__':
    run(sys.argv[1])
