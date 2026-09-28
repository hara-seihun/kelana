"""Two-lane accumulator toy: a representation change that loses locally and wins over a chain.

Two nonnegative accumulators start at an unknown state with one bit per lane, x0 and y0 in
{0,1}, supplied as input. Each stage adds one digit pair from {0,1,2}^2. The packed
representation stores both accumulators in one byte as x + 16*y, so a single byte add
advances both lanes. The lanes stay independent only while neither exceeds 15, which bounds
how long a packed run may be: after n stages a lane can hold 1 + 2n.

The cost model is synthetic. The enter and exit charges are gateway charges for changing
representation, not instruction counts.
"""

from __future__ import annotations

import heapq
from dataclasses import dataclass, replace

DIGITS = (0, 1, 2)
DIGIT_PAIRS = tuple((a, b) for a in DIGITS for b in DIGITS)
MAX_DIGIT = max(DIGITS)

INITIAL_BITS = (0, 1)
UNKNOWN_INITIAL = frozenset((x, y) for x in INITIAL_BITS for y in INITIAL_BITS)
ZERO_INITIAL = frozenset({(0, 0)})

LANE_BITS = 4
LANE_BASE = 1 << LANE_BITS
LANE_MAX = LANE_BASE - 1
BYTE_MAX = 255

State = tuple[int, int]
Digits = tuple[int, int]


def ordinary_step(state: State, digits: Digits) -> State:
    return (state[0] + digits[0], state[1] + digits[1])


def encodable(state: State) -> bool:
    return 0 <= state[0] <= LANE_MAX and 0 <= state[1] <= LANE_MAX


def encode(state: State) -> int:
    if not encodable(state):
        raise ValueError(f"state {state} does not fit two nibbles")
    return state[0] + LANE_BASE * state[1]


def decode(byte: int) -> State:
    return (byte % LANE_BASE, byte // LANE_BASE)


def packed_step(byte: int, digits: Digits) -> int:
    return (byte + digits[0] + LANE_BASE * digits[1]) & BYTE_MAX


def run_ordinary(initial: State, sequence: tuple[Digits, ...]) -> State:
    state = initial
    for digits in sequence:
        state = ordinary_step(state, digits)
    return state


def run_packed(initial: State, sequence: tuple[Digits, ...]) -> int:
    byte = encode(initial)
    for digits in sequence:
        byte = packed_step(byte, digits)
    return byte


@dataclass(frozen=True)
class Witness:
    """An input that drives the chain to a state: the initial state and the digits after it."""

    initial: State
    digits: tuple[Digits, ...]

    def extend(self, digits: Digits) -> "Witness":
        return Witness(self.initial, self.digits + (digits,))

    def as_json(self) -> dict:
        return {"initial_state": list(self.initial), "digits": [list(d) for d in self.digits]}


@dataclass(frozen=True)
class CostModel:
    """Synthetic charges. Dynamic digits and their packed form are common inputs."""

    ordinary_stage: int = 2
    packed_stage: int = 1
    enter: int = 3
    exit: int = 3
    fold_constant_entry: bool = False

    def enter_cost(self, entry_states: frozenset[State]) -> int:
        """A constant entry state can be folded; an unknown one has to be packed at runtime."""
        if self.fold_constant_entry and len(entry_states) == 1:
            return 0
        return self.enter


def folding(cost: CostModel) -> CostModel:
    return replace(cost, fold_constant_entry=True)


# Reachability


@dataclass(frozen=True)
class Reachable:
    """Per-stage reachable states with one witness input each."""

    levels: tuple[dict[State, Witness], ...]

    def states(self, stage: int) -> frozenset[State]:
        return frozenset(self.levels[stage])

    def witness(self, stage: int, state: State) -> Witness:
        return self.levels[stage][state]

    def max_lane(self, stage: int) -> int:
        return max(max(state) for state in self.levels[stage])


def reachable(stages: int, initial: frozenset[State] = UNKNOWN_INITIAL) -> Reachable:
    levels: list[dict[State, Witness]] = [{state: Witness(state, ()) for state in sorted(initial)}]
    for _ in range(stages):
        nxt: dict[State, Witness] = {}
        for state, witness in levels[-1].items():
            for digits in DIGIT_PAIRS:
                successor = ordinary_step(state, digits)
                if successor not in nxt:
                    nxt[successor] = witness.extend(digits)
        levels.append(nxt)
    return Reachable(tuple(levels))


# Representation validity, checked as a precondition on each edge


@dataclass(frozen=True)
class Validity:
    ok: bool
    reason: str = ""
    state: State | None = None
    digits: Digits | None = None
    witness: Witness | None = None

    @property
    def counterexample(self) -> Witness | None:
        if self.ok or self.witness is None:
            return None
        return self.witness if self.digits is None else self.witness.extend(self.digits)


def enter_valid(reach: Reachable, stage: int) -> Validity:
    for state, witness in sorted(reach.levels[stage].items()):
        if not encodable(state):
            return Validity(False, "state does not fit two nibbles", state, None, witness)
    return Validity(True)


def packed_stage_valid(reach: Reachable, stage: int) -> Validity:
    """Is a packed stage from `stage` to `stage + 1` exact for every reachable input?"""
    for state, witness in sorted(reach.levels[stage].items()):
        if not encodable(state):
            return Validity(False, "entry state does not fit two nibbles", state, None, witness)
        for digits in DIGIT_PAIRS:
            successor = ordinary_step(state, digits)
            if successor[0] > LANE_MAX:
                return Validity(False, "low lane carries into the high lane", state, digits, witness)
            if successor[1] > LANE_MAX:
                return Validity(False, "high lane leaves the byte", state, digits, witness)
    return Validity(True)


def max_packed_run(reach: Reachable, stage: int) -> int:
    """How many consecutive packed stages stay valid for every input, starting at `stage`."""
    run = 0
    while stage + run < len(reach.levels) - 1 and packed_stage_valid(reach, stage + run).ok:
        run += 1
    return run


# Plans and search


@dataclass(frozen=True)
class Edge:
    kind: str
    stage: int
    cost: int


@dataclass(frozen=True)
class Plan:
    edges: tuple[Edge, ...]
    cost: int

    @property
    def packed_stages(self) -> int:
        return sum(1 for edge in self.edges if edge.kind == PACKED)

    @property
    def packed_runs(self) -> tuple[tuple[int, int], ...]:
        runs: list[tuple[int, int]] = []
        for edge in self.edges:
            if edge.kind != PACKED:
                continue
            if runs and runs[-1][1] == edge.stage:
                runs[-1] = (runs[-1][0], edge.stage + 1)
            else:
                runs.append((edge.stage, edge.stage + 1))
        return tuple(runs)

    def describe(self) -> str:
        groups: list[list] = []
        for edge in self.edges:
            if groups and groups[-1][0] == edge.kind:
                groups[-1][1] += 1
            else:
                groups.append([edge.kind, 1, edge.stage])
        return " -> ".join(
            f"{kind}@{stage}" if count == 1 else f"{kind}x{count}@{stage}"
            for kind, count, stage in groups
        )


ORDINARY, PACKED = "ordinary", "packed"


def search(
    stages: int,
    cost: CostModel,
    *,
    initial: frozenset[State] = UNKNOWN_INITIAL,
    enforce_validity: bool = True,
) -> Plan:
    """Cheapest chain from ordinary state at stage 0 to ordinary state at stage `stages`.

    Node = (stage, representation). Validity is a precondition on packed and enter edges,
    independent of their cost; disabling it is what lets an invalid plan look cheapest.
    Equal costs are broken toward fewer representation changes, so a plan that merely ties
    with ordinary lowering is not reported as a reason to change representation.
    """
    reach = reachable(stages, initial)
    start, goal = (0, ORDINARY), (stages, ORDINARY)
    dist: dict[tuple[int, str], tuple[int, int]] = {start: (0, 0)}
    prev: dict[tuple[int, str], tuple[tuple[int, str], Edge]] = {}
    queue = [((0, 0), start)]

    while queue:
        (spent, switches), node = heapq.heappop(queue)
        if (spent, switches) > dist.get(node, (spent, switches)):
            continue
        if node == goal:
            break
        stage, rep = node
        moves: list[tuple[tuple[int, str], Edge]] = []
        if stage < stages:
            if rep == ORDINARY:
                moves.append(((stage + 1, ORDINARY), Edge(ORDINARY, stage, cost.ordinary_stage)))
            elif not enforce_validity or packed_stage_valid(reach, stage).ok:
                moves.append(((stage + 1, PACKED), Edge(PACKED, stage, cost.packed_stage)))
        if rep == ORDINARY and (not enforce_validity or enter_valid(reach, stage).ok):
            charge = cost.enter_cost(reach.states(stage))
            moves.append(((stage, PACKED), Edge("enter", stage, charge)))
        if rep == PACKED:
            moves.append(((stage, ORDINARY), Edge("exit", stage, cost.exit)))
        for successor, edge in moves:
            candidate = (spent + edge.cost, switches + (edge.kind in ("enter", "exit")))
            known = dist.get(successor)
            if known is None or candidate < known:
                dist[successor] = candidate
                prev[successor] = (node, edge)
                heapq.heappush(queue, (candidate, successor))

    edges: list[Edge] = []
    node = goal
    while node != start:
        node, edge = prev[node]
        edges.append(edge)
    edges.reverse()
    return Plan(tuple(edges), dist[goal][0])


def all_ordinary(stages: int, cost: CostModel) -> Plan:
    edges = tuple(Edge(ORDINARY, stage, cost.ordinary_stage) for stage in range(stages))
    return Plan(edges, stages * cost.ordinary_stage)


def fully_packed(
    stages: int, cost: CostModel, initial: frozenset[State] = UNKNOWN_INITIAL
) -> Plan:
    edges = (
        (Edge("enter", 0, cost.enter_cost(initial)),)
        + tuple(Edge(PACKED, stage, cost.packed_stage) for stage in range(stages))
        + (Edge("exit", stages, cost.exit),)
    )
    return Plan(edges, sum(edge.cost for edge in edges))


def greedy(
    stages: int,
    cost: CostModel,
    horizon: int = 1,
    initial: frozenset[State] = UNKNOWN_INITIAL,
) -> Plan:
    """Local lowering: at each stage compare the next `horizon` stages only.

    Entering must pay for itself inside the horizon, including the exit that returning
    to ordinary form requires, because the pass cannot see past it.
    """
    reach = reachable(stages, initial)
    edges: list[Edge] = []
    stage = 0
    while stage < stages:
        window = min(horizon, stages - stage)
        stay = window * cost.ordinary_stage
        run = min(window, max_packed_run(reach, stage))
        entry = cost.enter_cost(reach.states(stage))
        switch = (
            entry + run * cost.packed_stage + cost.exit + (window - run) * cost.ordinary_stage
            if enter_valid(reach, stage).ok and run > 0
            else None
        )
        if switch is not None and switch < stay:
            edges.append(Edge("enter", stage, entry))
            for offset in range(run):
                edges.append(Edge(PACKED, stage + offset, cost.packed_stage))
            edges.append(Edge("exit", stage + run, cost.exit))
            stage += run
        else:
            edges.append(Edge(ORDINARY, stage, cost.ordinary_stage))
            stage += 1
    return Plan(tuple(edges), sum(edge.cost for edge in edges))


def greedy_entry_horizon(
    stages: int, cost: CostModel, initial: frozenset[State] = UNKNOWN_INITIAL, limit: int = 32
) -> int | None:
    """Smallest lookahead at which local lowering enters the packed representation."""
    for horizon in range(1, limit + 1):
        if greedy(stages, cost, horizon, initial).packed_stages > 0:
            return horizon
    return None


def first_winning_length(
    cost: CostModel, initial: frozenset[State] = UNKNOWN_INITIAL, limit: int = 24
) -> int | None:
    for stages in range(1, limit + 1):
        if search(stages, cost, initial=initial).cost < all_ordinary(stages, cost).cost:
            return stages
    return None


# Exactness of the packed stage, checked over reachable states rather than input sequences


@dataclass(frozen=True)
class ExactnessReport:
    stages_checked: int
    state_digit_pairs: int
    first_failure_stage: int | None
    failure: Validity | None


def check_packed_exactness(
    stages: int, initial: frozenset[State] = UNKNOWN_INITIAL
) -> ExactnessReport:
    reach = reachable(stages, initial)
    checked = 0
    for stage in range(stages):
        verdict = packed_stage_valid(reach, stage)
        if not verdict.ok:
            return ExactnessReport(stage, checked, stage, verdict)
        for state in reach.levels[stage]:
            for digits in DIGIT_PAIRS:
                if decode(packed_step(encode(state), digits)) != ordinary_step(state, digits):
                    raise AssertionError(f"valid packed stage disagreed at {state} + {digits}")
                checked += 1
    return ExactnessReport(stages, checked, None, None)


def lane_overflow_counts(
    stages: int, initial_values: tuple[int, ...] = INITIAL_BITS
) -> tuple[int, int]:
    """Lane inputs whose running sum leaves a nibble, by sum DP over one lane."""
    sums = [0] * (max(initial_values) + 1)
    for value in initial_values:
        sums[value] += 1
    for _ in range(stages):
        nxt = [0] * (len(sums) + MAX_DIGIT)
        for total, ways in enumerate(sums):
            for digit in DIGITS:
                nxt[total + digit] += ways
        sums = nxt
    overflow = sum(ways for total, ways in enumerate(sums) if total > LANE_MAX)
    return overflow, sum(sums)


def breaking_sequence_count(
    stages: int, initial_values: tuple[int, ...] = INITIAL_BITS
) -> tuple[int, int]:
    """Count length-`stages` inputs whose fully packed run misdecodes. Lanes are independent."""
    overflow, total = lane_overflow_counts(stages, initial_values)
    return 2 * overflow * total - overflow * overflow, total * total
