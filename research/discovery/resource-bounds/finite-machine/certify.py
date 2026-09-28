"""Search the closed semantic-state graph and emit replayable optimality certificates.

Two potentials carry the whole lower-bound argument.

Forward potential `g` over semantic states satisfies `g[init] = 0`, `g >= 0`, and
`g[T_i(s)] <= g[s] + charge_i` for every state and instruction, with infinity
absorbing. Telescoping along any program gives `cost >= g[final state]`, so the
cheapest program reaching a set A costs at least `min_{s in A} g[s]`. An infinite
minimum is an impossibility proof covering every program length.

Backward potential `p` for a goal set G satisfies `p >= 0`, `p[s] = 0` on G, and
`p[s] <= charge_i + p[T_i(s)]`. Telescoping gives `cost >= p[start]` for any
program from `start` into G.

A program forced through a waypoint set W splits at its first W state, so it costs
at least `min_{s in W} (g[s] + p[s])`. That is how the certificate prices the cost
of materializing a chosen intermediate, with no extra state-space axis.

The two potentials together also bound instruction *counts*. A run of cost at most
C that takes instruction j at state s costs at least `g[s] + charge_j + p[T_j(s)]`,
so every step it takes satisfies that sum <= C. Let `A_j` be the largest drop
`p[s] - p[T_j(s)]` over the steps of j that fit the budget. Telescoping the drops
along the run gives `sum_j A_j n_j >= p[init]`. The inequality holds over counts
with no charges in it, but its coefficients come from a charged budget and are
only valid inside it: raising C admits more steps, grows the coefficients and
weakens the cut. An instruction with no step fitting the budget appears zero
times, which rules whole opcode families out of every optimal program.

Parent pointers exist only to print a witness program. The checker replays the
witness and re-derives both bounds; it never reads search history.
"""

from __future__ import annotations

import base64
import json
import math
from dataclasses import dataclass
from typing import Mapping, Sequence

import numpy as np

from machine import (
    GRAMMARS,
    GRAMMAR_NOTES,
    Instruction,
    Machine,
    build_grammar,
    goal_mask,
    semantic_tables,
    waypoint_mask,
)

INF = np.iinfo(np.int32).max


@dataclass
class Space:
    machine: Machine
    grammar_id: str
    instructions: list[Instruction]
    tables: np.ndarray
    charges: np.ndarray
    init: int

    @classmethod
    def build(cls, machine: Machine, grammar_id: str) -> "Space":
        instructions = build_grammar(machine, GRAMMARS[grammar_id])
        tables = semantic_tables(machine, instructions)
        charges = np.array([ins.charge for ins in instructions], dtype=np.int64)
        return cls(machine, grammar_id, instructions, tables, charges, machine.initial_semantic())


def forward_potential(space: Space) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Dijkstra by increasing distance. All charges are positive integers."""
    n = space.machine.semantic_count
    dist = np.full(n, INF, dtype=np.int64)
    parent_state = np.full(n, -1, dtype=np.int64)
    parent_instr = np.full(n, -1, dtype=np.int64)
    dist[space.init] = 0
    value, highest = 0, 0
    while value <= highest:
        frontier = np.flatnonzero(dist == value)
        if frontier.size:
            for k in range(len(space.instructions)):
                tentative = value + int(space.charges[k])
                landing = space.tables[k][frontier]
                improves = dist[landing] > tentative
                if not improves.any():
                    continue
                dist[landing[improves]] = tentative
                parent_state[landing[improves]] = frontier[improves]
                parent_instr[landing[improves]] = k
                highest = max(highest, tentative)
        value += 1
    return dist, parent_state, parent_instr


def backward_potential(space: Space, goal: np.ndarray) -> np.ndarray:
    """Value iteration to the least fixed point of the Bellman operator."""
    n = space.machine.semantic_count
    dist = np.where(goal, 0, INF).astype(np.int64)
    while True:
        best = np.full(n, INF, dtype=np.int64)
        for k in range(len(space.instructions)):
            landed = dist[space.tables[k]]
            candidate = np.where(landed >= INF, INF, landed + int(space.charges[k]))
            np.minimum(best, candidate, out=best)
        nxt = np.where(goal, 0, best)
        if np.array_equal(nxt, dist):
            return dist
        dist = nxt


def forward_witness(space: Space, parent_state: np.ndarray, parent_instr: np.ndarray, state: int) -> list[str]:
    program: list[str] = []
    while state != space.init:
        k = int(parent_instr[state])
        program.append(space.instructions[k].name)
        state = int(parent_state[state])
    program.reverse()
    return program


def backward_witness(space: Space, potential: np.ndarray, state: int) -> list[str]:
    program: list[str] = []
    while potential[state] > 0:
        for k in range(len(space.instructions)):
            landing = int(space.tables[k][state])
            if potential[landing] < INF and potential[landing] + int(space.charges[k]) == potential[state]:
                program.append(space.instructions[k].name)
                state = landing
                break
        else:
            raise AssertionError("backward potential has no improving step")
    return program


def budget_steps(space: Space, forward: np.ndarray, backward: np.ndarray, budget: int, k: int) -> np.ndarray:
    """States where instruction k can be taken by some accepting run of cost at most budget."""
    landed = backward[space.tables[k]]
    total = np.where((forward < INF) & (landed < INF), forward + int(space.charges[k]) + landed, INF)
    return total <= budget


def instruction_drops(space: Space, forward: np.ndarray, backward: np.ndarray, budget: int) -> list:
    out = []
    for k in range(len(space.instructions)):
        usable = budget_steps(space, forward, backward, budget, k)
        landing = space.tables[k]
        out.append(int((backward[usable] - backward[landing[usable]]).max()) if usable.any() else None)
    return out


POTENTIAL_INFINITY = 255


def encode_potential(values: np.ndarray) -> dict:
    finite = values[values < INF]
    if finite.size and int(finite.max()) >= POTENTIAL_INFINITY:
        raise ValueError("potential exceeds the byte encoding; widen the format before claiming this bound")
    packed = np.where(values >= INF, POTENTIAL_INFINITY, values).astype(np.uint8)
    return {
        "space": int(values.size),
        "infinity": POTENTIAL_INFINITY,
        "u8": base64.b64encode(packed.tobytes()).decode("ascii"),
    }


class Certificate:
    def __init__(self, experiment: str, space: Space, note: str) -> None:
        self.experiment = experiment
        self.space = space
        self.note = note
        self.forward, self._parent_state, self._parent_instr = forward_potential(space)
        self.backward: dict[str, tuple[Mapping, np.ndarray]] = {}
        self.queries: list[dict] = []
        self.cuts: list[dict] = []

    def _claim(self, name: str) -> None:
        taken = {q["name"] for q in self.queries} | {c["name"] for c in self.cuts}
        if name in taken:
            raise ValueError(f"claim name {name!r} is already used in this certificate")

    def exact_cost(self, goal_spec: Mapping) -> int:
        mask = goal_mask(self.space.machine, goal_spec)
        return int(self.forward[mask].min()) if mask.any() else INF

    def reach(self, name: str, goal_spec: Mapping) -> dict:
        self._claim(name)
        mask = goal_mask(self.space.machine, goal_spec)
        best = INF
        if mask.any():
            candidates = np.flatnonzero(mask)
            best = int(self.forward[candidates].min())
        if best >= INF:
            query = {
                "name": name,
                "goal": dict(goal_spec),
                "through": None,
                "claim": {"status": "impossible", "cost": None},
                "witness": [],
            }
        else:
            state = int(candidates[np.argmin(self.forward[candidates])])
            program = forward_witness(self.space, self._parent_state, self._parent_instr, state)
            query = {
                "name": name,
                "goal": dict(goal_spec),
                "through": None,
                "claim": {"status": "optimal", "cost": best},
                "witness": program,
            }
        self.queries.append(query)
        return query

    def through(self, name: str, goal_spec: Mapping, waypoint: Mapping, backward_id: str) -> dict:
        self._claim(name)
        machine = self.space.machine
        if backward_id not in self.backward:
            self.backward[backward_id] = (dict(goal_spec), backward_potential(self.space, goal_mask(machine, goal_spec)))
        stored_goal, potential = self.backward[backward_id]
        if stored_goal != dict(goal_spec):
            raise ValueError(f"backward potential {backward_id} was built for a different goal")
        way = waypoint_mask(machine, waypoint)
        total = np.where(
            way & (self.forward < INF) & (potential < INF),
            self.forward + potential,
            INF,
        )
        best = int(total.min())
        if best >= INF:
            query = {
                "name": name,
                "goal": dict(goal_spec),
                "through": {"backward": backward_id, "waypoint": dict(waypoint)},
                "claim": {"status": "impossible", "cost": None},
                "witness": [],
            }
        else:
            state = int(np.argmin(total))
            program = forward_witness(self.space, self._parent_state, self._parent_instr, state)
            program += backward_witness(self.space, potential, state)
            query = {
                "name": name,
                "goal": dict(goal_spec),
                "through": {"backward": backward_id, "waypoint": dict(waypoint)},
                "claim": {"status": "optimal", "cost": best},
                "witness": program,
            }
        self.queries.append(query)
        return query

    def count_cut(self, name: str, goal_spec: Mapping, backward_id: str, slack: int = 0) -> dict:
        self._claim(name)
        machine = self.space.machine
        if backward_id not in self.backward:
            self.backward[backward_id] = (dict(goal_spec), backward_potential(self.space, goal_mask(machine, goal_spec)))
        stored_goal, potential = self.backward[backward_id]
        if stored_goal != dict(goal_spec):
            raise ValueError(f"backward potential {backward_id} was built for a different goal")
        floor = int(potential[self.space.init])
        if floor >= INF:
            raise ValueError(f"{name}: no program reaches this goal, so there is nothing to count")
        budget = floor + slack
        drops = instruction_drops(self.space, self.forward, potential, budget)
        families: dict[str, int] = {}
        for ins, drop in zip(self.space.instructions, drops):
            if drop is not None:
                op = ins.name.split()[0]
                families[op] = max(families.get(op, drop), drop)
        widest = max((d for d in drops if d is not None), default=0)
        cut = {
            "name": name,
            "potential": backward_id,
            "budget": budget,
            "floor": floor,
            "drops": drops,
            "usable_families": sorted(families),
            "length_at_least": math.ceil(floor / widest) if widest > 0 else None,
        }
        self.cuts.append(cut)
        return cut

    def as_json(self) -> dict:
        space = self.space
        return {
            "format": "kelana-finite-machine-certificate/1",
            "experiment": self.experiment,
            "note": self.note,
            "machine": space.machine.as_json(),
            "grammar": {
                "id": space.grammar_id,
                "note": GRAMMAR_NOTES[space.grammar_id],
                "instructions": [
                    {"name": ins.name, "charge": ins.charge, "table": list(ins.table)} for ins in space.instructions
                ],
            },
            "forward": encode_potential(self.forward),
            "backward": [
                {"id": key, "goal": goal, **encode_potential(values)}
                for key, (goal, values) in sorted(self.backward.items())
            ],
            "queries": self.queries,
            "cuts": self.cuts,
        }

    def write(self, path) -> None:
        with open(path, "w") as handle:
            json.dump(self.as_json(), handle, separators=(",", ":"))
            handle.write("\n")


def observation_census(space: Space, forward: np.ndarray, observe: int = 0) -> dict[tuple[int, ...], int]:
    """Cheapest cost of every exactly observable function, in one pass over the reachable set."""
    machine = space.machine
    reachable = np.flatnonzero(forward < INF)
    views = [
        ((np.arange(machine.semantic_count, dtype=np.int64)[reachable] // machine.state_count**i) % machine.state_count
         >> (observe * machine.width)) & machine.mask
        for i in range(machine.inputs)
    ]
    key = np.zeros(reachable.size, dtype=np.int64)
    for view in reversed(views):
        key = key * (1 << machine.width) + view
    costs = forward[reachable]
    order = np.lexsort((costs, key))
    key, costs = key[order], costs[order]
    first = np.concatenate(([True], key[1:] != key[:-1]))
    out = {}
    radix = 1 << machine.width
    for packed, cost in zip(key[first], costs[first]):
        packed = int(packed)
        signature = tuple((packed // radix**i) % radix for i in range(machine.inputs))
        out[signature] = int(cost)
    return out
