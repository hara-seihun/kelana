# Fill the paid Q/K cache lines before shrinking the denominator

The paid 112-plane Q/K score consumer leaves sixteen RoPE planes' worth of empty slots in its eight 64-byte BF16 key-cache lines. At layer 14, five groups already use all sixteen slots, while the other three use 7, 12 and 13 planes. Filling those three groups to sixteen, then refitting the selected BF16 key affine, lowers four-window held teacher-to-candidate causal attention KL from **.338360 to .308216**. At layer 0 the corresponding result is **.260143 to .252318**. All four previously inspected held windows improve at each layer. This buys score quality without enlarging the padded key cache; it does spend sixteen more plane scores per key and 64 more affine bytes per layer.

| Layer | Previous 112, existing fit | 112, same new fit budget | 128, FP16 post-gain diagnostic | 128, BF16 affine consumer | Full paid Q/K |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .260143 | .260184 | .252337 | **.252318** | .162115 |
| 14 | .338360 | .338609 | .308094 | **.308216** | .288208 |

The same-fit-budget 112 control matters. Re-optimizing the earlier 112 gains on the same train observations does not produce this gain. Layer-14 held BF16 values are `[.294505, .318116, .288100, .332145]` at 128 against `[.325117, .343474, .323470, .361381]` for the preceding 112 image. Layer 0 gives `[.257943, .263617, .239549, .248163]` against `[.265307, .274652, .246860, .253752]`.

## Construction and price

Both arms keep the same frozen paid binary Q and K factor images, original-producer hidden captures, BF16 projection and RMSNorm schedule, and the full raw 128-coordinate K norm per group. The 112 mask and its fitted group affine come from [the paid plane reassignment](../paid-qk-plane-allocation/README.md). For each group with fewer than sixteen selected planes, a train-only greedy step estimates the finite causal cross-entropy derivative and diagonal softmax curvature of every unselected whole-plane score. It chooses the best predicted positive bounded coefficient, updates the train scores and repeats until the group's sixteen slots are full. This is a local selection heuristic, not an optimum over plane subsets. Both the new 128 mask and an unchanged 112-mask control get an 80-iteration bounded L-BFGS-B fit with the same `.002` ridge. Gains round to FP16 before multiplication into the existing group-indexed BF16 key affine. The post-gain FP16 arm is a diagnostic; the reported direct consumer reads only the BF16 table. Eight 256-token train windows supply sixteen strided causal queries per window; four distinct but repeatedly inspected validation windows supply all causal query/key pairs and both heads per group.

| Charged quantity per layer or occupied key | 112 | 128 |
| --- | ---: | ---: |
| Logical BF16 cached key coordinates | 224 | 256 |
| Logical BF16 cache bytes | 448 | 512 |
| Padded cache bytes, one 64-byte line per group | 512 | 512 |
| Two-head scalar score products per key | 448 | 512 |
| Selected BF16 key affine bytes | 448 | 512 |
| Bitmap for 64 planes in each of eight groups | 64 | 64 |
| Raw K rows used by RMSNorm, across eight groups | 1,024 | 1,024 |
| Paid binary Q/K projection image and factor terms | unchanged | unchanged |

The 14.3% added score products are on every causal key and are **not** free just because the padded cache bytes are unchanged. Query coordinate preparation also grows from 448 to 512 selected BF16 coordinates across both heads. Native gather, register occupancy, cache traffic and complete-model quality have not been measured. The full paid Q/K score uses all 64 planes, 1,024 logical K coordinates and 2,048 two-head products/key; it is a higher-cost ceiling, not an equal-work baseline. With norm computation still full-width, this experiment does not establish a cheap sparse K producer. It identifies a score/cache trade worth taking into a jointly trained selected-row producer, not a runtime selection.

The next useful comparison takes the [causally fitted sparse K denominator](../causal-key-norm/README.md) through these changed 128-plane masks, then trains the selected-row Q/K factors and norm together on quantized-upstream text. Freeze both images before disjoint gold or post-O evaluation. A 112-plane score with a cheaper norm and a 128-plane score with the full norm are distinct cost points, not competing measurements of one map.

`measure.py` and `/path/to/workspace/data/kelana-subbit/paid-qk-cache-slack/layer{00,14}.json` retain both masks, every greedy addition, fitted gains, complete BF16 tables, per-window KLs, score/work counts and SHA256 of source, model, capture, paid factor images and previous receipt. Reproduce each CPU panel without a GPU reservation:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/paid-qk-cache-slack
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 0 --output /path/to/workspace/data/kelana-subbit/paid-qk-cache-slack/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 14 --output /path/to/workspace/data/kelana-subbit/paid-qk-cache-slack/layer14.json
```

No GPU, Bonsai executable or resident service changed.
