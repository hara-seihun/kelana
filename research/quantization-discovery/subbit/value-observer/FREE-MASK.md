# Free block selection barely improves frozen narrow values

The 192-coordinate causal allocation previously required a prefix in each of eight rank-28 groups. I removed that restriction while keeping the rounded two-bit factors fixed: any eight of the 56 four-coordinate blocks may be discarded, with at least one block left per group. On layer 0, the best train-only exchange moves one omission from group 7 to group 0 and improves held relative post-O squared error from .391723 to .390890. On layer 14, all twelve starts return the existing prefix optimum, .339522. The cost-neutral coordinate reorder is real but small. This is a useful stopping point for *deleting blocks from this particular frozen rank-28 image*, not evidence against learning different coordinates or fitting with quantized producers.

| Original-producer layer | Selection | Group ranks | Train error | Held validation error |
| ---: | --- | --- | ---: | ---: |
| 0 | Exhaustive prefix control | 28,28,28,28,28,4,28,20 | .253771 | .391723 |
| 0 | Unrestricted exchange | 24,28,28,28,28,4,28,24 | .253212 | .390890 |
| 14 | Exhaustive prefix control | 28,28,28,8,28,16,28,28 | .195449 | .339522 |
| 14 | Unrestricted exchange | same | .195449 | .339522 |

The layer-0 gain is .000833 absolute, or .21% relative to the prefix control. It is 0.000833 of held teacher energy, not a model-loss change. Each of the twelve deterministic starts converged to the reported layer-0 mask; each converged to the prefix mask at layer 14. That is a local-search observation, **not** a certificate of the global optimum over unrestricted masks. The original-producer capture is the same eight 256-token train windows and four separate validation windows as [causal pruning](CAUSAL-PRUNE.md). No held response enters selection.

## What the search actually solves

Let `c_i` be the complete FP32 causal post-O response of block `i` using the existing rounded input and output factors, and let `r = sum_i c_i - y`, where `y` is the original V/O teacher response. For a dropped set `D`, the scored error is exactly the quadratic `||r - sum_{i in D} c_i||² / ||y||²` on the captured arrays. A 56-by-56 Gram and 56 linear terms include cross-head and cross-group cancellation. Starting from the exhaustive prefix optimum and eleven seeded feasible random masks, the search takes the best strictly improving one-for-one block exchange until none remains. Swaps respect eight dropped blocks and at least one retained block per group. Thus each returned mask has no improving legal single-block exchange, up to the stated floating tolerance; combinations of two or more exchanges remain open. Direct reconstruction from all 56 recorded FP32 responses agrees with the quadratic to 0.000005 on the selected arms. Neither is bit-exact Qwen BF16 inference.

A standalone packed factor image reorders retained columns into a local 0..r-1 coordinate; attention and O consume that coordinate directly. The code and FP16 scales of every retained original coordinate are copied, with decoded tensors checked against the selected source columns. I conservatively store eight bytes of original-coordinate provenance masks in the image, charging **183,560 bytes**, or **.466817 BPW** over 3,145,728 original V/O weights. Dropping the optional masks yields the prefix image size of 183,552 bytes, .466797 BPW. Both choices retain 192 coordinates, 589,824 factor terms per token and 384 logical BF16 value bytes per token; K plus narrow V uses 2,432 logical BF16 bytes per token. At sixteen-wide tile padding the selected layer-0 shape uses 240 value lanes and layer 14 uses 224, unchanged from each corresponding prefix control. There is no native instruction or latency receipt, and no reason to time a fused consumer merely to exploit this .21% local held-error gain.

This negative redirects the next quality experiment: refit a new unequal-rank or pruned basis with quantized producers and the complete causal post-O objective, then evaluate fresh single-layer loss. Reordering the frozen basis is nearly exhausted on these two captures; a learned basis can change the span and the online representation without spending additional stored rate.

## Receipts

Run from Kelana with `/path/to/workspace/data/fish-s2-pro/venv/bin/python`:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$P research/quantization-discovery/subbit/value-observer/free_mask.py --layer 0 --starts 12
$P research/quantization-discovery/subbit/value-observer/free_mask.py --layer 14 --starts 12
```

`/path/to/workspace/data/kelana-subbit/value-observer/layer{00,14}-free-mask.json` has model, capture, source and packed-image SHA256 hashes, all starts' initial/final objectives and swap counts, direct and quadratic train/held scores and omitted block IDs. The selected packed images are `layer{00,14}-free-mask.npz`. Their SHA256 hashes are `af29945797e7c67451f15433d0de49b3a728831f78c0f72293889cc300307ec9` and `9d27288bb7e3a3e8474bac2fc3752d3c434dbe709eb782aa5bd8f8c90a17c67d`. This was a CPU study; GPU and serving were untouched.
