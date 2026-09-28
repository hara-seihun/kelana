# The key translation that softmax cannot see

The pinned Qwen3-0.6B key stream has a large component that the causal attention consumer cannot observe. On eight 256-token train windows, a constant **post-RoPE** vector per GQA group accounts for 90.12% of layer-0 rotated-key squared energy and 55.41% at layer 14. Subtracting that train-fitted vector leaves 9.87% and 46.59% of the respective key energy on four existing held validation windows. This is an exact real-score softmax quotient, not a reason to drop a coordinate or a new paid sub-bit image.

The placement matters. Subtracting a constant **before** RoPE instead changes held causal attention by 1.54078/0.78095 teacher-to-candidate KL at layers 0/14. The safe post-RoPE subtraction changes double-precision softmax by less than numerical noise, with measured KL about zero and centered score error below `6e-30`. The frequently tempting move of folding a mean into the K producer is therefore wrong unless the producer emits the *position-dependent* pre-RoPE offset that becomes one common post-RoPE vector.

## Exact observation and restricted obstruction

Let `q_s` and `k_t` be the already rotated query/key vectors, and let `a_{s,t} = softmax_{t<=s}(q_s·k_t / sqrt(128))`. For one fixed vector `b` shared across all keys seen by a query,

```
softmax_t(q_s·(k_t - b)/sqrt(128)) = softmax_t(q_s·k_t/sqrt(128)).
```

The removed score `q_s·b/sqrt(128)` is independent of `t`. It need not be computed, restored, or stored in the cache. The identity applies separately to both heads sharing each GQA group, to any causal prefix, and to every input, with no assumption about how `b` was learned. For unrestricted queries and a prefix containing keys `t,u`, a collection of key perturbations preserves **all** score differences only if `δ_t - δ_u = 0`; the query can otherwise distinguish the difference. This necessity concerns score differences, not coincidences of one finite query distribution.

A constant pre-RoPE subtraction `c` gives `δ_t = R_t c`. In the 64 Qwen RoPE planes, consecutive positions rotate by nonzero angles strictly between zero and `2π`; no plane has a nonzero fixed vector. Thus `R_0 c = R_1 c` implies `c=0`. A nonzero pre-RoPE mean is not the same gauge. To emit `k_t-b` from a pre-RoPE producer one must subtract `R_t^{-1} b` at position `t`, or subtract `b` after rotation. Neither operation is free in a native consumer.

The train mean `b_g = mean_{w,t} k_{w,g,t}` minimizes unweighted train squared key magnitude within the exact translation class by completing the square. It is a **single frozen vector per group** learned on train, not a different center per held window or causal prefix. Minimizing this norm is not the same as minimizing rounded-score KL.

## Paired finite map

`study.py` uses the original BF16 Q/K projections, normalization and RoPE schedule from `rope-causal-mask/fit.py`, scores all 256 causal queries against their available keys for both heads in each group, and computes softmax and KL in float64. It fits eight static 128-element centers on the eight train windows. The four repeatedly inspected validation windows are a diagnostic, not fresh model selection. The BF16 arms round the rotated raw or centered keys before scoring with the same query; they do **not** include a sub-bit weight image. The per-window values, group energies, source/model/capture hashes and observation contract are in `/path/to/workspace/data/kelana-subbit/softmax-key-gauge/layer{00,14}.json`.

| Layer | Held energy remaining after train post-center | BF16 raw key KL | BF16 post-centered key KL | Real pre-RoPE center KL |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 9.868% | 3.98645e-6 | **2.43620e-6** | 1.54078 |
| 14 | 46.588% | **1.56077e-6** | 1.18419e-5 | 0.78095 |

Every layer-0 held window improves BF16 KL with the post-center; every layer-14 window worsens. The layer-14 reversal is the useful warning: a 55% reduction in key energy does not imply a better score after independent BF16 rounding. At layer 0 the gain is only a tiny BF16 score error, not language quality. The dramatic pre-RoPE KL shows that where the offset enters the composed map matters more than the size of the offset.

A direct selected-128-plane key cache would pay at most 256 center coordinates, 512 FP16 bytes/layer and 256 subtracts/token/layer if it writes the centered BF16 key after RoPE. A full 1,024-coordinate cache would pay four times that. A future packed centered-key producer can instead absorb the offset into its codeword response, but its position dependence, table bytes, pack/write operations, and score preparation still need to be charged. Translation does not itself reduce the 128-plane key cache, K factor terms, or stored weight rate. Double scores after a BF16 cache write are also a changed numerical map, not bit-identical to the deployed Qwen BF16/F32 score path.

## Next construction

Fit a position-aware centered **paid K cache image** on quantized-upstream train text. Compare a codebook or selected-row Q/K factor trained on the residual `R_t k_pre - b` against the same-rate uncentered factor using causal/post-O and fresh gold loss, with the 128-plane masks and sparse denominator held matched. Charge the actual post-RoPE centering/write cost and try groupwise acceptance: layer 14 should not be forced into the layer-0 BF16 choice. Do not treat an unrotated K mean or a small Frobenius norm as a softmax certificate.

Run the CPU replay, with no GPU reservation or service change:

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/softmax-key-gauge/study.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/softmax-key-gauge/layer$(printf '%02d' "$layer").json"
done
```
