# Ridge-seeded paid layer-0 value decoder

Can a better continuous causal decoder improve the existing 192-coordinate, two-bit narrow V/O image when it is rounded into the *same* paid left-code and FP16 scale slots? On the frozen original-producer layer-0 capture, yes, but only after refitting the rounded signs against the actual causal response. Direct rounding loses.

I kept the train-selected unequal ranks `[28,28,28,28,28,4,28,20]`, all eight two-bit right factors, their scales, Q/K, and the causal observation fixed. There are 384 attended features across both query heads. The target is the original layer-0 post-O output on eight 256-token train windows. Eight leave-one-train-window-out fits selected ridge penalty `0.1` times the mean diagonal of the feature Gram from the fixed grid `0.0001, 0.001, 0.01, 0.1, 1`. No validation row entered selection. The real ridge solution was quantized row by row into the existing two-bit odd-signed output codes and FP16 scales. I then gave that image two train-only coordinate/scale sweeps, the same number used by the preceding paid image. Each code update minimizes the train squared error conditionally on the other stored codes and scales; FP16 scales are refitted per output row and head.

| Decoder | Train relative post-O squared error | Four-window held error |
| --- | ---: | ---: |
| Existing two-sweep paid image | .233558 | .385779 |
| Real ridge decoder, not a paid image | .194567 | .341205 |
| Ridge rounded directly to paid slots | .288764 | .421650 |
| Ridge seed plus two paid-code sweeps | **.221616** | **.381749** |

The final image improves each held window, with error `[.37111,.40809,.35281,.39390]` against `[.37394,.41510,.35351,.39935]`. It changes the paid left codes and row/head scales, not the right factor, group ranks or metadata. The eight-group V/O image remains **183,552 parameter bytes, .466797 BPW**, with **589,824 signed factor terms/token** and a **384-byte logical BF16 value cache/token**. No dense decoder is required online. The continuous gain of .04457 held error mostly vanishes on direct rounding; this experiment establishes a better *initializer* for a fixed-rate causal code fit, not a new rank floor or a native speedup.

This is original-producer causal-output quality on four previously inspected validation windows. It is not gold loss, quantized-producer behavior or native timing. The preceding equal-rate uniform-24 two-sweep control scored .407794 on these captures. The next decision is a frozen one-layer gold-loss replay on disjoint text, followed by refitting the same paid codes with a viable quantized producer before considering this image for a native cache layout. Do not choose a runtime from the .00403 response-error improvement alone; earlier rank allocation reversed on fresh validation loss.

`layer0_ridge.py` generates `/path/to/workspace/data/kelana-subbit/value-observer/layer00-causal-ridge.json` and its `.npz` image. The receipt contains all eight selection-fold errors, per-window train and held scores, source, model, capture and initial/final image SHA256 hashes. The final image SHA256 is `1cc3f7eeeac919ffa038d9bb61f7979dec254a8d413d499fd05a446e4ff81bc7`. To reproduce from Kelana:

```sh
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-observer/layer0_ridge.py
```

No GPU, Bonsai executable or resident service changed.
