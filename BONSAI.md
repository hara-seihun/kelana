# Bonsai toy problems

Initial descriptions of three related computations. Backends, executable references and Lean proofs are future work. Their interfaces and decomposition boundaries remain open.

## Source

Repository: `/path/to/workspace/projects/bonsai-halo`.
Revision: `6fcff4c0a881e1fa2f448db630e76a57cb1bf268`.
The source tree was clean when these descriptions were recorded.

- [`src/halo_format.h`](/path/to/workspace/projects/bonsai-halo/src/halo_format.h): `pack5`, `pack4`, `encode_block`, layout and scalar decoding.
- [`kernels/device.hpp`](/path/to/workspace/projects/bonsai-halo/kernels/device.hpp): `peel`, `peel_last`, `dot4`, `mv_rows_pre`, `mv_rows_t`.
- [`kernels/phases.hpp`](/path/to/workspace/projects/bonsai-halo/kernels/phases.hpp): `mvw_rows`, `ph_matvec_w`, `ph_matvec_auto`.

These descriptions do not copy the implementation. Use the pinned revision when comparing later source changes.

## 1. Packed trit peeling

A logical trit t is in `{0,1,2}` and represents weight `t - 1`. Five trits have 243 possible tuples. For their base-three rank q, with the first trit most significant, Bonsai stores:

```text
q = 81*t0 + 27*t1 + 9*t2 + 3*t3 + t4
b = ceil(256*q / 243)
```

The canonical domain is the image of this encoding, 243 byte patterns, not the integer interval 0 through 242. Decoding repeatedly applies:

```text
m = 3*b
t = m >> 8
b = m & 255
```

Five steps recover the tuple. The terminal remainder is unobserved. The four-trit tail encoding uses `ceil(256*q / 81)` and four steps.

The GPU's `peel` handles two independent bytes in the low bytes of two u16 fields of one register. Packed multiplication and shifting return `[ta,0,tb,0]`; masking retains both remainders. Each per-field product is at most 765, so multiplication fits in u16. The final peel omits remainder production.

Potential proof obligations:

- Encode/decode round trip for all canonical tuples.
- Packed peeling equals two scalar peeling maps.
- Repeated steps preserve the decoder's state invariant.
- Omitting an unobserved terminal remainder preserves the result.

A replacement may decode several trits together or use a different encoding. The larger problems need not call this operation.

## 2. Byte-lane assembly and dot product

Two peeled words combine into four byte lanes:

```text
[ta,0,tb,0] OR ([tc,0,td,0] << 8) = [ta,tc,tb,td]
```

The fields are disjoint because each trit fits in a byte. Bonsai's storage order makes those lanes match the activation order without a runtime permutation.

For unsigned trits t and signed int8 activations x, the integer target over one 128-element block is:

```text
y = sum_i ((t_i - 1) * x_i)
  = sum_i (t_i * x_i) - sum_i x_i
```

The backend constructs 32 four-byte words, executes 32 unsigned-by-signed `dot4` operations per activation row, then subtracts the activation sum. The multi-row path shares decoding across rows. Expanded weight bytes remain in registers rather than an expanded weight matrix in device memory.

With zero initial accumulator and arbitrary signed int8 x, the unsigned partial sum has absolute value at most 32768; the corrected sum at most 16384. These block computations fit in int32. An incoming accumulator would need its own range contract. Bonsai's activation quantizer uses the narrower range -127 through 127.

Potential proof obligations:

- Byte assembly and activation layout preserve the intended pairings.
- Dot4 decomposition equals the logical integer sum without overflow.
- Unsigned-trit correction equals the signed ternary result.
- Sharing decoding across activation rows preserves each result.

The dot-product result is an independent observer. A new backend may bypass byte expansion entirely. FP16 weight scales, FP32 activation scales, FMA and cross-block reductions are outside this initial integer contract.

## 3. Ternary matrix tiles through WMMA

On AMD, WMMA means Wave Matrix Multiply-Accumulate. A wave of 32 threads collectively computes `D = A*B + C`; matrix fragments occupy registers distributed across lanes. The instruction Bonsai uses has M=N=K=16, byte operands and int32 accumulators. It represents 4096 multiply-accumulate terms, not 4096 independent instructions or a promise of single-cycle execution.

The logical block computation has 32 weight rows, reduction width 128 and R activation columns, with R at most 8 in Bonsai:

```text
Y[m,r] = sum_k ((T[m,k] - 1) * X[k,r])
```

The current backend decodes each lane's 128 trits into 32 packed words. Eight reduction slices of width 16 each use two WMMA calls to cover the 32 weight rows. Lane-half swaps construct the second weight fragment. Hardware columns beyond the eight activation rows duplicate existing columns and their outputs are discarded. Each output receives the corresponding activation-sum correction.

The result layout is part of the contract. For accumulator register j and lane half h, the first fragment produces weight row `2*j` when h=0 and `2*j+17` when h=1. The second produces `2*j+16` when h=0 and `2*j+1` when h=1. The column is the lane index modulo 16. This ownership rule explains why a lane swap changes which weight rows the instruction computes.

Potential proof obligations:

- Fragment assembly implements the intended matrix entries and signedness.
- Lane exchange and output ownership cover each requested output exactly once.
- Width-16 slices compose to the width-128 integer product without overflow.
- Discarded duplicate columns do not affect observed outputs.
- Activation-sum correction agrees with signed ternary multiplication.

Bonsai dispatches up to four activation rows through dot4 and larger passes through WMMA. This is an implementation choice, not a mathematical boundary. Its eight-row prefill and verification passes make this a useful first larger consumer of alternative trit representations.
