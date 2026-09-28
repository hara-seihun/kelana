#!/usr/bin/env python3
"""Turn independently checked finite-machine potentials into resource cuts.

The budget is part of the program family. These cuts do not become unconditional
merely because another resource model prices the same instruction counts.
"""
import argparse
from collections import Counter
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path

from certificates import InvalidArtifact, binding, digest, require, verify_relaxation_pair

HERE = Path(__file__).resolve().parent
FINITE = HERE.parent / "finite-machine"
spec = importlib.util.spec_from_file_location("finite_certificate_checker", FINITE / "check.py")
finite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(finite)


def derive(source):
    path = (HERE / source["path"]).resolve()
    try:
        raw = path.read_bytes()
    except OSError as error:
        raise InvalidArtifact(f"finite certificate unavailable: {error}") from error
    require(hashlib.sha256(raw).hexdigest() == source["sha256"], "finite certificate changed")
    cert = json.loads(raw)
    try:
        finite.check(cert)
    except finite.Rejected as error:
        raise InvalidArtifact(f"finite certificate rejected: {error}") from error
    cuts = [cut for cut in cert["cuts"] if cut["name"] == source["cut"]]
    require(len(cuts) == 1, "source must name exactly one finite count cut")
    cut = cuts[0]
    potentials = [p for p in cert["backward"] if p["id"] == cut["potential"]]
    require(len(potentials) == 1, "ambiguous finite potential")
    goal = potentials[0]["goal"]
    queries = [q for q in cert["queries"] if q["goal"] == goal and not q.get("through")
               and q["claim"]["status"] == "optimal" and q["claim"]["cost"] <= cut["budget"]]
    require(queries, "no attaining program for the cut's target and budget")
    query = queries[0]
    instructions = cert["grammar"]["instructions"]
    names = [op["name"] for op in instructions]
    charges = {op["name"]: op["charge"] for op in instructions}
    model = {
        "unit": "abstract sequential charge",
        "resources": {"issue": 1},
        "operations": {name: {"demand": {"issue": charges[name]}} for name in names},
        "assumptions": [
            "Instructions act on the named finite register file; arguments are not freely rewired SSA operands.",
            "One sequential abstract issue resource delivers one charge per tick. This is not a hardware rate.",
            "Instruction semantics and charges are those replayed by finite-machine/check.py."
        ],
    }
    problem = {"id": query["name"], "machine": cert["machine"], "goal": goal,
               "instruction_semantics_sha256": digest(cert["grammar"])}
    drops = {name: value for name, value in zip(names, cut["drops"]) if value is not None}
    absent = [name for name, value in zip(names, cut["drops"]) if value is None]
    obligations = [{
        "id": "charge-budget", "coefficients": {name: -charges[name] for name in names},
        "minimum": -cut["budget"], "role": "class_restriction",
        "premise": "Only finite-machine straight-line programs with total declared charge at most the budget."
    }, {
        "id": "potential-drop", "coefficients": drops, "minimum": cut["floor"],
        "role": "necessary_for_target",
        "premise": "Replayed Bellman potentials bound every step fitting the budget; drops telescope to the initial potential."
    }]
    obligations += [{"id": "absent:"+name, "coefficients": {name: -1}, "minimum": 0,
                     "role": "necessary_for_target",
                     "premise": "No transition with this instruction fits the verified prefix + step + suffix budget."}
                    for name in absent]
    family = {"id": cut["name"], "allowed_operations": names, "obligations": obligations,
              "program_contract": "Fixed finite register file, declared initial state and observation; straight-line programs only."}
    price = max((Fraction(drop, charges[name]) for name, drop in drops.items()), default=Fraction(0))
    require(price > 0, "potential has no positive per-charge drop")
    bind = binding(model, problem, family)
    dual = {"binding": bind, "lambda": {"potential-drop": 1}, "mu": {"issue": str(price)}}
    primal = {"binding": bind, "counts": dict(Counter(query["witness"])), "time": query["claim"]["cost"]}
    check = verify_relaxation_pair(model, problem, family, dual, primal)
    require(check["valid"], f"finite-to-resource bridge failed: {check}")
    return {"name": cut["name"], "model": model, "problem": problem, "family": family,
            "proposal": {"dual": dual, "primal": primal}, "semantic_source": source}


def verify_source(case):
    """Re-derive the semantic premises, rather than trust a stored 'proved' flag."""
    derived = derive(case["semantic_source"])
    for field in ("model", "problem", "family"):
        require(case[field] == derived[field], f"{field} no longer matches checked finite semantics")
    return {"valid": True, "kind": "finite_potential_to_count_cut",
            "budget_is_family_restriction": True, "native_runtime_claim": False}


def examples():
    cases = []
    for filename, index in (("m1-full.cert.json", 0), ("m2-trit.cert.json", 0)):
        path = FINITE / "results" / filename
        raw = path.read_bytes()
        cert = json.loads(raw)
        source = {"path": "../finite-machine/results/"+filename,
                  "sha256": hashlib.sha256(raw).hexdigest(), "cut": cert["cuts"][index]["name"]}
        cases.append(derive(source))
    return {"format": "kelana-resource-certificates/1", "cases": cases}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=HERE / "potential-results.json")
    args = parser.parse_args()
    args.out.write_text(json.dumps(examples(), indent=2)+"\n")
    print(args.out)
