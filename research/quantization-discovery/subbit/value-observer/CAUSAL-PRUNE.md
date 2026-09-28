# Spend fewer frozen value coordinates on the causal output

The fitted rank-28 shared V/O image has 224 narrow value coordinates. Can we remove 32 without spending the remaining 192 uniformly? Yes, on both original-producer captures. An exhaustive train-only choice within the **frozen, prefix-truncated two-bit image** improves held causal post-O error over uniform rank 24 at exactly the same bytes and value-cache size. The layer-14 choice also beats a group-separable causal allocation because it accounts for cancellation after the O sum. No right or left codes were refitted, so this is a rate-allocation construction, not a new complete-model quantizer.

| Layer | 192-coordinate choice | Train relative squared post-O error | Validation error | Image bytes |
| ---: | --- | ---: | ---: | ---: |
| 0 | uniform rank 24 | .280493 | .416947 | 183,552 |
| 0 | 28,28,28,28,28,4,28,20 | **.253771** | **.391723** | 183,552 |
| 14 | uniform rank 24 | .212639 | .353041 | 183,552 |
| 14 | separable train choice 28,28,28,8,28,20,28,24 | .195455 | .342653 | 183,552 |
| 14 | joint train choice 28,28,28,8,28,16,28,28 | **.195449** | **.339522** | 183,552 |

The frozen full-rank-28 controls cost 208,640 bytes and score .378887 and .326195 on validation at layers 0 and 14. Pruning thus costs some held accuracy against the more expensive image. Compared with uniform 24, the same-rate joint choice reduces held error by 6.05% at layer 0 and 3.83% at layer 14. The layer-14 separable choice is almost tied on train but loses .003131 held error to the joint choice; that is an observation, not a guarantee that cross-group fitting always generalizes.

## The finite optimization

Split each of eight already-fitted 28-coordinate groups into seven consecutive blocks of four coordinates. Retain a prefix of rank 4, 8, ..., 28 per group, with total rank 192. If `c_{g,b}` is a frozen block's entire causal post-O output on the fixed 256-token training windows, and `y` is the original V/O teacher output, selecting suffix omissions `D` minimizes

```
||sum_{g,b} c_{g,b} - y - sum_{(g,b) in D} c_{g,b}||².
```

Precompute the 56-by-56 Gram of block responses and their inner products with the full-image residual. The quadratic keeps cross-block and cross-group terms. Enumerate all **6,371** legal rank tuples with eight omitted blocks. This exhausts the grammar for the captured FP32 block responses; validation does not enter selection. A second exhaustive choice drops inter-group Gram terms but preserves within-group terms and the full-image residual, to isolate what the joint observer buys. The held-only oracle rank tuple is recorded in the receipt for diagnosing selection gap, never used to select an image. The objective is a squared error on the original Q/K probabilities, not a teacher-forced language loss or a bit-exact FP32 engine map. Gram accumulation is FP32; separately recomputed direct FP32 errors differ by at most 0.000006 in the recorded arms.

Every retained two-bit code and FP16 scale is copied from the causal-refined rank-28 image. Columns are repacked without rounding; the script decodes each generated group and checks its left/right matrices against the original prefix. The serialized group images each contain their own shapes, bitplanes and scales. The 192-coordinate payload is **.466797 BPW over the original 3,145,728 V/O weights**, down from .530599. It needs 589,824 signed-grid factor terms per token instead of 688,128, and 384 logical BF16 value bytes per token instead of 448. With K unchanged the logical BF16 K/V payload is 2,432 rather than 2,496 bytes per token. A 16-wide execution tile pads the selected layer-0 groups to 240 lanes and layer-14 groups to 224, while uniform rank 24 pads to 256. These are work and byte counts, not native timings. Unequal loop bounds, scale work, accumulation and cache layout need pricing before a speed claim.

This test also names a limit. The allocation can only *delete suffixes* of a basis learned at rank 28. A freshly fitted rank-24 basis, or one trained with quantized upstream activations, is a different competitor and may win. The obvious next experiment is to refit the selected truncated codes against quantized-producer causal captures and measure single-layer loss on fresh text; if that reverses the ranking, learn the basis using the causal features instead of recycling the original-producer SVD ordering. Native mixed-rank V/O is earned only once that quality gain persists.

## Reproduction and custody

From the Kelana checkout, using the installed CPU PyTorch environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$P research/quantization-discovery/subbit/value-observer/causal_prune.py --layer 0
$P research/quantization-discovery/subbit/value-observer/causal_prune.py --layer 14
```

`/path/to/workspace/data/kelana-subbit/value-observer/layer{00,14}-causal-prune.json` stores model, capture, source and frozen-image hashes, direct and quadratic train/validation measurements, held oracle, rate and hashed packed images for every arm. This CPU experiment did not reserve the GPU or change Bonsai serving.
