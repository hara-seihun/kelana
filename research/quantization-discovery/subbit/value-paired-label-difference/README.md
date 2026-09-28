# A paired signed difference on duplicate value labels

The paid Qwen3-0.6B rank-28 signed-byte V cache has two query heads per GQA group and repeats whole value rows in layer 0. Two existing exact readers exploit those facts separately: [duplicate-only aggregation](../value-selective-label-aggregation/README.md) shortens both byte dots, while [co-head sharing](../value-cohead-mass-share/README.md) keeps one raw-key dot and reads the other head's signed count difference. Composing them saves another 209,403 low-byte label uses on the four inspected layer-0 windows beyond two duplicate-only dots. It does not need a new weight or cache image.

## The integer map

For a causal prefix, let `c_i` be one signed-byte row shared by all keys with whole-row label `i`. The two heads have nonnegative integer counts `a_k` and `b_k`, each summing to `M=4095`. Group a label only after its second occurrence. A singleton contributes its own key; a grouped label contributes `A_i=sum_{k:label(k)=i} a_k` and `B_i=sum_{k:label(k)=i} b_k`. For the resulting list of grouped labels and singleton keys, compute

```
A = sum_i A_i c_i
B = A + sum_{i:B_i != A_i} (B_i - A_i) c_i.
```

This is both original integer attention responses, coordinate by coordinate, on **every** nonnegative conserved-count input. No intermediate 128-dimensional value or int4 weight is reconstructed. Split the first coefficients at unsigned byte 255; clip the signed differences to `[-128,127]` and add exact scalar overflow corrections. Conservation bounds first-head correction entries by 15. Positive difference mass and negative difference mass are each at most 4,095, even after aggregation. A positive correction needs at least 128 units and a negative correction at least 129 under this asymmetric signed-byte clip. Thus there are at most `floor(4095/128)+floor(4095/129)=62` signed corrections at any context length. This bound is attained on the conserved-count domain: give 31 labels a positive difference of 129, 31 other labels a negative difference of 129, and put the remaining 96 mass units in both heads at one common label. The first integer coordinate has magnitude at most `4095*127=520065`; the difference at most `8190*127=1040130`. Int32 is enough for these integer dots. Apply the existing FP16 coordinate scales and paid O maps afterward. Changing floating reduction order is not a claim of bit-identical FP32 output.

Duplicates can also cancel head differences: `sum(b-a)` for a label may vanish although none of its individual keys has equal head counts. This is the benefit that neither parent reader obtains alone. A causal append dictionary may mark both keys grouped at the second occurrence. Historical-prefix replay, rollback, count construction and synchronization need an implementation; the measured script reconstructs every prefix offline and does **not** price that work as free.

## Paid Qwen3-0.6B panel

Four previously inspected separate 256-token original-producer validation windows per layer; eight GQA groups, both heads and every causal query. The parent 4,095-count map, rounded paid right factor and 28-byte signed value rows are unchanged. The script compares every integer coordinate of both heads against raw keys, then matches the parent's complete integer response hash. Values below are logical *row uses*; multiply byte/correction uses by 28 for coordinate products. The first dot remains dense over distinct labels, while the second skips zero differences.

| Layer | Two duplicate-only byte dots | Paired unpadded | Paired with 4-key difference padding | Paired with 32-key difference padding | Correction uses, two dots → paired | Duplicate histogram scatters / bins |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 1,290,736 | 1,081,333 | 1,093,568 | 1,213,880 | 45,390 → 76,826 | 1,133,536 / 318,928 |
| 14 | 2,105,344 | 1,759,387 | 1,771,756 | 1,886,592 | 40,770 → 56,946 | 0 / 0 |

Layer 0's first dot uses 645,368 labels and its nonzero difference 435,965. Its unpadded byte-term cut from two aggregated dots is 16.22%, but rounding every difference list to 32 leaves only 5.95% before the 31,436 extra scalar corrections. Four-key lists retain 15.28%. Against the raw-key two-head dots (2,105,344 uses), the composed unpadded reader cuts 48.64%; against the raw-key paired difference (1,774,660), it cuts 39.07%. Those larger percentages depend on paying the duplicate routing already justified by neither native timer nor a free scatter. At layer 14 no code row repeats: this is exactly the original co-head difference construction, and a duplicate histogram must be bypassed. The maximum observed signed correction list has 17 entries at layer 0 and 15 at layer 14, below its tight 62-entry full-domain bound.

The result changes the native question. A fused two-head count builder should route repeated labels once, accumulate both counts, compact the nonzero signed label differences and use a short four-key padded byte dot; compare *all* append, count, routing, correction, paid O and memory work against raw signed-byte and E4M3 at occupied context. If the 31,436 extra correction uses and duplicate scatters overwhelm the saved byte dots, changing the learned value codebook to create cheap head-difference cancellation is more promising than adding a separate 32-key sparse reader. There is no GPU time, complete-model loss, executable or service change in this result.

[Receipts](/path/to/workspace/data/kelana-subbit/value-paired-label-difference/README.md) record model, capture, paid image, code, count, response, source and parent hashes. From a Kelana writer checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-paired-label-difference/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
