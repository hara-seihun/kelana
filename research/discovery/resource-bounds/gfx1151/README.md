# Conditional resource profile for gfx1151

Lower-bound certificates need a cost space, and gfx1151 does not come with one. The sources this
repository pins — AMD's machine-readable RDNA 3.5 ISA and the architecture manual — give semantics,
encodings and correctness-level hazards. They do not contain a per-instruction issue cost, a
throughput table or a port model. So this profile counts **service slots** on one modelled resource
and stops there. Nothing here is denominated in time.

The deliverable is the bridge. Every statement that carries weight is sorted into one of three tiers:

| tier | what it is | what it buys | what it cannot do |
| --- | --- | --- | --- |
| **architectural** | read out of the pinned AMD sources | holds against any program someone might write | say nothing about cost; the sources contain none |
| **family restriction** | a declared class of programs, domains or charging rules | a bound inside the class | bind a program that leaves the class |
| **achieved rate** | a number one kernel reached | existence of a feasible schedule at that rate | bound anything from below, ever |

A conclusion inherits the weakest tier among everything it depends on: cited premises, the quantities
its conclusion reads, and transitively the steps it builds on. **Absence of a measurement is not
unconditionality, and an empty premise list launders nothing** — a step with no citations still
inherits from its `depends_on` chain and from the quantities in its own check.
[`validate.py`](validate.py) computes that transitively and rejects three failure modes, each with a
regression in `--self-test`: promoting an achieved rate into a lower bound, relabelling a
family-tainted step as architectural by emptying its `uses`, and relabelling a family-tainted
quantity.

**Neither case proves dominance, and neither tries to.** Both state one-sided sufficient conditions on
service demand, with the missing premises named.

## What a slot is, and how one would become a time bound

One slot is what a single full-rate wave32 VALU instruction asks of the SIMD32 issue path. Slots are
service demand: additive over instructions, independent of scheduling.

A demand becomes a **time lower bound** through `T ≥ demand / C`, and the only thing that needs is a
proved **upper bound `C` on the resource's service capacity**. Arguing that the resource is the
bottleneck is neither necessary nor sufficient: a capacity bound on any single resource already gives
a valid `T`, and naming a bottleneck establishes no capacity number. No such `C` is available here.
An earlier version of this profile said a bottleneck argument was required; that was wrong in both
directions. The current profile requires the capacity bound instead.

A demand does not become a **time upper bound** by dividing either. That needs an exhibited feasible
schedule — instructions assigned to issue opportunities respecting dependencies and hazards, or a
measurement of a real one. It is why the WMMA side below rests on a measured schedule rather than on
arithmetic.

Slots are also not a sum across resources (independent work overlaps) and not latency times count
(the LLVM GFX11 model's 5 and 8 are assigned to `Latency`, not occupancy; see
[`research/cost-model.md`](../../../cost-model.md)).

Geometry is 20 WGPs, 40 CUs, **80 SIMD32**, per [`GEOMETRY.md`](../../../ffn/batched/GEOMETRY.md).
Probe records whose `waves_per_simd` field was printed against an assumed 40 carry twice the physical
value; the correct IU4 figure at high occupancy is **~6.0 ns per instruction per SIMD32**, not the
~3.0 that dividing by the stored label gives.

## Case: PERM lookup-and-accumulate against IU4 WMMA

[`cases/perm-vs-iu4-wmma.json`](cases/perm-vs-iu4-wmma.json)

Scope first: this compares the **register-resident inner arithmetic only**. The PERM side is not
charged for its byte-lane drain, online table construction, 85 MB selector stream or activation
staging; the WMMA side is not charged for fragment layout, staging or epilogue. The two output
contracts differ — packed bytes awaiting a drain against int32 accumulators. Neither exclusion is
bounded, so nothing here carries to whole kernels.

**Architectural.** `V_PERM_B32`'s `BYTE_PERMUTE` pseudocode partitions all 256 selector values into
exactly 14 functions of the two data operands: eight byte projections, four sign replications,
constant `0x00`, constant `0xff`. `V_PERM_B32` has no dedicated accumulator operand.
Its data operands could carry prior state in a different program family; this family restricts
them to activation functions. Of the declared word combiners, the widest reads three 32-bit
words and writes one. Exactly 17 opcodes carry a VOPD encoding and all are named
`V_DUAL_*`; `V_PERM_B32` and `V_ADD3_U32` are not among them. Under the unit-slot
convention and the specified reduction grammar, two `V_DUAL_ADD_NC_U32` operations in a
VOPD remove the same two words one `V_ADD3_U32` does. That conditional count grants dual issue.
One IU4 WMMA delivers 128 lane-MAC and an accumulating `D→C` chain needs no filler.

Two things that are **not** architectural, and were wrongly filed as such in the first version:

- **The 14-function arity bounds nothing on its own.** A group of `g` trits needs one selector code
  per equivalence class of its `3^g` patterns under "agree on every activation in the domain". On a
  degenerate domain every pattern collapses into one class and no `g` is excluded. Bounding `g`
  needs a separation premise over a declared domain and weight family.
- **Operand-field count is not word arity.** Three fields do not mean three words: the widest explicit
  input field in this inventory is 256 bits, and implicit `EXEC`, `MODE` and the lane-crossing
  modifiers are not fields at all. The reduction bound is scoped to a named opcode grammar and its
  read widths, not to VALU in general.

**The separation premise is existential.** Two weight patterns need different codes as soon as *one*
activation vector separates them, so a single witness bounds the class count from below and no
worst case over activations is involved. For A4 activations the triple `(-7, -6, -4)` gives 25
pairwise distinct sums, so the 27 three-trit patterns fall into at least 25 classes and `25 > 14`.
That witness is not a minimum. With a prepared additive bias, use the difference from the
contribution at zero; all target linear forms vanish there, so the same 25 normalized functions
remain distinct. The zero vector and three unit vectors in fact distinguish all 27 coefficient
patterns. Further weight-dependent relabelings or multiplicative corrections are outside this
family and could change its capacity argument.

**Family restriction.** With the selector fixed offline, one PERM per group, irredundant partials and
the word-combiner grammar, one PERM carries at most 8 lane-MAC and `k` PERMs need combining. The
floor then depends on the accumulator, and this turned out to matter more than expected:

| accumulator premise | floor, slots per lane-MAC | attained at | sufficient σ_W |
| --- | --- | --- | ---: |
| running accumulator required | **3/16** | every even `k` | **24** |
| removable zero, `k ≥ 2` | 1/6 | `k = 3` | 64/3 ≈ 21.33 |
| removable zero, `k = 1` admitted | 1/8 | `k = 1` | 16 |

[`PermResourceBounds.lean`](../../../../Kelana/PermResourceBounds.lean) checks the
three resulting resource inequalities: `3M ≤ 16T`, `M ≤ 6T`, and `M ≤ 8T`.
The contribution and combiner count cuts remain explicit premises. A formal
counterexample shows why dropping the running accumulator invalidates the first bound.

`⌈k/2⌉` and `⌈(k−1)/2⌉` coincide at even `k` and differ by one at odd `k`, so the gap is a parity
effect, and a valid floor has to be the infimum over whatever `k` the schedule may choose. At `k = 1`
a single PERM's four bytes are the answer and nothing is combined — which is the `perm-issue-ceiling`
kernel the owning experiment already excludes from the family for exactly that reason.

**The inequality that follows.** If `σ_W ≤ 24`, the WMMA path's demand for this region sits at or
below a proved floor on the family's demand, hence at or below the family's actual demand. This is
**sufficient, not necessary, and not dominance**: when it fails the family's actual demand may still
exceed WMMA's by any amount, because a floor bounds the family only from below. `σ_W > 24` leaves the
question open rather than reversing it.

**Achieved rates, load-bearing for nothing.** One interleaved run gives 683.6 MAC/ns/SIMD32 for IU4
and 723.8 for a pure-PERM stream — 5.99 ns and 0.354 ns per instruction, ratio **16.94**. The
sixteen-pass structural reading puts σ_W at **16**. Both clear 24 and 64/3. **Neither clears 16.**
So the conclusion's survival rests on `MODEL.ACCUMULATOR_REQUIRED`, not on the measurement, and that
sensitivity is the result rather than a footnote.

**Where the count model visibly fails to predict time.** The assembled `core-rq8-tok4` kernel meets
the instruction-count floor exactly — 64 PERM and 32 ADD3 per loop body is 3 instructions per 16
lane-MAC — and takes **1.256×** what the pure-PERM stream's per-instruction rate would suggest. Read
narrowly: for those two streams the count model does not predict elapsed time. It is not a
falsification of unit service demand, which is a definition of a counting resource rather than a
prediction, and it does not show the bounds are conservative.

Two static explanations are excluded. The declared 67 VGPRs allocate 72 of 1536, permitting 21 waves
against the 8 requested; and the loop carries 32 independent accumulators rather than a serial chain.
Neither exclusion isolates all occupancy and latency effects — achieved residency, launch and drain,
instruction fetch, clock behaviour under different mixes and forwarding on the accumulate path are all
untested. Per-opcode issue cost and operand supply remain candidates among others, and the manual's
only documented operand-supply structure (four VGPR banks indexed by `SRC[1:0]`, one read port per
source position) is scoped to VOPD pairing.

## Case: two instructions against three for the packed 2×2

[`cases/packed-2x2-slots.json`](cases/packed-2x2-slots.json)

The incumbent online core for the exact ternary `D = AB + C` is two `V_DOT8_I32_IU4` and one
`V_LSHL_OR_B32`. The fused core is one `V_DOT4_I32_IU8` chained into one `V_DOT8_I32_IU4`, the
shift-or replaced by a prescale splitting 256 as 16 × 16 between the weight and the wire.

**Architectural.** Three instructions against two, assembled and counted. Dependency-**graph** depth
is 2 either way. The fused program names one fewer 32-bit temporary. `V_DOT4_I32_IU8`'s `SRC2` is a
full 32-bit signed accumulator, so the chain is a legal operand pairing.

**What those do not say.** Equal graph depth is not equal latency: the two programs use different
opcodes along their critical paths, a result feeding a VOP3P dot's `SRC2` need not forward like one
feeding a VOP3 shift-or, and no pinned source gives either latency. The saving is therefore **not**
shown to be latency-neutral. The temporary count describes these two schedules as written, not a
register-pressure theorem about the map.

**Family restriction.** Calling one saved instruction one saved slot. Both dots are `ENC_VOP3P` with
identical operand signatures and nothing in the pinned sources distinguishes their cost. The weaker
symbolic form `2·D8 + S` against `D4 + D8` is no stronger in tier, because the ordering `D4 ≤ D8` is
itself unsupported.

**Two is not proved optimal.** One `V_DOT8_I32_IU4` under shared packing is refuted by a reach
argument. One `V_DOT4_I32_IU8` under shared packing is **open** — CP-SAT returns UNKNOWN on the
general affine weight rule at 40 s, and the 5036 infeasible scans used signed int8 weights only.

**Why WMMA is not the comparison here.** This workload gives every lane its own A, B and C, while
`V_WMMA_I32_16X16X16_IU4` is wave-collective over replicated fragments. The obvious block-diagonal
embedding wastes most of its 4096 products, so the two are not measured against each other and the
fused core's 4 lane-MAC per instruction must not be read against WMMA's 128. That is a statement
about the comparison we make, not an impossibility: no claim that a cleverer embedding cannot exist.

## Where no defensible hardware lower bound exists

- **Any instruction's cycle cost.** Not determinable from the sources this repository pins. Other
  documents may supply one; adopting a source would be an acquisition task, not an impossibility.
- **`tau_V`, a capacity upper bound on VALU issue.** Searching the pinned manual for per-cycle issue
  language returns memory bandwidth, the WMMA hazard rule and the delay instruction, and nothing
  stating a VALU rate. That establishes the parameter is absent **from these sources**, not from the
  world. Without it, no slot count becomes a time lower bound.
- **`σ_W`, the slot cost of IU4 WMMA.** Two candidates, 16 structural and 16.94 measured, neither
  proved, and the choice between the 24 / 21.33 / 16 thresholds decides whether either suffices.
- **Whether IU4 WMMA is optimal.** Not claimed. Nothing here bounds the WMMA path from below.
- **Whether `σ_W ≤ 24` means WMMA dominates.** No. It is sufficient for a one-sided service-demand
  comparison on a sub-region, with excluded work on both sides and differing output contracts.
- **Why `core` misses its own count floor by 25.6%.** Not determined; the static exclusions narrow the
  field without isolating occupancy and latency.

## Files

| file | contents |
| --- | --- |
| [`facts.json`](facts.json) | 12 architectural facts with provenance, extraction method and explicit `does_not_imply` limits |
| [`extract_facts.py`](extract_facts.py) | regenerates them from the pinned XML and manual text; no network, no GPU, no compiler |
| [`profile.json`](profile.json) | the bridge, the cost space, every assumption and unproved parameter |
| [`cases/`](cases) | worked-case premises, derivations and claims |
| [`validate.py`](validate.py) | exact-rational re-derivation, transitive tier inheritance, role rule, three regressions |
| [`results/validation.json`](results/validation.json) | the receipt |
| [`SCHEMA.md`](SCHEMA.md) | the JSON shapes, for integrating against an independent checker |

## Run

```sh
cd research/discovery/resource-bounds/gfx1151
python3 extract_facts.py                  # rebuild facts.json from hardware/gfx1151/sources
python3 validate.py --reextract           # 206 checks: hashes, re-extraction, arithmetic, tiers, roles
python3 validate.py --self-test           # three laundering controls, all must be rejected
```

Validation needs only Python 3's standard library and the pinned sources in
[`hardware/gfx1151/`](../../../../hardware/gfx1151/README.md). It executes nothing on the GPU and
measures nothing.

## What this reuses

[`hardware/gfx1151`](../../../../hardware/gfx1151/README.md) owns the pinned ISA inventory.
[`research/toy2/optimality`](../../../toy2/optimality/NOTES.md) owns the packed 2×2 constructions,
their Lean proofs and search results.
[`register-observer`](../../../ffn/batched/register-observer/README.md) owns the PERM family, its
kernels and measured rates. [`triple-packing`](../../../ffn/batched/triple-packing/README.md) owns the
per-SIMD normalization and [`GEOMETRY.md`](../../../ffn/batched/GEOMETRY.md) the processor-unit
conversion. [`research/cost-model.md`](../../../cost-model.md) owns the reading of the compiler
scheduling metadata. This directory adds no measurements.
