# Source range folding minimizes an error box, not the realized quantizer loss

An invertible positive diagonal V coordinate change can be folded into the existing producer and every output consumer:

```
V' = Lambda V,       W_V' = Lambda W_V,
O_h' = O_h Lambda^-1      for every Q head using that KV head.
```

For fixed attention probabilities, the exact unquantized output is unchanged. Unlike changing an intermediate activation alone, this pays no extra runtime scale vector when the actual stored weights contain the factors. Diagonal smoothing is established quantization practice; this note identifies the precise robust-box objective, its integer structure, and the gap to real packed min/max loss. The separate [KIVI2 V/O fold](../kivi-value-scale-fold/README.md) owns actual BF16 source and cache acceptance; it is not inferred from the bound. That fixed source fold preserves all12 unquantized outputs bitwise but raises held packed-cache output error3.126% at unchanged bytes.

## 1. Complete causal output and its error set

Freeze the K cache and therefore its actual probabilities `a[h,t,i]`. For a shared KV head let `e[i,d]` be the V quantization error measured back in original coordinates. Its effect on complete output is linear:

```
(Ae)[t,o] = sum_i,d mask[t,i] (sum_h a[h,t,i] O_h[o,d]) e[i,d].
```

The mask records the **actual causal flush time**, not merely `i<=t`; recent full-precision V contributes no quantization error. All heads sharing V and their O cross terms remain inside A. If K already has error relative to the teacher, the complete error is `b+Ae` for a fixed baseline vector b. The [value-coordinate/Gram study](../value-coordinate-gauge/README.md) proves the corresponding finite transport and masked squared-response identities.

Take one original quantization group and positive calibration envelopes `M_d` with `|v_d|<=M_d` on the declared source set. For positive scales lambda define

```
H(lambda) = max_d lambda_d M_d.
```

Ideal real per-token min/max quantization with K equal subintervals has step at most `2H/K`; nearest-level reconstruction error in the scaled coordinates is at most `H/K`. After inverse transport the original-coordinate error belongs to the box

```
B(lambda) = { e : |e_d|<=H(lambda)/(K lambda_d) }.
```

The same box can be repeated across causally quantized tokens and groups. It ignores many joint restrictions of real min/max residuals, so its worst-case risk is an upper relaxation, not the actual reachable quantizer-error set.

## 2. Continuous envelope equalization is simultaneously robust-optimal

By definition `lambda_d M_d<=H`, hence every coordinate radius obeys

```
H/(K lambda_d) >= M_d/K.
```

Choosing `lambda_d=H0/M_d`, for any positive common H0, attains equality in every coordinate at once. Therefore its box

```
B* = { e : |e_d|<=M_d/K }
```

is contained in every competing diagonal gauge's envelope box. It minimizes **any** worst-case objective defined on these boxes, including `sup_e ||b+Ae||²` for every fixed multihead observer, flush schedule and K-error baseline. No diagonal output-metric or independent-head assumption is required. This is simultaneous set inclusion, not optimization of a trace surrogate.

This statement requires positive M_d. An exactly zero calibration coordinate raises a separate extrapolation/representation question; it must not be divided by zero or silently assumed zero on unseen inputs. The actual source experiment found no such channel.

## 3. Power-of-two folding and the full-observer factor

Fix the original group cap `H0=max_d M_d`. The single source policy is

```
e_d=floor(log2(H0/M_d)),    lambda_d=2^e_d.
```

Then `M_d lambda_d<=H0<2M_d lambda_d`. A maximum-envelope coordinate has exponent zero, so `H(lambda)=H0`. Thus

```
M_d/K <= H0/(K lambda_d) < 2M_d/K,
B* subset B(lambda) subset 2B*.
```

The candidate therefore has at most four times the **optimal continuous robust squared-response bound**, not four times an achieved quantizer loss. This remains true with fixed key-error baseline b. If z and -z belong to B* and each has squared response at most R, the exact finite identity

```
||b+2Az||² = 3||b+Az||² + ||b-Az||² - 3||b||² <= 4R
```

proves it directly. Homogeneity alone would incorrectly omit b. [`Kelana/ValueRangeGauge.lean`](../../../Kelana/ValueRangeGauge.lean) proves the finite rational radius lower bound/attainment, box containment, actual linear squared-response Gram/scaling, affine doubled-error identity and both factor-four bounds. The integration writer's direct `lake env lean Kelana/ValueRangeGauge.lean` exited0 after building its ValueCoordinateGauge dependency. The ideal min/max rounding bridge, log-floor bands and group-anchor characterization remain the explicit analytic arguments in this note, not claims about FP16 code decisions.

### All integer envelope candidates reduce to finitely many anchors

More generally, every integer gauge has a coordinate j attaining `H=M_j 2^e_j`. Subtract its exponent from the entire group, preserving all relative radii. The normalized H is then M_j and every other exponent obeys

```
e_d <= floor(log2(M_j/M_d)).
```

Increasing each to this upper value cannot enlarge any error-box radius and keeps j at zero. Consequently, among **all** integer exponent vectors, at least one of the at-most g anchor gauges (one per channel in a g-channel group) is no worse for every monotone box-risk objective than a proposed vector. This is a finite Pareto-cover theorem for envelope boxes, not an assertion that the original maximum anchor is exactly optimal under every observer or actual quantizer.

No anchor search is being used to change the already prescribed source experiment. Physical BF16 range/normality and exact source equivalence are additional obligations; an abstract integer anchor can fail them.

## 4. A stricter envelope can make exact min/max quantization worse

Consider two exact calibration/source vectors in a three-coordinate group:

```
v0=(4,1,4),      v1=(0,1,3),
M=(4,1,4),       O=(0,1,1),      K=3  (four levels).
```

The maximum-anchor powers are `(1,4,1)`, and the transported consumer is `(0,1/4,1)`. Original per-token min/max grids represent **both vectors exactly**. For v0 the folded vector is `(4,4,4)`, also exact. For v1 it is `(0,4,3)`, whose grid is `(0,4/3,8/3,4)`: the final coordinate rounds to8/3, so the final output becomes11/3 rather than4. Actual total squared output error rises **0→1/9**.

Yet the envelope-box maximum squared output error falls strictly: the original middle/last radii are4/3 each, giving **64/9** per token, while the folded radii are1/3 and4/3, giving **25/9**. The strongest direct source evaluation has zero error, so this is not a proposed compressed winner. It is an exact counterexample to treating a better robust bound as better realized quantization, even on the same source used to set the envelopes.

[`example.py`](example.py) replays the ideal rational grids, transported outputs and exact bounds without floating arithmetic or randomness; [`example.json`](example.json) records the results. Its rational coefficients are a mathematical fixture, not an FP16 packed-format acceptance.

## 5. Finite fields and unseen values

The preceding quantizer bound uses exact min/max fields and exact nearest-level assignment. If a code c in `[0,K]` was assigned on an ideal grid and stored origin/step have errors delta_a, delta_s, the unscaled radius becomes

```
[H/K + |delta_a| + K|delta_s|] / lambda_d.
```

Further assignment-arithmetic differences require their own error term. FP16 storage therefore does not inherit the ideal box merely because scale factors are exact powers of two. BF16 projection and O contractions also have source-rounding boundaries, checked separately in the real experiment.

Calibration envelopes constrain only the stated source set. Held channels may exceed them; held behavior is measured through the frozen original observer, not guaranteed by the train box. No consumer image, current-SOTA comparison, native speedup or model-wide generation result follows from this theorem alone.
