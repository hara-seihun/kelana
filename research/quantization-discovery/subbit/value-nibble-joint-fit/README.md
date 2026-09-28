# Repeated response fitting does not rescue the frozen nibble cache

The previous signed-nibble V cache fit visited each of its 224 coordinates once. That leaves interactions between coordinates and GQA groups unresolved: changing an early coordinate changes the best later choice, and changing the later one can make revisiting the early choice worthwhile. I ran three cyclic passes over the complete two-head post-O response, using ten FP16 step and lower-endpoint candidates per coordinate centered on the previously selected image. This is a stronger fit of the *same frozen rank-28 V/O basis*, not a new representation.

Eight original-producer Qwen3-0.6B WikiText train windows choose candidates. Four previously inspected validation windows score them. The objective is squared post-O difference from original V/O, divided by the teacher response energy. Both heads and all eight GQA groups enter the residual before each decision. Each update evaluates `2<R,D> + ||D||²`, where `D` is the candidate's change to the entire post-O response, then updates `R`. The incumbent is always in the finite set. Each pass therefore cannot increase the train squared error, but three passes do not certify a joint optimum.

| Layer | Train parent → cyclic | Held parent → cyclic | Held E4M3 | Coordinate changes by pass |
| ---: | ---: | ---: | ---: | --- |
| 0 | .230378 → .230284 | .386084 → .386194 | .379186 | 30, 1, 0 |
| 14 | .189812 → .187486 | .346759 → .345965 | .326527 | 77, 39, 36 |

Layer 0 loses on three of four held windows, despite reaching a coordinate-wise fixed point in this ten-candidate grammar after the third pass. Layer 14 improves on three windows, yet still trails E4M3 by .019438 in relative error, compared with .020232 before the extra fit. Its third pass still moves 36 coordinates, so these numbers do not bound what a different optimizer or basis might achieve. They do show that the first-pass stopping rule alone did not cause the frozen nibble image's large layer-14 quality gap. Another pass over its steps is a poor next experiment. Change the rank-28 basis and paid O codes while fitting the cache on quantized-producer complete-model continuation, then check fresh model loss before native lowering.

The cached value stays 112 logical / 128 padded bytes per token per layer; the 224 FP16 steps are 448 bytes/layer, and the literal lower-endpoint mask is 28 bytes/layer. Producer quantization, 448 nibble products per key across heads, floating-probability attention and the paid O factor have the same online cost as the parent. The E4M3 comparison uses 224 logical / 256 padded cache bytes. These CPU results neither price native inference nor test integer-mass rounding or quantized-producer model quality.

[The replay](measure.py) writes source, model, capture, factor and parent hashes, every coordinate move and per-window errors to `/path/to/workspace/data/kelana-subbit/value-nibble-joint-fit/layer{00,14}-8x4.json`. Run one layer from a Kelana checkout:

```sh
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-nibble-joint-fit/measure.py --layer 14
```
