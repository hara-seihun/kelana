#!/usr/bin/env python3
"""Scan the open case: one 8-bit-lane dot, shared wiring, weights affine in k.

For each candidate pair (p, q) the weight rule w = k0*p + k1*q + r is fixed, so
the placement problem becomes small and CP-SAT decides it in milliseconds.  A
feasible pair would mean the online core collapses to a single instruction with
A-independent packing; every pair scanned so far is infeasible.

This is evidence, not a proof: it fixes the orientation at (1,1), restricts the
weight rule to be affine in k, and bounds p and q.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import random
import time
from pathlib import Path

from ortools.sat.python import cp_model

import shared_one as S


def candidates(values, mass):
    return [p for p in itertools.product(values, repeat=4) if 0 < sum(abs(v) for v in p) <= mass]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--values", default="-8,-4,-3,-2,-1,0,1,2,3,4,8")
    parser.add_argument("--mass", type=int, default=12)
    parser.add_argument("--partners", type=int, default=3)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--budget", type=float, default=45.0)
    parser.add_argument("--per-case", type=float, default=0.5)
    parser.add_argument("--output")
    args = parser.parse_args()

    values = tuple(int(v) for v in args.values.split(","))
    cands = candidates(values, args.mass)
    random.seed(args.seed)
    random.shuffle(cands)

    start = time.time()
    tried = feasible = undecided = 0
    witnesses = []
    for p in cands:
        for q in random.sample(cands, args.partners):
            for signed in (False, True):
                model, *_ = S.build(signed, fixed_p=list(p), fixed_q=list(q))
                solver = cp_model.CpSolver()
                solver.parameters.num_workers = 2
                solver.parameters.max_time_in_seconds = args.per_case
                name = solver.StatusName(solver.Solve(model))
                tried += 1
                if name in ("OPTIMAL", "FEASIBLE"):
                    feasible += 1
                    witnesses.append({"p": list(p), "q": list(q), "signed_lanes": signed})
                elif name == "UNKNOWN":
                    undecided += 1
            if time.time() - start > args.budget:
                break
        if time.time() - start > args.budget:
            break

    result = {"tried": tried, "feasible": feasible, "undecided": undecided,
              "witnesses": witnesses, "seed": args.seed, "values": list(values),
              "mass": args.mass, "seconds": round(time.time() - start, 1),
              "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    text = json.dumps(result, indent=2, sort_keys=True)
    print(text)
    if args.output:
        Path(args.output).write_text(text + "\n")


if __name__ == "__main__":
    main()
