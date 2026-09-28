# Spend the narrow-value rank where the composed response needs it

The rank-28 shared GQA value image assigns the same number of coordinates to all eight groups. That is convenient for a kernel, but the original-producer response spectra differ sharply. On the existing Qwen3-0.6B layer-0 captures, an exact allocation of 224 continuous coordinates among the groups reduces held stacked V/O response error from .416918 to .388564 at the *same* two-bit payload formula, factor-term count and logical value-cache size. Layer 14 moves from .081591 to .077096. This is a conditional continuous construction, not a new rounded image or a model-loss result.

## Contract and optimum

For group `g`, let `V_g` be its 128×1024 value matrix, `A_g` the vertical stack of its two 1024×128 output slices, and `X` the fixed 2,048×1024 original-producer train input. The measured surrogate is

```
L_g(r) = min_{B in R^(r×1024), D in R^(2048×r)} ||X V_g^T A_g^T - X B^T D^T||_F².
```

`X V_g^T` has 128 columns. QR gives `X V_g^T=Q R`; the Eckart-Young tail of `R A_g^T` is exactly `L_g(r)`. The right singular subspace lifts through `R⁻¹` into a shared input basis. Both heads can consume it, but the expression stacks their unmixed responses. It does not optimize their separate causal attention probabilities.

Choose one rank from `{4,8,...,64}` per group, with total rank exactly 224. The objective is the **sum of eight separate group squared errors**, not the squared error of the summed attention output; cross-group cancellation is excluded. The dynamic program in [`rank_allocation.py`](rank_allocation.py) keeps the minimum loss at every `(number of groups, total rank)`. Since the response targets and rank choices separate by group, that recurrence is a global optimum for this finite grammar and continuous train surrogate. Validation freezes the train subspaces and evaluates the corresponding maps against 1,024 separate original-producer validation inputs; it plays no part in the choice.

| Layer | Ranks by GQA group, train-selected | Train error uniform → selected | Validation error uniform → selected |
| ---: | --- | ---: | ---: |
| 0 | 24, 48, 36, 32, 16, 16, 40, 12 | .368711 → .347500 | .416918 → .388564 |
| 14 | 40, 28, 16, 48, 32, 24, 20, 16 | .066959 → .062921 | .081591 → .077096 |

Errors divide the sum of group squared errors by the sum of group teacher energy on that split. The layer-0 held change is 6.8% of its uniform value, layer 14 is 5.5%. The two layer selections are independent. Neither selection sees validation.

## What the equal cost means

At rank `r` divisible by four, one group's existing 2/2-bit grammar stores 2,048×`r` output codes, `r`×1,024 input codes, 2,048 FP16 output scales, `8r` FP16 input group scales and two 16-byte descriptors. That is `784r+4,128` bytes. Both allocations total **208,640 bytes**, or .53060 BPW over the original 3,145,728 V/O weights. Both have 688,128 signed-grid factor terms per token and 448 logical BF16 value bytes per token. Rounding each group to a 16-wide matrix tile uses 256 total lanes in both displayed allocations, though unequal ranks require distinct loop bounds or bucketing; no native implementation or measured latency exists.

These are costs of the proposed *rounded* two-bit grammar, not the cost of storing the continuous optimum measured above. Quantization can reverse the ranking. Unequal groups may also require extra dispatch, padding and register lifetime. In particular, the existing rank-28 causal-coordinate fit achieved .37889 layer-0 validation post-O squared relative error, an observation **different** from the stacked, unmixed response metric in this table. Do not compare those numbers or call the selected ranks an improved model.

The useful next experiment is to quantize the train-selected per-group bases, then refit the paid two-bit output codes on the actual causal post-O map and measure held post-O response and model loss against the existing uniform-rank image. The result here avoids blindly raising every rank: the same bytes can put 48 coordinates in a difficult group by borrowing from groups that need 12 or 16. If causal fitting removes this gain, allocate rank against the attention-weighted features instead of another stacked-response spectrum.

## Reproduce and custody

Run from Kelana with the installed CPU PyTorch environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$P research/quantization-discovery/subbit/value-observer/rank_allocation.py --layer 0
$P research/quantization-discovery/subbit/value-observer/rank_allocation.py --layer 14
```

Each command takes the pinned safetensors model and `full-model/capture/layer{00,14}.npz`, computes the 128-dimensional Gram eigenproblem for each group and writes the complete train/validation curves, source/model/capture SHA256s and selected ranks to `/path/to/workspace/data/kelana-subbit/value-observer/layer{00,14}-rank-allocation.json`. The spectra and paid-rate rule are deterministic CPU work. No GPU lock, native executable or resident service changed.
