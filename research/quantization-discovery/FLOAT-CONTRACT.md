# Floating-point contract for the Bonsai hidden producer

This is the arithmetic contract for the first directed producer evaluator. Its input boundary is a fixed upstream int8 code vector `q_d`, its exact integer sums, and bounded binary32 block scales. Its output boundary is the hidden int8 codes, hidden binary32 scales, and integer block sums consumed by the down projection.

The contract follows the deployed source and the gfx1151 lowering. In particular, it does not replace `__expf` with real `exp`, flatten the gate accumulation tree, or treat `127 / amax` as an exact reciprocal.

## Source and compiler evidence

The captured dataset names Bonsai commit `6fcff4c0a881e1fa2f448db630e76a57cb1bf268`. The relevant files at that commit have these SHA-256 hashes:

| File | SHA-256 |
|---|---|
| `Makefile` | `0a3fe3dd886ca5695fa7639892d4e53290b302b34acdb2908e8fa0982751307f` |
| `kernels/device.hpp` | `cf328825dd5d93be65766bd344110c5e46e6bca91ceda82df7c3c6ca90634f71` |
| `kernels/phases.hpp` | `6b45186b66e66c263626573b663180e6f2137ac8dce62edf0945a617906d9a06` |
| `kernels/halo_rows.hip` | `6b35f118f56c8589ed322751423e980da9c81a0e41cd526126e44423d3263843` |
| `halo_rows.hip-hip-amdgcn-amd-amdhsa.hipfb` | `f74f990b4991c014e0fd7e65b854121f8cff7e427ea5033b60d784911d1f21af` |

The Makefile compiles with:

```text
hipcc --offload-arch=gfx1151 -O3 -std=c++17
```

It does not enable `-ffast-math`, finite-only arithmetic, approximate reciprocals, or denormal flushing. The committed HIP bundle contains a gfx1151 code object. Its `.comment` section identifies `nixpkgs-AMD clang version 22.0.0`, ROCm `7.2.3`, and LLD 22.0.0. This is the same compiler family as the current host toolchain.

The four captured forward-kernel descriptors have FP32 round mode 0 and denormal mode 3. In the AMD ABI these mean round to nearest, ties to even, and preserve FP32 input and output denormals. The raw `COMPUTE_PGM_RSRC1` words are `0xe0af000c`, `0xe0af000e`, `0xe0af001b`, and `0xe0af001b`; all have the same floating-point mode bits.

The current compiler invocation links these control modules:

```text
oclc_daz_opt_off.bc
oclc_unsafe_math_off.bc
oclc_finite_only_off.bc
oclc_correctly_rounded_sqrt_on.bc
```

The `float_contract_fixture.hip` fixture records the small expressions used below. Compile it without running a GPU:

```sh
hipcc --offload-arch=gfx1151 -O3 -std=c++17 \
  --cuda-device-only -S -emit-llvm \
  research/quantization-discovery/float_contract_fixture.hip -o /tmp/float-contract.ll

hipcc --offload-arch=gfx1151 -O3 -std=c++17 \
  --cuda-device-only -S \
  research/quantization-discovery/float_contract_fixture.hip -o /tmp/float-contract.s
```

The optimized IR marks ordinary operations `contract`, but not `reassoc`, `arcp`, `afn`, `nnan`, `ninf`, or `nsz`. `contract` permits a multiply-add contraction where one exists. It does not permit arbitrary reassociation. The target expressions have the following fixed boundaries:

- The weight-scale times source-scale multiplication is a separate `fmul` feeding an explicit `llvm.fma.f32`.
- SiLU has an `exp2` intrinsic, an addition, an `fdiv`, then two separate multiplications.
- Hadamard butterflies remain additions and subtractions. The final multiplication by `1/32` is separate.
- Both dynamic-quantizer divisions remain `fdiv`. The compiler does not replace them with a bare approximate reciprocal.

The fixture is a lowering witness. The operation tree itself comes from the complete captured source.

## Supported profile

The initial evaluator supports the following domain:

- `q_d[b,k]` and `xsum_d[b]` are fixed, with `q_d` signed int8 and `xsum_d[b] = sum_k q_d[b,k]`.
- Every upstream scale ranges over a closed interval of binary32 values. Scale endpoints are finite and nonnegative.
- HALO trits and binary16 weight scales are fixed by the captured weight image.
- Every ordinary FP32 intermediate is finite. The evaluator must reject a box if it cannot prove this.
- Every `V_EXP_F32` call has a finite normal mathematical result after its input-denormal rule. This keeps the first evaluator away from the exp overflow and output-underflow transition. Splitting an interval until it meets this condition is valid.
- In each hidden 128-block, `amax` is either exactly zero or `127 / amax` is finite. Nonzero blocks must also keep every float-to-int input in signed 32-bit range.
- NaNs are outside this profile.

These conditions include the captured layer-0 values by a wide margin. Across the eight stored rows, gate values range from about `-2.143` to `2.105`.

Intervals which fail a condition are `unsupported`, not silently widened under ideal-real semantics. Later evaluators can add exp overflow and underflow cases by modeling the documented flush behavior.

The initial boundary deliberately excludes post-attention RMS normalization and upstream quantization. Therefore `rsqrtf` is not part of this evaluator. Its gfx1151 contract is recorded below for the later end-to-end extension.

## Primitive operations

Write `RN32(x)` for exact real `x` rounded to binary32 in round-to-nearest, ties-to-even mode. Write `FMA32(a,b,c)` for one fused multiplication and addition followed by one such rounding.

For finite supported inputs:

- FP16 to FP32 conversion is exact.
- Integer accumulators in this producer convert exactly to FP32 because their magnitude is below `2^24`.
- `+`, `-`, and `*` are `RN32` operations.
- `fmaf` is `FMA32`.
- `/` is the ordinary LLVM `fdiv` operation under the kernel's round-to-nearest-even mode, so the evaluator uses `RN32(a/b)`. The [LLVM floating-point environment contract](https://llvm.org/docs/LangRef.html#floating-point-environment) guarantees correctly rounded, bit-identical non-NaN results for ordinary IEEE operations. The `contract` flag permits multiply-add fusion only and does not weaken a standalone division.
- `fabsf` clears the sign bit. `fmaxf` selects a finite operand. Neither introduces rounding.
- Multiplication by a sign value exactly equal to `-1` or `1` is exact for finite inputs, including subnormals under denormal mode 3.

The emitted division is not `V_RCP_F32` by itself. Clang emits `V_DIV_SCALE_F32`, reciprocal estimates, two Newton-Raphson refinement steps using FMA, `V_DIV_FMAS_F32`, and `V_DIV_FIXUP_F32`. AMD describes this as its high-precision division macro. Modeling a source division with the ISA's one-ULP bound for bare `V_RCP_F32` would model the wrong operation.

The local RDNA 3.5 ISA manual states 0.5-ULP accuracy and denormal support for `V_ADD_F32`, `V_SUB_F32`, `V_MUL_F32`, and `V_FMA_F32`. With the descriptor's nearest-even mode, the `RN32` and `FMA32` definitions above capture these operations.

## Gate and up projections

There are 40 source blocks. Each output row has an exact signed integer accumulator

```text
A[i,b] = sum_k trit[i,b,k] * q_d[b,k].
```

The deployed reduction is not one 40-term FMA chain. Eight waves each own five consecutive blocks. For gate or up row `i`, wave `w` computes:

```text
p = +0.0f
for b = 5*w, ..., 5*w+4:
    t = RN32(float(weight_scale_fp16[i,b]) * source_scale[b])
    p = FMA32(float(A[i,b]), t, p)
partial[w] = p
```

Wave 0 then reduces the partials in this order:

```text
value = partial[0]
for w = 1, ..., 7:
    value = RN32(value + partial[w])
```

Gate and up use the same source scales. A directed evaluator should retain that common dependence for as long as its interval or affine representation allows.

Both deployed row paths have this FP32 tree. Passes of up to four rows use scalar-fed `sudot4`; the eight-row pass uses integer WMMA. Their integer dot implementation differs, but each produces the same exact per-block integer before the five-FMA partial and eight-wave reduction.

## The exact deployed SiLU sequence

At the source level:

```c++
float silu(float x) { return x / (1.0f + __expf(-x)); }
d = silu(gate) * up * sign;
```

On this AMD toolchain, `__expf` is defined in `__clang_hip_math.h` as:

```c++
const float log2_e = 0x1.715476p+0f;
return __builtin_amdgcn_exp2f(log2_e * x);
```

The constant has binary32 bits `0x3fb8aa3b`. Thus one hidden coordinate is evaluated as:

```text
z   = RN32((-gate) * 0x1.715476p+0f)
e   = V_EXP_F32(z)
den = RN32(1.0f + e)
s   = RN32(gate / den)
p   = RN32(s * up)
d   = RN32(p * sign)
```

Unary negation is an exact sign-bit operation. The two product roundings after the division are separate. There is no legal reassociation into `gate*up/den` under the emitted IR.

### Sound `V_EXP_F32` enclosure

This is not a CUDA accuracy assumption. AMD's RDNA 3.5 ISA manual defines `V_EXP_F32` as `2^x`, states one-ULP accuracy, and states that denormals are flushed. The relevant local source is `hardware/gfx1151/sources/rdna35-isa.txt`, in the `V_EXP_F32` entry around source lines 23704 through 23730.

For a normal finite positive real `y`, define the conservative upper-binade ULP

```text
U(y) = 2^(floor(log2(y)) - 23).
```

For a binary32 input `z`, let `z0` be `z` with a subnormal input flushed to signed zero. In the supported profile, `y = 2^z0` is normal and finite. The instruction result lies in

```text
[y - U(y), y + U(y)] intersect binary32.
```

For an interval of possible `z`, use monotonicity of real `2^z` to bound the ideal endpoint values with directed high-precision arithmetic, then expand by the largest `U` over that range. This bound includes both the rounded multiplication by the binary32 `log2(e)` approximation and the instruction error because the multiplication is enclosed before applying the `V_EXP_F32` rule. On a normal finite output range, a uniform relative expansion of `2^-22` is a valid, looser substitute for the one-ULP expansion.

A tighter implementation may retain only binary32 values in that expanded interval. It must not use `RN32(exp(gate))`, a host `expf`, or a CUDA `__expf` ULP claim.

Outside the initial profile, the instruction flushes subnormal inputs and outputs. A future complete implementation should split around the input-subnormal, output-underflow, and overflow boundaries and include positive zero or positive infinity according to the ISA behavior.

## The 1024-point Hadamard

The source applies the standard unnormalized Walsh-Hadamard butterflies and then multiplies by the exactly representable binary32 value `0.03125f`.

Its physical decomposition fixes the arithmetic tree:

1. Two add/subtract stages within each consecutive group of four values.
2. Five add/subtract stages across the 32 lanes of a wave.
3. Three add/subtract stages across the eight 128-value LDS slices.
4. One multiplication by `1/32` for every output.

This is ten rounded add/subtract stages. Each butterfly is:

```text
lo = RN32(a + b)
hi = RN32(a - b)
```

The final output is `RN32(h * 0.03125f)`. Scaling by a power of two is exact when its result remains representable, but the evaluator should still pass it through its binary32 multiplication primitive so overflow, underflow, and signed zero are handled uniformly.

Do not replace the transform with an exact real Hadamard followed by one rounding. Do not use a depth-10 gamma allowance when exact directed evaluation of the ten-stage tree is available.

## Dynamic hidden quantization

Each wave owns one consecutive 128-value block. For finite values, its `fmaxf(fabsf(...))` tree returns the exact maximum of the 128 represented binary32 magnitudes. The order of max operations therefore does not enlarge a finite interval once every value is enclosed.

For a block maximum `m`:

```text
if m > 0:
    iscale = RN32(127.0f / m)
else:
    iscale = +0.0f

scale = RN32(m / 127.0f)

for each value y:
    t = RN32(y * iscale)
    q = round_to_nearest_integer_ties_to_even(t)

xsum = exact_integer_sum(q)
```

The source computes `iscale` and `scale` with separate divisions. They are not reciprocals of one shared rounded quantity.

`__float2int_rn` lowers to `llvm.rint.f32`, then float-to-signed-int conversion. The gfx1151 assembly uses `V_RNDNE_F32` followed by `V_CVT_I32_F32`. A code enclosure must include every nearest-even integer reached by the enclosed binary32 product. In particular, exact half-integer endpoints require parity-aware handling.

The nonzero-block profile requires finite `iscale` and an in-range conversion. Under those conditions, packing the low byte preserves the resulting code. A block which could produce an infinite scale or an out-of-range conversion is unsupported until those hardware cases are added explicitly.

## `rsqrtf` for a later upstream extension

The fixed-`q_d` evaluator does not call `rsqrtf`. If the boundary moves back through RMS normalization, do not model HIP `rsqrtf(x)` as one unconditional `V_RSQ_F32(x)`.

The current ROCm device library emits this structure for binary32:

```text
small = ordered(x < 2^-126)
t = small ? RN32(x * 2^24) : x
r = V_RSQ_F32(t)
out = small ? RN32(r * 2^12) : r
```

AMD documents `V_RSQ_F32` as `1/sqrt(x)` with one-ULP accuracy and denormal flushing. The scaling branch moves positive subnormal inputs into the normal range before that instruction. An interval which straddles `2^-126` should evaluate both branches. RMS inputs are positive because of epsilon, but the reduction, mean division, epsilon addition, and this branch all need their own outward operations.

The linked `oclc_correctly_rounded_sqrt_on.bc` setting does not turn reciprocal square root into a correctly rounded operation. Use the documented one-ULP enclosure for `V_RSQ_F32`.

## What the evaluator may claim

An evaluator implementing this file may claim enclosure of the ROCm 7.2.3 gfx1151 source program over its declared fixed-code scale box, provided every supported-profile check passes. It may then derive finite hidden-code sets, hidden-scale intervals, and exact code sums.

It may not claim an upstream workload guarantee. Fixing `q_d` and bounding scales is still a premise supplied by the caller.

One custody gap remains in the existing dataset manifest. It records the clean Bonsai source commit, but not the linked `halo_rows.o` or final code-object hash. The committed code object at that source revision identifies the expected compiler and confirms the lowering family. A future capture intended as a last-bit deployment certificate should also record the loaded code-object hash and full compiler invocation.

## Reproduction references

- Captured source: `/path/to/workspace/projects/bonsai-halo`, commit `6fcff4c0a881e1fa2f448db630e76a57cb1bf268`.
- Dataset manifest: `/path/to/workspace/data/kelana-ffn/ptq1_0/layer00/manifest.json`.
- Installed HIP intrinsic header: `/nix/store/ly700gf82nzmd5y8cyz14107d0ql3fib-rocm-toolchain/lib/clang/22/include/__clang_hip_math.h`, SHA-256 `de239ed4fcf1fc64ec4c4f6d3dddfffa8cd2c253b58c27923b8099e0baa48fe3`.
- Local AMD ISA source: `hardware/gfx1151/sources/rdna35-isa.txt`, SHA-256 `af07d5a7b1bbcf27355f6b38405bfae83ad729acc512c0a77c20beb257978727`.
- Compiler provenance already tracked in `hardware/gfx1151/compiler/PROVENANCE.md`.
