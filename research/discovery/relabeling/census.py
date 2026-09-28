"""Exhaustive census of small labelled families, counted up to relabeling.

The question the census answers is quantitative: how often does knowing that
every operation is *separately* conjugate tell you that the *family* is
simultaneously conjugate?  The answer is obtained by exact orbit counting, not
by sampling.

Method.  Two families ``(f_1..f_k)`` and ``(g_1..g_k)`` are simultaneously
conjugate exactly when they lie in one orbit of ``S_n`` acting by
``p . (f_1..f_k) = (p f_1 p^-1, .., p f_k p^-1)``.  So:

* orbits are enumerated by fixing ``f_1`` at a canonical point of its own orbit
  and then canonicalising the remaining operations under the centraliser of
  ``f_1``, which is exactly the stabiliser of that point;
* two distinct orbits whose per-operation invariants agree are a *separation*:
  each operation is separately conjugate, the family is not;
* two distinct orbits whose full necessary-screen signature agrees witness the
  incompleteness of those screens.

Every count below is a complete enumeration of its stated domain.  No count is
an instruction cost.
"""

from __future__ import annotations

import json
import time
from collections import defaultdict
from itertools import permutations, product
from pathlib import Path

from relabeling import (
    Family,
    automorphisms,
    canonical_refinement,
    commutation_matrix,
    functional_graph_signature,
    orbit_signature,
    pair_refinement,
    preimage_profile,
    shortest_distinguishing_word,
    simultaneous,
    word_profile,
)

#: Word length used for the census screen signature.  Declared, not adaptive.
SCREEN_DEPTH = 2


def all_functions(n: int):
    return list(product(range(n), repeat=n))


def all_permutations(n: int):
    return list(permutations(range(n)))


def conjugate_table(p: tuple[int, ...], table: tuple[int, ...]) -> tuple[int, ...]:
    """``p f p^-1``: the table seen after relabeling state ``x`` as ``p[x]``."""
    out = [0] * len(table)
    for x, y in enumerate(table):
        out[p[x]] = p[y]
    return tuple(out)


def single_op_orbits(pool, n: int):
    """Canonical representatives of the ``S_n`` orbits of one transition."""
    group = all_permutations(n)
    seen = {}
    for table in pool:
        key = min(conjugate_table(p, table) for p in group)
        if key not in seen:
            seen[key] = key
    return sorted(seen)


def centraliser(table: tuple[int, ...], n: int) -> list[tuple[int, ...]]:
    """Permutations commuting with one transition: the stabiliser of that point."""
    auts, capped = automorphisms(Family(n, (("f", table),)), limit=100000)
    if capped:
        raise RuntimeError("centraliser enumeration hit its cap")
    return auts


def family_orbits(n: int, k: int, pool):
    """Every ``S_n`` orbit of ``k``-operation families, one representative each."""
    reps = single_op_orbits(pool, n)
    orbits = []
    for first in reps:
        group = centraliser(first, n)
        seen = set()
        for rest in product(pool, repeat=k - 1):
            key = min(tuple(conjugate_table(p, t) for t in rest) for p in group)
            if key in seen:
                continue
            seen.add(key)
            orbits.append((first,) + key)
    return orbits


def make_family(tables) -> Family:
    return Family(len(tables[0]), tuple((chr(ord("a") + i), t) for i, t in enumerate(tables)))


def per_operation_signature(tables) -> tuple:
    """What "each operation is separately conjugate" means, as one key."""
    return tuple(functional_graph_signature(t) for t in tables)


def screen_signature(tables, depth: int = SCREEN_DEPTH) -> tuple:
    """Every necessary condition the tool checks, folded into one key."""
    family = make_family(tables)
    return (
        per_operation_signature(tables),
        commutation_matrix(family),
        orbit_signature(family),
        tuple(sorted(word_profile(family, depth).items())),
        canonical_refinement(family),
        pair_refinement(family),
    )


def census(n: int, k: int, kind: str) -> dict:
    pool = all_permutations(n) if kind == "permutations" else all_functions(n)
    started = time.time()
    orbits = family_orbits(n, k, pool)
    by_operation: dict[tuple, list] = defaultdict(list)
    by_screen: dict[tuple, list] = defaultdict(list)
    for tables in orbits:
        by_operation[per_operation_signature(tables)].append(tables)
        by_screen[screen_signature(tables)].append(tables)

    separating = {key: group for key, group in by_operation.items() if len(group) > 1}
    screen_gap = {key: group for key, group in by_screen.items() if len(group) > 1}

    # smallest witnesses, chosen deterministically
    def pick(groups):
        if not groups:
            return None
        key = min(groups, key=lambda key: (len(groups[key]), sorted(groups[key])[0]))
        chosen = sorted(groups[key])[:2]
        return chosen

    separation_witness = pick(separating)
    screen_witness = pick(screen_gap)

    separated_orbits = sum(len(group) for group in separating.values())
    screen_orbits = sum(len(group) for group in screen_gap.values())

    result = {
        "states": n,
        "operations": k,
        "transition_kind": kind,
        "families_total": len(pool) ** k,
        "orbits": len(orbits),
        "per_operation_classes": len(by_operation),
        "orbits_sharing_a_per_operation_class": separated_orbits,
        "separation_rate": round(separated_orbits / len(orbits), 6) if orbits else None,
        "largest_per_operation_class": max((len(g) for g in by_operation.values()), default=0),
        "screen_classes": len(by_screen),
        "orbits_sharing_a_screen_class": screen_orbits,
        "screen_incompleteness_rate": round(screen_orbits / len(orbits), 6) if orbits else None,
        "largest_screen_class": max((len(g) for g in by_screen.values()), default=0),
        "screen_depth": SCREEN_DEPTH,
        "seconds": round(time.time() - started, 2),
    }
    if separation_witness:
        result["separation_witness"] = {
            "source": [list(t) for t in separation_witness[0]],
            "target": [list(t) for t in separation_witness[1]],
        }
    if screen_witness:
        result["screen_incompleteness_witness"] = {
            "source": [list(t) for t in screen_witness[0]],
            "target": [list(t) for t in screen_witness[1]],
        }
    return result


def word_signature(tables, depth: int) -> tuple:
    """Only what invariants of the composite maps can see.

    Separate from `screen_signature` on purpose.  The question this answers is
    how deep a *behavioural* screen has to look -- one that inspects composite
    maps and nothing about how states sit relative to each other.  The
    relational screens are strictly stronger and are measured separately.
    """
    family = make_family(tables)
    return (
        per_operation_signature(tables),
        commutation_matrix(family),
        tuple(sorted(word_profile(family, depth).items())),
    )


def word_depth_sweep(n: int, k: int, kind: str, depths=(1, 2, 3, 4, 5, 6)) -> dict:
    """How deep a word-only screen must look before it separates everything."""
    pool = all_permutations(n) if kind == "permutations" else all_functions(n)
    orbits = family_orbits(n, k, pool)
    out = {"states": n, "operations": k, "transition_kind": kind, "orbits": len(orbits),
           "screen": "composite-word invariants only"}
    survivors = {}
    for depth in depths:
        buckets: dict[tuple, list] = defaultdict(list)
        for tables in orbits:
            buckets[word_signature(tables, depth)].append(tables)
        tied = {key: group for key, group in buckets.items() if len(group) > 1}
        survivors[depth] = sum(len(group) for group in tied.values())
        if tied:
            chosen = sorted(min(tied.values(), key=lambda g: sorted(g)[0]))[:2]
            out[f"witness_depth_{depth}"] = {
                "source": [list(t) for t in chosen[0]],
                "target": [list(t) for t in chosen[1]],
            }
    out["orbits_tied_by_depth"] = survivors
    out["deepest_tie"] = max((d for d, c in survivors.items() if c), default=0)
    return out


def depth_sweep(n: int, k: int, kind: str, depths=(1, 2, 3, 4, 5, 6)) -> dict:
    """How deep must the word screen look before it separates everything?

    For each depth, count the orbits that still share a screen signature with a
    different orbit.  A non-zero count at depth ``L`` is a pair of families
    agreeing on the invariant of every composite word of length at most ``L``
    and still not simultaneously conjugate.
    """
    pool = all_permutations(n) if kind == "permutations" else all_functions(n)
    orbits = family_orbits(n, k, pool)
    out = {"states": n, "operations": k, "transition_kind": kind, "orbits": len(orbits)}
    survivors = {}
    for depth in depths:
        buckets: dict[tuple, list] = defaultdict(list)
        for tables in orbits:
            buckets[screen_signature(tables, depth)].append(tables)
        tied = {key: group for key, group in buckets.items() if len(group) > 1}
        count = sum(len(group) for group in tied.values())
        survivors[depth] = count
        if tied:
            chosen = sorted(min(tied.values(), key=lambda g: sorted(g)[0]))[:2]
            out[f"witness_depth_{depth}"] = {
                "source": [list(t) for t in chosen[0]],
                "target": [list(t) for t in chosen[1]],
            }
    out["orbits_tied_by_depth"] = survivors
    out["deepest_tie"] = max((d for d, c in survivors.items() if c), default=0)
    return out


SWEEP_PLAN = [
    (5, 2, "permutations"),
    (6, 2, "permutations"),
    (4, 2, "functions"),
    (3, 3, "permutations"),
]

PLAN = [
    (3, 2, "functions"),
    (4, 2, "functions"),
    (5, 2, "functions"),
    (3, 2, "permutations"),
    (4, 2, "permutations"),
    (5, 2, "permutations"),
    (6, 2, "permutations"),
    (3, 3, "permutations"),
    (4, 3, "permutations"),
    (3, 3, "functions"),
]


def verify(entry: dict) -> dict:
    """Recheck each reported witness with the independent conjugacy decision."""
    checks = {}
    for name, key in (
        ("separation", "separation_witness"),
        ("screen_incompleteness", "screen_incompleteness_witness"),
    ):
        pair = entry.get(key)
        if not pair:
            continue
        source = make_family([tuple(t) for t in pair["source"]])
        target = make_family([tuple(t) for t in pair["target"]])
        verdict = simultaneous(source, target)
        per_op_equal = per_operation_signature(source.tables) == per_operation_signature(
            target.tables
        )
        checks[name] = {
            "simultaneously_conjugate": verdict.conjugate,
            "per_operation_invariants_agree": per_op_equal,
            "obstruction": verdict.obstruction,
        }
        if name == "screen_incompleteness":
            checks[name]["screen_signatures_agree"] = screen_signature(
                source.tables
            ) == screen_signature(target.tables)
            checks[name]["collision_cardinalities_agree"] = [
                list(preimage_profile(t)) for t in source.tables
            ] == [list(preimage_profile(t)) for t in target.tables]
    return checks


def _load() -> dict:
    path = Path(__file__).with_name("census.json")
    if path.exists():
        return json.loads(path.read_text())
    return {}


def _save(data: dict) -> Path:
    path = Path(__file__).with_name("census.json")
    data["screen_depth"] = SCREEN_DEPTH
    path.write_text(json.dumps(data, indent=2) + "\n")
    return path


def main(argv: list[str]) -> None:
    """Run one section at a time.

    The full census exceeds a single bounded run, so each section writes its own
    part of `census.json` and leaves the others alone.  `python3 census.py`
    lists the sections; `python3 census.py all` runs every one in order.
    """
    sections = {
        "orbits": "exhaustive orbit counts and separation rates",
        "sweeps": "how deep the full screen battery must look",
        "words": "how deep a composite-word-only screen must look",
    }
    wanted = argv[1:] or []
    if not wanted:
        print("sections:")
        for name, what in sections.items():
            print(f"  {name:8s} {what}")
        print("\n  all      every section, which takes a few minutes")
        return
    if wanted == ["all"]:
        wanted = list(sections)
    unknown = [name for name in wanted if name not in sections]
    if unknown:
        raise SystemExit(f"unknown section(s): {', '.join(unknown)}")

    data = _load()
    if "orbits" in wanted:
        entries = []
        for n, k, kind in PLAN:
            entry = census(n, k, kind)
            entry["witness_checks"] = verify(entry)
            entries.append(entry)
            print(
                f"n={n} k={k} {kind:13s} orbits={entry['orbits']:6d} "
                f"per-op classes={entry['per_operation_classes']:6d} "
                f"separating orbits={entry['orbits_sharing_a_per_operation_class']:6d} "
                f"screen-tied orbits={entry['orbits_sharing_a_screen_class']:5d} "
                f"({entry['seconds']}s)"
            )
        data["entries"] = entries
    if "sweeps" in wanted:
        sweeps = []
        for n, k, kind in SWEEP_PLAN:
            sweep = depth_sweep(n, k, kind)
            sweeps.append(sweep)
            print(
                f"full screen n={n} k={k} {kind:13s} "
                f"tied orbits by depth: {sweep['orbits_tied_by_depth']}"
            )
        data["depth_sweeps"] = sweeps
    if "words" in wanted:
        word_sweeps = []
        for n, k, kind in SWEEP_PLAN:
            sweep = word_depth_sweep(n, k, kind)
            word_sweeps.append(sweep)
            print(
                f"word only   n={n} k={k} {kind:13s} "
                f"tied orbits by depth: {sweep['orbits_tied_by_depth']}"
            )
        data["word_only_depth_sweeps"] = word_sweeps
    print(f"\nwrote {_save(data)}")


if __name__ == "__main__":
    import sys

    main(sys.argv)
