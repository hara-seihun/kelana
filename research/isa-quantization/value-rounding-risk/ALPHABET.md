# Change the reconstruction alphabet, not only its coupling

The completed covariance studies keep original decoded V2 levels fixed. The deterministic pair program changes assignments on that grid, but loses to a smaller retention control. A different representation premise is a shared four-level reconstruction alphabet: still2-bit labels and the same per-group FP16 low/step, but the labels no longer mean integers0,1,2,3. One16B FP32 table per layer is model-specific shared state; the reader must actually consume it.

## Frozen source objective

For each original V record that reaches a V33 flush on the eight train windows, let v be the original BF16 value and a,b its actual original FP16 affine fields. For b>0 form normalized target z=(v-a)/b and source weight

```
kappa = ||O0_column||²+||O1_column||²,
w = b²*kappa.
```

Use both same-layer Q-head O columns of this KV coordinate. With ideal arithmetic,

```
kappa*(v-(a+b*c))² = w*(z-c)².
```

One weighted four-means fit on sorted z therefore targets source-diagonal O energy without query/attention data. Zero steps produce a constant decoded value and do not affect the alphabet. The fit uses train source only; each layer has its own source and16B alphabet. Held data and full-output outcomes do not select levels, partition count or arithmetic precision.

The declared fit is weighted one-dimensional contiguous-cluster dynamic programming. After a single FP32 rounding of its four centroids, the actual encoder enumerates four **actual FP32 decoded levels**, using the original stored fields and separate multiply/add, and chooses nearest source value with a declared tie rule. This actual nearest assignment need not reproduce ideal calibration cluster boundaries after rounding. Fields, K, recent BF16 words and causal flush timing stay unchanged. The reader uses the table rather than pretending the code labels still decode as integers. Original/moment/delay/K2V4 controls retain their own bytes and costs.

## Prior-art boundary

Sorted one-dimensional k-means dynamic programming is established; see Wang and Song, [*Ckmeans.1d.dp: Optimal k-means Clustering in One Dimension by Dynamic Programming*](https://journal.r-project.org/articles/RJ-2011-015/) (The R Journal,2011). Neither scalar centroid fitting nor nonuniform reconstruction levels are claimed as new. The local contribution is the frozen source weighting, actual original-field/rounded-table causal program, complete-output/cost comparison and exact proof boundary. The rational weighted identities below do not turn the numerical implementation into an exact solver certificate.

## Exact calibration foundation

[`Kelana/ValueAlphabetCalibration.lean`](../../../Kelana/ValueAlphabetCalibration.lean) proves finite rational statements, separately from the numerical fit implementation:

- Weighted cost expands into second moment, first moment and mass.
- If a centroid c satisfies `W*c=Σwz`, then `cost(d)-cost(c)=W*(d-c)²`. Thus it minimizes a nonnegative-mass cluster, and once-rounding its center incurs this exact ideal penalty.
- Source affine normalization and the separate decoder-defect cross term are exact algebraic identities.
- Ordered centers induce ordered nearest-distance cells; the difference changes by `2*(b-a)*(y-x)` between ordered points.
- Merging two centered chunks gives the usual between-chunk variance from actual finite source sums.
- For successive chunk masses a,b,c and mean gaps l,r≥0, the Monge gap after intrinsic within-chunk errors cancel is

```
a*c/(a+b+c) * [a/(a+b)*l² + 2*l*r + c/(b+c)*r²] >= 0.
```

  The identity is proved by exact denominator cancellation, including zero middle mass when the outside masses are positive. Adding the preceding DP layer's row potential preserves the inequality. Earliest minimizing cuts cannot move backwards; the feasible comparison and strict-earliest-tie premises are explicit.

Direct Lean compilation exits0. These facts explain contiguous weighted DP and its monotone minima. They do not prove a particular floating divide-and-conquer implementation immune to cancellation or certify its rounded result as the exact rational global optimum. The independent fit/source checks and emitted table own the numeric boundary.

## Packed labels are computation coordinates

The same Lean module proves the exact Boolean map for any four levels:

```
level(lo,hi) = c0 + (c1-c0)*lo + (c2-c0)*hi
                 + (c3-c2-c1+c0)*lo*hi.
```

It then carries this labeling through the complete scalar weighted value sum. With token-specific affine fields, four weighted statistics suffice: the affine offset and the three bit terms. Uniform integer reconstruction has zero quadratic-bit coefficient; a general alphabet need not. This is a structural reader identity, not an instruction-count improvement. Actual floating reduction, static coefficients, bit placement, shared partials and boundary conversion must be priced before choosing such a realization. The current paid reader uses its actual table directly; this theorem does not silently replace it by reassociated arithmetic.

## Why full output and cost still decide

The fit omits other coordinates, tokens, shared-head cross terms and fixed K/source error. The [exact omitted-response theorem](../value-pair-covariance/CODES.md) still applies. Local source-diagonal improvement is not an output guarantee. Each table read, preparation step, lookup decision and persistent field must be counted before a quality/state/execution claim. A negative result stops this alphabet; there is no four-level table, clipping or fit-restart ladder.

## Completed paid source result

The [one paid alphabet program](../kivi-value-alphabet/README.md) retains physical16B tables, actual events/images and independent source/field/digit/phase/full-O receipts. Complete SSE falls **209.016698→181.835822** on contextual train, **107.923584→92.407606** on validation, and **.832658→.753385** on eight retained layer0 queries. The candidate's single-sequence peak is **304784B**,16B above original; the improvement is not inferred from its larger source-diagonal gain. The3328B delay2 control is worse on all three pooled panels; the4096B independent-code moment is worse contextually but better on layer0. K2/V4 is more accurate with57072B more peak state. The distinction between these rates is essential.

The initial invalid layer1 run used a layer0 donor path; source-field checks caught it. The owning fit/producer/reader now select and validate the correct contextual donor and all final evidence was regenerated from that corrected source. The source law/table count was not tuned after outcomes. The numerical fit's global-minimum algorithm is not called an exact-rational optimality certificate. The [complete native producer/reader/control](../kivi-value-alphabet-native/README.md) is now compiled and source-reviewed. It starts from empty resident state, encodes actual arrivals, and uses the uploaded table in the full16Q/8KV/O query. Its candidate reader body is14096B versus13968B for control; the shared four-way producer body is2968B. The benchmark loads both readers and counts all40376B of code plus448B descriptors, separately from4548612/4548628B explicit control/candidate global allocations. Thus16B is the data-state increment, not the entire program-description difference. All4096 CPU physical phase checks and eight candidate target hashes pass. Device acceptance then independently matched4096 actual phase images/4358144 ordered records and all16 complete-output guards, maximum coordinate error1.431e-6. Actual teacher SSE is.8326574748→.7533859211, preserving9.5203% improvement. On32 fresh order-balanced t128/t256 pairs, candidate/control event ratio median is1.144219; candidate is slower on all32 (t128 median1.124253,t2561.188503). Events include input transfer, append, complete query/O and scheduled K/V flush. Host wall additionally includes output-file/validation work and is not pure serving latency. This is a measured layer0 quality/state/time tradeoff, not a speed win or complete-model deployment.

## Exact encoder decision without squares

[`Kelana/AlphabetThresholdDecision.lean`](../../../Kelana/AlphabetThresholdDecision.lean) proves that for strictly increasing **actual decoded** rational levels, nearest squared-distance selection with the lowest-label tie is exactly the first satisfied test

```
2*x <= l0+l1; 2*x <= l1+l2; 2*x <= l2+l3.
```

It proves comparison with all four labels, including strict superiority to every earlier label, and the all-coincident zero-step case. Thresholds are sums of actual decoded values, not unrounded ideal affine fields. Three adjacent sums can therefore be prepared once for the32 coordinates sharing a field pair; four squares per coordinate are not mathematically necessary. The general partial-duplicate case is outside this strict-order theorem.

The [single CPU/compile-only lowering](../kivi-alphabet-threshold-encoder/README.md) keeps the table, field computation, reader and placement. It compares doubled source values with FP64 sums of the actual FP32 levels and maps coincident selected levels to their first label. All16 emitted source windows match:28672 V records,3670016 coordinate choices and11010048 exact boundary checks, with zero changed decisions or rounded adjacent sums. The smallest nonzero exact boundary margin is5/33554432. These source-word checks, not an unrestricted floating-point theorem, connect the rational identity to the frozen encoder. The CPU parity path consumes original field words; unchanged GPU field generation is inherited from the accepted native source.

This realization fails its compiled-description objective: V33 body2968→9124B, full module40376→46532B, static vector ALU310→1003. It removes FP64 square sites (multiply17→1), but compare/add expansion more than offsets the static reduction; VGPR falls56→50, zero V LDS/private scratch remains. Static sites are not dynamic latency. No GPU execution or further expression/precision/placement variant was run. Retain the exact identity and source-byte witness, but do not replace the measured native program with this larger-code realization or claim an inferred speedup.
