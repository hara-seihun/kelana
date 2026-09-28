# Coarse FFN activations

The target is to remove an activation plane from the paired arithmetic map. This directory measures the behavior cost; the arithmetic worker owns its batched speed measurement. No model-quality threshold has been accepted.

## Native model result

[quality-layer-sweep.json](quality-layer-sweep.json) scores every next-token distribution at 128 positions from two 64-token prompts. The model runs all 64 layers, including attention and recurrent state. Each configuration receives the same teacher-forced tokens. The changed operation is FFN input quantization only; down-projection activations remain A8.

For A4, `q4 = round(q8 * 7/127)` and the block scale is multiplied by `127/7`. Preparation recomputes block sums. A6 uses 31 instead of 7. The integer nearest-rounding formula has no half ties. Stochastic rounding selects adjacent codes using a seeded 32-bit hash; this implementation is not a source of mathematically independent random variables.

| Changed first layers | Input codes | Mean KL, reference to candidate | Mean total variation | Changed argmax |
|---:|---|---:|---:|---:|
| 0, repeat control | A8 | 0 | 0 | 0/128 |
| 1 | A4 nearest | 0.0001775 | 0.00628 | 1/128 |
| 8 | A4 nearest | 0.0004783 | 0.01026 | 1/128 |
| 32 | A4 nearest | 0.002502 | 0.02298 | 5/128 |
| 64 | A4 nearest | 0.008679 | 0.04391 | 10/128 |
| 64 | A6 nearest | 0.0007051 | 0.01262 | 3/128 |
| 64 | A4 stochastic | 0.01801 | 0.06318 | 8/128 |

Error grows as more layers change. These results do not establish cancellation, long-context stability, or task accuracy. The mean next-token NLL change for A4 nearest is -0.00732 on these positions; that small sample is not evidence of a model improvement. The prompts are separate from the quick-brown-fox local calibration data. Further tuning against these results makes them development data, not a fresh acceptance set.

`quality.hip` intercepts FFN preparation calls while including the unchanged Bonsai row kernel. Production files are untouched. Per-layer counters assert the number of modified chunks. `quality.cpp` computes full-vocabulary KL, total variation, target NLL changes and argmax changes. The repeat control has zero maximum logit difference at every position. This intervention program measures behavior, not inference speed.

Run from the repository root:

```sh
python3 research/ffn/batched/lossy/run_quality.py --tokens 64 \
  --out research/ffn/batched/lossy/quality-layer-sweep.json
```

The runner builds, takes the shared research GPU lock and records source, linked-object and binary hashes. It returns 75 when another researcher holds the lock. Model paths, sizes and modification times are recorded, not claimed as content hashes. Configurations are `bits:first_layers:stochastic`, comma separated via `--configs`. An optional fourth `consumer` field selects the [packed-half polynomial intervention](../consumer-polynomial/README.md). `--reference CONFIG` chooses a matched approximation as the reference; the default remains `8:0:0:0`.

## Direct quantization at both FFN boundaries

The arithmetic candidate rounds the transformed float directly, rather than first committing to an A8 grid. [quality-direct-both.json](quality-direct-both.json) measures that quantizer at both the gate/up input and the down input. All 64 layers are modified, using the same 128 scored positions:

| Codes | Mean KL | Mean total variation | Changed argmax | Mean target NLL change |
|---|---:|---:|---:|---:|
| A4 nearest | 0.01598 | 0.06082 | 14/128 | +0.01495 |
| A6 nearest | 0.0007917 | 0.01343 | 3/128 | -0.00495 |

The repeat A8 control is again identical. For A4, modifying the first 1, 8 and 32 layers gives mean KL 0.0001919, 0.0006232 and 0.004587. These configurations accumulate error rather than cancel it.

```sh
python3 research/ffn/batched/lossy/run_quality.py --tokens 64 --direct --down \
  --configs 8:0:0,4:1:0,4:8:0,4:32:0,4:64:0,6:64:0 \
  --out research/ffn/batched/lossy/quality-direct-both.json
```

`--direct` reads the transformed floats still resident in the deployed producer's shared memory, then requantizes with `amax/limit`. `--down` also changes the hidden-activation quantizer. This matches the candidate's quantizer formula, not its changed matrix-reduction order. The full-model run retains deployed projections; it is not a full-model run of the new batched kernel.

The [arithmetic measurements](../arithmetic/README.md) give a 1.27 to 1.47x whole-FFN gain for A4 against that worker's otherwise matched batched IU8/A8 control. Native IU4 provides a similar speed rung with integer accumulation. Those are FFN timings, not full-model inference timings. Quality and speed are separate measurements, with no accepted combined threshold yet.

## Going coarser has a sharp quality cost

[quality-direct-coarse.json](quality-direct-coarse.json) keeps the direct quantizer at both FFN boundaries. A2 means the three values `{-1,0,1}` times a block scale, not four equally used codes.

| Codes / changed first layers | Mean KL | Mean total variation | Changed argmax |
|---|---:|---:|---:|
| A2 / 1 | 0.005726 | 0.02849 | 3/128 |
| A2 / 8 | 0.1635 | 0.1849 | 26/128 |
| A2 / 32 | 1.211 | 0.5267 | 66/128 |
| A2 / 64 | 3.809 | 0.8212 | 104/128 |
| A3 / 64 | 0.09866 | 0.1507 | 25/128 |

Naive ternary activations across this model do not retain its behavior. The three-way hardware-packing investigation remains an arithmetic experiment, not an accepted model optimization. [`TriplePacking.lean`](../../../../Kelana/TriplePacking.lean) proves the integer packing `a+33*b+1089*c`, exact recovery for low channels in `[-16,16]`, and dot-product composition. Ternary packed operands stay within `[-1123,1123]`; three bounded sums stay within `[-17968,17968]`. Native floating WMMA error and total cost are separate obligations.

## Local perturbation model

[probe.py](probe.py) follows a complete FFN using actual layer weights and native gate/up outputs as anchors. It propagates perturbations in float64 through SiLU, signs, Hadamard, hidden quantization and down projection. It is not the native implementation. Its baseline hidden codes differ from the captured native reference at 2 positions in layer 0 and 1 in layer 10.

[layer00.json](layer00.json) and [layer10.json](layer10.json) contain 32 stochastic trials. A4 nearest yields activation RMS error of 11.35% and 11.79%, but residual-output RMS error of 1.00% and 1.55%. This attenuation at isolated residual outputs does not imply cancellation across the model. Stochastic rounding raises per-run output error and exhibits downstream bias.

[clipping-layer00.json](clipping-layer00.json) and [clipping-layer10.json](clipping-layer10.json) explore sacrificing activation extremes for a finer A4 step. A max-range fraction of 0.9 reduces local output error modestly. More clipping lowers activation RMS error while sometimes raising FFN output error, so input reconstruction error alone is the wrong objective. Native clipping quality has not been measured. The smaller `*-pilot.json` files are initial checks, not additional independent evidence.

## Consumer-aware representations

[Consumer geometry](consumer-geometry.md) studies correlated errors that the down projection cannot see. It gives a general real-arithmetic endpoint theorem, a Lean-checked three-coordinate example, and exact modular rank certificates showing that the large global nullspace is not available inside the sampled 128-coordinate scale groups.

## Proof boundary

[`Kelana/Approximation.lean`](../../../../Kelana/Approximation.lean) proves adjacent stochastic-rounding mean/energy identities, its variance bound, examples where nonlinearities create bias, and a zero-mean error whose energy quadruples at every layer. It also exhibits the difference between independent and coherent accumulation. These are exact integer identities; none is a model-specific stability proof or a correctness proof for the GPU random generator.
