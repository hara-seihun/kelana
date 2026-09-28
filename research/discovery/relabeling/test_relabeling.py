#!/usr/bin/env python3
"""Checks for the simultaneous relabeling tools.  Runs in a few seconds.

The important ones are the cross-checks: the fast search against exhaustive
permutation enumeration, and the census orbit counts against Burnside's lemma
computed a completely different way.
"""

from __future__ import annotations

import pathlib
import random
import sys
from itertools import permutations, product
from math import factorial

import census
import fields
from relabeling import (
    BRUTE_FORCE_LIMIT,
    SCREEN_NAMES,
    Family,
    RelabelingError,
    all_witnesses,
    automorphisms,
    bit_permutation,
    brute_force,
    canonical_refinement,
    chain_agrees,
    compose,
    conjugate_in_class,
    conjugates,
    gf2_affine,
    gf2_linear,
    generating_states,
    independent,
    invert,
    modular_affine,
    orbit_partition,
    orbit_signature,
    pair_refinement,
    preimage_profile,
    screens,
    separates,
    shortest_distinguishing_word,
    simultaneous,
    symmetric,
    xor_translation,
)

FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  ok   {name}")
    else:
        FAILURES.append(f"{name}: {detail}")
        print(f"  FAIL {name} {detail}")


def random_family(rng: random.Random, n: int, k: int, bijective: bool) -> Family:
    ops = []
    for index in range(k):
        if bijective:
            table = list(range(n))
            rng.shuffle(table)
        else:
            table = [rng.randrange(n) for _ in range(n)]
        ops.append((chr(ord("a") + index), tuple(table)))
    return Family(n, tuple(ops))


def random_permutation(rng: random.Random, n: int) -> tuple[int, ...]:
    table = list(range(n))
    rng.shuffle(table)
    return tuple(table)


# --------------------------------------------------------------------------


def test_search_against_brute_force() -> None:
    print("search against exhaustive permutation enumeration")
    rng = random.Random(20260915)
    mismatches = 0
    witness_mismatches = 0
    trials = 0
    for n in range(2, BRUTE_FORCE_LIMIT + 1):
        for k in (1, 2, 3):
            for bijective in (True, False):
                for _ in range(40):
                    trials += 1
                    source = random_family(rng, n, k, bijective)
                    if rng.random() < 0.5:
                        target = source.relabel(random_permutation(rng, n))
                    else:
                        target = random_family(rng, n, k, bijective)
                    fast = simultaneous(source, target)
                    slow = brute_force(source, target)
                    if fast.conjugate != (slow is not None):
                        mismatches += 1
                    if fast.witness is not None and not conjugates(
                        fast.witness, source, target
                    ):
                        witness_mismatches += 1
    check(f"{trials} random pairs agree with brute force", mismatches == 0, f"{mismatches} differ")
    check("every returned witness verifies", witness_mismatches == 0)


def test_all_witnesses_complete() -> None:
    print("complete witness enumeration")
    rng = random.Random(7)
    bad = 0
    coset = 0
    for _ in range(120):
        n = rng.randrange(2, 7)
        source = random_family(rng, n, rng.randrange(1, 3), rng.random() < 0.5)
        target = source.relabel(random_permutation(rng, n))
        found, capped = all_witnesses(source, target)
        if capped:
            continue
        exhaustive = brute_force(source, target, all_solutions=True)
        if sorted(found) != sorted(exhaustive):
            bad += 1
        auts, _ = automorphisms(source)
        if len(found) != len(auts):
            coset += 1
        # the coset identity itself: p0 . Aut(source) is exactly the witness set
        if found:
            built = {compose(found[0], a) for a in auts}
            if built != set(found):
                coset += 1
    check("witness sets equal the exhaustive solution sets", bad == 0, f"{bad} differ")
    check("witness set is the coset of the automorphism group", coset == 0, f"{coset} differ")


def test_screens_are_necessary() -> None:
    print("screens never reject a real conjugacy")
    rng = random.Random(99)
    bad = 0
    for _ in range(400):
        n = rng.randrange(2, 8)
        source = random_family(rng, n, rng.randrange(1, 4), rng.random() < 0.5)
        target = source.relabel(random_permutation(rng, n))
        found = screens(source, target)
        if not all(found[name] for name in SCREEN_NAMES):
            bad += 1
    check("every screen passes on a genuinely relabeled family", bad == 0, f"{bad} false rejections")


def test_screens_are_incomplete() -> None:
    print("screens are not sufficient")
    a = (0b010, 0b100, 0b011)
    b = (0b011, 0b111, 0b101)
    source = Family(7, (("a", fields.point_action(a)), ("b", fields.point_action(b))))
    target = Family(7, (("a", fields.plane_action(a)), ("b", fields.plane_action(b))))
    found = screens(source, target)
    behavioural = ("collision_cardinalities", "per_operation_graphs", "commutation",
                   "orbit_structure", "word_profile", "refinement")
    check(
        "GL(3,2) point/plane pair passes every behavioural screen",
        all(found[name] for name in behavioural),
        str({name: found[name] for name in behavioural}),
    )
    check("no word of any length separates them", shortest_distinguishing_word(source, target) is None)
    check(
        "pair refinement does reject it, so the screens are not all equivalent",
        not found["pair_refinement"],
    )
    check("it is not conjugate", not simultaneous(source, target).conjugate)
    check("brute force over 5040 agrees", brute_force(source, target) is None)
    check("both families are transitive", len(orbit_partition(source)) == 1 and len(orbit_partition(target)) == 1)


def test_separation_examples() -> None:
    print("separately conjugate but not simultaneously conjugate")
    source = Family.of(3, a=lambda x: (x + 1) % 3, b=lambda x: (x + 1) % 3)
    target = Family.of(3, a=lambda x: (x + 1) % 3, b=lambda x: (x + 2) % 3)
    check("minimal 3-state separation", separates(source, target))
    n = 8
    source = Family.of(n, inc=lambda x: (x + 1) % n, clear=lambda x: x & 6)
    target = Family.of(n, inc=lambda x: (x + 3) % n, clear=lambda x: x & 6)
    check("three-bit increment/clear separation", separates(source, target))
    check(
        "the increments alone are conjugate",
        simultaneous(
            Family(n, (("inc", source.table("inc")),)),
            Family(n, (("inc", target.table("inc")),)),
        ).conjugate,
    )


def test_burnside_orbit_counts() -> None:
    print("census orbit counts against Burnside's lemma")
    for n, k, kind in ((3, 2, "permutations"), (4, 2, "permutations"), (5, 2, "permutations"),
                       (3, 2, "functions"), (4, 2, "functions"), (3, 3, "permutations")):
        pool = census.all_permutations(n) if kind == "permutations" else census.all_functions(n)
        # fixed points of the conjugation action, counted directly
        total = 0
        for p in permutations(range(n)):
            fixed = sum(1 for t in pool if census.conjugate_table(p, t) == t)
            total += fixed ** k
        expected = total // factorial(n)
        check(
            f"n={n} k={k} {kind}: {expected} orbits",
            total % factorial(n) == 0 and len(census.family_orbits(n, k, pool)) == expected,
            f"enumerated {len(census.family_orbits(n, k, pool))}, Burnside {total / factorial(n)}",
        )


def test_generating_states_minimal() -> None:
    print("generating sets cover the state space and are minimum")
    rng = random.Random(4242)
    bad_cover = 0
    bad_size = 0
    for _ in range(200):
        n = rng.randrange(1, 8)
        family = random_family(rng, n, rng.randrange(1, 3), rng.random() < 0.4)
        roots = generating_states(family)
        reached = set(roots)
        frontier = list(roots)
        while frontier:
            x = frontier.pop()
            for _, table in family.ops:
                if table[x] not in reached:
                    reached.add(table[x])
                    frontier.append(table[x])
        if reached != set(range(n)):
            bad_cover += 1
        # minimum: no smaller subset of states covers the family
        smaller = False
        if len(roots) > 0:
            for size in range(len(roots)):
                for subset in product(range(n), repeat=size):
                    seen = set(subset)
                    stack = list(subset)
                    while stack:
                        x = stack.pop()
                        for _, table in family.ops:
                            if table[x] not in seen:
                                seen.add(table[x])
                                stack.append(table[x])
                    if seen == set(range(n)):
                        smaller = True
                        break
                if smaller:
                    break
        if smaller:
            bad_size += 1
    check("forward closure of the generating set is everything", bad_cover == 0)
    check("no smaller set has that closure", bad_size == 0, f"{bad_size} not minimum")


def test_restricted_classes() -> None:
    print("restricted relabeling classes")
    for width in (2, 3):
        n = 1 << width
        for cls in (xor_translation(width), bit_permutation(width), gf2_linear(width), gf2_affine(width)):
            listed = list(cls.enumerate_all())
            check(
                f"{cls.name} enumerates {cls.size} distinct permutations",
                len(listed) == cls.size and len(set(listed)) == cls.size,
                f"got {len(set(listed))}",
            )
            check(
                f"{cls.name} membership agrees with its enumeration",
                all(cls.holds(p) for p in listed)
                and sum(1 for p in permutations(range(n)) if cls.holds(p)) == cls.size,
            )
    check(
        "modular_affine(12) has phi(12)*12 = 48 members",
        modular_affine(12).size == 48
        and sum(1 for p in permutations(range(6))) > 0,
    )


def test_class_restriction_changes_the_answer() -> None:
    print("restricting the relabeling changes the answer")
    source = Family(8, (("mul", fields.field_multiplication(3, 1, include_zero=True)),))
    target = Family(8, (("mul", fields.field_multiplication(3, 3, include_zero=True)),))
    check("an arbitrary relabeling exists", simultaneous(source, target).conjugate)
    for cls in (gf2_linear(3), gf2_affine(3), bit_permutation(3), xor_translation(3)):
        verdict = conjugate_in_class(source, target, cls)
        check(f"no witness inside {cls.name}", not verdict.conjugate)
        # the same answer by exhaustive class enumeration, a different route
        by_enumeration = any(conjugates(p, source, target) for p in cls.enumerate_all())
        check(f"{cls.name} coset route agrees with enumeration", by_enumeration == verdict.conjugate)
    zero = tuple([0] * 8)
    check(
        "the minimal polynomial is the reason",
        fields.polynomial_value(source.table("mul"), (1, 1, 0, 1)) == zero
        and fields.polynomial_value(target.table("mul"), (1, 1, 0, 1)) != zero,
    )


def test_discrete_log_chain() -> None:
    print("discrete logarithm relabels a whole multiplication family")
    for width in (3, 4):
        order = (1 << width) - 1
        exponents = (1, 3, 5)
        labels = tuple(f"m{k}" for k in exponents)
        source = Family(
            order,
            tuple(
                (label, fields.field_multiplication(width, k, include_zero=False))
                for label, k in zip(labels, exponents)
            ),
        )
        target = Family(
            order,
            tuple(
                (label, tuple((x + k) % order for x in range(order)))
                for label, k in zip(labels, exponents)
            ),
        )
        verdict = simultaneous(source, target)
        log = fields.discrete_log(width)
        expected = tuple(log[state + 1] for state in range(order))
        check(f"width {width}: conjugate", verdict.conjugate)
        check(f"width {width}: the witness is the discrete logarithm", verdict.witness == expected)
        chain = ("m1", "m3", "m5", "m1", "m3", "m5", "m1")
        check(f"width {width}: a 7-operation chain needs one encode and one decode",
              chain_agrees(source, target, verdict.witness, chain))
        shift = sum(int(name[1:]) for name in chain) % order
        check(f"width {width}: the chain collapses to one addition",
              target.word(chain) == tuple((x + shift) % order for x in range(order)))


def test_chain_semantics() -> None:
    print("conjugacy carries whole chains")
    rng = random.Random(1234)
    bad = 0
    for _ in range(200):
        n = rng.randrange(2, 7)
        source = random_family(rng, n, 2, rng.random() < 0.5)
        target = source.relabel(random_permutation(rng, n))
        verdict = simultaneous(source, target)
        if not verdict.conjugate:
            bad += 1
            continue
        word = tuple(rng.choice(source.labels) for _ in range(rng.randrange(1, 12)))
        if not chain_agrees(source, target, verdict.witness, word):
            bad += 1
    check("every relabeled family conjugates every chain", bad == 0, f"{bad} failures")


def test_independent_versus_shared() -> None:
    print("independent relabeling is strictly weaker")
    rng = random.Random(555)
    shared_implies_independent = 0
    strictly_weaker = 0
    for _ in range(300):
        n = rng.randrange(2, 7)
        source = random_family(rng, n, 2, rng.random() < 0.6)
        target = random_family(rng, n, 2, rng.random() < 0.6)
        sep = independent(source, target)
        joint = simultaneous(source, target).conjugate
        if joint and not sep["all_conjugate"]:
            shared_implies_independent += 1
        if sep["all_conjugate"] and not joint:
            strictly_weaker += 1
    check("a shared relabeling always implies separate ones", shared_implies_independent == 0)
    check("separate relabelings do not imply a shared one", strictly_weaker > 0,
          "no separating pair was sampled")


def test_invariants_are_relabeling_invariant() -> None:
    print("invariants survive relabeling")
    rng = random.Random(31337)
    bad = 0
    for _ in range(200):
        n = rng.randrange(2, 8)
        family = random_family(rng, n, rng.randrange(1, 4), rng.random() < 0.5)
        moved = family.relabel(random_permutation(rng, n))
        if (
            canonical_refinement(family) != canonical_refinement(moved)
            or orbit_signature(family) != orbit_signature(moved)
            or pair_refinement(family) != pair_refinement(moved)
            or [preimage_profile(t) for t in family.tables]
            != [preimage_profile(t) for t in moved.tables]
        ):
            bad += 1
    check("refinement, orbit and pair invariants are relabeling invariants", bad == 0, f"{bad} differ")


def test_shortest_word_is_shortest() -> None:
    print("shortest distinguishing word")
    rng = random.Random(606)
    bad = 0
    checked = 0
    for _ in range(150):
        n = rng.randrange(2, 6)
        source = random_family(rng, n, 2, rng.random() < 0.5)
        target = random_family(rng, n, 2, rng.random() < 0.5)
        word = shortest_distinguishing_word(source, target)
        if word is None:
            continue
        checked += 1
        from relabeling import word_profile

        if word_profile(source, len(word) - 1) != word_profile(target, len(word) - 1):
            bad += 1
        if word_profile(source, len(word)) == word_profile(target, len(word)):
            bad += 1
    check(f"{checked} reported words are exactly the shortest", bad == 0, f"{bad} wrong")


def test_malformed_inputs() -> None:
    print("malformed input is refused")
    for build, why in (
        (lambda: Family(3, (("a", (0, 1)),)), "wrong table length"),
        (lambda: Family(3, (("a", (0, 1, 3)),)), "state outside the set"),
        (lambda: Family(0, ()), "empty state set"),
        (lambda: Family(2, (("a", (0, 1)), ("a", (1, 0)))), "duplicate label"),
        (lambda: Family(2, (("a", (0, 1)),)).relabel((0, 0)), "not a permutation"),
        (lambda: Family(2, (("a", (0, 1)),)).with_labels("x", "y"), "wrong label count"),
    ):
        try:
            build()
        except RelabelingError:
            print(f"  ok   refuses {why}")
        else:
            FAILURES.append(f"accepted {why}")
            print(f"  FAIL accepted {why}")
    mismatched = simultaneous(
        Family(2, (("a", (0, 1)),)), Family(2, (("b", (0, 1)),))
    )
    check(
        "mismatched labels report a label problem, not a conjugacy answer",
        not mismatched.conjugate and "with_labels" in (mismatched.obstruction or ""),
    )


def test_lean_tables_agree() -> None:
    """The Lean file states the same tables and the same verdicts.

    Lean checks its own theorems; what it cannot check is that its tables are
    the ones the search actually analysed.  This reads them back and reruns the
    decisions here, so a transcription slip cannot leave the two layers
    disagreeing quietly.
    """
    import re

    lean = pathlib.Path(__file__).resolve().parents[3] / "Kelana" / "Relabeling.lean"
    if not lean.exists():
        check("Kelana/Relabeling.lean is present", False, str(lean))
        return
    text = lean.read_text()
    tables = {
        name: tuple(int(v) for v in body.split(","))
        for name, body in re.findall(r"def (\w+) : Fin \d+ . Fin \d+ := t\d \[([^\]]+)\]", text)
    }
    check("every table in the Lean file was read", len(tables) == 11, str(sorted(tables)))

    pairs = [
        ("three-state separation", ("succ3", "succ3"), ("succ3", "twice3"), False),
        ("three-bit separation", ("inc1", "clearLow"), ("inc3", "clearLow"), False),
        ("GF(8) single operation", ("mulAlpha",), ("mulAlphaCubed",), True),
        ("GL(3,2) point/plane", ("aPoint", "bPoint"), ("aPlane", "bPlane"), False),
    ]
    for name, left, right, expected in pairs:
        source = Family(
            len(tables[left[0]]),
            tuple((chr(ord("a") + i), tables[t]) for i, t in enumerate(left)),
        )
        target = Family(
            len(tables[right[0]]),
            tuple((chr(ord("a") + i), tables[t]) for i, t in enumerate(right)),
        )
        verdict = simultaneous(source, target)
        check(
            f"Lean tables for {name}: conjugate={expected}",
            verdict.conjugate == expected,
            f"python says {verdict.conjugate}",
        )
        if not expected:
            check(
                f"Lean tables for {name}: each operation separately conjugate",
                independent(source, target)["all_conjugate"],
            )

    # the GF(8) pair must be conjugate, and by nothing bit-linear
    source = Family(8, (("mul", tables["mulAlpha"]),))
    target = Family(8, (("mul", tables["mulAlphaCubed"]),))
    check(
        "Lean tables for GF(8): no bit-linear witness",
        not conjugate_in_class(source, target, gf2_linear(3)).conjugate
        and not conjugate_in_class(source, target, gf2_affine(3)).conjugate,
    )
    # and the exhibited Lean witness really works
    witness = tables.get("__none__")
    lean_witness = re.search(r"refine .t8 \[([^\]]+)\], t8 \[([^\]]+)\]", text)
    if lean_witness:
        p_table = tuple(int(v) for v in lean_witness.group(1).split(","))
        q_table = tuple(int(v) for v in lean_witness.group(2).split(","))
        check(
            "the witness exhibited in Lean conjugates and its stated inverse inverts",
            conjugates(p_table, source, target) and invert(p_table) == q_table,
        )


def main() -> int:
    for test in (
        test_search_against_brute_force,
        test_all_witnesses_complete,
        test_screens_are_necessary,
        test_screens_are_incomplete,
        test_separation_examples,
        test_burnside_orbit_counts,
        test_generating_states_minimal,
        test_restricted_classes,
        test_class_restriction_changes_the_answer,
        test_discrete_log_chain,
        test_chain_semantics,
        test_independent_versus_shared,
        test_invariants_are_relabeling_invariant,
        test_shortest_word_is_shortest,
        test_malformed_inputs,
        test_lean_tables_agree,
    ):
        test()
    if FAILURES:
        print(f"\n{len(FAILURES)} failure(s):")
        for line in FAILURES:
            print(f"  {line}")
        return 1
    print("\nall checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
