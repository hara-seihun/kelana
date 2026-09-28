"""What a relabeling costs, under a declared model, with the program to check.

A witness permutation is a mathematical object.  Running a conjugate family
means applying that permutation at a region's entry and its inverse at its
exit, so a conjugacy result is only actionable once the boundary map has a
price.  This module supplies that price two ways, and neither of them asserts
anything about real hardware.

**Synthesised programs.**  `Grammar` is an explicitly declared set of invertible
operations on a `w`-bit word.  `synthesise` searches for the cheapest program in
that grammar computing a given permutation, by meet-in-the-middle over both
ends, and returns the program.  `verify` re-runs the emitted program on all
`2^w` inputs.  The cost of a relabeling is then a fact about the declared
grammar -- a program exists, here it is, and no shorter one does within the
searched bound -- rather than an assertion about an instruction set.

**Declared costs.**  Every operation's charge comes from a `CostModel` the
caller supplies.  The default is one unit per operation, which makes the cost
an operation count and nothing more.  A caller with real per-operation charges
can supply them and the same minimisation runs.

What this module does **not** do: name machine instructions, claim occupied
cycles, model register pressure, hazards, addressing, packing, masking or
wait states.  The grammar is a mathematical grammar.  A cost reported here is
a minimum operation count in that grammar, which bounds nothing about a real
device until someone maps the grammar onto one and prices that map.

Every search is bounded.  A result that hit its bound is reported with
`optimal=False` and the bound that stopped it; it is an upper bound only.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from relabeling import (
    Family,
    all_witnesses,
    conjugates,
    invert,
)


class BoundaryError(ValueError):
    """A malformed grammar, model or width."""


# --------------------------------------------------------------------------
# declared cost model
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class CostModel:
    """Charges for grammar operations, supplied by the caller.

    `units` names what a charge means so a report cannot silently be read as
    cycles.  `charges` maps an operation family name to its charge; anything
    absent falls back to `default`.
    """

    units: str = "grammar operations"
    default: int = 1
    charges: tuple[tuple[str, int], ...] = ()

    def __post_init__(self):
        charges = tuple(tuple(entry) for entry in self.charges)
        if type(self.default) is not int or self.default <= 0:
            raise BoundaryError("default cost must be a positive integer")
        if any(len(entry) != 2 or not isinstance(entry[0], str) or not entry[0]
               or type(entry[1]) is not int or entry[1] <= 0 for entry in charges):
            raise BoundaryError("named costs must be positive integers")
        if len({name for name, _ in charges}) != len(charges):
            raise BoundaryError("cost families must be unique")
        object.__setattr__(self, "charges", charges)

    def charge(self, family_name: str) -> int:
        for name, value in self.charges:
            if name == family_name:
                return value
        return self.default

    @property
    def uniform(self) -> bool:
        return all(value == self.default for _, value in self.charges)

    def describe(self) -> dict:
        return {
            "units": self.units,
            "default_charge": self.default,
            "explicit_charges": {name: value for name, value in self.charges},
            "uniform": self.uniform,
            "warning": (
                "these are declared abstract charges, not measured hardware cost; "
                "nothing here is an instruction count for any device"
            ),
        }


#: Operation count, and nothing else.  The honest default.
OPERATION_COUNT = CostModel()


# --------------------------------------------------------------------------
# a declared grammar of invertible word operations
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Op:
    """One invertible operation on a `w`-bit word, with its table."""

    name: str
    family: str
    table: tuple[int, ...]

    def apply_after(self, current: tuple[int, ...]) -> tuple[int, ...]:
        """Compose: run `current` first, then this operation."""
        return tuple(self.table[v] for v in current)

    @property
    def inverse(self) -> tuple[int, ...]:
        out = [0] * len(self.table)
        for x, y in enumerate(self.table):
            out[y] = x
        return tuple(out)

    def undo_before(self, current: tuple[int, ...]) -> tuple[int, ...]:
        """Peel this operation off the front: returns `op^-1 . current`."""
        back = self.inverse
        return tuple(back[v] for v in current)


@dataclass(frozen=True)
class Grammar:
    """A declared set of invertible word operations.

    The default grammar is the usual invertible integer/bit repertoire on one
    word: XOR and ADD by a constant, rotations, and the two triangular
    `x ^= x << k` / `x ^= x >> k` mixes.  It is a choice, recorded here, not a
    claim that a machine has exactly these.
    """

    width: int
    ops: tuple[Op, ...]
    description: str

    @property
    def n(self) -> int:
        return 1 << self.width

    def families(self) -> tuple[str, ...]:
        seen = []
        for op in self.ops:
            if op.family not in seen:
                seen.append(op.family)
        return tuple(seen)

    def describe(self) -> dict:
        counts: dict[str, int] = {}
        for op in self.ops:
            counts[op.family] = counts.get(op.family, 0) + 1
        return {
            "width": self.width,
            "description": self.description,
            "operation_count": len(self.ops),
            "families": counts,
        }


def _is_permutation(table: tuple[int, ...]) -> bool:
    return sorted(table) == list(range(len(table)))


def word_grammar(width: int) -> Grammar:
    """The default declared grammar on a `w`-bit word."""
    if not 1 <= width <= 8:
        raise BoundaryError(f"width {width} is outside the supported range 1..8")
    n = 1 << width
    mask = n - 1
    ops: list[Op] = []

    for c in range(1, n):
        ops.append(Op(f"xor {c}", "xor_constant", tuple(x ^ c for x in range(n))))
    for c in range(1, n):
        ops.append(Op(f"add {c}", "add_constant", tuple((x + c) & mask for x in range(n))))
    for k in range(1, width):
        ops.append(
            Op(
                f"rotl {k}",
                "rotate",
                tuple(((x << k) | (x >> (width - k))) & mask for x in range(n)),
            )
        )
    for k in range(1, width):
        ops.append(
            Op(f"xor-shl {k}", "shift_mix", tuple(x ^ ((x << k) & mask) for x in range(n)))
        )
        ops.append(Op(f"xor-shr {k}", "shift_mix", tuple(x ^ (x >> k) for x in range(n))))

    for op in ops:
        if not _is_permutation(op.table):
            raise BoundaryError(f"grammar operation {op.name} is not invertible")
    return Grammar(
        width,
        tuple(ops),
        "xor/add by constant, rotate, and the triangular xor-shift mixes",
    )


# --------------------------------------------------------------------------
# program synthesis
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Program:
    """A straight-line word program, its cost and how far the search went."""

    steps: tuple[str, ...]
    cost: int
    optimal: bool
    searched_to: int
    model_units: str
    note: str = ""

    def describe(self) -> dict:
        return {
            "steps": list(self.steps),
            "cost": self.cost,
            "units": self.model_units,
            "optimal_within_search": self.optimal,
            "searched_to_cost": self.searched_to,
            "note": self.note,
        }


def run(program: Program | tuple[str, ...], grammar: Grammar) -> tuple[int, ...]:
    """Evaluate an emitted program as a table, so a claim can be rechecked."""
    steps = program.steps if isinstance(program, Program) else tuple(program)
    lookup = {op.name: op for op in grammar.ops}
    current = tuple(range(grammar.n))
    for name in steps:
        if name not in lookup:
            raise BoundaryError(f"{name!r} is not in this grammar")
        current = lookup[name].apply_after(current)
    return current


def verify(program: Program | tuple[str, ...], target: tuple[int, ...], grammar: Grammar) -> bool:
    """Does the emitted program compute the target permutation on every input?"""
    return run(program, grammar) == tuple(target)


def _expand(
    frontier: dict[tuple[int, ...], tuple[str, ...]],
    seen: dict[tuple[int, ...], tuple[str, ...]],
    grammar: Grammar,
    *,
    before: bool,
) -> dict[tuple[int, ...], tuple[str, ...]]:
    """One breadth-first layer.  `before` prepends the operation instead."""
    nxt: dict[tuple[int, ...], tuple[str, ...]] = {}
    for table, word in frontier.items():
        for op in grammar.ops:
            if before:
                # backward invariant: target == run(word) . table.  Prefixing `op`
                # to the word means the new table must satisfy op . new == table.
                grown = op.undo_before(table)
                path = (op.name,) + word
            else:
                grown = op.apply_after(table)
                path = word + (op.name,)
            if grown in seen or grown in nxt:
                continue
            nxt[grown] = path
    return nxt


def synthesise(
    target: tuple[int, ...],
    grammar: Grammar,
    *,
    max_cost: int = 6,
    model: CostModel = OPERATION_COUNT,
) -> Program | None:
    """Cheapest program in `grammar` computing `target`, or `None` within bound.

    With a uniform model the search is a meet-in-the-middle breadth-first
    search from both ends, so the returned length is the true minimum whenever
    one is found at or below `max_cost`.  With a non-uniform model the search
    is a bounded uniform-cost search from one end, which is still exact up to
    the budget but explores more.

    `None` means no program of cost at most `max_cost` exists.  It never means
    the permutation is uncomputable: a longer program may exist, and for a
    grammar generating the full symmetric group one always does.
    """
    if type(max_cost) is not int or max_cost < 0:
        raise BoundaryError("max_cost must be a nonnegative integer")
    target = tuple(target)
    if len(target) != grammar.n:
        raise BoundaryError(
            f"target has {len(target)} states, grammar width {grammar.width} has {grammar.n}"
        )
    if not _is_permutation(target):
        raise BoundaryError("only permutations can be synthesised from an invertible grammar")
    identity = tuple(range(grammar.n))
    if target == identity:
        return Program((), 0, True, max_cost, model.units, "the identity needs no operations")

    if not model.uniform:
        return _synthesise_weighted(target, grammar, max_cost=max_cost, model=model)

    forward: dict[tuple[int, ...], tuple[str, ...]] = {identity: ()}
    backward: dict[tuple[int, ...], tuple[str, ...]] = {target: ()}
    forward_frontier = dict(forward)
    backward_frontier = dict(backward)
    for total in range(1, max_cost // model.default + 1):
        if len(forward_frontier) <= len(backward_frontier):
            forward_frontier = _expand(forward_frontier, forward, grammar, before=False)
            forward.update(forward_frontier)
        else:
            backward_frontier = _expand(backward_frontier, backward, grammar, before=True)
            backward.update(backward_frontier)
        meet = set(forward) & set(backward)
        if meet:
            best = min(
                (forward[table] + backward[table] for table in meet), key=lambda w: (len(w), w)
            )
            charge = sum(model.charge(_family_of(step, grammar)) for step in best)
            return Program(best, charge, True, total * model.default, model.units)
    return None


def _family_of(step: str, grammar: Grammar) -> str:
    for op in grammar.ops:
        if op.name == step:
            return op.family
    raise BoundaryError(f"{step!r} is not in this grammar")


def _synthesise_weighted(
    target: tuple[int, ...], grammar: Grammar, *, max_cost: int, model: CostModel
) -> Program | None:
    import heapq

    identity = tuple(range(grammar.n))
    best: dict[tuple[int, ...], int] = {identity: 0}
    queue: list[tuple[int, tuple[int, ...], tuple[str, ...]]] = [(0, identity, ())]
    while queue:
        cost, table, word = heapq.heappop(queue)
        if cost > best.get(table, cost):
            continue
        if table == target:
            return Program(word, cost, True, max_cost, model.units)
        for op in grammar.ops:
            grown = op.apply_after(table)
            grown_cost = cost + model.charge(op.family)
            if grown_cost > max_cost:
                continue
            if grown_cost < best.get(grown, grown_cost + 1):
                best[grown] = grown_cost
                heapq.heappush(queue, (grown_cost, grown, word + (op.name,)))
    return None


def price_relabeling(
    p: tuple[int, ...],
    grammar: Grammar,
    *,
    max_cost: int = 6,
    model: CostModel = OPERATION_COUNT,
) -> Program:
    """The cheapest declared-grammar program for `p`, or an explicit failure.

    A returned program is verified against `p` on every input before it leaves
    this function, so a caller never receives an unchecked cost.
    """
    found = synthesise(p, grammar, max_cost=max_cost, model=model)
    if found is None:
        return Program(
            (),
            -1,
            False,
            max_cost,
            model.units,
            f"no program of cost at most {max_cost} in this grammar computes it; "
            "the cost is unknown, not infinite",
        )
    if not verify(found, p, grammar):
        raise BoundaryError("internal: synthesis returned a program that does not compute the target")
    return found


def structure_report(
    p: tuple[int, ...],
    width: int,
    *,
    max_cost: int = 6,
    model: CostModel = OPERATION_COUNT,
) -> dict:
    """Structural classes containing `p`, and its cheapest declared program.

    Class membership is a mathematical property of the permutation.  It is
    reported separately from the program cost because the two answer different
    questions: one says what shape `p` has, the other says what it costs in a
    declared grammar.  Neither is a statement about a machine.
    """
    from relabeling import (
        bit_permutation,
        gf2_affine,
        gf2_linear,
        modular_affine,
        xor_translation,
    )

    grammar = word_grammar(width)
    classes = {
        cls.name: cls.holds(p)
        for cls in (
            xor_translation(width),
            bit_permutation(width),
            gf2_linear(width),
            gf2_affine(width),
            modular_affine(1 << width),
        )
    }
    return {
        "classes_containing_it": classes,
        "program": price_relabeling(p, grammar, max_cost=max_cost, model=model).describe(),
    }


# --------------------------------------------------------------------------
# choosing a witness
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class WitnessChoice:
    """The cheapest relabeling found, and whether that is known to be cheapest."""

    witness: tuple[int, ...]
    encode: Program
    decode: Program
    total: int
    witnesses_examined: int
    witness_set_complete: bool
    optimal: bool
    note: str

    def describe(self) -> dict:
        return {
            "witness": list(self.witness),
            "encode": self.encode.describe(),
            "decode": self.decode.describe(),
            "round_trip_cost": self.total,
            "witnesses_examined": self.witnesses_examined,
            "witness_set_complete": self.witness_set_complete,
            "optimal": self.optimal,
            "note": self.note,
        }


def cheapest_witness(
    source: Family,
    target: Family,
    grammar: Grammar,
    *,
    max_cost: int = 6,
    model: CostModel = OPERATION_COUNT,
    witness_limit: int = 4096,
) -> WitnessChoice | None:
    """Minimise the round-trip boundary cost over the conjugating bijections.

    Conjugating bijections form a coset of the source family's automorphism
    group, so a symmetric family offers many and they do not cost the same.
    Every examined witness is priced by synthesis and the minimum is returned.

    Two things can make the answer an upper bound rather than a minimum, and
    both are reported rather than hidden: the witness set can exceed
    `witness_limit`, and a witness can have no program within `max_cost`.
    """
    found, capped = all_witnesses(source, target, limit=witness_limit)
    if not found:
        return None
    best: WitnessChoice | None = None
    unpriced = 0
    for p in found:
        encode = price_relabeling(p, grammar, max_cost=max_cost, model=model)
        if encode.cost < 0:
            unpriced += 1
            continue
        decode = price_relabeling(invert(p), grammar, max_cost=max_cost, model=model)
        if decode.cost < 0:
            unpriced += 1
            continue
        total = encode.cost + decode.cost
        if best is None or total < best.total:
            best = WitnessChoice(
                p, encode, decode, total, len(found), not capped, True, ""
            )
    if best is None:
        return WitnessChoice(
            found[0],
            price_relabeling(found[0], grammar, max_cost=max_cost, model=model),
            price_relabeling(invert(found[0]), grammar, max_cost=max_cost, model=model),
            -1,
            len(found),
            not capped,
            False,
            f"none of the {len(found)} examined relabelings has a program of cost at "
            f"most {max_cost} in this grammar",
        )
    reasons = []
    if capped:
        reasons.append(
            f"the witness set exceeded the {witness_limit} examined, so a cheaper "
            "relabeling may exist outside the examined part"
        )
    if unpriced:
        reasons.append(
            f"{unpriced} examined relabeling(s) had no program within cost {max_cost}, "
            "so their cost is unknown rather than higher"
        )
    if not reasons:
        return best
    return WitnessChoice(
        best.witness,
        best.encode,
        best.decode,
        best.total,
        best.witnesses_examined,
        not capped,
        False,
        "; ".join(reasons),
    )


# --------------------------------------------------------------------------
# when a relabeled region pays
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Window:
    """Region-length comparison under one declared cost model.

    `connector` is the charge a per-operation relabeling scheme pays *between*
    consecutive operations.  It is a parameter, not a constant: a consumer that
    already accepts the next operation's labeling, or a connector fused into an
    adjacent operation, can make it zero.  Set it to what the situation
    actually costs.
    """

    enter: int
    exit: int
    source_per_operation: int
    target_per_operation: int
    horizon: int = 4096

    def __post_init__(self) -> None:
        if self.horizon < 1:
            raise BoundaryError("horizon must be at least one operation")

    @property
    def boundary(self) -> int:
        return self.enter + self.exit

    def shared_cost(self, length: int) -> int:
        """One relabeling for the whole region: two crossings, whatever `length` is."""
        return 0 if length == 0 else self.boundary + length * self.target_per_operation

    def separate_cost(self, length: int, connector: int) -> int:
        """Per-operation relabelings, paying `connector` at each internal boundary."""
        if length == 0:
            return 0
        return self.boundary + length * self.target_per_operation + (length - 1) * connector

    def native_cost(self, length: int) -> int:
        return length * self.source_per_operation

    def _interval(self, cost) -> dict:
        """Every region length in `1..horizon` where `cost` beats running natively.

        Reported as an explicit interval rather than a first crossing, because a
        scheme whose per-operation charge is worse can still win over a bounded
        stretch and lose afterwards.
        """
        winning = [m for m in range(1, self.horizon + 1) if cost(m) < self.native_cost(m)]
        if not winning:
            return {
                "profitable": False,
                "first": None,
                "last": None,
                "contiguous": True,
                "reaches_horizon": False,
                "horizon": self.horizon,
            }
        first, last = winning[0], winning[-1]
        return {
            "profitable": True,
            "first": first,
            "last": last,
            "contiguous": len(winning) == last - first + 1,
            "reaches_horizon": last == self.horizon,
            "horizon": self.horizon,
            "note": (
                "the profitable set runs to the search horizon; whether it continues "
                "is decided by the per-operation charges, not by this search"
            )
            if last == self.horizon
            else "the profitable set is bounded: the scheme loses again at longer regions",
        }

    def describe(self, connector: int) -> dict:
        return {
            "enter": self.enter,
            "exit": self.exit,
            "source_per_operation": self.source_per_operation,
            "target_per_operation": self.target_per_operation,
            "connector": connector,
            "shared_profitable_lengths": self._interval(self.shared_cost),
            "separate_profitable_lengths": self._interval(
                lambda m: self.separate_cost(m, connector)
            ),
            "samples": {
                length: {
                    "native": self.native_cost(length),
                    "shared": self.shared_cost(length),
                    "separate": self.separate_cost(length, connector),
                }
                for length in (1, 2, 4, 8, 64)
                if length <= self.horizon
            },
        }


def amortised(window: Window, connector: int) -> dict:
    """Charge per operation as a region grows, under the declared model.

    The two boundary crossings of a shared relabeling are a fixed cost and
    vanish in the average.  A per-operation scheme vanishes the same way
    *if* its connector charge is zero, which happens when the next consumer
    already accepts the previous operation's labeling or the connector folds
    into an adjacent operation.  It is the connector charge that decides this,
    not the number of relabelings.
    """
    return {
        "native": window.source_per_operation,
        "shared_relabeling": window.target_per_operation,
        "separate_relabelings": window.target_per_operation + connector,
        "connector_charge": connector,
        "note": (
            "with connector 0 the two schemes have the same limit; a shared "
            "relabeling guarantees that charge is 0 without needing a compatible "
            "consumer, which is the difference between them"
        ),
    }


def price_family_boundary(
    source: Family,
    target: Family,
    witness: tuple[int, ...],
    grammar: Grammar,
    *,
    source_per_operation: int,
    target_per_operation: int,
    connector: int | None = None,
    max_cost: int = 6,
    model: CostModel = OPERATION_COUNT,
    horizon: int = 4096,
) -> dict:
    """Full accounting for one conjugacy result under a declared model."""
    if not conjugates(witness, source, target):
        raise BoundaryError("the supplied permutation does not conjugate this family")
    encode = price_relabeling(witness, grammar, max_cost=max_cost, model=model)
    decode = price_relabeling(invert(witness), grammar, max_cost=max_cost, model=model)
    if encode.cost < 0 or decode.cost < 0:
        return {
            "witness": list(witness),
            "model": model.describe(),
            "grammar": grammar.describe(),
            "encode": encode.describe(),
            "decode": decode.describe(),
            "priced": False,
            "reason": "no program within the search bound; no cost is claimed",
        }
    if connector is None:
        connector = encode.cost + decode.cost
    window = Window(
        encode.cost, decode.cost, source_per_operation, target_per_operation, horizon
    )
    return {
        "witness": list(witness),
        "model": model.describe(),
        "grammar": grammar.describe(),
        "encode": encode.describe(),
        "decode": decode.describe(),
        "encode_verified": verify(encode, witness, grammar),
        "decode_verified": verify(decode, invert(witness), grammar),
        "priced": True,
        "window": window.describe(connector),
        "amortised": amortised(window, connector),
    }
