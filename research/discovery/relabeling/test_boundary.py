#!/usr/bin/env python3
"""Checks for the declared-cost boundary model.  Runs in a few seconds.

The load-bearing ones are: every synthesised program is re-executed against its
target, and the meet-in-the-middle minima are confirmed by an independent
forward-only breadth-first search.  A cost this module reports is a minimum
operation count in a declared grammar; these tests check that claim and nothing
stronger, because nothing stronger is claimed.
"""

from __future__ import annotations

import random
import sys

import boundary
from boundary import (
    OPERATION_COUNT,
    BoundaryError,
    CostModel,
    Window,
    cheapest_witness,
    price_family_boundary,
    price_relabeling,
    run,
    structure_report,
    synthesise,
    verify,
    word_grammar,
)
from relabeling import Family, all_witnesses, conjugates, invert

FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  ok   {name}")
    else:
        FAILURES.append(f"{name}: {detail}")
        print(f"  FAIL {name} {detail}")


def forward_minimum(target, grammar, limit: int):
    """Independent forward-only search for the shortest program, for cross-checking."""
    identity = tuple(range(grammar.n))
    if tuple(target) == identity:
        return 0
    seen = {identity: ()}
    level = dict(seen)
    for depth in range(1, limit + 1):
        nxt = {}
        for table, word in level.items():
            for op in grammar.ops:
                grown = op.apply_after(table)
                if grown in seen or grown in nxt:
                    continue
                nxt[grown] = word + (op.name,)
        seen.update(nxt)
        level = nxt
        if tuple(target) in seen:
            return depth
    return None


def test_grammar_is_well_formed() -> None:
    print("the declared grammar")
    for width in (2, 3, 4):
        grammar = word_grammar(width)
        n = 1 << width
        bad = [op.name for op in grammar.ops if sorted(op.table) != list(range(n))]
        check(f"width {width}: every operation is a permutation", not bad, str(bad))
        wrong = [
            op.name
            for op in grammar.ops
            if tuple(op.inverse[op.table[x]] for x in range(n)) != tuple(range(n))
        ]
        check(f"width {width}: every inverse table inverts", not wrong, str(wrong))
        names = [op.name for op in grammar.ops]
        check(f"width {width}: operation names are unique", len(set(names)) == len(names))
    try:
        word_grammar(99)
    except BoundaryError:
        print("  ok   refuses an unsupported width")
    else:
        FAILURES.append("accepted width 99")
        print("  FAIL accepted width 99")


def test_synthesis_is_verified_and_minimal() -> None:
    print("synthesis against an independent forward search")
    grammar = word_grammar(4)
    n = 16
    targets = {
        "identity": tuple(range(n)),
        "xor 5": tuple(x ^ 5 for x in range(n)),
        "rotate left 1": tuple(((x << 1) | (x >> 3)) & 15 for x in range(n)),
        "swap bit pairs": tuple(((x & 3) << 2) | ((x >> 2) & 3) for x in range(n)),
        "7x+2 mod 16": tuple((7 * x + 2) % n for x in range(n)),
        "3x mod 16": tuple((3 * x) % n for x in range(n)),
        "add 1": tuple((x + 1) % n for x in range(n)),
    }
    for name, table in targets.items():
        program = price_relabeling(table, grammar, max_cost=5)
        check(f"{name}: a program was found", program.cost >= 0, program.note)
        if program.cost < 0:
            continue
        check(f"{name}: the emitted program recomputes the target", verify(program, table, grammar))
        independent = forward_minimum(table, grammar, 5)
        check(
            f"{name}: length {program.cost} matches the independent minimum",
            independent == program.cost,
            f"forward search says {independent}",
        )


def test_unreachable_targets_report_no_cost() -> None:
    print("out-of-bound targets report no cost rather than a guess")
    grammar = word_grammar(4)
    rng = random.Random(11)
    claimed = 0
    for _ in range(30):
        table = list(range(16))
        rng.shuffle(table)
        program = price_relabeling(tuple(table), grammar, max_cost=3)
        if program.cost >= 0:
            claimed += 1
            check("a claimed program verifies", verify(program, tuple(table), grammar))
    check(
        "random permutations mostly fall outside a short bound and say so",
        claimed < 30,
        f"{claimed}/30 were priced within cost 3",
    )
    hard = price_relabeling(tuple(range(16)), grammar, max_cost=0)
    check("the identity still prices at zero", hard.cost == 0 and hard.optimal)


def test_rejects_non_permutations() -> None:
    print("input validation")
    grammar = word_grammar(3)
    for bad, why in (
        ((0, 0, 2, 3, 4, 5, 6, 7), "not a permutation"),
        ((0, 1, 2), "wrong state count"),
    ):
        try:
            synthesise(bad, grammar)
        except BoundaryError:
            print(f"  ok   refuses {why}")
        else:
            FAILURES.append(f"accepted {why}")
            print(f"  FAIL accepted {why}")
    try:
        run(("no such op",), grammar)
    except BoundaryError:
        print("  ok   refuses an operation outside the grammar")
    else:
        FAILURES.append("accepted an unknown operation")
        print("  FAIL accepted an unknown operation")


def test_weighted_model_agrees() -> None:
    print("a non-uniform declared model")
    grammar = word_grammar(3)
    uniform = CostModel(units="operations")
    weighted = CostModel(
        units="declared units",
        default=1,
        charges=(("add_constant", 5), ("shift_mix", 3)),
    )
    check("uniform model reports itself uniform", uniform.uniform)
    check("weighted model reports itself non-uniform", not weighted.uniform)
    n = 8
    target = tuple((x + 1) % n for x in range(n))
    cheap = price_relabeling(target, grammar, max_cost=8, model=uniform)
    dear = price_relabeling(target, grammar, max_cost=8, model=weighted)
    check("both models find a program", cheap.cost >= 0 and dear.cost >= 0)
    check("both programs verify", verify(cheap, target, grammar) and verify(dear, target, grammar))
    check(
        "the weighted model never reports a cheaper charge for its own program",
        dear.cost
        >= sum(
            weighted.charge(next(o.family for o in grammar.ops if o.name == step))
            for step in dear.steps
        ),
    )
    check("the reported units come from the model", dear.model_units == "declared units")


def test_cheapest_witness_minimises() -> None:
    print("witness selection minimises the round trip")
    width = 4
    n = 1 << width
    grammar = word_grammar(width)
    source = Family.of(n, x3=lambda x: x ^ 3, x5=lambda x: x ^ 5, x9=lambda x: x ^ 9)
    rotate = tuple(((x << 1) | (x >> (width - 1))) & (n - 1) for x in range(n))
    target = source.relabel(rotate)
    choice = cheapest_witness(source, target, grammar, max_cost=4)
    check("a witness was chosen", choice is not None)
    check("the chosen witness conjugates", conjugates(choice.witness, source, target))
    check("both programs verify", verify(choice.encode, choice.witness, grammar)
          and verify(choice.decode, invert(choice.witness), grammar))
    every = []
    for p in all_witnesses(source, target)[0]:
        one = price_relabeling(p, grammar, max_cost=4)
        two = price_relabeling(invert(p), grammar, max_cost=4)
        if one.cost >= 0 and two.cost >= 0:
            every.append(one.cost + two.cost)
    check(
        f"no examined witness is cheaper than the chosen {choice.total}",
        choice.total == min(every),
        f"minimum over {len(every)} priced witnesses is {min(every)}",
    )


def test_capped_search_reports_incompleteness() -> None:
    print("capped and unpriced searches report that they are upper bounds")
    width = 4
    n = 1 << width
    grammar = word_grammar(width)
    source = Family.of(n, x3=lambda x: x ^ 3, x5=lambda x: x ^ 5)
    target = source.relabel(tuple(((x << 1) | (x >> 3)) & 15 for x in range(n)))
    capped = cheapest_witness(source, target, grammar, max_cost=4, witness_limit=8)
    check("a capped witness set is reported incomplete", not capped.witness_set_complete)
    check("a capped result is not claimed optimal", not capped.optimal)
    check("the capped result still says why", "exceeded" in capped.note)
    tight = cheapest_witness(source, target, grammar, max_cost=1, witness_limit=4096)
    check(
        "an unpriced-witness result is not claimed optimal",
        tight is None or not tight.optimal or tight.total >= 0,
    )
    if tight is not None and tight.total >= 0:
        check("its note names the unpriced witnesses", "no program within" in tight.note
              or "exceeded" in tight.note, tight.note)


def test_window_reports_the_whole_profitable_interval() -> None:
    print("break-even reported as an interval, not a first crossing")
    # cheaper per operation: profitable from some length onward
    window = Window(enter=1, exit=1, source_per_operation=4, target_per_operation=1, horizon=64)
    shared = window.describe(connector=2)["shared_profitable_lengths"]
    check("a cheaper target is profitable and stays profitable", shared["profitable"]
          and shared["first"] == 1 and shared["reaches_horizon"])
    # a scheme that wins briefly and then loses: the case a slope test misses
    window = Window(enter=0, exit=0, source_per_operation=3, target_per_operation=1, horizon=64)
    separate = window.describe(connector=5)["separate_profitable_lengths"]
    check(
        "a bounded profitable interval is found and reported bounded",
        separate["profitable"] and separate["first"] == 1 and separate["last"] == 1
        and not separate["reaches_horizon"],
        str(separate),
    )
    # never profitable
    window = Window(enter=6, exit=6, source_per_operation=1, target_per_operation=1, horizon=64)
    never = window.describe(connector=1)["shared_profitable_lengths"]
    check("an equal-cost target is never profitable", not never["profitable"])
    check("the horizon is reported", never["horizon"] == 64)
    try:
        Window(1, 1, 1, 1, horizon=0)
    except BoundaryError:
        print("  ok   refuses a zero horizon")
    else:
        FAILURES.append("accepted a zero horizon")
        print("  FAIL accepted a zero horizon")


def test_amortised_depends_on_the_connector() -> None:
    print("the amortised limit turns on the connector charge, not the scheme")
    window = Window(enter=6, exit=6, source_per_operation=2, target_per_operation=1, horizon=64)
    free = boundary.amortised(window, connector=0)
    check(
        "with a free connector both schemes reach the same limit",
        free["shared_relabeling"] == free["separate_relabelings"] == 1,
    )
    charged = boundary.amortised(window, connector=3)
    check(
        "with a charged connector the separate scheme does not",
        charged["shared_relabeling"] == 1 and charged["separate_relabelings"] == 4,
    )


def test_family_boundary_accounting() -> None:
    print("whole-family accounting")
    width = 4
    n = 1 << width
    grammar = word_grammar(width)
    source = Family.of(n, x3=lambda x: x ^ 3, x5=lambda x: x ^ 5, x9=lambda x: x ^ 9)
    rotate = tuple(((x << 1) | (x >> 3)) & 15 for x in range(n))
    target = source.relabel(rotate)
    report = price_family_boundary(
        source, target, rotate, grammar, source_per_operation=1, target_per_operation=1
    )
    check("the report is priced", report["priced"])
    check("both directions are verified in the report",
          report["encode_verified"] and report["decode_verified"])
    check("the declared model is carried in the report",
          "warning" in report["model"] and report["model"]["units"] == "grammar operations")
    check(
        "an equal-cost target never becomes profitable",
        not report["window"]["shared_profitable_lengths"]["profitable"],
    )
    try:
        price_family_boundary(
            source, target, tuple(range(n)), grammar,
            source_per_operation=1, target_per_operation=1,
        )
    except BoundaryError:
        print("  ok   refuses a permutation that does not conjugate")
    else:
        FAILURES.append("accepted a non-conjugating permutation")
        print("  FAIL accepted a non-conjugating permutation")


def test_structure_report_separates_shape_from_cost() -> None:
    print("structural class membership is reported apart from cost")
    width = 3
    rotate = tuple(((x << 1) | (x >> 2)) & 7 for x in range(8))
    report = structure_report(rotate, width)
    check("a rotation is recognised as a bit permutation",
          report["classes_containing_it"]["bit_permutation(w=3)"])
    check("a rotation is not an XOR translation",
          not report["classes_containing_it"]["xor_translation(w=3)"])
    check("the cost comes from a program, with its units named",
          report["program"]["cost"] == 1
          and report["program"]["units"] == "grammar operations")


def main() -> int:
    for test in (
        test_grammar_is_well_formed,
        test_synthesis_is_verified_and_minimal,
        test_unreachable_targets_report_no_cost,
        test_rejects_non_permutations,
        test_weighted_model_agrees,
        test_cheapest_witness_minimises,
        test_capped_search_reports_incompleteness,
        test_window_reports_the_whole_profitable_interval,
        test_amortised_depends_on_the_connector,
        test_family_boundary_accounting,
        test_structure_report_separates_shape_from_cost,
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
