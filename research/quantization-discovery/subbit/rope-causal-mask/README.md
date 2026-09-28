# A causal Q/K plane mask beats weight-covariance selection

The [112-plane allocation](../rope-plane-rate-allocation/README.md) chose Q/K RoPE planes from the original projection weight covariance with isotropic hidden inputs and uniformly distributed relative offsets. That is a useful cost construction, but it is a bad proxy for the actual attention distribution. Here the *same* 112 whole planes, at most 16 per GQA group, are selected using the original model's causal Q/K responses. Both query heads of a group share the selected key planes. The selected query/key score map remains a 224-scalar logical key, 448 scalar products for two heads per key, and eight padded 64-byte key lines per token/layer. Neither arm decodes a 128-coordinate key.

## Local objective and construction

Let `s_tj` be a teacher attention logit and `z_tj,i` the contribution of RoPE plane `i`, so `s_tj = sum_i z_tj,i`. For a causal query row with teacher distribution `p_t`, omitting a set `D` changes the logits by `-sum_(i in D) z_i`. The second derivative at the *original logits* of `KL(p_t || softmax(s_t + epsilon delta))` is `Var_(j~p_t)(delta_j)`. Its exact quadratic form for a fixed row is `1_D^T Cov_(j~p_t)(z_tj) 1_D`. This is a local curvature identity, **not** an equality with finite-mask KL. It includes the softmax's invariance to a row-constant score and both heads' causal key frequencies. The only exactness claimed is the real-valued local derivative; the executed Q/K projection, RMSNorm and RoPE use the existing BF16/FP32 model operations.

Eight pinned 256-token train windows from the layer-0 and layer-14 original-producer captures supply Q/K inputs. Per query, 16 keys are drawn with replacement from its actual masked teacher softmax. The centered sample covariance with denominator 15 is an unbiased estimate of that row's 64-plane Fisher Gram. The seeded draws and all eight groups' resulting 64x64 Grams are in the receipts. One-for-one plane exchange gives one feasible mask for each group/count 4..16; a dynamic program optimizes the 112-plane allocation *conditional on those masks*. We also keep uniform counts and the earlier weight-derived counts, changing only their selected planes. This does not establish global mask optimality. Four separate 256-token validation windows evaluate every causal key exactly, with no sampling in the reported teacher attention KL or finite-mask Fisher variance.

## Held attention result

Each entry is mean `KL(original attention || compressed attention)` over 16 heads and four held windows. Fisher is the mean teacher-weighted variance of the omitted score, not KL. All arms keep 112 planes and one padded line per group. There are no learned gains or extra metadata compared with the weight-only masks.

| Layer | Mask selection | Held KL | Held Fisher variance |
| ---: | --- | ---: | ---: |
| 0 | Uniform 14, weight covariance | 1.470106 | .885837 |
| 0 | Allocated, weight covariance | 1.460407 | .869052 |
| 0 | Uniform 14, causal curvature | **.366896** | .349106 |
| 0 | Weight counts, causal planes | .384649 | .337657 |
| 0 | Allocated, causal curvature | .372829 | **.326647** |
| 14 | Uniform 14, weight covariance | 2.759048 | 5.389645 |
| 14 | Allocated, weight covariance | 2.782441 | 5.615116 |
| 14 | Uniform 14, causal curvature | .520572 | .847631 |
| 14 | Weight counts, causal planes | **.488532** | .805460 |
| 14 | Allocated, causal curvature | .498204 | **.695943** |

Every held window favors a causally fitted mask over the corresponding weight-only uniform mask. The causal rank allocator minimizes its sampled train quadratic but **does not win finite attention KL**: uniform causal is better at layer 0, and fixed weight-derived counts with causal plane fitting are better at layer 14. That disagreement is precisely where a finite-KL or downstream fitting objective, rather than another exact quadratic allocator, is needed. The large causal versus weight-only gap means the earlier .44/.57 retained weight-variance figures cannot select a mask for real attention. The selected geometry is still severely lossy: .37/.49 KL after a single layer's Q/K score change is not evidence of viable whole-model quality.

The boundary matters. This is original-producer text captured before quantizing earlier layers, original BF16 Q/K matrices, and four already existing validation windows. No sub-bit Q/K weight image, quantized upstream, post-O/model loss, or native timing is claimed. The next experiment should fit paid selected-row Q/K codes jointly with the plane mask on **quantized-producer train text**, select by finite causal attention/post-O loss, and freeze the image before fresh model evaluation. Compare at equal total stored bytes and include code-to-selected-row producer work. The local Fisher construction is a strong initializer, not the image selector.

The source is `fit.py`. Model, capture, source and earlier weight-receipt SHA256 values, exact masks, train Grams and individual held-window metrics live under `/path/to/workspace/data/kelana-subbit/rope-causal-mask/layer{00,14}.json`. Reproduce on CPU without a GPU lock:

```sh
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/rope-causal-mask/fit.py --layer 0 --output /path/to/workspace/data/kelana-subbit/rope-causal-mask/layer00.json
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/rope-causal-mask/fit.py --layer 14 --output /path/to/workspace/data/kelana-subbit/rope-causal-mask/layer14.json
```

Bonsai's executable, GPU and resident service did not change.
