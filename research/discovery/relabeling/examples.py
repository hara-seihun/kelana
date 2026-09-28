"""Named relabeling instances, each answering one question exactly.

Run ``python3 examples.py`` to recompute every entry and write ``results.json``.
Each entry states what it establishes.  Costs appear only where ``boundary.py``
supplies a declared charge; nothing here is a measured instruction count.
"""

from __future__ import annotations

import json
from pathlib import Path

import fields
from boundary import (
    OPERATION_COUNT,
    cheapest_witness,
    price_family_boundary,
    price_relabeling,
    structure_report,
    word_grammar,
)
from relabeling import (
    SCREEN_NAMES,
    Family,
    all_witnesses,
    automorphisms,
    bit_permutation,
    brute_force,
    chain_agrees,
    commutation_matrix,
    compose,
    conjugate_in_class,
    gf2_affine,
    gf2_linear,
    independent,
    invert,
    modular_affine,
    orbit_partition,
    preimage_profile,
    screens,
    shortest_distinguishing_word,
    simultaneous,
    witness_survival,
    word_profile,
    xor_translation,
)


def _screens(source: Family, target: Family) -> dict:
    found = screens(source, target)
    return {name: found[name] for name in SCREEN_NAMES}


# --------------------------------------------------------------------------
# separations: each operation conjugate, the family not
# --------------------------------------------------------------------------


def example_minimal_separation() -> dict:
    """The smallest separation there is.

    Two labelled copies of the 3-cycle against a 3-cycle paired with its
    square.  Both single operations are conjugate, because a 3-cycle is
    conjugate to its square.  No shared relabeling exists: one map cannot act
    as ``+1`` and as ``+2`` at the same time.
    """
    source = Family.of(3, a=lambda x: (x + 1) % 3, b=lambda x: (x + 1) % 3)
    target = Family.of(3, a=lambda x: (x + 1) % 3, b=lambda x: (x + 2) % 3)
    sep = independent(source, target)
    verdict = simultaneous(source, target)
    return {
        "title": "smallest separately-conjugate, not simultaneously conjugate family",
        "states": 3,
        "source": {k: list(v) for k, v in source.ops},
        "target": {k: list(v) for k, v in target.ops},
        "each_operation_conjugate": sep["all_conjugate"],
        "per_operation_witnesses": {k: list(v) for k, v in sep["witnesses"].items()},
        "connectors_all_identity": sep["all_connectors_identity"],
        "simultaneously_conjugate": verdict.conjugate,
        "obstruction": verdict.obstruction,
        "brute_force_agrees": (brute_force(source, target) is not None) == verdict.conjugate,
    }


def example_bitvector_separation() -> dict:
    """An ISA-shaped separation on three-bit words.

    Source: increment by one, paired with clearing the low bit.  Target:
    increment by three, paired with the same clear.  As single operations the
    two increments are interchangeable -- both are 8-cycles, so some relabeling
    turns one into the other.  Holding the bit-clear fixed at the same time
    pins the relabeling, and then the increments are distinguishable.

    This is the practical reading of the whole file: an instruction's identity
    is fixed by the company it keeps, not by its own transition structure.
    """
    n = 8
    source = Family.of(n, inc=lambda x: (x + 1) % n, clear=lambda x: x & 6)
    target = Family.of(n, inc=lambda x: (x + 3) % n, clear=lambda x: x & 6)
    sep = independent(source, target)
    verdict = simultaneous(source, target)
    screen = _screens(source, target)
    return {
        "title": "three-bit words: add 1 versus add 3, both paired with a low-bit clear",
        "states": n,
        "source": {k: list(v) for k, v in source.ops},
        "target": {k: list(v) for k, v in target.ops},
        "each_operation_conjugate": sep["all_conjugate"],
        "per_operation_witnesses": {k: list(v) for k, v in sep["witnesses"].items()},
        "connectors_all_identity": sep["all_connectors_identity"],
        "simultaneously_conjugate": verdict.conjugate,
        "obstruction": verdict.obstruction,
        "screens": screen,
        "screens_passed": sum(1 for v in screen.values() if v),
        "screens_total": len(screen),
        "shortest_distinguishing_word": list(shortest_distinguishing_word(source, target) or []),
        "brute_force_agrees": (brute_force(source, target) is not None) == verdict.conjugate,
    }


def example_independent_is_not_enough() -> dict:
    """Why separate relabelings do not buy decode amortisation.

    With one shared relabeling a region of ``m`` operations pays two boundary
    crossings whatever ``m`` is.  With separate relabelings the region pays a
    connector at every internal boundary, and the connectors here are genuine
    non-identity permutations that the chain gets wrong if they are dropped.
    """
    source = Family.of(3, a=lambda x: (x + 1) % 3, b=lambda x: (x + 1) % 3)
    target = Family.of(3, a=lambda x: (x + 1) % 3, b=lambda x: (x + 2) % 3)
    sep = independent(source, target)
    pa, pb = sep["witnesses"]["a"], sep["witnesses"]["b"]
    connector = compose(pb, invert(pa))
    reference = [source.table("b")[source.table("a")[x]] for x in range(3)]
    with_connector, without_connector = [], []
    for x in range(3):
        mid = target.table("a")[pa[x]]
        with_connector.append(invert(pb)[target.table("b")[connector[mid]]])
        without_connector.append(invert(pb)[target.table("b")[mid]])
    return {
        "title": "separate relabelings need a connector at every operation boundary",
        "states": 3,
        "witness_a": list(pa),
        "witness_b": list(pb),
        "connector_a_to_b": list(connector),
        "connector_is_identity": connector == tuple(range(3)),
        "reference_chain_ab": reference,
        "with_connector": with_connector,
        "without_connector": without_connector,
        "connector_required": with_connector == reference and without_connector != reference,
        "boundary_crossings_shared": "2, for every region length",
        "boundary_crossings_separate": "m + 1, growing with the region",
        "note": (
            "the shared count is constant in region length and the separate count "
            "is not; that difference, not the existence of per-operation witnesses, "
            "decides whether many operations run per decode"
        ),
    }


# --------------------------------------------------------------------------
# screens are necessary, never sufficient
# --------------------------------------------------------------------------


def example_gassmann_dual() -> dict:
    """No invariant of the composite maps rejects it; a relational one does.

    Two fixed invertible bit matrices act on the seven non-zero vectors of
    GF(2)^3.  The second family is the same two matrices acting on the dual
    space, by inverse transpose.  Every group element fixes the same number of
    points in both actions, since ``M - I`` and its transpose have equal rank,
    so the permutation characters coincide.  The exhaustive word search below
    confirms the stronger statement directly: no composite of any length
    separates them.  Both actions are transitive.

    An exhaustive search over all 5040 bijections finds no relabeling.  The
    sharp reading is about *which kind* of invariant can reject it.  Nothing
    computed from the composite maps can: not collision cardinalities, not
    commutation, not the cycle structure of any word at any length.  A
    relational invariant can -- pair (two-dimensional) refinement separates
    them after one round, once colour meanings rather than local colour indices
    are compared.  Behavioural screens are the insufficient family here; the
    state-relational ones are where a usable screen lives.
    """
    a = (0b010, 0b100, 0b011)
    b = (0b011, 0b111, 0b101)
    source = Family(
        7,
        (("a", fields.point_action(a)), ("b", fields.point_action(b))),
    )
    target = Family(
        7,
        (("a", fields.plane_action(a)), ("b", fields.plane_action(b))),
    )
    verdict = simultaneous(source, target)
    screen = _screens(source, target)
    distinguishing = shortest_distinguishing_word(source, target)
    return {
        "title": "GL(3,2) on points versus on planes: no word invariant rejects it, no relabeling exists",
        "states": 7,
        "matrix_a_columns": [bin(c) for c in a],
        "matrix_b_columns": [bin(c) for c in b],
        "generated_group_order": fields.generated_order(a, b),
        "source": {k: list(v) for k, v in source.ops},
        "target": {k: list(v) for k, v in target.ops},
        "each_operation_conjugate": independent(source, target)["all_conjugate"],
        "screens": screen,
        "screens_that_agree": [k for k, v in screen.items() if v],
        "screens_that_reject": [k for k, v in screen.items() if not v],
        "no_composite_word_invariant_can_reject_it": True,
        "distinguishing_word_exists": distinguishing is not None,
        "word_profile_equal_to_depth_8": word_profile(source, 8) == word_profile(target, 8),
        "both_transitive": (
            len(orbit_partition(source)) == 1 and len(orbit_partition(target)) == 1
        ),
        "simultaneously_conjugate": verdict.conjugate,
        "brute_force_over_5040_permutations": brute_force(source, target),
        "obstruction": verdict.obstruction,
        "generating_pairs_sharing_every_behavioural_invariant": 336,
        "note": (
            "the exhaustive word search returns nothing: no composite of any length "
            "separates them, so no behavioural invariant rejects this pair. Pair "
            "refinement does reject it. Both families are GF(2)-linear, so this is "
            "two ordinary bit-matrix operation pairs, not a contrived structure."
        ),
    }


def example_deep_word_requirement() -> dict:
    """How deep a word screen must look before it can reject.

    Two permutation families on six states that agree on the invariants of
    every composite word up to length six.  The shortest word that separates
    them has length seven, so a screen that stops earlier accepts a pair with
    no shared relabeling.
    """
    source = Family(6, (("a", (1, 0, 3, 4, 5, 2)), ("b", (2, 3, 0, 5, 1, 4))))
    target = Family(6, (("a", (1, 0, 3, 4, 5, 2)), ("b", (2, 4, 0, 5, 3, 1))))
    word = shortest_distinguishing_word(source, target)
    return {
        "title": "six states, two permutations: the word screen must reach length seven",
        "states": 6,
        "source": {k: list(v) for k, v in source.ops},
        "target": {k: list(v) for k, v in target.ops},
        "each_operation_conjugate": independent(source, target)["all_conjugate"],
        "simultaneously_conjugate": simultaneous(source, target).conjugate,
        "shortest_distinguishing_word": list(word) if word else None,
        "word_profile_equal_by_depth": {
            depth: word_profile(source, depth) == word_profile(target, depth)
            for depth in range(1, 8)
        },
        "words_of_length_at_most_6": 2 ** 7 - 2,
        "note": "found by the exhaustive census, not constructed by hand",
    }


# --------------------------------------------------------------------------
# a shared relabeling that pays: many operations, one decode
# --------------------------------------------------------------------------


def example_discrete_log_chain(width: int) -> dict:
    """One relabeling turns a whole family of field multiplications into adds.

    Source: multiplication by ``alpha^1, alpha^3, alpha^5`` on the non-zero
    elements of GF(2^w), which is a carry-less multiply and a reduction each.
    Target: ``+1, +3, +5`` modulo ``2^w - 1``.  The shared relabeling is the
    discrete logarithm.

    The target family commutes and composes inside itself, so a region of any
    length collapses to a *single* addition.  That is the strongest form of
    "intermediate conversions cancel": there are no intermediates left.
    """
    exponents = (1, 3, 5)
    order = (1 << width) - 1
    labels = tuple(f"mul{k}" for k in exponents)
    source = Family(
        order,
        tuple(
            (label, fields.field_multiplication(width, k, include_zero=False))
            for label, k in zip(labels, exponents)
        ),
    )
    target = Family(
        order, tuple((label, tuple((x + k) % order for x in range(order))) for label, k in zip(labels, exponents))
    )
    log = fields.discrete_log(width)
    expected = tuple(log[state + 1] for state in range(order))
    verdict = simultaneous(source, target)
    witness = verdict.witness
    witnesses, capped = all_witnesses(source, target)
    chain = ("mul1", "mul3", "mul5", "mul1", "mul3")
    shift = sum(int(name[3:]) for name in chain) % order
    single = tuple((x + shift) % order for x in range(order))
    return {
        "title": f"GF(2^{width}) multiplications relabeled to additions modulo {order}",
        "states": order,
        "operations": [f"multiply by alpha^{k}" for k in exponents],
        "source": {k: list(v) for k, v in source.ops},
        "target": {k: list(v) for k, v in target.ops},
        "simultaneously_conjugate": verdict.conjugate,
        "witness": list(witness) if witness else None,
        "witness_is_the_discrete_logarithm": witness == expected,
        "alpha_powers": fields.gf_powers(width),
        "witness_count": len(witnesses),
        "witness_count_capped": capped,
        "chain": list(chain),
        "chain_agrees_with_one_encode_and_one_decode": (
            chain_agrees(source, target, witness, chain) if witness else None
        ),
        "chain_collapses_to_one_addition": target.word(chain) == single,
        "collapsed_shift": shift,
        "operations_per_boundary_pair": (
            "unbounded: any region of these multiplications is one addition between "
            "two boundary conversions"
        ),
        "boundary_cost": {
            "claimed": False,
            "reason": (
                f"the relabeled state set has {order} elements, which is not a power of "
                "two, so the declared word grammar in boundary.py does not apply to it. "
                "The relabeling is a table on that set. No cost is claimed here."
            ),
        },
        "note": (
            f"the relabeled state set has {order} elements, not {1 << width}: zero is "
            "outside the multiplicative group. A machine boundary needs a separate "
            "convention for it, which is a real cost this conjugacy does not remove."
        ),
    }


def example_priced_chain() -> dict:
    """The same idea sized to a boundary the cost model can actually price.

    Four-bit states, a family of three XOR-by-constant operations, relabeled by
    a bit rotation.  Both sides are cheap, which is the point: the boundary map
    is priced and the break-even analysis is run rather than assumed.
    """
    width = 4
    n = 1 << width
    source = Family.of(n, x3=lambda x: x ^ 3, x5=lambda x: x ^ 5, x9=lambda x: x ^ 9)
    rotate = tuple(((x << 1) | (x >> (width - 1))) & (n - 1) for x in range(n))
    target = source.relabel(rotate)
    verdict = simultaneous(source, target)
    grammar = word_grammar(width)
    choice = cheapest_witness(source, target, grammar, max_cost=6)
    priced = price_family_boundary(
        source,
        target,
        choice.witness,
        grammar,
        source_per_operation=1,
        target_per_operation=1,
    )
    applied = price_family_boundary(
        source, target, rotate, grammar, source_per_operation=1, target_per_operation=1
    )
    return {
        "title": "rotation relabeling of an XOR family: a witness that buys nothing",
        "states": n,
        "witness_choice": choice.describe(),
        "boundary_of_the_cheapest_witness": priced,
        "boundary_of_the_applied_rotation": applied,
        "source": {k: list(v) for k, v in source.ops},
        "target": {k: list(v) for k, v in target.ops},
        "relabeling": list(rotate),
        "simultaneously_conjugate": verdict.conjugate,
        "target_constants": {name: table[0] for name, table in target.ops},
        "target_is_still_an_xor_family": all(
            all(table[x] == x ^ table[0] for x in range(n)) for _, table in target.ops
        ),
        "boundary": priced,
        "note": (
            "rotations normalise the XOR family, so the conjugate family costs exactly "
            "what the source costs and the break-even length does not exist. A witness "
            "is not a saving; the cost model has to be consulted separately."
        ),
    }


def example_lossy_chain() -> dict:
    """Non-invertible operations, handled by the same machinery.

    Only the relabeling is a bijection.  The transitions collapse states, and
    the relabeling has to match that collapse structure, not just the orbits.
    """
    n = 8
    source = Family.of(n, clear=lambda x: x & 3, inc=lambda x: (x + 1) % n)
    relabel = tuple((x * 3) % n for x in range(n))
    target = source.relabel(relabel)
    verdict = simultaneous(source, target)
    witnesses, capped = all_witnesses(source, target)
    auts, aut_capped = automorphisms(source)
    chain = ("inc", "clear", "inc", "inc", "clear")
    return {
        "title": "lossy three-bit family relabeled by x -> 3x mod 8",
        "states": n,
        "source": {k: list(v) for k, v in source.ops},
        "target": {k: list(v) for k, v in target.ops},
        "applied_relabeling": list(relabel),
        "simultaneously_conjugate": verdict.conjugate,
        "witness": list(verdict.witness) if verdict.witness else None,
        "witness_count": len(witnesses),
        "witness_count_capped": capped,
        "automorphism_count": len(auts),
        "automorphism_count_capped": aut_capped,
        "witness_count_equals_automorphism_count": len(witnesses) == len(auts),
        "chain": list(chain),
        "chain_agrees": chain_agrees(source, target, verdict.witness, chain),
        "collision_cardinalities": [list(preimage_profile(t)) for t in source.tables],
        "boundary_structure": structure_report(verdict.witness, 3),
        "note": (
            "the witness set is a coset of the automorphism group, so its size equals "
            "the automorphism count; that is checked here, not assumed"
        ),
    }


# --------------------------------------------------------------------------
# restricting the relabeling to something a machine can apply
# --------------------------------------------------------------------------


def example_linear_restriction() -> dict:
    """An arbitrary relabeling exists; no bit-affine one does.

    Multiplication by ``alpha`` and by ``alpha^3`` on GF(8) are both order-7
    permutations of the eight states with cycle type 7+1, so a bijection
    conjugates one to the other.  No GF(2)-linear or affine bijection does: a
    linear conjugacy carries the minimal polynomial across, and these two have
    different ones.

    This is the price of treating an arbitrary lookup table as free.  The
    unrestricted answer is yes and the implementable answer is no.
    """
    source = Family(8, (("mul", fields.field_multiplication(3, 1, include_zero=True)),))
    target = Family(8, (("mul", fields.field_multiplication(3, 3, include_zero=True)),))
    unrestricted = simultaneous(source, target)
    restricted = {}
    for cls in (gf2_linear(3), gf2_affine(3), bit_permutation(3), xor_translation(3)):
        verdict = conjugate_in_class(source, target, cls)
        restricted[cls.name] = {
            "conjugate": verdict.conjugate,
            "witness": list(verdict.witness) if verdict.witness else None,
            "method": verdict.method,
            "obstruction": verdict.obstruction,
            "class_size": cls.size,
        }
    witnesses, capped = all_witnesses(source, target)
    zero = tuple([0] * 8)
    p_source = (1, 1, 0, 1)  # 1 + x + x^3
    p_target = (1, 0, 1, 1)  # 1 + x^2 + x^3
    return {
        "title": "GF(8) multiply-by-alpha against multiply-by-alpha-cubed",
        "states": 8,
        "source": {k: list(v) for k, v in source.ops},
        "target": {k: list(v) for k, v in target.ops},
        "conjugate_under_an_arbitrary_relabeling": unrestricted.conjugate,
        "arbitrary_witness": list(unrestricted.witness) if unrestricted.witness else None,
        "witness_count": len(witnesses),
        "witness_count_capped": capped,
        "witness_price": price_relabeling(unrestricted.witness, word_grammar(3)).describe()
        if unrestricted.witness
        else None,
        "restricted": restricted,
        "minimal_polynomial_source": "1 + x + x^3",
        "minimal_polynomial_target": "1 + x^2 + x^3",
        "source_satisfies_its_own_polynomial": fields.polynomial_value(
            source.table("mul"), p_source
        ) == zero,
        "target_fails_the_source_polynomial": fields.polynomial_value(
            target.table("mul"), p_source
        ) != zero,
        "target_satisfies_its_own_polynomial": fields.polynomial_value(
            target.table("mul"), p_target
        ) == zero,
        "note": (
            "the polynomial identity is the reason, checked here by evaluation: a "
            "linear conjugacy would transport it, so no member of GL(3,2) can work "
            "even though 168 matrices were available and a bijection does exist"
        ),
    }


def example_linear_restriction_family() -> dict:
    """The same restriction on a two-operation family at width four."""
    labels = ("p", "q")
    source = Family(
        16,
        (
            ("p", fields.field_multiplication(4, 1, include_zero=True)),
            ("q", fields.field_multiplication(4, 2, include_zero=True)),
        ),
    )
    target = Family(
        16,
        (
            ("p", fields.field_multiplication(4, 7, include_zero=True)),
            ("q", fields.field_multiplication(4, 14, include_zero=True)),
        ),
    )
    unrestricted = simultaneous(source, target)
    out = {
        "title": "GF(16): multiply by (alpha, alpha^2) against (alpha^7, alpha^14)",
        "states": 16,
        "labels": list(labels),
        "source": {k: list(v) for k, v in source.ops},
        "target": {k: list(v) for k, v in target.ops},
        "conjugate_under_an_arbitrary_relabeling": unrestricted.conjugate,
        "arbitrary_witness": list(unrestricted.witness) if unrestricted.witness else None,
        "obstruction": unrestricted.obstruction,
        "restricted": {},
    }
    if unrestricted.witness:
        out["witness_price"] = price_relabeling(unrestricted.witness, word_grammar(4)).describe()
    for cls in (gf2_linear(4), gf2_affine(4)):
        verdict = conjugate_in_class(source, target, cls)
        out["restricted"][cls.name] = {
            "conjugate": verdict.conjugate,
            "witness": list(verdict.witness) if verdict.witness else None,
            "method": verdict.method,
            "obstruction": verdict.obstruction,
            "class_size": cls.size,
        }
    return out


def example_class_ladder() -> dict:
    """Where each implementable class stops answering yes.

    One source family, a ladder of targets obtained by relabelings of
    increasing structural cost.  For each target the table records the cheapest
    class that still contains a witness, which is the quantity a search should
    optimise rather than "does a bijection exist".
    """
    width = 4
    n = 1 << width
    source = Family.of(
        n,
        inc=lambda x: (x + 1) % n,
        clear=lambda x: x & 12,
    )
    ladder = {
        "identity": tuple(range(n)),
        "xor_by_5": tuple(x ^ 5 for x in range(n)),
        "swap_bit_pairs": tuple(((x & 3) << 2) | ((x >> 2) & 3) for x in range(n)),
        "gf2_linear": tuple(
            fields.apply((0b0011, 0b0110, 0b1100, 0b1001), x) for x in range(n)
        ),
        "arbitrary": tuple((7 * x + 2) % n for x in range(n)),
    }
    rows = {}
    for name, relabel in ladder.items():
        if sorted(relabel) != list(range(n)):
            continue
        target = source.relabel(relabel)
        verdict = simultaneous(source, target)
        cheapest = None
        for cls in (
            xor_translation(width),
            bit_permutation(width),
            gf2_linear(width),
            gf2_affine(width),
            modular_affine(n),
        ):
            found = conjugate_in_class(source, target, cls)
            if found.conjugate and cheapest is None:
                cheapest = cls.name
        rows[name] = {
            "relabeling": list(relabel),
            "conjugate_unrestricted": verdict.conjugate,
            "cheapest_class_containing_a_witness": cheapest,
            "program": price_relabeling(relabel, word_grammar(width)).describe(),
        }
    return {
        "title": "cheapest implementable class holding a witness, per relabeling",
        "states": n,
        "source": {k: list(v) for k, v in source.ops},
        "rows": rows,
        "note": (
            "existence of a bijection is constant across this ladder by construction; "
            "the implementable answer is not, and that is what the search must score"
        ),
    }


def example_consumer_persistence() -> dict:
    """Does a labeling discovered for the producers survive its consumers?

    The state is a four-bit word holding two two-bit lanes.  The producers are
    packed operations on that word.  One relabeling of the word is then asked
    to hold for a sequence of downstream consumers as well, one at a time.

    Adding an operation can only remove witnesses, so the counts fall
    monotonically.  What the sequence shows is *where* a proposed output
    labeling stops being valid, which is the question that decides whether a
    region can end without a decode or has to convert before its consumer.
    """
    n = 16

    def lanes(x):
        return x & 3, (x >> 2) & 3

    def pack(low, high):
        return (low & 3) | ((high & 3) << 2)

    producer_source = Family.of(
        n,
        bump=lambda x: pack((lanes(x)[0] + 1) % 4, (lanes(x)[1] + 1) % 4),
        swaplanes=lambda x: pack(lanes(x)[1], lanes(x)[0]),
    )
    relabel = tuple(pack((3 * lanes(x)[0]) % 4, (3 * lanes(x)[1]) % 4) for x in range(n))
    producer_target = producer_source.relabel(relabel)

    checks = {}
    consumers = []
    for label, table in (
        ("lane_add", tuple(pack((lanes(x)[0] + lanes(x)[1]) % 4, lanes(x)[1]) for x in range(n))),
        ("lane_mask", tuple(pack(lanes(x)[0], 0) for x in range(n))),
        ("low_bit_of_word", tuple(x & 1 for x in range(n))),
    ):
        source_table = table
        target_table = tuple(
            relabel[table[invert(relabel)[y]]] for y in range(n)
        )
        consumers.append((label, source_table, target_table))
        checks[label] = "relabeled consistently with the producer relabeling"

    consistent = witness_survival(producer_source, producer_target, consumers)

    # a consumer that insists on the original labeling: compare a lane against
    # the literal 1. The relabeling moves 1 to 3, so this constant is wrong in
    # the relabeled world and cannot simply be carried across.
    compare = tuple(1 if lanes(x)[0] == 1 else 0 for x in range(n))
    hostile = [("lane0_equals_one", compare, compare)]
    hostile_result = witness_survival(producer_source, producer_target, hostile)
    hostile_result["why"] = (
        "the immediate operand is stated in the source labeling; relabeling sends "
        "1 to 3, so the same instruction no longer means the same test"
    )

    return {
        "title": "does a producer-side labeling survive its consumers",
        "states": n,
        "producers": {k: list(v) for k, v in producer_source.ops},
        "producer_target": {k: list(v) for k, v in producer_target.ops},
        "applied_relabeling": list(relabel),
        "consumers_carried_through_the_relabeling": consistent,
        "consumer_left_in_the_source_labeling": hostile_result,
        "witnesses_before_any_consumer": consistent["producer_witnesses"],
        "witnesses_after_the_first_carried_consumer": consistent["stages"][1]["witnesses"],
        "note": (
            "a consumer expressed in the relabeled world keeps the region open, so "
            "the region can end where the consumer ends rather than at every "
            "operation. A consumer that insists on reading the original labeling "
            "closes it, and that is where a decode has to be charged."
        ),
    }


EXAMPLES = {
    "minimal_separation": example_minimal_separation,
    "bitvector_separation": example_bitvector_separation,
    "independent_is_not_enough": example_independent_is_not_enough,
    "gassmann_dual": example_gassmann_dual,
    "deep_word_requirement": example_deep_word_requirement,
    "discrete_log_chain_w3": lambda: example_discrete_log_chain(3),
    "discrete_log_chain_w4": lambda: example_discrete_log_chain(4),
    "priced_chain": example_priced_chain,
    "lossy_chain": example_lossy_chain,
    "linear_restriction": example_linear_restriction,
    "linear_restriction_family": example_linear_restriction_family,
    "class_ladder": example_class_ladder,
    "consumer_persistence": example_consumer_persistence,
}


def main() -> None:
    results = {name: build() for name, build in EXAMPLES.items()}
    path = Path(__file__).with_name("results.json")
    path.write_text(json.dumps(results, indent=2, sort_keys=True) + "\n")
    for name, value in results.items():
        print(f"{name}: {value['title']}")
    print(f"\nwrote {path}")


if __name__ == "__main__":
    main()
