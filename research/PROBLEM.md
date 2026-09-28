# Unit-cycle minimization across loading and computation

the project lead's selected objective is limiting average execution-unit cycles per computation as reuse of a loaded weight version tends to infinity, not latency or finite-run total cost. Every finite one-time loading or transformation cost contributes exactly zero to this limit. Weights and activations are both inputs. They can have different reuse lifetimes. Loading weights into VRAM is itself an operation and may transform their representation, including packing, rather than merely copy bytes. All proof work in this investigation stays on the main agent thread; supporting workers inspect instruction costs and enumerate constructions.

## Staging the map

Write the requested operation as `F(W, X)` for arbitrary valid weights W and activations X. A candidate consists of

```
loadTransform : W → DeviceRepresentation
produce      : X → ActivationRepresentation
run          : DeviceRepresentation × ActivationRepresentation → Y
∀ W X, run(loadTransform(W), produce(X)) = F(W, X).
```

`loadTransform` includes the chosen transfer and representation changes. It may pack trits before transfer, convert during staging, rearrange data on the GPU, or load an already transformed file. These are alternative implementations of one operation in the graph. The theorem quantifies over W; it does not bake in one model's literal weights.

A transformed file is an optional persisted intermediate. A cached device representation is valid for the weight version that produced it and can be reused until those weights change. This is dependency and reuse analysis, not an assumption that weights are compile-time constants. Weight-dependent corrections or tables require their own construction and storage accounting.

For N activation uses of one loaded weight version, the bill is

```
U_total = U_loadTransform(W) + Σᵢ [U_produce(Xᵢ) + U_run(W, Xᵢ)]
U_total / N = U_loadTransform(W) / N + average per-use work.
```

We select the large-reuse limit as the optimization target:

```
U_infinity = limsup_{N→∞} U_total / N.
```

For every finite `U_loadTransform(W)`, its contribution is zero. When the per-use cost is a constant C, `U_infinity = C`. One-time input packing, signed conversion, correction-table construction and layout transformation must not be charged to C or used to reject a candidate. Their correctness and resulting storage requirements still matter. Recurring conversion, gathering, loads and output decoding remain charged. A constant multiplier on recurring work does not disappear.

The weights remain arbitrary inputs: correctness quantifies over every valid W, then the cost limit considers unbounded reuse of that loaded version. Finite-reuse comparisons may be reported separately, but are not the selected optimum.

Activation representations are equally selectable. Count their conversion or fuse it into the producer and count the producer's changed work. Moving an operation across a graph boundary does not erase its cost.

## The current exact map

The primary toy is `D = AB + C` for 2×2 matrices whose twelve input entries are all trits. Each output entry is an integer in `[-3,3]`. The [self-contained proof](toy2/PROOF.md) fixes common packed input/output contracts and gives an exact implementation with 9 vector instructions versus a specified 13-instruction elementwise int4 baseline.

A is an arbitrary reusable input whose coefficients and codec metadata may be prepared at load time. B and C vary per use. D finishes in a lossless packed representation, not as a mandated unpacked int32 matrix. Input-dependent conversions needed by the agreed interface count. Mathematical intermediate sums may appear in proofs without being required runtime states.

The immediate goal is a proved improvement, not a global matrix-multiplication optimum. Restricted optimality results are useful when their scope is explicit. The [arbitrary-int8 matrix and information lemmas](INFORMATION.md) are subsidiary results for a different interface; they do not constrain the current toy's representations.

Register-to-register proofs remain useful local lemmas. They must state fragment layouts and replication, and must not be promoted to whole-graph optima without the loading and producer maps. Report file bytes, transferred bytes, resident bytes and live registers. Track DMA, CPU and GPU charges in their own resource classes until a common normalization is specified. A lookup used to compute an answer remains part of the charged graph.

## Representation budget

Let S be the allowed representation storage, including resident weight payload, auxiliary tables and specialized code. Compare

```
min U_infinity, subject to exactness and representation size ≤ S.
```

Storage is a constraint and a reported tradeoff, not an added latency objective. The reuse limit is selected; keep the storage budget S explicit until a concrete value is selected. Unlimited free tables plus an abstract unit-cost lookup would make the question degenerate into precomputing the answer for every activation input. Construction, lookup work and storage must remain visible.

Examples excluding scales, padding and metadata:

| Device layout | Weight payload | Work movable into loading or file preparation |
| --- | ---: | --- |
| Original pack5 bytes | 8 bits / 5 trits | Encoding only |
| Three pack5 bytes in a 32-bit word at offsets 0,10,20 | 32 bits / 15 trits | Three-stream input repacking |
| Native signed IU4 fragments | 4 bits / trit | All weight peeling, gathering and signed conversion |
| Native signed IU8 fragments | 8 bits / trit | All weight peeling, gathering and signed conversion |

The three-stream word layout uses one-third more payload than densely stored pack5 bytes. A theoretical 30-bit triple can be packed densely into a file, but loading it as the required independent 32-bit words reintroduces extraction. Do not call a 30-bit dense stream the zero-repacking word layout.

Predecoding directly to IU8 is therefore one baseline, with a larger transfer or resident footprint depending on where conversion occurs. Compressed representations must be compared against its limiting per-use bill under the selected storage budget, not only against the original Halo decoder. Its finite one-time load conversion is zero in that objective. The IU4 route narrows operands but still needs extra matrix operations for arbitrary int8 activations.

## The source codec remains useful

Bonsai's packed source is not an ordinary base-3 integer stored in a byte. For five digits `tᵢ = Aᵢ + 1`, let

```
q = 81t₀ + 27t₁ + 9t₂ + 3t₃ + t₄
p = ceil(256q / 243) = floor((256q + 242) / 243).
```

The Lean codec proof establishes how to convert this source exactly. The earlier fixed-input experiment grouped three sets of five plus one padded set per 16-element weight column, giving 64 logical source bytes per tile. That remains a reproducible comparison boundary, but it is no longer a requirement on the prepared weight file. Bonsai's existing 128-element HALO swizzle and the toy column layout are distinct.

## Execution-unit charges

For a program P, define

```
U(P) = Σ executed instruction instances i  charge(i).
```

`charge(i)` is occupied execution-unit cycles in an explicitly named unit. It is not result latency. Independent parallel execution does not erase a charge. A bundled or dual-issued instruction needs its actual resource charge, not a count of its printed mnemonics.

Different hardware resources initially have separate charges. A scalar total needs a declared normalization or weight for each resource class. The [cost investigation](cost-model.md) records available evidence. A proof under symbolic charges remains a conditional theorem, not a measured cycle result.

Registers constrain legality and batching. Register-slot cycles are not a second objective. Finite register capacity, instruction hazards and finite code/table storage still prevent impossible implementations from entering the admitted class. Constants are free online only where their encoding or prepared placement actually avoids online setup.

## What an optimality proof must establish

1. Input domains and reuse lifetimes, representation budget, output contract and exact instruction semantics.
2. A construction with finite one-time preparation and a complete recurring resource bill, with the setup contribution proved to vanish under unlimited reuse.
3. A lower bound for every admitted construction, including representation choices and movements of work between stages.
4. Equality between that bound and the construction's bill.

The full gfx1151 class includes nonlinear bit operations, shuffles, table lookup, dot products, WMMA, floating-point encodings and control flow. A bound for one radix encoding family does not cover all of them. Search exhaustion is a proof only when its grammar, bounds and completeness argument cover the claimed class.

The [2×2 proof](toy2/PROOF.md) records the current positive result. The [Bonsai representation report](RESULTS.md) records the other checked constructions and their scope. Global minimum amortized unit-cycles remains open and is not a prerequisite for the current experiment's success.
