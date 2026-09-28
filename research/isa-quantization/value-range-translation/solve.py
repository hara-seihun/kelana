"""Frozen exact max-cycle-mean source screen for the original KIVI V G32 blocks."""
import hashlib
import json
from fractions import Fraction
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'kivi-value-intern'


def source():
    chunks, hashes = [], []
    for window in range(8):
        raw = (SOURCE / f'train-{window}-events.bin').read_bytes()
        owner = json.loads((SOURCE / f'train-{window}-manifest.json').read_text())
        assert hashlib.sha256(raw).hexdigest() == owner['events_sha256']
        assert len(raw) == owner['events_bytes'] == 256 * 4098
        events = np.frombuffer(raw, dtype=np.uint8).reshape(256, 4098)
        times = events[:, :2].copy().view('<u2').reshape(256)
        assert np.array_equal(times, np.arange(1, 257))
        chunks.append(events[:, 2050:].copy().view('<u2').reshape(256, 8, 128))
        hashes.append(hashlib.sha256(raw).hexdigest())
    bits = np.concatenate(chunks, axis=0)
    assert not np.any((bits & 0x7f80) == 0x7f80)
    values = (bits.astype(np.uint32) << 16).view(np.float32).astype(np.float64)
    nonzero = bits[(bits & 0x7fff) != 0]
    exp = (nonzero >> 7) & 255
    mantissa = np.where(exp == 0, nonzero & 127, (nonzero & 127) | 128)
    exponent = np.where(exp == 0, -133, exp.astype(np.int32) - 134)
    trailing = np.log2(mantissa & -mantissa).astype(np.int32)
    unit = int(np.min(exponent + trailing))
    integers = np.ldexp(values, -unit)
    # B<2^45 bounds all int64 hot loops: pair differences <2^46,
    # length-32 Karp walks <2^51, and denominator<=32 potential walks <2^57.
    assert np.max(np.abs(integers)) < 2**45
    assert np.array_equal(integers, np.rint(integers))
    return integers.astype(np.int64).reshape(2048, 32, 32), hashes, unit


def maximum_mean(a):
    n = len(a)
    minus_inf = -(1 << 57)
    dp = np.full((n + 1, n), minus_inf, dtype=np.int64)
    dp[0, 0] = 0
    for length in range(1, n + 1):
        dp[length] = np.max(a + dp[length - 1][None, :], axis=1)
    best = None
    for vertex in range(n):
        low = min(Fraction(int(dp[n, vertex] - dp[k, vertex]), n-k)
                  for k in range(n) if dp[k, vertex] != minus_inf)
        if best is None or low > best:
            best = low
    return best


def potential(a, rate):
    n = len(a)
    assert rate.denominator <= n and np.max(np.abs(a)) < 2**46
    assert abs(rate.numerator) < 2**51
    weight = a.astype(np.int64)*rate.denominator - rate.numerator
    c = np.zeros(n, dtype=np.int64)
    for _ in range(n-1):
        c = np.maximum(c, np.max(weight + c[None, :], axis=1))
    assert np.all(weight + c[None, :] <= c[:, None])
    centered = 2*c - int(c.min()) - int(c.max())
    return centered, 2*rate.denominator


def cycle(a, center, center_den, rate):
    n = len(a)
    adjacency = [[d for d in range(n) if int(a[d,e])*center_den*rate.denominator
                  - (int(center[d])-int(center[e]))*rate.denominator
                  == rate.numerator*center_den] for e in range(n)]
    visited, stack, positions = set(), [], {}

    def dfs(u):
        visited.add(u)
        positions[u] = len(stack)
        stack.append(u)
        for v in adjacency[u]:
            if v in positions:
                return stack[positions[v]:]
            if v not in visited:
                found = dfs(v)
                if found is not None:
                    return found
        stack.pop()
        del positions[u]
        return None

    for start in range(n):
        if start not in visited:
            result = dfs(start)
            if result is not None:
                return result
    raise AssertionError('optimal tight graph has no critical cycle')


def main():
    values, hashes, unit = source()
    maxima = np.empty((32, 32, 32), dtype='<i8')
    outcomes = []
    center_float = np.empty((32, 32), dtype=np.float64)
    for group in range(32):
        v = values[:, group, :]
        a = np.max(v[:, :, None] - v[:, None, :], axis=0)
        maxima[group] = a
        rate = maximum_mean(a)
        center, denom = potential(a, rate)
        witness = cycle(a, center, denom, rate)
        center_float[group] = center.astype(np.float64)/denom * (2.0**unit)
        outcomes.append({'group': group, 'radius_units': [rate.numerator, rate.denominator],
                         'center_numerators': [int(x) for x in center], 'center_denominator': denom,
                         'critical_cycle': witness})
    assert np.isfinite(center_float).all()
    rounded = center_float.astype('<f2')
    assert np.isfinite(rounded).all()
    center_bytes = rounded.tobytes()
    assert len(center_bytes) == 2048
    max_bytes = maxima.tobytes()
    (HERE / 'source-maxima.i64').write_bytes(max_bytes)
    (HERE / 'center-fp16.bin').write_bytes(center_bytes)
    (HERE / 'certificate.json').write_text(json.dumps({
        'source_sha256': hashes, 'source_arrivals_per_window': 256,
        'source_layout': 'u16 timestamp, 2048 K bytes, 2048 BF16 V bytes; 8 heads x 4 contiguous G32',
        'integer_unit_exponent': unit, 'source_maxima_sha256': hashlib.sha256(max_bytes).hexdigest(),
        'center_fp16_sha256': hashlib.sha256(center_bytes).hexdigest(),
        'optimizer': 'Karp source vertex 0, max-min exact fractions; 31 Jacobi longest-path rounds from zero; midpoint gauge; lex-first tight DFS cycle',
        'groups': outcomes}, separators=(',', ':')) + '\n')
    print('source maxima/center/certificate written; independent checker owns all range distributions')


if __name__ == '__main__':
    main()
