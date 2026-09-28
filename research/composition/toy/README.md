# Composition toy: a representation change that loses locally and wins over seven stages

A runnable model of one question. When does changing representation pay for itself, and what stops
the win from growing with the chain? The arithmetic is exact and small enough to check by
enumeration. The cost model is invented for this toy.

## The problem

Two nonnegative accumulators start at an unknown state. One bit per lane, `x0` and `y0` in
`{0, 1}`, arriving as input alongside the digits. A stage adds one digit to each accumulator, both
drawn from `{0, 1, 2}`, so a chain of `n` stages has `4 * 9^n` possible inputs.

The packed representation puts both accumulators in one byte as `x + 16*y`, and a packed stage is a
single byte add of `a + 16*b`. The lanes stay independent while neither exceeds 15. After `n`
stages a lane can hold `1 + 2n`, so seven stages reach 15 and every packed stage up to stage 7
decodes exactly. At stage 8 a lane can reach 17. In the low lane that carries into the high nibble
and destroys the decoding; in the high lane the encoding leaves the byte.

The unknown initial bits are what make the entry a real operation. With a constant start, a
lowering could fold the pack away, and the cost boundary would move. That case is kept as a
separate variant rather than mixed into the main model.

## Cost model

Synthetic gateway charges, not instruction counts:

| operation | cost |
| --- | --- |
| ordinary stage (two separate adds) | 2 |
| packed stage (one byte add) | 1 |
| enter the packed representation | 3 |
| exit the packed representation | 3 |

The dynamic digits and their packed form `a + 16*b` are common inputs to both lowerings. Producing
them sits outside the toy. That is an assumption of the model, not a claim that packing inputs is
free in a real FFN.

A packed interval of length `k` from the entry state costs `k + 6` against `2k`, so it ties at 6
and first wins at 7. One unit, once.

## What the toy shows

Run `python3 check.py` in this directory. It prints 16 checks and rewrites
[`result.json`](result.json).

Greedy lowering never enters. Looking one stage ahead, an ordinary stage costs 2 while entering and
running one packed stage already costs 4, and the exit is still owed. The pass has to compare whole
intervals of length 7 before entering looks cheaper, and `greedy_entry_horizon` in the result
confirms 7 is the smallest lookahead that finds it. Global search over `(stage, representation)`
nodes finds the 7-stage interval at cost 13 against 14.

Validity is a precondition on the edge, not a cost. `packed_stage_valid` asks whether every
reachable state at that stage survives every digit pair, which is why the search refuses the
8-stage packed plan even though it would price at 14 and beat the valid 15. Turning the
precondition off (`search(8, COST, enforce_validity=False)`) returns exactly that wrong plan, which
is the failure mode a cost-only lowering has.

At length 8 the answer is a packed prefix of 7 followed by an ordinary stage, 15 against 16.

Headroom, not cost, caps the win. Entering later means entering with a worse worst case: after `j`
ordinary stages a lane can already hold `1 + 2j`, so the longest valid packed run from stage `j` is
`7 - j`, and a run shorter than 7 never pays for its two boundaries. From stage 7 on, no packed
stage is valid at all. So one interval at the front is the only one that ever pays, and the saving
stays at exactly 1 unit for every chain length from 7 upward. `reentry_headroom` in the result
tabulates the run length and the saving for each entry stage.

## Counterexamples kept explicit

Initial `(1, 0)` with eight `(2, 0)` stages gives the true state `(17, 0)`; the packed byte is 17
and decodes to `(1, 1)`. Initial `(0, 1)` with eight `(0, 2)` stages gives `(0, 17)`, whose
unbounded encoding is 272. The byte addition wraps it to 16, which decodes to `(0,1)`.
Both are in `counterexamples` in the result, with the initial state and the digits.

The boundary is narrow. A lane breaks only when `x0 + sum(digits) > 15`, which happens for 10 of
its `2 * 3^8 = 13122` inputs: all eight digits 2 from either start, or seven 2s and one 1 from
start 1. Across both lanes that is 262340 of 172186884 inputs of length 8.
`lane_overflow_counts` gets the 10 from a sum DP and the checks cross-check it against brute-force
enumeration of one lane. The same independence is why the search works over reachable states
instead of inputs: the reachable set after `k` stages is `[0, 1 + 2k]^2`, at most 256 states inside
the encodable region.

## The constant-folding variant

`constant_folding_variant` in the result records the other model: initial state the known constant
`(0, 0)`, entry folded to 0. There the first win is 4 stages, not 7. The main model does not admit
that fold, and `CostModel.enter_cost` only returns 0 when the reachable entry set is a single
state, so the two cases cannot be confused by flipping a cost.

## Scope

This is an architecture test of how representation changes compose, aimed at one question: whether
cheapest-node lowering can find an interval win that no local step sees, and what limits the
interval. It proves nothing about native optimality, says nothing about real instruction costs, and
claims no FFN speedup. [CompositionCost.lean](../../../Kelana/CompositionCost.lean)
proves the best schedule for every chain length in this fixed cost and validity model, without
enumerating schedules. [PackedChains.lean](../../../Kelana/PackedChains.lean) proves the
encoding's exact capacity boundary.

## Files

- [`toy.py`](toy.py): arithmetic, encoding, reachable-state DP, validity preconditions, cost model,
  global search, greedy lowering.
- [`check.py`](check.py): the checks and the result writer.
- [`result.json`](result.json): cost table, boundary edges with counterexamples, re-entry headroom,
  check outcomes.
