"""Exact finite observer questions, kept separate from implementation cost.

States are integers indexing an explicitly supplied finite domain. Numeric state
labels are retained during program search; only information queries use fibers.
"""
from collections import deque
from dataclasses import dataclass
from heapq import heappop, heappush
from itertools import count
from types import MappingProxyType
from typing import Hashable, Mapping, Sequence


def fibers(values: Sequence[Hashable]) -> tuple[int, ...]:
    labels = {}
    return tuple(labels.setdefault(v, len(labels)) for v in values)


@dataclass(frozen=True)
class Collision:
    left: int
    right: int
    carrier_value: Hashable
    left_target: Hashable
    right_target: Hashable


@dataclass(frozen=True)
class Factorization:
    decoder: Mapping[Hashable, Hashable] | None
    collision: Collision | None

    @property
    def sufficient(self) -> bool:
        return self.collision is None


def factor(carrier: Sequence[Hashable], target: Sequence[Hashable]) -> Factorization:
    """Construct a semantic decoder on the reachable image, or a collision.

    No instruction cost is assigned to this arbitrary finite table.
    """
    if len(carrier) != len(target):
        raise ValueError("carrier and target must cover the same input domain")
    seen = {}
    decoder = {}
    for i, (c, t) in enumerate(zip(carrier, target)):
        if c in decoder and decoder[c] != t:
            j = seen[c]
            return Factorization(None, Collision(j, i, c, target[j], t))
        decoder[c] = t
        seen.setdefault(c, i)
    return Factorization(MappingProxyType(decoder), None)


@dataclass(frozen=True)
class Machine:
    observation: tuple[Hashable, ...]
    transitions: Mapping[str, tuple[int, ...]]

    def __post_init__(self):
        observation = tuple(self.observation)
        transitions = {name: tuple(table) for name, table in self.transitions.items()}
        n = len(observation)
        if not n:
            raise ValueError("a machine must have at least one state")
        for name, table in transitions.items():
            if not isinstance(name, str) or not name:
                raise ValueError("transition names must be nonempty strings")
            if len(table) != n or any(type(s) is not int or not 0 <= s < n for s in table):
                raise ValueError(f"{name}: transition must be total and stay in the state domain")
        fibers(observation)  # Observations must be hashable.
        object.__setattr__(self, "observation", observation)
        object.__setattr__(self, "transitions", MappingProxyType(transitions))

    def after(self, state: int, word: Sequence[str]) -> int:
        if type(state) is not int or not 0 <= state < len(self.observation):
            raise ValueError("invalid initial state")
        for name in word:
            state = self.transitions[name][state]
        return state


@dataclass(frozen=True)
class Quotient:
    classes: tuple[int, ...]
    machine: Machine
    refinement_sizes: tuple[int, ...]


def stable_quotient(machine: Machine) -> Quotient:
    """Coarsest observation-respecting quotient closed under every named step.

    Each refinement splits a class if one allowed next instruction can expose a
    distinction. This is NOT a requirement on a fixed whole-region replacement.
    """
    classes = fibers(machine.observation)
    sizes = [len(set(classes))]
    while True:
        refined = fibers(tuple((classes[s], tuple(classes[t[s]] for t in machine.transitions.values()))
                               for s in range(len(classes))))
        if refined == classes:
            break
        classes = refined
        sizes.append(len(set(classes)))
    reps = [classes.index(c) for c in range(max(classes) + 1)]
    quotient = Machine(tuple(machine.observation[s] for s in reps),
                       {name: tuple(classes[table[s]] for s in reps)
                        for name, table in machine.transitions.items()})
    return Quotient(classes, quotient, tuple(sizes))


def distinguishing_word(machine: Machine, left: int, right: int) -> tuple[str, ...] | None:
    """Shortest continuation that distinguishes two states, or None.

    Empty tuple means the current observation already distinguishes them.
    Breadth-first search visits at most n*(n+1)/2 unordered state pairs.
    """
    machine.after(left, ())
    machine.after(right, ())
    start = tuple(sorted((left, right)))
    queue = deque([start])
    parent = {start: None}
    while queue:
        pair = queue.popleft()
        a, b = pair
        if machine.observation[a] != machine.observation[b]:
            word = []
            while parent[pair] is not None:
                pair, name = parent[pair]
                word.append(name)
            return tuple(reversed(word))
        for name, table in machine.transitions.items():
            nxt = tuple(sorted((table[a], table[b])))
            if nxt not in parent:
                parent[nxt] = (pair, name)
                queue.append(nxt)
    return None


def suffix_observations(machine: Machine, word: Sequence[str]) -> tuple[tuple[Hashable, ...], ...]:
    """Final observation of each fixed suffix, at every possible entry state.

    Entry zero is the complete word, entry len(word) is the final observation.
    Distinct reachable domains can be restricted by the caller at each boundary.
    """
    result = [machine.observation]
    for name in reversed(word):
        table = machine.transitions[name]
        result.append(tuple(result[-1][s] for s in table))
    return tuple(reversed(result))


@dataclass(frozen=True)
class Instruction:
    name: str
    table: tuple[int, ...]
    cost: int = 1

    def __post_init__(self):
        table = tuple(self.table)
        if not self.name or type(self.cost) is not int or self.cost <= 0:
            raise ValueError("instruction requires a name and a positive integer cost")
        if not table or any(type(s) is not int or not 0 <= s < len(table) for s in table):
            raise ValueError("instruction must be a total map on its finite register domain")
        object.__setattr__(self, "table", table)


@dataclass(frozen=True)
class SearchResult:
    status: str
    program: tuple[str, ...] | None
    cost: int | None
    states_seen: int
    states_expanded: int


def decoder_search(carrier: Sequence[int], target: Sequence[int], instructions: Sequence[Instruction],
                   max_cost: int, max_states: int = 100_000) -> SearchResult:
    """Dijkstra search for a one-register decoder in the declared grammar.

    Input packing is the caller's contract, not a free operation inferred here.
    Exact labeled truth vectors are the search key. Using fibers instead would
    merge states that the next ISA function acts on differently.
    """
    if len(carrier) != len(target):
        raise ValueError("carrier and target must cover the same input domain")
    if type(max_cost) is not int or max_cost < 0 or type(max_states) is not int or max_states < 1:
        raise ValueError("invalid search bounds")
    if not instructions:
        if tuple(carrier) == tuple(target):
            return SearchResult("found", (), 0, 1, 1)
        return SearchResult("exhausted_bound", None, None, 1, 1)
    n = len(instructions[0].table)
    if any(len(i.table) != n for i in instructions):
        raise ValueError("instructions disagree on register domain")
    if len({i.name for i in instructions}) != len(instructions):
        raise ValueError("instruction names must be unique")
    if any(type(x) is not int or not 0 <= x < n for x in (*carrier, *target)):
        raise ValueError("carrier and target must be values in the register domain")
    start, goal = tuple(carrier), tuple(target)
    serial = count()
    queue = [(0, next(serial), start)]
    best = {start: 0}
    parent = {start: None}
    expanded = 0
    while queue:
        cost, _, state = heappop(queue)
        if best[state] != cost:
            continue
        expanded += 1
        if state == goal:
            program = []
            while parent[state] is not None:
                state, name = parent[state]
                program.append(name)
            return SearchResult("found", tuple(reversed(program)), cost, len(best), expanded)
        for instr in instructions:
            new_cost = cost + instr.cost
            if new_cost > max_cost:
                continue
            nxt = tuple(instr.table[x] for x in state)
            if new_cost < best.get(nxt, new_cost + 1):
                if nxt not in best and len(best) >= max_states:
                    return SearchResult("state_limit", None, None, len(best), expanded)
                best[nxt] = new_cost
                parent[nxt] = (state, instr.name)
                heappush(queue, (new_cost, next(serial), nxt))
    return SearchResult("exhausted_bound", None, None, len(best), expanded)
