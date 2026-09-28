"""Exact conditional resource certificates. Solvers propose; this module replays.

A n >= b describes a declared family, D n <= T c describes its resource bill.
Nonnegative lambda/mu with A^T lambda <= D^T mu imply
T >= (lambda.b)/(mu.c). The premise A n >= b is not proved by checking the dual.
"""
from fractions import Fraction
from functools import wraps
import hashlib
import json


class InvalidArtifact(ValueError):
    pass


def require(condition, reason):
    if not condition:
        raise InvalidArtifact(reason)


def rational(value):
    require(isinstance(value, (int, str, Fraction)) and not isinstance(value, bool),
            "rational values must be integers or exact strings, never floats")
    return Fraction(value)


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def checked(fn):
    @wraps(fn)
    def call(*args, **kwargs):
        try:
            return fn(*args, **kwargs)
        except (InvalidArtifact, KeyError, TypeError, ZeroDivisionError, ValueError) as error:
            return {"valid": False, "reason": str(error)}
    return call


def model_data(model):
    require(model["unit"] and model["assumptions"], "name the timing unit and machine assumptions")
    resources = model["resources"]
    operations = model["operations"]
    require(resources and operations, "model needs resources and operations")
    capacities = {r: rational(c) for r, c in resources.items()}
    require(all(c > 0 for c in capacities.values()), "resource capacities must be positive")
    demands = {}
    for name, op in operations.items():
        require(set(op["demand"]) <= set(resources), f"unknown demand resource in {name}")
        demands[name] = {r: rational(op["demand"].get(r, 0)) for r in resources}
        require(all(d >= 0 for d in demands[name].values()), "resource demands must be nonnegative")
    return capacities, demands


def family_data(model, family):
    capacity, demand = model_data(model)
    allowed = family["allowed_operations"]
    require(allowed and len(allowed) == len(set(allowed)), "allowed operations must be nonempty and unique")
    require(set(allowed) <= set(demand), "family names an unknown operation")
    cuts = family["obligations"]
    require(cuts, "a family needs explicit obligations")
    require(len({c["id"] for c in cuts}) == len(cuts), "obligation IDs must be unique")
    for cut in cuts:
        require(cut["premise"], f"missing justification/premise for {cut['id']}")
        require(cut["role"] in ("necessary_for_target", "class_restriction"), "declare each cut's logical role")
        require(set(cut["coefficients"]) <= set(allowed), "cut references an operation outside its family")
        rational(cut["minimum"])
        for a in cut["coefficients"].values():
            rational(a)
    return capacity, demand, cuts


def binding(model, problem, family):
    return {"model": digest(model), "problem": digest(problem), "family": digest(family)}


def check_binding(model, problem, family, cert):
    require(cert["binding"] == binding(model, problem, family), "certificate has a stale or different model, target, or family")


def weights(names, raw):
    require(set(raw) <= set(names), "certificate names unknown coordinates")
    result = {n: rational(raw.get(n, 0)) for n in names}
    require(all(v >= 0 for v in result.values()), "certificate weights must be nonnegative")
    return result


@checked
def verify_dual(model, problem, family, certificate):
    capacity, demand, cuts = family_data(model, family)
    check_binding(model, problem, family, certificate)
    lam = weights([c["id"] for c in cuts], certificate["lambda"])
    mu = weights(capacity, certificate["mu"])
    denominator = sum(mu[r]*capacity[r] for r in capacity)
    require(denominator > 0, "zero resource-price normalization")
    slack = {}
    for op in family["allowed_operations"]:
        left = sum(lam[c["id"]]*rational(c["coefficients"].get(op, 0)) for c in cuts)
        right = sum(mu[r]*demand[op][r] for r in capacity)
        require(left <= right, f"dual inequality fails for {op}: {left} > {right}")
        slack[op] = str(right-left)
    numerator = sum(lam[c["id"]]*rational(c["minimum"]) for c in cuts)
    lower = max(Fraction(0), numerator/denominator)
    return {"valid": True, "kind": "conditional_resource_lower_bound", "lower_bound": str(lower),
            "unit": model["unit"], "operation_slack": slack,
            "premises": [c["premise"] for c in cuts], "machine_assumptions": model["assumptions"],
            "semantic_cuts_proved_by_this_checker": False}


@checked
def count_caps(model, problem, family, certificate, time_budget):
    """Necessary instruction caps for programs meeting a declared time budget.

    Dual column slack is a nonnegative penalty. Its total bill cannot exceed
    budget * priced capacity - priced required work. At a tight bound all
    positive-slack instructions disappear, without naming source intermediates.
    """
    result = verify_dual(model, problem, family, certificate)
    require(result["valid"], f"invalid dual: {result}")
    capacity, _, cuts = family_data(model, family)
    lam = weights([c["id"] for c in cuts], certificate["lambda"])
    mu = weights(capacity, certificate["mu"])
    budget = rational(time_budget)
    require(budget >= 0, "negative time budget")
    service = sum(mu[r]*capacity[r] for r in capacity)
    work = sum(lam[c["id"]]*rational(c["minimum"]) for c in cuts)
    remaining = budget*service-work
    slack = {op: rational(v) for op, v in result["operation_slack"].items()}
    return {"valid": True, "kind": "conditional_budget_count_caps", "time_budget": str(budget),
            "budget_infeasible": remaining < 0,
            "joint_penalty_coefficients": {op: str(v) for op, v in slack.items()},
            "joint_penalty_at_most": str(remaining),
            "counts_at_most": {} if remaining < 0 else
                {op: remaining // v for op, v in slack.items() if v > 0},
            "zero_slack_is_unconstrained": [op for op, v in slack.items() if v == 0],
            "budget_is_additional_premise": True, "native_runtime_claim": False}


@checked
def verify_infeasible(model, problem, family, certificate):
    _, _, cuts = family_data(model, family)
    check_binding(model, problem, family, certificate)
    lam = weights([c["id"] for c in cuts], certificate["lambda"])
    for op in family["allowed_operations"]:
        require(sum(lam[c["id"]]*rational(c["coefficients"].get(op, 0)) for c in cuts) <= 0,
                f"infeasibility certificate has a positive column at {op}")
    gain = sum(lam[c["id"]]*rational(c["minimum"]) for c in cuts)
    require(gain > 0, "infeasibility certificate has no positive contradiction")
    return {"valid": True, "kind": "conditional_family_impossibility", "contradiction": str(gain),
            "premises": [c["premise"] for c in cuts], "semantic_cuts_proved_by_this_checker": False}


@checked
def verify_primal(model, problem, family, certificate):
    capacity, demand, cuts = family_data(model, family)
    check_binding(model, problem, family, certificate)
    counts = weights(family["allowed_operations"], certificate["counts"])
    time = rational(certificate["time"])
    require(time >= 0, "negative relaxed time")
    for cut in cuts:
        achieved = sum(rational(cut["coefficients"].get(op, 0))*counts[op] for op in counts)
        require(achieved >= rational(cut["minimum"]), f"relaxed counts violate {cut['id']}")
    for r in capacity:
        require(sum(demand[op][r]*counts[op] for op in counts) <= time*capacity[r],
                f"relaxed counts exceed resource {r}")
    return {"valid": True, "kind": "feasible_count_relaxation", "time": str(time),
            "is_program_or_schedule": False}


@checked
def verify_relaxation_pair(model, problem, family, dual, primal):
    d, p = verify_dual(model, problem, family, dual), verify_primal(model, problem, family, primal)
    require(d["valid"], f"invalid dual: {d}")
    require(p["valid"], f"invalid primal: {p}")
    require(rational(d["lower_bound"]) <= rational(p["time"]), "weak duality violated")
    return {"valid": True, "relaxation_optimal": d["lower_bound"] == p["time"],
            "lower_bound": d["lower_bound"], "relaxed_feasible_time": p["time"],
            "proves_program_optimality": False}


def propose(model, problem, family, max_bases=20000, max_seconds=3):
    """Propose small exact LP vertices; only replayed witnesses establish claims."""
    from vertices import minimum_vertex
    capacity, demand, cuts = family_data(model, family)
    ops, resources = family["allowed_operations"], list(capacity)
    b = [rational(c["minimum"]) for c in cuts]
    a = [[rational(c["coefficients"].get(op, 0)) for op in ops] for c in cuts]
    d = [[demand[op][r] for op in ops] for r in resources]
    c = [capacity[r] for r in resources]
    dual_search = minimum_vertex([-v for v in b]+[0]*len(resources),
                                 [[a[i][j] for i in range(len(cuts))]+[-d[i][j] for i in range(len(resources))]
                                  for j in range(len(ops))], [0]*len(ops),
                                 [[0]*len(cuts)+c], [1], max_bases, max_seconds)
    primal_search = minimum_vertex([0]*len(ops)+[1],
                                   [[-v for v in row]+[0] for row in a]+[row+[-cap] for row, cap in zip(d, c)],
                                   [-v for v in b]+[0]*len(resources), max_bases=max_bases, max_seconds=max_seconds)
    coverage = {"dual": {k: v for k, v in dual_search.items() if k not in ("point", "objective")},
                "primal": {k: v for k, v in primal_search.items() if k not in ("point", "objective")}}
    dual_values, primal_values = dual_search["point"], primal_search["point"]
    if dual_values is None or primal_values is None:
        return {"status": "no_witness_pair", "search": coverage,
                "proves_infeasibility": False, "certificate": None}
    bind = binding(model, problem, family)
    dual = {"binding": bind, "lambda": {cut["id"]: str(v) for cut, v in zip(cuts, dual_values)},
            "mu": {r: str(v) for r, v in zip(resources, dual_values[len(cuts):])}}
    primal = {"binding": bind, "counts": {op: str(v) for op, v in zip(ops, primal_values)},
              "time": str(primal_values[-1])}
    result = verify_relaxation_pair(model, problem, family, dual, primal)
    return {"status": "checked" if result["valid"] else "rejected_proposal",
            "dual": dual, "primal": primal, "verification": result, "search": coverage}
