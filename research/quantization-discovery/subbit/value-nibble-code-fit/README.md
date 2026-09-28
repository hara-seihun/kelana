# The sixteenth value-cache code is not the missing quality

The shared rank-28 V/O value cache used signed nibbles but clipped them to `[-7,7]`, leaving code `-8` unused. I let a train-only complete-response fit choose between `[-7,7]` and `[-8,7]` for each coordinate, while also adjusting its already-paid FP16 step. The new code needs no extra cache byte or value dot. On the frozen paid Qwen3-0.6B V/O images, its gain is real but small. The one-byte E4M3 cache still wins on both inspected layers.

For each group and coordinate, ten candidates use five FP16-rounded step ratios `.7,.85,1,1.15,1.4` times the preceding response-fitted step and the two lower endpoints. The incumbent is among them. If `R` is the residual of the **complete** two-head post-O response and `D` is one candidate's response change, the train objective changes by exactly `2<R,D> + ||D||²` over real arithmetic. I update `R` after each coordinate. This is a deterministic one-pass conditional choice, not an optimality claim for joint codes, basis or complete-model loss. The head probabilities, factor images and original-producer hidden states are frozen.

Eight WikiText train windows choose the codes. Four previously inspected validation windows score them. Error is squared complete post-O difference from the original V/O teacher divided by its squared norm. The per-window values and selected FP16 steps/endpoints are in the receipts.

| Layer | Train parent → selected | Held parent `[-7,7]` | Held all `[-8,7]` at parent steps | Held selected | Held E4M3 | Selected `-8` coordinates |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .231194 → .230378 | .386631 | .386623 | .386084 | .379186 | 127 / 224 |
| 14 | .195754 → .189812 | .348247 | .348987 | .346759 | .326527 | 145 / 224 |

All eight held windows improve over the parent. The layer-0 window improvements are `.000968,.000317,.000500,.000412`; layer 14 has `.001897,.001548,.000197,.002373`. Using the sixteenth code everywhere without a fitted endpoint mask is essentially a null at layer 0 and loses at layer 14. The remaining E4M3 gaps are `.006899/.020232` at layers 0/14. More endpoint/step sweeps of this fixed basis are poor candidates for native integration. Train the narrow basis and paid O codes together with the four-bit cache on quantized-producer complete-model continuation, then judge fresh loss against E4M3.

The cached coordinate remains one signed nibble: 112 logical or 128 padded bytes per token per layer. The 224 FP16 steps occupy 448 bytes/layer. A literal per-coordinate endpoint mask needs 28 bytes/layer, or 224 bits; producer clipping now selects one of two fixed lower bounds per coordinate, after its division and rounding. The signed-byte direct integer-mass consumer already handles `-8`, so its 448 value-code products/key across both heads do not change. Causal probability/count preparation and the paid O projection also remain. This experiment measures floating-probability CPU replay, not integer-mass rounding, native latency or fresh model loss. It changes neither weight BPW nor Bonsai's executable or service.

The [source](measure.py) loads the frozen paid V/O images and preceding [response-step fit](../value-nibble-response-step/README.md). Model, capture, factor, parent and source hashes accompany every coordinate decision and held-window score in `/path/to/workspace/data/kelana-subbit/value-nibble-code-fit/layer{00,14}-8x4.json`. Reproduce one CPU layer from a Kelana checkout:

```sh
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-nibble-code-fit/measure.py --layer 14
```
