# The Bonsai hidden-activation producer

This note defines the producer domain behind the down projection. It separates three claims that must not be mixed:

1. the exact source program that produced the stored operands;
2. real-arithmetic relations implied by that program for every residual input;
3. conditional local domains around a captured operand.

The source gives useful global correlation. The eight captured rows do not turn that correlation into a learned global activation set.

## Source and data custody

The dataset is `/path/to/workspace/data/kelana-ffn/ptq1_0/layer00`. Its manifest identifies Bonsai commit `6fcff4c0a881e1fa2f448db630e76a57cb1bf268`, model `PTQ1_0.gguf`, layer 0, `D = 5120`, `FF = 17408`, and block width 128. The files relevant here are:

- `gate.halo` and `up.halo`, the exact packed bytes uploaded by the engine;
- `post_norm_s.f32`, the post-attention RMS-norm weights with the input Hadamard signs folded in;
- `signs_ff.f32`, the 17408 hidden Hadamard signs;
- `r8/xq_d.i8`, `xs_d.f32`, and `xsum_d.i32`, the operand of gate and up;
- `r8/gate.f32` and `up.f32`, the two projection outputs;
- `r8/xq_ff.i8`, `xs_ff.f32`, and `xsum_ff.i32`, the operand of down.

The `r1` files repeat the first token of `r8` under the one-row schedule. Gate, up, input codes and scales, and hidden codes and scales are byte-identical for that row. There are eight distinct contextual rows, not nine.

`research/ffn/full-map/harness/build_dataset.cpp` produced each group by resetting the engine and stopping at a source barrier. In particular, barrier 9 captured the post-norm operand, barrier 10 captured gate and up, and barrier 12 captured the hidden operand and residual output. This is stronger provenance than reconstructing intermediate values from the final residual.

The relevant producer in the captured commit is the same deployed `QL = 127` path visible in the current `kernels/phases.hpp`:

```text
post-norm residual
  -> signed normalized H_1024
  -> dynamic int8 by 128
  -> gate and up ternary matvecs
  -> signs_ff * silu(gate) * up
  -> normalized H_1024
  -> dynamic int8 by 128
  -> down ternary matvec
```

Here `normalized H_1024` means a Walsh-Hadamard transform divided by 32, independently on each consecutive 1024 coordinates.

## Exact producer contract

Let `b` index a 128-wide input block and `i` a hidden coordinate. Decode the HALO images into trits

```text
t^g[i,b,k], t^u[i,b,k] in {-1,0,1}
```

and FP16 block scales `lambda^g[i,b]` and `lambda^u[i,b]`. Let `q[b,k]` be the upstream int8 code, `s[b]` its FP32 scale, and `xsum[b] = sum_k q[b,k]`.

The packed kernel stores trits as unsigned codes and subtracts `xsum`. Its integer results are therefore exactly

```text
A^g[i,b] = sum_k t^g[i,b,k] q[b,k]
A^u[i,b] = sum_k t^u[i,b,k] q[b,k].
```

There is no integer overflow here. A block has 128 products of magnitudes at most 127, far below the signed 32-bit limit.

The source gives each of eight waves five consecutive blocks. Each wave starts gate and up partials at zero and performs five source FMAs:

```text
g_partial = fma(A^g[i,b], RN32(float(lambda^g[i,b]) * s[b]), g_partial)
u_partial = fma(A^u[i,b], RN32(float(lambda^u[i,b]) * s[b]), u_partial).
```

Wave 0 then adds the eight partials in wave order. This is not one sequential 40-FMA chain. [FLOAT-CONTRACT.md](FLOAT-CONTRACT.md) records the source tree and compiler lowering. Gate and up use the same `(q,s)`. Treating them as two unrelated boxes throws away the principal producer relation.

For hidden coordinate `i`, the prep phase computes

```text
d[i] = signs_ff[i] * silu(g[i]) * u[i]
silu(x) = x / (1 + __expf(-x)).
```

The signs are exactly `-1` or `1`. The kernel transforms each 1024-wide chunk of `d` through ten add/subtract stages and multiplies by the exactly representable number `1/32`. Call the resulting FP32 values `y`.

For each consecutive 128-wide block `B`, the source computes

```text
m_B       = max_{i in B} abs(y[i])
iscale_B  = float32(127 / m_B)             if m_B > 0, else 0
qff[i]    = round_to_nearest_even(float32(y[i] * iscale_B))
sff[B]    = float32(m_B / 127)
xsumff[B] = sum_{i in B} qff[i].
```

This is the rounding-sound definition of the deployed producer. An exact domain may simply be defined as the image of this finite-precision program over a declared upstream input set. Any analytic relaxation must enclose these operations rather than replace them silently with real arithmetic.

## A global correlation available from source

There is a cheap global relation beyond the fact that every nonzero hidden block contains a code of magnitude 127.

For fixed input block `b`, any joint integer probe of a gate accumulator and an up accumulator pulls back to the same code vector:

```text
c_g A^g[i,b] + c_u A^u[j,b]
  = sum_k (c_g t^g[i,b,k] + c_u t^u[j,b,k]) q[b,k].
```

Over the relaxed source code box `q[b,k] in [-127,127]`, its exact support is

```text
127 sum_k |c_g t^g[i,b,k] + c_u t^u[j,b,k]|.
```

The maximizing corner has every coordinate equal to `-127` or `127`, so imposing the dynamic-quantizer condition `max_k |q[b,k]| = 127` does not change this support. The same pullback works for any number of gate and up rows. Combine their trit rows first, then take the L1 norm. Summing independent gate and up supports is weaker and can be strictly larger.

With fixed scales, this gives an exact integer affine domain. It is directly usable by a search that retains a shared generator until the last weight block touched by that generator. With variable scales, the integer accumulator remains exact but multiplication by the scale needs a continuous bound or a finite scale menu.

In ideal real arithmetic the whole pair satisfies the familiar pullback

```text
alpha . g + beta . u
  = (G^T alpha + U^T beta) . xhat,
```

where `xhat[b,k] = s[b] q[b,k]`. This places `(g,u)` in the image of one 5120-dimensional operand, rather than a 34816-dimensional product box. The relation comes from the weights and producer. No capture fitting is involved.

### A global scale budget

The preceding relation still needs a domain for the 40 input scales. RMS norm supplies one in ideal real arithmetic.

For any residual `r`, with `eps > 0`,

```text
rho = r / sqrt(mean(r^2) + eps)
||rho||_2 <= sqrt(D).
```

Let `w` be `post_norm_s`, and let `z = H(w * rho)` before upstream quantization. The block-diagonal normalized Hadamard is orthogonal, hence

```text
||z||_2 <= sqrt(D) ||w||_infinity.
```

If `127 s[b] = max_{k in b} |z[b,k]|`, then

```text
sum_b s[b]^2 <= D ||w||_infinity^2 / 127^2.                 (1)
```

For this layer, `||w||_infinity = 1.006683349609375`, so (1) gives

```text
||s||_2 <= 0.56718421.
```

Individual scale entries in the eight captured rows range from `0.0014663251` through `0.006483105`. Their rowwise L2 norms range from `0.013189236` through `0.029085268`. Those extrema are observations, not replacements for (1).

The ideal dequantization error in block `b` obeys

```text
||s[b] q[b] - z[b]||_2 <= sqrt(128) s[b] / 2.
```

Together with (1), this gives

```text
||xhat||_2
  <= (1 + sqrt(128)/254) sqrt(D) ||w||_infinity.             (2)
```

Consequently every joint gate/up probe has the ellipsoidal support bound

```text
|alpha . g + beta . u|
  <= R ||G^T alpha + U^T beta||_2,
R = (1 + sqrt(128)/254) sqrt(D) ||w||_infinity.              (3)
```

Equations (1) through (3) are globally valid for the ideal producer. They are broad, but they are genuine source-derived correlation and cheap to evaluate. They can certify assignments whose error appears too large under independent gate and up boxes.

They are not yet deployed FP32 certificates. Such a certificate must inflate them for the source RMS reduction and `rsqrtf`, input multiplies, ten Hadamard additions, scale division, and matvec multiply/FMA chain. The [local evaluator](ENCLOSURE.md) implements the stages after the upstream code/scale boundary. It does not yet implement the full RMS-to-hidden chain required for these global norm bounds. The exact source-program image remains rounding-sound by definition; the analytic real bounds do not become source-bit bounds by assertion.

## A usable conditional local domain

A tighter domain can be built around any captured row while preserving shared gate/up dependence.

Fix the captured upstream codes `q0` and declare a scale set

```text
S = {s0 + B z : |z_l| <= 1}.
```

An interval box is the special case where `B` is diagonal. Reject any `S` that permits a negative scale. For every hidden coordinate and block, precompute the exact integers `A^g[i,b]` and `A^u[i,b]` from `q0`. Gate and up are then affine functions of the same generators `z` under real arithmetic. Under source arithmetic, outward interval or affine evaluation of the multiply/FMA chain encloses them while retaining those common generators.

This fixed-code scale domain is sound under the explicit assumption

```text
the upstream producer emits q0 and a scale vector in S.
```

It is not a neighborhood theorem about arbitrary model inputs. In particular, eight captures do not prove that upstream codes stay fixed or that future scales lie in `S`.

### Propagation through SiLU and the product

Suppose an enclosure around one coordinate gives

```text
|g - g0| <= G,    |u - u0| <= U.
```

Let

```text
L = sup_{x in [g0-G,g0+G]} |silu'(x)|,
silu'(x) = sigmoid(x) + x sigmoid(x)(1-sigmoid(x)).
```

Then

```text
|silu(g)u - silu(g0)u0|
  <= L G (|u0| + U) + |silu(g0)| U.                         (4)
```

Multiplication by the sign does not change the radius. A joint affine or Taylor enclosure is usually sharper than (4), because the same scale generators move `g` and `u`. Formula (4) is the fallback scalar certificate.

The deployed `__expf` and surrounding FP32 operations need outward error terms. A real-valued SiLU interval alone does not certify the source program.

### Propagation through Hadamard

Let `D_i` bound the perturbation of the signed product in one 1024 chunk. Every normalized Hadamard output obeys

```text
epsilon_j <= (1/32) sum_i D_i.                              (5)
```

The coarser uniform form is `||delta y||_infinity <= 32 ||delta d||_infinity`. Carrying the affine generators through the Hadamard retains cancellations and is preferable when the solver supports it.

For round-to-nearest FP32 addition, no overflow, and real Hadamard input values already enclosed, a standard depth-10 allowance for the transform itself is

```text
|fl(Hd)_j - (Hd)_j| <= gamma_10 (1/32) sum_i |d_i|,
gamma_10 = 10 u / (1 - 10 u),    u = 2^-24.                 (6)
```

The multiplication by `1/32` is exact for normal binary floating-point values. Equation (6) does not cover the earlier SiLU/product errors, subnormal behavior, or compiler changes. Those need separate terms.

### Dynamic scaling and rounding

For a real-valued reference block `y`, write `m = ||y||_infinity`. If `||y' - y||_infinity <= epsilon < m`, then `|m' - m| <= epsilon` and

```text
|127 y'_i/m' - 127 y_i/m|
  <= 254 epsilon / (m - epsilon).                           (7)
```

This is the useful denominator effect. Bounding `y` while pretending the dynamic scale is fixed is unsound.

Let `a_i = 127 y_i/m` and let `mu_i` be its distance to the nearest half-integer rounding boundary. In ideal round-to-nearest-even arithmetic, code `i` is fixed whenever the right side of (7) is strictly below `mu_i`. For a code interval, use

```text
{ round_to_nearest_even(t) : t lies in the enclosed normalized interval }.
```

This set handles tie parity exactly. A convenient but weaker integer bound is `|q'_i-q_i| <= floor(delta_i)+1` when the normalized value moves by at most `delta_i`.

The source does not evaluate `127*y/m` as one real expression. It rounds `127/m` to FP32, rounds the multiplication, and then converts to integer. A deployed certificate must instead evaluate outward

```text
Iscale = RN32(127 / M)
P_i    = RN32(Y_i * Iscale)
Q_i    = RN-even-to-int(P_i)
Scale  = RN32(M / 127),
```

including all attainable `M = max_i abs(Y_i)`. Equations (7) and the margin test are sound only after adding an allowance that encloses this source sequence. The [implemented evaluator](ENCLOSURE.md) now encloses the rounded division/product/conversion directly in its supported finite, nonzero-scale range. It also retains the prequantized affine generators for the dequantized operand and pays an explicit rounding residual.

The resulting local domain can retain, for every hidden 128-block:

- a finite interval or set for each hidden code;
- an interval for the hidden scale;
- the exact relation `xsumff = sum qff`;
- shared affine generator labels across gate, up, SiLU/product, and Hadamard until interval splitting is unavoidable.

This is suitable input to a correlated-domain assignment solver. Its validity is conditional on the declared fixed-code scale set and the floating-point enclosure.

## What the eight rows establish

The captures establish exact values for eight real contextual inputs under one layer, model, prompt, and source revision. They can support the following work without a GPU:

- decode every HALO block into trits and FP16 scales;
- compute exact integer gate/up block accumulators for every captured upstream code vector;
- retain gate and up as functions of one common upstream operand;
- compute captured rounding margins and candidate local radii;
- build calibration-derived boxes or zonotopes and test other stored rows for containment;
- replay ideal real or CPU FP32 approximations and report their difference from the captured gate, up, hidden codes, and scales;
- derive the global integer support and real scale bounds above from source and stored weights.

The existing CPU decoder is `research/ffn/batched/deferred-carrier/carrier_scan.py:halo_matrix`. It decodes the same radix-3 bytes and FP16 tail scales consumed by `device.hpp`. Reusing it avoids inventing a second weight format.

The small fixture [bonsai-layer00-gate-up-block0.json](instances/bonsai-layer00-gate-up-block0.json) contains gate and up row 0, input block 0, plus the first upstream block of all eight rows. It records both full-file and 896-byte tile hashes, raw FP16 scale bits, source-file hashes at the captured Bonsai commit, input stride, tokens, and complete trit and code arrays. Its exact interface ends at the paired integer accumulators. It does not promote the eight inputs into a global domain.

A box obtained by transforming these eight `qff` vectors, including a box in a final Hadamard basis, is a finite calibration domain. Held-out containment is a useful diagnostic. Neither operation turns it into a producer guarantee.

## Why no global domain follows from eight rows

Let `C` be the set of eight captured upstream operands. Suppose a proposed fitted set `Z` omits some legal source output at an operand `x*`. Then there are two possible input populations that agree on every element of `C`:

```text
R1 = C
R2 = C union {x*},
```

The captures cannot distinguish `R1` from `R2`. This does not rule out a globally valid envelope derived from source, or the entire source image itself. It shows why fitting the captured outputs cannot establish containment when an omitted legal output exists. The held-out failures in [PRODUCER.md](PRODUCER.md) exhibit that omission for the particular Hadamard box used here.

Knowing the source program changes the situation only by supplying the image map and algebraic constraints. It does not identify which residual histories the complete model can reach. A positive-radius or global containment statement therefore needs at least one of:

- a source-derived domain for all incoming residuals, such as the RMS bound above;
- an invariant propagated through all preceding layers and recurrent or attention state;
- an explicit workload contract restricting inputs to a finite recorded set;
- a runtime guard that checks membership and falls back outside the certified region.

No amount of fitting to the same eight rows supplies that missing premise.

## Recommended contract for current experiments

Use two named domains rather than one ambiguous activation set.

`ProducerGlobalReal` contains every ideal-real producer output generated by:

```text
q[b,k] in [-127,127],
max_k |q[b,k]| = 127 for nonzero blocks,
xsum[b] = sum_k q[b,k],
s[b] >= 0,
sum_b s[b]^2 <= D ||post_norm_s||_infinity^2 / 127^2,
```

with gate and up computed from the same `(q,s)`, followed by real SiLU/product, normalized Hadamard, and exact nearest-even dynamic quantization. It supports the exact joint integer pullback and the real bounds (1) through (7). It is broad and does not certify deployed last bits.

`ProducerLocalFP(q0,S,E)` fixes a captured upstream code vector, ranges its shared scale vector over `S`, and evaluates every source FP32 operation outward with error record `E`. It is a deployed-semantic certificate once the upstream fixed-code premise and every outward operation in `E` have been checked. The [directed evaluator and certificate](ENCLOSURE.md) now implement this contract from fixed upstream codes and explicit scale intervals through the first 1024 hidden coordinates. Its range checks and arithmetic assumptions are explicit; the contract is not a global workload invariant.

Keep a calibration-derived domain under a third, plainly statistical name. It may guide search and held-out experiments, but it must not discharge either producer contract.

The useful structure is common upstream generators, exact paired integer supports and a global real-arithmetic RMS scale budget. The local route through nonlinear and dynamic-quantized stages is now executable. The remaining task is to replace its narrow fixed-code premise with a broad, cheaply described input invariant and extend the source enclosure through the upstream RMS/quantization stages.
