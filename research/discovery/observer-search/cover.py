"""An exact information relaxation: choose an additive-cost menu of carriers.

Joint sufficiency is weighted set cover over input pairs distinguished by the
required output. This does not price the decoder or model shared computation.
"""
from dataclasses import dataclass
from heapq import heappop, heappush
from itertools import count
from typing import Hashable, Sequence


@dataclass(frozen=True)
class Feature:
    name: str
    values: tuple[Hashable, ...]
    cost: int

    def __post_init__(self):
        if not self.name or type(self.cost) is not int or self.cost <= 0:
            raise ValueError("features need names and positive integer costs")
        object.__setattr__(self, "values", tuple(self.values))
        for v in self.values:
            hash(v)


@dataclass(frozen=True)
class CoverResult:
    status: str
    features: tuple[str, ...] | None
    cost: int | None
    required_pairs: int
    states_seen: int
    unresolved_pair: tuple[int, int] | None = None


def minimum_cover(target: Sequence[Hashable], features: Sequence[Feature],
                  max_states: int = 100_000) -> CoverResult:
    """Find a cheapest jointly sufficient feature set in this additive menu.

    Exact minimum for this information objective when status is found. It is
    neither a minimum ISA program nor an optimal choice after decoder pricing.
    """
    if type(max_states) is not int or max_states < 1:
        raise ValueError("invalid state limit")
    n = len(target)
    if len({f.name for f in features}) != len(features):
        raise ValueError("feature names must be unique")
    if any(len(f.values) != n for f in features):
        raise ValueError("all features must cover the target's input domain")
    pairs = [(i, j) for i in range(n) for j in range(i + 1, n) if target[i] != target[j]]
    masks = [sum(1 << k for k, (i, j) in enumerate(pairs) if f.values[i] != f.values[j])
             for f in features]
    goal = (1 << len(pairs)) - 1
    available = 0
    for mask in masks:
        available |= mask
    if available != goal:
        missing = goal ^ available
        k = (missing & -missing).bit_length() - 1
        return CoverResult("insufficient_menu", None, None, len(pairs), 1, pairs[k])
    serial = count()
    queue = [(0, next(serial), 0)]
    best = {0: 0}
    parent = {0: None}
    while queue:
        cost, _, covered = heappop(queue)
        if best[covered] != cost:
            continue
        if covered == goal:
            chosen = []
            while parent[covered] is not None:
                covered, name = parent[covered]
                chosen.append(name)
            return CoverResult("found", tuple(reversed(chosen)), cost, len(pairs), len(best))
        for f, mask in zip(features, masks):
            nxt = covered | mask
            new_cost = cost + f.cost
            if new_cost < best.get(nxt, new_cost + 1):
                if nxt not in best and len(best) >= max_states:
                    return CoverResult("state_limit", None, None, len(pairs), len(best))
                best[nxt] = new_cost
                parent[nxt] = (covered, f.name)
                heappush(queue, (new_cost, next(serial), nxt))
    raise AssertionError("the complete menu was sufficient but its union was unreachable")
