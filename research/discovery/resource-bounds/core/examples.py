#!/usr/bin/env python3
"""Small complete certificates. All timing profiles here are abstract, not native."""
import copy
import itertools
import json
from pathlib import Path

from certificates import binding, digest, propose, verify_infeasible
from schedule import compare

HERE = Path(__file__).resolve().parent


def operation(mask, port, latency=1):
    return {"arity": 1, "table": [x ^ mask for x in range(4)],
            "demand": {port: 1}, "latency": latency,
            "reservations": [{"resource": port, "offset": 0, "duration": 1, "amount": 1}]}


def cut(name, coefficients, minimum, premise, role="necessary_for_target"):
    return {"id": name, "coefficients": coefficients, "minimum": minimum,
            "premise": premise, "role": role}


def plan(model, problem, nodes, outputs):
    return {"binding": {"model": digest(model), "problem": digest(problem)},
            "nodes": nodes, "outputs": outputs}


def node(name, op, args, start):
    return {"id": name, "op": op, "args": args, "start": start}


def xor_case():
    model = {"unit": "abstract ticks", "resources": {"valu": 1}, "register_capacity": 2,
             "value_count": 4, "operations": {f"xor{k}": operation(k, "valu") for k in (1, 2, 3)},
             "assumptions": ["Declared one-slot unary XOR machine, not a gfx1151 cycle model.",
                             "Operands read at issue; inputs already in registers; output ready after latency."]}
    problem = {"id": "toggle-both-bits", "inputs": ["x"],
               "cases": [{"inputs": [x], "outputs": [x ^ 3]} for x in range(4)],
               "input_contract": "all two-bit input words, no preprocessing"}
    family = {"id": "separate-bit-toggles", "allowed_operations": ["xor1", "xor2"],
              "obligations": [cut("low", {"xor1": 1}, 1, "Only xor1 changes bit zero in this grammar; the required output changes it."),
                              cut("high", {"xor2": 1}, 1, "Only xor2 changes bit one in this grammar; the required output changes it.")]}
    attaining = plan(model, problem, [node("a", "xor1", ["x"], 0), node("b", "xor2", ["a"], 1)], ["b"])
    competitor = plan(model, problem, [node("b", "xor3", ["x"], 0)], ["b"])
    return model, problem, family, attaining, competitor


def parallel_case(latency=1):
    model = {"unit": "abstract ticks", "resources": {"left": 1, "right": 1}, "register_capacity": 2,
             "value_count": 4, "operations": {"xor1": operation(1, "left", latency), "xor2": operation(2, "right", latency)},
             "assumptions": ["Two independent issue resources, each one operation per tick.",
                             "These are declared abstract ports, not inferred GPU ports.",
                             "Operands read at issue; homogeneous register reuse is allowed after the last read."]}
    problem = {"id": "two-independent-outputs", "inputs": ["x", "y"],
               "cases": [{"inputs": [x, y], "outputs": [x ^ 1, y ^ 2]} for x, y in itertools.product(range(4), repeat=2)],
               "input_contract": "all pairs of two-bit words, supplied in registers"}
    family = {"id": "independent-observers", "allowed_operations": ["xor1", "xor2"],
              "obligations": [cut("low", {"xor1": 1}, 1, "Required low-bit change needs xor1."),
                              cut("high", {"xor2": 1}, 1, "Required high-bit change needs xor2.")]}
    schedule = plan(model, problem, [node("a", "xor1", ["x"], 0), node("b", "xor2", ["y"], 0)], ["a", "b"])
    return model, problem, family, schedule


def run():
    model, problem, family, optimum, competitor = xor_case()
    proposal = propose(model, problem, family)
    assert proposal["status"] == "checked", proposal
    strict = compare(model, problem, family, proposal["dual"], competitor)
    attaining = compare(model, problem, family, proposal["dual"], optimum)
    assert strict["status"] == "family_strictly_dominated_under_premises"
    assert attaining["status"] == "family_optimum_under_premises"
    cases = [{"name": "separate-toggle optimum and strict domination", "model": model, "problem": problem,
              "family": family, "proposal": proposal, "attaining_schedule": optimum,
              "competitor_schedule": competitor, "attainment": attaining, "dominance": strict}]
    for latency in (1, 4):
        m, p, f, s = parallel_case(latency)
        proposed = propose(m, p, f)
        assert proposed["status"] == "checked", proposed
        result = compare(m, p, f, proposed["dual"], s)
        expected = "family_optimum_under_premises" if latency == 1 else "bounds_leave_gap"
        assert result["status"] == expected, result
        cases.append({"name": f"independent ports, latency {latency}", "model": m, "problem": p,
                      "family": f, "proposal": proposed, "schedule": s, "comparison": result})
    impossible = copy.deepcopy(family)
    impossible["allowed_operations"] = ["xor1"]
    impossible["obligations"] = [cut("high", {}, 1, "xor1 preserves bit one; the target does not.")]
    cert = {"binding": binding(model, problem, impossible), "lambda": {"high": 1}}
    proof = verify_infeasible(model, problem, impossible, cert)
    assert proof["valid"], proof
    cases.append({"name": "high bit cannot change", "model": model, "problem": problem,
                  "family": impossible, "certificate": cert, "verification": proof})
    return {"format": "kelana-resource-certificates/1", "cases": cases}


if __name__ == "__main__":
    result = run()
    (HERE/"results.json").write_text(json.dumps(result, indent=2)+"\n")
    for case in result["cases"]:
        print(case["name"], case.get("comparison", case.get("dominance", case.get("verification"))))
