# Register-resident PERM observer for the gate/up projection

The map is exact and costs no bandwidth. In the schedules measured here it runs at 0.27–0.56 of
the IU4 matrix instruction's rate with every operand already in registers, so none of them is a
projection candidate.

The observer computes real projection sums with no weight expansion, no LDS table and no matrix
instruction. One `V_PERM_B32` produces partial sums for four output rows at once. What it cannot do
is absorb its own accumulation: each lookup result still has to be added into something, and that
is where the schedules measured here lose to a matrix instruction that accumulates 4096 MAC
internally.

This is not the [LDS lookup](../lookup/README.md) family. Nothing here reads a table from memory;
what limits it is instruction issue.

## The map

For one activation pair `(a1, a2)` of one token, the eight dynamic bytes of a PERM operand pair
hold the eight nonzero two-trit outcomes, biased by 14 so every byte is a small unsigned number:

```text
lo = [ a1+a2 | a1-a2 | a1 | a2 ] + 14        hi = 0x1c1c1c1c - lo
```

`hi` is one `v_sub_u32`: each byte of `lo` is at most 28, so `28 - lo_byte` borrows nowhere and
lands on exactly the four negated outcomes. Table byte order and selector codes:

| selector | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 12 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `(w1,w2)` | (1,1) | (1,-1) | (1,0) | (0,1) | (-1,-1) | (-1,1) | (-1,0) | (0,-1) | (0,0) |
| byte | `a1+a2+14` | `a1-a2+14` | `a1+14` | `a2+14` | `14-a1-a2` | `14-a1+a2` | `14-a1` | `14-a2` | `0` |

A selector dword carries four such codes, so **one PERM delivers four output rows times two
weights**: eight ternary MAC per instruction, four output sums at once. Selectors are weight-only
and prepared offline. Tables are activation-only, built online and shared across every output row
the wave holds.

Zero-weight pairs take PERM's built-in selector 12 and contribute 0 rather than the biased 14. The
deficit is `14 * (number of nonzero pairs on that row in the window)`, determined by the weights
alone, so it is an offline per-(row, 128-block) constant folded in beside the existing scales. No
dynamic bias byte is needed, and the eight dynamic slots stay free for the eight nonzero patterns.

Accumulation is carry-free in packed bytes: each contribution is in `[0, 28]`, so eight of them
reach at most 224 and no carry crosses a byte boundary. Every eight pairs the four byte lanes are
drained into two 16-bit lane pairs, where a whole 128-input block reaches at most 1792. Signs never
leave the table, and nothing in the online path is approximate.

`./build/probe` verifies this against an exact integer reference on the GPU: **2052 row cases over
random ternary weights and random A4 activations, every window length from 8 to 128 inputs, zero
mismatches.**

Main's `Kelana/RegisterObserver.lean` proves the arithmetic underneath: `zero_slot` and
`encoded_range` for the `[0,28]` byte encoding, `offline_bias_correction` for
`sum(encoded) - 14*count(active) = dot`, `eight_pairs_fit_byte` for the 224 bound, and
`four_byte_decode` / `pack_add` for carry-free four-row accumulation in one dword. Those proofs
cover the encoding, not the hardware permutation; PERM's meaning is the one modelled in
`Kelana/Hardware/IntOps.lean` and exercised by the check above.

## The IU4 baseline is at issue rate, not latency

An earlier version of this directory timed IU4 with two dependent accumulator chains, which can
measure WMMA latency instead of WMMA issue rate and would flatter everything compared against it.
`rate_bench` now sweeps the chain count instead of assuming:

| independent accumulator chains | 1 | 2 | 4 | 8 |
| --- | ---: | ---: | ---: | ---: |
| 8 waves/SIMD | 681.2 | 683.9 | 683.8 | 683.6 |
| 1 wave/SIMD | 642.4 | 684.3 | 684.2 | 684.1 |

MAC/ns/SIMD32. The sweep does detect latency limiting where it exists — at one wave per SIMD a
single chain loses 6% — and it shows none at the eight waves per SIMD everything else is measured
at, where even one chain is within 0.4% of the best. The paired analysis puts every chain count
within 0.6% of `chains8` with bootstrap intervals that mostly straddle 1.0.

Against the sensor clock recorded during those blocks (2.64–2.81 GHz, mean 2.767), 683.6
MAC/ns/SIMD is 247 MAC/clk/SIMD32, against the 256 MAC/clk/SIMD32 that a 16-cycle
`v_wmma_i32_16x16x16_iu4` gives. Sensor snapshots are not cycle counts, so read that as consistent
with the instruction running at its architectural rate, not as a measured cycle count. The same
figure is reached independently by [triple-packing](../triple-packing/README.md#how-the-stored-samples-normalize),
whose probe measures 5.989 ns per IU4 instruction per SIMD against 5.94 ns here, from a different
kernel and protocol. Read that section before quoting its stored samples: their `waves_per_simd`
field is twice the physical value, and dividing by it rather than by the physical wave count gives
3.02 ns and about twice the true device rate.

## Measured rates

Randomized interleaved rounds with the shared telemetry recorder, `kelana-batch-bench/2` format,
analyzed by [`bench/paired_analysis.py`](../bench/paired_analysis.py). Every variant is normalized
to the same useful ternary MAC per call, so a round speed ratio is a rate ratio. 15 rounds, 450
calls per variant, 2 s untimed rotating ramp, 8 waves/SIMD, all operands register-resident.
Instruction counts are read from the emitted assembly by
[`count_instructions.py`](count_instructions.py), not assumed.

| variant | MAC/lane/instr | MAC/ns/SIMD | round ratio to iu4 | bootstrap 95% |
| --- | ---: | ---: | ---: | --- |
| `perm-issue-ceiling`, results never accumulated | 8.00 | 723.8 | 1.062 | 1.057–1.066 |
| `iu4-wmma-chains8` | 128.00 | 683.6 | 1.000 | — |
| `core-rq8-tok4`, PERM pairs accumulated by `v_add3` | 5.33 | 384.2 | 0.565 | 0.560–0.570 |
| `core-rq16-tok4` | 5.33 | 375.2 | 0.555 | 0.552–0.558 |
| `freetables-rq8-tok4`, plus byte-lane drain | 4.00 | 250.2 | 0.368 | 0.365–0.371 |
| `full-rq16-tok2`, plus online table construction | 3.28 | 209.5 | 0.309 | 0.307–0.310 |
| `full-rq8-tok4` | 2.91 | 186.0 | 0.273 | 0.271–0.275 |

Raw samples, blocks and the sensor trace: [`results/rates.json`](results/rates.json); analysis:
[`results/rates-analysis.json`](results/rates-analysis.json); instruction counts:
[`results/instruction-counts.json`](results/instruction-counts.json). The first version's
sequential best-of-seven numbers are retained in [`results/probe.json`](results/probe.json) as
recorded measurements; where they disagree with the table above, the interleaved run is the one
this report relies on.

The first row is the interesting one. PERM issues at about 1.02 instructions per clock per SIMD
here, and a full-rate VALU instruction carrying 8 MAC per lane delivers 256 MAC/clk/SIMD32 — the
same number the IU4 matrix instruction reaches. So the lookup itself is not what loses. What loses
is that a PERM result is not yet a sum: `v_add3_u32` lets two PERMs share one accumulate, and that
third instruction alone takes the schedule from 1.06 to 0.565.

## What the tested schedules cost, and the model that explains it

Under one explicit operation model — each group's contribution produced by a single `V_PERM_B32`
whose operands depend only on activations and whose selector byte is fixed offline from weights,
and each PERM result folded into an accumulator by VALU integer adds — two things follow:

- A selector byte names at most ten things: the eight operand bytes, `0x00` (code 12) and `0xff`
  (code 13); codes 8–11 replicate an operand sign bit and add no further value. Nine two-trit
  patterns fit; 27 three-trit patterns do not. So a group is two trits and a PERM carries at most
  8 MAC per lane.
- With `v_add3_u32` as the widest available combiner, at best two PERMs share one accumulate, so
  the model's best case is 16 MAC per 3 instructions, or 5.33 MAC per lane per instruction. At the
  VALU issue rate measured here that is about 171 MAC/clk/SIMD32 against IU4's 247, i.e. **0.69**.

`core` reaches 0.565 of IU4, so the schedules are within 82% of what that model allows. The rest of
the loss is the byte-lane drain a 128-input block forces and the online table construction, which
the `freetables` and `full` variants separate: construction costs the difference between 0.368 and
0.273–0.309, and is worth about 0.06–0.10 of IU4 even when it is amortized over sixteen row quads.
Ten instructions per token per four activations build both tables of two pairs:

```text
U  = X + 0x07070707              bytes a_i + 14
S  = X + (X >> 8)                byte 0 = a1+a2+14, byte 2 = a3+a4+14
D  = (X + 0x0e0e0e0e) - (X>>8)   byte 0 = a1-a2+14, byte 2 = a3-a4+14
SD = perm(S, D, 0x02060004)
lo0 = perm(SD, U, 0x01000504)    lo1 = perm(SD, U, 0x03020706)
hi  = 0x1c1c1c1c - lo
```

Activations are wave-uniform, so construction could in principle move to the scalar unit; the
`freetables` variant is what the schedule reaches if it is deleted outright, and that is 0.368.

**This bounds the stated model, not V_PERM_B32.** It assumes one PERM per group, an offline
selector, and integer adds as the combiner. It says nothing about maps that spend several PERMs or
planes per group, compute selectors online, feed PERM output to a different consumer instruction,
restrict the weight family so fewer than ten patterns occur per group, or accept approximate table
entries. Pattern collisions could in principle let a group exceed two trits, but for A4 activations
they are scarce — the worst three-activation triple `(-7,-6,-4)` still yields 25 distinct sums
(`./build/probe` enumerates this) — and which patterns collide depends on activation values, while
the selector is fixed offline and cannot track them.

## Traffic and layout

Nothing below was measured in a projection kernel; it is the accounting a projection kernel would
inherit.

- **Selectors are four bits per weight.** One selector byte covers two weights of one row, so the
  gate/up image is 85.00 MB, the size of `iu4n`'s nibble image and twice `iu4p`'s two-bit image.
  Selectors cannot be stored two bits per weight and expanded cheaply: the expansion is a byte-wise
  remap of nine sparse four-bit codes, costing several instructions per PERM the codes feed.
- **Online layout is cheap.** The producer writes activations as biased bytes `a+7`, four per dword,
  broadcast to all lanes — comparable to the WMMA B-fragment write it replaces, and it removes the
  fragment replication the matrix path needs.
- **Accumulator registers are not the constraint.** Four rows share one byte-packed dword and two
  16-bit lane pairs: 0.75 dwords per (row, token) against the matrix path's 1.0.
- **The epilogue is unchanged**: per-(row, block) scale, the offline bias constant, FP16 row scale
  and FP32 token scale, as the arithmetic candidates do it.

## Why no projection candidate is registered

The tested schedules reach 0.27–0.37 of the IU4 instruction rate with no memory traffic, no scales
and no epilogue, and the operation model above does not offer more than 0.69 even if construction
and drain were free. A projection kernel built on them would add the 85 MB selector stream,
activation staging and the epilogue to a starting point already well below the matrix instruction
that existing candidates use. Registering one would consume shared bench rounds to place a
candidate whose component rate is already this far behind, so `candidates/` stays empty and the
bench glob finds nothing here.

For magnitude context only, `arithmetic/proj_probe` was run in the same session and recorded in
[`results/arith-proj-baseline.txt`](results/arith-proj-baseline.txt): `iu4p` computes the real
178.3 M-weight projection at 265–297 MAC/ns/SIMD at 128–256 tokens, `iu4n` at 218–226. **That is a
sequential run of a separate probe, not part of the interleaved experiment above**, and the two sets
of numbers should not be combined into a single ratio.

What would reopen this: a PERM-shaped instruction carrying more than two trits per destination
byte; a combiner that absorbs more than two lookups per instruction; a weight family restricted
enough that fewer than ten patterns occur per group; or a consumer that wants the packed byte state
directly rather than an integer sum, which is the shape the
[two-trit observer](../../contracted-map/README.md) wins with.

## Reproduce

From this directory:

```sh
mkdir -p build results
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value probe.hip -o build/probe
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value rate_bench.hip -o build/rate_bench
../hardware-run ./build/probe                            # exactness against an integer reference

../hardware-run ./build/rate_bench --rounds 15 --calls 450 --json results/rates.json
../hardware-run ./build/rate_bench --waves-per-simd 1 --rounds 8 --calls 48 \
    --json results/rates-1wave.json                      # chain sweep where latency does bite
python3 ../bench/paired_analysis.py results/rates.json \
    --baseline iu4-wmma-chains8 --out results/rates-analysis.json

hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value --cuda-device-only -S \
    rate_bench.hip -o build/rate_bench.s
python3 count_instructions.py build/rate_bench.s --out results/instruction-counts.json
```

Blocks must stay longer than the recorder's ~5 ms sampling interval or rounds arrive without clock
data; at 450 calls over 15 rounds all 270 blocks in the recorded run carry it. GPU work goes through
the shared [`hardware-run`](../hardware-run) lock and changes no services or clocks. `build/` is
disposable; sources, this file and `results/` are owned by Kelana.
