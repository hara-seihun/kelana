#!/usr/bin/env python3
"""Search for, and verify, a ONE-instruction realisation of the whole output word.

The instruction is a dot product: result = sum_i w_i * lane_i(S1) + S2, where S1
and S2 are wire registers (every bit position holds a constant or a copy of one
input bit) and the weights w_i are prepared from A.  Nothing here is relaxed:
the constant term is produced by wired constant bits, and every candidate is
replayed against the reference map on all 6561 dynamic inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
from dataclasses import dataclass
from pathlib import Path

from ortools.sat.python import cp_model

from model import TRITS, Wire, all_matrices, dot, input_word, output_word, pack_lanes, prepare


def oriented(a, hi, lo):
    """Coefficients and constant of the output word for a chosen sign orientation.

    The orientation is prepared metadata shared with the decoder, so any of the
    four sign pairs is a legal representation; only the int4 construction needs
    the coefficients to fit a nibble."""
    a00, a01, a10, a11 = a
    k = (lo * a10 + 7 * hi * a00, lo * a11 + 7 * hi * a01, 7 * hi, lo)
    bias = 24 - sum(k)
    coeff = {}
    for column, scale in ((0, 1), (1, 256)):
        for j in range(4):
            field = 4 * column + j
            coeff[2 * field] = scale * k[j]
            coeff[2 * field + 1] = 2 * scale * k[j]
    return coeff, 257 * bias, k


@dataclass(frozen=True)
class Witness:
    weights: tuple
    lane_bits: dict     # (lane, offset) -> input bit
    lane_ones: tuple    # (lane, offset) holding a constant 1
    acc_bits: dict      # acc position -> input bit
    acc_ones: tuple


def search(coeff, constant, weights, width=8, lanes=4, signed_lanes=False,
           acc_positions=20, seconds=10.0, workers=8, odd_lanes=None):
    """weights: fixed tuple, or (lo, hi) bounds to let the solver choose them."""
    bits = [b for b in sorted(coeff) if coeff[b] != 0]
    places = [-(1 << (width - 1)) if (signed_lanes and o == width - 1) else (1 << o)
              for o in range(width)]
    m = cp_model.CpModel()
    free_weights = not isinstance(weights, tuple) or len(weights) != lanes
    if free_weights:
        lo, hi = weights
        wvars = [m.NewIntVar(lo, hi, f"w{i}") for i in range(lanes)]
        for i in range(1, lanes):
            m.Add(wvars[i - 1] >= wvars[i])
        if odd_lanes is not None:
            parity = []
            for i in range(lanes):
                p = m.NewIntVar(0, 1, f"par{i}")
                m.AddModuloEquality(p, wvars[i], 2)
                parity.append(p)
            m.Add(sum(parity) == odd_lanes)
        span = max(abs(lo), abs(hi)) * (1 << width)
    lane_sel, acc_sel, lane_one, acc_one = {}, {}, {}, {}
    per_bit = {b: [] for b in bits}
    const_terms = []

    for i in range(lanes):
        for o, place in enumerate(places):
            choice = []
            for b in bits:
                v = m.NewBoolVar(f"l{i}_{o}_{b}")
                lane_sel[(i, o, b)] = v
                if free_weights:
                    t = m.NewIntVar(-span, span, f"lt{i}_{o}_{b}")
                    m.Add(t == place * wvars[i]).OnlyEnforceIf(v)
                    m.Add(t == 0).OnlyEnforceIf(v.Not())
                    per_bit[b].append(t)
                else:
                    per_bit[b].append(weights[i] * place * v)
                choice.append(v)
            one = m.NewBoolVar(f"lone{i}_{o}")
            lane_one[(i, o)] = one
            if free_weights:
                t = m.NewIntVar(-span, span, f"lc{i}_{o}")
                m.Add(t == place * wvars[i]).OnlyEnforceIf(one)
                m.Add(t == 0).OnlyEnforceIf(one.Not())
                const_terms.append(t)
            else:
                const_terms.append(weights[i] * place * one)
            choice.append(one)
            m.AddAtMostOne(choice)

    for q in range(acc_positions):
        choice = []
        for b in bits:
            v = m.NewBoolVar(f"a{q}_{b}")
            acc_sel[(q, b)] = v
            per_bit[b].append((1 << q) * v)
            choice.append(v)
        one = m.NewBoolVar(f"aone{q}")
        acc_one[q] = one
        const_terms.append((1 << q) * one)
        choice.append(one)
        m.AddAtMostOne(choice)

    for b in bits:
        m.Add(sum(per_bit[b]) == coeff[b])
    m.Add(sum(const_terms) == constant)

    solver = cp_model.CpSolver()
    solver.parameters.num_workers = workers
    solver.parameters.max_time_in_seconds = seconds
    status = solver.Solve(m)
    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return None if status == cp_model.INFEASIBLE else "unknown"
    chosen = tuple(solver.Value(v) for v in wvars) if free_weights else tuple(weights)
    return Witness(
        weights=chosen,
        lane_bits={(i, o): b for (i, o, b), v in lane_sel.items() if solver.Value(v)},
        lane_ones=tuple(k for k, v in lane_one.items() if solver.Value(v)),
        acc_bits={q: b for (q, b), v in acc_sel.items() if solver.Value(v)},
        acc_ones=tuple(q for q, v in acc_one.items() if solver.Value(v)),
    )


def build_wires(w: Witness, width=8):
    lane = Wire("dot lane source")
    for (i, o), b in w.lane_bits.items():
        lane.place_bit(width * i + o, b)
    for (i, o) in w.lane_ones:
        lane.constants[width * i + o] = 1
    acc = Wire("dot accumulator source")
    for q, b in w.acc_bits.items():
        acc.place_bit(q, b)
    for q in w.acc_ones:
        acc.constants[q] = 1
    return lane, acc


def expected_word(a, hi, lo, b, c):
    coeff, constant, k = oriented(a, hi, lo)
    b00, b01, b10, b11 = b
    c00, c01, c10, c11 = c
    col0 = sum(x * (y + 1) for x, y in zip(k, (b00, b10, c00, c10)))
    col1 = sum(x * (y + 1) for x, y in zip(k, (b01, b11, c01, c11)))
    bias = constant // 257
    return (col0 + bias) + 256 * (col1 + bias)


def verify(a, w: Witness, width=8, lanes=4, signed_lanes=False, orientation=None):
    lane, acc = build_wires(w, width)
    weight_word = pack_lanes(w.weights, width)
    for b in itertools.product(TRITS, repeat=4):
        for c in itertools.product(TRITS, repeat=4):
            x = input_word(b, c)
            got = dot(weight_word, lane(x), acc(x), lanes=lanes, width=width,
                      signed0=True, signed1=signed_lanes)
            want = (output_word(a, b, c) if orientation is None
                    else expected_word(a, orientation[0], orientation[1], b, c))
            if got != want:
                return False
    return True


def weight_candidates(coeff, limit=None):
    """Weights worth trying: small multiples of the coefficient magnitudes."""
    base = sorted({abs(v) for v in coeff.values() if v})
    values = {1}
    for v in base:
        for shift in range(9):
            if v % (1 << shift) == 0:
                values.add(v >> shift)
            values.add(v << shift)
    values = sorted(v for v in values if v <= 127)
    out = []
    for combo in itertools.combinations_with_replacement(values, 4):
        out.append(combo)
    if limit:
        out = out[:limit]
    return out


def find(a, seconds=6.0, verbose=False):
    coeff, constant = target_coefficients(a)
    for weights in weight_candidates(coeff):
        for signs in ({(1, 1, 1, 1)} if all(v >= 0 for v in coeff.values())
                      else {(1, 1, 1, 1), (1, 1, 1, -1), (1, 1, -1, -1), (1, -1, -1, -1),
                            (-1, -1, -1, -1), (1, -1, 1, -1)}):
            signed = tuple(s * w for s, w in zip(signs, weights))
            if not all(-128 <= v <= 127 for v in signed):
                continue
            w = search(coeff, constant, signed, seconds=seconds)
            if isinstance(w, Witness):
                if verify(a, w):
                    return w
                raise AssertionError("witness failed replay")
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--matrices", default="1,0,0,1")
    parser.add_argument("--seconds", type=float, default=6.0)
    parser.add_argument("--output")
    args = parser.parse_args()
    matrices = (all_matrices() if args.matrices == "all"
                else [tuple(int(v) for v in g.split(",")) for g in args.matrices.split(";")])
    found = {}
    for a in matrices:
        w = find(a, seconds=args.seconds)
        found[str(a)] = None if w is None else {
            "weights": list(w.weights),
            "lane_bits": {f"{i},{o}": b for (i, o), b in sorted(w.lane_bits.items())},
            "lane_ones": [list(k) for k in sorted(w.lane_ones)],
            "acc_bits": {str(q): b for q, b in sorted(w.acc_bits.items())},
            "acc_ones": sorted(w.acc_ones),
        }
        print(a, "one-instruction" if w else "not found", flush=True)
    if args.output:
        Path(args.output).write_text(json.dumps(
            {"witnesses": found,
             "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},
            indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
