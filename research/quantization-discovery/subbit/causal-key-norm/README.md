# A causal denominator fit recovers most of the paid sparse-key score

A 224-coordinate RoPE score cache is not a 224-row K producer while the key RMSNorm still reads all 1,024 raw rows. I kept the latest paid binary Q/K planes and 448-byte BF16 group affine fixed, and asked whether a small number of extra raw binary-factor K rows can supply the denominator without throwing away the causal-score gain. On the pinned Qwen3-0.6B layer-0 and layer-14 original-producer captures, a train-only positive five-coefficient denominator using 16 extra rows per group nearly reaches the full-K norm. This is a measured CPU causal-score construction, not a whole-model or native result.

| Layer, held two-head causal KL | Full K norm | Selected-only causal fit | 16 sampled rows, unfit | 16 sampled rows, causal fit | 32 sampled rows, causal fit |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | .260143 | .271879 | .302857 | **.262074** | .262347 |
| 14 | .338360 | .481935 | .441346 | **.349021** | .343998 |

The layer-14 improvement over the same sampled rows with unit weights is .092325 KL for 16 rows. All four held windows improve; their full/16-fit means are `.325117/.342288`, `.343474/.348397`, `.323470/.332732`, `.361381/.372668`. The 32-row fit gives another .005023 KL, but needs twice as many extra signed terms. Layer 0's 16-row fit is within .001931 KL of its full-denominator arm. These four validation windows have already been inspected in related studies, so the next selection must freeze the sparse image and move to fresh quantized-upstream text. The result is a new rate/compute point within a fixed original-hidden observer, not evidence that the model now speaks well.

## The map and what the fit changes

The pinned paid K factor has a 256-coordinate common input factor and a binary output factor with 1,024 raw rows per layer. Each GQA group retains the already chosen whole RoPE planes, together 224 raw selected rows. For each group I draw either 16 or 32 additional rows from the omitted 100 or so, with a fixed-seed energy-stratified four-bin sample. Sampling is identical in the unit-weight and fitted arms. Let `e0` be the sum of selected raw BF16 squared values divided by 128. For bin `j`, let `ej` be its sampled squared-energy sum multiplied by the stratum population/sample-count ratio, then divided by 128. The new denominator is `d = a0 e0 + sum(a_j e_j)` with all five coefficients in `[.05, 4]`. This is positive for nonzero keys and homogeneous in the raw projection. The score path normalizes *only* the selected raw coordinates, rounds them to BF16, multiplies by the existing BF16 group affine, rotates the retained planes and scores both paid Q heads against every causal key. It does not reconstruct omitted K output coordinates.

Eight train windows and sixteen strided causal query positions per window fit five continuous coefficients per group by finite teacher-to-candidate causal cross-entropy with a `.001 ||a-1||²` penalty. The fit uses a smooth FP32 surrogate for the key normalization, because differentiation through BF16 rounding has zero gradient almost everywhere. It rounds the fitted coefficients to FP16, then evaluates the BF16 normalization and the complete causal 256-key observation on four separate held windows. The teacher uses original Q/K, the candidate uses the pinned paid binary Q/K and the latest paid plane/affine allocation. No held score selects coefficients or row lists. The finite objective is nonlinear in the denominator coefficients; the bounded L-BFGS-B result is not a global optimum.

The denominator's own RMS relative error does not order the observer. At layer 14, 32 sampled rows move from `.125598` to `.129076` relative denominator RMS under causal fitting while causal KL falls `.370193` to `.343998`. Optimizing energy alone selects the wrong map. A selected-only train energy fit scores `.569061` against `.481935` for its same-rate causal fit; even that cannot replace the few extra raw rows at layer 14.

## Paid online boundary

With 16 extras per group, K emits 352 rather than 1,024 raw rows per layer: 90,112 rather than 262,144 output-factor signed terms per token. The common 262,144 signed input terms still run, so total factor terms fall from 524,288 to 352,256, a 32.81% count reduction. At 32 extras, 480 rows cost 122,880 output terms and 385,024 total, a 26.56% reduction. The selected score still keeps 224 BF16 key coordinates and spends 448 products per causal key across both heads. The per-token norm also squares and reduces either 352 or 480 BF16 raw values; those operations and the paid 448-byte group affine remain. If the full binary K output factor is physically pruned to these rows, its one-bit signs fall from 32,768 to 11,264 or 15,360 bytes per layer, before scales and packing. Row indices cost 128/256 bytes per layer as uint8 values; five FP16 coefficients for each of eight groups add 80 bytes. The resulting sign-plus-new-metadata saving is 21,296/17,072 bytes per layer. The current full K image was **not** pruned or timed; these are executable-program work and storage counts, not a native speedup. The sampled rows have irregular output addresses and the selected mask already has its own prior cost. A native producer must lay the 352 or 480 rows directly in the packed factor image and price norm reduction, cache writes, packing and score traversal, rather than materialize full K then discard most of it.

The guarantee here is positivity and the counted finite observer, not exact normalization on every possible input. A full real quadratic in 256 factor coordinates cannot reproduce the BF16-rounded norm either, and [the dense exact-rank bound](../key-gram-sketch/README.md) charges at least 800 forms for omitted rows in its restricted grammar. The sparse map spends signed rows that can be shared with the selected producer, and trains the actual observing heads rather than missing-energy squared error.

## Evidence and next experiment

`measure.py` runs one group per CPU command; `summarize.py` checks all eight group identities and aggregates their four held windows. `/path/to/workspace/data/kelana-subbit/causal-key-norm/layer{00,14}-group{0..7}.json` hold every row index, coefficient, train objective, held per-window KL, denominator error and source/model/capture/paid-image/parent hashes. The `layer{00,14}-summary.json` files hash those group receipts. Reproduce a group and aggregate from the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/causal-key-norm
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 14 --group 0 --output /path/to/workspace/data/kelana-subbit/causal-key-norm/layer14-group0.json
python3 "$D/summarize.py" --layer 14
```

Fit the 16-row image and an equal-paid-rate binary control against quantized-producer causal/post-O behavior on disjoint train text, freeze them, then evaluate fresh gold loss. If the held observer survives, directly consume the pruned packed K output and norm on gfx1151; count the irregular row gather and score/cache boundary. CPU only in this turn; Bonsai executable, GPU service and serving defaults did not change.
