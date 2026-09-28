# Seven hardware products instead of eight

One level of Strassen on the deployed gate/up projection, with the fixed weight combinations
compiled offline instead of stored as expanded matrices. Measured on gfx1151 against eight-product
controls built from the same kernel, on the deployed layer-0 weights and real contextual token rows.

**The scheme works, it is exact, and what it buys depends on the batch.** Against a control with the
same tiling and the same weight traffic, seven products win 1.13–1.21x at every size measured, in
every round. Against the fastest eight-product configuration available at that size, it wins 1.13x
at 32 rows and 1.04x at 64 and 128, and loses 1.17x at 256, because the eight-product map can
spend the registers Strassen needs on a wider token tile. The plan also cannot run on the four-bit
activations of the fastest current map without extra machinery, so its wins are bought at A3, with
2.3x the projection quantisation error of A4.

## Problem and provenance

The default problem is real. Ternary weights and FP16 block scales are decoded from the deployed
`gate.halo` and `up.halo` of
`/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00` (layer 0, D = 5120, FF = 17408, 178.3 M
ternary weights, gate nonzero fraction 0.6723). Activations are the dataset's real contextual rows
carried through the deployed FFN input transform — post-attention RMS norm, the folded width-D sign
vector, the 1024-point Hadamard with the 1/32 factor — then quantised by this directory's
deterministic symmetric per-(token, 128-block) quantiser. The transform runs on the host, so its
float summation reassociates differently from the deployed device reduction; these are the deployed
transform of the real rows, not a bit copy of the engine's intermediate.

`--synthetic` selects random trits, synthetic scales and iid Gaussian activations. That problem is
kept only as a correctness case, in
[results/seven-check-synthetic.txt](results/seven-check-synthetic.txt); no speed or error claim on
this page comes from it.

Timing goes through [bench/probe_measure.hpp](../bench/probe_measure.hpp), the common standalone
probe adapter, so this probe runs the same schedule as the FFN driver: a 2 s untimed duration ramp
rotating through cases, randomised case blocks inside 10 rounds, rewarming after every switch, every
sample retained with its round, order and host timestamps, a 5 ms sensor trace, and source and
executable fingerprints in the record. It refuses to run outside [hardware-run](../hardware-run) and
rejects cases with unequal work. Ratios below come from
[bench/paired_analysis.py](../bench/paired_analysis.py): geometric mean of per-round speed ratios,
round-bootstrap 95% interval, and how many rounds the candidate won. Raw runs and analyses are in
[results/](results).

A timed run also prints the output hash of every case at the full FF = 17408 shape. At 32 rows
`eight-i4o-a3-t2`, `eight-i4n-a3-t2`, `eight-i4os-a3-t2`, `seven-i4c-a3-t2` and
`seven-i4-compiled-a3` all hash to `9aaf5a34aad3ee96`: seven products and eight products agree
bit-for-bit on the real problem, not only on the reduced `check` shape.

## The split that keeps the scale semantics intact

A 2x2 Strassen needs all three dimensions halved. The choice that matters is the K split:

| dimension | halves |
| --- | --- |
| weight rows | the gate row tile and the up row tile a wave already owns |
| K | two 16-wide WMMA slices **inside one 128-scale block** |
| tokens | two adjacent 16-token tiles |

A partial product for one 128-block carries the scale `sw[row] * sa[token]`, which does not depend
on k. Keeping both K halves inside one scale block makes that factor common to every term, so the
whole 32-column block product is a pure integer matmul and Strassen's cancellations happen in int32.
Nothing is rounded, no scale is shared or re-quantised, and the epilogue is unchanged.

The scale argument is a factorization. Within one K block the desired product is
`diag(weight_scales) * (T * Q) * diag(activation_scales)`. Seven products compute the
unscaled integer `T * Q`, and the original row and token scales are applied afterward.
Gate and up rows may have different scales; those differences do not obstruct this factorization.

Keeping both K slices inside the block preserves that factorization. The unscaled weight sums
have five values in `[-2,2]`. Across K blocks, a row's scale and a token's scale can change, so
this particular factoring argument no longer applies. Adding already scaled weights can produce
nine values, but that is a different construction. Neither case proves that every cross-block
scheme must approximate the scales.

`./build/seven_probe check` enforces this on the real weights: every seven-product kernel is
**bit-identical** to the eight-product control on the same codes, 0 of 65536 outputs differing, at
IU4/A3 and at IU8/A7 ([results/seven-check-layer0.txt](results/seven-check-layer0.txt)).

The identity itself is main's `Kelana/SevenProduct.lean`, which proves the standard `m1..m7` form
over a possibly noncommutative ring, so it applies to the block products here and not only to scalar
ones, together with the operand ranges: A3 sums and differences fit signed IU4, ternary sums and
differences fit `[-2,2]`, and A4 does not fit because 7+7 does not. This kernel uses exactly that
form, so the proof covers its recombination; it says nothing about cost, which is the rest of this
page. The proof is imported and audited by the main Lean project.

## Operand width, and why this implementation needs A3

Five of the seven products take a sum or difference of two activation fragments, and this
implementation feeds that sum to the instruction directly, with no rescaling and no correction term.

| activations | codes | operand this implementation needs | fits |
| --- | --- | --- | --- |
| A4, the fastest current map | [-7,7] | [-14,14], five signed bits | no |
| A3 | [-3,3] | [-6,6] | yes, signed IU4 |
| A8, the deployed width | [-127,127] | [-254,254] | no |
| A7 | [-63,63] | [-126,126] | yes, IU8 |

Weight sums are in `[-2,2]`, so the weight side is never the constraint. **This unscaled
sum/difference IU4 construction needs A3; exact A4 does not fit these operand forms without
additional encoding or correction** — a second plane, a rescaled sum with its own compensation, or
another representation would be a different scheme, not measured here. So the comparison is
two-sided: seven against eight at A3 for speed at matched numerics, and A3 against A4 for what the
numerics cost.

## Encoding the compiled operands

Seven operands per (row pair, k pair) instead of four blocks. Stored as compiled four-bit codes that
is 896 bytes where the baseline two-bit image holds 256 — a 3.5x weight image, 148.75 MB against
42.50 MB for gate+up. Measured, that is fatal: `seven-i4-compiled-a3` moves bytes at the same rate as
the nibble control and is 2.07x slower than the four-bit nibble control at 256 rows and 2.86x slower than the
offset-code control at the same tiling: 8.26 ms against 3.99 ms and 2.88 ms.

The encoding that works keeps the baseline image and rebuilds the operands in registers:

- store ternary as the **offset code `w+1` in {0,1,2}**, two bits, same layout as the existing map;
- expanding an offset code to a nibble is pure bit spreading, seven instructions per 32-bit half; it
  drops the sign-extension step the signed expansion needs;
- two offset operands add with a **plain 32-bit add** — no nibble can exceed 4, so no carry crosses a
  field. A difference is `0x22222222 - x` then add, one extra instruction;
- the WMMA runs with an **unsigned A operand**, and the constant offset comes back out as a rank-one
  term: adding `c` to every weight adds `c * (column sum of the activation operand)` to every row, so
  one integer per output block per token per 128-block is precomputed and the epilogue subtracts it.

Total: 14 extra vector instructions per k-pair against the four expansions the control already pays,
with **identical weight traffic**. That is the compact compiled block-sum encoding, and it is what
`seven-i4c` measures.

## Measurements

Deployed layer-0 weights, real contextual rows, weights streamed from memory every pass. `t2`/`t4` is
token tiles per wave; `w2`/`w4` is the shared-tile mapping described below. 60 timed calls per
candidate per size at 32–128 rows, 40 at 256, in 10 randomised rounds.

**Seven against eight at matched shape** — same tiling, same weight traffic, same offset storage,
same A3 codes, identical output hash. Baseline `eight-i4o-a3-t2`:

| rows | seven/eight | round bootstrap 95% | rounds won |
| ---: | ---: | --- | --- |
| 32 | **1.132** | 1.123 – 1.142 | 10 / 10 |
| 64 | **1.192** | 1.171 – 1.215 | 10 / 10 |
| 128 | **1.163** | 1.151 – 1.174 | 10 / 10 |
| 256 | **1.205** | 1.184 – 1.227 | 10 / 10 |

**Seven against the fastest eight-product configuration at that size**, paired in the same rounds:

| rows | fastest eight | fastest seven | seven/eight | 95% | rounds won |
| ---: | --- | --- | ---: | --- | --- |
| 32 | `eight-i4o-a3-t2` 0.524 ms | `seven-i4c-a3-t2` 0.440 ms | **1.132** | 1.123 – 1.142 | 10 / 10 |
| 64 | `eight-i4p-a4-t4` 0.623 ms | `seven-i4c-a3-w2` 0.606 ms | **1.038** | 1.022 – 1.051 | 8 / 10 |
| 128 | `eight-i4p-a4-t4` 1.089 ms | `seven-i4c-a3-w4` 1.019 ms | **1.037** | 1.019 – 1.054 | 9 / 10 |
| 256 | `eight-i4o-a3-w4t4` 1.750 ms | `seven-i4c-a3-w4` 2.040 ms | **0.857** | 0.842 – 0.869 | 0 / 10 |

Times are the minimum of the retained samples; the ratios are the paired round statistics, which is
what the comparison rests on. At 32, 64 and 128 rows the seven-product map is the fastest projection
measured here. At 256 the eight-product map wins, and by more than the seven-product map wins
anywhere else.

One saved product is 12.5% of WMMA issue time, and at the IU4 rate of about 6 ns per instruction per
physical SIMD these kernels reach roughly 45% of the issue rate at the shapes above, so a rough
additive estimate puts the arithmetic saving near 6% of the kernel.
That is an estimate, not an upper bound: the saved instruction also frees issue slots that overlap
with the memory work, which is consistent with the matched-shape ratios landing above it. This study
did not separate how much of the matched-shape 1.13–1.21x comes from the removed product, from the
operand construction, from the recombination, or from the different mix of loads and WMMA in the two
loops; those contributions were not isolated.

## What decides the large-batch case: registers

Seven products need seven accumulators per 32 tokens where four suffice — 1.75x the accumulator
registers per token, from [results/seven-registers.txt](results/seven-registers.txt):

| kernel | VGPRs | waves/SIMD | spills |
| --- | ---: | ---: | ---: |
| eight, 2 token tiles | 129 | 10 | 0 |
| eight, 4 token tiles | 233 | 6 | 0 |
| seven compact, 2 token tiles | 178 | 8 | 0 |
| seven compact, 4 token tiles | 256 | 5 | 12 |

The eight-product map reaches four token tiles per wave and halves its weight re-reads; the
seven-product map spills there and is held to two. Giving the control the extra accumulators without
the extra tokens does not help it: `eight-i4os-a3-t2`, which splits the eight products by k-parity
into eight independent chains at the same tiling, runs at 0.78–0.81x the plain control at every size
and loses every round. So the four-tile shape's advantage is not simply more independent chains.

The other way to amortise weight re-reads costs no registers, so both families can use it: give one
row tile to the whole workgroup and one token group to each wave (`w`), so the waves stream the same
weight bytes together. At 256 rows it is worth 1.110x to the eight-product map over its own
four-tile shape (1.097 – 1.125, 10/10 rounds), and that combination is what wins at 256. At 128 rows
the same mapping is a large loss against the same baseline (0.644), so it is size-dependent; it is
reported to [arithmetic](../arithmetic/README.md) as a tiling result independent of this experiment.

## What the A3 requirement costs

Relative RMS of the projection output against an FP32 reference, on the real weights and real rows
(FF = 256 real rows, 128 real tokens, [results/seven-check-layer0.txt](results/seven-check-layer0.txt)):

| map | rel RMS vs FP32 |
| --- | ---: |
| A8 | 0.502% |
| A7, the IU8 seven-product domain | 1.004% |
| A4, the fastest current map | 9.023% |
| A3, the IU4 seven-product domain | 21.098% |

A3 is 2.34x the projection error of A4, one bit as expected, and main's consumer-aware quantisation
study finds no cheap A3 quantiser that recovers it. These are projection-output errors, not FFN
residual errors and not model quality. So the 32-row win is 1.13x for 2.3x the local error, which
this directory does not consider a trade worth taking without a quality result that says otherwise.

The near-exact domain, IU8/A7, was measured only in the compiled-image form, which loses on traffic:
12.00 ms against 3.57 ms for `eight-i8-a8-t2` at 256 rows. The compact offset construction applies to
bytes as well and was not built; IU8 also issues at twice the cost of IU4 on this device, so a
compact seven-product IU8 map would have to overcome that gap before it could compete with the IU4
family here.

No whole-FFN candidate is registered. At 32 rows there is a real 1.13x on the projection and about
1.04x at 64 and 128; at 256 the map loses; and the numerics are strictly worse at every size, so a
registered candidate would currently measure a quality regression for a size-dependent speed
result. If an A3 quantiser with acceptable quality appears, the 32-row case is the one to register
first.

## Limits of this result

- 32 tokens is the smallest batch measured. The token dimension needs two 16-token tiles, so one-
  and eight-token batches would have to be padded to 32, which wastes most of the work; that is an
  efficiency argument against those sizes, not an impossibility.
- The activation operands are seven per (k pair, token pair) rather than four, 1.75x the activation
  image. In the probe they are built on the host like every other map's fragments, untimed. In a
  whole-FFN candidate the producer builds them, and the rank-one corrections with them; both are
  O(tokens × blocks) and were not measured here.
- The recombination cost is fixed per scale block. Sharing one scale across several 128-blocks would
  amortise it, at the error cost [grouped-scales](../grouped-scales/README.md) already measured.
- Only this split, and only the unscaled sum/difference operand form, were measured. Other splits,
  rescaled operands with compensation, or two-plane forms are different schemes.
- Layer 0 only, one document's rows, one device.

## Run

```sh
cd research/ffn/batched/seven-product
make                                          # build/seven_probe
../hardware-run ./build/seven_probe check     # real weights and rows: bit-exactness + error table
../hardware-run ./build/seven_probe check --synthetic
../hardware-run ./build/seven_probe run --rows 256 --iters 40 --rounds 10 \
    --json results/seven-proj-layer0-256.json     # one JSON per batch size
python3 ../bench/paired_analysis.py results/seven-proj-layer0-256.json \
    --baseline eight-i4o-a3-t2 --out results/seven-proj-layer0-256-matched-analysis.json
```

`check` uses the first 256 real rows of the real gate/up matrices and 128 real tokens, which keeps
the CPU reference affordable. `run` uses the full FF = 17408. The compiled seven-product images are
148.75 MB (IU4) and 297.50 MB (IU8), so the probe allocates about 0.6 GB of device memory.
