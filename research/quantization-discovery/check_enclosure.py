#!/usr/bin/env python3
"""Replay the saved local producer-cell and exact weight-assignment certificate."""
import hashlib
import json
from pathlib import Path
import numpy as np
from enclosure_experiments import enclose, exact_local_assignment
from fp_enclosure import guard_membership

HERE = Path(__file__).resolve().parent


def check():
    results = json.loads((HERE/'enclosure-results.json').read_text())
    for name, expected in results['source_sha256'].items():
        assert hashlib.sha256((HERE/name).read_bytes()).hexdigest() == expected, name
    fixture_path = HERE/'instances/bonsai-layer00-producer-chunk0.npz'
    assert hashlib.sha256(fixture_path.read_bytes()).hexdigest() == results['fixture_sha256']
    data = np.load(fixture_path)
    record = results['local_replacement']
    row = record['source_row']
    assert hashlib.sha256(data['q'][row].tobytes()).hexdigest() == record['upstream_codes_sha256']
    codes, scales = data['q'][row].reshape(5120), data['input_scales'][row].copy()
    def admitted(q, s):
        return guard_membership(q, s, codes, record['input_scale_lo_bits'], record['input_scale_hi_bits'])
    assert admitted(codes, scales)
    changed = codes.copy()
    changed[0] = 0 if changed[0] else 1
    assert not admitted(changed, scales)
    outside = np.asarray(record['input_scale_lo_bits'], dtype=np.uint32).copy()
    outside[0] -= 1
    assert not admitted(codes, outside.view(np.float32))
    assert not admitted(codes, scales.astype(np.float64))
    domain, output = enclose(data, row, record['relative_scale_radius'])
    assert np.all(output['codes_lo'][0] == output['codes_hi'][0])
    assert output['codes_lo'][0].tolist() == record['fixed_hidden_codes']
    assert domain['lo'].astype(np.float32).view(np.uint32).tolist() == record['input_scale_lo_bits']
    assert domain['hi'].astype(np.float32).view(np.uint32).tolist() == record['input_scale_hi_bits']
    weights = json.loads((HERE/'instances/bonsai-layer00-block0.json').read_text())
    repeated = exact_local_assignment(weights, output['codes_lo'][0])
    for name, value in repeated.items():
        assert record[name] == value, name
    counts = [int(h)-int(l)+1 for l, h in zip(record['input_scale_lo_bits'], record['input_scale_hi_bits'])]
    assert counts == record['scale_values_per_block']
    number = 1
    for count in counts:
        number *= count
    assert number == record['scale_tuples']
    return dict(valid=True, guard_checks_passed=True, integer_dot_error=0, admitted_scale_tuples=number,
                weight_packet_bits=record['padded_bits'], literal_guard_bytes=record['literal_guard_bytes'],
                global_model_compression=False,
                contract='Pinned gfx1151 arithmetic, fixed upstream int8 vector, explicit FP32 scale intervals.')


if __name__ == '__main__':
    print(json.dumps(check(), indent=2))
