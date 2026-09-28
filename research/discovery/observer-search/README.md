# Consumer-relative representation search

[PLAN.md](PLAN.md) records the whole-map research direction from the project lead's September 20 discussion. The executable starting point is [observer.py](observer.py), with recorded examples in [results.json](results.json).

The library separates three questions that a synthesis system must not collapse:

| Question | Tool | What a success means |
| --- | --- | --- |
| Does a carrier preserve enough information? | `factor(carrier, target)` | Some decoder exists on the reachable carrier image. No cost claim. |
| What information must a reusable interface preserve? | `stable_quotient(machine)` | Coarsest observation-respecting partition stable under every named transition. |
| What does one fixed remaining region need? | `suffix_observations(machine, word)` | Final observations of that fixed program's suffixes. No closure under other programs required. |
| How do two states become distinguishable? | `distinguishing_word(machine, a, b)` | A shortest named continuation, or equivalence under all finite continuations. |
| Is an available decoder cheap? | `decoder_search(...)` | Minimum additive instruction cost inside the supplied one-register grammar and cost bound, or an explicit bounded-search status. |

All domains are finite and explicit. Machine transitions must be total and closed on their state domain. Register search keeps the actual numeric labels, not merely their equality classes. Memory and multiple registers can be modeled as finite product states, but the current decoder helper operates on one finite register and does not claim to scale to full machine-state enumeration.

## Instruction-first discovery

[inverse_labels.py](inverse_labels.py) starts with ISA-shaped maps on a dense radix-3 word, then solves for output labels that give the map a complete gated-network meaning. It does not unpack the trits or choose a gate/up decomposition before searching.

For three ternary inputs, a bias-free gated ReLU map has zero value at the origin and quadratic even part. The tool builds the exact 19-dimensional span of `relu(g dot x)*x_j` with ternary g, checks that it attains that upper bound, and solves linear equations for the labels of each candidate map's output classes. A bijective relabeling exists within this function space exactly when no two class labels are forced equal. Over the rationals, finitely many nonzero label-difference polynomials can be avoided; the tool implements that construction after trying small labels.

### Why relabeling does not require enumerating permutations here

Let X be the finite input domain, B the indicator matrix of the proposed ISA map's m output classes, and A a basis matrix for an allowed source-function space. Unknown output labels r are feasible exactly when

```
B r = A c
```

for some source coefficients c. Solve this linear system, then project its nullspace onto r. Call that label space U. A bijective output relabeling exists exactly when no difference `r_i-r_j` vanishes identically on U. Necessity is immediate. For sufficiency over the rationals, finitely many proper hyperplanes cannot cover U.

There is a constructive version. Given a basis `u_0,...,u_(d-1)`, try `r(t)=sum_j u_j*t^j`. Each forbidden equality is a nonzero polynomial of degree at most d-1. Across all pairs there are at most `(d-1)*m*(m-1)/2` bad parameter values, so one more distinct integer trial guarantees a bijective labeling. Large labels may be expensive on hardware; the implementation first tries small coefficients and records label magnitude separately.

Thus this structural query replaces a factorial relabeling search with exact linear algebra and finitely many polynomial evaluations. It applies to a finite-domain source family linear in its free coefficients, not to arbitrary instruction families or arbitrary nonlinear parameter searches. For fixed trained weights there is no freedom to choose c: equal fibers must be checked against that fixed function. An instruction-first atlas constructs possible source networks; it does not establish that the trained network belongs to one of them.

The first declared grid contains 1,565 affine/extract and other unary maps, of which 1,199 have two through nine output classes. Those give 531 distinct partitions. Exactly 16 admit a gated-network interpretation with distinct output labels; 515 are rejected. [inverse-results.json](inverse-results.json) records the grammar, limits and representative exact network witnesses. The run completes in about 0.25 seconds. Fiber deduplication is valid here because this is a structural existence query, not instruction-cost optimization.

One discovered map needs no lookup relabeling at all. With input already encoded as

```
q = (x+1) + 3*(y+1) + 9*(z+1), x,y,z in {-1,0,1},
```

these two instructions compute a complete five-hidden-unit ternary gated network:

```asm
v_mad_u32_u24 v0, v0, 11, -13
v_bfe_i32    v0, v0, 8, 2
```

The network is

```
relu(-x-y-z)*(x+y) - relu(-x-y)*(x+y) - relu(-x)*x
  + relu(-x+z)*y + relu(-x+y+z)*x.
```

All gate, up and down coefficients in this expression are ternary. The packed computation never reconstructs an individual input or hidden channel. Its final signed extraction directly emits the answer. [`PackedObserver.lean`](../../../Kelana/PackedObserver.lean) proves the equality on all 27 inputs by kernel reduction. [packed-observer-encoding.txt](packed-observer-encoding.txt) records that LLVM assembles the two instructions for gfx1151.

This is a constructed network, not arbitrary Bonsai weights. Its output is -1 on packed codes 0 and 1, +1 on codes 25 and 26, and zero elsewhere. It therefore demonstrates the search route, not a full-model speedup. Input packing is part of the declared interface; producing q from separate registers would add work. The two-instruction count is an assembled construction, not a measured throughput comparison. The Lean proof uses the stated bitvector meanings, not a new formalization of the complete native instruction decoder.

## Exact packed sign consumer

The [27-state bitplane construction](fiber-cost/README.md) carries the original radix-3 code through a SiLU-gated ternary sign observation. For every one of 676 gate/up weight pairs on three ternary inputs, two literal `v_bfe_u32` operations and one subtraction compute the complete observed map from the packed input. All 18,252 endpoints agree with a separately evaluated SiLU expression; the witness assembles for gfx1151. This is a three-instruction optimum only in the declared bit-lookup/subtraction grammar. The caller must already supply the packed code and prepared masks, and Bonsai's actual A4/A8 hidden quantizer has a different scale and rounding contract.

## First findings

### A reusable representation may preserve much more than one region needs

For `relu(g)*u` with ternary `g,u`, there are nine input states and three final values. If later consumers may negate either input or swap them, the reusable quotient has five states. Add cyclic gate rotation and all nine become distinguishable.

This is an exact finite example, not a complexity estimate for a real FFN. It establishes why the continuation set belongs in the representation contract. Requiring a general interface can destroy a special whole-region opportunity before hardware search begins.

The stronger example uses `(x,y)` modulo 4, with observation `x+y`. The first source step doubles `y`; the second doubles `x`. The sum carrier cannot implement the first source step, but the complete region is just twice the original sum. The reusable quotient closed under both individual steps has all 16 states. The fixed complete region has only two observed values. `Kelana/Composition.lean` already proves the corresponding integer compound-closure example; this tool makes the distinction executable.

### Information equivalence is not a valid ISA-search deduplication key

On a three-bit register, `x` and `x xor 1` have identical fibers: both are injective. For target `x & 1`, in the grammar `{and 1, xor 1}`, the first carrier needs one instruction and the second needs two. The search preserves numeric truth vectors and finds both minima.

A search keyed only by fibers would conflate these programs and could silently lose the cheaper answer. Relabeling is free only in a semantic existence query, unless a proved instruction-family symmetry also transports the continuation and its costs.

### Sufficient for every observer does not mean every chosen carrier is closed

Suppose the external observer is constant, the chosen carrier is `n/2`, and the next source step is `n+1`. Every possible observed future is preserved, but no update of `n/2` alone can reconstruct `(n+1)/2`: inputs 0 and 1 collide before the step and separate afterward.

The coarsest future-observation quotient is stable. An arbitrary finer carrier can retain additional distinctions that are not stable. Do not confuse the two when proposing an encoder.

## A second information screen

`cover.py` treats joint carrier selection as weighted set cover. Every pair of inputs with different required answers must be distinguished by at least one selected feature. It finds the cheapest sufficient selection from an additive-cost menu, or a pair that the whole menu cannot distinguish. This can reject or rank proposals before decoder search. It does not account for shared computation between features or decoder cost, and does not justify discarding a differently labeled carrier from full program search.

## Lean connection

[`Kelana/Composition.lean`](../../../Kelana/Composition.lean) proves the factorization and operation-descent criteria, chain simulation and compound closure. [`Kelana/ObserverAutomata.lean`](../../../Kelana/ObserverAutomata.lean) adds:

- `future_refl`, `future_symm`, `future_trans`: equality under every named continuation is an equivalence relation.
- `future_observes`, `future_stable`: it respects the current observation and every next step.
- `greatest_stable_relation`: every observation-respecting stable relation is contained in it.
- `restrict_operations`: adding allowed operations can only require more distinctions.
- `future_sufficiency_does_not_imply_carrier_closure`: the finer-carrier trap above.

These are generic mathematical statements. The Python refinement and search implementations are exhaustively checked on small instances, not extracted from Lean or proved equivalent to the Lean definitions.

## Reproduce

```sh
cd research/discovery/observer-search
python3 -m unittest -q
python3 demo.py
python3 inverse_labels.py
llvm-mc -triple=amdgcn-amd-amdhsa -mcpu=gfx1151 --show-encoding packed_observer.s
cd ../../..
lake build Kelana.ObserverAutomata Kelana.PackedObserver
```

The seven observer checks take about 0.3 seconds on this host. The inverse-label search additionally requires SymPy and checks each accepted function against its exact source-network basis. They include every three-state machine with two labeled transitions and a binary observer: 5,832 machines. Quotients are compared against explicit words through length two; shortest witnesses and quotient transitions are checked. Factorization is checked over all 216 three-input carrier/target tables in the declared alphabets. Weighted decoder search is compared against explicit programs through cost four, for every four-state target table. Feature selection is checked against all subsets of a four-feature menu for every three-valued target on four inputs.

`found` is an optimal decoder within the declared positive additive cost model. `exhausted_bound` means no program in the specified grammar within the cost bound. `state_limit` means incomplete exploration and is not a negative result. The arbitrary decoder table returned by `factor` is never assigned a zero implementation cost.

No new native speedup is claimed here. These tools reject invalid representations, distinguish fixed-region opportunities from reusable interfaces, and keep semantic relabeling from corrupting a costed hardware search.
