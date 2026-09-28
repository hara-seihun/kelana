#!/usr/bin/env python3
"""Two online instructions compute the whole fixed output word, for every A.

  I1  V_DOT4_I32_IU8  (signed weights, unsigned lanes)  ->  256*p1 + bias
  I2  V_DOT8_I32_IU4  (signed weights, unsigned lanes)  ->  p0 + 256*p1

Both dynamic operands are wire registers (see model.Wire): I1 reads the four
column-1 codes, each shifted four bits up inside its own byte lane; I2 reads
the four column-0 codes in nibble lanes.  The 16-fold prescale in I1 is what
lets an 8-bit weight carry the 256 of the output byte position: weight 16*k
times lane 16*u is 256*k*u, and 16*k fits int8 exactly when k fits int4.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
from pathlib import Path

from model import (Prepared, TRITS, Wire, all_matrices, decode, dot, input_word,
                   output_word, pack_lanes, prepare, reference)

COLUMN0 = ("b00", "b10", "c00", "c10")
COLUMN1 = ("b01", "b11", "c01", "c11")


def wire_nibbles() -> Wire:
    w = Wire("column0 nibble lanes")
    for i, name in enumerate(COLUMN0):
        w.place_code(4 * i, name)
    return w


def wire_prescaled_bytes() -> Wire:
    w = Wire("column1 byte lanes, prescaled by 16")
    for i, name in enumerate(COLUMN1):
        w.place_code(8 * i + 4, name)
    return w


NIBBLES = wire_nibbles()
PRESCALED = wire_prescaled_bytes()


def weights(p: Prepared):
    k0, k1, kc0, kc1 = p.coeffs
    dot4 = pack_lanes([16 * k0, 16 * k1, 16 * kc0, 16 * kc1], 8)
    dot8 = pack_lanes([k0, k1, kc0, kc1, 0, 0, 0, 0], 4)
    assert all(-128 <= 16 * k <= 127 for k in p.coeffs)
    assert all(-8 <= k <= 7 for k in p.coeffs)
    return dot4, dot8


def run(a, x: int) -> int:
    p = prepare(a)
    w4, w8 = weights(p)
    r = dot(w4, PRESCALED(x), 257 * p.bias, lanes=4, width=8, signed0=True, signed1=False)
    return dot(w8, NIBBLES(x), r, lanes=8, width=4, signed0=True, signed1=False)


def exhaust():
    cases = 0
    for a in all_matrices():
        for b in all_matrices():
            for c in all_matrices():
                x = input_word(b, c)
                got = run(a, x)
                assert got == output_word(a, b, c), (a, b, c, got)
                assert decode(a, got) == reference(a, b, c), (a, b, c)
                cases += 1
    return cases


def intermediate_bounds():
    lo, hi = 1 << 31, -(1 << 31)
    for a in all_matrices():
        p = prepare(a)
        w4, _ = weights(p)
        for codes in itertools.product(TRITS, repeat=4):
            x = sum((t + 1) << (2 * (4 + i)) for i, t in enumerate(codes))
            r = dot(w4, PRESCALED(x), 257 * p.bias, lanes=4, width=8, signed0=True, signed1=False)
            lo, hi = min(lo, r), max(hi, r)
    return lo, hi


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output")
    args = parser.parse_args()

    source = Path(__file__).read_bytes() + Path(__file__).with_name("model.py").read_bytes()
    cases = exhaust()
    lo, hi = intermediate_bounds()
    results = {
        "cases": cases,
        "online_instructions": 2,
        "instructions": ["V_DOT4_I32_IU8", "V_DOT8_I32_IU4"],
        "intermediate_range": [lo, hi],
        "wire_positions": {
            "dot4_lanes": {name: 8 * i + 4 for i, name in enumerate(COLUMN1)},
            "dot8_lanes": {name: 4 * i for i, name in enumerate(COLUMN0)},
        },
        "source_sha256": hashlib.sha256(source).hexdigest(),
    }
    text = json.dumps(results, indent=2, sort_keys=True)
    if args.output:
        Path(args.output).write_text(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
