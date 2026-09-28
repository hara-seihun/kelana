# The static nibble value cache loses its quality margin

The shared rank-28 V/O image makes the value cache narrow, but its 224 BF16 coordinates still occupy 448 logical bytes per token/layer. I tested a direct signed-nibble coordinate for those values on the frozen paid .53060-BPW V/O image. Even after fitting a separate step for every coordinate and allowing a learned center, the layer-14 causal post-O error is much worse than the existing one-byte E4M3 cache. The next half-byte cache should change the paid V basis and its O consumer together; another scale search on this frozen basis is a poor bet.

For group `g`, let `z_t` be its 28 BF16-rounded narrow producer coordinates and `p_ht` the causal probability assigned to position `t` by either of its two heads. The new cache writes `c_tj = clip(round((z_tj-m_j)/s_j), -7, 7)` and the real-valued consumer computes

```
y_h = (sum_t p_ht c_t) diag(s) L_h^T + (sum_t p_ht) m L_h^T.
```

Since real softmax probabilities sum to one, the last term is a fixed head/group output offset, applied once per query rather than once per cached key. Both heads share the same codes. This identity does **not** claim bit-identical BF16/FP32 attention accumulation: the replay decodes `c*s+m` before the floating attention sum. A native delayed-scale/offset consumer is a different rounding map and needs its own quality comparison. It never needs to reconstruct the original 128-dimensional value vector. A direct integer probability dot would need to quantize probabilities and pay for that error and preparation; the measured replay does not do so.

Eight original-producer 256-token train windows select twelve candidate steps per coordinate by coordinate MSE, with FP16-rounded metadata. The raw arm has zero center; the centered arm uses the BF16-coordinate train mean. The adaptive arm selects raw or centered per coordinate by train MSE. A one-step-per-group arm is a capacity control. Four repeatedly inspected validation windows score full causal post-O response against original dense V/O, using the same paid factor image and Q/K probabilities as [the one-byte study](../value-fp8-cache/README.md). Its E4M3 scales come from that study's frozen train receipt.

| Layer | BF16 narrow | E4M3, 8-bit | Int4 group step | Int4 coordinate | Int4 centered | Int4 adaptive center |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 train relative squared error | .222819 | .223209 | .236699 | .232400 | .231962 | .231703 |
| 0 held relative squared error | .378887 | .379186 | .391599 | .386704 | .386049 | .385731 |
| 14 train relative squared error | .164176 | .164520 | .479263 | .214402 | .304531 | .221682 |
| 14 held relative squared error | .326195 | .326527 | .583001 | .365386 | .448759 | .371962 |

Per-coordinate MSE selection picks some mean-centered coordinates on layer 14, but that adaptive cache raises train post-O error from .214402 to .221682 and held error from .365386 to .371962. Optimizing the isolated cache coordinate does not optimize the shared causal/O consumer. The layer-14 coordinate arm loses to E4M3 on every held window: .368484/.411860/.324682/.359515 versus .323552/.367086/.289459/.327971. The centered arm is worse on all four and also worse on train. Layer 0's adaptive center improves the raw coordinate arm by .000973 held, but remains .006545 behind E4M3. A group step is especially damaging at layer 14. This is a measured negative for static affine signed-nibble coding of *these frozen coordinates*, not an impossibility result for 4-bit value caches. Train and held errors are both well above E4M3 at layer 14, so larger search over the same center/step family is unlikely to fix the gap.

The packed cache would use 112 logical bytes/token/layer and eight 16-byte group slots, 128 padded bytes, versus E4M3's 224 logical/256 padded and BF16's 448 logical/512 padded. The K cache remains 2,048 logical bytes. The centered/adaptive code adds 448 bytes of FP16 coordinate centers and 448 bytes of FP16 steps per layer, versus E4M3's 16-byte group scales; raw coordinate steps need 448 bytes. Folding the real-valued center contribution into one 1,024-element FP32 output bias costs another 4,096 bytes/layer and 1,024 adds/query token; without that table, applying the center after each head's output matrix costs up to 458,752 products/query token. Its 224 producer divisions, rounding/clamps and nibble packing per token, plus 448 narrow value accumulations per key across both heads and their post-attention scales are **online**. No native launch, traffic or latency was measured. Weight BPW and the paid 688,128 factor terms/token do not move.

This is CPU original-producer replay, not quantized-upstream loss or a useful full-model image. The result suggests training a *range-shaped narrow basis* with its paid output codes on quantized-producer continuation, including a four-bit cache term in the training objective. A changed basis could trade a little unquantized V/O accuracy for much less four-bit cache damage. Compare that against the frozen one-byte E4M3 and a quality-matched larger-rate model before native implementation.

`measure.py` reproduces the two layer receipts under `/path/to/workspace/data/kelana-subbit/value-centered-int4/layer{00,14}-8x4.json`. Each retains train/held per-window scores, FP16 metadata, model/capture/paid-image/source and E4M3 receipt hashes. From a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-centered-int4/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-centered-int4/measure.py --layer 14
```
