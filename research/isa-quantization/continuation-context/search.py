#!/usr/bin/env python3
"""Tiny exact residual-program quotient with union-paid static identities."""
import itertools
import json
from pathlib import Path

IDENTITIES = ("a", "b")
SUFFIXES = ("bit", "zero")
STATES = tuple(range(4))
PAID = tuple(frozenset(p) for n in range(3) for p in itertools.combinations(IDENTITIES, n))
NODES = tuple((s, paid) for s in STATES for paid in PAID)


def outcome(node, suffix):
    state, paid = node
    if suffix == "bit":
        return (state % 2, 1 - state % 2), len(paid | {"a"}), 1
    return (0, 0), len(paid), 2


def simulates(a, b):
    return all(any(x[0] == y[0] and x[1] <= y[1] and x[2] <= y[2]
                   for x in (outcome(a, v) for v in SUFFIXES))
               for y in (outcome(b, u) for u in SUFFIXES))


def frontier(node, teacher):
    candidates = [(sum(x != y for x, y in zip(outcome(node, u)[0], teacher)),
                   *outcome(node, u)[1:]) for u in SUFFIXES]
    return sorted({p for p in candidates if not any(
        q != p and all(x <= y for x, y in zip(q, p)) for q in candidates)})


def main():
    classes = []
    for node in NODES:
        for cls in classes:
            if simulates(node, cls[0]) and simulates(cls[0], node):
                cls.append(node)
                break
        else:
            classes.append([node])
    for cls in classes:
        for a, b in itertools.product(cls, repeat=2):
            assert all(frontier(a, t) == frontier(b, t)
                       for t in itertools.product(range(2), repeat=2))
    assert simulates((0, frozenset({"a"})), (2, frozenset({"a"})))
    assert not simulates((0, frozenset({"b"})), (0, frozenset({"a"})))
    assert outcome((0, frozenset({"a"})), "bit")[1] == 1
    assert outcome((0, frozenset({"b"})), "bit")[1] == 2
    result = {
        "domain": "states 0..3; paid subsets of a,b; two-input response maps",
        "suffixes": {"bit": "response (parity,1-parity), pays/reuses a, work 1",
                     "zero": "response (0,0), no static use, work 2"},
        "nodes": len(NODES), "mutual_simulation_classes": len(classes),
        "classes": [[{"state": s, "paid": sorted(p)} for s, p in cls] for cls in classes],
        "checked_teachers": 4,
    }
    path = Path(__file__).with_name("results.json")
    path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: result[k] for k in ("nodes", "mutual_simulation_classes", "checked_teachers")}))


if __name__ == "__main__":
    main()
