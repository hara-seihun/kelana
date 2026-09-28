#!/usr/bin/env python3
"""Exact finite-grid code descent with a decoded FP16 diagonal/factor metric."""
from fractions import Fraction as F
from hashlib import sha256
import json
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent


def run():
    path = HERE / 'metric.f16'
    path.write_bytes(struct.pack('<4e', 1, 1, 1, 1))
    fields = [F(x) for x in struct.unpack('<4e', path.read_bytes())]
    diagonal, factor = fields[:2], fields[2:]
    source = [F(1, 2)] * 2
    codes = [0, 0]
    (HERE / 'scalar-code.bin').write_bytes(bytes([0]))
    original = (HERE / 'scalar-code.bin').read_bytes()[0]
    assert codes == [original & 1, (original >> 1) & 1]
    error = [F(c) - target for c, target in zip(codes, source)]
    mode = sum(u * e for u, e in zip(factor, error))
    energy = lambda e: sum(d * x * x for d, x in zip(diagonal, e)) + sum(u * x for u, x in zip(factor, e)) ** 2
    before = energy(error)
    steps = []
    for d in range(2):
        gradient = diagonal[d] * error[d] + factor[d] * mode
        curvature = diagonal[d] + factor[d] ** 2
        changes = [(2 * (F(j) - codes[d]) * gradient + (F(j) - codes[d]) ** 2 * curvature, j) for j in (0, 1)]
        change, chosen = min(changes)
        delta = F(chosen - codes[d])
        next_error = error.copy()
        next_error[d] += delta
        assert energy(next_error) - energy(error) == change <= 0
        mode += delta * factor[d]
        assert mode == sum(u * x for u, x in zip(factor, next_error))
        steps.append({'coordinate': d, 'before_code': codes[d], 'after_code': chosen,
                      'gradient': str(gradient), 'curvature': str(curvature),
                      'energy_change': str(change)})
        error, codes[d] = next_error, chosen
    packed = codes[0] | (codes[1] << 1)
    (HERE / 'response-code.bin').write_bytes(bytes([packed]))
    decoded = (HERE / 'response-code.bin').read_bytes()[0]
    final_error = [F(decoded & 1) - source[0], F((decoded >> 1) & 1) - source[1]]
    after = energy(final_error)
    assert (before, after, codes) == (F(3, 2), F(1, 2), [1, 0])
    assert sum(e * e for e in final_error) == sum(x * x for x in source) == F(1, 2)
    files = ['metric.f16', 'scalar-code.bin', 'response-code.bin']
    result = {'source': list(map(str, source)), 'diagonal': list(map(str, diagonal)),
              'factor': list(map(str, factor)), 'before_energy': str(before), 'after_energy': str(after),
              'euclidean_error_both': '1/2', 'steps': steps,
              'images': [{'path': name, 'bytes': (HERE / name).stat().st_size,
                          'sha256': sha256((HERE / name).read_bytes()).hexdigest()} for name in files],
              'scope': 'Exact represented quadratic, not a complete attention quality or byte/work win.'}
    (HERE / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    run()
