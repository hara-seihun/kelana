# A complete error contract for a byte-encoded folded query

The [exact packed KIVI factorization](README.md) moves each stored per-channel key scale onto the query and retains a distinct origin bias for each key chunk. A byte representation of that live query is a **new approximation boundary** even when every cache bit stays fixed. The formulas below separate its error from existing cache error and carry the right score invariant through softmax to the complete value/O observer. They do not assume that fewer dequantization products imply faster execution.

## 1. What the packed map actually computes

For one query head and one quantized chunk, let the original paid key fields be `origin_d`, `step_d`, and unsigned codes `c_i,d` in `[0,L]` (`L=3` for K2). In exact real arithmetic on those stored fields:

```
z_d = q_d step_d,
B_chunk = sum_d q_d origin_d,
score_i = (B_chunk + sum_d z_d c_i,d)/sqrt(D).
```

Split the live z into fixed groups. With a positive represented group scale `a_g` and signed bytes `u_d`, the changed consumer computes

```
score'_i = (B_chunk + sum_g a_g sum_(d in g) u_d c_i,d)/sqrt(D).
```

Each integer group accumulation is exact while it remains in range. For32 coordinates, `|u_d|<=127` and `c_i,d<=3` give absolute sum at most **12,192**, well within signed32. The original per-chunk bias is not a globally removable softmax offset: different chunks generally have different origins. Recent BF16 keys remain on their unchanged path.

Define the complete live-coordinate edit

```
delta_d = a_g u_d - q_d step_d.
```

Then the actual mathematical score edit is exactly `e_i=sum_d delta_d c_i,d/sqrt(D)`. This delta may include represented-scale and product rounding; it must not be identified automatically with an ideal nearest-byte error. A bound `|delta_d|<=a_g/2` requires exact nearest rounding on that same z. An implemented FP32 fold/divide may need additional terms.

A byte holding four2-bit digits can be mapped directly to four int8-safe lanes without a codebook:

```
u=(c | (c<<12)) &0x000F000F;
w=(u | (u<<6)) &0x03030303.
```

The byte lanes of w are `(c>>(2j))&3` for `j=0..3`. This is bit dilation, not weight reconstruction in FP16. It still pays two shift/or maps and two masks (subject to actual ISA fusion), byte loads/extraction and query packing before a dot4 instruction. A four-term signed integer dot sees these nonnegative lanes correctly.

## 2. A code-alphabet score-range certificate

For each quantized chunk the code range alone gives

```
lo_chunk = L sum_(delta_d<0) delta_d /sqrt(D),
hi_chunk = L sum_(delta_d>0) delta_d /sqrt(D),
lo_chunk <= e_i <= hi_chunk.
```

If there are recent unchanged keys, include their edit zero. Define

```
lo = min(0, all lo_chunk),
hi = max(0, all hi_chunk),
R = hi-lo.
```

Without recent keys, omit the explicit zero. This bounds the **oscillation** of the complete row edit, not just per-chunk variation. A common row shift cancels in softmax, but independently subtracting a center for every chunk would change the candidate probabilities. Any tighter acceptance certificate can use actual stored code directions; the alphabet bound needs no teacher attention or future keys.

Recoding the digit to `c-h` is only an exact relabeling if its compensating query-dependent bias is retained. Using an exact rather than byte-approximated query in that compensation would define a different approximation and must not silently replace a frozen reader. Neither a signed-byte opcode nor a centered alphabet makes that obligation disappear.

## 3. Sharp normalization bound, independent of logit size

Let `p=softmax(s)` and `p'=softmax(s+e)` on a finite visible row. Put `r_i=exp(e_i)` and `mu=sum_i p_i r_i`. Then `p'_i=p_i r_i/mu`. If `r_i` lies in `[m,M]`, positivity and a convex chord give

```
TV(p,p') = sum_i p_i |r_i-mu|/(2mu)
 <= (M-mu)(mu-m)/(mu(M-m))
 <= (sqrt(M)-sqrt(m))/(sqrt(M)+sqrt(m)).
```

The final gap is exactly

```
(mu-sqrt(mM))²/[mu(M-m)].
```

With `M/m<=exp(R)` this yields the sharp bound

```
TV(p,p') <= tanh(R/4).                                  (1)
```

A constant row edit has R=0 and TV0. Two endpoint ratios with mean `sqrt(mM)` attain the bound. For rational endpoints `m=l²`, `M=u²`, the lower-end probability is `u/(u+l)`. [`Kelana/NormalizedRatioRange.lean`](../../../Kelana/NormalizedRatioRange.lean) proves the actual finite rational absolute-value chord, normalization identity, sharp bound, constant-ratio cancellation and two-endpoint equality witness. The integration writer's direct Lean command exits0; exp/tanh and source-float bridges remain analytic. This is standard likelihood-ratio contraction, applied here to the explicit packed-query edit rather than an unpriced coefficient norm.

## 4. Complete value/O consequence, with baseline cache error retained

Fix the same decoded V vectors and full O used by the two consumers. For each head h let

```
D_h = max_(i,j visible) ||O_h(v_i-v_j)||.
```

The signed measure `p'_h-p_h` has equal positive and negative mass TV; the corresponding output difference is TV times the difference of two convex combinations. Hence

```
||sum_i (p'_hi-p_hi) O_h v_i|| <= D_h TV(p_h,p'_h).
```

Summing the actual head outputs before taking their norm gives the valid complete bound

```
||Y'-Y|| <= sum_h D_h tanh(R_h/4).                       (2)
```

This triangle bound can be loose because it does not use beneficial cross-head cancellation; the exact Gram observer remains stronger when available. The [value-aware ratio-box support](RATIO_SUPPORT.md) gives an exact scalar observer alternative with attaining endpoints and a sorted scan; its finite rational certificate is Lean-proved. Independent ratio boxes still relax the shared-query constraints, and exact high-dimensional norm support retains a direction optimization. It nevertheless retains actual V/O, instead of calling attention KL the final target.

Here Y is the original **quantized-cache** reader, not the teacher. If its full-panel residual norm is E and the sum of squared per-position bounds from (2) is B², then the changed reader's residual norm is at most `E+B`; squared relative error is bounded by `(E+B)²/||teacher||²`. Existing K/V quantization error cannot be silently reset to zero when assessing the new query approximation.

The native realization must still price live max/scale reductions, byte quantization and packing, each chunk's bias, recent-key path, packed-code expansion, softmax, V/O, registers, LDS and synchronization. This mathematical contract contains no native latency or arbitrary-FP32-parity claim. The [fixed KIVI2 byte consumer](../kivi-two-bit-dot-query/README.md) has all twelve causal CPU replays and compiled dot4 instructions; the [native discriminator](../kivi-two-bit-dot-native/README.md) subsequently passed all16 numerical checks in a separately admitted run, but the byte reader is slower at both tested horizons. Its earlier admission denial remains distinct provenance.
