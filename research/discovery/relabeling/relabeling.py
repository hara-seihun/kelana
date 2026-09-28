"""Exact simultaneous relabeling of a labeled family of state transitions.

A *family* is a finite state set ``{0,..,n-1}`` together with named total
transitions ``f_a : S -> S``.  Two families ``F`` and ``G`` on the same state
count are **simultaneously conjugate** when one bijection relabels all of them
at once:

    exists a bijection  p : S_F -> S_G   with   p(f_a(x)) = g_a(p(x))
    for every label a and every state x.

That single shared ``p`` is the whole point.  If it exists, a chain of source
operations of any length runs as the corresponding chain of target operations
with ``p`` applied once at entry and ``p^-1`` once at exit; nothing is decoded
in between.  Relabeling each operation with its own bijection carries no such
guarantee: the connectors ``p_{i+1} . p_i^-1`` reappear between consecutive
operations and the boundary cost grows with the chain.

The transitions are arbitrary functions, not necessarily bijections, so the
same machinery covers lossy operations.  When they happen to be permutations
the question is simultaneous conjugacy in the symmetric group.

Scope notes that the search results here depend on:

* Conjugacy is decided exactly.  A reported witness is verified against every
  label and state before it is returned; a reported non-existence comes from an
  exhaustive search, not from a failed heuristic.
* Preimage-size multisets, fixed-point counts, commutation patterns and
  colour-refinement histograms are *necessary* conditions.  They reject, they
  never accept.  ``incompleteness`` below exhibits families that agree on all
  of them and are still not conjugate.
* Nothing here prices an instruction.  ``boundary.py`` holds the declared cost
  model; a witness permutation is a mathematical object until it is priced.
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from itertools import permutations, product
from math import gcd

#: Refuse full-symmetric-group brute force above this state count (8! = 40320).
BRUTE_FORCE_LIMIT = 8

#: Default ceiling on enumerated witnesses, so a highly symmetric family
#: reports "capped" instead of running until memory runs out.
WITNESS_LIMIT = 4096


class RelabelingError(ValueError):
    """A malformed family, mismatched label set or exceeded explicit bound."""


# --------------------------------------------------------------------------
# families
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Family:
    """``n`` states and a label-indexed set of total transitions on them."""

    n: int
    ops: tuple[tuple[str, tuple[int, ...]], ...]

    def __post_init__(self) -> None:
        if self.n <= 0:
            raise RelabelingError(f"state count must be positive, got {self.n}")
        seen = set()
        for name, table in self.ops:
            if name in seen:
                raise RelabelingError(f"duplicate label {name!r}")
            seen.add(name)
            if len(table) != self.n:
                raise RelabelingError(
                    f"transition {name!r} has {len(table)} entries for {self.n} states"
                )
            for value in table:
                if not isinstance(value, int) or isinstance(value, bool):
                    raise RelabelingError(f"transition {name!r} holds a non-integer {value!r}")
                if not 0 <= value < self.n:
                    raise RelabelingError(f"transition {name!r} leaves the state set: {value}")

    @staticmethod
    def of(n: int, **ops: object) -> "Family":
        """Build from keyword transitions, each a callable or an explicit table."""
        built = []
        for name, spec in ops.items():
            if callable(spec):
                built.append((name, tuple(int(spec(x)) for x in range(n))))
            else:
                built.append((name, tuple(int(v) for v in spec)))
        return Family(n, tuple(built))

    @property
    def labels(self) -> tuple[str, ...]:
        return tuple(name for name, _ in self.ops)

    @property
    def tables(self) -> tuple[tuple[int, ...], ...]:
        return tuple(table for _, table in self.ops)

    def table(self, label: str) -> tuple[int, ...]:
        for name, entries in self.ops:
            if name == label:
                return entries
        raise RelabelingError(f"no transition labelled {label!r}")

    def with_labels(self, *names: str) -> "Family":
        """Rename the transitions in order.

        Conjugacy pairs transitions **by label**, so comparing two families
        whose labels were spelled differently reports incomparable families
        rather than a mathematical answer.  Align them here first.
        """
        if len(names) != len(self.ops):
            raise RelabelingError(
                f"expected {len(self.ops)} labels, got {len(names)}"
            )
        return Family(self.n, tuple((name, table) for name, (_, table) in zip(names, self.ops)))

    def relabel(self, p: tuple[int, ...]) -> "Family":
        """Push this family through the bijection ``p``: state ``x`` becomes ``p[x]``."""
        check_permutation(p, self.n)
        moved = []
        for name, table in self.ops:
            image = [0] * self.n
            for x in range(self.n):
                image[p[x]] = p[table[x]]
            moved.append((name, tuple(image)))
        return Family(self.n, tuple(moved))

    def word(self, letters: str | tuple[str, ...]) -> tuple[int, ...]:
        """Compose labels left to right: ``word("ab")`` applies ``a`` then ``b``."""
        result = tuple(range(self.n))
        for letter in letters:
            table = self.table(letter)
            result = tuple(table[x] for x in result)
        return result


def check_permutation(p: object, n: int) -> tuple[int, ...]:
    if not isinstance(p, (tuple, list)) or len(p) != n:
        raise RelabelingError(f"expected a permutation of {n} points")
    if sorted(p) != list(range(n)):
        raise RelabelingError("not a permutation of the state set")
    return tuple(int(v) for v in p)


def invert(p: tuple[int, ...]) -> tuple[int, ...]:
    out = [0] * len(p)
    for x, y in enumerate(p):
        out[y] = x
    return tuple(out)


def compose(outer: tuple[int, ...], inner: tuple[int, ...]) -> tuple[int, ...]:
    """``compose(q, p)[x] == q[p[x]]``, i.e. apply ``p`` first."""
    return tuple(outer[v] for v in inner)


def conjugates(p: tuple[int, ...], source: Family, target: Family) -> bool:
    """Does ``p`` relabel every transition of ``source`` into ``target``?"""
    if source.n != target.n or source.labels != target.labels:
        return False
    for (_, f), (_, g) in zip(source.ops, target.ops):
        for x in range(source.n):
            if p[f[x]] != g[p[x]]:
                return False
    return True


# --------------------------------------------------------------------------
# necessary screens
# --------------------------------------------------------------------------


#: Every necessary condition this module checks, in report order.
SCREEN_NAMES = (
    "collision_cardinalities",
    "per_operation_graphs",
    "commutation",
    "orbit_structure",
    "word_profile",
    "refinement",
    "pair_refinement",
)


def preimage_profile(table: tuple[int, ...]) -> tuple[int, ...]:
    """Sorted preimage sizes.  The "collision cardinalities" of one transition."""
    counts = [0] * len(table)
    for value in table:
        counts[value] += 1
    return tuple(sorted(counts))


def functional_graph_signature(table: tuple[int, ...]) -> tuple:
    """A relabeling invariant of one transition, finer than collision counts.

    Records the cycle type of the eventual (periodic) part and the multiset of
    tree depths hanging off it, which together determine the functional graph
    of a single map up to isomorphism.
    """
    n = len(table)
    # eventual image: iterate n times, every state lands on a cycle.
    reached = list(range(n))
    for _ in range(n):
        reached = [table[x] for x in reached]
    on_cycle = set(reached)
    cycle_lengths = []
    unvisited = set(on_cycle)
    while unvisited:
        start = min(unvisited)
        length = 0
        x = start
        while True:
            unvisited.discard(x)
            x = table[x]
            length += 1
            if x == start:
                break
        cycle_lengths.append(length)
    # distance from each state to the cycle
    depth = [None] * n
    for x in on_cycle:
        depth[x] = 0
    changed = True
    while changed:
        changed = False
        for x in range(n):
            if depth[x] is None and depth[table[x]] is not None:
                depth[x] = depth[table[x]] + 1
                changed = True
    return (
        tuple(sorted(cycle_lengths)),
        tuple(sorted(d for d in depth if d)),
        preimage_profile(table),
    )


def commutation_matrix(family: Family) -> tuple[tuple[bool, ...], ...]:
    tables = family.tables
    return tuple(
        tuple(compose(a, b) == compose(b, a) for b in tables) for a in tables
    )


def word_profile(family: Family, length: int) -> dict[str, tuple]:
    """Invariant signature of every composite word up to ``length`` letters."""
    if length < 0:
        raise RelabelingError("word length must be non-negative")
    labels = family.labels
    out: dict[str, tuple] = {}
    for size in range(1, length + 1):
        for letters in product(labels, repeat=size):
            key = "".join(letters)
            out[key] = functional_graph_signature(family.word(letters))
    return out


def shortest_distinguishing_word(
    source: Family, target: Family, *, bound: int | None = None
) -> tuple[str, ...] | None:
    """Shortest word whose composite has different invariants in the two families.

    Breadth-first over pairs ``(word evaluated in source, word evaluated in
    target)``.  That pair set is finite and closed under the generators, so the
    search is exhaustive: returning ``None`` means *no* word of *any* length
    separates the families by composite-map invariants, and the word screen can
    never reject them however deep it looks.

    This measures a screen, not conjugacy.  Families with no distinguishing
    word can still fail to be conjugate; see ``screens`` and the census.
    """
    if source.n != target.n or source.labels != target.labels:
        raise RelabelingError("families must share state count and labels")
    identity = tuple(range(source.n))
    start = (identity, identity)
    seen = {start}
    frontier: list[tuple[tuple[int, ...], tuple[int, ...], tuple[str, ...]]] = [
        (identity, identity, ())
    ]
    while frontier:
        nxt = []
        for x, y, word in frontier:
            for (label, f), (_, g) in zip(source.ops, target.ops):
                fx = tuple(f[v] for v in x)
                gy = tuple(g[v] for v in y)
                if (fx, gy) in seen:
                    continue
                seen.add((fx, gy))
                extended = word + (label,)
                if functional_graph_signature(fx) != functional_graph_signature(gy):
                    return extended
                if bound is None or len(extended) < bound:
                    nxt.append((fx, gy, extended))
        frontier = nxt
    return None


def refinement_colours(source: Family, target: Family) -> tuple[list[int], list[int], int]:
    """Joint colour refinement over the disjoint union of both families.

    Returns per-state colours for each family and the number of colour classes.
    Two states may be matched by a conjugating bijection only if their colours
    agree, because the refinement uses nothing but relabeling-invariant local
    data.  Equal colour histograms do not imply conjugacy; see ``incompleteness``.
    """
    if source.n != target.n or source.labels != target.labels:
        raise RelabelingError("families must share state count and labels")
    n = source.n
    families = (source, target)
    # backward neighbourhoods carry the information; forward out-degree is always 1.
    back = [
        [[[] for _ in range(n)] for _ in fam.ops]
        for fam in families
    ]
    for side, fam in enumerate(families):
        for index, (_, table) in enumerate(fam.ops):
            for x, y in enumerate(table):
                back[side][index][y].append(x)

    initial = [[coincidence_pattern(fam, x) for x in range(n)] for fam in families]
    order = {}
    for side in range(2):
        for x in range(n):
            order.setdefault(initial[side][x], len(order))
    colour = [[order[initial[side][x]] for x in range(n)] for side in range(2)]
    classes = len(order)
    while True:
        signature = [[None] * n for _ in range(2)]
        for side, fam in enumerate(families):
            for x in range(n):
                forward = tuple(colour[side][table[x]] for _, table in fam.ops)
                backward = tuple(
                    tuple(sorted(colour[side][z] for z in back[side][index][x]))
                    for index in range(len(fam.ops))
                )
                signature[side][x] = (colour[side][x], forward, backward)
        order = {}
        for side in range(2):
            for x in range(n):
                order.setdefault(signature[side][x], len(order))
        fresh = [[order[signature[side][x]] for x in range(n)] for side in range(2)]
        if len(order) == classes:
            return fresh[0], fresh[1], classes
        colour = fresh
        classes = len(order)


def coincidence_pattern(family: Family, x: int) -> tuple:
    """Which of ``x, f_1(x), .., f_k(x)`` coincide, as a relabeling invariant.

    Plain colour refinement compares the *colours* of neighbours and therefore
    learns nothing about a family of bijections: every state then has exactly
    one in-edge and one out-edge per label, so the first round already
    stabilises with a single colour.  Which operations agree at a state, and
    which fix it, survives relabeling and is not visible that way.
    """
    values = (x,) + tuple(table[x] for _, table in family.ops)
    first: dict[int, int] = {}
    pattern = []
    for value in values:
        pattern.append(first.setdefault(value, len(first)))
    return tuple(pattern)


def orbit_partition(family: Family) -> list[list[int]]:
    """Weakly connected components of the union of the transition graphs.

    For a family of bijections these are the orbits of the generated group.
    Two families cannot be conjugate unless their component structures match,
    including the sub-family carried by each component.
    """
    n = family.n
    parent = list(range(n))

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for _, table in family.ops:
        for x, y in enumerate(table):
            a, b = find(x), find(y)
            if a != b:
                parent[a] = b
    groups: dict[int, list[int]] = defaultdict(list)
    for x in range(n):
        groups[find(x)].append(x)
    return sorted(groups.values(), key=lambda part: (len(part), part))


def orbit_signature(family: Family) -> tuple:
    """Sizes of the components together with each component's own invariants."""
    out = []
    for part in orbit_partition(family):
        index = {state: position for position, state in enumerate(part)}
        restricted = Family(
            len(part),
            tuple(
                (name, tuple(index[table[state]] for state in part))
                for name, table in family.ops
            ),
        )
        out.append(
            (
                len(part),
                tuple(functional_graph_signature(t) for t in restricted.tables),
                tuple(sorted(coincidence_pattern(restricted, x) for x in range(len(part)))),
            )
        )
    return tuple(sorted(out))


def canonical_refinement(family: Family) -> tuple:
    """Colour refinement of one family, numbered canonically.

    ``refinement_colours`` numbers classes in discovery order, which is only
    comparable between the two families it was given.  This variant numbers
    them by sorted signature, so the result is a relabeling invariant that can
    be compared across separately computed families.  It starts from the
    coincidence pattern rather than from a single colour, which is what makes
    it non-trivial on families of bijections.
    """
    n = family.n
    back = [[[] for _ in range(n)] for _ in family.ops]
    for index, (_, table) in enumerate(family.ops):
        for x, y in enumerate(table):
            back[index][y].append(x)
    initial = [coincidence_pattern(family, x) for x in range(n)]
    order = {key: index for index, key in enumerate(sorted(set(initial)))}
    colour = [order[value] for value in initial]
    classes = len(order)
    while True:
        signature = []
        for x in range(n):
            signature.append(
                (
                    colour[x],
                    tuple(colour[table[x]] for _, table in family.ops),
                    tuple(
                        tuple(sorted(colour[z] for z in back[index][x]))
                        for index in range(len(family.ops))
                    ),
                )
            )
        order = {key: index for index, key in enumerate(sorted(set(signature)))}
        fresh = [order[signature[x]] for x in range(n)]
        if len(order) == classes:
            return tuple(sorted(signature))
        colour = fresh
        classes = len(order)


def pair_refinement(family: Family, *, rounds: int | None = None) -> tuple:
    """Two-dimensional refinement with comparable color meanings.

    Keep every canonical palette along with its histogram. Local integer color
    IDs alone are not comparable across independently refined families: two
    discrete partitions both have histogram 0..n²-1 even if every color means
    something different. With rounds=None refine to stability. A supplied bound
    gives only that many rounds. Named generators need not preserve these
    colors, so this is not an orbital partition of the generated group.
    """
    n = family.n
    tables = family.tables
    start = {}
    for x in range(n):
        for y in range(n):
            start[(x, y)] = (
                x == y,
                tuple(t[x] == y for t in tables),
                tuple(t[y] == x for t in tables),
                tuple(t[x] == t[y] for t in tables),
            )
    palette = tuple(sorted(set(start.values())))
    order = {key: index for index, key in enumerate(palette)}
    current = {k: order[v] for k, v in start.items()}
    history = [(palette, tuple(sorted(current.values())))]
    classes = len(order)
    if rounds is not None and (type(rounds) is not int or rounds < 0):
        raise ValueError("rounds must be a nonnegative integer or None")
    for _ in range(n*n + 1 if rounds is None else rounds):
        signature = {}
        for x in range(n):
            for y in range(n):
                signature[(x, y)] = (
                    current[(x, y)],
                    tuple(sorted((current[(x, z)], current[(z, y)]) for z in range(n))),
                )
        palette = tuple(sorted(set(signature.values())))
        order = {key: index for index, key in enumerate(palette)}
        fresh = {k: order[v] for k, v in signature.items()}
        history.append((palette, tuple(sorted(fresh.values()))))
        if len(order) == classes:
            break
        current = fresh
        classes = len(order)
    return tuple(history)


def screens(source: Family, target: Family) -> dict:
    """Every necessary condition this module knows, and whether each passes."""
    if source.n != target.n or source.labels != target.labels:
        return {"comparable": False}
    result = {
        "comparable": True,
        "collision_cardinalities": all(
            preimage_profile(a) == preimage_profile(b)
            for a, b in zip(source.tables, target.tables)
        ),
        "per_operation_graphs": all(
            functional_graph_signature(a) == functional_graph_signature(b)
            for a, b in zip(source.tables, target.tables)
        ),
        "commutation": commutation_matrix(source) == commutation_matrix(target),
        "orbit_structure": orbit_signature(source) == orbit_signature(target),
    }
    depth = min(3, max(1, 6 // max(1, len(source.ops))))
    result["word_profile_depth"] = depth
    result["word_profile"] = word_profile(source, depth) == word_profile(target, depth)
    left, right, _ = refinement_colours(source, target)
    result["refinement"] = sorted(left) == sorted(right)
    result["pair_refinement"] = pair_refinement(source) == pair_refinement(target)
    result["all_pass"] = all(
        result[key] for key in SCREEN_NAMES
    )
    return result


# --------------------------------------------------------------------------
# root selection: a minimum set of states whose forward closure is everything
# --------------------------------------------------------------------------


def _strongly_connected(n: int, edges: list[list[int]]) -> list[int]:
    """Tarjan, iterative.  Returns a component index per state."""
    index = [None] * n
    low = [0] * n
    on_stack = [False] * n
    stack: list[int] = []
    component = [-1] * n
    counter = 0
    groups = 0
    for root in range(n):
        if index[root] is not None:
            continue
        work = [(root, 0)]
        while work:
            v, child = work[-1]
            if child == 0:
                index[v] = counter
                low[v] = counter
                counter += 1
                stack.append(v)
                on_stack[v] = True
            recursed = False
            while child < len(edges[v]):
                w = edges[v][child]
                child += 1
                work[-1] = (v, child)
                if index[w] is None:
                    work.append((w, 0))
                    recursed = True
                    break
                if on_stack[w]:
                    low[v] = min(low[v], index[w])
            if recursed:
                continue
            if low[v] == index[v]:
                while True:
                    w = stack.pop()
                    on_stack[w] = False
                    component[w] = groups
                    if w == v:
                        break
                groups += 1
            work.pop()
            if work:
                parent = work[-1][0]
                low[parent] = min(low[parent], low[v])
    return component


def generating_states(family: Family) -> tuple[int, ...]:
    """A minimum-size set whose forward closure under all transitions is ``S``.

    Condense the union of the transition graphs; the source components of that
    condensation must each contain a chosen state, and one state from each is
    enough.  This is the exact branching frontier of the search below: every
    other state's image is forced once these are chosen.
    """
    n = family.n
    edges: list[list[int]] = [[] for _ in range(n)]
    for _, table in family.ops:
        for x, y in enumerate(table):
            if y not in edges[x]:
                edges[x].append(y)
    component = _strongly_connected(n, edges)
    groups = max(component) + 1 if n else 0
    has_incoming = [False] * groups
    for x in range(n):
        for y in edges[x]:
            if component[x] != component[y]:
                has_incoming[component[y]] = True
    chosen = []
    taken = set()
    for x in range(n):
        c = component[x]
        if not has_incoming[c] and c not in taken:
            taken.add(c)
            chosen.append(x)
    return tuple(chosen)


# --------------------------------------------------------------------------
# the conjugacy search
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Verdict:
    """The result of one conjugacy question."""

    conjugate: bool
    witness: tuple[int, ...] | None
    obstruction: str | None
    method: str
    branches: int
    generators: tuple[int, ...] = ()

    def __bool__(self) -> bool:
        return self.conjugate


def _propagate(
    source: Family,
    target: Family,
    assign: list[int | None],
    used: list[int | None],
    start: int,
    image: int,
) -> list[int] | None:
    """Force everything implied by ``p(start) = image``.

    Returns the list of newly assigned states, or ``None`` on contradiction.
    The caller undoes the listed assignments when it backtracks.
    """
    if assign[start] is not None:
        return [] if assign[start] == image else None
    if used[image] is not None:
        return None
    added = [start]
    assign[start] = image
    used[image] = start
    frontier = [start]
    while frontier:
        x = frontier.pop()
        y = assign[x]
        for (_, f), (_, g) in zip(source.ops, target.ops):
            fx, gy = f[x], g[y]
            current = assign[fx]
            if current is None:
                if used[gy] is not None:
                    for state in added:
                        used[assign[state]] = None
                        assign[state] = None
                    return None
                assign[fx] = gy
                used[gy] = fx
                added.append(fx)
                frontier.append(fx)
            elif current != gy:
                for state in added:
                    used[assign[state]] = None
                    assign[state] = None
                return None
    return added


def find_conjugacy(
    source: Family,
    target: Family,
    *,
    all_solutions: bool = False,
    limit: int = WITNESS_LIMIT,
) -> tuple[list[tuple[int, ...]], int, tuple[int, ...], bool]:
    """Exact search.  Returns (witnesses, branches, generators, capped).

    Determinism does the heavy lifting: fixing ``p`` on one state forces it on
    that state's whole forward orbit, so the only real choices are the images
    of a minimum generating set.  Colour refinement prunes those choices.
    """
    if source.n != target.n or source.labels != target.labels:
        return [], 0, (), False
    n = source.n
    left, right, _ = refinement_colours(source, target)
    candidates_by_colour: dict[int, list[int]] = defaultdict(list)
    for y in range(n):
        candidates_by_colour[right[y]].append(y)
    roots = generating_states(source)
    assign: list[int | None] = [None] * n
    used: list[int | None] = [None] * n
    found: list[tuple[int, ...]] = []
    branches = 0
    capped = False

    def descend(depth: int) -> bool:
        """Returns True when the caller should stop (found enough)."""
        nonlocal branches, capped
        if depth == len(roots):
            if any(v is None for v in assign):
                return False
            witness = tuple(assign)  # type: ignore[arg-type]
            if not conjugates(witness, source, target):
                raise RelabelingError("internal: propagation accepted a non-conjugacy")
            found.append(witness)
            if not all_solutions or len(found) >= limit:
                capped = all_solutions and len(found) >= limit
                return True
            return False
        root = roots[depth]
        if assign[root] is not None:
            return descend(depth + 1)
        for image in candidates_by_colour[left[root]]:
            branches += 1
            added = _propagate(source, target, assign, used, root, image)
            if added is None:
                continue
            if descend(depth + 1):
                return True
            for state in added:
                used[assign[state]] = None
                assign[state] = None
        return False

    descend(0)
    return found, branches, roots, capped


def simultaneous(source: Family, target: Family) -> Verdict:
    """Decide whether one shared bijection relabels the whole family."""
    if source.n != target.n:
        return Verdict(False, None, "state counts differ", "shape", 0)
    if source.labels != target.labels:
        return Verdict(
            False,
            None,
            (
                f"labels are paired positionally by name: {source.labels} against "
                f"{target.labels}. Align them with Family.with_labels before asking; "
                "this is not a conjugacy answer"
            ),
            "shape",
            0,
        )
    screen = screens(source, target)
    if not screen["all_pass"]:
        failed = [key for key in SCREEN_NAMES if not screen[key]]
        return Verdict(False, None, "screen: " + ", ".join(failed), "screen", 0)
    found, branches, roots, _ = find_conjugacy(source, target)
    if found:
        return Verdict(True, found[0], None, "closure-search", branches, roots)
    return Verdict(
        False,
        None,
        f"exhaustive search over images of {len(roots)} generating state(s) found none",
        "closure-search",
        branches,
        roots,
    )


def independent(source: Family, target: Family) -> dict:
    """Relabel each operation on its own.  A much weaker question.

    Returns one witness per label, plus the connectors that a chain would have
    to pay between consecutive operations if only these separate relabelings
    exist.  A connector different from the identity is recurring work per
    operation, which is exactly what simultaneous conjugacy removes.
    """
    if source.n != target.n or source.labels != target.labels:
        return {"all_conjugate": False, "reason": "incomparable families"}
    per_label = {}
    for label in source.labels:
        one_source = Family(source.n, ((label, source.table(label)),))
        one_target = Family(target.n, ((label, target.table(label)),))
        per_label[label] = simultaneous(one_source, one_target)
    all_ok = all(v.conjugate for v in per_label.values())
    result = {
        "all_conjugate": all_ok,
        "witnesses": {k: v.witness for k, v in per_label.items()},
        "obstructions": {k: v.obstruction for k, v in per_label.items() if not v.conjugate},
    }
    if all_ok:
        identity = tuple(range(source.n))
        connectors = {}
        for a in source.labels:
            for b in source.labels:
                connector = compose(per_label[b].witness, invert(per_label[a].witness))
                connectors[f"{a}->{b}"] = {
                    "map": connector,
                    "is_identity": connector == identity,
                }
        result["connectors"] = connectors
        result["all_connectors_identity"] = all(
            c["is_identity"] for c in connectors.values()
        )
    return result


def separates(source: Family, target: Family) -> bool:
    """True when every operation is separately conjugate but the family is not."""
    if not independent(source, target)["all_conjugate"]:
        return False
    return not simultaneous(source, target).conjugate


# --------------------------------------------------------------------------
# brute-force reference
# --------------------------------------------------------------------------


def brute_force(source: Family, target: Family, *, all_solutions: bool = False):
    """Every permutation, tested.  The reference the fast search is checked against."""
    if source.n > BRUTE_FORCE_LIMIT:
        raise RelabelingError(
            f"brute force refuses {source.n} states; the limit is {BRUTE_FORCE_LIMIT}"
        )
    if source.n != target.n or source.labels != target.labels:
        return [] if all_solutions else None
    out = []
    for p in permutations(range(source.n)):
        if conjugates(p, source, target):
            if not all_solutions:
                return p
            out.append(p)
    return out if all_solutions else None


def automorphisms(family: Family, *, limit: int = WITNESS_LIMIT):
    """All bijections commuting with every transition.  Witnesses form its coset."""
    found, _, _, capped = find_conjugacy(family, family, all_solutions=True, limit=limit)
    return found, capped


def all_witnesses(source: Family, target: Family, *, limit: int = WITNESS_LIMIT):
    """Every conjugating bijection, up to ``limit``.

    The solution set is either empty or a left coset ``p0 . Aut(source)``, so
    its size is the automorphism count of the source family.
    """
    found, _, _, capped = find_conjugacy(source, target, all_solutions=True, limit=limit)
    return found, capped


# --------------------------------------------------------------------------
# restricted relabeling classes
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Class:
    """A set of permutations a machine can actually apply at a boundary."""

    name: str
    n: int
    contains: object  # callable: permutation -> bool
    size: int | None
    enumerate_all: object | None = None  # callable: () -> iterator of permutations

    def holds(self, p: tuple[int, ...]) -> bool:
        return bool(self.contains(p))


def _bits(x: int, width: int) -> tuple[int, ...]:
    return tuple((x >> i) & 1 for i in range(width))


def _is_gf2_affine(p: tuple[int, ...], width: int) -> bool:
    c = p[0]
    linear = [p[x] ^ c for x in range(1 << width)]
    basis = [linear[1 << i] for i in range(width)]
    for x in range(1 << width):
        expected = 0
        for i in range(width):
            if (x >> i) & 1:
                expected ^= basis[i]
        if linear[x] != expected:
            return False
    return True


def _gf2_matrices(width: int):
    """All invertible width x width GF(2) matrices, as column-image tuples."""
    size = 1 << width
    def extend(chosen: tuple[int, ...], span: frozenset):
        if len(chosen) == width:
            yield chosen
            return
        for value in range(1, size):
            if value in span:
                continue
            fresh = set(span)
            for s in span:
                fresh.add(s ^ value)
            yield from extend(chosen + (value,), frozenset(fresh))
    yield from extend((), frozenset({0}))


def gf2_affine(width: int) -> Class:
    n = 1 << width
    order = 1
    for i in range(width):
        order *= (1 << width) - (1 << i)

    def enumerate_all():
        for columns in _gf2_matrices(width):
            base = [0] * n
            for x in range(n):
                acc = 0
                for i in range(width):
                    if (x >> i) & 1:
                        acc ^= columns[i]
                base[x] = acc
            for shift in range(n):
                yield tuple(v ^ shift for v in base)

    return Class(
        f"gf2_affine(w={width})",
        n,
        lambda p: _is_gf2_affine(p, width),
        order * n,
        enumerate_all,
    )


def gf2_linear(width: int) -> Class:
    n = 1 << width
    order = 1
    for i in range(width):
        order *= (1 << width) - (1 << i)

    def enumerate_all():
        for columns in _gf2_matrices(width):
            base = [0] * n
            for x in range(n):
                acc = 0
                for i in range(width):
                    if (x >> i) & 1:
                        acc ^= columns[i]
                base[x] = acc
            yield tuple(base)

    return Class(
        f"gf2_linear(w={width})",
        n,
        lambda p: p[0] == 0 and _is_gf2_affine(p, width),
        order,
        enumerate_all,
    )


def bit_permutation(width: int) -> Class:
    n = 1 << width

    def build(order: tuple[int, ...]) -> tuple[int, ...]:
        out = []
        for x in range(n):
            y = 0
            for i in range(width):
                if (x >> i) & 1:
                    y |= 1 << order[i]
            out.append(y)
        return tuple(out)

    table = {build(order) for order in permutations(range(width))}

    def enumerate_all():
        yield from sorted(table)

    import math

    return Class(
        f"bit_permutation(w={width})",
        n,
        lambda p: tuple(p) in table,
        math.factorial(width),
        enumerate_all,
    )


def xor_translation(width: int) -> Class:
    n = 1 << width

    def enumerate_all():
        for c in range(n):
            yield tuple(x ^ c for x in range(n))

    return Class(
        f"xor_translation(w={width})",
        n,
        lambda p: all(p[x] == x ^ p[0] for x in range(n)),
        n,
        enumerate_all,
    )


def modular_affine(m: int) -> Class:
    units = [a for a in range(m) if gcd(a, m) == 1]

    def enumerate_all():
        for a in units:
            for b in range(m):
                yield tuple((a * x + b) % m for x in range(m))

    def contains(p: tuple[int, ...]) -> bool:
        b = p[0]
        if m == 1:
            return True
        a = (p[1] - b) % m
        if gcd(a, m) != 1:
            return False
        return all(p[x] == (a * x + b) % m for x in range(m))

    return Class(f"modular_affine(m={m})", m, contains, len(units) * m, enumerate_all)


def symmetric(n: int) -> Class:
    import math

    return Class(
        f"symmetric(n={n})",
        n,
        lambda p: sorted(p) == list(range(n)),
        math.factorial(n),
        lambda: permutations(range(n)),
    )


def conjugate_in_class(
    source: Family,
    target: Family,
    cls: Class,
    *,
    witness_limit: int = WITNESS_LIMIT,
) -> Verdict:
    """Is there a conjugating bijection *inside* a cheaply implementable class?

    Two exact routes, whichever bounds smaller.  Enumerating the witnesses of
    the unrestricted problem and testing membership is cheap when the source
    family is rigid; otherwise the class itself is enumerated.
    """
    if source.n != cls.n or target.n != cls.n:
        return Verdict(False, None, "class is built for a different state count", "shape", 0)
    found, capped = all_witnesses(source, target, limit=witness_limit)
    if not capped:
        if not found:
            return Verdict(
                False,
                None,
                "no bijection at all relabels this family",
                "witness-coset",
                0,
            )
        for p in found:
            if cls.holds(p):
                return Verdict(True, p, None, "witness-coset", len(found))
        return Verdict(
            False,
            None,
            (
                f"all {len(found)} relabeling(s) exist outside {cls.name}; "
                "the unrestricted answer is yes and the restricted answer is no"
            ),
            "witness-coset",
            len(found),
        )
    if cls.enumerate_all is None:
        raise RelabelingError(f"{cls.name} cannot be enumerated and the witness set was capped")
    tried = 0
    for p in cls.enumerate_all():
        tried += 1
        if conjugates(p, source, target):
            return Verdict(True, tuple(p), None, "class-enumeration", tried)
    return Verdict(False, None, f"no member of {cls.name} conjugates", "class-enumeration", tried)


# --------------------------------------------------------------------------
# chain semantics: what a shared relabeling actually buys
# --------------------------------------------------------------------------


def extend(family: Family, *ops: tuple[str, tuple[int, ...]]) -> Family:
    """Append operations to a family, keeping the existing ones in order."""
    return Family(family.n, family.ops + tuple((name, tuple(t)) for name, t in ops))


def witness_survival(
    source: Family,
    target: Family,
    consumers: list[tuple[str, tuple[int, ...], tuple[int, ...]]],
    *,
    limit: int = WITNESS_LIMIT,
) -> dict:
    """Does a relabeling found for the producers survive the consumers?

    Adding an operation to both families can only remove conjugating
    bijections, never add one, because every constraint of the smaller problem
    is still present in the larger one.  So the useful question is not whether
    a relabeling exists for the producers -- it is how much of that witness set
    is still standing once each downstream operation has to hold as well.

    ``consumers`` is a list of ``(label, source table, target table)``.  They
    are added one at a time and the surviving witness set is reported after
    each, together with the first consumer that empties it.
    """
    base, capped = all_witnesses(source, target, limit=limit)
    stages = [
        {
            "after": "producers only",
            "labels": list(source.labels),
            "witnesses": len(base),
            "capped": capped,
        }
    ]
    survivors = list(base)
    grown_source, grown_target = source, target
    died = None
    for label, left, right in consumers:
        grown_source = extend(grown_source, (label, left))
        grown_target = extend(grown_target, (label, right))
        survivors = [
            p for p in survivors if all(p[left[x]] == right[p[x]] for x in range(source.n))
        ]
        stages.append(
            {
                "after": label,
                "labels": list(grown_source.labels),
                "witnesses": len(survivors),
                "capped": capped,
            }
        )
        if not survivors and died is None:
            died = label
    return {
        "producer_witnesses": len(base),
        "producer_witness_count_capped": capped,
        "stages": stages,
        "surviving_witnesses": [list(p) for p in survivors],
        "first_consumer_with_no_surviving_relabeling": died,
        "label_persists_through_every_consumer": bool(survivors) and not capped,
        "note": (
            "adding operations can only remove witnesses, so this sequence is "
            "non-increasing; a relabeling that survives to the end is one output "
            "labeling valid for the whole region, producers and consumers together"
        ),
    }


def run_chain(family: Family, letters: str | tuple[str, ...], state: int) -> int:
    for letter in letters:
        state = family.table(letter)[state]
    return state


def chain_agrees(
    source: Family,
    target: Family,
    p: tuple[int, ...],
    letters: str | tuple[str, ...],
) -> bool:
    """One encode, the whole chain in the target family, one decode."""
    q = invert(p)
    return all(
        q[run_chain(target, letters, p[x])] == run_chain(source, letters, x)
        for x in range(source.n)
    )


def chain_collapses(target: Family, letters: str | tuple[str, ...]) -> tuple[int, ...] | None:
    """Does a whole word in the target family equal one of its single letters?"""
    composite = target.word(letters)
    for label in target.labels:
        if target.table(label) == composite:
            return composite
    return None
