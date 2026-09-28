"""Exact dyadic finite-grid decisions on already-saved causal K chunks.

Consumes only original pre32/pre256 cache snapshots and stored donor events.
No source projections, candidate fitting, or complete-output re-evaluation.
"""
from pathlib import Path
import hashlib
import json
import struct
import sys
import time

HERE = Path(__file__).resolve().parent
BASE = HERE.parent / 'kivi-causal-cache'
METRIC = HERE.parent / 'kivi-response-metric'


def sha(blob):
    return hashlib.sha256(blob).hexdigest()


def unpack(blob):
    return [v for x in blob for v in (x & 15, x >> 4)]


def scaled(values, exponent):
    result = []
    for v in values:
        n, d = v.as_integer_ratio()
        assert (1 << exponent) % d == 0
        result.append(n * ((1 << exponent) // d))
    return result


def key_values(blob):
    return [struct.unpack('<f', struct.pack('<I', word << 16))[0]
            for word in struct.unpack('<4096H', blob)]


def key_events(blob):
    result = []
    at = 0
    while at < len(blob):
        kind = blob[at]
        t = int.from_bytes(blob[at+1:at+3], 'little')
        size = 2560 if kind == ord('K') else 80
        assert kind in (ord('K'), ord('V')) and at + 3 + size <= len(blob)
        if kind == ord('K'):
            result.append((t, blob[at+3:at+3+size]))
        at += 3 + size
    assert len(result) == 8 and [t for t, _ in result] == list(range(32, 257, 32))
    return result


def decision(g, hstep, current):
    """First boundary whose adjacent energy increment is nonnegative.

    An exact zero means a two-code tie; choose the even code. This is at
    most four bracket comparisons among 15 strictly increasing boundaries.
    """
    low, high, comparisons = 0, 15, 0
    while low < high:
        middle = (low + high) // 2
        boundary = 2 * g + hstep * (2 * (middle - current) + 1)
        comparisons += 1
        if boundary < 0:
            low = middle + 1
        else:
            high = middle
    tie = low < 15 and 2 * g + hstep * (2 * (low - current) + 1) == 0
    chosen = low + int(tie and low % 2 == 1)
    assert comparisons <= 4
    return chosen, comparisons, tie


def run(panel, window, t):
    started = time.monotonic()
    assert panel in ('train', 'held') and t in (32, 256)
    metric_blob = (METRIC / 'metric-fp16.bin').read_bytes()
    assert sha(metric_blob) == '2d4837028c2e04fb61b3f554eb409b4ff450374634b54febabe451cd846cadc9'
    metric = struct.unpack('<1152e', metric_blob)
    # Fixed common dyadic scales belong to the represented metric, not to a fit.
    uflat = scaled(metric[:1024], 24)
    U = [uflat[i:i+8] for i in range(0, 1024, 8)]
    diag = scaled(metric[1024:], 48)
    curvature = [diag[d] + sum(u*u for u in U[d]) for d in range(128)]
    assert all(x > 0 for x in diag)
    original_log = (BASE / f'{panel}-{window}-flush.bin').read_bytes()
    candidate_log = (METRIC / f'{panel}-{window}-flush.bin').read_bytes()
    original_manifest = json.loads((BASE / f'{panel}-{window}-manifest.json').read_text())
    candidate_manifest = json.loads((METRIC / f'{panel}-{window}.json').read_text())
    assert sha(original_log) == original_manifest['flush_log_sha256']
    assert sha(candidate_log) == candidate_manifest['flush_log_sha256']
    original = key_events(original_log)[t//32-1][1]
    candidate = key_events(candidate_log)[t//32-1][1]
    assert original[2048:] == candidate[2048:]
    snapshot = (BASE / f'{panel}-{window}-pre-{t}.bin').read_bytes()
    # Original preflush layout is quantized K, quantized V, recent K, recent V.
    key_offset = 0 if t == 32 else 7*2560 + 223*80
    expected_size = 16384 if t == 32 else 52400
    assert len(snapshot) == expected_size
    assert sha(snapshot) == original_manifest['prefixes'][t-1]['before_flush']['sha256']
    source = key_values(snapshot[key_offset:key_offset+8192])
    fields = struct.unpack('<256e', original[2048:])
    exponent = max(v.as_integer_ratio()[1].bit_length()-1 for v in (*source, *fields))
    source_int = scaled(source, exponent)
    field_int = scaled(fields, exponent)
    codes, target = unpack(original[:2048]), unpack(candidate[:2048])
    stats = {'source_error': 0, 'mode': 0, 'gradient': 0, 'curvature_step': 0,
             'threshold': 0, 'curvature': max(v.bit_length() for v in curvature),
             'diagonal': max(v.bit_length() for v in diag),
             'factor': max(abs(v).bit_length() for v in uflat), 'mode_product': 0}
    changed = ties = comparisons = 0
    min_boundary_abs = None
    energy_before = energy_after = 0
    def note(name, values):
        stats[name] = max(stats[name], max((abs(x).bit_length() for x in values), default=0))
    for token in range(32):
        row = codes[token*128:(token+1)*128]
        e = [field_int[2*d] + row[d]*field_int[2*d+1] - source_int[token*128+d]
             for d in range(128)]
        s = [sum(U[d][r]*e[d] for d in range(128)) for r in range(8)]
        initial = sum(diag[d]*e[d]*e[d] for d in range(128)) + sum(x*x for x in s)
        energy_before += initial
        note('source_error', e); note('mode', s)
        for d in range(128):
            step = field_int[2*d+1]
            if step == 0:
                assert row[d] == target[token*128+d]
                continue
            assert step > 0
            products = [U[d][r]*s[r] for r in range(8)]
            g = diag[d]*e[d] + sum(products)
            hb = curvature[d]*step
            j, ncompare, tie = decision(g, hb, row[d])
            # Independent exhaustive objective comparisons, exact integers.
            costs = [2*(z-row[d])*step*g + (z-row[d])**2*step**2*curvature[d] for z in range(16)]
            best = min(costs)
            assert costs[j] == best <= 0
            minimizers = [z for z in range(16) if costs[z] == best]
            assert j == (next(z for z in minimizers if z % 2 == 0) if len(minimizers) > 1 else minimizers[0])
            assert j == target[token*128+d], (panel, window, t, token, d, j, target[token*128+d])
            bounds = [2*g + hb*(2*(z-row[d])+1) for z in range(15)]
            positive = [abs(x) for x in bounds if x]
            if positive:
                near = min(positive)
                min_boundary_abs = near if min_boundary_abs is None else min(min_boundary_abs, near)
            note('mode_product', products); note('gradient', [g]); note('curvature_step', [hb]); note('threshold', bounds)
            delta = (j-row[d])*step
            e[d] += delta
            s = [s[r]+delta*U[d][r] for r in range(8)]
            row[d] = j
            changed += int(delta != 0); comparisons += ncompare; ties += int(tie)
            note('source_error', e); note('mode', s)
        assert s == [sum(U[d][r]*e[d] for d in range(128)) for r in range(8)]
        final = sum(diag[d]*e[d]*e[d] for d in range(128)) + sum(x*x for x in s)
        assert final <= initial
        energy_after += final
        codes[token*128:(token+1)*128] = row
    output = bytes(codes[2*i] | codes[2*i+1] << 4 for i in range(2048)) + original[2048:]
    assert output == candidate
    # Observed widths are a finite source certificate, not a universal BF16 bound.
    assert max(stats.values()) < 127
    report = {'panel': panel, 'window': window, 'prefix': t,
              'sample_scope': 'All32 tokens in saved pre32 or pre256 original source snapshot; not all8 chunks.',
              'snapshot_sha256': sha(snapshot), 'original_log_sha256': sha(original_log),
              'metric_log_sha256': sha(candidate_log), 'metric_sha256': sha(metric_blob),
              'exact_output_sha256': sha(output), 'different_bytes': 0,
              'decisions': 4096, 'binary_comparisons': comparisons, 'exact_boundary_ties': ties,
              'changed_codes': changed, 'field_source_common_exponent': exponent,
              'mode_denominator_exponent': exponent+24,
              'gradient_threshold_denominator_exponent': exponent+48,
              'maximum_observed_magnitude_bits': stats,
              'minimum_nonzero_boundary_numerator': str(min_boundary_abs),
              'energy_before_numerator': str(energy_before), 'energy_after_numerator': str(energy_after),
              'energy_denominator_exponent': 2*exponent+48,
              'seconds': time.monotonic()-started,
              'scope': 'Exact integer recurrence and finite-grid optimum; Python integers, no native code/latency claim.'}
    (HERE / f'{panel}-{window}-{t}.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    run(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
