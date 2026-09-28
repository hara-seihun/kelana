"""The two negatives that do not need a solver, and the window-shape sweep.

    python3 negatives.py

1. No multiplier reaches a usable lane index from the two-bit packed word. The
   search space is 128 residues, not 2^32, because `ds_bpermute_b32` reads
   address bits [6:2] and `(raw * M) mod 128` depends only on `M mod 128`.

2. The two-trit register-window shape does not extend to three trits. Each
   shape is an exhaustive SMT query over all wirings and constants.
"""

from __future__ import annotations

import json
import multiprocessing as mp
import random
from typing import List

from isa import BY_NAME
from model import STATES, packed2
from panel import RESULTS, spec_for
from synth import Synthesizer

WINDOW_SHAPES = [
    ("v_bfe_u32", "v_perm_b32"),
    ("v_alignbit_b32", "v_perm_b32"),
    ("v_alignbit_b32", "v_bfe_u32"),
    ("v_lshrrev_b32", "v_and_b32"),
    ("v_alignbit_b32", "v_and_b32"),
    ("v_bfe_u32", "v_bfe_u32"),
]


def multiplier_negative(trials: int = 2000, seed: int = 11) -> dict:
    raws = [packed2(x) for x in STATES]
    best = 0
    injective: List[int] = []
    for m in range(128):
        lanes = {((r * m) >> 2) & 31 for r in raws}
        best = max(best, len(lanes))
        if len(lanes) == 27:
            injective.append(m)
    rng = random.Random(seed)
    reduction_holds = True
    for _ in range(trials):
        m = rng.randrange(1 << 32)
        a = {((r * m) >> 2) & 31 for r in raws}
        b = {((r * (m % 128)) >> 2) & 31 for r in raws}
        if a != b:
            reduction_holds = False
    return {
        "claim": "no 32-bit multiplier turns the two-bit packed word into a "
                 "ds_bpermute_b32 lane index that separates all 27 states",
        "argument": "the lane index is bits [6:2] of the product, and "
                    "(raw*M) mod 128 = (raw*(M mod 128)) mod 128",
        "valid_words": sorted(raws),
        "residues_checked": 128,
        "covers_multipliers": 2 ** 32,
        "injective_residues": injective,
        "max_distinct_lanes": best,
        "states": 27,
        "reduction_spot_checked_on": trials,
        "reduction_holds": reduction_holds,
    }


def _window_case(task: tuple) -> dict:
    net, contract, shape, timeout_ms = task
    spec = spec_for(net, contract, "byte", "exact")
    r = Synthesizer(spec, [BY_NAME[n] for n in shape], n_consts=6,
                    timeout_ms=timeout_ms).run()
    return {
        "network": net, "image": int(net.split("i")[1]),
        "contract": contract, "shape": list(shape),
        "outcome": r.outcome, "seconds": round(r.seconds, 2),
        "program": r.program,
    }


def window_negative(timeout_ms: int = 30000, workers: int = 24) -> dict:
    tasks = [(net, contract, shape, timeout_ms)
             for net in ("w1i5", "w2i8")
             for contract in ("packed2", "radix3")
             for shape in WINDOW_SHAPES]
    with mp.get_context("fork").Pool(workers) as pool:
        rows = pool.map(_window_case, tasks)
    for r in rows:
        print(f"{r['network']:6s} {r['contract']:8s} "
              f"{'+'.join(r['shape']):34s} -> {r['outcome']:8s} "
              f"{r['seconds']:6.2f}s", flush=True)
    return {
        "claim": "no register-window shape realizes a three-trit map exactly, "
                 "including the two-instruction shape that solves two trits",
        "output_contract": "low byte equals the map's value",
        "constants_allowed": 6,
        "per_query_timeout_ms": timeout_ms,
        "rows": rows,
        "any_sat": any(r["outcome"] == "sat" for r in rows),
        "unexplored": [r for r in rows if r["outcome"] == "timeout"],
    }


if __name__ == "__main__":
    out = {"multiplier": multiplier_negative()}
    m = out["multiplier"]
    print(f"multiplier: {len(m['injective_residues'])} of 128 residues work, "
          f"best separates {m['max_distinct_lanes']}/27, "
          f"reduction holds on {m['reduction_spot_checked_on']} random M: "
          f"{m['reduction_holds']}")
    print()
    out["window"] = window_negative()
    RESULTS.mkdir(parents=True, exist_ok=True)
    (RESULTS / "negatives.json").write_text(json.dumps(out, indent=1))
    print(f"\nany window shape sat: {out['window']['any_sat']}")
