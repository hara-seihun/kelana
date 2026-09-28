"""Independent exact source/certificate verifier; does not import the solver."""
import hashlib
import json
from fractions import Fraction
from pathlib import Path

import numpy as np

DIRECTORY = Path(__file__).resolve().parent


def arrivals():
    blocks, hashes = [], []
    for w in range(8):
        payload = (DIRECTORY.parent / 'kivi-value-intern' / f'train-{w}-events.bin').read_bytes()
        digest = hashlib.sha256(payload).hexdigest()
        owner = json.loads((DIRECTORY.parent / 'kivi-value-intern' / f'train-{w}-manifest.json').read_text())
        assert digest == owner['events_sha256']
        hashes.append(digest)
        assert len(payload) == owner['events_bytes'] == 1049088
        for t in range(256):
            chunk = payload[t*4098:(t+1)*4098]
            assert int.from_bytes(chunk[:2], 'little') == t+1
            blocks.append(np.frombuffer(chunk[2050:], dtype='<u2').copy().reshape(32, 32))
    words = np.stack(blocks)
    assert np.all((words & 0x7f80) != 0x7f80)
    return (words.astype('<u4') << 16).view('<f4').astype(np.float64), hashes


def exact_integer(x, unit):
    scaled = np.ldexp(x, -unit)
    assert np.max(np.abs(scaled)) < 2**45 and np.all(scaled == np.rint(scaled))
    return scaled.astype(np.int64)


def stats(x):
    return {'min': float(np.min(x)), 'median': float(np.median(x)),
            'mean': float(np.mean(x)), 'p90': float(np.percentile(x, 90)),
            'max': float(np.max(x))}


def main():
    receipt = json.loads((DIRECTORY / 'certificate.json').read_text())
    vals, hashes = arrivals()
    assert hashes == receipt['source_sha256']
    unit = receipt['integer_unit_exponent']
    integer = exact_integer(vals, unit)
    raw_maxima = (DIRECTORY / 'source-maxima.i64').read_bytes()
    assert hashlib.sha256(raw_maxima).hexdigest() == receipt['source_maxima_sha256']
    maxima = np.frombuffer(raw_maxima, dtype='<i8').reshape(32, 32, 32)
    raw_center = (DIRECTORY / 'center-fp16.bin').read_bytes()
    assert len(raw_center) == 2048 and hashlib.sha256(raw_center).hexdigest() == receipt['center_fp16_sha256']
    rounded = np.frombuffer(raw_center, dtype='<f2').reshape(32, 32).astype(np.float64)
    assert np.all(np.isfinite(rounded))
    common_unit = min(unit, -24)
    source_common = exact_integer(vals, common_unit)
    center_common = exact_integer(rounded, common_unit)
    originals = np.max(source_common, axis=2) - np.min(source_common, axis=2)
    achieved = np.max(source_common-center_common[None,:,:], axis=2) - np.min(source_common-center_common[None,:,:], axis=2)
    rows = []
    for g, entry in enumerate(receipt['groups']):
        assert entry['group'] == g
        source = integer[:, g, :]
        for d in range(32):
            for e in range(32):
                assert int(np.max(source[:, d] - source[:, e])) == int(maxima[g, d, e])
        a = maxima[g]
        r = Fraction(*entry['radius_units'])
        den = entry['center_denominator']
        p = entry['center_numerators']
        assert len(p) == 32 and den > 0 and min(p)+max(p) == 0
        for d in range(32):
            for e in range(32):
                assert Fraction(int(a[d,e]), 1) - Fraction(p[d]-p[e],den) <= r
        cycle = entry['critical_cycle']
        assert len(set(cycle)) == len(cycle) and len(cycle) > 0
        assert all(0 <= vertex < 32 for vertex in cycle)
        outgoing = [0]*32
        incoming = [0]*32
        edge_mass = {}
        for i, tail in enumerate(cycle):
            head = cycle[(i+1)%len(cycle)]
            outgoing[tail] += 1
            incoming[head] += 1
            edge_mass[(tail,head)] = edge_mass.get((tail,head), 0) + Fraction(1,len(cycle))
        assert incoming == outgoing and sum(edge_mass.values()) == 1
        edge_sum = sum(int(a[head,tail])*mass for (tail,head),mass in edge_mass.items())
        assert edge_sum == r
        exact_values = [Fraction(v, den) * 2**unit if unit >= 0 else Fraction(v, den*2**(-unit)) for v in p]
        rounded_values = [Fraction.from_float(float(x)) for x in rounded[g]]
        for d, (exact, nearest) in enumerate(zip(exact_values, rounded_values)):
            candidate = np.float16(rounded[g, d])
            distance = abs(exact-nearest)
            for direction in (np.float16(-np.inf), np.float16(np.inf)):
                neighbor = np.nextafter(candidate, direction)
                if np.isfinite(neighbor):
                    other_distance = abs(exact-Fraction.from_float(float(neighbor)))
                    assert distance < other_distance or (distance == other_distance and int(candidate.view('<u2')) % 2 == 0)
        delta = max(abs(x-y) for x,y in zip(exact_values, rounded_values))
        exact_range = max(Fraction(int(a[d,e]))-Fraction(p[d]-p[e],den)
                          for d in range(32) for e in range(32))
        assert exact_range == r
        rounded_unit = [x / Fraction(2**unit if unit>=0 else Fraction(1,2**(-unit))) for x in rounded_values]
        attained = max(Fraction(int(a[d,e]))-rounded_unit[d]+rounded_unit[e]
                       for d in range(32) for e in range(32))
        assert attained-r <= 2*delta / Fraction(2**unit if unit>=0 else Fraction(1,2**(-unit)))
        assert int(np.max(achieved[:,g])) == attained * Fraction(2**(unit-common_unit) if unit >= common_unit else Fraction(1, 2**(common_unit-unit)))
        rows.append({'group':g, 'original_worst': float(np.max(originals[:,g])*2**common_unit),
                     'optimum': float(r*2**unit), 'rounded_worst': float(attained*2**unit),
                     'rounding_delta_max': float(delta),
                     'cycle_length': len(cycle), 'center_min':float(min(rounded_values)),
                     'center_max':float(max(rounded_values))})
    scale = 2.0**common_unit
    summary = {
        'verification': '8 exact source SHA256/chronology, 32768 independently recomputed source maxima, 32768 rational potential inequalities, 32 exact critical cycles/means, exact FP16 rounding law',
        'center_bytes': len(raw_center), 'maxima_bytes': len(raw_maxima),
        'all_group_token_original': stats(originals*scale),
        'all_group_token_rounded': stats(achieved*scale),
        'by_window': [{'window':w, 'original':stats(originals[w*256:(w+1)*256]*scale),
                       'rounded':stats(achieved[w*256:(w+1)*256]*scale)} for w in range(8)],
        'groups': rows,
        'count_groups_worst_improved': sum(row['rounded_worst'] < row['original_worst'] for row in rows),
        'count_token_groups_improved': int(np.sum(achieved < originals)),
        'count_token_groups_worsened': int(np.sum(achieved > originals)),
        'max_rounding_delta': max(row['rounding_delta_max'] for row in rows),
    }
    (DIRECTORY / 'screen.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({k:v for k,v in summary.items() if k not in ('groups','by_window')}, indent=2))


if __name__ == '__main__':
    main()
