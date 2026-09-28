"""Check a concrete SSA schedule in a declared, abstract resource machine.

Inputs are present at time zero. Operands are read at instruction start;
results are available after the declared latency. A destination occupies one
homogeneous register from issue until its last read, or until return if observed.
This is an explicit machine contract, not a claim about gfx1151 operand capture.
"""
from collections import Counter, defaultdict
from fractions import Fraction
import heapq

from certificates import (checked, require, rational, digest, model_data, family_data,
                          verify_dual, verify_infeasible)


def sweep(intervals):
    events = defaultdict(Fraction)
    for start, end, amount, _ in intervals:
        if start < end:
            events[start] += amount
            events[end] -= amount
    active = peak = Fraction(0)
    at = Fraction(0)
    for time, delta in sorted(events.items()):
        active += delta
        require(active >= 0, "negative active reservation")
        if active > peak:
            peak, at = active, time
    require(active == 0, "unclosed reservation")
    return peak, at


@checked
def verify_schedule(model, problem, plan):
    capacity, demand = model_data(model)
    require(plan["binding"] == {"model": digest(model), "problem": digest(problem)},
            "schedule has a stale or different model/target")
    inputs = problem["inputs"]
    require(len(inputs) == len(set(inputs)), "duplicate input names")
    ready = {name: Fraction(0) for name in inputs}
    starts = {name: Fraction(0) for name in inputs}
    uses = {name: [] for name in inputs}
    reservations = {r: [] for r in capacity}
    horizon = Fraction(0)
    counts = Counter()
    nodes = plan["nodes"]
    for node in nodes:
        name, opname, args = node["id"], node["op"], node["args"]
        require(name not in ready, f"duplicate value ID {name}")
        require(opname in model["operations"], f"unknown operation {opname}")
        op = model["operations"][opname]
        require(isinstance(op["arity"], int) and op["arity"] >= 0, "invalid instruction arity")
        require(len(args) == op["arity"], f"arity mismatch at {name}")
        require(all(arg in ready for arg in args), f"unavailable value at {name}")
        start, latency = rational(node["start"]), rational(op["latency"])
        require(start >= 0 and latency > 0, "negative start or nonpositive instruction latency")
        require(all(ready[arg] <= start for arg in args), f"dependency not ready at {name}")
        for arg in args:
            uses[arg].append(start)
        starts[name], ready[name], uses[name] = start, start+latency, []
        counts[opname] += 1
        horizon = max(horizon, start+latency)
        billed = {r: Fraction(0) for r in capacity}
        for reservation in op["reservations"]:
            resource = reservation["resource"]
            require(resource in capacity, f"unknown reservation resource {resource}")
            offset, duration, amount = (rational(reservation[k]) for k in ("offset", "duration", "amount"))
            require(offset >= 0 and duration > 0 and amount > 0, "invalid reservation interval")
            reservations[resource].append((start+offset, start+offset+duration, amount, name))
            billed[resource] += duration*amount
            horizon = max(horizon, start+offset+duration)
        for r in capacity:
            require(billed[r] >= demand[opname][r], f"schedule footprint underpays lower demand for {opname}/{r}")
    outputs = plan["outputs"]
    require(outputs and all(out in ready for out in outputs), "missing or unknown returned value")
    peaks = {}
    for r in capacity:
        peak, at = sweep(reservations[r])
        require(peak <= capacity[r], f"resource {r} overbooked at {at}: {peak} > {capacity[r]}")
        peaks[r] = str(peak)
    live = []
    for name in ready:
        end = max([ready[name]]+uses[name]+([horizon] if name in outputs else []))
        live.append((starts[name], end, Fraction(1), name))
    register_peak, _ = sweep(live)
    register_peak = max(register_peak, len(inputs), len(set(outputs)))
    limit = model["register_capacity"]
    require(isinstance(limit, int) and limit > 0, "register capacity must be a positive integer")
    require(register_peak <= limit, f"register capacity exceeded: {register_peak} > {limit}")
    ends = {name: end for _, end, _, name in live}
    allocation = {name: i for i, name in enumerate(inputs)}
    active = [(ends[name], i) for i, name in enumerate(inputs)]
    heapq.heapify(active)
    free = list(range(len(inputs), limit))
    heapq.heapify(free)
    for node in sorted(nodes, key=lambda n: starts[n["id"]]):
        name = node["id"]
        while active and active[0][0] <= starts[name]:
            _, slot = heapq.heappop(active)
            heapq.heappush(free, slot)
        require(free, "register allocation failed despite peak check")
        slot = heapq.heappop(free)
        allocation[name] = slot
        heapq.heappush(active, (ends[name], slot))
    semantics = all("table" in model["operations"][n["op"]] for n in nodes)
    replayed = 0
    if semantics:
        size = model["value_count"]
        require(isinstance(size, int) and size > 0, "value alphabet must be positive")
        for node in nodes:
            op = model["operations"][node["op"]]
            require(len(op["table"]) == size**op["arity"], "instruction table shape mismatch")
            require(all(type(v) is int and 0 <= v < size for v in op["table"]), "invalid instruction result")
        require(problem["cases"], "no reachable inputs declared")
        for index, case in enumerate(problem["cases"]):
            require(len(case["inputs"]) == len(inputs), "input case arity mismatch")
            require(all(type(v) is int and 0 <= v < size for v in case["inputs"]), "invalid input value")
            values = dict(zip(inputs, case["inputs"]))
            for node in nodes:
                op = model["operations"][node["op"]]
                address = sum(values[arg]*size**i for i, arg in enumerate(node["args"]))
                values[node["id"]] = op["table"][address]
            observed = [values[out] for out in outputs]
            require(observed == case["outputs"], f"endpoint mismatch on case {index}: {observed} != {case['outputs']}")
            replayed += 1
    return {"valid": True, "kind": "model_feasible_schedule", "upper_bound": str(horizon),
            "unit": model["unit"], "counts": dict(counts), "resource_peaks": peaks,
            "register_peak": int(register_peak), "register_assignment": allocation,
            "correctness_replayed": semantics,
            "reachable_inputs_replayed": replayed,
            "state_contract": "SSA values; read at start, result after latency; homogeneous registers; half-open reservations",
            "machine_assumptions": model["assumptions"]}


def membership(model, family, counts):
    _, _, cuts = family_data(model, family)
    outside = set(counts)-set(family["allowed_operations"])
    failed = []
    for cut in cuts:
        total = sum(rational(cut["coefficients"].get(op, 0))*n for op, n in counts.items())
        if total < rational(cut["minimum"]):
            failed.append(cut["id"])
    restrictions = [c["id"] for c in cuts if c["role"] == "class_restriction" and c["id"] in failed]
    necessities = [c["id"] for c in cuts if c["role"] == "necessary_for_target" and c["id"] in failed]
    return {"allowed_operations_only": not outside, "outside_operations": sorted(outside),
            "satisfies_count_obligations": not failed, "failed_obligations": failed,
            "failed_class_restrictions": restrictions, "failed_necessary_cuts": necessities}


@checked
def compare(model, problem, family, dual, plan):
    lower = verify_dual(model, problem, family, dual)
    upper = verify_schedule(model, problem, plan)
    require(lower["valid"], f"lower certificate failed: {lower}")
    require(upper["valid"], f"upper schedule failed: {upper}")
    require(upper["correctness_replayed"], "schedule lacks an endpoint correctness certificate")
    member = membership(model, family, upper["counts"])
    lo, hi = rational(lower["lower_bound"]), rational(upper["upper_bound"])
    contradiction = (member["allowed_operations_only"] and not member["failed_class_restrictions"]
                     and bool(member["failed_necessary_cuts"]))
    status = ("correct_program_refutes_stated_count_obligation" if contradiction else
              "family_strictly_dominated_under_premises" if hi < lo else
              "family_optimum_under_premises" if hi == lo and member["allowed_operations_only"] and member["satisfies_count_obligations"] else
              "matches_family_lower_bound_outside_family" if hi == lo else
              "bounds_leave_gap")
    require(not (member["allowed_operations_only"] and member["satisfies_count_obligations"] and hi < lo),
            "consistent certificates violate weak duality")
    return {"valid": True, "status": status, "lower_bound": str(lo), "upper_bound": str(hi),
            "membership": member, "lower": lower, "upper": upper,
            "native_runtime_claim": False}
