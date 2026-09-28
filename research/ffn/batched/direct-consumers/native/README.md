# Reading a packed product without decoding either channel: native components

A packed value `p = g + R*u` can hand over the product `g*u` in two instructions, with no channel
ever reconstructed. Square it and take a signed bitfield out of the low 32 bits:

```
v_mul_i32_i24 t, p, p          ; low 32 bits of p^2 = g^2 + 2^17*g*u   (R = 65536)
v_bfe_i32     r, t, 17, 15     ; r = g*u
```

The algebra is `p^2 = g^2 + 2*R*g*u + R^2*u^2`: at `R = 65536` the `u^2` term is a multiple of
`2^32` and vanishes from the low word, and `g^2` stays below bit 17 whenever `|g| <= 362`, so the
15-bit field at bit 17 is exactly `g*u`. The gate's sign is also readable straight from `p`: bit 15
is set exactly when `g < 0`.

**Measured: the consumer is genuinely 1.97x cheaper than decoding, and it is still not the cheapest
way to obtain `g*u` on this device.** Against decode-both-then-multiply on identical packed inputs
the two-instruction consumer wins 1.969x [1.941, 1.998], 20 of 20 rounds. The fast form needs
`v_mul_i32_i24`; with the generally valid `v_mul_lo_u32` it is 1.20x *slower* than decoding, because
the 32-bit multiply runs at a quarter rate. Starting from two separate channel registers, packing
and then consuming costs 3 instructions and beats decoding by 1.288x [1.270, 1.305], but simply
multiplying the two separate channels costs 1 instruction and beats the fused packed consumer by
1.79x. So the packed-square consumer pays only where a packed `g + 65536*u` already exists.

- [pack.hpp](pack.hpp): the exact integer algebra, shared by host and device.
- [consumer_probe.hip](consumer_probe.hip): every candidate as an explicit ISA sequence, an
  exactness mode and a randomized rate mode with retained samples and telemetry.
- [build.sh](build.sh): build, dump real device assembly, run both modes through
  [`hardware-run`](../../hardware-run), and produce paired per-round statistics.
- [kernel_ops.py](kernel_ops.py): per-kernel inner-loop instruction counts read out of that assembly.
- [results/](results): `check.json`, `rate.json`, `rate-summary.txt`, `paired/`, `asm/`.

## Exactness

`./build/consumer_probe check`, all counts from [results/check.json](results/check.json). Every
sequence tested here is the same inline-asm sequence the rate probe times.

| claim | test | result |
| --- | --- | --- |
| `sbfe(low32(p*p), 17, 15) = g*u` with a 32-bit square | 3,281,697 cases, `g` in [-400,400], `u` in [-2048,2048] | exact on all 315,641 cases in the predicted region, wrong on every case outside it |
| predicted region is `g^2 < 2^17` and `g*u` in [-2^14, 2^14) | same sweep | tight in both directions: 0 failures inside, 0 accidental successes outside |
| domain `\|g\|, \|u\| <= 127` | exhaustive 65,025 cases | exact for the 32-bit square, the 24-bit square and the gate-masked product |
| gate sign = bit 15 of `p` | every case with `\|g\| < 128` | 0 failures |
| `w-pack-fused`, the real producer: `v_lshl_add_u32` from separate `g`, `u` then square and extract | same sweep | 0 failures in the `\|g\|, \|u\| <= 127` domain; 178,010 failures in the wider predicted region, identical to the bare 24-bit square |
| `w-sep-mul`, separate channels multiplied | same sweep | 0 failures anywhere in the predicted region |
| decode-both-then-multiply | same inputs | 0 failures |
| `R = 1024`, `sbfe(p*p, 11, 9)` | exhaustive `g,u` in [-64,64] | exact on all 3,531 cases in the predicted region |
| `R = 1024` over the stated FP16 domain `\|g\|, \|u\| <= 16` | exhaustive 1,089 cases | 2 failures, exactly the 2 cases with `g*u = +256` |
| the `p = +-16400` detector repairs those | same domain | 0 failures, integer and float paths alike; outside the domain 8 of the 10 `g*u = 256` cases in the wider box are missed, so the detector is domain-specific |
| float paths over `\|g\|, \|u\| <= 16` | exhaustive 1,089 cases | `n-decode-f32` 0 failures, `n-fused-f32-guard` 0 failures, unguarded `n-fused-f32` 2 failures |
| packed polynomial `P(g+Ru) = P(g) + R*u*P'(g) mod R^2` | exhaustive `g` in [-3,3], `u` in [-7,7] for `P = 480x^2 + 80x^3 - x^5` | 0 failures, and both the low and high parts stay in range |
| `S = sum c_i*p_i^2`, one extraction per output | 1,048,576 random trials, fan-in 128, channels in [-7,7], ternary `c` | 0 failures, 0 trials out of bounds |

### Why the fast square needs a small domain

`v_mul_i32_i24` truncates its operands to signed 24 bits, so it returns the true product only when
`p` fits that width. `|g|, |u| <= 127` is *sufficient* for that, not a description of the boundary:
`|p| <= 127 + 65536*127 < 2^23`. It is not the whole set of packed values that fit — `g = 0` with
`u = -128` fits too, and the sweep finds 3,841 further cases outside the box where the truncated
operand still yields the right answer, all of them `g = 0`. Measured directly: 133,790 in-region
cases have `p` inside signed 24 bits and none of them fail. The theoretical region reached by the
32-bit square, `|g| <= 362` with `|g*u| <= 16383`, is real but only available at quarter rate.

## Rate

`./build/consumer_probe rate 8000 20 5`: 20 rounds, candidate order reshuffled every round, 5 timed
launches per block, **every sample retained** with its round, position in the round and wall-clock
window, alongside a GPU clock, power, temperature, busy and host-load trace and the list of
processes holding a DRM device. The file is `kelana-batch-bench/2`, so
[bench/paired_analysis.py](../../bench/paired_analysis.py) reads it unmodified; `rows` carries waves
per SIMD32 for the consumer groups and 1 for the bilinear group. Inputs are register-resident with
no memory traffic in the timed loop, and each candidate is emitted stage by stage across the eight
accumulator values a lane holds from one WMMA tile, so dependent instructions sit eight apart and
the number is issue cost rather than a gfx11 dependent-issue bubble, which inline asm cannot cover
with `s_delay_alu` hints. The separate-channel candidates read `g` and `u` from two different
device buffers; no candidate manufactures its second operand from the first.
[results/asm/kernel_ops.json](results/asm/kernel_ops.json) confirms every inner loop contains
exactly `8 * ops` VALU instructions and 4 SALU, with nothing added by the compiler.

Clocks matter here and were checked rather than assumed. An unramped run records 0.625 GHz at the
start of the first group and 2.6 GHz by the third, a larger effect than anything being compared, so
the probe spins the GPU for 2 s before the first group and 0.5 s before each group. The recorded
trace for this run holds 2.678–2.752 GHz for the 2-wave group, 2.785–2.798 for the 8-wave group and
2.812–2.833 for the bilinear group, at 92–100% busy. `bonsai-halo` and a headless Chrome held DRM
file descriptors throughout; that is recorded in the file, not excluded.

Per application per physical SIMD32, 8 waves per SIMD32
([processor-unit correction](../../GEOMETRY.md)):

| candidate | VALU ops | ns | ns per op |
| --- | ---: | ---: | ---: |
| `empty` loop overhead | 0 | 0.1804 | — |
| `w-sep-mul` separate `g`, `u` registers, one `v_mul_i32_i24` | 1 | 0.4209 | 0.421 |
| `w-fused-24` square + extract | 2 | 0.7617 | 0.381 |
| `w-fused-lo` 32-bit square + extract | 2 | 1.7630 | 0.882 |
| `w-pack-fused` `v_lshl_add_u32` producer + the fused consumer | 3 | 1.1519 | 0.384 |
| `w-decode-24` decode both, multiply | 4 | 1.4868 | 0.372 |
| `w-decode-lo` decode both, 32-bit multiply | 4 | 2.4798 | 0.620 |
| `w-fused-relu` product + gate sign mask | 4 | 1.5043 | 0.376 |
| `w-decode-relu` decode, `v_max_i32`, multiply | 5 | 1.8397 | 0.368 |
| `w-poly-fused` packed quartic | 8 | 5.0073 | 0.626 |
| `w-poly-decode` decode, Horner on `P'` | 9 | 3.4785 | 0.387 |
| `n-fused` R=1024 square + extract | 2 | 0.7592 | 0.380 |
| `n-fused-guard` with the `+-16400` detector | 4 | 1.4764 | 0.369 |
| `n-decode` R=1024 decode, multiply | 4 | 1.4897 | 0.372 |
| `n-fused-f32` float in/out, domain excludes `g*u = +256` | 4 | 1.4907 | 0.373 |
| `n-fused-f32-guard` float in/out, domain matched to `n-decode-f32` | 6 | 2.2240 | 0.371 |
| `n-decode-f32` all-float decode, multiply | 4 | 1.4817 | 0.370 |

Paired per-round comparisons, geomean over rounds with a bootstrap 95% interval over rounds, from
[results/paired/](results/paired), 8 waves per SIMD32:

| pair | speedup of the second | 95% interval | rounds won |
| --- | ---: | --- | ---: |
| `w-decode-24` → `w-fused-24` | **1.969x** | [1.941, 1.998] | 20/20 |
| `w-decode-24` → `w-fused-lo` | 0.836x | [0.829, 0.843] | 0/20 |
| `w-decode-24` → `w-pack-fused` | **1.288x** | [1.270, 1.305] | 20/20 |
| `w-decode-24` → `w-sep-mul` | 3.530x | [3.470, 3.587] | 20/20 |
| `w-decode-relu` → `w-fused-relu` | **1.223x** | [1.213, 1.234] | 20/20 |
| `n-decode` → `n-fused` | 1.965x | [1.950, 1.981] | 20/20 |
| `n-decode` → `n-fused-guard` | 1.010x | [0.999, 1.021] | 12/20 |
| `n-decode-f32` → `n-fused-f32-guard` | 0.665x | [0.659, 0.671] | 0/20 |
| `w-poly-decode` → `w-poly-fused` | 0.693x | [0.687, 0.698] | 0/20 |
| `bilinear-decode` → `bilinear-fused` | 1.180x | [1.177, 1.183] | 20/20 |

Dividing paired ratios against a common baseline gives the two producer-side numbers: the fused
packed consumer costs **1.79x** a plain separate multiply (3.530/1.969), and pack-then-consume costs
**2.74x** it (3.530/1.288).

Two instruction facts read off the table directly. `v_mul_i32_i24` is full rate; `v_mul_lo_u32` is
not — `w-fused-lo` minus a `v_bfe_i32` puts it near 1.40 ns, about four full-rate slots, which is
why every 32-bit-multiply variant loses. `v_bfe_i32`, `v_bfi_b32`, `v_max_i32`, `v_lshl_add_u32`,
`v_mad_i32_i24`, `v_cvt_*` and the FP32 ops all issue at the same 0.37 ns full rate.

## The bilinear component, one extraction per output

`S = sum_i c_i*p_i^2` accumulated in int32, `+65536`, one `v_bfe_i32(17,15)` per output. No product
is extracted per element, and `sum c_i*u_i^2` wraps away. Fan-in 128, ternary `c`, four independent
partial sums in both paths, against decoding every element: **1.180x** [1.177, 1.183], 20 of 20
rounds. That is well below the 1.97x of the isolated consumer. This kernel is fed from memory, so
address arithmetic sits alongside the arithmetic being compared: the inner loops hold 41 and 50 VALU
per four elements.

For these two fixed schedules the arithmetic accounting is: per element the fused path spends 1
instruction and the decode path 4, while per (element, output) pair both spend the same 2, so a
schedule with `N` outputs sharing one loaded input has arithmetic ratio `(4+2N)/(1+2N)` — 2.00 at
one output, 1.33 at four, 1.18 at eight. That model counts only these two instruction sequences
under this loop structure; it is not a statement about other schedules, other data layouts or
programs that restructure the loop. The measured 1.180x at `N = 1` sits below the model's 2.00
because of the address arithmetic the model ignores.

## What this settles, and what it does not

1. **The extraction works, exactly, over its stated domains.** Both radices, the gate-sign variant,
   the real producer sequence, the polynomial rule and the accumulated bilinear map all reproduce an
   exact integer reference, with region boundaries measured rather than assumed.
2. **Removing the decode is worth 1.97x on the consumer alone**, 1.22x for the gate-masked product,
   20 of 20 rounds each. That needs `v_mul_i32_i24`, for which `|g|, |u| <= 127` is sufficient.
3. **Building the packed value costs less than decoding it, but more than never packing.**
   `w-pack-fused` at 3 instructions beats `w-decode-24` by 1.288x, so a producer is not required to
   be free for the map to pay — any producer cheaper than the 2-instruction saving wins. What loses
   here is packing channels you already hold separately: that costs 2.74x a plain multiply.
4. **No candidate producer has been measured end to end.** The known paired-FP16 WMMA operand
   cannot carry a `65536` radix, and IU4/IU8 operands have no radix room either, so the packed
   carrier would have to come from somewhere this directory has not built. No whole-FFN candidate
   was constructed or timed here, and nothing in these measurements rules out a producer that
   supplies the carrier cheaply.
5. **The FP16-feasible radix loses once its domains are matched.** `R = 1024` needs the `+-16400`
   guard inside its own stated domain; guarded, it ties decode in integers (1.010x [0.999, 1.021])
   and loses 1.50x in the float-in/float-out form that an FP32 WMMA accumulator actually produces.
6. **This polynomial allocation loses, for a reason specific to it.** The measured quartic spends
   two `v_mul_lo_u32`, so it runs 1.44x slower than decode-and-evaluate. That is a fact about this
   `k = 16`, 16-bit-derivative allocation, not a necessary condition: `v_mul_i32_i24` returns the
   correct product modulo `2^24` even when its inputs were wider, so a consumer that only needs the
   low 24 bits can run a whole polynomial in that quotient. Another allocation or representation
   could avoid the 32-bit multiplies entirely.

## Reproducing

```
./build.sh                                   # build, dump assembly, run check and rate, pair up
../../hardware-run ./build/consumer_probe check
../../hardware-run ./build/consumer_probe rate 8000 20 5
```

`check` returns 2 if any claim fails. Expected nonzero counts are characterizations, not failures:
`v_mul_i32_i24` outside a signed 24-bit `p`, the unguarded `R = 1024` sequence on `g*u = +256`, and
the `+-16400` detector outside the domain it is claimed for.
