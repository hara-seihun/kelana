# Can a preserved-column transfer skip the missing head's value dot?

The [preserved paid V/O column image](../value-column-skeleton/README.md) keeps ten of sixteen 28-coordinate query-head output groups and fits the other six through a two-bit transfer. Its output map is `(z_C + z_D T) Cᵀ`. The missing coordinates `z_D` still require their own causal attention dot over the shared narrow GQA value cache. We tested a cheaper continuation: where a missing query head has a retained partner in the same GQA group, substitute the partner's 28 attended coordinates. The cache labels are identical for the two heads; their attention probabilities are not.

## Exact boundary

For a missing head `d` and its retained group partner `r`, write the cached value at key `t` as `v_t ∈ R²⁸`, its two attention probabilities as `p_dt` and `p_rt`, and the missing head's complete output transfer as `M = T_d Cᵀ`. Its contribution is `sum_t p_dt v_t M`. Replacing it with the retained head's already-computed coordinate produces `sum_t p_rt v_t M`. Their difference is

`sum_t (p_dt - p_rt) v_t M`.

For independently variable cache values in a reachable subspace `V`, the substitution is exact for **every** cache history iff `(p_dt - p_rt) v M = 0` for every key `t` and every `v ∈ V`. If `M` is nonzero on `V`, the condition reduces to equality of the two attention distributions key by key. On a finite correlated model trace, cancellation can give additional accidental equalities; none is licensed by shared GQA value storage alone. This is a real-linear map theorem, not an FP32 rounding identity. A missing head with no retained partner cannot use this shortcut. The transfer in the parent image goes between distinct heads, so it cannot generally be pushed into a head-local V producer ahead of unequal attention distributions.

The approximation keeps the parent packed two-bit transfer, ten retained paid decoder groups, producer, value-cache bytes and online transfer/output terms unchanged. It skips one 28-coordinate value-weighted attention dot per eligible missing head/query/key; it does **not** remove the group's cached 28-byte value row when the other head or transferred missing heads still consume it. The changed map can also be viewed as folding `T_d` into the retained head's output decoder, but doing so would create a new, unpaid decoder image rather than preserve the parent's two-bit codes.

## Paid Qwen3-0.6B result

[`measure.py`](measure.py) loads the same pinned original-producer Q/K and paid rank-28 V/O images as the parent. It uses the parent's train-selected group sets, recomputes the paid-response least-squares transfer and the identical per-28-group two-bit quantizer, then observes the complete post-O output on four previously inspected 256-token validation windows. No held row selects a group, transfer code or substitution. Relative squared error is against the original-weight two-head output, not model loss.

| Layer / retained groups | Missing heads eligible for partner substitution | Value dots / 16 | Preserved paid-transfer error | Partner-substituted error | Substitution delta squared relative to preserved output |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 / 8 | 4 | 12 | .438055 | .486991 | .085789 |
| 0 / 10 | 4 | 12 | .413157 | .456104 | .068999 |
| 0 / 12 | 4 | 12 | .393022 | .442951 | .078418 |
| 0 / 14 | 2 | 14 | .385226 | .429174 | .066376 |
| 14 / 8 | 2 | 14 | .388559 | .397353 | .013444 |
| 14 / 10 | 2 | 14 | .375237 | .388176 | .015103 |
| 14 / 12 | 2 | 14 | .352990 | .367390 | .023372 |
| 14 / 14 | 0 | 16 | .338091 | .338091 | 0 |

For the ten-group image, skipping a quarter of the layer-0 logical narrow value products costs .042947 absolute teacher-relative squared error, more than a tenth of the parent's .413157 error. At layer 14 one eighth of the products costs .012939. Neither is a native speed measurement. Even if native arithmetic scaled linearly, score creation, count construction, cache reads, transfer and the 1024-row output decoder would still run. The image's .428472 V/O BPW does not change. This is a measured negative for **using a partner's unchanged distribution** on this frozen paid image, not for learned shared attention, query-dependent corrections or jointly fitted V/O codes.

The next useful construction must make two heads' attention distributions agree where the transferred value map observes them, or cheaply predict their weighted difference. A model-trained shared-support or corrected-attention representation has a path to skipping a dot; simply noticing that the two heads share K/V storage does not. Fit that representation to causal post-O or language loss with quantized upstream producers before pricing a GPU reader.

CPU receipts, source/parent/model/capture/image/decoder hashes and four per-window errors are in [`data/kelana-subbit/value-transfer-commutation/`](/path/to/workspace/data/kelana-subbit/value-transfer-commutation/README.md). No GPU lock, executable or service changed.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-transfer-commutation/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
