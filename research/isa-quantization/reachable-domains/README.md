# Complementary routes give a guard-free contrast code

A two-route mixture is a small producer whose reachable domain is cheaper to describe than a fitted activation enclosure. Let each route producer emit **one** integer code `q_i ∈ {0,...,127}` and define its other code as `127-q_i`. For example, compute `q_i = clamp(RN_even(127 p_i),0,127)` from a two-key softmax probability, then subtract once. This is an invariant of the producer program for *every* input, not a statistical claim about prompts. It costs an integer subtraction and avoids a second quantization. Independently rounding both probabilities is not equivalent: at `p=1/254`, ties-to-even gives codes `(0,126)`.

For fixed paired expert coefficients `w_i0,w_i1`, an existing additive bias `b`, and any number of independently changing gates,

```
F(q) = b + Σ_i [w_i0 q_i + w_i1 (127-q_i)]
     = B + Σ_i d_i q_i,
B = b + 127 Σ_i w_i1,       d_i = w_i0-w_i1.
```

Store only contrasts `d_i` and the folded bias `B`. The complete producer/consumer is exact on the full `128^M` code domain, without a runtime domain-membership guard or a copy of either expert bank. The original two banks need not be reconstructed. A single signed-byte dot over the first route codes plus a bias is a plausible consumer lowering when the prepared contrasts fit signed bytes. It needs **expanded contrast bytes** in its hot representation. Reading the stored three-bit codes directly would require unpacking or a different packed reader; expansion, its buffer and reuse threshold must be priced. Packed-code extraction, construction of `q`, bias addition, layout, and native dot scheduling remain paid work. This is a fixed-pair expert family, not an assertion that arbitrary dynamic attention values are static weights.

This is an extension of the normalized-logit quotient in [reachable quotients](../../ternary-toys/reachable-quotients/README.md), not a new softmax identity. The extra decision here is to *change the quantized probability producer* so its complement survives rounding, then prepare and quantize the static **contrasts** across many gates. Unlike the guarded fixed-code cell in [the producer enclosure](../../quantization-discovery/ENCLOSURE.md), its domain guarantee costs no literal input vector. A competent conventional optimizer can also fold these coefficients. There is no claim of a speedup over that fused control.

## Exact robust quantization rule

Suppose we approximate each contrast by `d'_i` and choose the replacement bias freely. Put `e_i=d'_i-d_i`. The error before recentering ranges from `127 Σ min(0,e_i)` to `127 Σ max(0,e_i)` over the full independently reachable code cube. Every extreme is attained by choosing each `q_i` as zero or 127. The best *integer* replacement bias therefore has worst-case absolute error

```
ceil(127 Σ |e_i| / 2).
```

So fitting a common contrast grid for worst-case output error reduces to minimizing its coefficient L1 error. This theorem requires independent reachability of the `q_i` endpoints for equality; with coupled gates its expression is still a safe bound. For exact replacement on the full cube, all contrasts must survive exactly: compare the responses at `q=0` and at each basis input `q_i=1`. This is why an arbitrary unrelated pair of expert banks cannot be declared three-bit simply because the mixture is normalized.

`check.py` exhausts a four-gate endpoint, checks small robust-error cubes and searches finite affine grids on a planted and an unstructured 32-gate contrast list. Its scalar controls are stronger than coefficient-wise rounding: each independent weight gets a 2- or 4-bit affine code, both banks share an optimized integer step, and the optimizer may choose their *difference* directly while folding any error in the common mode into the bias. A `k`-bit independent pair can therefore choose any contrast in `[-(2^k-1)s,(2^k-1)s]`. The contrast arm gets one affine three-bit code per pair, with a signed 16-bit origin and unsigned 16-bit step. All arms pay a signed 32-bit folded bias. The independent arms pay a 16-bit step; their common origin cancels and need not be stored. Bit counts exclude common framing and padding.

| 32 pairs | Three-bit contrast | Independent two-bit | Independent four-bit |
| --- | ---: | ---: | ---: |
| Model bits | 160 | 176 | 304 |
| Planted contrasts `2*(i%7-3)`, worst integer output error | 0 | 0 | 0 |
| Uniform random integer contrasts `[-60,60]`, seed 2409, worst output error | 6160 | 9271 | 1969 |

The planted contrast list has 7 values and can use a three-bit affine grid. The two-bit control also gets zero error, but takes 16 more model bits and requires two codes per pair rather than one. This is a cold-storage and potential hot-reader opportunity, not superiority in fit against the strong control. The unstructured bank demonstrates the limit: four-bit independent coding at 304 bits cuts its worst-case error to 1969. A three-bit-per-pair asymmetric independent format with separate bank scales can recreate an eight-level contrast grid; it needs the extra scale metadata and must still combine two codes. It is a valid competing implementation, not an impossibility claim.

This is exact integer semantics for a modified quantized producer. It neither preserves the original independently rounded two-branch outputs at their ties nor bounds error against ideal real-valued softmax. No real model has been measured, and no gfx1151 program or timing has been produced. The useful transfer test is a fixed two-expert gate with many genuinely shared mixture weights, checking whether its *trained contrasts* occupy a narrow grid. Include the fused conventional control; comparing only against two unfused dot products would overstate the result.

Run from the Kelana root:

```
python3 research/isa-quantization/reachable-domains/check.py
```
