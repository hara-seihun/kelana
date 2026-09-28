# Exact observation through the Qwen post-MoE RMSNorm

The question is whether a complete post-MoE hidden vector can be replaced by a positive-ray label when the next consumer normalizes it. This is an endpoint/fiber question, not an obligation to reconstruct every source expert. For the pinned Qwen3.6-35B-A3B GGUF, [Bonsai's installed-weight census](../../../../bonsai-halo/docs/qwen-moe-rms-observation.md) checks the actual next-norm gains and epsilon. Every one of the forty relevant 2,048-coordinate gain vectors has no zero or nonfinite coordinate; `epsilon = 9.999999974752427e-7 > 0`. Layers 0–38 feed the post-MoE residual to the next layer's attention RMSNorm and layer 39 to the output RMSNorm. The [source/inventory/acquisition/payload-hashed CPU receipt](/path/to/workspace/data/qwen-moe/rms-observation/receipt.json) owns the installed-image facts.

## Complete-vector fiber theorem

**Domain:** all finite real vectors `x ∈ R^d`. **Observation:** the entire ideal-real RMS-normalized vector, not final logits, argmax or a subset of channels. **Parameters:** positive real `e` and fixed gains `g_i ≠ 0` for every coordinate. Define

```
F(x)_i = g_i x_i / sqrt(e + ||x||₂²/d).
```

**Result:** `F` is injective, including at zero. More strongly, it has an explicit inverse on its image. Given `y=F(x)`, set `z_i=y_i/g_i` and `q=||z||₂²/d`. If `s=||x||₂²/d`, then `q=s/(e+s)<1`, so

```
x_i = z_i sqrt(e/(1-q)).
```

This identity both constructs the inverse and proves equal fibers: `F(x)=F(x')` implies `x=x'`. With any *fixed* residual/shared contribution `b`, the map `r ↦ F(b+r)` from routed expert sum `r` is also injective. A carrier that identifies distinct `r` values cannot reproduce this complete observation; in particular, a positive-ray label does not suffice. This is different from the `e=0` map, whose nonzero positive-ray fibers coincide when all gains are nonzero. A variable `b` must itself be carried jointly with `r` or otherwise recovered; the fixed-`b` statement does not require the routed sum as an intermediate in a different complete-map program.

The inverse is a **semantic witness, not a free implementation**: it evaluates a norm, division, a square root and coordinate gains. Its existence supplies no native instruction or weight-byte lower bound. It is also not bit-identity in native FP32: rounded real inputs may coalesce after floating-point normalization, and the selected kernel's reduction/rounding order is a separate contract. A weaker final observation may have coarser fibers even if the intermediate complete vector does not. Thus this theorem rejects only *exact real projectivization at this boundary*, not a search over joint producer/consumer labels or an output-level quotient.

## Conditional approximation modulus

For the unweighted map `f(x)=x/sqrt(e+||x||²/d)`, the Jacobian is

```
Df(x) = I/sqrt(e+s) - xxᵀ/[d(e+s)^(3/2)],  s=||x||²/d.
```

Its tangential eigenvalue is `(e+s)^(-1/2)` and its radial eigenvalue is `e(e+s)^(-3/2)`. On the ball `||x||≤R`, the radial eigenvalue is at least `m=e/(e+R²/d)^(3/2)`. Integrating the quadratic form of `Df` along the segment from `x` to `x'` and applying Cauchy–Schwarz gives `||f(x)-f(x')||≥m||x-x'||`. Multiplication by the nonzero diagonal gains then gives

```
||F(x)-F(x')||₂ ≥ (min_i |g_i|) e/(e+R²/d)^(3/2) ||x-x'||₂.
```

The installed minimum absolute gain is `0.12109375`. For the illustrative ball `R=√2048`, this guaranteed coefficient is only about `1.210935e-7`; **this radius is not a measurement of actual Qwen hidden states**. Radial distinctions can be numerically minuscule even when their exact fibers are singleton. The bound is ideal-real and conservative, not a tolerated native or language-loss error budget.

## What it changes

The previous [projective routed-sum observer](../../../../bonsai-halo/docs/qwen-moe-routed-norm-observer.md) grants an epsilon-free direction quotient **only on the isolated routed sum**; its callback did not save residual or shared-branch outputs. It cannot be called an exact next-layer RMSNorm observer. It found that even this freely weakened isolated observation saves almost no unchanged-expert traffic at 5% local direction error. The useful next test captures the actual post-add producer (or both residual and shared branch alongside routed output), proposes a paid changed coordinate, evaluates disjoint *complete-model* language loss and prices its packed native consumer. Ordinary Q8/expert physical-time work is independent. This mathematical result changes neither GGUF, native arithmetic nor serving defaults, and required no GPU run.
