#!/usr/bin/env python3
"""Replay saved witnesses without invoking the proposal solver."""
import argparse
import json
from pathlib import Path

from certificates import checked, require, verify_infeasible, verify_relaxation_pair
from schedule import compare


@checked
def replay(artifact):
    require(artifact["format"] == "kelana-resource-certificates/1", "unsupported certificate format")
    require(artifact["cases"], "empty certificate artifact")
    results = []
    for case in artifact["cases"]:
        model, problem, family = (case[k] for k in ("model", "problem", "family"))
        checks = {}
        if "semantic_source" in case:
            from potential_bridge import verify_source
            checks["semantic_source"] = verify_source(case)
        if "proposal" in case:
            p = case["proposal"]
            checks["relaxation"] = verify_relaxation_pair(model, problem, family, p["dual"], p["primal"])
            for key in ("schedule", "attaining_schedule", "competitor_schedule"):
                if key in case:
                    checks[key] = compare(model, problem, family, p["dual"], case[key])
        else:
            checks["impossibility"] = verify_infeasible(model, problem, family, case["certificate"])
        results.append({"name": case["name"], "checks": checks})
    accepted = all(check["valid"] and check.get("status") != "correct_program_refutes_stated_count_obligation"
                   for result in results for check in result["checks"].values())
    return {"accepted": accepted, "results": results, "proposal_solver_used": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    try:
        result = replay(json.loads(args.artifact.read_text()))
    except json.JSONDecodeError as error:
        result = {"accepted": False, "reason": str(error)}
    text = json.dumps(result, indent=2)+"\n"
    if args.out:
        args.out.write_text(text)
    else:
        print(text, end="")
    raise SystemExit(0 if result.get("accepted", False) else 1)
