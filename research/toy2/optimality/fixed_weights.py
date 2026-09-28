#!/usr/bin/env python3
"""Decide the single-instruction placement problem once the lane weights are fixed.

With the weights fixed the instruction offers a known multiset of tokens: one
token w_i * 2**o per lane position, plus one token 2**q per accumulator-wire
position.  Every token may serve at most one input bit, and each input bit's
target coefficient must be the exact sum of the tokens it receives.  That is a
small assignment problem which CP-SAT decides in milliseconds, so it is usable
as the inner loop of a weight search.
"""
from __future__ import annotations

from ortools.sat.python import cp_model


def tokens(weights, width, signed_lanes, acc_bits):
    out = []
    for i, w in enumerate(weights):
        for o in range(width):
            place = -(1 << (width - 1)) if (signed_lanes and o == width - 1) else (1 << o)
            out.append(w * place)
    out.extend(1 << q for q in range(acc_bits))
    return out


def solve(coeff, weights, width, signed_lanes=False, acc_bits=18, seconds=5.0, workers=4):
    bits = [b for b in sorted(coeff) if coeff[b] != 0]
    toks = tokens(weights, width, signed_lanes, acc_bits)
    m = cp_model.CpModel()
    sel = {}
    for t, value in enumerate(toks):
        choice = []
        for b in bits:
            v = m.NewBoolVar(f"s{t}_{b}")
            sel[(t, b)] = v
            choice.append(v)
        m.AddAtMostOne(choice)
    for b in bits:
        m.Add(sum(value * sel[(t, b)] for t, value in enumerate(toks)) == coeff[b])
    solver = cp_model.CpSolver()
    solver.parameters.num_workers = workers
    solver.parameters.max_time_in_seconds = seconds
    status = solver.Solve(m)
    if status in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        placement = {}
        for b in bits:
            placement[b] = [toks[t] for t in range(len(toks)) if solver.Value(sel[(t, b)])]
        return "feasible", placement
    if status == cp_model.INFEASIBLE:
        return "infeasible", None
    return "unknown", None
