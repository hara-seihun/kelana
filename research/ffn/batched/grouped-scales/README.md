# Grouped scales: deleting the per-128 epilogue

**Answer: it works, and it is worth about 7% on the whole FFN at 256 rows, not a factor.** A joint
scale over eight adjacent 128-blocks lets the WMMA integer accumulator run 1024 columns of K
instead of 128, and the per-128 convert-and-scale epilogue disappears with it. Deleting that
per-block scale correction in a more approximate ablation reduced time by **12.9% at 256 rows**. That is an observed implementation, not a lower bound on runtime or an upper bound on other grouped-scale maps. Retaining a fitted approximation to the per-block scales, by
folding an integer multiplier into the int4 matrix operand, costs about half of the saving back and
lands at **7.2% faster than the matched control for 7.6% more relative RMS error**.

The same construction on IU8 is a **loss**: there the operand has enough range that the scale is
nearly exact, but the wider decode costs more than the epilogue it removes.

All numbers are whole-FFN, native, on 256 real contextual rows of
`/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00`, through
[`../bench`](../bench/README.md), against the residual the deployed engine produced for those rows.

## What has to be true to delete the epilogue

The deployed representation carries an FP16 weight scale per (row, 128-block) and an FP32
activation scale per (token, 128-block). So

```
y[i,j] = sum_b lam[i,b] * c[j,b] * (sum_{k in block b} t[i,k] * q[j,k])
```

and the int32 accumulator has to be read out, converted and scaled every 128 columns even though
nothing about the hardware forces the chain to break there. Extending the accumulation over G
adjacent blocks needs both scales constant across the group, which costs something on each side:

- **activation**: one amax per (token, `G*128`) instead of per (token, 128). This requires no additional activation plane; the changed reduction is included in kernel timing. It adds quantisation error where a block's own amax was smaller than its group's.
- **weight**: `lam[i,b] -> L[i,g] * m[i,b]` with `m` a positive integer riding inside the matrix
  operand, so the accumulation still sees one scale. The operand width caps `m`, and that cap
  *is* the scale resolution: **7 for IU4, 127 for IU8**.

Offline weight fitting is free; the activation grouping is a producer change inside `run`.

## The operand width is the binding constraint on the weight side

The real scales inside a 1024-block are close but not equal — mean max/min spread 1.21, p99 1.39,
max 1.61 ([`scale_fit.py`](scale_fit.py), all three FFN matrices of layer 0, from the HALO tiles).
Fitting them with `L * m` and integer `m`:

| group | spread mean | `m <= 7` (IU4) | `m <= 15` | `m <= 127` (IU8) | one shared scale, no `m` |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2 blocks (256) | 1.087 | 2.15% | 0.84% | 0.090% | 4.67% |
| 4 blocks (512) | 1.146 | 3.08% | 1.32% | 0.145% | 5.73% |
| 8 blocks (1024) | 1.207 | 3.69% | 1.64% | 0.182% | 6.20% |

(relative RMS of the fitted scale against the deployed one, 2048 sampled rows per matrix)

Three bits of multiplier over ratios that live in [0.63, 1] is coarse, and no cleverness inside
this family fixes it: the ratio grid available from `m1/m2` with both `<= 7` has a gap from 1 to
7/6, so a 1.08 ratio is unrepresentable however the pair is chosen. Independent per-weight dithering would introduce additional noise. Coordinated, consumer-aware multiplier choices are a different construction and are not ruled out by this grid argument.

What saves this is not the weight side. **A 3.69% weight-scale perturbation moves the FFN output by
0.37%**, because it perturbs each block's partial sum multiplicatively and those errors partly
cancel within a row, and because the FFN output is dominated by the residual it is added to. The
activation grouping, by contrast, moves it by 0.62%. The cheap-looking half is the expensive one.

## Measured, whole FFN

Minimum of three repetitions per candidate, rotating order, milliseconds. The resident
`bonsai-halo` server shares the device and inflates medians by up to 30% at random, so the table
reports `ms_min`; full samples and medians are in
[`results/gs-layer0.json`](results/gs-layer0.json).

| rows | 32 | 64 | 128 | 256 | rel RMS vs engine (256) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `gs-control-iu4-a4` (matched control) | 0.902 | 0.965 | 1.550 | 3.006 | 0.965% |
| `gs-act1024-iu4-a4` (activation grouping alone) | 0.915 | 0.988 | 1.619 | 2.969 | 1.145% |
| `gs-shared1024-iu4-a4` (shared-scale ablation, no per-block correction) | 0.840 | 0.906 | 1.394 | **2.618** | 1.304% |
| `gs-absorb1024-iu4-a4` | 0.884 | 0.933 | 1.451 | 2.792 | 1.202% |
| `gs-absorb1024-iu4-a4-clip800` | 0.876 | 0.926 | 1.443 | **2.791** | **1.038%** |
| `gs-absorb512-iu4-a4` | 0.868 | 0.953 | 1.458 | 2.811 | 1.125% |
| `gs-absorb256-iu4-a4-clip875` | 0.900 | 0.992 | 1.542 | 3.009 | 0.977% |
| `gs-control-iu8-a8` | 1.007 | 1.270 | 2.168 | 4.214 | 0.012% |
| `gs-absorb1024-iu8-a8` | 1.087 | 1.371 | 2.402 | 4.635 | 0.080% |
| `arith-paired-a4` (previous best in the family) | 0.856 | 0.954 | 1.481 | 3.099 | 0.965% |

Reading it:

- **The shared-scale ablation saves about 13% here.** It drops per-block scale information and seven eighths of the scale epilogues. This does not prove a ceiling, price the remaining epilogues independently, or rule out larger groups and different schedules.
- **The int4 multiplier gives back part of the saving.** `gs-absorb1024` takes 6.6% longer than the shared-scale ablation. One
  `v_mul_lo_u32` per 16 weights per matrix per K-slice is a quarter-rate instruction and it is paid
  on every block whether or not the group is long, which is exactly why `gs-absorb256` (G=2, half
  the epilogue removed, the same multiplier cost) shows no gain at all.
- **The trade at 256 rows is 7.2% for 7.6%.** `gs-absorb1024-iu4-a4-clip800` against the matched
  control: 2.791 vs 3.006 ms, 1.038% vs 0.965% relative RMS, bias 1.6e-6 against 1.7e-7, worst row
  2.16% against 2.06%. Against the previous best whole-FFN candidate, `arith-paired-a4`, it is 9.9%
  faster at 256 rows and slower at 32.
- **The tested near-control-error setting does not win.** `gs-absorb256-iu4-a4-clip875` reaches 0.977% versus the control's 0.965%, at essentially the same measured time. This is not a complete matched-error frontier.
- **IU8 is a negative result.** Its operand has the resolution — 0.182% scale error, 0.080% at the
  FFN output — but `expand_i8_m` costs more per weight than the epilogue it deletes, so the
  candidate is 10% *slower* than its own control at every batch size. Accurate joint scales are
  available on the rung that was already the wrong rung.
- The gain is concentrated in the down projection (K = 17408, 136 blocks, so more epilogues per
  output element): at 256 rows its stage drops 14.7% against the control's 1.174 ms while gate/up
  drops 7.0% (`KELANA_GS_STAGES=1`, which synchronises between stages).

## The quantiser step matters more than the scale grouping

A group amax is a max over 1024 samples rather than 128, so it sits further out in the tail and the
deployed `amax/7` step is longer than it should be. Shortening it recovers most of the grouping's
error:

| activation quantiser | per-128 | per-1024 |
| --- | ---: | ---: |
| step `amax/7` (deployed) | 11.10% | 13.26% |
| step at its own best factor | 10.27% (0.875) | 10.82% (0.750) |

(relative RMS of the four-bit quantiser on the real FFN input of all 256 rows, `scale_fit.py act`)

End to end the picture is not identical, because clipping's error passes through SiLU differently:
shortening the step helps the grouped candidate (1.202% -> 1.038% at factor 0.800) and *hurts* the
per-128 control (0.965% -> 0.988% at 0.875). Factor 0.700 overshoots badly (1.400%). This is a knob
on the shipped quantiser rather than a property of grouping, and it belongs to main's error
contract; it is here because without it the grouped candidate's error looks 25% worse instead of
7.6% worse, and that difference decides whether the trade is worth anything.

## Also measured: the scale layout, worth 3%

`gs-control-iu4-a4-rowscales` is the control with weight scales indexed `[row][block]`, the layout
[`../arithmetic/candidates/arith_maps.hip`](../arithmetic/candidates/arith_maps.hip) shipped with,
and everything else identical: 3.086 vs 3.001 ms at 256 rows, same error to the last digit, and the
gap held in all three repetitions. Tile-major `[tile][block][16]` puts the 16 scales a wave needs
for one block in 32 contiguous bytes instead of 16 dwords spread over 1280.

That edit is **already applied** to `arith_maps.hip` in this branch, so `arith-iu4-a4`,
`arith-iu8-a8` and the `-down8` variants pick it up with no numerical change. It does not touch the
paired maps, which already carry their scales inside the block image.

A first measurement of this looked like a 28% win; it was contention from the resident server
between two runs, not the layout. Comparisons here are min-of-three within rotating order for that
reason, and single-run candidate-to-candidate differences under about 5% on this machine should not
be believed.

Main's replacement driver now randomizes warmed candidate blocks within timing rounds and records clock, temperature, power and visible GPU clients. [Interleaved results](../bench/MEASUREMENT.md) reproduce the grouped candidate's advantage: 1.063x and 1.078x on two layer-0 runs, 1.083x on layer 10 at 256 rows. All samples are retained. The exact scale-layout change also reproduces at about 1.028x, with identical output hashes.

These are observed relative performance results under the recorded shared-machine conditions. Full-model quality acceptance remains separate. Neither a large measured difference nor a small bootstrap interval eliminates all environmental confounds.

## What this does not answer

The projections still re-read the weight stream once per token group, which is the other half of
the gap to the instruction rate and is untouched here — two-level tiling with LDS staging is a
different question and was deliberately left alone.

Whether 1.038% instead of 0.965% is affordable is not a question this directory can answer. It is a
7.6% increase in relative RMS on one layer with the bias still at 1.6e-6; logit divergence and
held-out loss across layers belong to [`../lossy`](../lossy/README.md) and to main's full-model
evaluation.

## Run

```sh
cd research/ffn/batched/grouped-scales
python3 scale_fit.py weights        # -> results/scale-fit-weights.json, the fit table above
python3 scale_fit.py act            # -> results/scale-fit-act.json, the quantiser table above

cd ../bench && make build/batch-bench
../hardware-run ./build/batch-bench --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
    --rows 32,64,128,256 --iters 40 --warmup 12 --candidate all \
    --json ../grouped-scales/results/gs-layer0.json
```

`KELANA_GS_STAGES=1` prints the four per-stage times to stderr and synchronises between stages, so
leave it unset for a timed run. All candidates live in
[`candidates/gs_maps.hip`](candidates/gs_maps.hip); the mode names in this README are its `Mode`
enum.
