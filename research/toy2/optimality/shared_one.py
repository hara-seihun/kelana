#!/usr/bin/env python3
"""Search for ONE instruction with a single A-independent wire packing.

Fix the sign orientation at (h, l) = (1, 1), which is legal for every A because
the orientation is prepared decoder metadata.  Then

    k = (a10 + 7*a00, a11 + 7*a01, 7, 1),

so only k0 and k1 depend on A, each ranging over {-8,-7,-6,-1,0,1,6,7,8}, and
the output word is

    W(A, x) = sum_j k_j * (u_j^0 + 256 * u_j^1) + 257 * (16 - k0 - k1).

We look for one wire register (four byte lanes), one wire accumulator, and a
weight rule w(A) = k0*p + k1*q + r, all A-independent except the prepared
weights themselves.  A solution means the incumbent's three online instructions
collapse to one without any A-dependent packing.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
from pathlib import Path

from ortools.sat.python import cp_model

from model import TRITS, Wire, all_matrices, dot, input_word, pack_lanes

LANES, WIDTH, ACC_BITS = 4, 8, 20
K_VALUES = (-8, -7, -6, -1, 0, 1, 6, 7, 8)
# bit -> (code index 0..3, scale inside the output word)
BIT_INFO = {}
for column, column_scale in ((0, 1), (1, 256)):
    for j in range(4):
        field = 4 * column + j
        BIT_INFO[2 * field] = (j, column_scale)
        BIT_INFO[2 * field + 1] = (j, 2 * column_scale)

FIXED_K = {2: 7, 3: 1}  # the c-code slots have A-independent coefficients


def build(signed_lanes=False, weight_limit=127, fixed_p=None, fixed_q=None):
    m = cp_model.CpModel()
    places = [-(1 << (WIDTH - 1)) if (signed_lanes and o == WIDTH - 1) else (1 << o)
              for o in range(WIDTH)]
    bits = sorted(BIT_INFO)

    lane_sel, lane_one = {}, {}
    for i in range(LANES):
        for o in range(WIDTH):
            choice = []
            for b in bits:
                v = m.NewBoolVar(f"l{i}_{o}_{b}")
                lane_sel[(i, o, b)] = v
                choice.append(v)
            one = m.NewBoolVar(f"lone{i}_{o}")
            lane_one[(i, o)] = one
            choice.append(one)
            m.AddAtMostOne(choice)

    acc_sel, acc_one = {}, {}
    for q in range(ACC_BITS):
        choice = []
        for b in bits:
            v = m.NewBoolVar(f"a{q}_{b}")
            acc_sel[(q, b)] = v
            choice.append(v)
        one = m.NewBoolVar(f"aone{q}")
        acc_one[q] = one
        choice.append(one)
        m.AddAtMostOne(choice)

    span = (1 << WIDTH)
    lam = {}
    for i in range(LANES):
        for b in bits:
            v = m.NewIntVar(-span, span, f"lam{i}_{b}")
            m.Add(v == sum(places[o] * lane_sel[(i, o, b)] for o in range(WIDTH)))
            lam[(i, b)] = v
    kappa = []
    for i in range(LANES):
        v = m.NewIntVar(-span, span, f"kap{i}")
        m.Add(v == sum(places[o] * lane_one[(i, o)] for o in range(WIDTH)))
        kappa.append(v)

    p = [m.NewIntVar(-16, 16, f"p{i}") for i in range(LANES)]
    q = [m.NewIntVar(-16, 16, f"q{i}") for i in range(LANES)]
    for i in range(LANES):
        if fixed_p is not None:
            m.Add(p[i] == fixed_p[i])
        if fixed_q is not None:
            m.Add(q[i] == fixed_q[i])
    r = [m.NewIntVar(-weight_limit, weight_limit, f"r{i}") for i in range(LANES)]
    for k0, k1 in itertools.product((-8, 8), repeat=2):
        for i in range(LANES):
            m.Add(k0 * p[i] + k1 * q[i] + r[i] <= weight_limit)
            m.Add(k0 * p[i] + k1 * q[i] + r[i] >= -weight_limit - 1)

    big = 17 * span

    def dotprod(vec, values, name):
        terms = []
        for i in range(LANES):
            t = m.NewIntVar(-big, big, f"{name}{i}")
            m.AddMultiplicationEquality(t, [vec[i], values[i]])
            terms.append(t)
        return sum(terms)

    for b in bits:
        j, scale = BIT_INFO[b]
        values = [lam[(i, b)] for i in range(LANES)]
        alpha = sum((1 << qq) * acc_sel[(qq, b)] for qq in range(ACC_BITS))
        m.Add(dotprod(p, values, f"dp{b}_") == (scale if j == 0 else 0))
        m.Add(dotprod(q, values, f"dq{b}_") == (scale if j == 1 else 0))
        m.Add(dotprod(r, values, f"dr{b}_") + alpha == FIXED_K.get(j, 0) * scale)

    kconst = sum((1 << qq) * acc_one[qq] for qq in range(ACC_BITS))
    m.Add(dotprod(p, kappa, "kp") == -257)
    m.Add(dotprod(q, kappa, "kq") == -257)
    m.Add(dotprod(r, kappa, "kr") + kconst == 257 * 16)
    return m, lane_sel, lane_one, acc_sel, acc_one, p, q, r, places


def extract(solver, lane_sel, lane_one, acc_sel, acc_one, p, q, r):
    lane = {}
    for (i, o, b), v in lane_sel.items():
        if solver.Value(v):
            lane[(i, o)] = b
    ones = [k for k, v in lane_one.items() if solver.Value(v)]
    acc = {q_: b for (q_, b), v in acc_sel.items() if solver.Value(v)}
    acc_ones = [q_ for q_, v in acc_one.items() if solver.Value(v)]
    return {"lane_bits": lane, "lane_ones": ones, "acc_bits": acc, "acc_ones": acc_ones,
            "p": [solver.Value(v) for v in p], "q": [solver.Value(v) for v in q],
            "r": [solver.Value(v) for v in r]}


def replay(sol, signed_lanes=False):
    lane = Wire()
    for (i, o), b in sol["lane_bits"].items():
        lane.place_bit(WIDTH * i + o, b)
    for (i, o) in sol["lane_ones"]:
        lane.constants[WIDTH * i + o] = 1
    acc = Wire()
    for q_, b in sol["acc_bits"].items():
        acc.place_bit(q_, b)
    for q_ in sol["acc_ones"]:
        acc.constants[q_] = 1
    for a in all_matrices():
        a00, a01, a10, a11 = a
        k = (a10 + 7 * a00, a11 + 7 * a01, 7, 1)
        weights = [k[0] * sol["p"][i] + k[1] * sol["q"][i] + sol["r"][i] for i in range(LANES)]
        if not all(-128 <= w <= 127 for w in weights):
            return False, a, "weight out of int8"
        word = pack_lanes(weights, WIDTH)
        bias = 24 - sum(k)
        for b in itertools.product(TRITS, repeat=4):
            for c in itertools.product(TRITS, repeat=4):
                x = input_word(b, c)
                b00, b01, b10, b11 = b
                c00, c01, c10, c11 = c
                col0 = sum(kk * (t + 1) for kk, t in zip(k, (b00, b10, c00, c10))) + bias
                col1 = sum(kk * (t + 1) for kk, t in zip(k, (b01, b11, c01, c11))) + bias
                got = dot(word, lane(x), acc(x), LANES, WIDTH, True, signed_lanes)
                if got != col0 + 256 * col1:
                    return False, a, (b, c, got, col0 + 256 * col1)
    return True, None, None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=float, default=45.0)
    parser.add_argument("--signed-lanes", action="store_true")
    parser.add_argument("--workers", type=int, default=12)
    parser.add_argument("--output")
    parser.add_argument("--p")
    parser.add_argument("--q")
    args = parser.parse_args()

    fp = [int(v) for v in args.p.split(',')] if args.p else None
    fq = [int(v) for v in args.q.split(',')] if args.q else None
    m, lane_sel, lane_one, acc_sel, acc_one, p, q, r, _ = build(args.signed_lanes, fixed_p=fp, fixed_q=fq)
    solver = cp_model.CpSolver()
    solver.parameters.num_workers = args.workers
    solver.parameters.max_time_in_seconds = args.seconds
    status = solver.Solve(m)
    print(solver.StatusName(status))
    result = {"status": solver.StatusName(status), "signed_lanes": args.signed_lanes,
              "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    if status in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        sol = extract(solver, lane_sel, lane_one, acc_sel, acc_one, p, q, r)
        ok, where, detail = replay(sol, args.signed_lanes)
        print("replay", ok, where, detail)
        result["solution"] = {"lane_bits": {f"{i},{o}": b for (i, o), b in sorted(sol["lane_bits"].items())},
                              "lane_ones": [list(v) for v in sorted(sol["lane_ones"])],
                              "acc_bits": {str(k): v for k, v in sorted(sol["acc_bits"].items())},
                              "acc_ones": sorted(sol["acc_ones"]),
                              "p": sol["p"], "q": sol["q"], "r": sol["r"]}
        result["replay_all_matrices"] = ok
    if args.output:
        Path(args.output).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
