# Optimality certificates for a bounded finite machine

This directory proves that particular programs are optimal, and that particular
observations are impossible, over a **complete** program space rather than over
programs shorter than some depth. The proof ships as a file. A checker that
knows nothing about how the search ran reads that file and decides the claim.

Everything here is relative to a declared register width, a declared instruction
set and declared abstract charges. None of it measures gfx1151 or any other real
machine, and the costs are not cycles.

## The machine and what counts as state

A machine state is the whole register file: `registers` registers of `width`
bits. The input sits in `r0` at the start and the remaining registers start at 0.
Each instruction is a total map on the machine state set, written as an explicit
table. There is no memory, no flag, and no branch.

The state includes the input until an instruction overwrites it. That is not a
detail. A program that leaves `x` in a register has kept every distinction `x`
carries, and several contracts below become trivial because of it.

The search runs over *semantic states*, which is the register file of every
declared input at once, so a semantic state is a map `domain -> machine state`.
A straight-line program prefix is described completely by its semantic state, and
the set of semantic states is finite. Three machines appear here:

| id | registers | width | input domain | semantic states |
| --- | ---: | ---: | --- | ---: |
| M1 | 2 | 2 | all four 2-bit values | 65,536 |
| M2 | 2 | 2 | signed trit codes 0, 1, 3 for 0, +1, -1 | 4,096 |
| M3 | 3 | 2 | the same trit codes | 262,144 |

M2 declares code 2 outside the input domain, so nothing constrains the machine on
it. That is the usual situation for a packed operand contract.

## The observation contract is a parameter, not a convention

Four contracts appear in the certificates, all reading one register at the end.

- `exact`: the observed register holds the target value for every input.
- `cleared`: `exact`, and every other register ends at 0. This prices the output
  interface. Erasing input-dependent residue is work, and the certificates below
  show it changing both the optimum and the optimal program.
- `relabeled`: the observed register has exactly the target's fibers. Any
  bijection of the output labels is accepted, and no intermediate has to be
  recoverable.
- `refines`: the observed register merely separates inputs the target separates,
  so a decoder exists.

A separate `through` clause can force the program to hold a named intermediate in
some register at some step. That is how "preserve this familiar value" gets a
price.

## The certificate

Two potentials carry the whole argument. Both are integer functions on semantic
states with infinity allowed.

A forward potential `g` satisfies `g[init] = 0`, `g >= 0`, and
`g[T_i(s)] <= g[s] + charge_i` for every state `s` and instruction `i`.
Telescoping along any program gives `cost >= g[final state]`, so reaching a set
`A` costs at least `min_{s in A} g[s]`. When that minimum is infinite, no program
of any length reaches `A`. One forward potential prices every query on its
machine at once, which is why the certificates are not per target.

A backward potential `p` for a goal set `G` satisfies `p >= 0`, `p = 0` on `G`,
and `p[s] <= charge_i + p[T_i(s)]`. Then `cost >= p[s]` for any program from `s`
into `G`. A program forced through a waypoint set `W` splits at its first `W`
state, so it costs at least `min_{s in W} (g[s] + p[s])`. Waypoints therefore
need no extra state axis.

I picked this over one Bellman potential per target because it scales better and
because the feasibility conditions are three inequalities a reader can check by
eye. Any feasible potential is sound; the search happens to emit the exact
distances, which is what makes the bounds tight.

### Coefficients on instruction counts

The same two potentials bound instruction *counts*. The inequality carries no
charges, but its coefficients are derived under a charged budget, and the charges
stay load-bearing.

A run of cost at most C that takes instruction j at state s costs at least
`g[s] + charge_j + p[T_j(s)]`, so every step it takes satisfies that sum <= C.
That is where the charges enter. Widen C and more steps qualify, the coefficients
grow, and the cut weakens. Let `A_j` be the largest drop `p[s] - p[T_j(s)]` over
the steps of j that fit the budget. The drops along the run telescope to
`p[init]`, so

```
sum_j A_j n_j  >=  p[init]
```

for any accepting run within budget C. An instruction with no step fitting the
budget has `n_j = 0`. The result constrains counts rather than cost, which is
what lets a consumer with a different charge model use it, but only for programs
inside the budget it was derived under. Nothing in it appeals to a count of
source operations.

I got the corridor wrong at first and used `g[s] + p[s] <= C`, dropping the
charge of the step itself. That gave a maximum drop of 2 almost everywhere and
cuts too weak to say anything. Putting `charge_j` back inside the budget is what
makes them sharp.

`check.py` recomputes `A_j` and rejects a declared drop that is too small, or a
family declared absent while a step for it fits.

`check.py` re-derives every instruction table from its name, re-derives the
declared grammar from its id, re-derives each goal set from its contract,
verifies both potentials against the transition relation, and replays each
witness program. A claim survives only when the replayed cost equals the
recomputed bound. It imports nothing from the search, and it has its own copy of
the instruction semantics so it cannot inherit a generator bug.

Every scalar it reads must already be a JSON integer. There is no `int()`
coercion anywhere in the checker, so `2.0` and `true` are rejected rather than
quietly accepted as 2 and 1. Duplicate backward ids, duplicate claim names and
references to absent potentials are rejected too, because a repeated key would
let one entry silently win and change what a reference means.

Seventeen tamper cases in `test_finite_machine.py` cover understated charges,
dropped instructions, rewritten tables, inflated potentials, edited witnesses,
witnesses that skip their waypoint, false impossibility claims, understated
instruction drops, a family declared absent while a step for it fits the budget,
an inflated length bound, floats and bools in fourteen numeric positions,
duplicate ids and names, dangling references, and missing fields.

## Joint terminal observations

[Two outputs from one packed word](MULTI-OUTPUT.md) now have a checked complete-state bound. On M1, exact AND in `r0` and XOR in `r1` cost four abstract instructions together, against three plus two separately. Reverse their register positions and the optimum is five. Scaled AND and OR also cost four together against six separately. The 65,536-state certificate prices both observed registers, so it neither reconstructs source bits nor grants a free output permutation. Its optimal-budget count cuts reduce the AND/XOR search to `and`, `shri`, `sub`, and the scaled-AND/OR search to `add`, `or`, `shri`, `sub`. These are finite-machine charges, not native cycles.

## Representation freedom beats the familiar intermediate

Every row is exact and complete for its machine and grammar.

| target | free optimum | forced through | cost | program the search returns |
| --- | ---: | --- | ---: | --- |
| M1 `b1 xor b0` | **2** | `b0 + b1` | 4 | `addi r0 1 ; shri r0 1` |
| M1 `b1 == b0` | **2** | `b0 + b1` | 5 | `addi r0 3 ; shri r0 1` |
| M1 `2*(b1 and b0)` | **3** | `b1 and b0` | 4 | `sub r1 r0 ; and r1 r0 ; sub r0 r1` |
| M1 `2*(b1 and b0)` | **3** | `b1 nand b0` | 6 | as above |
| M2 `relu(t)` | **2** | `-t` | 3 | `addi r0 1 ; shri r0 1` |
| M2 `relu(t)` | **2** | `t < 0` | 3 | as above |

The `2*(b1 and b0)` row is the sharpest statement in the directory. Computing the
scaled conjunction costs 3. Requiring the unscaled conjunction to exist in a
register at any point during the computation costs 4. The recognizable value is
not on any optimal path, and this is a proof, not a failure to find one.

XOR in two instructions is my favourite. `x+1` then `x >> 1` never forms either
input bit, never forms their sum, and the two-instruction bound says nothing
cheaper exists at any length. The same two instructions compute `relu` of a trit
on M2. One program, two declared domains, two functions nobody would call
related.

Output labels are worth the same kind of freedom. On M2 the indicator of `t != 0`
coded as `{0, 3}` costs 2 and leaves `-t` in the scratch register. The same
partition coded as `{0, 1}` costs 1, with `andi r0 1`. If the consumer accepts
any injective relabeling, half the work disappears.

## What an optimal program is allowed to contain

The count cuts narrow the optimal programs to a short instruction vocabulary.
Each row holds for every accepting program within the stated cost budget.

| target | budget | instructions at least | opcodes that can appear at all |
| --- | ---: | ---: | --- |
| M1 `b1 xor b0` | 2 | 2 | `addi`, `shri` |
| M1 `b1 == b0` | 2 | 2 | `addi`, `shri` |
| M2 `relu(t)` | 2 | 2 | `addi`, `shri` |
| M2 `t != 0` as `{0,3}` | 2 | 2 | `or`, `sub` |
| M1 `2*(b1 and b0)` | 3 | 3 | 12 of 16, excluding `andi`, `mul`, `muli`, `shri` |

Fourteen of the sixteen opcode families appear in no cost-2 program for XOR, and
the two survivors are exactly the two the witness uses. The `nonzero` row is the
one I would not have guessed: its only cost-2 programs are built from `or` and
`sub`, and the cheap-looking `andi r0 1` route is a full charge more expensive
because it lands on the wrong output labels.

## Retained input, and the price of the output interface

Two rows in `m2-trit.cert.json` exist to keep the contract honest.

`negate-relabeled-by-retained-input` costs 0. Negation is injective on three
states, `r0` already holds the input, so the empty program satisfies a
fibers-only contract. `xor-refined-by-retained-input` costs 0 on M1 for the same
reason. A carrier that "preserves the information" is free whenever the input
survives, so sufficiency alone never justifies a representation.

`nonzero` costs 2 and its optimal program leaves `-t` in `r1`. Under `cleared`
the optimum rises to 3 and the program changes completely, to
`andi r0 1 ; not r0 ; addi r0 1`, which never touches `r1`. On M1, `and` costs 3
free and 4 cleared. Retained input-dependent registers are part of the state, and
handing back a clean register file costs one charge here.

## Impossible observations and excluded instruction families

Restricting the grammar closes the reachable set, and the certificate reports
that closure as impossibility at every program length.

| grammar | excluded | instructions | reachable states on M1 | observable functions |
| --- | --- | ---: | ---: | ---: |
| `full` | nothing | 68 | 65,536 / 65,536 | 256 / 256 |
| `nomul` | multiply by register or immediate | 58 | 65,536 / 65,536 | 256 / 256 |
| `noshr` | right shift | 66 | 4,096 / 65,536 | 64 / 256 |
| `monotone` | complement, xor, carry arithmetic | 34 | 1,120 / 65,536 | 36 / 256 |
| `affine` | every bitwise op and register multiply | 32 | 256 / 65,536 | 16 / 256 |

Each count matches an invariant that can be stated independently, which is the
reassuring part.

- `noshr` keeps bit 0 of every register a function of bit 0 of the input, so `b1`
  is unobservable and exactly 64 functions survive. `m1-noshr.cert.json` proves
  `b1` impossible and prices the control `2*b0` at 1.
- `monotone` leaves each output bit a monotone Boolean function of the two input
  bits. There are 6 of those, and 6 squared is 36. The complement of the input is
  impossible; `or` remains possible at 4, one more than its cost of 3 under
  `full`.
- `affine` leaves every register holding `a*x + b` mod 4, which is 4 slopes times
  4 intercepts for each of two registers, so 256 semantic states and 16
  observations. `b0` is impossible; negation still costs 2.

The interesting failure is `nomul`. Deleting both multiplies changes no optimum
and no reachable observation on either machine. The family is redundant under
these charges, and paying 3 for it was never worth it. A bounded negative, but a
real one.

`monotone` also has the worst optimum in the table at 6, above `full`'s 5,
despite reaching 58 times fewer states. Fewer instructions can mean longer
optimal programs for what remains reachable.

## Scaling

M3 adds a third register: 123 instructions, 262,144 semantic states, all of them
reachable, built and searched in 0.3 s. It lowers none of the M2 optima and makes
no new function observable. For this domain the second register is already
enough, which the census records as two empty lists.

The dense transition tables dominate everything else. They cost
`instructions * semantic_states * index_width` bytes, and semantic states are
`state_count ** inputs`. Indices use the narrowest unsigned type that fits.

| machine | semantic states | instructions | tables | one potential |
| --- | ---: | ---: | ---: | ---: |
| M1 | 65,536 | 68 | 8.9 MB | 66 KB |
| M3 | 262,144 | 123 | 129 MB | 262 KB |
| 3 bits, 2 registers, 4 inputs | 16,777,216 | 120 | 8.05 GB | 16.8 MB |

M3 peaks at 164 MiB resident. The 3-bit row is the wall, and the potential file
is not what breaks it. The tables are 480 times larger.

I called that a representation problem in the first draft. It is not. Two
algorithms are available and they differ in work, not just in encoding. The
current one materializes each instruction's successor array over the whole
semantic space and then runs Dial's algorithm at one gather per edge. The
alternative keeps only the reachable set in a sorted array and recomputes
successors from the per-machine-state tables, which have `2 ** (registers*width)`
entries and stay small at every size here. That replaces the gather with `inputs`
divisions and a binary search per edge, so expect roughly an order of magnitude
more time per edge in exchange for memory proportional to the reachable set
rather than to the whole space. I have not implemented or measured it, so the
crossover point is a guess, and it only pays when the reachable set is a small
fraction of the space. On M1 and M3 under `full` the reachable set is everything,
where it would lose.

## Running it

```sh
python3 experiments.py          # 0.9 s, writes results/
python3 check.py results/*.cert.json   # 0.4 s, verifies every claim
python3 test_finite_machine.py  # 0.6 s, 24 tests
```

`check.py` needs only a certificate and numpy. Decoding a potential by hand is
one line: `np.frombuffer(base64.b64decode(block["u8"]), dtype=np.uint8)`, with
255 meaning infinity.

| file | contents |
| --- | --- |
| [`machine.py`](machine.py) | machine, instruction semantics, charges, grammars, contracts |
| [`certify.py`](certify.py) | Dijkstra, value iteration, witness extraction, certificate assembly |
| [`check.py`](check.py) | standalone checker with independent semantics |
| [`experiments.py`](experiments.py) | the declared experiments and the census |
| [`test_finite_machine.py`](test_finite_machine.py) | checker independence and tamper rejection |
| [`results/*.cert.json`](results) | certificates, 25 to 369 KiB each |
| [`results/census.json`](results/census.json) | per-grammar reachability, named costs, third-register comparison |

## Scope

Every number is relative to the width, the instruction set and the charge table
in `machine.py`. Change any of the three and the optimum changes. Nothing here is
a statement about gfx1151, about any real instruction's latency, or about a
program written for a wider machine.

The model has no branch, no memory and no loop instruction. Straight-line
programs are covered at every length because the potential covers every semantic
state, and a loop with no data-dependent exit unrolls into one. A data-dependent
branch splits the input domain and is outside the transition structure used here.

The charges are abstract positive integers. Multiply costs 3 and everything else
costs 1, which is a guess, not a measurement. The `nomul` result says that guess
never mattered on these machines, which also means these machines cannot validate
a charge model.

Open, and worth doing in this order:

1. Wider registers. 3 bits with four inputs needs a sparse reachable-set search
   and a smaller potential encoding. The Dijkstra is not the problem.
2. More than one input register, so genuinely two-operand functions get priced
   rather than two bits of one word.
3. Several observations from one run, which is where a shared representation
   should start paying and where the single-observation contracts here say
   nothing.
4. A memory or lane-permutation instruction family, which is what would connect
   these bounds to the packed-observer work rather than to bit tricks on 2-bit
   words.
