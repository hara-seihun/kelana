# A RoPE-compatible narrow Q/K score consumer

The [fixed-decoder orbit bound](../rope-key-orbit/README.md) needs 128 post-rotation key dimensions even for a rank-one producer. That bound does not apply if the consumer keeps whole RoPE planes and projects both Q and K before scoring. Here is a concrete 28-coordinate map with no per-key dense decoder, and a bound on what its coordinate restriction costs.

## Map and proof

For each of Qwen3-0.6B's eight KV groups, choose a set `S` of 14 out of 64 RoPE planes, shared by its two query heads. Store the two real components of each selected rotated key plane; rotate the same selected query planes and form their ordinary 28-term dot product. The projection `P_S` commutes with every RoPE rotation because a whole plane is either retained or removed. Thus the native score is exactly `qᵀ P_S R_(key-query) k` over real arithmetic, with 28 stored key scalars, 28 query scalars per head and no reconstruction of a 128-dimensional key. Relative to the original real score, the discarded plane scores are an intentional approximation. BF16 operations and softmax do not inherit an exactness guarantee from this identity.

For an explicit tractable domain, draw the unrotated query and key hidden inputs independently from zero-mean isotropic distributions with unit covariance, then apply the *original* BF16 Q and K projection weights cast to FP64. Give each of the two query heads half weight. Average relative key rotations uniformly over offsets 0–4095. This is a weight-induced score-variance surrogate, not actual token behavior: no query/key norm, bias, causal frequency distribution, softmax, quantized producer or model continuation enters it.

Let `Cq` be the mean covariance of the two query heads and `Ck` the finite-rotation-averaged key covariance. Write the score as the sum of the 64 plane scores. Their Gram matrix is `M_ij = sum_(a in plane i, b in plane j) Cq_ab Ck_ab`. For a retained set `S`, its *score error* is exactly `sum_(i,j not in S) M_ij`; divide by `sum_(i,j) M_ij` to compare groups. The script uses the complete cross-plane Gram. A reverse greedy deletion followed by exhaustive single-plane exchanges chooses a shared 14-plane set from the real Q/K matrices. This is a feasible set, not a certificate of global optimality among all 14-plane sets.

There are two useful certified controls. With isotropic queries, `Cq=I` and the Gram is diagonal. Choosing the 14 planes with the largest sum of their two K-row energies is therefore **globally optimal within all 14-plane masks**, for every horizon, even though the rotated key covariance itself has off-plane structure. For the actual Q-weighted domain, the Ky Fan sum of the largest 28 eigenvalues of `Cq^(1/2) Ck Cq^(1/2)` is the **best continuous rank-28 post-rotation linear encoding/decoding**. It is an upper bound on any plane mask's score-variance retention, but its arbitrary post-rotation coordinates need not have this cheap RoPE consumer. These controls do not bound nonlinear or input-dependent programs.

## Pinned-weight result

All figures are arithmetic means of the eight groupwise retained score-variance fractions. The Q-weighted column uses the same 14-plane mask for both query heads. `Unrestricted` is a rank-28 continuous upper bound in that same Q-weighted domain, not a native program.

| Layer | Best 14-plane isotropic score | Best unrestricted rank-28 isotropic post-RoPE | Q-weighted score with isotropic mask | Q-weighted feasible mask | Unrestricted rank-28 Q-weighted |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .343273 | .379899 | .424727 | **.443464** | .520303 |
| 14 | .412793 | .444175 | .483917 | **.563333** | .653300 |

The unrestricted isotropic values are from [the previous finite-orbit receipt](../rope-key-orbit/README.md), on the identical model, horizon and groups. The Q-weighted masks gain .018737/.079416 over selecting by K energy alone. No single-plane exchange improves the greedy sets; that local termination says nothing about distant replacements. At layer 0 the feasible mask's Q-weighted retained fraction ranges .354378–.664943 by group, versus .441327–.706645 at layer 14. The unrestricted-minus-feasible rank-28 gap ranges .048909–.147982 and .055961–.120238 across groups. Those nonzero gaps give the price of requiring a plane-preserving coordinate *under this surrogate*, and the isotropic columns make that price a certified .036626/.031382 averaged fraction within their respective domains.

At the online score boundary, the selected map needs 28 scalar products and 56 BF16 key bytes per group per occupied position, versus 128 products and 256 BF16 bytes for the full key. Across eight groups and 28 layers it saves 44,800 key bytes per occupied token, or 175 MiB at 4,096 occupied positions, before alignment and other caches. Both query heads can reuse each group's selected key loads. Rotation is 14 two-dimensional rotations per query/key rather than 64; the key coordinate can be produced directly by a learned selected-row or packed projection. This is a **logical cost**: it excludes factor projection, scale/code preparation, memory transactions, the unchanged V cache, score reduction, launch and register occupancy. Keeping the original full projection and slicing its output would still pay the full projection. BF16 selected rows themselves are not a sub-bit weight image, and we have no native latency or language-quality claim.

This narrows the next experiment. Fit the Q/K packed projections **with their plane mask and both head scores in the loss**, on causal positions produced by the quantized model, rather than training a generic rank-28 K decoder and expanding it at the score loop. Compare held attention KL, post-O error and complete-model gold loss with an equal-paid-rate binary Q/K control. Only after a useful quality point survives should a gfx1151 consumer price the projected rows, cache alignment and reduction. The present weight-only numbers indicate that plane selection is a credible cheap geometry, not that its omitted score variance is acceptable for real text.

`/path/to/workspace/data/kelana-subbit/rope-plane-consumer/receipt.json` holds every mask, group fraction, full covariance-score denominator, horizon and model/config/source SHA256. Reproduce on CPU:

```sh
cd /path/to/workspace/projects/kelana
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/rope-plane-consumer/planes.py \
  --output /path/to/workspace/data/kelana-subbit/rope-plane-consumer/receipt.json
```

No GPU reservation, Bonsai executable or serving service changed.
