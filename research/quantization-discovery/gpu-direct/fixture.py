#!/usr/bin/env python3
"""Export the pinned real block and aggregate paired GPU event intervals."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'instances' / 'bonsai-layer00-down-block0.npz'
RESULT = HERE / 'results.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export(folder):
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    with np.load(SOURCE) as z:
        w = z['trits']
        assert w.shape == (5120, 128) and w.dtype == np.int8
        q = z['queries']
        assert q.shape == (8, 128) and q.dtype == np.int8
        controls = np.stack([
            np.zeros(128, dtype=np.int8),
            np.full(128, 127, dtype=np.int8),
            np.full(128, -128, dtype=np.int8),
            np.tile(np.array([-128, 127], dtype=np.int8), 64),
        ])
        assert np.array_equal(z['scale_bits'], z['scales_fp16'].view(np.uint16))
        assert np.isin(w, [-1, 0, 1]).all()
    (folder / 'weights.i8').write_bytes(w.tobytes())
    (folder / 'queries.i8').write_bytes(np.concatenate([q, controls]).tobytes())
    print(json.dumps({'fixture_sha256': sha(SOURCE), 'source_sha256': sha(HERE / 'probe.hip'),
                      'weights_sha256': sha(folder / 'weights.i8'),
                      'queries_sha256': sha(folder / 'queries.i8')}))


def record(raw):
    data = json.loads(Path(raw).read_text())
    names = list(data['us_per_kernel'])
    samples = {n: np.asarray(data['us_per_kernel'][n]).reshape(9, 12) for n in names}
    medians = {n: float(np.median(np.median(v, axis=0))) for n, v in samples.items()}
    data['median_us'] = medians
    data['paired_round_ratio_vs_two_bit'] = {
        n: [float(np.median(samples['two_bit_decode'][r] / samples[n][r])) for r in range(9)]
        for n in names if n != 'two_bit_decode'
    }
    data['fixture_sha256'] = sha(SOURCE)
    data['source_sha256'] = sha(HERE / 'probe.hip')
    data['binary_sha256'] = sha(Path(raw).parent / 'probe')
    data['timing_scope'] = ('GPU event interval over 32 host-submitted launches, divided by 32; '
                            'includes any inter-launch gaps, not graph replay or isolated kernel cycles')
    RESULT.write_text(json.dumps(data, indent=2) + '\n')
    print(json.dumps(medians))


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('export', 'record'):
        raise SystemExit('usage: fixture.py export DIR | record RAW_JSON')
    (export if sys.argv[1] == 'export' else record)(sys.argv[2])
