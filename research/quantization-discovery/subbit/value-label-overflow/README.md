# Aggregate repeated value labels before the sparse-overflow dot

The [indexed narrow-value cache](../value-label-histogram/README.md) found repeated whole 224-byte signed-byte rows at Qwen3-0.6B layer 0. Its proposed histogram reader looked worse than the [key-wise sparse-overflow reader](../value-mass-overflow/README.md) because it used **two full byte dots** for the aggregated 4,095-unit counts. That is the wrong comparison. Apply the sparse-overflow split *after* adding counts for identical labels. It is an exact integer construction that cuts the layer-0 logical code products by 37.67% against the key-wise sparse reader, with unchanged codes, storage, count map and model response.

For each GQA group, let `c_j ∈ [-127,127]^28` be its distinct signed-byte rows and `i(k)` the shared byte ID of key `k`. Each head owns nonnegative counts `n_{h,k}` summing to 4,095. Accumulate `H_{h,j} = Σ_{k:i(k)=j} n_{h,k}`, then split `b_{h,j}=min(H_{h,j},255)` and `e_{h,j}=max(H_{h,j}-255,0)`. The complete observed integer map is

```
Σ_k n[h,k] c[i(k)] = dot_u8_i8(b[h,:], c[:,:])
                       + Σ_{j:e[h,j]>0} e[h,j] c[j].
```

Every intermediate count is at most 4,095; the output coordinate magnitude is at most `127×4,095=520,065`, safely within int32. There can be at most `floor(4095/256)=15` overflowing labels per head/query, independent of context and number of repeated keys. First-occurrence dictionary IDs mean a prefix touches a contiguous run of labels. This proof covers **all** nonnegative conserved-count rows and all signed-byte codes, not only the captured rows. FP32 scheduling after the integer response and floating attention before count rounding are separate maps.

The CPU replay uses four previously inspected 256-token original-producer validation windows per layer, the frozen paid rank-28 V/O image, the parent's FP16-rounded signed-byte scales and its cumulative-rounded 4,095-unit causal counts. It checks the direct integer dot at **every** head/query and hashes the entire output in exactly the same order as the parent sparse-overflow receipt. Both layer output hashes match. The pinned model, capture, image, factor decoder and code hashes are in the [raw receipts](/path/to/workspace/data/kelana-subbit/value-label-overflow/README.md).

| Layer | Key-wise low byte products + scalar corrections | Grouped low byte products + scalar corrections | Count scatters / touched-bin initialization | Maximum overflowing labels |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 58,949,632 + 1,070,888 | 36,140,608 + 1,270,920 | 2,105,344 / 1,290,736 | 9 |
| 14 | 58,949,632 + 1,141,560 | 58,949,632 + 1,141,560 | 2,105,344 / 2,105,344 | 9 |

At layer 0, the grouped expression saves 22,809,024 byte products and adds 200,032 irregular scalar correction products. Counting those unlike products equally gives 37,411,528 versus 60,020,520, a 37.67% reduction **before** 2.11 million head/key histogram adds and 1.29 million touched-bin clears. The extra overflow is real: merging small counts can push a label above 255, increasing overflow labels from 38,246 to 45,390. Nevertheless the 15-label bound survives merging. The earlier two-byte-dot histogram needed 72,281,216 byte products; the new split has one 36,140,608-product byte pass instead. At layer 14 every row is distinct, so grouping buys no dot work and only adds scatter and initialization. A consumer should bypass the histogram on such blocks; first-occurrence IDs already reveal the unique count at append time.

The byte counts remain those of the parent indexed cache: 125.273 bytes/key including shared IDs and block metadata at layer 0, 225.023 at layer 14, versus 224 raw. No additional dictionary is required. Byte-product counts are *not* gfx1151 issued dot instructions, and scattered int32 histogram additions can serialize or cost more than the products they replace. A byte-dot reader might pad unique counts to a tile width. Appending the dictionary, constructing the 4,095 counts, index gathers, zeroing touched bins, scatter conflicts, sparse corrections, scale/O and occupancy are unpaid. There is no GPU, native timing, new model-quality point, executable or service change.

The next native experiment is a group-owned indexed append plus fused two-head count-scatter/one-byte-dot/sparse-correction consumer at an occupied context. Compare the **complete** reader with raw signed-byte plus key-wise sparse correction and E4M3, and measure both the repeated early layer and an all-unique layer to validate block bypass. If scatter dominates, learn a value codebook that induces more repeats or directly aggregates counts during softmax instead of adding another full dot.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-label-overflow/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
