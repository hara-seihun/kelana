# Resource-bound certificates, Lean side

Proof-grade lower bounds on execution time from semantic cuts and nonnegative
resource prices, plus the sound way to compare one against an exhibited run.
Three modules, no Mathlib, pinned Lean `v4.33.0` with the bundled `Std`:

- [`Kelana/ResourceVectors.lean`](../../../../Kelana/ResourceVectors.lean) —
  integer vectors as finite lists with zero padding, the transpose identity, and
  the histogram that turns a trace into a count vector.
- [`Kelana/ResourceBounds.lean`](../../../../Kelana/ResourceBounds.lean) — the
  framework: obligations, machines, executions, dual certificates, lower and
  upper bounds, native time, and the countermodels.
- [`Kelana/ResourceModels.lean`](../../../../Kelana/ResourceModels.lean) — a
  packed and a scalar instruction-resource model of the same job, a model
  optimum, and conditional strict domination.

[`Kelana/ResourceCertificates.lean`](../../../../Kelana/ResourceCertificates.lean)
contains generated instances from the saved Python duals. Lean recomputes the
concrete certificate arithmetic. Its `Feasible` premise still supplies semantic
cuts and service limits; the exporter does not prove a native machine model.

The executable checker and replayable upper schedules are in
[`../core`](../core/README.md). The [`gfx1151 profile`](../gfx1151/README.md)
records source facts and the extra premises a native instance would need;
it does not supply a complete native timing model. Same algebra, separate implementations:
`Certificate.check` here and the `Fraction` checker there agree on `Aᵀλ ≤ Dᵀμ`,
and the pinned instances below fix the arithmetic both must produce.

Build:

```sh
lake build Kelana.ResourceModels
```

Each module ends with `#print axioms`; everything reported depends only on
`propext`, `Classical.choice` and `Quot.sound`.

## The theorem

A program's instruction counts are `n : List Nat`. Semantic cuts assert
`A n ≥ b`. Each resource asserts `D n ≤ T c`, one inequality per resource
against one shared makespan `T`. A certificate is a pair of nonnegative weight
vectors `λ, μ` with `Aᵀλ ≤ Dᵀμ`, checked by `Certificate.check` — a `Bool`, so
an external checker can mirror it exactly. Then

```
Certificate.bound : λ·b ≤ T · (μ·c)
```

which is `T ≥ (λ·b)/(μ·c)` with denominators cleared. The bound is homogeneous
of degree one in `(λ, μ)`, so a rational certificate is used by multiplying
through by a common denominator; the `Nat` weights lose nothing and make
`λ ≥ 0`, `μ ≥ 0` structural rather than side conditions.

`ceilBound` turns the inequality into a tick count, `Family.lower` packages it
as a `LowerBound`.

## Where assumptions enter

`Family` has exactly two premise fields and no others:

- `meets` — every run satisfies the cuts. Justified outside the framework.
  `potential_cut` is one way: a potential `Φ` on complete machine states with
  `Φ ≥ b` initially, `Φ ≤ 0` at acceptance, and a per-class bound on how far one
  instruction can drop it over a domain closed under the allowed steps.
  Telescoping gives `w · n ≥ b`. No monotonicity, no recognisable intermediate
  values, so a Bellman certificate from a finite-state search lands here
  directly. Transitions are a relation `R j s s'`, so one class may cover many
  operand choices, immediates or memory contents without being split.
- `serves` — every run satisfies `D n ≤ T c`. For this to be sound, `c` must be
  a ceiling on what the resource can deliver in a tick. A measured throughput is
  not one.

Native time needs a third, `TickRate`, and gets its own theorem
(`native_seconds`) that never fires without it. Nothing in the framework
produces seconds otherwise.

## Separate units and obligations

| quantity | type | combined by |
|---|---|---|
| instruction counts | `Execution.counts : List Nat` | the cuts |
| resource service | `Machine.Serves`, one row per resource | one shared `T` |
| dependency latency | `LowerBound.ofChain` | `LowerBound.max` |
| native time | `TickRate` + `Seconds` | nothing else |
| register peak | `Machine.Fits` | nothing; it is not a time |

`parallel_resources_are_not_sequential` and `sum_is_not_a_lower_bound` are
countermodels, not cautions: an execution satisfying every premise refutes both
summation rules. `feasible_is_not_a_run` refutes reading an upper bound off the
relaxation, which is why `UpperBound` demands a run and
`capacity_premise_is_load_bearing` shows the service premise carrying weight.

## Comparisons

`optimal` needs a lower and an upper bound on the *same* runs.
`dominates` needs the same machine, the same target value, a lower bound on the
loser and an exhibited run of the winner; the clock is a type parameter on both
bound types, so a bound in one time base cannot be compared against another.
Families may differ in which instructions they use — that is the point of
comparing them.

## Pinned instances

`A = I₂`, `b = (1,1)` charged two ways, which fixes how overlap is normalised:

| machine | `λ·b` | `μ·c` | bound |
|---|---|---|---|
| one shared port, capacity 1 | 2 | 1 | 2 |
| two ports, capacity 1 each | 2 | 2 | 1, attained |

Capacities meet in the denominator of one makespan; times are never added.
`chainFamily` adds four ticks of dependency latency over the same one-tick
reservations: the dual bound stays at 1 against a four-tick run, so the
certificate alone proves no optimum — `chain_dual_is_not_optimality`. The
latency premise closes it through `max`, never through `+`.

## The two instruction-resource models

Three classes share one issue port: packed multiply-add retiring `lanes`
products, scalar multiply-add retiring one, and an operand shuffle retiring
none. `lanes`, `issue` and `regs` come from a hardware profile; `group`, how
many packed issues one shuffle prepares, is an amortisation claim about a code
shape. All of them stay parameters, and every theorem carries them.

- `packed_optimum` — the exhibited packed schedule is the fastest run that
  family can have, by a certificate tight on the packed and shuffle classes.
  The rational form is `λ = (1 + 1/group, lanes/group)`, `μ = lanes`; the Lean
  form is that times `group`.
- `packed_dominates_scalar` — every scalar run is strictly slower than the
  exhibited packed run, given `group + 1 < lanes · group`. That inequality is
  sufficient comparison here. These assumed product counts do not rule out
  other algorithms that compute the target without retiring each named product.

`packedSchedule_feasible` shows the counts satisfy the cuts, service bound
and register budget. It proves consistency of the relaxation, not existence
of a run. A program and its schedule still have to be supplied and replayed.

## Known gaps and assumptions carried

- Model feasibility is not realisability. The framework never converts a
  feasible point into an upper bound, so anything claiming a schedule exists
  must come from the schedule checker.
- The cuts are only as good as their justification. `potential_cut` gives one
  route; a cut asserted without one is an assumption that travels into every
  conclusion drawn from it.
- Nothing here bounds what an unknown instruction could do. A lower bound is
  over the families and the machine it names.
- `Execution.ticks : Nat` builds in that a makespan is a whole number of ticks.
  That is what licenses the ceiling in `ceilBound`; on a clock too coarse to
  make it true, use a finer tick.
- Only weak duality is proved. A matching primal point shows the certificate is
  the best the relaxation offers, not that the relaxation is tight against the
  machine.
- `LowerBound.ofChain` takes "every run contains this dependency chain" as a
  premise. The framework computes the chain's latency from a profile but does
  not analyse dependencies; that obligation belongs to the schedule checker.
