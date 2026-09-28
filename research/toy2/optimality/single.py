#!/usr/bin/env python3
"""Decide whether ONE affine gfx1151 instruction can produce the whole output word.

Model (see NOTES.md).  The dynamic input is the 16-bit word of eight 2-bit trit
codes.  A free packing pass may build any number of wire registers: every bit
position holds a constant or a copy of one input bit.  The online instruction
reads wire registers and prepared A-dependent constants.

An affine instruction is any op of the shape

    result = sum_i w_i * lane_i(S1) [+ S2 [+ S3]]   (mod 2**32)

with L lanes of width W read signed or unsigned, prepared lane weights w_i from
the format's range, and optional extra summed wire sources.  This covers
V_DOT8_I32_IU4, V_DOT8_U32_U4, V_DOT4_I32_IU8, V_DOT4_U32_U8, V_MAD_U32_U24,
V_MAD_I32_I24, V_MUL_LO_U32, V_MAD_U64_U32's low half, V_ADD_U32, V_ADD3_U32,
V_LSHL_ADD_U32, V_ADD_LSHL_U32, V_XAD_U32 and V_LSHL_OR_B32 whenever the OR
lands on disjoint bits (an OR on overlapping bits is not affine and belongs to
the bit-local class handled by bitlocal.py).

Because the output word must equal the target exactly, the target's affine
expansion in the sixteen input bits is unique, so realizability reduces to
placing the required per-bit coefficients on instruction positions.  Every
position of a wire register carries at most one input bit; that disjointness is
the whole difficulty.  One bit may still occupy several positions of the same
lane, and the model allows it: a bit's per-lane coefficient is the sum of the
place values it occupies.

Opcode signedness is prepared data and may be chosen per matrix, so the signed
and unsigned readings of each dot appear as separate shapes below.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

from ortools.sat.python import cp_model

from model import Prepared, all_matrices, prepare

M32 = 1 << 32


@dataclass(frozen=True)
class Shape:
    name: str
    lanes: int
    width: int
    signed_lanes: bool
    weight_lo: int
    weight_hi: int
    acc_wires: int = 1            # summed wire sources besides the lane source
    negatable_bits: bool = False  # a position may hold the complement of an input bit


SHAPES = (
    Shape("V_DOT8_I32_IU4 signed-lanes", 8, 4, True, -8, 7),
    Shape("V_DOT8_I32_IU4 unsigned-lanes", 8, 4, False, -8, 7),
    Shape("V_DOT8_U32_U4", 8, 4, False, 0, 15),
    Shape("V_DOT4_I32_IU8 signed-lanes", 4, 8, True, -128, 127),
    Shape("V_DOT4_I32_IU8 unsigned-lanes", 4, 8, False, -128, 127),
    Shape("V_DOT4_U32_U8", 4, 8, False, 0, 255),
    Shape("V_MAD_U32_U24", 1, 24, False, 0, (1 << 24) - 1),
    Shape("V_MAD_I32_I24", 1, 24, True, -(1 << 23), (1 << 23) - 1),
    Shape("V_MUL_LO_U32", 1, 32, False, 0, M32 - 1),
    Shape("V_ADD3/V_LSHL_ADD/V_XAD", 1, 32, False, 1, 1, acc_wires=2, negatable_bits=True),
)


def target_coefficients(a):
    """Unique affine expansion of the output word in the sixteen input bits."""
    p: Prepared = prepare(a)
    k = p.coeffs  # coefficients of (b0+1, b1+1, c0+1, c1+1) inside one output byte
    coeff = {}
    for column, scale in ((0, 1), (1, 256)):
        for j in range(4):
            field = 4 * column + j
            coeff[2 * field] = scale * k[j]          # bit "code == 1"
            coeff[2 * field + 1] = 2 * scale * k[j]  # bit "code == 2"
    return coeff, 257 * p.bias


def lane_place_values(shape: Shape):
    """Signed place value of every offset inside one lane."""
    return [(-(1 << (shape.width - 1)) if (shape.signed_lanes and o == shape.width - 1)
             else (1 << o)) for o in range(shape.width)]


def build(shape: Shape, coeff, constant):
    m = cp_model.CpModel()
    bits = sorted(coeff)
    places = lane_place_values(shape)
    lane_span = max(abs(shape.weight_lo), abs(shape.weight_hi)) * sum(abs(p) for p in places)
    reach = shape.lanes * lane_span + max(abs(v) for v in coeff.values()) + abs(constant) + 4
    acc_positions = min(32, max(2, reach.bit_length() + 1))
    big = max(abs(shape.weight_lo), abs(shape.weight_hi)) * lane_span + 1

    weights = [m.NewIntVar(shape.weight_lo, shape.weight_hi, f"w{i}") for i in range(shape.lanes)]
    for i in range(1, shape.lanes):  # lanes are interchangeable
        m.Add(weights[i - 1] >= weights[i])

    per_bit = {b: [] for b in bits}
    const_terms = []

    for i in range(shape.lanes):
        select = {b: [] for b in bits}
        const_select = []
        for o, place in enumerate(places):
            choice = []
            for b in bits:
                sel = m.NewBoolVar(f"x{i}_{o}_{b}")
                select[b].append((place, sel))
                choice.append(sel)
                if shape.negatable_bits:
                    nsel = m.NewBoolVar(f"n{i}_{o}_{b}")
                    select[b].append((-place, nsel))
                    const_select.append((place, nsel))
                    choice.append(nsel)
            one = m.NewBoolVar(f"one{i}_{o}")
            const_select.append((place, one))
            choice.append(one)
            m.AddAtMostOne(choice)
        for b in bits:
            lam = m.NewIntVar(-lane_span, lane_span, f"lam{i}_{b}")
            m.Add(lam == sum(place * sel for place, sel in select[b]))
            prod = m.NewIntVar(-big, big, f"p{i}_{b}")
            m.AddMultiplicationEquality(prod, [weights[i], lam])
            per_bit[b].append(prod)
        kappa = m.NewIntVar(-lane_span, lane_span, f"kap{i}")  # constant bits wired into the lane
        m.Add(kappa == sum(place * sel for place, sel in const_select))
        prodk = m.NewIntVar(-big, big, f"pk{i}")
        m.AddMultiplicationEquality(prodk, [weights[i], kappa])
        const_terms.append(prodk)

    for reg in range(shape.acc_wires):
        for q in range(acc_positions):
            choice = []
            for b in bits:
                sel = m.NewBoolVar(f"y{reg}_{q}_{b}")
                per_bit[b].append(sel * (1 << q))
                choice.append(sel)
                if shape.negatable_bits:
                    nsel = m.NewBoolVar(f"yn{reg}_{q}_{b}")
                    per_bit[b].append(nsel * (-(1 << q)))
                    const_terms.append(nsel * (1 << q))
                    choice.append(nsel)
            one = m.NewBoolVar(f"yone{reg}_{q}")
            const_terms.append(one * (1 << q))
            choice.append(one)
            m.AddAtMostOne(choice)

    wrapping = shape.width >= 32
    for b in bits:
        if wrapping:
            wrap = m.NewIntVar(-4, 4, f"m{b}")
            m.Add(sum(per_bit[b]) == coeff[b] + M32 * wrap)
        else:
            m.Add(sum(per_bit[b]) == coeff[b])
    k = m.NewIntVar(-M32, M32, "K")  # prepared constant addend, always available
    const_terms.append(k)
    wrapc = m.NewIntVar(-8, 8, "mc")
    m.Add(sum(const_terms) == constant + M32 * wrapc)
    return m, weights, acc_positions


def feasible(shape: Shape, coeff, constant, seconds=60.0, workers=8):
    m, weights, _ = build(shape, coeff, constant)
    solver = cp_model.CpSolver()
    solver.parameters.num_workers = workers
    solver.parameters.max_time_in_seconds = seconds
    status = solver.Solve(m)
    if status in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return "feasible", {"weights": [solver.Value(w) for w in weights]}
    if status == cp_model.INFEASIBLE:
        return "infeasible", None
    return "unknown", None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output")
    parser.add_argument("--seconds", type=float, default=60.0)
    parser.add_argument("--matrices", default="all")
    parser.add_argument("--shapes", default="all")
    args = parser.parse_args()

    matrices = (all_matrices() if args.matrices == "all"
                else [tuple(int(v) for v in g.split(",")) for g in args.matrices.split(";")])
    shapes = [s for s in SHAPES if args.shapes == "all" or s.name in args.shapes.split(";")]

    results = {}
    for a in matrices:
        coeff, constant = target_coefficients(a)
        row = {}
        for shape in shapes:
            verdict, witness = feasible(shape, coeff, constant, seconds=args.seconds)
            row[shape.name] = verdict if witness is None else [verdict, witness]
        results[str(a)] = row
        print(str(a), {k: (v[0] if isinstance(v, list) else v) for k, v in row.items()}, flush=True)

    summary = {
        "feasible_with_one_instruction": sorted(
            k for k, v in results.items()
            if any(x == "feasible" or isinstance(x, list) for x in v.values())),
        "undecided": sorted(k for k, v in results.items() if any(x == "unknown" for x in v.values())),
        "results": results,
        "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    }
    if args.output:
        Path(args.output).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
