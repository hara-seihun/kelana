#!/usr/bin/env python3
"""Build the declared certificates and the grammar census.

    python3 experiments.py            # writes results/, prints the summary
    python3 experiments.py --quiet    # writes results/ only

Everything here is relative to a declared register width, instruction set and
charge table. Nothing in this directory measures a real machine.
"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import numpy as np

from certify import INF, Certificate, Space, forward_potential, observation_census
from machine import GRAMMARS, GRAMMAR_NOTES, Machine

RESULTS = Path(__file__).resolve().parent / "results"

M1 = Machine(width=2, registers=2, domain=(0, 1, 2, 3), scratch=(0,))
M2 = Machine(width=2, registers=2, domain=(0, 1, 3), scratch=(0,))
M3 = Machine(width=2, registers=3, domain=(0, 1, 3), scratch=(0, 0))

BITS = {
    "b0": (0, 1, 0, 1),
    "b1": (0, 0, 1, 1),
    "and": (0, 0, 0, 1),
    "or": (0, 1, 1, 1),
    "xor": (0, 1, 1, 0),
    "eq": (1, 0, 0, 1),
    "sum": (0, 1, 1, 2),
    "nand": (1, 1, 1, 0),
    "and-scaled": (0, 0, 0, 2),
    "complement": (3, 2, 1, 0),
    "negate": (0, 3, 2, 1),
    "b0-scaled": (0, 2, 0, 2),
}

TRITS = {
    "relu": (0, 1, 0),
    "abs": (0, 1, 1),
    "negate": (0, 3, 1),
    "is-negative": (0, 0, 1),
    "nonzero-as-minus-one": (0, 3, 3),
    "double": (0, 2, 2),
}


def exact(target, observe=0):
    return {"kind": "exact", "observe": observe, "target": list(target)}


def kind(name, target, observe=0):
    return {"kind": name, "observe": observe, "target": list(target)}


def anywhere(target):
    return {"target": list(target), "registers": "any"}


def m1_full() -> Certificate:
    note = (
        "Two 2-bit registers, input in r0, r1 starts at 0. Targets read the input as two bits "
        "b1 b0. Each `-through-` query forces the program to hold the named intermediate in some "
        "register at some step; the plain query leaves every intermediate free."
    )
    cert = Certificate("m1-full", Space.build(M1, "full"), note)
    cert.reach("xor", exact(BITS["xor"]))
    cert.through("xor-through-sum", exact(BITS["xor"]), anywhere(BITS["sum"]), "xor")
    cert.reach("eq", exact(BITS["eq"]))
    cert.through("eq-through-sum", exact(BITS["eq"]), anywhere(BITS["sum"]), "eq")
    cert.reach("and-scaled", exact(BITS["and-scaled"]))
    cert.through("and-scaled-through-and", exact(BITS["and-scaled"]), anywhere(BITS["and"]), "and-scaled")
    cert.through("and-scaled-through-nand", exact(BITS["and-scaled"]), anywhere(BITS["nand"]), "and-scaled")
    cert.reach("and", exact(BITS["and"]))
    cert.reach("and-cleared", kind("cleared", BITS["and"]))
    cert.reach("xor-relabeled", kind("relabeled", BITS["xor"]))
    cert.reach("xor-refined-by-retained-input", kind("refines", BITS["xor"]))
    and_xor = {"kind": "pair-exact", "targets": [list(BITS["and"]), list(BITS["xor"])]}
    xor_and = {"kind": "pair-exact", "targets": [list(BITS["xor"]), list(BITS["and"])]}
    cert.reach("and-in-r0-xor-in-r1", and_xor)
    cert.reach("xor-in-r0-and-in-r1", xor_and)
    scaled_and_or = {"kind": "pair-exact", "targets": [list(BITS["and-scaled"]), list(BITS["or"])]}
    cert.reach("scaled-and-in-r0-or-in-r1", scaled_and_or)
    cert.reach("or-alone", exact(BITS["or"]))
    cert.count_cut("and-xor-count-cut", and_xor, "and-xor")
    cert.count_cut("scaled-and-or-count-cut", scaled_and_or, "scaled-and-or")
    cert.count_cut("xor-count-cut", exact(BITS["xor"]), "xor")
    cert.count_cut("eq-count-cut", exact(BITS["eq"]), "eq")
    cert.count_cut("and-scaled-count-cut", exact(BITS["and-scaled"]), "and-scaled")
    return cert


def m2_trit() -> Certificate:
    note = (
        "Two 2-bit registers over the three signed trit codes 0, 1, 3 for the values 0, +1, -1. "
        "Code 2 is outside the declared input domain. `cleared` additionally requires r1 to end at 0, "
        "which prices erasing the input-dependent residue the cheapest program leaves behind."
    )
    cert = Certificate("m2-trit", Space.build(M2, "full"), note)
    cert.reach("relu", exact(TRITS["relu"]))
    cert.through("relu-through-negate", exact(TRITS["relu"]), anywhere(TRITS["negate"]), "relu")
    cert.through("relu-through-is-negative", exact(TRITS["relu"]), anywhere(TRITS["is-negative"]), "relu")
    cert.reach("nonzero", exact(TRITS["nonzero-as-minus-one"]))
    cert.reach("nonzero-relabeled", kind("relabeled", TRITS["nonzero-as-minus-one"]))
    cert.reach("nonzero-cleared", kind("cleared", TRITS["nonzero-as-minus-one"]))
    cert.reach("negate", exact(TRITS["negate"]))
    cert.reach("negate-relabeled-by-retained-input", kind("relabeled", TRITS["negate"]))
    cert.reach("abs", exact(TRITS["abs"]))
    cert.count_cut("relu-count-cut", exact(TRITS["relu"]), "relu")
    cert.count_cut("nonzero-count-cut", exact(TRITS["nonzero-as-minus-one"]), "nonzero")
    return cert


def m3_three_register() -> Certificate:
    note = (
        "The same trit domain with a third 2-bit register. 262144 semantic states, every one of them "
        "reachable. The extra register lowers none of the m2-trit optima."
    )
    cert = Certificate("m3-three-register", Space.build(M3, "full"), note)
    cert.reach("relu", exact(TRITS["relu"]))
    cert.reach("nonzero", exact(TRITS["nonzero-as-minus-one"]))
    cert.reach("nonzero-cleared", kind("cleared", TRITS["nonzero-as-minus-one"]))
    return cert


def m1_restricted(grammar: str, impossible: str, control: str) -> Certificate:
    note = (
        f"Grammar {grammar}: {GRAMMAR_NOTES[grammar]}. The impossible query is a closed-semantics "
        "result, not a search budget: the forward potential is finite exactly on the states some "
        "program can reach, and no state in the goal set carries a finite value."
    )
    cert = Certificate(f"m1-{grammar}", Space.build(M1, grammar), note)
    cert.reach(f"{impossible}-impossible", exact(BITS[impossible]))
    cert.reach(f"{control}-control", exact(BITS[control]))
    return cert


def census() -> dict:
    out: dict = {
        "note": "Costs and reachability under the declared grammars. Every number is relative to the "
        "register width, the instruction set and the abstract charges in machine.py.",
        "machines": {},
    }
    for label, machine, names in (("M1", M1, BITS), ("M2-trit", M2, TRITS)):
        rows = {}
        for grammar in GRAMMARS:
            space = Space.build(machine, grammar)
            forward, _, _ = forward_potential(space)
            table = observation_census(space, forward)
            rows[grammar] = {
                "note": GRAMMAR_NOTES[grammar],
                "instructions": len(space.instructions),
                "reachable_semantic_states": int((forward < INF).sum()),
                "semantic_states": machine.semantic_count,
                "observable_functions": len(table),
                "possible_functions": (1 << machine.width) ** machine.inputs,
                "worst_optimal_cost": max(table.values()),
                "named_costs": {k: table.get(tuple(v)) for k, v in names.items()},
            }
        out["machines"][label] = {"machine": machine.as_json(), "grammars": rows}

    space2, space3 = Space.build(M2, "full"), Space.build(M3, "full")
    f2, _, _ = forward_potential(space2)
    f3, _, _ = forward_potential(space3)
    t2, t3 = observation_census(space2, f2), observation_census(space3, f3)
    out["third_register"] = {
        "note": "Same trit domain, three registers instead of two, observed in r0.",
        "semantic_states": M3.semantic_count,
        "reachable_semantic_states": int((f3 < INF).sum()),
        "instructions": len(space3.instructions),
        "functions_cheaper_with_three_registers": sorted(k for k in t2 if t3.get(k, INF) < t2[k]),
        "functions_only_with_three_registers": sorted(k for k in t3 if k not in t2),
    }
    return out


def main(argv: list[str]) -> int:
    RESULTS.mkdir(exist_ok=True)
    quiet = "--quiet" in argv
    start = time.time()
    built = []
    for cert in (
        m1_full(),
        m2_trit(),
        m3_three_register(),
        m1_restricted("monotone", "complement", "or"),
        m1_restricted("affine", "b0", "negate"),
        m1_restricted("noshr", "b1", "b0-scaled"),
    ):
        path = RESULTS / f"{cert.experiment}.cert.json"
        cert.write(path)
        built.append((cert, path))

    data = census()
    with open(RESULTS / "census.json", "w") as handle:
        json.dump(data, handle, indent=1, sort_keys=True)
        handle.write("\n")

    if not quiet:
        for cert, path in built:
            size = path.stat().st_size / 1024
            print(f"{path.name}  ({cert.space.machine.semantic_count} states, {size:.0f} KiB)")
            for query in cert.queries:
                claim = query["claim"]
                if claim["status"] == "impossible":
                    print(f"    {query['name']:<36} impossible at every program length")
                else:
                    print(f"    {query['name']:<36} {claim['cost']}  {' ; '.join(query['witness']) or '(empty program)'}")
            for cut in cert.cuts:
                print(
                    f"    {cut['name']:<36} cost<={cut['budget']}: >={cut['length_at_least']} instructions, "
                    f"only {', '.join(cut['usable_families'])}"
                )
        print(f"\ncensus.json written; total {time.time() - start:.1f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
