# Refit the paid Q/K score consumer before changing its codes

The existing 112-plane RoPE mask and group-specific key affine were learned from original Q/K projections. I froze the actual refined binary Q and K images, projected the same captured inputs through both, and refitted the two-head causal score against the original Q/K teacher. The changed parameters are the 224 selected BF16 key affine entries already charged by the sparse group table. Neither image nor its factor work changes.

On four previously inspected held 256-token windows, the folded image lowers teacher-to-candidate causal attention KL at both measured layers:

| Layer | Prior group affine | Paid-Q/K refit, FP16 gain after affine | Paid-Q/K refit folded into BF16 affine | Full paid Q/K, all 64 planes |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .277716 | .263566 | **.263541** | .162115 |
| 14 | .488731 | .421752 | **.421567** | .288208 |

Every held window improves: layer 0 moves `[.279410, .301512, .262796, .267147]` to `[.264675, .284793, .249116, .255581]`; layer 14 moves `[.505947, .491629, .476970, .480378]` to `[.431019, .410846, .414724, .429678]`. The FP16 post-gain numbers are an intermediate fit, not the proposed consumer. Folding gains into BF16 affine loses no measurable quality here, though it is not a bit-identity claim. The full paid-image control is substantially better at more key-cache and score work. These windows have been inspected by earlier experiments; the result is a construction and local quality measurement, not an image-selection verdict on fresh text.

## Conditional fit and observation

For group `g`, let `z_{qk,p}` be the paid Q/K score contribution from selected RoPE plane `p`, for query `q` and causal key `k`, including the prior group affine. Both query heads observe the same selected key. For frozen paid projections, masks and prior affine, choose nonnegative gains `a_p` by minimizing the teacher cross-entropy

`mean_q [ log sum_{k<=q} exp(sum_p a_p z_{qk,p}) - sum_{k<=q} P_teacher(k|q) sum_p a_p z_{qk,p} ] + λ ||a-1||²`

with `0.25 <= a_p <= 4` and `λ=.002`. This is a convex finite-score objective in `a`, since its Hessian is the covariance of plane contributions under the candidate softmax plus `2λI`. The script uses L-BFGS-B to find a feasible fit; it does not claim a numerically certified optimum. Eight train windows supply sixteen strided causal queries each, starting at position 64; all keys before each query enter the fit. Evaluation uses every causal query and key in four separate validation windows. The teacher has original BF16 Q/K projections, BF16 RMSNorm and RoPE; the candidate has the paid binary Q/K projections expanded to BF16, the old group BF16 key affine and the same RoPE schedule. Both heads contribute to each group's fit.

The full paid Q/K control retains its original shared BF16 key norm affine and scores every plane. It is not an equal-cost competitor; it measures the selected observation's remaining loss. The candidate still computes every raw K output row for its norm denominator, exactly as the earlier sparse-affine image does.

## Storage and consumer bill

The frozen Q/K binary factors, their scales, 112 plane IDs, 224 cached BF16 key coordinates and 448 products per key across the two heads are unchanged. The selected group BF16 affine remains 448 bytes per layer, one normalization multiplication per selected coordinate. Each new table value is `BF16(old_group_gamma[p] * FP16(fitted_gain[p]))`; the stored gain vector and its 224 extra multiplications belong **only** to the diagnostic post-gain arm and are absent from the folded image. The full paid Q/K control carries 1,024 cached BF16 key coordinates and 2,048 products per key across the two heads. Cache-line padding, full raw K norm production, native sparse table loads and whole-model quality have not been measured here. Folding is a different rounded BF16 map, not a proof of FP32 distributivity or bit-identical behavior.

The conspicuous remaining gap to full paid Q/K points to an actual new experiment: train selected-row binary Q/K *and* their norm rule on quantized-upstream causal or post-O/gold behavior, using a same-byte full-score binary control and disjoint text. More scalar gains on the frozen producer will not recover omitted plane directions. The concurrent norm-sketch studies price ways of removing the full-row denominator; their map changes and costs are separate.

`/path/to/workspace/data/kelana-subbit/paid-qk-plane-gain/layer{00,14}.json` retains all four held scores per arm, every fitted and rounded affine entry, per-group train cross-entropies, source/model/capture/paid Q/K/prior hashes and cost counts. These are CPU results. No GPU lock, Bonsai runtime, installed executable or service changed. Each layer runs in a bounded command from the Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/paid-qk-plane-gain
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 0 --output /path/to/workspace/data/kelana-subbit/paid-qk-plane-gain/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 14 --output /path/to/workspace/data/kelana-subbit/paid-qk-plane-gain/layer14.json
```
