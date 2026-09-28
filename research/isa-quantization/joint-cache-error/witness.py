#!/usr/bin/env python3
"""Exactly decoded same-byte fields show joint K/V loss cancellation."""
from fractions import Fraction as F
from hashlib import sha256
import json
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent


def decode(path):
    p0, p1, v0, v1 = struct.unpack('<BBbb', path.read_bytes())
    p, v = [F(p0, 4), F(p1, 4)], [F(v0, 2), F(v1, 2)]
    assert all(x > 0 for x in p) and sum(p) == 1
    return p, v


def run():
    source = HERE / 'teacher.bin'
    changed = HERE / 'joint-candidate.bin'
    source.write_bytes(struct.pack('<BBbb', 2, 2, -2, 2))
    changed.write_bytes(struct.pack('<BBbb', 3, 1, -1, 3))
    p, v = decode(source)
    a, va = decode(changed)
    dv = [new - old for new, old in zip(va, v)]
    teacher = sum(x * y for x, y in zip(p, v))
    candidate = sum(x * y for x, y in zip(a, va))
    key = sum((x - y) * z for x, y, z in zip(a, p, v))
    value = sum(x * y for x, y in zip(p, dv))
    cross = sum((x - y) * z for x, y, z in zip(a, p, dv))
    assert candidate - teacher == key + value + cross
    assert (key, value, cross, candidate - teacher) == (F(-1, 2), F(1, 2), F(0), F(0))
    result = {'teacher_output': str(teacher), 'candidate_output': str(candidate),
              'key_error': str(key), 'value_error': str(value), 'interaction': str(cross),
              'separate_squared_errors': [str(key ** 2), str(value ** 2)],
              'joint_squared_error': str((candidate - teacher) ** 2),
              'images': [{'path': path.name, 'bytes': path.stat().st_size,
                          'sha256': sha256(path.read_bytes()).hexdigest()} for path in [source, changed]],
              'grammar': 'Two uint8 probability numerators over4; two signed-int8 value numerators over2.',
              'scope': 'One finite query, not a causal-cache program or free per-query value compensation.',
              'strong_control': 'Direct zero reader has exact output and a smaller description.'}
    (HERE / 'witness.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    run()
