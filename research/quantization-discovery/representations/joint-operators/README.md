# Folding a gated product before quantizing it

A generic bilinear gate has a much smaller complete operator than its three matrices. For `x ∈ R³`, 32 hidden channels and four outputs, let

```
F(x) = D ((Gx) ⊙ (Ux)) / 2.
C[o,i,i] = Σh D[o,h] G[h,i] U[h,i] / 2
C[o,i,j] = Σh D[o,h] (G[h,i] U[h,j] + G[h,j] U[h,i]) / 2, i < j.
F(x)[o] = Σi≤j C[o,i,j] x[i] x[j].
```

This identity holds for *any* `G,U,D`; it does not need planted cancellation, low rank, identical consumers or recovered intermediate weights. The encoded object is 24 coefficients of the complete quadratic map, rather than the original 320 scalar weights. All four output rows use the same six input monomials. A direct reader builds those six products once and performs 24 code-feature products, four output scales and the output writes. It never constructs the two 32-channel projections or their product. The unfused reader needs 320 weight-input products, 32 hidden products and, for a SiLU gate, 32 nonlinear evaluations. The folded quadratic is exact only for the bilinear gate; replacing SiLU by its first Taylor term changes the model.

Eight independent seeded Gaussian teachers test the identity and quantized response without planting a shared basis. `G` and `U` have standard deviations .7 and .65; `D` has standard deviation `1/√32`. The independent Gaussian input panels have standard deviations .6, .8 and 2.3. No observation was used to choose the polynomial or fit its coefficients: conversion algebraically expands the teacher, fits a scalar step to each code group, rounds that step to FP16, and rounds codes again. The receipt gives every teacher seed, all three input panels, and the maximum observed gate magnitude. The largest relative FP64 identity error on the wide panels is `3.45e-16`.

## Physical image and response

Every encoded row is independently addressable. Direct int8 stores 24 signed bytes and four FP16 row scales, **32 bytes**. Direct signed q4 stores six nibbles per output row and the same scales, **20 bytes**; nibble 15 is unused. The scalar ternary image puts each three-trit gate/up row in one radix-3 byte and each 32-trit down row in a seven-byte radix-3 word. Its three FP16 tensor scales bring it to **98 bytes**. Independently scaled ternary rows have 68 scales and total **228 bytes**. The scalar signed-q4 control packs 320 nibbles into 160 bytes and has three FP16 tensor scales, **166 bytes**. All weights, scales and codewords are charged. Fixed shape, fixed code alphabet and generic reader are shared executable code, not model-specific metadata. These are valid capacity layouts; this Python script evaluates unpacked arrays, not a timed compressed decoder.

Relative RMS is `||candidate(x)-teacher(x)||₂ / ||teacher(x)||₂` over all 1,024 held samples and four outputs, reported as the median across eight teachers. The range across teachers is in `results.json`.

| Image | Bytes | Bilinear held RMS | SiLU held RMS | SiLU wide RMS |
| --- | ---: | ---: | ---: | ---: |
| Scalar ternary, one scale/matrix | 98 | .6249 | .6323 | .6279 |
| Scalar ternary, one scale/row | 228 | .6003 | .5857 | .5671 |
| Scalar q4, one scale/matrix | 166 | .1929 | **.1893** | **.1837** |
| Folded quadratic q4 | **20** | .0623 | .5913 | .6758 |
| Folded quadratic int8 | **32** | **.0037** | .5884 | .6748 |
| Folded quadratic FP16 | 48 | .0002 | .5884 | .6749 |
| Degree-2/3 SiLU polynomial int8 | 72 | n/a | .4105 | 1.8960 |
| Degree-2/3/5 SiLU polynomial int8 | 156 | n/a | .7553 | 25.7925 |

The direct int8 image beats the **larger scalar q4 image** on the complete bilinear response for every one of the eight teachers: its RMS range is `.0022–.0047`, versus scalar q4's `.1077–.4135`. This is a structural compression result for a quadratic operator, not a claim about SwiGLU. Its benefit comes from composing before quantization, rather than quantizing each hidden stage then hoping errors cancel.

SiLU is the discriminator. Multiplying `SiLU(g) = g/2 + g²/4 - g⁴/48 + ...` by `u` produces degrees 2, 3 and 5. The expansion has respectively 6, 16 and 37 distinct monomials in three inputs, shared across outputs. Degree-3 int8 needs 64 coefficients plus eight scale bytes, roughly the ternary tensor image size, and improves held RMS `.6323→.4105`. But scalar q4 is better at 166 bytes. Degree 5 is already worse on ordinary held inputs and explodes on the wide panel, where observed `|g|` can exceed 21. Even an unquantized Taylor polynomial has the same failure. Changing this from a polynomial approximation to an exact SiLU implementation would require retaining a sufficient representation of the individual gate nonlinearities, or proving a restricted producer domain; it is not licensed by bilinear exactness.

## Online bill and timing

The quadratic reader consumes the external float input directly, forms three squares and three cross-products, reads 24 codes and four scales, and emits four float outputs. The scalar reader reads 320 codes and three or 68 scales, forms both 32-channel projections, multiplies their corresponding channels, then computes four down rows. Decoding radix-3 rows is recurring work in the scalar format. No entry rotation, recovered scalar matrix, hidden buffer or exit coordinate conversion is needed for the quadratic image. The polynomial SiLU arms additionally construct 10 cubic or 21 quintic monomials and read 64 or 148 codes, respectively. All constructions were fit offline; each monomial and code read is online.

One illustrative host NumPy/float64 256-input batch, measured as a median of five groups of 80 calls with one BLAS thread, takes `15.0 µs` for the pre-expanded scalar ternary SiLU matrix chain, `15.2 µs` for scalar q4, `126.7 µs` for the pre-expanded quadratic float matrix and `357.6 µs` for the cubic. The generic Python feature generator dominates. These are **not timings of the packed images**: both sides use unpacked coefficients, and the scalar side does not pay its radix-3 decode. The experiment therefore separates an algebraic/physical-rate win from an *unproven* native inference win. The next execution test should use a fused native six-monomial reader and a radix-3 or nibble scalar reader under the same input/output layout and cache occupancy, including each side's scale and decode work. If that complete reader does not beat the scalar control, this construction is a storage/accuracy result only.

There is no actual Qwen FFN quality inference here. Qwen's SiLU gates, residual input domain and dense hidden width are precisely where the cheap quadratic loses its behavioral equivalence. The cheapest transfer falsifier is a frozen real Qwen gate/up/down snippet with **actual quantized-producer inputs**, plus held text windows: fit a producer-conditional direct polynomial or other whole-map code only on training windows and score both held post-down outputs and full-model token loss against equally stored scalar quantization. An off-domain held reversal like the wide panel would rule out a global polynomial decoder even if a narrow calibration loss looked good.

Run from the Kelana root:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/quantization-discovery/representations/joint-operators/experiment.py \
  > research/quantization-discovery/representations/joint-operators/results.json
```
