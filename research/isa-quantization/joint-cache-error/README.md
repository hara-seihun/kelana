# Joint K/V cache error: exact interactions and the frozen KIVI baseline

Key and value errors are coupled at the live output, but a possibility of cancellation does not mean a particular cache is exploiting it. This study derives the exact finite error decomposition and measures it on all twelve already captured [KIVI causal-cache](../kivi-causal-cache/README.md) windows. **Both K and V contribute materially.** Their cross inner product is small on the aggregate held panel: the separate losses sum to `.000154925`, close to the full `.000155356`. No new cache was fitted and no GPU was run.

## Exact finite decomposition

For one causal query, let p be the teacher probabilities, a the candidate probabilities, v the teacher values after any fixed linear O map, and d the candidate value changes in that same output space. Define

```
E_K = sum_i (a_i-p_i) v_i,
E_V = sum_i p_i d_i,
C   = sum_i (a_i-p_i) d_i.
```

Then the complete error is exactly

```
E_both = sum_i a_i(v_i+d_i)-sum_i p_i v_i = E_K+E_V+C.       (1)
||E_both||² = ||E_K||²+||E_V||²+||C||²
              +2<E_K,E_V>+2<E_K,C>+2<E_V,C>.               (2)
```

The same decomposition applies to two heads sharing a cache by adding their O-projected vectors **before** taking norms. Summing per-head errors would lose another set of cross terms. These are finite algebraic identities, not a small-quantization approximation.

When both probability rows sum1, C is unchanged by replacing every d_i by `d_i-c` for any common c. For strictly positive p, weighted Cauchy gives

```
||C||² <= [sum_i (a_i-p_i)²/p_i] * sum_i p_i||d_i-E_p d||². (3)
```

`Kelana/JointCacheError.lean` proves the finite rational scalar identities, squared cross terms, iff-zero cancellation, centering and bound(3), using the previously proved finite weighted Cauchy. Summing coordinatewise gives the Euclidean vector bound analytically. No softmax, floating arithmetic or source-model conclusion is a premise of those rational identities.

### Coupled errors can cancel exactly

The four-byte toy in `witness.py` has teacher p=(1/2,1/2), v=(-1,1), output0. A same-byte candidate uses a=(3/4,1/4), changed v=(-1/2,3/2). Its key-only error is−1/2, value-only error+1/2, and C=0: **two separate squared losses of1/4 give zero combined loss**. Actual integer probability/value fields are decoded independently. A direct constant-zero reader is exact and smaller, so this is an algebraic witness rather than an improved cache.

This cancellation is for the declared query. A shared causal cache cannot choose a different value compensation for every future query for free. Independent K/V rejection gates can miss joint programs, while extrapolating this tiny cancellation to all queries would be equally wrong.

## Analytic first variation, with the query fixed

Let candidate logits be `l+t e` and values `v+t d`, with p=softmax(l), y=E_p v. Then

```
dy/dt at0 = E_p d + sum_i p_i(e_i-E_p e)(v_i-y).            (4)
```

For key changes at fixed q, `e_i=q dot deltaK_i/sqrt(head_width)`. If O is fixed it can be incorporated in v,d before applying(4). This is the ordinary softmax Jacobian, not a globally exact error formula. Common logit shifts vanish; value directions determine which score errors matter. The cross term C in(1) is of second order when both field perturbations are small, but `2<E_K,E_V>` is already part of the leading squared error. A joint quadratic objective therefore generally differs from the sum of separately optimized K/V objectives.

## Frozen source measurement, no changed reader

`measure.py` imports the original source producer and the independent packed decoder from the KIVI owner. It reconstructs each pre-query state from **current source insertions and the timed packed flush log**, verifies every before/after prefix hash and the final image, and decodes only fields available at that prefix. No final-cache quantization is retroactively applied to an earlier query.

The immutable source BF16/FP32 Q/K/V/O and actual FP32-decoded KIVI cache are then promoted to **FP64 for the diagnostic logits, probabilities, value contractions and O**. This isolates the algebra from FP32 summation differences; it is not a native/full-model replay or a replacement for the owner's original FP32 score. The original teacher K is the FP32 rotary result, so K error includes the original KIVI BF16 recent/input rounding as well as quantization. V is the original BF16 projection. All8 train/four inspected-held windows and both Q heads are retained; no data/fit/codes/configuration are changed.

For each prefix we calculate the actual K-only, V-only, interaction, both-changed and first-order-K vectors in the original shared two-head O space. Only after summing both heads do we collect squared norms and inner products. `aggregate.py` sums numerators and the common original-teacher denominator across windows, not relative-error averages. Every receipt pins the owner source, decoder, manifest and original result hashes.

| Complete two-head O, relative squared quantities | Train | Inspected held |
| --- | ---: | ---: |
| K-only error | .0000898192 | **.0000914772** |
| V-only error | .0000457191 | **.0000634475** |
| Exact interaction C | .0000002822 | .0000004045 |
| Twice K/V inner product | +.0000010273 | **−.0000001395** |
| Sum of separate K/V squared errors | .0001355382 | .0001549246 |
| Full actual error in diagnostic arithmetic | **.0001366115** | **.0001553556** |
| First-order predicted error squared | .0001329046 | .0001530317 |
| Squared discrepancy between first-order and actual error vectors | .0000010694 | .0000012532 |

Full identity(1) closes within **1.09e−16** per O coordinate. The owner's FP32 held pair error `.000155354877` and this `.000155355552` diagnostic differ only at the expected arithmetic boundary. The small held twice-inner-product is not a universal independence claim: individual windows have either sign, and different quantizers can create very different alignments. The first-order vector discrepancy is about0.81% of actual held **squared** error, not a0.81% relative vector error guarantee.

The frozen cache therefore does not hide a large beneficial K/V cancellation that can be harvested merely by retuning a common value bias. A source-aware K assignment and a V improvement are both plausible targets, but must earn complete causal output at their paid state/preparation cost. This diagnostic does not predict the outcome of another quantizer, and the general coupled construction is not rejected by it.

## Custody and cost

No new inference state or model image is created by the real-source measurement. The existing KIVI state remains52,400B peak /46,592B final; common model fields, original query producer, min/max quantization/flush, recent K/V, softmax and O are unchanged. This offline diagnostic materializes decoded prefixes and FP64 values and is not a memory-efficient deployment. Source capture and paid cache files remain with the original owner. New compact receipts and toy fields are owned here.

```sh
python3 research/isa-quantization/joint-cache-error/witness.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/joint-cache-error/measure.py train 0
# Same individual command for train1..7 and held0..3; each bounded under one minute.
python3 research/isa-quantization/joint-cache-error/aggregate.py
lake build Kelana.NormalizedKernelError
lake env lean Kelana/JointCacheError.lean
```
