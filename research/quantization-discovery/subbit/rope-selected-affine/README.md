# Selected-coordinate key affine

The [group-indexed key affine](../rope-group-affine/README.md) charged a dense `(8,128)` BF16 table, 2,048 bytes per layer, to retain each group's fitted causal RoPE-plane gain without an extra normalization multiply. That is a valid full-width implementation but an unnecessarily expensive image for the **selected-plane score consumer**. At the unchanged 112-plane mask, the consumer observes only 224 normalized key coordinates across eight groups. Store their already multiplied BF16 affine values in mask order. The table is 448 bytes, and the selected score map is identical to the dense group-affine map.

## Map and proof

For group `g`, raw key `u_g` and mask `M_g`, first compute the **full 128-coordinate** denominator `d_g = rsqrt(mean_i BF16(u_{g,i})² + 1e-6)`, with the same FP32 reduction and BF16 rounding as the dense key normalization. For each plane `p` in `M_g`, take normalized BF16 `n_{g,p}` and `n_{g,p+64}`, multiply them by the dense group's BF16 affine entries `gamma[g,p]` and `gamma[g,p+64]`, then rotate those two outputs. The narrow table concatenates exactly these `gamma` entries in `(g, mask order, first-half then second-half)` order. The group offsets come from the mask lengths. No online gain multiplication or float reconstruction of the omitted normalized coordinates occurs.

Each selected multiply has identical operands and type to the dense implementation. RoPE is block diagonal in its 64 two-coordinate planes, so omitted planes cannot contribute to a selected rotated coordinate. Identical selected rotated keys and unchanged queries imply identical finite scores, softmax outputs and attention weights under the same reduction schedule. This is a bit-identity argument for this **selected score observation**, not for the omitted full key tensor or a changed projection/denominator. It does not assert that arbitrary FP32 reassociation is bit-identical.

The CPU replay uses original-producer Qwen3-0.6B BF16 K projections, the previous frozen group gains and masks, and all 1,024 positions of four already inspected validation windows at layers 0 and 14. There are zero BF16 differences in selected normalized coordinates and zero FP32-bit differences in selected rotated coordinates in either layer. Hence the previous dense group-affine held attention KL, `.229924`/`.343980`, carries over **exactly** for the same query and score schedule. The replay does not train a new image or establish fresh language quality. Its two [source/model/capture/prior-hashed receipts](/path/to/workspace/data/kelana-subbit/rope-selected-affine/) retain every BF16 table entry and per-group comparison counts.

## Paid rate and online boundary

| Key affine storage per layer | Layer 0 | Layer 14 | Meaning |
| --- | ---: | ---: | --- |
| Original shared full-width | 256 B | 256 B | Existing key RMSNorm gamma |
| Shared gamma restricted to union of selected coordinates | 144 B | 176 B | Different groups reuse an entry |
| Group-specific gamma restricted to selected coordinates | **448 B** | **448 B** | Full fitted group gains, identical selected map |
| Dense group-specific gamma | 2,048 B | 2,048 B | Also gives unused normalized coordinates |

All selected score images pay the same 112 plane IDs, which can be stored as 112 unsigned bytes, and group lengths or offsets. The 448-byte table adds 192 bytes/layer against the deployed full-width shared 256-byte gamma, or .000488 bits per Q/K projection weight for 3,145,728 Q/K weights/layer. The dense group table instead adds 1,792 bytes/layer, .004557 bits per Q/K weight. Repeating this comparison over 28 identical-shape layers saves 44,800 bytes versus dense group tables, but actual trained masks/gains and quality for those other layers are **not** established.

The selected consumer still needs the full 128-coordinate *raw* K norm denominator to reproduce this original-producer map. It may omit the unselected affine multiplies and rotated coordinates; it cannot simply run a 28-coordinate RMSNorm, omit the raw producer rows, or claim a cheap selected-row sub-bit K projection from this proof. The native lowering must price full-denominator production, selected affine indexing, mask loads, cache lines, register pressure and score scheduling. An alternative jointly trained narrow-denominator producer is a **different lossy map** whose quality must be measured. If another consumer needs all key coordinates, this sparse table is insufficient. No GPU, complete-model loss or Bonsai runtime measurement was made.

This closes the storage penalty for using the previously fitted group-specific gains at the narrow-score boundary. The next experiment should fit selected-row sub-bit Q/K *and its normalization rule* with quantized upstream against held causal/post-O or gold loss, including a same-rate binary Q/K control. A native sparse-table consumer is worth timing only if that paid image survives this comparison.

From the Kelana checkout, the replay is bounded to one layer per command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/rope-selected-affine/measure.py --layer 0 --output /path/to/workspace/data/kelana-subbit/rope-selected-affine/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/rope-selected-affine/measure.py --layer 14 --output /path/to/workspace/data/kelana-subbit/rope-selected-affine/layer14.json
```
