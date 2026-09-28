# A sparse norm survives the larger paid Q/K score observer

Filling the paid key-cache lines with sixteen more RoPE planes improved the full-norm causal score, but also changed which raw K rows a sparse producer must retain. I refit the positive 16-extra-row denominator on that new mask, using the same original-producer Qwen3-0.6B captures, binary Q/K images and train-only sampling and finite causal objective as the [112-plane sparse norm](../causal-key-norm/README.md). The 128-plane sparse map beats the old sparse map on all four inspected held windows at layers 0 and 14. It stays close to the new full denominator at layer 0; layer 14 pays another .01745 KL. This is a real score/producer-work trade, not a native speed or language result.

| Layer, mean held two-head causal KL | 112 planes, full K | 112 planes, 16 extra rows | 128 planes, full K | 128 planes, 16 extra rows unfit | 128 planes, 16 extra rows fit |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .260143 | .262074 | .252318 | .284271 | **.253286** |
| 14 | .338360 | .349021 | .308216 | .413889 | **.325664** |

The four 128-plane sparse held-window means are `[.256872, .270101, .240045, .246124]` at layer 0, versus `[.261891, .282019, .250466, .253921]` for the old sparse arm. At layer 14 they are `[.318649, .328938, .303363, .351707]` versus `[.342288, .348397, .332732, .372668]`. The comparison reuses repeatedly inspected validation windows. No selection or new image should be justified by treating these windows as fresh.

## Construction and cost

The [128-plane cache-slack receipt](../paid-qk-cache-slack/README.md) fixes sixteen whole RoPE planes per GQA group, the BF16 group key affine and the paid binary Q/K factors. Per group, the map needs 32 selected raw BF16 K coordinates for score and sixteen additional raw rows for norm. I draw the extra rows from the other 96 coordinates with the preceding four-stratum train-energy sampler and identical fixed group seeds. The five positive denominator coefficients weight selected energy and the four sampled-bin energies. A bounded 60-iteration L-BFGS-B fit minimizes smooth finite two-head causal cross-entropy on sixteen strided query positions per 256-token window across eight train windows. FP16 coefficients then enter the BF16-normalized held score over all causal positions in four other windows. The full-norm arm changes only that denominator, while the unfit arm uses the same sampled row lists with unit coefficients. This fit does not change the Q/K factors, selected affine or upstream producer.

| Per layer or occupied key | Previous 112-plane sparse | New 128-plane sparse | Full 128-plane norm |
| --- | ---: | ---: | ---: |
| K raw producer rows | 352 | 384 | 1,024 |
| Common plus output factor signed terms/token | 352,256 | 360,448 | 524,288 |
| Selected BF16 key coordinates | 224 | 256 | 256 |
| Key cache payload, 64-byte padded lines | 512 B | 512 B | 512 B |
| Two-head scalar score products/key | 448 | 512 | 512 |
| Selected BF16 affine bytes/layer | 448 | 512 | 512 |
| New sparse row indices plus norm coefficients/layer | 208 B | 208 B | 0 |

The new sparse image would remove 31.25% of the full K input-plus-output factor terms. Compared with the old sparse map, 32 additional selected rows cost 8,192 signed terms per token and 64 score products per causal key, for the measured .00879/.02336 held-KL gain at layers 0/14. Its K output-factor signs need 12,288 bytes rather than the full factor's 32,768, before row scales and packing. The 128-plane score image itself spends 64 more affine bytes than 112 planes; the denominator indices and coefficients are separate. The full binary K image was retained for this CPU replay. A native program must physically prune and reorder the output factor, reduce 48 raw energies per group and write the selected 32-key coordinates. No int4 expansion or full raw output is needed by this proposed consumer, but its memory and instruction costs have not been timed.

Layer 14 has a sharper norm penalty than layer 0. An extra .01745 KL relative to its full-norm 128-plane arm means these fixed train-energy row lists are not a quality-free replacement. The next experiment should fit sparse Q/K output codes, row support and norm together on quantized-upstream train text, freeze them, then compare disjoint causal/post-O and gold loss to an equally charged binary full-score control. [Train-CE row-support pruning](../norm-row-support/README.md) applies to the *old* 112-plane mask; its deleted rows are not automatically safe here. If the 128-plane score gain survives propagation, native scoring should compare its extra 64 score products per key with a 112-plane sparse consumer under matched contexts.

## Custody and reproduction

`measure.py` reuses the causal-norm fit and BF16 held-score code. Each CPU group receipt at `/path/to/workspace/data/kelana-subbit/cache-slack-norm/layer{00,14}-group{0..7}.json` retains the exact mask, sampled row list, stratum weights, FP16 coefficients, train objective, per-window full/unfit/fit KL, costs and hashes of source, model, capture, paid factors and parent score receipt. `summarize.py` checks that eight group receipts have matching identities and writes per-window means plus receipt hashes to `layer{00,14}-summary.json`. No GPU or Bonsai executable changed.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/cache-slack-norm
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 14 --group 0 --output /path/to/workspace/data/kelana-subbit/cache-slack-norm/layer14-group0.json
python3 "$D/summarize.py" --layer 14
```
