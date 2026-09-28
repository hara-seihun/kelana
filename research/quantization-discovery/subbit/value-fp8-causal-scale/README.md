# Causal scale selection for the one-byte narrow value cache

One E4M3 scale per GQA group is already paid in the narrow V cache image. Selecting that scale against the complete two-head causal output rather than coordinate reconstruction improves the training response, but barely moves held layer 0 and reverses on held layer 14. The precision is not the main source of the paid V/O image's error. A native reader should use the simpler coordinate-MSE scale until new producer and decoder labels justify a different choice.

## Conditional construction

Keep the rank-28, two-bit V/O factors, BF16 narrow producer, original Q/K probabilities, E4M3 format, and one FP16 scale per group fixed. Each group's scale is drawn from the same sixteen percentile-derived candidates as the [one-byte cache study](../value-fp8-cache/README.md). For a candidate scale `s_g`, let `C_g(s_g)` be the **sum of both heads'** full 1,024-coordinate output responses over every causal query. The objective is `||teacher - Σ_g C_g(s_g)||²`, with the original dense V/O response as teacher. Unlike coordinate MSE, this accounts for the decoder, head attention, and interference among GQA groups.

Starting from eight coordinate-MSE choices, visit the eight groups twice. With other groups fixed, evaluating all sixteen candidates and choosing the smallest complete residual squared norm is the exact conditional optimum in this finite grammar. The resulting two-sweep image is not a global optimum over `16^8` joint choices. Candidate attention, group decoders, and teacher outputs are computed offline. The online program remains one E4M3 conversion per coordinate at append, the same cache-byte reads and narrow post-O work; only eight existing FP16 scale constants change. Neither candidate fitting nor teacher inference is counted as online work.

The eight 256-token original-producer training windows fit the scales. Four distinct, previously inspected validation windows measure held error. Both arms have the same candidate set, factor image, train inputs, held inputs and reader. A separate two-sweep fit **on validation** diagnoses available capacity, but cannot select a deployable image or certify a global bound.

| Layer | Train relative squared error, coordinate → causal | Held BF16 | Held coordinate → causal | Held-fitted diagnostic |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .22320946 → .22310700 | .37888697 | .37918583 → .37917539 | .37905654 |
| 14 | .16451949 → .16448635 | .32619494 | .32652724 → .32653087 | .32599509 |

Layer 0 improves three of four individual held windows, but its aggregate improvement is only .00001043 relative squared error. Layer 14 improves two windows and loses in aggregate by .00000364. The layer-14 held-only fit's .00053215 advantage over the coordinate scale shows that this candidate set contains useful changes **for these held observations**; the train objective does not select them. Even that diagnostic is small against the paid BF16 response error .32619, and cannot establish generalization. The E4M3-over-BF16 error is .00029886/.00033230 in the coordinate arm at layers 0/14. Paying another offline fit for the same frozen codes is not a path to fixing their much larger approximation error.

This is a CPU original-producer post-O result, not whole-model NLL, native time or a changed Bonsai executable. There is no bit-identity assertion: E4M3 rounding deliberately changes the map. The frozen image still stores 208,640 V/O bytes per layer, while the E4M3 value cache uses 224 logical bytes/token or eight 32-byte group slots, with sixteen existing FP16 scale bytes/layer. Actual conversion latency and cache traffic remain unpaid. The next worthwhile quality question is jointly training the narrow V producer codes and both O consumers on broader quantized-producer text, then checking fresh language loss. This static-cache-scale selection should not precede it.

## Reproduce and custody

From the Kelana root, each layer finishes in one CPU command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-fp8-causal-scale/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-fp8-causal-scale/measure.py --layer 14
```

`/path/to/workspace/data/kelana-subbit/value-fp8-causal-scale/layer{00,14}.json` retains source, parent source, paid image, capture, model and pinned revision hashes; all sixteen scale values per group, train/held choices, each fit sweep and per-window scores. The code replays the published BF16 and coordinate-MSE controls; its scores match the earlier cache study. No GPU reservation or service change was needed.
