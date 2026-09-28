# Causal gain on a fixed narrow Q/K score map

The [exhaustive mask search](../rope-exhaustive/README.md) left the original-producer layer-0 and layer-14 attention KL at .301353 and .432293. It held 112 of 512 RoPE planes across eight KV groups. Rather than search another mask, I fitted one shared scalar per retained key plane against finite causal attention loss. Both observing query heads use the same scalar. The fixed masks, 224 logical key coordinates, 512 padded BF16 key bytes per occupied token/layer and 448 score products per key across both heads stay put.

For plane `i`, scalar `a_i` multiplies its complete two-coordinate key vector after key RMSNorm and before RoPE. A scalar commutes with its plane's rotation, so this is also `a_i z_i` in the causal score. No 128-dimensional key reconstruction or extra work per attended key is needed. Fit `a_i` in [0.25,2] with L-BFGS-B to `mean(logsumexp(sum_i a_i z_i) - E_teacher[sum_i a_i z_i]) + .002 sum_i(a_i-1)^2`, independently for each KV group. The 16 strided queries per window from the eight existing train windows include every causal key and both heads. Round fitted scalars to FP16 before scoring all queries and keys of four separate held windows. Those windows have already been examined in the mask studies and are not fresh model acceptance data.

| Layer | Fixed-mask held KL | With FP16 shared gains | Relative reduction | Held windows improved |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .301353 | **.229977** | 23.7% | 4/4 |
| 14 | .432293 | **.343686** | 20.5% | 4/4 |

The fitted gains range .815–2.000 on layer 0 and .632–2.000 on layer 14; 3 and 7 respectively reach the upper bound. The four individual KL pairs and all paid gains are in the receipts. The selected masks are stationary under single-plane exchanges at *unit gains* on sampled train rows, but allowing this tiny amplitude family changes their observed attention substantially. The earlier [weight-covariance gain fit](../rope-plane-block/README.md) recovered less than .0006 retained variance. That negative does not transfer to a causal softmax observation.

This is an explicit rate and execution trade. The gains cost **224 FP16 bytes per layer** (112 shared scalars), or .000570 added bits per original Q/K matrix weight at this layer. Apply them once to the key producer after normalization: 224 scalar multiplies per key token/layer. Per-key attention work, cache width and cache-line count stay fixed. Folding them into the raw K weight rows is *not* generally valid because the following RMSNorm changes its denominator. A native BF16 post-normalization multiply and cache round may change the numerical map here: the experiment uses FP32 captured plane contributions, real-valued score multiplication with FP16-stored gains, and NumPy FP64 softmax. No paid sub-bit Q/K projection image, quantized upstream, post-O behavior, whole-model loss or GPU timing follows from this result.

The next question is whether these gains survive **paid selected-row sub-bit Q/K producer fitting on quantized-producer text**. Train the selected rows and gains together against both heads' finite attention and post-O observations. Freeze them against fresh model loss and a same-byte binary control before lowering the narrow key consumer. The result is a useful cheap score-map construction, not a reason to optimize the original-producer masks further.

`fit.py` is CPU-only. `/path/to/workspace/data/kelana-subbit/rope-causal-gain/layer{00,14}.json` records per-window held KL, FP16 gain values, train objective changes, optimizer status, masks and source/model/capture/prior hashes. Reproduce from the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-causal-gain/fit.py --layer 0 --output /path/to/workspace/data/kelana-subbit/rope-causal-gain/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-causal-gain/fit.py --layer 14 --output /path/to/workspace/data/kelana-subbit/rope-causal-gain/layer14.json
```

No Bonsai executable or resident service changed.
