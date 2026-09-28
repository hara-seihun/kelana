# Response-aware packed pair fitting

Fitting the complete nonlinear response helps the low-rate code at unchanged storage. In the complete Qwen3-0.6B model, a layer-0 three-bit pair replacement improves test perplexity from 120.625 to 110.259 after discrete response fitting. Validation improves too. It still loses to the selected ternary model at 104.212 test perplexity, so we adopt no replacement.

The eight-bit pair gives a different result. Response fitting improves a separate train check but worsens held local response and complete-model loss. A scalar control fitted against the same response improves modestly. These results follow the [weight-fitted full-layer experiment](../vector-full/README.md).

## What is searched

[search.py](search.py) changes actual packed pair indices, keeping the FP16 codebook and every byte count fixed. It does not train a dense replacement or leave a hidden residual. Each index chooses a gate/up coefficient pair. Every scored response contains all 3,072 hidden channels, SiLU, the selected ternary down matrix and all 1,024 output coordinates.

The target is the original BF16 MLP on actual inputs produced by the selected complete ternary model. The candidate keeps the selected ternary down, so it can compensate for that consumer's error as well as gate/up quantization. Other model weights are untouched.

For each hidden row, derivatives of current output error nominate four input columns. The search enumerates every table entry at those columns and computes the exact change in the complete output squared error. If a hidden activation changes by `d` and its down column is `v`, the score change is `2 <E v, d> + ||v||² ||d||²`. This needs no full MLP evaluation per candidate. Each accepted code updates the full residual. Complete responses are recomputed from the actual codes at sweep boundaries. A tiny independent float64 test checks the composed map, monotonic fit loss and preservation of an already exact image.

This is discrete local search, not a global optimum. Each sweep considers one accepted coordinate per hidden row at most. The four-column nomination can miss useful moves and pairwise interactions.

## Train selection and local result

All inputs come from the retained `vector-full/capture/ternary-train-464-4.npz` capture, four public train windows. The first trial fits positions 0–15 of each window and selects on positions 16–31. Two sweeps overfit, so the unchanged eight-bit source wins the train check and is exported bit-identically.

A second trial expands calibration in response to that train-check failure. It fits positions 0–127 of each window, 512 positions, and selects on positions 128–159, 128 positions. The unchanged source and both sweep boundaries compete on this train check. Validation positions 0–31 from each of four separate validation windows are read only after the selected image is exported. No held result selects a checkpoint.

| Image | Changed pair indices | Fit RMS, before → selected | Train-check RMS, before → selected | Held RMS, before → selected |
| --- | ---: | ---: | ---: | ---: |
| Learned eight-bit pair, 64 fit positions | 0 | .45776 → .45776 | .41914 → .41914 | .39728 → .39728 |
| Learned eight-bit pair, 512 fit positions | 3,072 | .41872 → .38506 | .41788 → .41361 | .39728 → .40290 |
| Learned three-bit pair, 512 fit positions | 6,105 | .71231 → .59806 | .71435 → .62376 | .69242 → .61463 |
| Fitted scalar-scale, 512 fit positions | 0, sixteen scales eligible | .51350 → .50174 | .52342 → .50828 | .48186 → .47378 |

The scalar row is a separate [response-fitted scale control](SCALAR.md). It retains every index, optimizes sixteen paid scales against the composed response and scores the actual FP16-rounded export. It is not a matched optimizer-effort comparison. Both methods get the same fit/check text and no extra model bytes. Scalar reports retain its smaller-calibration trial too.

The joint search uses two CPU threads and no GPU. The two large-data sweeps take about 41 seconds for the eight-bit table and 32 seconds for the three-bit table, plus model loading and scoring. It scores all 256 or eight entries per nominated coordinate rather than making that many whole-model forwards. The scalar fit uses a precomputed sixteen-scale projection basis. This is conversion work; no inference timing gain follows from it.

## Complete-model acceptance

All seven arms, including the unchanged selected ternary source, were [frozen together](frozen.json) before gold-token loss evaluation. Only layer-0 gate/up changes. The evaluator decodes the exported images into BF16 and leaves the other 195 matrices unchanged, including the tied embedding/head and layer-0 down. This measures quality, not packed serving speed.

| Whole image | Payload bytes | Validation NLL | Test NLL | Test perplexity |
| --- | ---: | ---: | ---: | ---: |
| Selected ternary source | 128,678,649 | 4.733112 | 4.646432 | 104.212 |
| Eight-bit learned pair, weight fit | 130,468,539 | 4.734665 | 4.635837 | 103.114 |
| Eight-bit learned pair, response fit | 130,468,539 | 4.742142 | 4.637115 | 103.246 |
| Three-bit learned pair, weight fit | 128,501,467 | 4.889163 | 4.792683 | 120.625 |
| Three-bit learned pair, response fit | 128,501,467 | 4.808191 | 4.702836 | 110.259 |
| Paired scalar-scale, weight fit | 130,467,547 | 4.771282 | 4.666629 | 106.339 |
| Paired scalar-scale, response fit | 130,467,547 | 4.764190 | 4.659092 | 105.540 |

Validation contains 2,040 predicted tokens and test 8,160, the unchanged standard panels. The three-bit repair removes about 61% of its weight-fitted test-NLL gap to the selected ternary model, while saving 177,182 bytes from that model. It does not close the remaining gap. The scalar response gain also transfers to both splits. The eight-bit pair repair loses against its own weight-fitted source on both splits.

[results.json](results.json) records local search histories and compact complete-model outcomes with hashes of the full immutable receipts. [scalar-results.json](scalar-results.json) and [scalar-fit128-results.json](scalar-fit128-results.json) retain scalar fitting/selection details. Packed joint exports and source receipts live in `/path/to/workspace/data/kelana-subbit/vector-response/`; scalar exports are in `vector-full/images/`. Whole-model receipts are in `vector-full/model-quality/response-frozen-layer0-*`. Each result names its input capture and source image.

## Reproduction

```bash
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/representations/vector-response
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 "$PY" "$D/search.py" --layer 0 --width 3 --sweeps 2 --columns 4 --train-per-window 128 --check-per-window 32 --name layer00-learned3-response512
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 "$PY" "$D/response-scalar.py" --fit-positions 128 --check-positions 32
```

Existing exports are immutable and commands reject them. Use a new search name for a repeat; scalar reproduction needs an unpopulated destination/report location. Whole-model acceptance uses `../vector-full/model.py evaluate --config "$PWD/$D/frozen.json"` through Bonsai's GPU wrapper. Both panels restored the resident service. No model or runtime was deployed.

The useful result is that exact local response search can repair some low-rate quantization damage without a dense training run. It is not a universal quality improvement, and this candidate has not beaten the selected ternary model.
