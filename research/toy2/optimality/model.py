#!/usr/bin/env python3
"""Shared model: the toy2 map, its fixed output word, and wire-only input packing.

A wire register is a 32-bit word whose every bit position is either a fixed
constant or a copy of one bit of the dynamic input word.  Wires cannot add,
carry, or depend on A, so a free wire-packing pass cannot compute any part of
the answer; it can only place and duplicate input bits.  Both the incumbent
6-instruction expansion network (shifts, masks, ors) and every packing used
here are wires.
"""
from __future__ import annotations

import itertools
from dataclasses import dataclass

TRITS = (-1, 0, 1)
ORIENTATIONS = ((1, 1), (1, -1), (-1, 1))

# Dynamic input word: eight 2-bit codes u = t + 1, in this field order.
CODE_ORDER = ("b00", "b10", "c00", "c10", "b01", "b11", "c01", "c11")
CODE_INDEX = {name: i for i, name in enumerate(CODE_ORDER)}


def input_word(b, c):
    b00, b01, b10, b11 = b
    c00, c01, c10, c11 = c
    values = dict(b00=b00, b10=b10, c00=c00, c10=c10, b01=b01, b11=b11, c01=c01, c11=c11)
    return sum((values[name] + 1) << (2 * i) for i, name in enumerate(CODE_ORDER))


def reference(a, b, c):
    a00, a01, a10, a11 = a
    b00, b01, b10, b11 = b
    c00, c01, c10, c11 = c
    return (a00 * b00 + a01 * b10 + c00,
            a00 * b01 + a01 * b11 + c01,
            a10 * b00 + a11 * b10 + c10,
            a10 * b01 + a11 * b11 + c11)


@dataclass(frozen=True)
class Prepared:
    hi: int
    lo: int
    k0: int
    k1: int
    bias: int

    @property
    def coeffs(self):
        """Coefficients of (b0+1, b1+1, c0+1, c1+1) inside one output byte."""
        return (self.k0, self.k1, 7 * self.hi, self.lo)


def prepare(a) -> Prepared:
    a00, a01, a10, a11 = a
    for hi, lo in ORIENTATIONS:
        k0 = lo * a10 + 7 * hi * a00
        k1 = lo * a11 + 7 * hi * a01
        if -8 <= k0 <= 7 and -8 <= k1 <= 7:
            return Prepared(hi, lo, k0, k1, 24 - (k0 + k1 + 7 * hi + lo))
    raise AssertionError("no orientation fits signed int4")


def column(p: Prepared, b0, b1, c0, c1):
    k0, k1, kc0, kc1 = p.coeffs
    return k0 * (b0 + 1) + k1 * (b1 + 1) + kc0 * (c0 + 1) + kc1 * (c1 + 1) + p.bias


def output_word(a, b, c):
    """The fixed output contract: p(column 0) in byte 0, p(column 1) in byte 1."""
    p = prepare(a)
    b00, b01, b10, b11 = b
    c00, c01, c10, c11 = c
    return column(p, b00, b10, c00, c10) + 256 * column(p, b01, b11, c01, c11)


def decode(a, w):
    p = prepare(a)
    out = []
    for byte in (w & 0xFF, (w >> 8) & 0xFF):
        out.append((p.hi * (byte // 7 - 3), p.lo * (byte % 7 - 3)))
    (d00, d10), (d01, d11) = out
    return (d00, d01, d10, d11)


class Wire:
    """A 32-bit register built only from constant bits and copies of input bits."""

    def __init__(self, name=""):
        self.name = name
        self.sources: dict[int, int] = {}   # dest position -> input bit index
        self.constants: dict[int, int] = {}  # dest position -> 0/1

    def place_bit(self, dest: int, src_bit: int):
        assert 0 <= dest < 32 and 0 <= src_bit < 16
        assert dest not in self.sources and dest not in self.constants, "position reused"
        self.sources[dest] = src_bit
        return self

    def place_code(self, dest: int, code_name: str):
        """Copy a 2-bit input code so its value is scaled by 2**dest."""
        i = CODE_INDEX[code_name]
        return self.place_bit(dest, 2 * i).place_bit(dest + 1, 2 * i + 1)

    def constant(self, value: int):
        for pos in range(32):
            bit = (value >> pos) & 1
            if bit:
                assert pos not in self.sources and pos not in self.constants
                self.constants[pos] = 1
        return self

    def __call__(self, x: int) -> int:
        out = sum(1 << pos for pos, bit in self.constants.items() if bit)
        for dest, src in self.sources.items():
            out |= ((x >> src) & 1) << dest
        return out


def sign_extend(value: int, width: int) -> int:
    top = 1 << (width - 1)
    return value - (1 << width) if value & top else value


def pack_lanes(values, width: int) -> int:
    mask = (1 << width) - 1
    return sum((v & mask) << (width * i) for i, v in enumerate(values))


def dot(src0: int, src1: int, src2: int, lanes: int, width: int,
        signed0: bool, signed1: bool) -> int:
    """V_DOT8_I32_IU4 / V_DOT4_I32_IU8 exactly as the RDNA3.5 pseudocode defines them."""
    mask = (1 << width) - 1
    total = src2
    for i in range(lanes):
        a = (src0 >> (width * i)) & mask
        b = (src1 >> (width * i)) & mask
        total += (sign_extend(a, width) if signed0 else a) * (sign_extend(b, width) if signed1 else b)
    assert -(1 << 31) <= total < (1 << 31)
    return total


def all_matrices():
    return tuple(itertools.product(TRITS, repeat=4))
