# Paired attention difference on the paid narrow-value image

Two Qwen GQA heads share each rank-28 value code, but their attention probabilities differ. The [preserved-column transfer](../value-transfer-commutation/README.md) showed that borrowing one head's attended value from its partner loses quality. Could a lower-rank *difference* retain the missing information and save value dots instead? On the frozen paid V/O image, the answer is no at an attractive rate and cost. This is a measured negative for a specific linear family, not a limit on jointly trained values or attention.

Let `z0 = Σ_k p0k c_k`, `z1 = Σ_k p1k c_k`, and let `D0,D1` be the paid 28-to-1024 output maps for one GQA group. In real arithmetic the complete contribution is

```
z0 D0 + z1 D1 = (z0+z1)(D0+D1)/2 + (z0-z1)(D0-D1)/2.
```

Factor `D = (D0-D1)/2` as a rank-`r` map, without reconstructing either individual output head. The sum can use 28 code-coordinate attention dots; the difference can use `r` preprojected code coordinates, reducing 56 to `28+r` value dots/group/query/key. This is the whole observed post-O map. It does not assume either individual head value must exist. SVD gives the best rank-`r` matrix approximation in Frobenius norm. We also calculate a held-data oracle: the rank-`r` tail of the *observed difference response*, which is a lower bound on each group's response error for any rank-`r` matrix chosen even with access to these held inputs. It is not a lower bound on the final sum across groups because their errors can cancel.

The same frozen packed two-bit V/O image and four previously inspected original-producer 256-token validation windows as the transfer study supply the values and attention probabilities. The recorded observation is the FP64 post-O response of the **paid image**, not the original teacher or model NLL. All sixteen 28-to-1024 left factors are decoded as real matrices, and the SVD factors have no paid low-bit representation in this experiment. Each row below applies one rank to all eight groups. The error is squared change divided by squared paid-output norm; rank 28 reconstructs it to numerical roundoff.

| Rank of difference | Value dot coordinates/group, formerly 56 | Layer 0 change | Layer 14 change | Extra cached coordinates/group if projected at append |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 28 | .234328 | .280096 | 0 |
| 8 | 36 | .147467 | .087880 | 8 |
| 16 | 44 | .080417 | .047892 | 16 |
| 24 | 52 | .027455 | .017171 | 24 |
| 28 | 56 | <1e-28 | <1e-28 | 28 |

All eight difference matrices have full rank 28. Their smallest singular values are at least 1.729 and 3.635 for layers 0 and 14, respectively; their worst condition numbers are 2.319 and 3.040. Thus **exact** factoring of the two independent attention responses within this linear difference grammar needs all 28 difference coordinates on the full 28-dimensional code domain. The captured held-data oracle remains costly: at rank 24, even a per-group factor fitted to those same held rows has squared error at least 0.20–1.58% of that group's complete response at layer 0 and 0.11–0.53% at layer 14. Those are *individual-group* bounds; they cannot be summed to bound the complete layer.

The apparent value-dot saving also has a boundary bill. The existing signed-byte rank-28 V cache stores 224 bytes/key/layer. Holding the original codes and `r` preprojected difference coordinates adds `8r` coordinates/key/layer: at `r=24`, 192 more bytes/key/layer if each is one byte, plus `8×28×24=5,376` projection products/key/layer and `8×1024×24=196,608` difference-output products/query/layer. The latter replace part of the original output work rather than add to it. One-byte projections would add another rounding error not included above. Projecting after attention avoids the extra cache but still needs both original 28-coordinate head dots, so it saves no value-dot work. A jointly trained producer could replace rather than supplement the original coordinates; this frozen-image experiment does not price or rule out that construction.

This is a poor frozen-image native target. The `r=24` arm saves only 4/56 value dots and pays a large cache/append bill while changing the paid response by 1.7–2.7% relative squared norm. The next useful question is whether a jointly trained shared/difference V producer and both output maps can make the difference *actually* low rank under quantized-producer causal loss. Only then compare a paid low-bit factor image and its complete native append/attention/output reader. No GPU, model-loss result, Bonsai executable or service changed.

The [CPU receipts](/path/to/workspace/data/kelana-subbit/value-paired-difference/README.md) retain source, model, capture, paid-image and decoder hashes, all singular values, per-window changes and per-group held-oracle tails. Reproduce each layer with `OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-paired-difference/measure.py --layer 0` or `--layer 14` from Kelana's root.
