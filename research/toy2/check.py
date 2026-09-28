#!/usr/bin/env python3
"""Exhaust the ternary 2x2 MAC and both explicitly specified instruction constructions."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TRITS = (-1, 0, 1)
ORIENTATIONS = ((1, 1), (1, -1), (-1, 1))  # high/output-row-0 sign, low/output-row-1 sign


def pack_nibbles(values):
    return sum((x & 15) << (4 * i) for i, x in enumerate(values))


def prepare(a):
    a00, a01, a10, a11 = a
    hi, lo = next((hi, lo) for hi, lo in ORIENTATIONS
                  if all(-8 <= lo * low + 7 * hi * high <= 7
                         for high, low in ((a00, a10), (a01, a11))))
    row0 = (hi * a00, hi * a01, hi, 0)
    row1 = (lo * a10, lo * a11, 0, lo)
    packed = tuple(x + 7 * y for x, y in zip(row1, row0))
    assert all(-8 <= x <= 7 for x in packed)
    b0, b1 = 3 - sum(row0), 3 - sum(row1)
    return {
        "signs": (hi, lo),
        "baseline_weights": tuple(pack_nibbles(row) << shift
                                  for shift in (0, 16) for row in (row0, row1)),
        "baseline_biases": (b0, b1),
        "packed_weights": (pack_nibbles(packed), pack_nibbles(packed) << 16),
        "packed_bias": b1 + 7 * b0,
    }


def pack_input(b, c):
    b00, b01, b10, b11 = b
    c00, c01, c10, c11 = c
    return sum((t + 1) << (2 * i) for i, t in
               enumerate((b00, b10, c00, c10, b01, b11, c01, c11)))


def expand(x):
    x = (x | (x << 8)) & 0x00FF00FF
    x = (x | (x << 4)) & 0x0F0F0F0F
    return (x | (x << 2)) & 0x33333333


def dot8(weights, x, bias):
    total = bias
    for i in range(8):
        w = (weights >> (4 * i)) & 15
        w = w if w < 8 else w - 16
        total += w * ((x >> (4 * i)) & 15)
    assert -(1 << 31) <= total < (1 << 31)
    return total


def baseline(p, input_word):
    x = expand(input_word)
    b0, b1 = p["baseline_biases"]
    d = [dot8(w, x, bias) for w, bias in zip(p["baseline_weights"], (b0, b1, b0, b1))]
    assert all(0 <= v <= 6 for v in d)
    return (d[1] + 7 * d[0]) | ((d[3] + 7 * d[2]) << 8)


def candidate(p, input_word):
    x = expand(input_word)
    d0, d1 = (dot8(w, x, p["packed_bias"]) for w in p["packed_weights"])
    assert 0 <= d0 <= 48 and 0 <= d1 <= 48
    return d0 | (d1 << 8)


def reference(a, b, c):
    a00, a01, a10, a11 = a
    b00, b01, b10, b11 = b
    c00, c01, c10, c11 = c
    return (a00 * b00 + a01 * b10 + c00, a00 * b01 + a01 * b11 + c01,
            a10 * b00 + a11 * b10 + c10, a10 * b01 + a11 * b11 + c11)


def decode(p, word):
    hi, lo = p["signs"]
    q0, q1 = word & 255, (word >> 8) & 255
    return (hi * (q0 // 7 - 3), hi * (q1 // 7 - 3),
            lo * (q0 % 7 - 3), lo * (q1 % 7 - 3))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    mats = list(itertools.product(TRITS, repeat=4))
    orientations = {str(s): 0 for s in ORIENTATIONS}
    count = 0
    for a in mats:
        p = prepare(a)
        orientations[str(p["signs"])] += 1
        for b in mats:
            for c in mats:
                x = pack_input(b, c)
                got = candidate(p, x)
                assert got == baseline(p, x), (a, b, c)
                assert decode(p, got) == reference(a, b, c), (a, b, c)
                count += 1
    for x in range(65536):
        assert expand(x) == sum(((x >> (2 * i)) & 3) << (4 * i) for i in range(8))
    column_outputs = {(b0 + b1 + c0, b0 - b1 + c1)
                      for b0, b1, c0, c1 in itertools.product(TRITS, repeat=4)}
    result = {
        "checked_matrix_inputs": count,
        "checked_bit_expansions": 65536,
        "orientation_counts": orientations,
        "hadamard_column_outputs": len(column_outputs),
        "hadamard_matrix_outputs": len(column_outputs) ** 2,
        "baseline_instructions": {"v_lshl_or_b32": 4, "v_and_b32": 3,
                                  "v_dot8_i32_iu4": 4, "v_mad_u32_u24": 2},
        "candidate_instructions": {"v_lshl_or_b32": 4, "v_and_b32": 3,
                                   "v_dot8_i32_iu4": 2},
        "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "scope": "Exact finite checks of all valid 2x2 ternary inputs; not a hardware timing measurement.",
    }
    text = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
