"""Aggregate every search result into one table and re-check every solution.

Each recorded `sat` is re-executed on all 27 states by `emulate.py`, which was
written from the vendor pseudocode independently of the solver's encoding. A
solution that does not survive that check is reported as a defect, not dropped.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List

from emulate import check_program, check_index_partition
from panel import RESULTS, load_panel, spec_for


def collect() -> dict:
    panel = load_panel()
    rows: List[dict] = []
    defects: List[dict] = []
    for path in sorted(RESULTS.glob("search-*.json")):
        st = json.loads(path.read_text())
        spec = spec_for(st["network"], st["contract"], st["projection"], st["mode"])
        checked = []
        for sol in st["solutions"]:
            prog = sol["program"]
            if st["projection"] == "lane5":
                chk = check_program(prog, spec.contract.input_names,
                                    spec.contract.inputs, spec.targets,
                                    "int32", sol["table"])
                partition = check_index_partition(prog, spec.contract.input_names,
                                                  spec.contract.inputs, spec.targets, st["mode"])
                chk["index_partition"] = partition
                if not partition["valid"]:
                    defects.append({"job": st["job"], "index_partition": partition})
            elif st["mode"] == "exact":
                chk = check_program(prog, spec.contract.input_names,
                                    spec.contract.inputs, spec.targets,
                                    st["projection"])
            else:
                chk = {"note": "collision-structure result; value not asserted"}
            checked.append({"components": sol["components"], "check": chk})
            if chk.get("mismatches"):
                defects.append({"job": st["job"], **checked[-1]})
        rows.append({
            "job": st["job"],
            "network": st["network"],
            "image": panel[st["network"]]["image"],
            "contract": st["contract"],
            "projection": st["projection"],
            "mode": st["mode"],
            "valu": st["valu"],
            "library": st["library"],
            "constants_allowed": st["n_consts"],
            "queue_total": st.get("queue_total"),
            "queue_done": st.get("queue_done"),
            "counts": st.get("counts"),
            "per_query_timeout_ms": st.get("per_query_timeout_ms"),
            "solutions": len(st["solutions"]),
            "solution_components": [s["components"] for s in st["solutions"]],
            "rechecked": checked,
            "unexplored_multisets": st.get("timeout_multisets", []),
        })
    return {"rows": rows, "defects": defects}


def table(data: dict) -> str:
    lines = [f"{'job':42s} {'img':>3s} {'done/total':>10s} "
             f"{'sat':>4s} {'unsat':>6s} {'to':>3s}  first solution"]
    for r in sorted(data["rows"], key=lambda r: (r["network"], r["contract"],
                                                 r["mode"], r["valu"])):
        c = r["counts"] or {}
        first = ""
        if r["solution_components"]:
            first = "+".join(r["solution_components"][0])
        lines.append(f"{r['job']:42s} {r['image']:3d} "
                     f"{str(r['queue_done']) + '/' + str(r['queue_total']):>10s} "
                     f"{c.get('sat', 0):4d} {c.get('unsat', 0):6d} "
                     f"{c.get('timeout', 0):3d}  {first}")
    return "\n".join(lines)


def matrix(data: dict) -> str:
    """Best programs found, not minima across incomplete searches.

    Match constrains the lane index BEFORE lookup, not the final answer. Every
    correct final answer already has exactly the target's fibers.
    """
    cells: Dict[tuple, dict] = {}
    for r in data["rows"]:
        if r["projection"] != "lane5":
            continue
        k = (r["network"], r["image"], r["contract"])
        c = cells.setdefault(k, {"refine": None, "match": None,
                                 "unexplored": []})
        counts = r["counts"] or {}
        if counts.get("sat"):
            best = c[r["mode"]]
            total = r["valu"] + 1  # the lookup itself
            c[r["mode"]] = total if best is None else min(best, total)
        c["unexplored"] += [f"{r['mode']}{r['valu']}:{'+'.join(m)}"
                            for m in r["unexplored_multisets"]]
        c["unexplored"] += [f"{r['mode']}{r['valu']}:unrun"] * (
            (r["queue_total"] or 0) - (r["queue_done"] or 0))
    lines = [f"{'network':9s} {'img':>3s} {'contract':10s} "
             f"{'best found':>10s} {'matched index+lookup':>20s}  unexplored"]
    for (net, img, con), c in sorted(cells.items()):
        ref = f"{c['refine']} instr" if c["refine"] else "no hit"
        mat = f"{c['match']} instr" if c["match"] else "no hit"
        lines.append(f"{net:9s} {img:3d} {con:10s} {ref:>9s} {mat:>11s}  "
                     f"{len(c['unexplored'])}")
    return "\n".join(lines)


if __name__ == "__main__":
    data = collect()
    print(table(data))
    print()
    print(matrix(data))
    print()
    print(f"defects: {len(data['defects'])}")
    data["matrix_text"] = matrix(data)
    (RESULTS / "summary.json").write_text(json.dumps(data, indent=1))
    readme = Path(__file__).with_name("README.md")
    text = readme.read_text()
    start = text.index("```\nnetwork") + 4
    end = text.index("\n```", start)
    readme.write_text(text[:start] + data["matrix_text"] + text[end:])
