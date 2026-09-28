# Post-O selection of frozen signed-nibble value codes

The frozen rank-28 shared V/O image has two already-paid signed-nibble cache fits per coordinate: raw and train-mean-centered. The earlier cache study chose between them by coordinate reconstruction MSE. That selection actually worsened layer-14 held causal post-O error from .365386 to .371962. I asked whether selecting these same stored coordinates against the complete two-head O response could rescue the half-byte cache without changing its rate or online program.

For group `g`, coordinate `i`, let `d_t` be centered decoded cache value minus raw decoded cache value at key `t`. Its complete response difference is

`D_{g,i}(q) = sum_{h=0}^1 [sum_{t<=q} p_{q,h,t} d_t] L_{g,h,:,i}`.

Here `L` is the *paid* decoded output factor. No individual value or head-output target needs to be reconstructed for this selector. Given the current full post-O residual `R`, toggling this coordinate changes its squared error by exactly `2 <R,D> + ||D||²`. A deterministic one-pass coordinate descent accepts negative changes and updates `R`. This identity holds for the floating-probability CPU replay of the frozen factors and FP16-rounded cache metadata; it is not a claim about bit-identical floating execution or about the separate integer probability map. The source evaluates the response of both heads together and keeps all other groups in `R` while deciding each toggle.

Eight original-producer 256-token train windows select codes. Four previously inspected validation windows measure the chosen image; both layers use the same frozen paid V/O factor and metadata as the preceding cache study. The [source](measure.py) records source/model/capture/image/metadata hashes, every toggle and every per-window error under `/path/to/workspace/data/kelana-subbit/value-cache-post-o-select/`. All scores are squared post-O error relative to the original V/O teacher, with the same denominator per layer.

| Layer | Centered choices / 224 | Train raw → selected | Held raw | Held MSE-selected | Held post-O-selected | Held E4M3 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 121 | .232400 → .231070 | .386704 | .385731 | .385921 | .379186 |
| 14 | 105 | .214402 → .202801 | .365386 | .371962 | .356487 | .326527 |

All four held layer-14 windows improve against raw: .368484→.355393, .411860→.401234, .324682→.317177, .359515→.354552. Layer 0 improves against raw but loses to the MSE-selected mix and to E4M3. At layer 14 the full-response objective does repair the harmful MSE center selection and buys .008899 over the best raw arm, but **still loses .029960 to the one-byte E4M3 cache**. A two-train/two-held layer-0 diagnostic is also retained, with its distinct window count, rather than replacing the 8x4 result.

This selector changes only offline code assignment. The weight image stays at the frozen .53060 V/O BPW, the value cache remains 112 logical or 128 padded bytes/token/layer, and the charged FP16 center/step metadata stays 896 bytes/layer. The code producer still subtracts center, divides by step, rounds and clamps each of 224 coordinates, and the direct signed-nibble consumer still spends its full count preparation and nibble dots. It does **not** buy an online speedup or close the value-quality gap. A model-level decision also needs fresh quantized-producer text and a native consumer. No GPU, executable or service changed.

The next quality experiment should change the *code values or shared basis* under this complete response objective, not run more selectors over the two frozen options. In particular, optimize per-coordinate step/center candidates and paid O codes on quantized-producer train continuation, and compare E4M3 and equal-rate controls on fresh complete-model loss before spending native work on the half-byte cache. Selecting frozen centers alone leaves a measurable floor above E4M3 in both layers.

From a Kelana checkout, each layer runs as a bounded CPU command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-cache-post-o-select/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-cache-post-o-select/measure.py --layer 14
```
