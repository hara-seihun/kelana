# Proving a program cannot be cheaper

This toolkit connects maps on complete machine states to conditional resource
lower bounds. It does not assume gate/up channels, individual trits, matrix
products or any other familiar intermediate must survive.

The key construction is a potential on machine states. If every successful
program starts with potential at least `b`, ends at most zero, and an instruction
of class `j` can decrease it by at most `a_j`, then every successful program has

```
Σ_j a_j n_j ≥ b.
```

The potential can increase along a program. Telescoping still works. This is a
way to derive necessary instruction-count inequalities from the actual target
and allowed transitions rather than count source operations and assume they
are unavoidable.

## What exists

- [Finite-machine certificates](finite-machine/README.md) search complete
  finite register-state spaces and produce independently replayed potentials
  and programs. They establish optima and impossibilities at every program
  length in their declared grammars. The [joint endpoint result](finite-machine/MULTI-OUTPUT.md)
  proves two packed-bit observations can share work and prices their register placement.
- [Exact resource checker](core/README.md) combines count inequalities with
  resource demands using rational dual certificates. A separate checker replays
  endpoint semantics, dependency readiness, port reservations and register
  allocation for supplied schedules.
- [Lean proofs](formal/README.md) establish the potential-to-count argument,
  resource weak duality, conditional optimality and strict domination. They
  also give counterexamples to adding overlapping resource times or treating
  a feasible count vector as an executable program.
- [gfx1151 profile](gfx1151/README.md) separates source-derived ISA facts,
  program-family restrictions and observed rates. It identifies the missing
  premises for a native timing claim rather than filling them with measurements.

The [potential bridge](core/potential_bridge.py) joins the first two pieces.
It rechecks the finite certificate, derives the count cuts, and binds them to
an exact resource certificate. A cost-limited search corridor stays an explicit
family restriction. Changing the resource price does not erase that restriction.

## Results that are proved

In the two-bit machine, `x` contains bits `b1,b0` and instructions have the
charges listed in the finite-machine model.

| target | unrestricted representation | requiring a familiar intermediate |
| --- | ---: | ---: |
| `b1 xor b0` | 2 | 4 through `b0+b1` |
| `b1 == b0` | 2 | 5 through `b0+b1` |
| `2*(b1 and b0)` | 3 | 4 through `b1 and b0` |
| trit ReLU | 2 | 3 through `-t` |

These are complete optima for that machine, not unsuccessful depth-bounded
searches. The optimum XOR program is `add 1; shift right 1`. The same program
computes ReLU on the signed trit input domain. Requiring an ordinary intermediate
really can exclude every optimal program.

Removing right shift makes the high input bit impossible to observe in the low
output bit in the tested grammar. Restricting to affine operations makes the
low-bit extraction impossible. The certificates cover all program lengths.

A separate worked resource example proves a two-instruction family optimal at
two abstract ticks and exhibits a one-instruction competitor. Another puts two
instructions on independent ports and proves one tick, not two. Adding four
ticks of latency leaves the service lower bound at one: a gap, not a false
optimality claim.

## How the bound works

Let `n` be the instruction counts. Necessary semantic inequalities are `A n ≥ b`.
Resource limits are `D n ≤ T c`, where all resources share one elapsed time `T`.
Choose nonnegative prices `λ, μ` such that

```
Aᵀ λ ≤ Dᵀ μ.
```

Then

```
T ≥ (λ·b)/(μ·c),     μ·c > 0.
```

A solver proposes these prices; the checker uses exact rational arithmetic to
verify them. A matching feasible count vector proves the relaxation optimum.
Only a correct program with a feasible schedule can turn that into a program
optimum. A competitor's checked upper bound below a family's lower bound proves
strict domination of that family.

A resource need not be the bottleneck to give a lower bound. Its capacity must
be a genuine upper bound on its service rate. Measuring one fast loop does not
establish such a ceiling.

## Use a bound to shrink the next search

A dual certificate also assigns each instruction a nonnegative penalty

```
δ_j = (Dᵀμ − Aᵀλ)_j.
```

For any program meeting a time budget `B`,

```
Σ_j δ_j n_j ≤ B(μ·c) − λ·b.
```

At the lower bound, every positive-penalty instruction must disappear. Near it,
the same inequality caps how many times those instructions can occur. This is
complementary slackness used as a search tool, without prescribing intermediate
values. [`Certificate.penalty_budget`](../../../Kelana/ResourceBounds.lean)
proves it; `core/certificates.py` derives the exact integer count caps.

The finite-state certificates give a sharper vocabulary result in their tiny
machine: every cost-two XOR program uses only `addi` and `shri`. Fourteen opcode
families are excluded from every optimum, rather than merely absent from the
first solution found.

## Limits that matter for the next search

The finite experiments have two-bit registers and no branches, memory or lane
operations. Their bounds are not gfx1151 bounds. The Lean proofs quantify over
supplied semantic and service premises; they do not prove a native capacity
from an instruction mnemonic.

The gfx1151 PERM example has a useful conditional comparison: in its restricted
additive observer family, with an independent incoming accumulator, at least
`3/16` declared issue slots are needed per lane-MAC. A comparable WMMA upper
charge of at most 24 slots suffices to meet that floor. This does not exclude
joint consumers, different encodings, correlated partials or a different
algorithm. Nor does it prove native elapsed-time dominance.

The next useful extension is a larger instruction-state model with several
observations from one program. Keep the endpoint contract explicit and derive
potentials before prescribing an intermediate layout. If the lower and upper
bounds do not meet, preserve the gap: it tells us whether we need a stronger
potential, a better schedule, or a different representation.

## Replay

From the repository root:

```sh
lake build Kelana.ResourceModels
python3 research/discovery/resource-bounds/finite-machine/check.py research/discovery/resource-bounds/finite-machine/results/*.cert.json
python3 research/discovery/resource-bounds/core/replay.py research/discovery/resource-bounds/core/results.json
python3 research/discovery/resource-bounds/core/replay.py research/discovery/resource-bounds/core/potential-results.json
python3 research/discovery/resource-bounds/gfx1151/validate.py --reextract
```

Search and replay are separate. A timeout, a missing witness, and an
impossibility certificate are different outcomes throughout.
