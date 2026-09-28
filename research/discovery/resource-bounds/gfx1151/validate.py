#!/usr/bin/env python3
"""Validate the gfx1151 conditional resource profile.

Checks five things and writes a receipt:

1.  The pinned AMD sources still hash to what ``facts.json`` recorded.
2.  Every fact re-extracts to the same value from those sources (``--reextract``).
3.  Every quantity a case declares recomputes in exact rational arithmetic, and
    every ``check`` in its derivation holds.
4.  Every premise a case cites resolves to a real fact or a real assumption.
5.  No derivation step marked ``direction: lower-bound`` cites evidence whose
    role is ``achieved-rate``. This is the rule that keeps a measured regression
    from being promoted to an impossibility.

It also sweeps the unproved parameter of each case and reports the range over
which the conclusion survives.

    python3 validate.py
    python3 validate.py --reextract --out results/validation.json
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import operator
import re
import subprocess
import sys
from fractions import Fraction
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]

FORMAT = "kelana-resource-validation/1"

# Weakest last. A conclusion inherits the weakest tier among the premises it uses.
TIERS = ["architectural", "family-restriction", "achieved-rate"]


def load_json(text):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON field {key!r}")
            result[key] = value
        return result
    return json.loads(text, object_pairs_hook=unique)


# ---------------------------------------------------------------- exact arithmetic


def _log3_floor(n: Fraction) -> Fraction:
    """Largest g with 3**g <= n."""
    if n < 1:
        raise ValueError("log3_floor needs n >= 1")
    g, v = 0, 1
    while v * 3 <= n:
        v *= 3
        g += 1
    return Fraction(g)


FUNCS = {
    "ceil": lambda x: Fraction(-((-x.numerator) // x.denominator)),
    "floor": lambda x: Fraction(x.numerator // x.denominator),
    "min": min,
    "max": max,
    "log3_floor": _log3_floor,
}

BINOPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
}


def evaluate(expr: str, env: dict[str, Fraction]) -> Fraction:
    """Exact rational evaluation of a small arithmetic language."""

    def walk(node):
        if isinstance(node, ast.Expression):
            return walk(node.body)
        if isinstance(node, ast.Constant):
            if isinstance(node.value, bool) or not isinstance(node.value, (int, float, str)):
                raise ValueError(f"bad literal {node.value!r}")
            literal = ast.get_source_segment(expr, node) if isinstance(node.value, float) else str(node.value)
            return Fraction(literal.replace("_", ""))
        if isinstance(node, ast.Name):
            if node.id not in env:
                raise ValueError(f"undefined quantity {node.id}")
            return env[node.id]
        if isinstance(node, ast.BinOp) and type(node.op) in BINOPS:
            return BINOPS[type(node.op)](walk(node.left), walk(node.right))
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            return -walk(node.operand)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id not in FUNCS:
                raise ValueError(f"unknown function {node.func.id}")
            return FUNCS[node.func.id](*[walk(a) for a in node.args])
        raise ValueError(f"disallowed syntax {type(node).__name__}")

    return walk(ast.parse(expr, mode="eval"))


def names_in(expr: str) -> set[str]:
    """Every quantity name an expression reads."""
    return {
        n.id
        for n in ast.walk(ast.parse(expr, mode="eval"))
        if isinstance(n, ast.Name) and n.id not in FUNCS
    }


def check_relation(text: str, env: dict[str, Fraction]) -> tuple[bool, str]:
    for token, rel in (
        ("==", operator.eq),
        ("<=", operator.le),
        (">=", operator.ge),
        ("<", operator.lt),
        (">", operator.gt),
    ):
        if token in text:
            left, right = text.split(token, 1)
            lv, rv = evaluate(left.strip(), env), evaluate(right.strip(), env)
            return rel(lv, rv), f"{left.strip()} = {fmt(lv)} {token} {fmt(rv)}"
    raise ValueError(f"no relation in check {text!r}")


def fmt(v: Fraction) -> str:
    if v.denominator == 1:
        return str(v.numerator)
    return f"{v} ({float(v):.6g})"


# ---------------------------------------------------------------- helpers


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def dig(value, dotted: str):
    for part in dotted.split("."):
        if isinstance(value, list):
            value = value[int(part)]
        else:
            value = value[part]
    return value


class Report:
    def __init__(self) -> None:
        self.checks: list[dict] = []

    def add(self, name: str, ok: bool, detail: str = "") -> bool:
        self.checks.append({"check": name, "ok": bool(ok), "detail": detail})
        return ok

    @property
    def failures(self) -> list[dict]:
        return [c for c in self.checks if not c["ok"]]


# ---------------------------------------------------------------- validation steps


def check_sources(facts: dict, rep: Report) -> None:
    for key, meta in facts["sources"].items():
        path = REPO / meta["path"]
        if not path.exists():
            rep.add(f"source {key} present", False, f"missing {path}")
            continue
        got = sha256(path)
        rep.add(
            f"source {key} hash",
            got == meta["sha256"],
            f"{meta['path']} {got[:16]}",
        )


def check_reextract(facts: dict, rep: Report) -> None:
    proc = subprocess.run(
        [sys.executable, str(HERE / "extract_facts.py"), "--stdout"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        rep.add("re-extract facts", False, proc.stderr.strip()[-400:])
        return
    fresh = load_json(proc.stdout)
    same = {f["id"]: f["value"] for f in fresh["facts"]}
    stored = {f["id"]: f["value"] for f in facts["facts"]}
    rep.add("re-extract fact ids", set(same) == set(stored), f"{len(same)} facts")
    for fid in sorted(set(same) & set(stored)):
        rep.add(f"re-extract {fid}", same[fid] == stored[fid])


def check_case(case: dict, facts: dict, profile: dict, rep: Report) -> dict:
    cid = case["id"]
    fact_by_id = {f["id"]: f for f in facts["facts"]}
    assume_by_id = {a["id"]: a for a in profile["assumptions"]}

    # 4. premises resolve
    for premise in case.get("premises", []):
        kind, _, name = premise.partition(":")
        table = fact_by_id if kind == "FACT" else assume_by_id
        rep.add(f"{cid}: premise {premise} resolves", name in table)

    # quantities that name a fact must agree with the fact, and each carries a tier that
    # is no stronger than anything it reads
    env: dict[str, Fraction] = {}
    qtier: dict[str, str] = {}
    for q in case["quantities"]:
        try:
            env[q["id"]] = evaluate(q["expr"], env)
        except Exception as exc:  # noqa: BLE001
            rep.add(f"{cid}: quantity {q['id']}", False, str(exc))
            continue

        declared = q.get("tier")
        rep.add(f"{cid}: quantity {q['id']} declares a tier", declared in TIERS, str(declared))
        read = [qtier[n] for n in names_in(q["expr"]) if n in qtier]
        if "from" in q and q["from"].startswith("FACT:"):
            fid0 = max(
                (f for f in fact_by_id if q["from"][5:].startswith(f)),
                key=len,
                default=None,
            )
            if fid0:
                read.append(fact_by_id[fid0].get("tier", "architectural"))
        inferred = max(read, key=TIERS.index) if read else "architectural"
        if declared in TIERS:
            qtier[q["id"]] = declared
            rep.add(
                f"{cid}: quantity {q['id']} tier is not stronger than what it reads",
                TIERS.index(declared) >= TIERS.index(inferred),
                f"declared {declared}, reads give {inferred}",
            )
        else:
            qtier[q["id"]] = inferred
        if "from" in q and q["from"].startswith("FACT:"):
            dotted = q["from"][len("FACT:") :]
            # Fact ids contain dots, so take the longest id that prefixes the path.
            fid = max(
                (f for f in fact_by_id if dotted == f or dotted.startswith(f + ".")),
                key=len,
                default=None,
            )
            if fid is None:
                rep.add(f"{cid}: {q['id']} traces to {q['from']}", False, "no such fact")
                continue
            rest = dotted[len(fid) :].lstrip(".")
            try:
                raw = dig(fact_by_id[fid]["value"], rest) if rest else fact_by_id[fid]["value"]
            except Exception as exc:  # noqa: BLE001
                rep.add(f"{cid}: {q['id']} traces to {q['from']}", False, str(exc))
                continue
            wanted = Fraction(int(raw)) if isinstance(raw, bool) else Fraction(str(raw))
            rep.add(
                f"{cid}: {q['id']} matches {q['from']}",
                env[q["id"]] == wanted,
                f"{fmt(env[q['id']])} vs {raw}",
            )

    # 3. derivation checks
    for step in case["derivation"]:
        if "check" not in step:
            continue
        try:
            ok, detail = check_relation(step["check"], env)
        except Exception as exc:  # noqa: BLE001
            rep.add(f"{cid}: step {step['step']} check", False, str(exc))
            continue
        rep.add(f"{cid}: step {step['step']} {step['check']}", ok, detail)

    # 5a. tier inheritance: no step may claim a tier stronger than its weakest premise
    def tier_of(premise: str) -> str | None:
        kind, _, name = premise.partition(":")
        if kind == "FACT":
            return fact_by_id.get(name, {}).get("tier")
        if kind == "ASSUME":
            return assume_by_id.get(name, {}).get("tier")
        return None

    model_tier = assume_by_id.get(case.get("operation_model", ""), {}).get("tier")
    step_tiers: list[str] = []
    resolved: dict[int, str] = {}
    for step in case["derivation"]:
        declared = step.get("tier")
        rep.add(f"{cid}: step {step['step']} declares a tier", declared in TIERS, str(declared))
        rep.add(
            f"{cid}: step {step['step']} declares depends_on",
            isinstance(step.get("depends_on"), list),
            "missing depends_on" if "depends_on" not in step else "ok",
        )
        if declared not in TIERS:
            continue
        step_tiers.append(declared)

        # Transitive dependency provenance: premises, the quantities the step's own
        # check reads, and every step it builds on. An empty `uses` launders nothing.
        sources = [t for t in (tier_of(u) for u in step.get("uses", [])) if t in TIERS]
        if "check" in step:
            for text in re.split(r"==|<=|>=|<|>", step["check"]):
                sources += [qtier[n] for n in names_in(text.strip()) if n in qtier]
        for prior in step.get("depends_on", []):
            if prior in resolved:
                sources.append(resolved[prior])
            else:
                rep.add(
                    f"{cid}: step {step['step']} depends_on {prior} resolves",
                    False,
                    "forward or unknown reference",
                )
        weakest = max(sources, key=TIERS.index) if sources else "architectural"
        resolved[step["step"]] = max([declared, weakest], key=TIERS.index)
        rep.add(
            f"{cid}: step {step['step']} tier covers premises, quantities and prior steps",
            TIERS.index(declared) >= TIERS.index(weakest),
            f"declared {declared}, dependencies give {weakest}",
        )

    inherited = (
        max(list(resolved.values()) or step_tiers, key=TIERS.index)
        if (resolved or step_tiers)
        else "architectural"
    )
    if model_tier in TIERS:
        inherited = max([inherited, model_tier], key=TIERS.index)
    claim_tier = case["claim"].get("tier")
    rep.add(f"{cid}: claim declares a tier", claim_tier in TIERS, str(claim_tier))
    if claim_tier in TIERS:
        rep.add(
            f"{cid}: claim tier matches what its steps inherit",
            claim_tier == inherited,
            f"declared {claim_tier}, inherited {inherited}",
        )
    rep.add(
        f"{cid}: claim makes no native runtime statement",
        bool(case["claim"].get("native_runtime_claim", "").startswith("none")),
        case["claim"].get("native_runtime_claim", "absent"),
    )

    # 5b. role discipline
    roles = {e["id"]: e.get("role") for e in case.get("evidence", [])}
    for step in case["derivation"]:
        if step.get("direction") != "lower-bound":
            continue
        cited = [u for u in step.get("uses", []) if u in roles]
        bad = [u for u in cited if roles[u] == "achieved-rate"]
        rep.add(
            f"{cid}: step {step['step']} lower bound cites no achieved rate",
            not bad,
            f"offending: {bad}" if bad else "clean",
        )
    for ev in case.get("evidence", []):
        rep.add(
            f"{cid}: evidence {ev['id']} declares a role",
            ev.get("role") in profile["evidence_roles"],
            str(ev.get("role")),
        )

    # sensitivity sweep
    sweep = None
    sens = case.get("sensitivity")
    if sens:
        break_even = Fraction(str(sens["break_even"]))
        rows = []
        for raw in sens["sweep"]:
            value = Fraction(str(raw))
            rows.append(
                {
                    "value": float(value),
                    "dominates": value <= break_even,
                    "strictly": value < break_even,
                }
            )
        sweep = {
            "parameter": sens["parameter"],
            "break_even": float(break_even),
            "rows": rows,
            "holds_for": f"{sens['parameter']} <= {break_even}",
        }
        rep.add(
            f"{cid}: sensitivity break-even agrees with the derivation",
            any(
                s.get("check", "").replace(" ", "").endswith(f"=={break_even}")
                for s in case["derivation"]
            )
            or break_even == env.get("sigma_W_break_even"),
            f"break_even={break_even}",
        )

    # observations: recomputed for the writeup, explicitly outside the derivation
    observations = None
    obs = case.get("observations")
    if obs:
        oenv = dict(env)
        values = {}
        for item in obs["inputs"] + obs["derived"]:
            oenv[item["id"]] = evaluate(item["expr"], oenv)
            values[item["id"]] = float(oenv[item["id"]])
        cited = {u for s in case["derivation"] for u in s.get("uses", [])}
        rep.add(
            f"{cid}: observations stay out of the derivation",
            not (cited & set(values)),
            "no derivation step reads an observed rate",
        )
        observations = {"role": obs["role"], "load_bearing": obs["load_bearing"], "values": values}

    return {
        "case": cid,
        "tier": claim_tier,
        "inherited_tier": inherited,
        "architectural_part": [
            f"step {s['step']}: {s['conclusion']}"
            for s in case["derivation"]
            if s.get("tier") == "architectural"
        ],
        "quantities": {k: {"exact": str(v), "float": float(v)} for k, v in env.items()},
        "observations": observations,
        "sensitivity": sweep,
        "claim": case["claim"]["statement"],
        "native_runtime_claim": case["claim"].get("native_runtime_claim"),
        "conditional_on": case["claim"].get("conditional_part"),
        "missing_premises_for_a_native_claim": case.get("missing_premises_for_a_native_claim", []),
        "not_established": case["not_established"],
    }


# ---------------------------------------------------------------- negative control


def self_test() -> int:
    """Regressions for the two rules that keep the tiers honest."""
    facts = load_json((HERE / "facts.json").read_text())
    profile = load_json((HERE / "profile.json").read_text())
    base = load_json((HERE / "cases/perm-vs-iu4-wmma.json").read_text())

    rep = Report()
    check_case(base, facts, profile, rep)
    clean = not rep.failures
    print(f"unmodified case passes: {clean}")
    for c in rep.failures:
        print(f"  unexpected: {c['check']}  {c['detail']}")

    controls = []

    def control(name: str, mutate, marker: str):
        case = json.loads(json.dumps(base))
        case["id"] = name
        mutate(case)
        r = Report()
        check_case(case, facts, profile, r)
        hits = [c for c in r.failures if marker in c["check"]]
        controls.append((name, bool(hits), hits))

    def step_by(case, n):
        return next(s for s in case["derivation"] if s["step"] == n)

    # 1. A measured regression promoted into the impossibility argument.
    control(
        "control-achieved-rate-laundering",
        lambda c: step_by(c, 4)["uses"].append("MEAS.CORE_ABOVE_FLOOR"),
        "cites no achieved rate",
    )

    # 2. A family conclusion relabelled architectural by emptying its premise list.
    #    The step still depends on family steps and reads family quantities, so the
    #    transitive rule must catch it even with `uses` empty.
    def launder_via_empty_uses(case):
        s = step_by(case, 5)
        s["uses"] = []
        s["tier"] = "architectural"

    control(
        "control-transitive-taint-via-empty-uses",
        launder_via_empty_uses,
        "tier covers premises, quantities and prior steps",
    )

    # 3. A family quantity relabelled architectural while still reading family inputs.
    def launder_quantity(case):
        for q in case["quantities"]:
            if q["id"] == "perm_floor_required_accumulator":
                q["tier"] = "architectural"

    control(
        "control-quantity-tier-laundering",
        launder_quantity,
        "tier is not stronger than what it reads",
    )

    for name, hit, hits in controls:
        print(f"{name}: {'rejected' if hit else 'NOT REJECTED'}")
        for c in hits[:1]:
            print(f"  {c['check']}: {c['detail']}")

    duplicate_rejected = False
    try:
        load_json('{"depends_on": [1], "depends_on": [2]}')
    except ValueError:
        duplicate_rejected = True
    decimal_exact = evaluate("1.00000000000000001", {}) == Fraction(100000000000000001, 100000000000000000)
    print(f"duplicate JSON field rejected: {duplicate_rejected}")
    print(f"decimal literal retained exactly: {decimal_exact}")
    ok = clean and all(hit for _, hit, _ in controls) and duplicate_rejected and decimal_exact
    print("self-test", "passed" if ok else "FAILED")
    return 0 if ok else 1


# ---------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--reextract", action="store_true", help="re-run extract_facts.py and diff")
    ap.add_argument("--out", default=str(HERE / "results/validation.json"))
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument(
        "--self-test",
        action="store_true",
        help="check that the evidence-role rule rejects a lower bound resting on an achieved rate",
    )
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    facts = load_json((HERE / "facts.json").read_text())
    profile = load_json((HERE / "profile.json").read_text())
    cases = [
        load_json(p.read_text()) for p in sorted((HERE / "cases").glob("*.json"))
    ]

    rep = Report()
    check_sources(facts, rep)
    if args.reextract:
        check_reextract(facts, rep)

    summaries = [check_case(c, facts, profile, rep) for c in cases]

    receipt = {
        "format": FORMAT,
        "target": facts["target"],
        "scope": (
            "Re-derives every declared quantity in exact rational arithmetic and enforces the "
            "profile's evidence-role rule. It does not measure hardware and does not turn any "
            "slot bound into a time bound."
        ),
        "reextracted": bool(args.reextract),
        "facts_sha256": hashlib.sha256((HERE / "facts.json").read_bytes()).hexdigest(),
        "profile_sha256": hashlib.sha256((HERE / "profile.json").read_bytes()).hexdigest(),
        "checks_run": len(rep.checks),
        "failures": rep.failures,
        "passed": not rep.failures,
        "bridge": {
            "rule": profile["bridge"]["inheritance_rule"],
            "per_case": {s["case"]: s["tier"] for s in summaries},
            "native_dominance_proved": False,
            "why": profile["bridge"]["honest_summary_for_this_target"],
        },
        "cases": summaries,
        "unproved_parameters": [
            {"id": p["id"], "status": p["status"], "statement": p["statement"]}
            for p in profile["parameters"]
        ],
        "detail": rep.checks,
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=1) + "\n")

    if not args.quiet:
        for c in rep.checks:
            if not c["ok"]:
                print(f"FAIL  {c['check']}  {c['detail']}")
        print(f"{len(rep.checks)} checks, {len(rep.failures)} failures")
        for s in summaries:
            print(f"\n{s['case']}  [{s['tier']}]")
            for k, v in s["quantities"].items():
                print(f"  {k:<38} {v['exact']}")
            if s["observations"]:
                print("  observed (achieved rates, not used by the derivation):")
                for k, v in s["observations"]["values"].items():
                    print(f"    {k:<36} {v:.6g}")
            if s["sensitivity"]:
                sv = s["sensitivity"]
                flip = [r["value"] for r in sv["rows"] if not r["dominates"]]
                print(f"  holds for {sv['holds_for']}; sweep flips at {min(flip) if flip else 'nothing swept'}")
        print(f"\nreceipt: {out}")

    return 0 if not rep.failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
