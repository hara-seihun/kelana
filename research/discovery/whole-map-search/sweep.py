"""Run many jobs as one flat queue so the slow tail of each job overlaps.

    python3 sweep.py --budget 45 --timeout-ms 30000 JOB [JOB ...]

Same result files and same resume behaviour as `run_search.py`; this only
changes how the work is scheduled.
"""

from __future__ import annotations

import json
import multiprocessing as mp
import sys
import time
from typing import Dict, List

from isa import BY_NAME
from panel import RESULTS, spec_for
from run_search import LIBS, key, parse_job, queue_for
from synth import Synthesizer

_SPECS: Dict[str, object] = {}


def _spec(cfg: dict):
    k = f"{cfg['network']}/{cfg['contract']}/{cfg['projection']}/{cfg['mode']}"
    if k not in _SPECS:
        _SPECS[k] = spec_for(cfg["network"], cfg["contract"], cfg["projection"],
                             cfg["mode"])
    return _SPECS[k]


def _solve(task: tuple) -> tuple:
    job, cfg, item = task
    r = Synthesizer(_spec(cfg), [BY_NAME[n] for n in item["components"]],
                    n_consts=cfg["n_consts"], timeout_ms=cfg["timeout_ms"]).run()
    return (job, key(item), r.outcome, round(r.seconds, 3), list(r.multiset),
            r.program, r.constants, r.table, r.observed, r.relabel,
            r.relabel_is_bijective)


def main() -> None:
    argv = sys.argv
    budget = float(argv[argv.index("--budget") + 1]) if "--budget" in argv else 45.0
    workers = int(argv[argv.index("--workers") + 1]) if "--workers" in argv else 30
    timeout_ms = int(argv[argv.index("--timeout-ms") + 1]) if "--timeout-ms" in argv else 30000
    retry = "--retry-timeouts" in argv
    jobs = [a for a in argv[1:] if not a.startswith("--") and not a.isdigit()]
    jobs = [j for j in jobs if "-" in j]

    states: Dict[str, dict] = {}
    tasks: List[tuple] = []
    for job in jobs:
        cfg = parse_job(job)
        cfg["timeout_ms"] = timeout_ms
        path = RESULTS / f"search-{job}.json"
        st = json.loads(path.read_text()) if path.exists() else {
            "job": job, **cfg, "library_components": LIBS[cfg["library"]],
            "done": {}, "solutions": [],
        }
        st["per_query_timeout_ms"] = timeout_ms
        if retry:
            for k, v in list(st["done"].items()):
                if v["outcome"] == "timeout":
                    del st["done"][k]
            st["solutions"] = [s for s in st["solutions"]]
        states[job] = st
        for item in queue_for(cfg):
            if key(item) not in st["done"]:
                tasks.append((job, cfg, item))

    t0 = time.time()
    processed = 0
    if tasks:
        ctx = mp.get_context("fork")
        with ctx.Pool(workers) as pool:
            for out in pool.imap_unordered(_solve, tasks, chunksize=1):
                (job, k, outcome, secs, multiset, program, consts, table,
                 observed, relabel, bijective) = out
                st = states[job]
                st["done"][k] = {"outcome": outcome, "seconds": secs}
                processed += 1
                if outcome == "sat":
                    st["solutions"].append({
                        "components": multiset, "program": program,
                        "constants": [f"0x{c:08x}" for c in (consts or [])],
                        "table": table, "observed": observed,
                        "relabel_observed_to_map": relabel,
                        "relabel_is_bijective": bijective,
                    })
                if time.time() - t0 > budget:
                    pool.terminate()
                    break

    for job, st in states.items():
        counts = {"sat": 0, "unsat": 0, "timeout": 0}
        for v in st["done"].values():
            counts[v["outcome"]] += 1
        st["counts"] = counts
        st["queue_total"] = len(queue_for(parse_job(job)))
        st["queue_done"] = len(st["done"])
        st["timeout_multisets"] = [json.loads(k) for k, v in st["done"].items()
                                   if v["outcome"] == "timeout"]
        (RESULTS / f"search-{job}.json").write_text(json.dumps(st, indent=1))
        print(f"{job}: {st['queue_done']}/{st['queue_total']} {counts}")
    print(f"+{processed} queries, {time.time()-t0:.1f}s")


if __name__ == "__main__":
    main()
