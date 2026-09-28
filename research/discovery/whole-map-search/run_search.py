"""Resumable driver: one SMT query per component multiset, results on disk.

    python3 run_search.py JOB [--budget SECONDS] [--workers N] [--retry-timeouts]

A job fixes a network, an input contract, an output contract, a number of VALU
instructions, and whether a final `ds_bpermute_b32` is allowed. Its queue is
every multiset of that size drawn from the library, one SMT query each, so a
completed job with no `sat` is a negative over that whole space and a job with
timeouts reports exactly which multisets remain unexplored.

Job name: NETWORK-CONTRACT-PROJECTION-MODE-SIZE  e.g. w256i27-bytes-lane5-refine-1

The input contract names the packed word the program actually receives. Nothing
in the search recovers individual trits from it; the packed word is the input
coordinate system and the components are maps on it.
"""

from __future__ import annotations

import itertools
import json
import multiprocessing as mp
import sys
import time
from pathlib import Path
from typing import List

from isa import LIBRARY, BY_NAME
from panel import RESULTS, load_panel, spec_for
from synth import Synthesizer

FULL = [c.name for c in LIBRARY]
# Subset used where the full library does not fit the budget; every component
# here is one the full-library sweeps at smaller sizes showed to matter.
CORE = [
    "v_add_nc_u32", "v_sub_nc_u32", "v_mul_lo_u32", "v_and_b32", "v_xor_b32",
    "v_lshlrev_b32", "v_lshrrev_b32", "v_bfe_u32", "v_perm_b32",
    "v_lshl_add_u32", "v_add3_u32", "v_dot4_i32_i8", "v_alignbit_b32",
    "v_med3_i32", "v_sad_u8",
]
LIBS = {"full": FULL, "core": CORE}

CONSTS_BY_SIZE = {0: 2, 1: 3, 2: 4, 3: 6}


def parse_job(job: str) -> dict:
    net, contract, projection, mode, size = job.split("-")
    size = int(size)
    lib = "core" if size >= 3 else "full"
    # An `exact` search must not be limited by its own constant budget: the
    # prepared operands have to be able to carry the map. 3 slots per
    # instruction is the most the encoding can name.
    n_consts = 3 * size if mode == "exact" else CONSTS_BY_SIZE[size]
    return {
        "network": net, "contract": contract, "projection": projection,
        "mode": mode, "valu": size, "library": lib,
        "n_consts": max(n_consts, 2),
    }


def queue_for(cfg: dict) -> List[dict]:
    lib = LIBS[cfg["library"]]
    return [{"components": list(sub)}
            for sub in itertools.combinations_with_replacement(lib, cfg["valu"])]


def key(item: dict) -> str:
    return json.dumps(item["components"])


_WORK: dict = {}


def _init(cfg: dict) -> None:
    _WORK["spec"] = spec_for(cfg["network"], cfg["contract"], cfg["projection"],
                             cfg["mode"])
    _WORK["cfg"] = cfg


def _solve(item: dict) -> tuple:
    cfg = _WORK["cfg"]
    comps = [BY_NAME[n] for n in item["components"]]
    syn = Synthesizer(_WORK["spec"], comps, n_consts=cfg["n_consts"],
                      timeout_ms=cfg["timeout_ms"])
    r = syn.run()
    return (key(item), r.outcome, round(r.seconds, 3), list(r.multiset),
            r.program, r.constants, r.table, r.observed, r.relabel,
            r.relabel_is_bijective)


def main() -> None:
    job = sys.argv[1]
    argv = sys.argv
    budget = float(argv[argv.index("--budget") + 1]) if "--budget" in argv else 45.0
    workers = int(argv[argv.index("--workers") + 1]) if "--workers" in argv else 28
    timeout_ms = int(argv[argv.index("--timeout-ms") + 1]) if "--timeout-ms" in argv else 15000
    cfg = parse_job(job)
    cfg["timeout_ms"] = timeout_ms
    path = RESULTS / f"search-{job}.json"
    state = json.loads(path.read_text()) if path.exists() else {
        "job": job, **cfg, "library_components": LIBS[cfg["library"]],
        "done": {}, "solutions": [],
    }
    state["per_query_timeout_ms"] = timeout_ms
    full_q = queue_for(cfg)
    if "--retry-timeouts" in argv:
        for k, v in list(state["done"].items()):
            if v["outcome"] == "timeout":
                del state["done"][k]
    q = [item for item in full_q if key(item) not in state["done"]]
    t0 = time.time()
    processed = 0
    if q:
        ctx = mp.get_context("fork")
        with ctx.Pool(workers, initializer=_init, initargs=(cfg,)) as pool:
            it = pool.imap_unordered(_solve, q, chunksize=1)
            for (k, outcome, secs, multiset, program, consts, table, observed,
                 relabel, bijective) in it:
                state["done"][k] = {"outcome": outcome, "seconds": secs}
                processed += 1
                if outcome == "sat":
                    state["solutions"].append({
                        "components": multiset,
                        "program": program,
                        "constants": [f"0x{c:08x}" for c in (consts or [])],
                        "table": table,
                        "observed": observed,
                        "relabel_observed_to_map": relabel,
                        "relabel_is_bijective": bijective,
                    })
                    print("SAT", multiset)
                if time.time() - t0 > budget:
                    pool.terminate()
                    break
    counts = {"sat": 0, "unsat": 0, "timeout": 0}
    for v in state["done"].values():
        counts[v["outcome"]] += 1
    state["counts"] = counts
    state["queue_total"] = len(full_q)
    state["queue_done"] = len(state["done"])
    state["timeout_multisets"] = [json.loads(k) for k, v in state["done"].items()
                                  if v["outcome"] == "timeout"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=1))
    print(f"{job}: {state['queue_done']}/{len(full_q)} multisets, {counts}, "
          f"+{processed} this run, {time.time()-t0:.1f}s")


if __name__ == "__main__":
    main()
