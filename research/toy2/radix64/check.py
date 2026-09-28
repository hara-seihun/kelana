#!/usr/bin/env python3
"""Replay one byte-dot over every ternary A, B, C with a shared wire."""
from __future__ import annotations

import hashlib
import itertools
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "optimality"))
from model import Wire, all_matrices, decode, dot, input_word, output_word, pack_lanes, reference

COLUMN0 = ("b00", "b10", "c00", "c10")
COLUMN1 = ("b01", "b11", "c01", "c11")
wire = Wire("two ternary input codes per unsigned byte")
for i, (lo, hi) in enumerate(zip(COLUMN0, COLUMN1)):
    wire.place_code(8*i, lo).place_code(8*i+6, hi)


def prepared(a):
    a00, a01, a10, a11 = a
    k = (a10+7*a00, a11+7*a01, 7, 1)
    bias = 24-sum(k)
    assert all(-128 <= v <= 127 for v in k)
    assert 0 <= bias <= 48
    return pack_lanes(k, 8), 65*bias


def run(a, x):
    weight, bias = prepared(a)
    return dot(weight, wire(x), bias, lanes=4, width=8, signed0=True, signed1=False)


def decode64(p):
    low, high = p & 63, p >> 6
    return (low//7-3, high//7-3, low%7-3, high%7-3)


def main():
    cases = 0
    values = set()
    for a in all_matrices():
        for b in all_matrices():
            for c in all_matrices():
                x = input_word(b, c)
                p = run(a, x)
                assert 0 <= p <= 3120
                assert decode64(p) == reference(a, b, c), (a,b,c,p)
                # The prior byte-pair code may choose flipped signs. Compare
                # decoded maps, not word equality across distinct labels.
                assert decode(a, output_word(a,b,c)) == decode64(p)
                values.add(p)
                cases += 1
    print(json.dumps({"cases": cases, "distinct_codes": len(values),
        "online_opcode": "v_dot4_i32_iu8", "output_radix": 64,
        "max_result": max(values), "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},
        indent=2, sort_keys=True))

if __name__ == "__main__":
    main()
