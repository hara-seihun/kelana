# Resource certificates with replayable upper schedules

This component checks conditional lower bounds, independently checks concrete schedules, and compares the two. The arithmetic uses `Fraction`; floating-point coefficients are rejected. A bounded exact vertex search proposes linear-program witnesses, but the replay command does not search or trust stored optimizer status.

The examples are abstract machines. They establish no new native gfx1151 cycle bound.

## The lower-bound contract

A family names its permitted operations. Let `n` be their nonnegative execution counts. Declared obligations give

```
A n >= b.
```

A machine profile supplies nonnegative minimum resource demands `D`, positive capacities `c`, and a common elapsed time `T`:

```
D n <= T c.
```

For nonnegative prices `lambda` and `mu`, the checker verifies each operation column of

```
Aᵀ lambda <= Dᵀ mu.
```

It then returns

```
T >= (lambda·b)/(mu·c),  provided mu·c > 0.
```

Resources may overlap. Two independent ports each doing one tick of work do not imply two ticks of elapsed time. Pricing both ports also prices both capacities in the denominator. The saved parallel-port example has lower bound one and an attaining one-tick schedule.

All cuts must apply jointly to the same count vector and accounting boundary. Separate worst-case inputs do not automatically justify adding their costs. The supplied schedules are static SSA programs. Extending a cut to data-dependent control flow requires counting its executed trace and any information carried by control or timing.

### What the checker does not prove

An obligation has a required `role`:

- `necessary_for_target` asserts that every correct program in the declared class must satisfy the count inequality. Its proof or justification is a premise.
- `class_restriction` defines the narrower family being compared. A competitor may violate it and still compute the same target.

The checker validates the certificate algebra, not these semantic premises. In particular, counting the MACs in the familiar FFN transcription is not a lower bound on all representations of that FFN. Requiring every activation to be reconstructed is also not a valid premise unless the external observation actually requires it.

Resource demands and capacities are premises too. An achieved throughput measures what one schedule did; it does not establish an upper ceiling on all possible schedules. A native profile needs a defensible transfer from its resource model to hardware before these inequalities become native time bounds.

## Prune the instruction vocabulary

`count_caps` retains the dual's column slack `δ = Dᵀμ − Aᵀλ` rather than
throwing it away. Any program within time budget `B` must satisfy
`δ·n ≤ B(μ·c) − λ·b`. A positive slack therefore gives a checked integer
upper bound on that instruction's count. At a tight optimum its count is zero.
Zero slack gives no individual cap. A negative remaining budget rules the
budget out under the same premises.

`Certificate.penalty_bound` and `penalty_budget` in Lean prove this strengthened
inequality. The extra time budget remains a premise. Count caps do not establish
that any program within it exists, and they do not transfer to a different
resource model without rechecking its dual.

## Semantic cuts from checked potentials

`potential_bridge.py` imports the independent finite-machine checker, replays
its Bellman certificates and derives progress cuts and excluded-instruction
cuts. `replay.py potential-results.json` repeats that derivation and compares
the resulting model, target and family against the artifact. It does not trust
a stored "proved" flag. The source certificate is hash-bound.

The first two bridged cases give a count-relaxation bound of two for XOR and
trit ReLU. The finite certificate separately supplies the attaining programs.
Its prefix-plus-step-plus-suffix corridor depends on an abstract charge budget;
that budget remains an explicit family restriction in the resource artifact.
These are not unconditional cuts for arbitrary schedules under a new price.

The bridge stays at the count level. Instructions act on a fixed register file
with fixed operand positions. Allowing arbitrary SSA argument rewiring for
free would enlarge the program grammar and invalidate transfer of its lower
bounds. It does not export a falsely equivalent SSA upper schedule.

This optional bridge needs NumPy through the finite checker. The algebra and
schedule checker themselves remain standard-library Python.

## Relaxation optimum is not program optimum

`propose` searches both sides of the count relaxation, recording its active-set and time budgets. The primal permits rational instruction counts and ignores dependencies and register pressure. `verify_primal` checks those counts against the declared cuts and service capacities. Equality with a checked dual proves the **relaxation's** optimum.

It does not supply a program. The tests include a `3/2` instruction count, deliberately leaving that distinction visible. No lower bound is rounded to an integer time without a time-quantum assumption.

A separate Farkas-style certificate proves conditional impossibility: nonnegative `lambda` with `Aᵀ lambda <= 0` and `lambda·b > 0` contradicts every nonnegative count vector. A solver's infeasible or unbounded status without such a witness remains only a solver status.

## Concrete Lean instances

`export_lean.py` emits `Kelana/ResourceCertificates.lean` from saved duals.
Lean recomputes their inequalities with `decide`, then applies the generic
bound theorem. Rational constraint rows are independently scaled to integers;
their prices are inversely scaled before a common weight denominator is cleared.
Zero-priced rows are omitted from this particular arithmetic proof.

The exported theorem still assumes its semantic and service inequalities. It
does not silently turn the Python finite-state checker or a hardware profile
into Lean-verified machine semantics. The source case hash identifies exactly
which artifact supplied the instance. The generated module builds in under a
second after dependencies are present.

## A concrete upper bound

A program is a static list of SSA nodes with explicit operations, arguments, start times and returned values. Its machine contract states:

- Inputs are already present at time zero. Their preparation is part of the declared interface, not silently charged as free encoder work.
- Operands are read at issue, and each result becomes available after its declared latency.
- Port reservations have separate offsets, durations and amounts. The verifier sweeps their exact interval endpoints and rejects overlapping capacity violations.
- Every used operation's reservation integral must cover its declared lower resource demand.
- Each value occupies one homogeneous register. Destinations are allocated at issue and survive through their last read, or to return if observed. Retained original inputs count. Registers may be reused after the last read under this abstract read-at-issue contract.
- The upper time includes both result readiness and the end of all reservations, including reservations that extend beyond result readiness.

This is an explicit abstract resource machine. It does not claim to model native operand-capture timing, bank conflicts, caches, memory aliasing, wave scheduling or heterogeneous register classes. A native schedule witness needs those additional constraints where they matter.

For finite semantics, each operation has a complete truth table over a declared value alphabet. The verifier executes the whole program on every input listed in the target contract and compares the observed outputs. Table addresses use little-endian argument order. Intermediate values may be anything; no recognizable source operation is required.

Without those semantics, resource feasibility can still be checked, but the comparison refuses to turn it into a correctness-backed upper bound. The endpoint table defines the finite target domain; passing it is not a claim about unlisted native inputs.

## Comparing bounds

The lower-bound family and the upper program share hashes of the machine and complete target/input contract. This prevents comparing a program receiving precomputed answers with a lower bound whose interface receives raw inputs.

- An in-family correct program attaining the lower bound establishes conditional optimality in that family.
- A correct competitor with upper bound below the family's lower bound establishes conditional strict dominance. The competitor may use operations excluded from that family.
- A correct program using allowed operations that violates a claimed necessary cut, while satisfying the family's explicit restrictions, is reported as a counterexample to the premise. It is not credited as a successful lower-bound proof.
- Otherwise the bounds leave a gap. The long-latency example has resource lower bound one and concrete upper bound four. It is not labelled optimal.

Every result retains the premises and says `native_runtime_claim: false`. A certificate is evidence for the implication it states, not a way to certify arbitrary hardware assumptions by putting them in JSON.

## Files and commands

- `certificates.py`: exact dual, primal and impossibility replay, plus budget-dependent instruction count caps.
- `test_count_caps.py`: optimal/near-optimal vocabulary and fractional-budget regressions.
- `vertices.py`: bounded exact proposal search, with incomplete coverage reported as such.
- `export_lean.py`, `test_export_lean.py`: denominator-safe export and its rational-row regression.
- `schedule.py`: dependencies, resource reservations, register liveness, finite endpoint replay and bound comparison.
- `examples.py`: builds the small worked artifacts.
- `results.json`: saved witnesses and original reports.
- `replay.py`: reconstructs reports from witnesses, ignoring stored solver verdicts.
- `test_core.py`: malformed certificates, overlap, latency, retained-state pressure, false premises and missing semantics.
- `potential_bridge.py`: replay finite-state potentials and transfer their count cuts without dropping the budget restriction.
- `potential-results.json`, `potential-replay.json`: bridged artifacts and checked reports.
- `test_potential_bridge.py`: source binding, target binding and budget-tampering regressions.

```
python3 examples.py
python3 replay.py results.json --out replay-results.json
python3 -m unittest test_core test_potential_bridge test_export_lean test_count_caps
python3 potential_bridge.py
python3 replay.py potential-results.json --out potential-replay.json
python3 export_lean.py
# From repository root: lake build Kelana.ResourceCertificates
```

The tests take less than a second. The unbridged proposal generation and replay use only the Python standard library. No GPU or persistent external state is involved.

Independent replay caught a real defect during development. SymPy's simplex proposed time zero with positive resource use for `n1+3*n2>=4`, demands `(3*n1,2*n2)` and capacities `(2,1)`. The checker rejected it. The owning proposal mechanism now uses bounded exact vertex enumeration instead; the regression pins the correct optimum `24/13`, attained by counts `(16/13,12/13)`. Exhausting a search budget returns no witness, never an impossibility claim.
