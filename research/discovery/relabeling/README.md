# Simultaneous relabeling of an operation family

A state relabeling is a bijection `p` of the state set.  It conjugates one
transition `f` into another `g` when `p(f(x)) = g(p(x))` everywhere.  The
question this directory answers exactly, on small state sets, is whether **one**
bijection does that for a whole labelled family at once.

That distinction is the point.  A shared relabeling lets a region pay `p` at
entry and `p⁻¹` at exit whatever `m` is, and the operations in between never
leave the new representation.  Separate per-operation relabelings leave a
connector `pᵢ₊₁ ∘ pᵢ⁻¹` at each internal boundary.  Those connectors are not
automatically expensive — a consumer that already accepts the previous
operation's labeling, or a connector folded into an adjacent operation, can
make them free — so the honest statement is that a shared relabeling
*guarantees* a constant boundary count without needing that luck, and the cost
model has to be told what a connector actually costs.  That is a parameter in
[`boundary.py`](boundary.py), not a constant.

The tools decide the question, produce a witness permutation or an exhaustive
obstruction, and price the witness instead of assuming a lookup table is free.

## What came out of it

**Per-operation invariants leave many families indistinguishable in these censuses.** The census
enumerates every family up to relabeling and groups the results by their
per-operation invariants.  Any two distinct orbits in one group are a pair
whose operations are individually interchangeable and whose families are not.

| states | ops | transitions | families | orbits | per-operation classes | orbits in a shared class | share | largest class |
| ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 3 | 2 | functions | 729 | 129 | 49 | 112 | 86.8% | 6 |
| 4 | 2 | functions | 65,536 | 2,836 | 324 | 2,797 | 98.6% | 55 |
| 5 | 2 | functions | 9,765,625 | 83,061 | 1,764 | 82,986 | 99.9% | 273 |
| 3 | 2 | permutations | 36 | 11 | 9 | 4 | 36.4% | 2 |
| 4 | 2 | permutations | 576 | 43 | 25 | 32 | 74.4% | 4 |
| 5 | 2 | permutations | 14,400 | 161 | 49 | 148 | 91.9% | 9 |
| 6 | 2 | permutations | 518,400 | 901 | 121 | 880 | 97.7% | 32 |
| 3 | 3 | permutations | 216 | 49 | 27 | 36 | 73.5% | 5 |
| 4 | 3 | permutations | 13,824 | 681 | 125 | 662 | 97.2% | 24 |
| 3 | 3 | functions | 19,683 | 3,303 | 343 | 3,272 | 99.1% | 36 |

Every row is a complete enumeration, and the orbit counts are checked against
Burnside's lemma computed a different way in the test suite.  At six states and
two permutations, 121 per-operation classes carry 901 genuinely different
families: knowing each instruction's transition structure leaves you a factor
of seven short of knowing the family's.

The ISA-shaped instance is three-bit words with *add 1* paired with *clear the
low bit*, against *add 3* paired with the same clear.  Both increments are
8-cycles, so in isolation a relabeling turns either into the other.  Holding
the clear fixed at the same time pins the relabeling, and then the two
increments are no longer interchangeable.  An instruction's identity is fixed
by the company it keeps.

**Per-word cycle types miss distinctions that pair refinement finds.** Take
`GL(3,2)` acting on the seven non-zero vectors of `GF(2)³`, and the same two
matrices acting on the dual space by inverse transpose.  Every group element
fixes the same number of points in both actions, because `rank(M − I) =
rank(Mᵀ − I)`, so the two permutation characters coincide; both actions are
transitive.  The exhaustive word search confirms the stronger statement
directly.

| screen | verdict |
| --- | --- |
| collision cardinalities | agree |
| per-operation functional graphs | agree |
| commutation pattern | agree |
| orbit and component structure | agree |
| cycle structure of every composite word, **at every length** | agree |
| colour refinement | agree |
| **pair (two-dimensional) refinement** | **rejects, after one round** |
| exhaustive search over all 5,040 bijections | no relabeling exists |

The word check is exhaustive rather than truncated: the search runs over pairs
of evaluated words, a finite closed set, and reports that no word of any length
separates the two families.  336 generating pairs of `GL(3,2)` have that
property.  Both families are ordinary bit-matrix multiplications.

The useful distinction is between these specific screens. Per-word cycle
types, collision counts and the recorded commutation pattern do not reject this
pair. This is not a claim about every possible statistic of the composite maps.
A screen that compares how states sit relative to each other does.  Pair refinement is what
separates them, and it only does so when colour *meanings* rather than local
colour indices are compared across the two families; comparing local palettes
reports a false agreement.  That correction is [`test_pair_palette.py`](test_pair_palette.py).

Under the corrected battery the census finds **no** tied pair at all: across
every row below, every pair of distinct orbits is rejected by some screen.
Whether pair refinement remains complete beyond six states and three
operations is open, and this directory does not claim it.

A second measurement counts what this word-only signature misses.  Sweeping the
census by word length, with only the composite-map invariants in play:

| rows | depth 1 | 2 | 3 | 4 | 5 | 6 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 6 states, 2 permutations (901 orbits) | 854 | 611 | 308 | 288 | 288 | 108 |
| 5 states, 2 permutations (161 orbits) | 139 | 54 | 12 | 12 | 12 | 10 |
| 4 states, 2 functions (2,836 orbits) | 2,707 | 1,859 | 1,040 | 1,024 | 1,024 | 1,024 |
| 3 states, 3 permutations (49 orbits) | 22 | 6 | 0 | 0 | 0 | 0 |

Those are orbits still sharing a word signature with a different orbit, so
still accepted by a word screen looking that deep.  A worked pair on six states
needs a word of length **seven** before it is rejected, and 1,024 of the
four-state function orbits are never rejected by a word screen at any depth.

**A shared relabeling can collapse a whole region, and the cheap ones are rare.**
Multiplication by `α¹`, `α³` and `α⁵` on the non-zero elements of `GF(2^w)` is
three separate carry-less multiplies with reduction.  The discrete logarithm
relabels all three at once into `+1`, `+3` and `+5` modulo `2^w − 1`.  The
search finds that relabeling without being told about the field.  Because the
target operations commute and compose inside themselves, a region of any length
collapses to a *single* addition when the word is fixed and its increment can
be prepared. The source region also collapses to one field multiplication by
a prepared constant. The example therefore establishes a structural change
between those two operations, not a speedup proportional to word length.
Zero is outside
the multiplicative group, so the relabeled state set has `2^w − 1` elements and
a machine boundary needs its own path for the missing one.

**Restricting the relabeling to bit-affine maps changes the answer.**
Multiplication by `α` and by `α³` on `GF(8)`, as permutations of the eight
states, are both order-7 with cycle type 7+1, so a bijection conjugates one to
the other — seven of them do.  No `GF(2)`-linear or affine one does, and not
because a search ran out: a linear conjugacy transports the minimal polynomial,
and `1 + x + x³` against `1 + x² + x³` rules it out.  All 168 matrices of
`GL(3,2)` and all 1,344 affine maps are excluded by that one identity.

The precise claim is about that class and no other: a bit-affine relabeling
does not exist.  Some other cheap map may; the seven relabelings that do exist
are priced below and the cheapest is a six-operation program in the declared
grammar, not a table.  Nothing here rules out a cheap relabeling outside the
affine class.

**A witness is not a saving.**  Relabeling a family of XOR-by-constant
operations by a bit rotation succeeds — 128 relabelings work — and produces
another family of XOR-by-constant operations.  The rotation class normalises
the operation class, so under equal per-operation charges the conjugate family
costs what the original cost and the profitable region length set is empty.
Structural match and cheap realisation are separate stages, and this directory
keeps them separate.

**A producer-side labeling can survive its consumers, or not.**  On a four-bit
word holding two two-bit lanes, the producers alone admit 128 relabelings.  One
downstream consumer, expressed in the relabeled world, cuts that to exactly
one, and two further consumers leave it standing: one labeling is valid for the
whole region, so the region ends where the consumer ends rather than at every
operation.  A consumer that insists on the original labeling — comparing a lane
against the literal `1`, when the relabeling sends 1 to 3 — leaves none.  That
is where a decode has to be charged.

## How the search works

Determinism does the work.  Fixing `p` on one state forces it on that state's
entire forward orbit, because `p(f(x)) = g(p(x))` determines `p` at `f(x)` as
soon as it is known at `x`.  So the only free choices are the images of a
minimum set of states whose forward closure is everything.

That set is computed exactly: condense the union of the transition graphs into
strongly connected components and take one state from each source component.
Choices are filtered by joint colour refinement, propagated, and checked for
injectivity as they go.  Typical families need one or two branch points.

The solution set is either empty or a left coset `p₀ · Aut(source)`, which the
tests verify directly.  That is what makes the restricted question cheap: to
ask whether an implementable relabeling exists, enumerate the witnesses and
test membership, and fall back to enumerating the class only when a symmetric
family has more witnesses than the cap.

Correctness is pinned down three ways: 1,680 random pairs are decided against
exhaustive enumeration of all `n!` permutations; witness sets are compared with
the exhaustive solution sets and with the automorphism coset; and the census
orbit counts are reproduced by Burnside's lemma.

## Pricing the boundary

A conjugacy result is only actionable once the boundary map has a price, and a
price is only meaningful under a stated model.  [`boundary.py`](boundary.py)
supplies one, and it makes no claim about any device.

The model has two halves.  A **declared grammar** of invertible operations on a
`w`-bit word: XOR and ADD by a constant, rotations, and the two triangular
`x ^= x << k` / `x ^= x >> k` mixes.  That is a choice, written down, not an
assertion that some machine has exactly these.  A **declared cost model**
assigns a charge to each operation family; the default is one unit per
operation, which makes a cost an operation count and nothing more.  A caller
with real charges supplies them and the same minimisation runs.

Given a permutation, the tool **synthesises a program** in that grammar by
meet-in-the-middle search from both ends, and re-executes the emitted program
on all `2^w` inputs before returning it.  So a reported cost is a checkable
fact with a witness attached:

| relabeling, four-bit words | synthesised program | operations |
| --- | --- | ---: |
| identity | (empty) | 0 |
| `x ^ 5` | `xor 5` | 1 |
| rotate left 1 | `rotl 1` | 1 |
| swap the two bit pairs | `rotl 2` | 1 |
| `7x + 2 mod 16` | `add 13`, `xor-shl 3`, `xor 7` | 3 |
| `3x mod 16` | `add 6`, `xor-shl 1`, `add 1`, `xor-shl 1`, `xor 13` | 5 |
| the GF(8) witness, three-bit words | `rotl 2`, `add 1`, `rotl 2`, `add 7`, `rotl 2`, `add 3` | 6 |

Those lengths are minima in the grammar, not upper bounds: the test suite
reproduces each one with an independent forward-only breadth-first search.

Every search is bounded and says so.  A permutation with no program inside the
cost bound is reported as **cost unknown**, never as expensive and never with
an invented number — most random 16-point permutations are in that state, and
the GF(16) family witness is too.  Witness selection minimises the round-trip
charge across the conjugating bijections rather than pricing whichever one the
search returned first, and when the witness set exceeds the examined cap, or a
witness has no program in bound, the result carries `optimal=False` and the
reason.

Region-length comparison reports the **whole** profitable interval over a
declared horizon, not a first crossing.  A scheme whose per-operation charge is
worse can still win over a short stretch and lose afterwards; that interval is
computed and reported as bounded rather than inferred from an asymptotic slope.
Under the declared model the amortised charge per operation is the target's own
for a shared relabeling, and `target + connector` for separate relabelings —
equal when the connector charge is zero.

What this model does not do: name machine instructions, claim occupied cycles,
or account for register pressure, hazards, addressing, masking, packing or
wait states.  A cost here bounds nothing about real hardware until someone maps
this grammar onto a device and prices that map.  Two cases are outside the
grammar entirely and report no cost rather than a guess: the discrete-logarithm
relabeling acts on `2^w − 1` states, which is not a power of two, and the
GF(16) family witness has no program within the searched bound.

## Files## Files

| file | contents |
| --- | --- |
| [`relabeling.py`](relabeling.py) | families, the exact search, witness enumeration, invariants, restricted classes, consumer survival |
| [`fields.py`](fields.py) | `GF(2^w)` arithmetic and `GL(w,2)` matrices as transition tables |
| [`boundary.py`](boundary.py) | declared grammar and cost model, program synthesis and verification, cheapest-witness selection, profitable-region intervals |
| [`census.py`](census.py) | exhaustive orbit census and the word-depth sweep, writes [`census.json`](census.json) |
| [`examples.py`](examples.py) | the named instances above, writes [`results.json`](results.json) |
| [`test_relabeling.py`](test_relabeling.py) | brute-force, Burnside and Lean-table cross-checks |
| [`test_pair_palette.py`](test_pair_palette.py) | regression for the pair-refinement palette comparison |
| [`test_boundary.py`](test_boundary.py) | grammar validity, synthesis minimality against an independent search, bound reporting |
| [`Relabeling.lean`](../../../Kelana/Relabeling.lean) | the composition laws and the concrete obstructions |

```sh
cd research/discovery/relabeling
python3 test_relabeling.py     # about 8 seconds
python3 -m unittest -q test_pair_palette test_boundary_contract
python3 test_boundary.py       # about 10 seconds
python3 test_pair_palette.py   # under a second
python3 examples.py            # a few seconds, rewrites results.json
python3 census.py              # lists its sections
python3 census.py orbits       # about 35 seconds
python3 census.py sweeps       # about 20 seconds
python3 census.py words        # about 30 seconds
```

Python 3's standard library is the only dependency.  The census runs in
sections because the whole of it exceeds a single bounded run; each section
rewrites its own part of `census.json` and leaves the others intact.

The Lean file proves that a shared relabeling carries an arbitrary word, that
one encode and one decode suffice for a whole region, that conjugacy is
`Composition.Simulates` with the graph of `p` as its relation, that adding
operations only removes witnesses, and that fixed points, commutation and
collisions transport.  It then proves the three obstructions directly: the
three-state and three-bit separations, the bit-linear impossibility by the
minimal-polynomial argument, and the `GL(3,2)` point/plane pair.  The last two
mirror the search rather than enumerating maps — the 7-cycle constraint reduces
`7⁷` candidates to seven.  The test suite reads the tables back out of the Lean
source and reruns the decisions here, so the two layers cannot drift apart
quietly.

## Boundaries of the claim

Relabelings here are bijections.  No states are identified, every fibre is a
single point, and nothing in this directory is a quotient or a decoder
construction — that is the subject of the observer and continuation work, and
the two compose in one direction: encode as quotient first, then relabel.

The census covers at most six states and three operations.  Nothing here
enumerates an instruction set, and no measurement of any device appears; the
cost model is a declared grammar with declared charges, and a program length in
it is not a cycle count.  A witness permutation is a structural result, useful
before any lowering exists.  Whether it can be applied cheaply is the separate
question `boundary.py` asks under a stated model, and the XOR example above is
a case where the structural answer is yes and the cost answer is nothing
gained.

Two further limits worth stating plainly.  Pair refinement rejects every
non-conjugate pair the census reaches, but that is a measurement over `n <= 6`
and `k <= 3`, not a completeness theorem.  And the grammar's reach is small: a
permutation needing more than six operations is reported as cost unknown, which
is honest but not informative, so a sharper bound on those cases is open.
