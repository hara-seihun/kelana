# Chronological feedback and the complete observer

First-order error feedback is standard noise shaping. Its useful invariant is a temporal difference, not a guarantee about an arbitrary future attention row. The [frozen paid experiment](README.md) measures that distinction with unchanged K, original V grids and a 4,096-B residual state; it does not choose a feedback filter from held queries.

## Exact recurrence, with the floating defect retained

For one coordinate, let `v_i` be the arrived value, `d_i` the reconstruction from the actual stored grid, and `r_i` the carried residual before quantizing aged token i. Define the defect by

```
r_(i+1) = r_i + v_i - d_i + eta_i.
```

Thus `e_i = d_i-v_i = r_i-r_(i+1)+eta_i`. In exact arithmetic eta is zero. In the actual program, FP32 target addition and residual subtraction both contribute to eta; stored FP16 grid rounding is already in d, not discarded as an ideal decoder. For any m aged tokens and any scalar weights,

```
sum_(i<m) p_i e_i
 = p_0 r_0 - p_m r_m
   + sum_(i<m) (p_(i+1)-p_i) r_(i+1)
   + sum_(i<m) p_i eta_i.
```

The arbitrary extension p_m cancels algebraically. Setting it to zero exposes the finite-prefix boundary. With r_0=0 and uniform weights p_i=c, the expression is `-c*r_m + sum c*eta_i`. If the complete row has T tokens but only its first m have aged, recent tokens have no quantized V error; uniform attention therefore uses c=1/T, not 1/m. The residual update happens **after** the query that triggers aging. A t256 preflush query reads 223 quantized V tokens, not the 224 in its after-flush state.

[`Kelana/ValueErrorFeedback.lean`](../../../Kelana/ValueErrorFeedback.lean) proves the finite rational recurrence/error sign, weighted identity for every m including zero, uniform corollary, scalar linear-coordinate pushforward, and a two-token zero-sum/selective-readout witness. These statements do not assume floating exactness or bounded residuals.

## The observer pays weight variation

For m>0, r_0=0, nonnegative attention weights and a bound `||r_j||<=rho`, the triangle inequality gives

```
||sum_(i<m) p_i e_i||
 <= rho * [p_(m-1) + sum_(1<=j<m) |p_j-p_(j-1)|]
    + sum_(i<m) p_i ||eta_i||.
```

This is an analytic norm consequence of the finite identity, not a new Lean norm theorem. Uniform weights leave only the endpoint. A concentrated interior-token row can instead pay nearly 2rho. The bound does not assert that the actual stored grids keep rho small. The ideal changing-grid condition and the additional finite-arithmetic obligations are separated below.

For the actual multihead observer apply each head's fixed O block to the residual coordinate vector, then weight by that head's **actual K2 probabilities** and sum heads before taking a squared norm. The [value-coordinate owner](../value-coordinate-gauge/README.md) gives the complete fixed-probability linear map and its cross-head Gram form. Error relative to the original teacher also contains the already present K/source error as an affine offset. Consequently a smaller temporal prefix sum, or even a smaller separate V error, need not reduce the full teacher error.

## Stability is possible across changing ranges; finite defects must be paid

Changing ranges alone do **not** prevent first-order stability. Suppose the i-th ideal clipped quantizer has endpoints `a_i,b_i` containing its original source `v_i`, returns the appropriate endpoint outside that interval, and has interior error at most `h_i`. Then

```
|r_(i+1)| <= max(|r_i|, h_i).
```

Above the upper endpoint, clipping leaves `r_i-(b_i-v_i)`, between zero and the positive carried residual. The lower case is symmetric. Inside, the quantizer's gap bound applies. Hence a uniform gap bound H and `|r_0|<=H` bound all ideal residuals by H even when the ranges change at every step. A nearest uniform grid has interior radius half its spacing; the finite theorem uses the endpoint/interior property explicitly rather than assuming a particular nearest-grid implementation.

For the actual arithmetic, separate target-addition error beta, reconstruction discrepancy xi from that ideal quantizer (including stored fields **and any changed code decision**), and residual-subtraction error gamma:

```
target = v_i+r_i+beta_i
r_(i+1) = target - (ideal_decode(target)+xi_i) + gamma_i.
```

If their absolute values are bounded by U_i,D_i,G_i, respectively, the uniform-gap result becomes

```
|r_n| <= H + sum_(i<n)(U_i+D_i+G_i).
```

The same Lean file proves the clipped local bound, perturbed local bound and this complete finite varying-grid budget using rational interval inequalities. Its premises are not a GPU/FP32 certificate. In the earlier recurrence the actual d already includes xi, so **eta=beta+gamma**, not beta+xi+gamma. This avoids charging field error twice in the weighted identity while still charging it in the residual-stability budget. No source or candidate was rerun to assert these premises for the experiment.

## Stable residuals still do not imply selective-output improvement

A complete exact four-token counterexample uses source coordinate `v_i=1/12` and the unchanged two-bit grid `{0,1/3,2/3,1}`. The source group may include constant coordinates 0 and1 to supply these extrema; a scalar observer selects only this interior coordinate. Original nearest-grid codes are all zero. With first-order feedback and nearest-even ties, the four emitted codes are `(0,0,1,0)` and residuals are `(0,1/12,1/6,-1/12,0)`. Every code minimizes exact squared distance to its shifted target, all residuals stay within half a grid step, and the final residual is zero.

Uniform averaging gives zero feedback error, versus original error `-1/12`. But the strictly positive normalized weights `(1/12,1/12,3/4,1/12)` give feedback error `1/6` versus the same original error `-1/12`: **four times the squared output error**. `witness_grid_and_recurrence` and `witness_stable_but_selective_worse` in the Lean owner verify all finite choices, updates, bounds and weighted errors by kernel reduction. This is an exact quantizer/observer counterexample, not a claim that these probabilities occur in a particular captured model. It establishes that clipping instability, source rounding and end-residual accumulation are **not necessary** for feedback to lose under selective attention.

## What the one realization establishes

The actual eight retained full-O observations improve pooled error from .003068937 to .002139543, at 308,864 B cache-plus-residual peak. This is a measured 30.28% reduction, not a consequence of the identity. The unchanged-code V34 retention control is 768 B smaller and gives .002973482; feedback beats it in six of eight states. K2/V4 is more accurate overall at a larger 361,856-B peak. No gain, order, filter, or second precision was selected. The [completed native realization](../kivi-value-feedback-native/README.md) preserves every actual cache/residual phase and the measured output gain, while costing4096B more globals and1.084× median paired flush-boundary event time. The query's unchanged format does not make encoding free.

The [unchanged contextual layer1 test](../contextual-value-feedback/README.md) instead loses: full-query train SSE rises14.70% and inspected validation rises11.58%, while the smaller original-code V34 control improves both pooled scores. Its input is the original teacher's captured layer0 residual, with a declared CPU layer1 projection/observer; it is not a rollout of the layer0 candidate. The counterexample above rules out a generic inference from stability to quality but does not identify which mechanism causes this model's loss. The [completed selectivity/residual diagnostic](../value-feedback-selectivity/README.md) now shows the direct observer distinction on matching eight held positions per layer: layer1 uniform V-error SSE falls99.24%, while actual selective V error rises45.85% and complete error rises15.80%. It preserves the K/source offset and every signed inner product. Encoder residuals remain finite (largest observed.194036 in layer1) and actual update defects are at most2.98e−8; clipping counts do not by themselves establish clipping as the cause. These are measured finite-image observations, not a proof of optimal routing or a fitted next reader. The separate [residual-transport contract](TRANSPORT.md) states how a changed causal route would pair with actual attention differences, retaining skipped errors and the pending-recipient mask before any source geometry is mistaken for output cancellation.
