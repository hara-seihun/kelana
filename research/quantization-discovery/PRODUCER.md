# Quantization over correlated producer domains

This continues the [first quantization investigation](README.md). The target is an error guarantee over a producer's reachable outputs, rather than agreement on a few captured inputs. The source analysis is in [BONSAI-PRODUCER.md](BONSAI-PRODUCER.md). The executable work uses exact integer arithmetic and runs without the GPU or inference service.

The next round, [ENCLOSURE.md](ENCLOSURE.md), implements the source-aware floating-point continuation. It proves a fixed hidden-code block over a declared local input contract and finds a five-byte exact replacement for a real block. Its literal guard is much larger than the saved weight payload, so this remains a conditional semantic result rather than net model compression.

## The domain and its exact support

Write a producer envelope as

```
x = (c + sum_j b_j z_j + delta) / D,
integer |z_j| <= r_j,
integer |delta_i| <= epsilon_i,
D > 0.
```

For weight error `e = q-w`, its exact worst-case absolute response error is

```
S(e) / D = (|e.c| + sum_j r_j |e.b_j| + sum_i epsilon_i |e_i|) / D.
```

The maximum is attained: choose every coefficient's sign so its contribution agrees with the center projection. There is no need to enumerate the domain. Coordinate residuals are ordinary basis-vector generators. Integer coefficients and a common denominator also represent rational lattices; no floating-point rounding is hidden in the formula.

[ProducerDomain.lean](../../Kelana/ProducerDomain.lean) proves the vector-to-scalar projection, upper bound, attaining witness, containment transport, and equality modulo directions invisible to the producer. The [proof guide](PRODUCER-PROOFS.md) names the exact interfaces.

The important distinction is between two obligations:

1. Computing the support of this declared domain is solved exactly.
2. Proving the actual producer stays in this domain is a separate obligation.

A box fitted to observations does not discharge the second obligation. The real-data experiment below deliberately tests that failure.

## The search parameter is the number of live correlations

For a fixed menu of block representations, each choice contributes to every projected error `e.b_j`. Its final absolute value couples choices from different blocks. Coordinate residual charges are already block-local.

The exact solver processes blocks in order. When no future block can change a projected error, it charges its absolute value permanently and removes that coordinate from the search key. Of histories with the same remaining sums, only the cheapest matters. It retains the chosen representation as a witness.

This is variable elimination applied to the producer-derived objective, not a new general-purpose DP algorithm. [ProducerElimination.lean](../../Kelana/ProducerElimination.lean) proves the closure identity and safe replacement under identical legal continuations. It also supplies a finite-menu Bellman theorem. See [ELIMINATION-PROOFS.md](ELIMINATION-PROOFS.md).

If the live factors at stage `i` have integer ranges of widths `R_j`, the number of possible keys is at most `product_j (R_j+1)`. A small number of live factors and small numeric ranges give a tractable family even when the total number of generators grows with the model. This is a pseudo-polynomial bound in the numeric ranges. A dense generator matrix can keep every factor live and defeat this solver.

The implementation limits states and reports `width-limit` if that limit is exceeded. It does not discard states and call the result exact. Block order affects width; reordering is permitted only when the underlying menu charges and legal actions permit it.

### An arbitrary-length chain

Let the producer be `x_i = z_i-z_(i+1)` with independent integer `|z_j|<=1`. The support is the total variation of the error row, including the two boundary terms. With two choices per weight, only one generator sum remains live across each cut, and that sum has at most two values. Thus each new block needs at most four transitions, regardless of chain length or the exponential number of complete assignments.

At 160 blocks the solver reaches the exact optimum **282** in **638 transitions**, retaining **two states** and **one live factor**. Keeping the full response history instead reaches the 4,096-state cap after completing only 12 blocks. The source row has mixed runs of zeros and ones; the optimum includes coupled decisions rather than independently choosing the cheapest weight code.

Transition counts exclude domain projection, lifetime preprocessing and witness copying. The current implementation stores the coefficient matrix densely. The entire experiment suite, including the real-data LP, completes in about one second on this host.

This is the change from the earlier DP: completed correlations disappear from state. Equality of the whole response vector is unnecessarily strong once part of the objective can no longer change.

### Exact sub-bit storage on a nonzero consumer

A controlled producer duplicates coordinates: `x_(2j)=x_(2j+1)=z_j`, with integer `|z_j|<=127`. This domain has `255^64` inputs. The source row has cancelling `[1,-1]` pairs in its first half and `[1,1]` pairs in its second half, so the consumer is not the zero map.

The same prefix-free eight-trit codec from the first investigation stores zero modes for the first half and repeated-positive modes for the second. It uses **48 bits including the FP16 scale**, or **0.375 bits per original weight**, and has **exactly zero error throughout the declared domain**. The DP certifies optimality within that codec menu. The saved six-byte packet round-trips through the actual codec. No learned dictionary or uncounted weight payload is needed.

This is a constructed producer, not a Bonsai compression claim. Its role is to exhibit a whole class where producer-dependent quantization changes weights while preserving every reachable output.

## Real Bonsai: retaining a transform is not enough

The captured down-projection block has 128 integer hidden operands. The last mixing operation in its producer is a 1,024-point Hadamard, followed by separate 128-entry dynamic quantizers. On one 128-entry output block, the 128-point Hadamard basis is aligned with the low-index factor of that mixing transform. It is not the inverse of the complete producer: the other factor, scales, nonlinearity and rounding remain relevant.

We transformed the three calibration captures with an unnormalized `H_128`, took a min/max interval in each transformed coordinate, and mapped that box back. With `H^2=128 I`, the exact integer representation uses center `H(low+high)`, generators equal to columns of `H`, radii `high-low`, and denominator 256. Every calibration point has an explicit integer coefficient witness.

The experiment asks two separate questions.

**Does this empirical correlated domain contain held-out producer outputs?** No. All five held-out captures escape it, violating respectively **62, 54, 70, 71 and 58** of its 128 transformed intervals. Keeping the Hadamard basis does not turn fitted intervals into a producer certificate.

**Can our current code menu compress safely throughout that domain?** No. Its exact robust optimum is **272 bits and zero error**, choosing every literal. Original HALO storage is **224 bits**. A rational signed dual, replayed using only integer arithmetic, meets the literal upper bound exactly at `69632/256 = 272`. This is an optimality result for the declared family, not just a failed heuristic search.

The earlier 63-bit candidate has worst-case error **3230.484375** on this domain, compared with 25 on the three individual calibration observations. It was exploiting cancellations that independent latent intervals do not preserve.

### What a missing residual guarantee costs

A second diagnostic uses the three captured inputs themselves as generators, then adds an independent coordinate residual of radius `rho`. The support is exactly

```
sum_(three captures x) |e.x| + rho ||e||_1.
```

A feasible 90-bit candidate has support 68 at `rho=0` and weight-error L1 mass 85. At `rho=1`, the same candidate's objective increases from 158 to 243, already above the exact source codec's 224 bits. Its break-even residual radius is `66/85`, less than one integer activation unit. These are feasible candidates, not globally optimal assignments in the tube domains.

This quantifies the missing assumption. A low-dimensional fit is useful only if we can control the off-domain component tightly enough. More calibration points alone are not a mathematical containment proof.

## Source-derived guarantees, as opposed to fitted envelopes

Bonsai's gate and up projections read the same upstream quantized input. At their exact integer block accumulators, for any probe `(a,b)`,

```
max_(|q_k|<=127) |a sum_k gate_k q_k + b sum_k up_k q_k|
    = 127 sum_k |a gate_k+b up_k|.
```

Treating gate and up independently instead gives

```
127 (|a| sum_k |gate_k| + |b| sum_k |up_k|).
```

The joint bound preserves real cancellations before applying absolute values. On layer 0, row 0, input block 0:

| Joint probe | Independent bound | Exact shared-input bound | Reduction |
|---|---:|---:|---:|
| Gate + up | 21,844 | 15,748 | 27.9% |
| Gate - up | 21,844 | 12,700 | 41.9% |

Each maximizing input is an explicit saturated integer corner, so the quantizer's saturation constraint does not invalidate attainment. The fixture and witnesses are recorded in [producer-results.json](producer-results.json). This guarantee applies to the integer accumulator interface over its bounded-code relaxation, not automatically to SiLU, floating-point scaling or the full FFN. The corner need not be reachable from a complete model history.

[BONSAI-PRODUCER.md](BONSAI-PRODUCER.md) also derives a global real-arithmetic norm budget and a local fixed-upstream-code construction through the shared scale variables. Certifying the deployed floating-point continuation still requires outward bounds for the actual RMS reduction, reciprocal square root, Hadamard, exponentials, scale calculation and FMAs. The subsequent [local enclosure](ENCLOSURE.md) implements these stages after the upstream quantized-input boundary. The full RMS-to-hidden global enclosure remains unfinished. Neither uses an observed CPU/GPU discrepancy as an error allowance.

## Reproduce and proof boundary

[producer_search.py](producer_search.py) owns the integer domain, menu compilation, frontier DP and dual replay. [producer_experiments.py](producer_experiments.py) owns the deterministic experiments and LP proposal. [check_producer_results.py](check_producer_results.py) replays the saved real-block certificate without solving the LP.

```
lake build Kelana.ProducerDomain Kelana.ProducerElimination
python3 research/quantization-discovery/producer_experiments.py
python3 research/quantization-discovery/check_producer_results.py
```

The generator uses the system Python's NumPy and SciPy for a small LP proposing signed dual coefficients. The LP is not trusted: coefficients are bounded, quantized to rational values, and every option minimum is recomputed with integers. `ProducerDomain.separableDual_lower` and `separableDual_ceiling_lower` prove the signed-L1 bound and its integer-ceiling form. The latter theorem covers nonnegative cleared numerators, including the saved certificate. The saved optimum can be replayed with the standard library alone. Source and fixture hashes are recorded.

The run compares 12 exact support calculations with corner enumeration, 24 frontier DPs and 24 signed dual bounds with exhaustive small-instance optima, and rejects an out-of-range dual. The two Lean modules prove the inference rules; the Python implementation and saved JSON are not themselves Lean proofs.

No GPU timings, full-model quality improvement or new Bonsai weight file are claimed. The directed local producer enclosure now lives in [ENCLOSURE.md](ENCLOSURE.md). The remaining search task is choosing broadly valid producer contracts and block/generator decompositions that keep both the domain description and live factor set small without discarding real dependence.
