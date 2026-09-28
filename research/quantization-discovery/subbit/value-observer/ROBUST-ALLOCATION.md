# A window-robust allocation does not fix the layer-0 loss tail

The fresh single-layer loss panel split by corpus: the selected 192-coordinate V/O image wins all twelve fresh test windows against equal-rate uniform rank 24, yet one validation window makes its eight-window validation NLL worse. Is this an average-error allocation that sacrifices a hard training window? For the existing frozen rank-28 basis, **no**. Among all 6,371 paid prefix allocations, the layer-0 choice that minimizes aggregate train causal post-O squared error *also minimizes the worst training window's relative squared error*. Penalizing the worst train window by up to twice its relative error cannot change the choice. The split in fresh language loss cannot be repaired by this tail penalty on the same original-producer squared-error observer.

| Layer, train selection | Ranks by KV group | Train mean | Train worst | Held mean | Held worst |
| --- | --- | ---: | ---: | ---: | ---: |
| 0, aggregate = minimax | 28,28,28,28,28,4,28,20 | .253771 | .288962 | .391723 | .421042 |
| 0, uniform 24 | 24,24,24,24,24,24,24,24 | .280493 | .311108 | .416947 | .446944 |
| 14, aggregate | 28,28,28,8,28,16,28,28 | .195449 | .210692 | .339522 | .379668 |
| 14, mean + worst | 28,20,28,8,28,24,28,28 | .196022 | .209857 | **.338224** | .377709 |
| 14, minimax | 28,20,24,12,28,24,28,28 | .197790 | **.209058** | .338899 | **.375383** |
| 14, uniform 24 | 24,24,24,24,24,24,24,24 | .212639 | .229305 | .353041 | .396125 |

The layer-14 mean-plus-worst choice at weights 1 or 2 lowers held aggregate error by .001298 against the prior train-mean choice without changing its 192-coordinate rate. The pure minimax choice lowers held worst-window error by .004285 but costs .002340 train aggregate error. At weights .25 and .5, the prior aggregate choice remains selected. These are frozen-code original-producer response results. Layer 14 had almost no fresh single-layer NLL separation in the preceding experiment, so neither small response gain earns a native kernel or a model-quality claim.

## Finite problem and scope

The original rank-28 two-bit factor supplies 56 four-coordinate causal post-O contribution tensors, seven per KV group. An allocation removes exactly eight suffix blocks, retaining 192 coordinates. For each of eight separate 256-token train windows and four validation windows, the script forms its 56-by-56 contribution Gram, its inner products with the full-image residual, and the original teacher energy. Thus each window's relative squared error for a removal mask `d` is `(||r||² - 2 d·C r + dᵀ C Cᵀ d)/||y||²`. Enumerating all 6,371 legal masks gives exact selection within this finite, frozen-response grammar, up to floating-point accumulation. The aggregate uses teacher-energy weights, matching the earlier total-error objective. The tail is the maximum *per-window normalized* error. Validation never selects a mask; its mean and worst errors diagnose transfer.

Every arm stores the same two-bit codes and scales for its retained coordinates as the paid rank-28 source. The earlier pruning script establishes that any of these rank tuples packs in 183,552 parameter bytes, .466797 BPW over V/O, and computes 589,824 signed-grid terms per token with 384 BF16 logical value bytes. The new minimax masks have **not** been repacked or refitted; the record is an allocation decision and a cost formula, not a newly measured native consumer. The previous layer-0 image was later refitted on original producers; its fresh model-loss tail is on different text and a different observation. The held response windows here are not that fresh text.

The result rules out *training-window minimax reallocation on this frozen right basis and this squared-error observer* as a cure for the layer-0 fresh-loss tail. It does not bound gold-token loss, quantized upstream producers, learned right directions, or a different rank/code family. Next fit the right basis with quantized-producer features and a train loss sensitive to the downstream logits, then select against separate fresh text. Reweighting these same block errors is the wrong next iteration.

## Reproduce

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-observer/robust_allocation.py
OPENBLAS_NUM_THREADS=1 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=1 "$P" "$D" --layer 14
```

The two `layer{00,14}-robust-allocation.json` records in `/path/to/workspace/data/kelana-subbit/value-observer/` carry every selected arm's twelve per-window errors, source/model/capture/image SHA256, grammar, held-only diagnostic optima, and all 6,371 train choices' count. This is a CPU experiment; the GPU, installed engine and resident service did not change.
