#!/usr/bin/env python3
"""Standalone checker for finite-machine optimality certificates.

Run it on a certificate and it decides the claims from the file alone:

    python3 check.py results/m2-trit.json

It imports nothing from the search. It re-derives the instruction semantics from
the instruction names, re-derives the declared grammar from its id, re-derives
every goal set from its contract, verifies both potentials against the transition
relation, and replays each witness program. A claim survives only if the replayed
cost equals the independently recomputed bound.

What a passing run means, precisely: under this register width, this instruction
set and these charges, no straight-line program of any length beats the reported
cost. It says nothing about any real machine.
"""

from __future__ import annotations

import base64
import json
import math
import sys
from typing import Mapping, Sequence

import numpy as np

INF = np.iinfo(np.int32).max

REG_OPS = {
    "mov": lambda a, b, m: b,
    "and": lambda a, b, m: a & b,
    "or": lambda a, b, m: a | b,
    "xor": lambda a, b, m: a ^ b,
    "add": lambda a, b, m: (a + b) & m,
    "sub": lambda a, b, m: (a - b) & m,
    "mul": lambda a, b, m: (a * b) & m,
}

IMM_OPS = {
    "movi": lambda a, c, m: c & m,
    "andi": lambda a, c, m: a & c,
    "ori": lambda a, c, m: a | c,
    "xori": lambda a, c, m: a ^ c,
    "addi": lambda a, c, m: (a + c) & m,
    "muli": lambda a, c, m: (a * c) & m,
    "shli": lambda a, c, m: (a << c) & m,
    "shri": lambda a, c, m: a >> c,
}

UNARY_OPS = {"not": lambda a, m: (~a) & m}


def index_dtype(size: int):
    for dtype in (np.uint8, np.uint16, np.uint32):
        if size - 1 <= np.iinfo(dtype).max:
            return dtype
    return np.uint64

CHARGES = {
    "mov": 1, "and": 1, "or": 1, "xor": 1, "add": 1, "sub": 1, "mul": 3,
    "movi": 1, "andi": 1, "ori": 1, "xori": 1, "addi": 1, "muli": 3,
    "shli": 1, "shri": 1, "not": 1,
}

ALL_OPS = tuple(sorted(set(REG_OPS) | set(IMM_OPS) | set(UNARY_OPS)))

GRAMMARS = {
    "full": ALL_OPS,
    "monotone": ("and", "andi", "mov", "movi", "or", "ori", "shli", "shri"),
    "affine": ("add", "addi", "mov", "movi", "muli", "shli", "sub"),
    "nomul": tuple(op for op in ALL_OPS if op not in ("mul", "muli")),
    "noshr": tuple(op for op in ALL_OPS if op != "shri"),
}


class Rejected(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Rejected(message)


def field(block, key: str, where: str):
    require(isinstance(block, dict), f"{where} must be an object")
    require(key in block, f"{where} is missing {key!r}")
    return block[key]


def integer(value, where: str) -> int:
    """JSON turns true into a Python bool and 1.0 into a float. Neither is an integer here."""
    require(
        isinstance(value, int) and not isinstance(value, bool),
        f"{where} must be an integer, not {type(value).__name__}",
    )
    return value


def integer_or_none(value, where: str):
    return None if value is None else integer(value, where)


def integers(value, where: str) -> list:
    require(isinstance(value, list), f"{where} must be a list")
    return [integer(item, f"{where}[{i}]") for i, item in enumerate(value)]


def text(value, where: str) -> str:
    require(isinstance(value, str), f"{where} must be a string")
    return value


def texts(value, where: str) -> list:
    require(isinstance(value, list), f"{where} must be a list")
    return [text(item, f"{where}[{i}]") for i, item in enumerate(value)]


def distinct(names: Sequence[str], where: str) -> None:
    seen = set()
    for name in names:
        require(name not in seen, f"{where} repeats {name!r}, so one reference would silently win")
        seen.add(name)


def expected_names(ops: Sequence[str], width: int, registers: int) -> list[str]:
    names: list[str] = []
    regs = range(registers)
    for op in sorted(ops):
        if op in UNARY_OPS:
            names += [f"{op} r{d}" for d in regs]
        elif op in REG_OPS:
            names += [f"{op} r{d} r{s}" for d in regs for s in regs if s != d]
        elif op in ("shli", "shri"):
            names += [f"{op} r{d} {c}" for d in regs for c in range(1, width)]
        else:
            names += [f"{op} r{d} {c}" for d in regs for c in range(1 << width)]
    return names


def derive_table(name: str, width: int, registers: int) -> list[int]:
    tokens = name.split()
    op, mask = tokens[0], (1 << width) - 1
    dst = int(tokens[1][1:])
    require(0 <= dst < registers, f"{name}: destination out of range")
    if op in UNARY_OPS:
        apply = lambda regs: UNARY_OPS[op](regs[dst], mask)
    elif op in REG_OPS:
        src = int(tokens[2][1:])
        require(0 <= src < registers and src != dst, f"{name}: bad source register")
        apply = lambda regs: REG_OPS[op](regs[dst], regs[src], mask)
    elif op in IMM_OPS:
        imm = int(tokens[2])
        apply = lambda regs: IMM_OPS[op](regs[dst], imm, mask)
    else:
        raise Rejected(f"{name}: unknown op")
    out = []
    for state in range(1 << (width * registers)):
        regs = [(state >> (j * width)) & mask for j in range(registers)]
        regs[dst] = apply(regs) & mask
        out.append(sum(r << (j * width) for j, r in enumerate(regs)))
    return out


class Checked:
    def __init__(self, cert: Mapping) -> None:
        require(cert.get("format") == "kelana-finite-machine-certificate/1", "unknown certificate format")
        machine = field(cert, "machine", "certificate")
        self.width = integer(field(machine, "width", "machine"), "machine.width")
        self.registers = integer(field(machine, "registers", "machine"), "machine.registers")
        require(1 <= self.width <= 16 and 1 <= self.registers <= 8, "machine width or register count out of range")
        self.domain = integers(field(machine, "domain", "machine"), "machine.domain")
        self.scratch = integers(field(machine, "scratch", "machine"), "machine.scratch")
        self.mask = (1 << self.width) - 1
        self.state_count = 1 << (self.width * self.registers)
        self.inputs = len(self.domain)
        self.size = self.state_count**self.inputs

        require(self.inputs >= 1, "input domain is empty")
        require(len(self.scratch) == self.registers - 1, "scratch does not cover registers 1..k-1")
        require(len(set(self.domain)) == self.inputs, "input domain repeats a value")
        require(all(0 <= v <= self.mask for v in self.domain + self.scratch), "domain or scratch exceeds width")

        grammar = field(cert, "grammar", "certificate")
        gid = text(field(grammar, "id", "grammar"), "grammar.id")
        require(gid in GRAMMARS, f"unknown grammar id {gid!r}")
        listing = field(grammar, "instructions", "grammar")
        require(isinstance(listing, list), "grammar.instructions must be a list")
        names = [text(field(ins, "name", f"grammar.instructions[{i}]"), f"grammar.instructions[{i}].name") for i, ins in enumerate(listing)]
        require(
            names == expected_names(GRAMMARS[gid], self.width, self.registers),
            f"instruction list is not exactly grammar {gid!r} for this machine",
        )
        charges = [integer(field(ins, "charge", f"grammar.instructions[{i}]"), f"charge of {names[i]!r}") for i, ins in enumerate(listing)]
        self.charges = np.array(charges, dtype=np.int64)
        require(all(c > 0 for c in charges), "charges must be positive")
        for ins, name, charge in zip(listing, names, charges):
            require(charge == CHARGES[name.split()[0]], f"{name}: charge differs from the model")
            table = integers(field(ins, "table", f"instruction {name!r}"), f"table of {name!r}")
            require(table == derive_table(name, self.width, self.registers), f"{name}: table does not match its name")
        self.names = names

        self.tables = self._semantic_tables([ins["table"] for ins in listing])
        self.init = sum(
            ((x & self.mask) | sum((s & self.mask) << ((j + 1) * self.width) for j, s in enumerate(self.scratch)))
            * self.state_count**i
            for i, x in enumerate(self.domain)
        )

    def _digits(self) -> list[np.ndarray]:
        idx = np.arange(self.size, dtype=np.int64)
        return [(idx // self.state_count**i) % self.state_count for i in range(self.inputs)]

    def _semantic_tables(self, tables: Sequence[Sequence[int]]) -> np.ndarray:
        digits = self._digits()
        out = np.empty((len(tables), self.size), dtype=index_dtype(self.size))
        for k, table in enumerate(tables):
            require(len(table) == self.state_count, "instruction table is not a total state map")
            arr = np.asarray(table, dtype=np.int64)
            require(bool(((arr >= 0) & (arr < self.state_count)).all()), "instruction table leaves the state set")
            acc = np.zeros(self.size, dtype=np.int64)
            for i, digit in enumerate(digits):
                acc += arr[digit] * self.state_count**i
            out[k] = acc
        return out

    def dense(self, block: Mapping, where: str) -> np.ndarray:
        require(integer(field(block, "space", where), f"{where}.space") == self.size, f"{where} is sized for a different state space")
        infinity = integer(field(block, "infinity", where), f"{where}.infinity")
        require(0 < infinity <= 255, f"{where}.infinity must be a positive byte value")
        raw = np.frombuffer(base64.b64decode(text(field(block, "u8", where), f"{where}.u8")), dtype=np.uint8)
        require(raw.size == self.size, f"{where} does not cover the state space")
        values = raw.astype(np.int64)
        require(bool((values <= infinity).all()), f"{where} value exceeds the declared infinity marker")
        return np.where(values == infinity, INF, values)

    def views(self, reg: int) -> list[np.ndarray]:
        return [(digit >> (reg * self.width)) & self.mask for digit in self._digits()]

    def goal(self, spec: Mapping) -> np.ndarray:
        kind = text(field(spec, "kind", "goal"), "goal.kind")
        if kind == "pair-exact":
            require(self.registers == 2, "pair-exact requires exactly two registers")
            targets = field(spec, "targets", "goal")
            require(isinstance(targets, list) and len(targets) == 2, "pair-exact needs two targets")
            goal = np.ones(self.size, dtype=bool)
            for reg, target in enumerate(targets):
                goal &= self.goal({"kind": "exact", "observe": reg, "target": integers(target, f"goal.targets[{reg}]")})
            return goal
        reg = integer(field(spec, "observe", "goal"), "goal.observe")
        target = integers(field(spec, "target", "goal"), "goal.target")
        require(0 <= reg < self.registers, "observed register out of range")
        require(len(target) == self.inputs, "target does not cover the input domain")
        require(all(0 <= v <= self.mask for v in target), "target value exceeds the register width")
        views = self.views(reg)
        if kind == "exact":
            ok = np.ones(self.size, dtype=bool)
            for view, want in zip(views, target):
                ok &= view == want
            return ok
        if kind == "cleared":
            ok = self.goal({"kind": "exact", "observe": reg, "target": target})
            for other in range(self.registers):
                if other == reg:
                    continue
                for view in self.views(other):
                    ok &= view == 0
            return ok
        if kind in ("relabeled", "refines"):
            ok = np.ones(self.size, dtype=bool)
            for i in range(self.inputs):
                for j in range(i + 1, self.inputs):
                    if kind == "relabeled":
                        ok &= (views[i] == views[j]) == (target[i] == target[j])
                    elif target[i] != target[j]:
                        ok &= views[i] != views[j]
            return ok
        raise Rejected(f"unknown goal kind {kind!r}")

    def waypoint(self, spec: Mapping) -> np.ndarray:
        target = integers(field(spec, "target", "waypoint"), "waypoint.target")
        require(len(target) == self.inputs, "waypoint does not cover the input domain")
        require(all(0 <= v <= self.mask for v in target), "waypoint value exceeds the register width")
        where = field(spec, "registers", "waypoint")
        regs = range(self.registers) if where == "any" else [integer(where, "waypoint.registers")]
        ok = np.zeros(self.size, dtype=bool)
        for reg in regs:
            require(0 <= reg < self.registers, "waypoint register out of range")
            here = np.ones(self.size, dtype=bool)
            for view, want in zip(self.views(reg), target):
                here &= view == want
            ok |= here
        return ok

    def verify_forward(self, values: np.ndarray) -> None:
        require(values[self.init] == 0, "forward potential is not zero at the initial state")
        for k in range(len(self.names)):
            budget = np.where(values >= INF, INF, values + int(self.charges[k]))
            require(bool((values[self.tables[k]] <= budget).all()), f"forward potential breaks on {self.names[k]!r}")

    def verify_backward(self, values: np.ndarray, goal: np.ndarray) -> None:
        require(bool((values[goal] == 0).all()), "backward potential is nonzero on a goal state")
        for k in range(len(self.names)):
            landed = values[self.tables[k]]
            budget = np.where(landed >= INF, INF, landed + int(self.charges[k]))
            require(bool((values <= budget).all()), f"backward potential breaks on {self.names[k]!r}")

    def verify_cut(self, cut: Mapping, forward: np.ndarray, backward: np.ndarray) -> dict:
        name = text(field(cut, "name", "cut"), "cut.name")
        floor = integer(field(cut, "floor", f"cut {name!r}"), f"cut {name!r}.floor")
        budget = integer(field(cut, "budget", f"cut {name!r}"), f"cut {name!r}.budget")
        require(int(backward[self.init]) == floor, f"{name}: floor is not the backward potential at the initial state")
        require(budget >= floor, f"{name}: cost budget is below the proven floor, so it describes no program")
        raw = field(cut, "drops", f"cut {name!r}")
        require(isinstance(raw, list), f"{name}: drops must be a list")
        declared = [integer_or_none(d, f"{name}: drop {i}") for i, d in enumerate(raw)]
        require(len(declared) == len(self.names), f"{name}: drops do not cover the instruction set")
        families: dict[str, int] = {}
        for k, claimed in enumerate(declared):
            landing = self.tables[k]
            landed = backward[landing]
            reachable = np.where((forward < INF) & (landed < INF), forward + int(self.charges[k]) + landed, INF)
            usable = reachable <= budget
            if claimed is None:
                require(not usable.any(), f"{name}: {self.names[k]!r} is usable inside the budget but declared unusable")
                continue
            require(bool(usable.any()), f"{name}: {self.names[k]!r} is declared usable but has no step inside the budget")
            actual = int((backward[usable] - backward[landing[usable]]).max())
            require(claimed >= actual, f"{name}: {self.names[k]!r} drops {actual}, more than the declared {claimed}")
            op = self.names[k].split()[0]
            families[op] = max(families.get(op, claimed), claimed)
        usable_families = texts(field(cut, "usable_families", f"cut {name!r}"), f"cut {name!r}.usable_families")
        require(sorted(families) == usable_families, f"{name}: usable families disagree with the drops")
        widest = max(families.values(), default=0)
        expected = math.ceil(floor / widest) if widest > 0 else None
        declared_length = integer_or_none(field(cut, "length_at_least", f"cut {name!r}"), f"cut {name!r}.length_at_least")
        require(declared_length == expected, f"{name}: length bound does not follow from the drops")
        return {
            "name": name,
            "budget": budget,
            "floor": floor,
            "length_at_least": expected,
            "usable_families": usable_families,
        }

    def replay(self, program: Sequence[str]) -> tuple[int, int, list[int]]:
        state, cost, trace = self.init, 0, [self.init]
        for step in program:
            require(step in self.names, f"witness uses {step!r}, which is not in the grammar")
            k = self.names.index(step)
            state = int(self.tables[k][state])
            cost += int(self.charges[k])
            trace.append(state)
        return state, cost, trace


def check(cert: Mapping) -> list[dict]:
    checked = Checked(cert)
    forward = checked.dense(field(cert, "forward", "certificate"), "forward potential")
    checked.verify_forward(forward)

    blocks = cert.get("backward", [])
    require(isinstance(blocks, list), "backward must be a list")
    distinct([text(field(b, "id", f"backward[{i}]"), f"backward[{i}].id") for i, b in enumerate(blocks)], "backward id")
    backward: dict[str, tuple[Mapping, np.ndarray]] = {}
    for block in blocks:
        goal = checked.goal(field(block, "goal", "backward potential"))
        values = checked.dense(block, f"backward potential {block['id']!r}")
        checked.verify_backward(values, goal)
        backward[block["id"]] = (block["goal"], values)

    declared_cuts = cert.get("cuts", [])
    require(isinstance(declared_cuts, list), "cuts must be a list")
    queries = field(cert, "queries", "certificate")
    require(isinstance(queries, list), "queries must be a list")
    names = [text(field(q, "name", f"queries[{i}]"), f"queries[{i}].name") for i, q in enumerate(queries)]
    names += [text(field(c, "name", f"cuts[{i}]"), f"cuts[{i}].name") for i, c in enumerate(declared_cuts)]
    distinct(names, "claim name")

    cuts = []
    for cut in declared_cuts:
        reference = text(field(cut, "potential", "cut"), "cut.potential")
        require(reference in backward, f"cut names backward potential {reference!r}, which the certificate does not carry")
        cuts.append(checked.verify_cut(cut, forward, backward[reference][1]))

    report = []
    for query in queries:
        name = query["name"]
        goal = checked.goal(field(query, "goal", f"query {name!r}"))
        through = query.get("through")
        if through is None:
            live = goal & (forward < INF)
            bound = int(forward[live].min()) if live.any() else INF
        else:
            reference = text(field(through, "backward", f"query {name!r}.through"), f"query {name!r}.through.backward")
            require(reference in backward, f"{name}: names backward potential {reference!r}, which is absent")
            spec, values = backward[reference]
            require(spec == query["goal"], f"{name}: backward potential was built for another goal")
            way = checked.waypoint(field(through, "waypoint", f"query {name!r}.through"))
            live = way & (forward < INF) & (values < INF)
            bound = int((forward[live] + values[live]).min()) if live.any() else INF

        claim = field(query, "claim", f"query {name!r}")
        status = text(field(claim, "status", f"query {name!r}.claim"), f"query {name!r}.claim.status")
        witness = texts(query.get("witness") or [], f"query {name!r}.witness")
        if bound >= INF:
            require(status == "impossible", f"{name}: no program exists but the claim is not impossible")
            cost_field = integer_or_none(field(claim, "cost", f"query {name!r}.claim"), f"query {name!r}.claim.cost")
            require(cost_field is None, f"{name}: impossible claim states a cost")
            require(not witness, f"{name}: impossible claim carries a witness")
            report.append({"name": name, "status": "impossible", "cost": None, "bound": None})
            continue

        final, cost, trace = checked.replay(witness)
        require(bool(goal[final]), f"{name}: witness does not end in the goal set")
        if through is not None:
            way = checked.waypoint(through["waypoint"])
            require(any(bool(way[s]) for s in trace), f"{name}: witness never materializes the waypoint")
        require(cost == bound, f"{name}: witness costs {cost}, lower bound is {bound}")
        claimed = integer(field(claim, "cost", f"query {name!r}.claim"), f"query {name!r}.claim.cost")
        require(status == "optimal" and claimed == bound, f"{name}: claim disagrees with the check")
        report.append({"name": name, "status": "optimal", "cost": cost, "bound": bound, "length": len(witness)})
    return report + [{"name": c["name"], "status": "count-cut", **c} for c in cuts]


def main(argv: Sequence[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    failures = 0
    for path in argv[1:]:
        with open(path) as handle:
            cert = json.load(handle)
        try:
            report = check(cert)
        except Rejected as error:
            print(f"REJECT {path}: {error}")
            failures += 1
            continue
        print(f"ACCEPT {path}  grammar={cert['grammar']['id']}  claims={len(report)}")
        for row in report:
            if row["status"] == "count-cut":
                summary = (
                    f"at cost <= {row['budget']}: at least {row['length_at_least']} instructions, "
                    f"only from {', '.join(row['usable_families'])}"
                )
            elif row["cost"] is None:
                summary = "impossible at every length"
            else:
                summary = f"cost {row['cost']}"
            print(f"    {row['name']:<34} {summary}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
