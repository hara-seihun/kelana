#!/usr/bin/env python3
"""Per-A search for a ONE-instruction realisation, with replay verification.

The wire packing here is allowed to depend on A.  That is legitimate in the
stated reuse regime (A is loaded once and reused indefinitely, so its packing
network is fixed for the whole run), but it is a weaker claim than the
two-instruction construction, whose packing serves every A unchanged.
"""
from __future__ import annotations

import argparse
import itertools
import json
from pathlib import Path

from model import all_matrices
from single_dot import Witness, oriented, search, verify

ORIENTATIONS = ((1, 1), (1, -1), (-1, 1), (-1, -1))
CONFIGS = ((False, 4), (False, 3), (True, 4))


def find(a, seconds=2.0):
    scored = sorted(ORIENTATIONS, key=lambda hl: -sum(1 for v in oriented(a, *hl)[2] if v >= 0))
    for hi, lo in scored:
        coeff, constant, k = oriented(a, hi, lo)
        for signed, odd in CONFIGS:
            w = search(coeff, constant, (-128, 127), seconds=seconds,
                       odd_lanes=odd, signed_lanes=signed)
            if isinstance(w, Witness):
                assert verify(a, w, signed_lanes=signed, orientation=(hi, lo)), (a, hi, lo)
                return {"orientation": [hi, lo], "k": list(k), "signed_lanes": signed,
                        "weights": list(w.weights),
                        "lane_bits": {f"{i},{o}": b for (i, o), b in sorted(w.lane_bits.items())},
                        "lane_ones": [list(v) for v in sorted(w.lane_ones)],
                        "acc_bits": {str(q): b for q, b in sorted(w.acc_bits.items())},
                        "acc_ones": sorted(w.acc_ones)}
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--count", type=int, default=81)
    parser.add_argument("--seconds", type=float, default=2.0)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    path = Path(args.output)
    found = json.loads(path.read_text()) if path.exists() else {}
    for a in all_matrices()[args.start:args.start + args.count]:
        if str(a) in found:
            continue
        w = find(a, seconds=args.seconds)
        found[str(a)] = w
        print(a, "one-instruction" if w else "not found", flush=True)
        path.write_text(json.dumps(found, indent=2, sort_keys=True) + "\n")
    hits = sum(1 for v in found.values() if v)
    print(f"{hits}/{len(found)} matrices realised by one instruction")


if __name__ == "__main__":
    main()
