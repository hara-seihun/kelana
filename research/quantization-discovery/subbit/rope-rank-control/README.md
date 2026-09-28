# A dense rank control for the RoPE-plane score map

The 112-plane causal mask has a genuinely cheaper producer: it projects only selected Q/K output rows and rotates only those planes. How much attention quality does that constraint cost at the *same key-cache width*? I fitted an unrestricted post-RoPE rank map on the original-producer Q/K captures, shared across the two query heads of each GQA group. It is a quality control, not a proposed cheap native image.

For each group let `q` be either observed query head and `k` its rotated key, both in 128 real coordinates. The observed score is `qᵀk / sqrt(128)`. The alternative stores `Bᵀk` in the cache, computes `Aᵀq` once per query and scores their rank-`r` dot product. The ranks equal *twice the plane counts of the frozen exhaustive-mask image*, separately for every group. Both maps therefore have 224 logical BF16 key coordinates over eight groups, 448 score products per key across two heads, and one padded 64-byte cache line per group. The mask and the dense fit see the same eight train windows and four previously inspected validation windows.

## Conditional optimum and its limit

Let `Cq = E[qqᵀ]` pool both query heads, and `Ck = E[kkᵀ]`, using the uncentered train second moments. On an **independent** draw of query and key, the squared score error of `M = ABᵀ` is

`E[(qᵀ(I-M)k)²] = ||Cq^(1/2) (I-M) Ck^(1/2)||_F²`.

If the two moments are positive definite, whitening is invertible and rank is preserved. The truncated SVD of `Cq^(1/2) Ck^(1/2)` therefore gives the global rank-`r` minimum in this independent-second-moment family; unwhitening its two factors gives `A,B`. This is Eckart-Young applied to the **complete bilinear score map**, rather than PCA of keys alone. It needs neither original per-plane contributions nor weight reconstruction online. The measured train second moments are positive definite. The retained independent-score energy is 0.920–0.999 across layer-0 groups and 0.944–0.997 across layer-14 groups.

Real causal pairs are not independent, and softmax KL is not squared score error. The theorem is not an optimality certificate for the measured attention objective. The fit has no causal or gold-loss training. It simply gives a strong, deterministic control with an exact conditional objective.

## Held attention result

The original BF16 Q/K projection and RMS normalization feed FP32 RoPE and scores. All 256 causal queries per validation window enter the comparison; each sees every eligible key. The learned factors are fitted on eight other 256-token train windows. The paid-rounding arm stores both factors in FP16 and the compact key coordinates in BF16.

| Layer | Frozen whole-plane mask KL | Real rank KL | FP16 factors, BF16 cached-key KL | Held score-variance, mask → paid rank |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .301353 | .185974 | .186049 | .361953 → .240111 |
| 14 | .432293 | .221056 | .221107 | .965535 → .393954 |

All four previously inspected validation windows improve in each layer. At layer 0 the paid rank arm scores `.181373, .199588, .173264, .189971` versus mask `.296971, .324062, .284893, .299484`. At layer 14 it scores `.194338, .255618, .206954, .227518` versus `.446155, .434758, .419644, .428617`. This is a real original-producer causal-attention gap at matched cache width, not complete-model language quality or fresh-text generalization. The earlier group-indexed key affine closes some of the plane gap at much lower cost, to `.229924/.343980` held KL, and remains a distinct control.

## The bill for the extra quality

The dense post-RoPE map cannot be described by the cache bytes alone. FP16 `A` and `B` add `2 × 128 × 224 × 2 = 114,688` bytes per layer, or `.29167` extra bits per original Q/K weight before quantizing the producer. Its online factor preparations cost `128 × 224 = 28,672` real products for the eight keys and `128 × 448 = 57,344` for the sixteen queries per token/layer, plus factor loads. Both are activation-dependent and included here rather than moved outside an inference timer. The selected-plane image needs only 224 K and 448 Q output rows of its 1,024-input projection. A dense post-RoPE encoder must instead first form all 1,024 K and 2,048 Q coordinates and rotate them, then apply the factors. Under a plain dense projection count that is 3,145,728 producer products rather than 688,128, before the 86,016 factor products. A factorized sub-bit producer changes the exact instruction bill but cannot simply claim the selected-row saving for this map.

The obstruction is structural. For a generic dense column of `B`, its inverse-rotated coefficient vectors across positions 0–127 span every nonzero RoPE frequency plane. When it has a nonzero component in all 64 planes, the ordinary distinct-frequency Vandermonde argument gives full rank 128. A fixed selection of fewer pre-RoPE K rows cannot compute `BᵀR_t k` for arbitrary `k,t`. This is a statement about exact fixed-row producers, not an impossibility claim for trained lossy producers, position-aware factors or a finite reachable activation domain. The same warning applies to the query projection. The half-precision factor arm does not include paid Q/K weight codes; original projections remain BF16 source weights.

The next useful construction should close part of the `.186/.221` versus `.301/.432` causal gap *without paying for all full-width Q/K producers and two dense rank preparations*. Try a RoPE-equivariant or sparse cross-plane rank grammar and learn its selected producer rows against quantized-upstream causal attention/post-O on separate text. A native kernel for this unrestricted control would optimize the expensive wrong boundary.

`measure.py` fits both layers without a GPU. `/path/to/workspace/data/kelana-subbit/rope-rank-control/layer{00,14}.json` retains the ranks, masks, individual held KL/variance, independent-score energy and source/model/capture/parent hashes. From the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-rank-control/measure.py --layer 0 --output /path/to/workspace/data/kelana-subbit/rope-rank-control/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-rank-control/measure.py --layer 14 --output /path/to/workspace/data/kelana-subbit/rope-rank-control/layer14.json
```

Bonsai's executable, numerical defaults and resident service did not change.
