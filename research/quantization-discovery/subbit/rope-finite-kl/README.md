# Fit the finite attention loss, not only its tangent

The causal Fisher mask study selected whole RoPE planes with a quadratic measured at the *original* attention logits. Removing 50 planes per group is not a small perturbation. I kept its 112-plane, maximum-16-per-group Q/K score consumer and optimized the actual teacher-to-masked causal attention KL instead. The selected key planes are shared by both observing query heads. No stored byte, key-cache element, score product or online instruction changes relative to each starting mask.

For a teacher row with probabilities `p`, plane contributions `z[j,i]` and selected planes `S`, the mask-dependent part of KL is exactly

`log(sum_{j<=t} exp(sum_{i in S} z[j,i])) - sum_{j<=t} p[j] sum_{i in S} z[j,i]`.

The discarded teacher entropy is independent of `S`. The row-constant logit direction cancels exactly. At each step I rank single remove/add pairs by the derivative of this expression with respect to their score difference, then **evaluate the exact finite expression** for the best twelve ranked pairs. A strictly improving pair is accepted; six steps per group are allowed. This is a feasible local search, not a global optimum over masks. The derivative only makes a shortlist, and the selected change is charged its full finite softmax cost. The three starting allocations are the previous uniform, weight-derived-count and Fisher-allocated causal masks; each preserves its own group counts.

Eight 256-token original-producer train windows supply every causal key for sixteen deterministic query positions, `64,76,...,244`, in both heads. Four separate validation windows supply *every* causal query/key, without sampling. The preceding study already inspected these validation windows; they are a held response check, not fresh model selection. Q/K projection and norm follow the original BF16 execution, RoPE and score use its FP32 computation. The fitting objective is computed on rounded captured contributions, not an FP32-identical claim for a native compressed model.

| Layer | Starting counts | Held attention KL before | Held attention KL after | Exchanges across eight groups |
| ---: | --- | ---: | ---: | ---: |
| 0 | uniform 14 | .366896 | .304851 | 12 |
| 0 | weight-derived | .384649 | .318343 | 11 |
| 0 | Fisher-allocated | .372829 | **.300849** | 14 |
| 14 | uniform 14 | .520572 | .462713 | 3 |
| 14 | weight-derived | .488532 | **.447792** | 2 |
| 14 | Fisher-allocated | .498204 | .480945 | 5 |

On layer 0 the best finite arm lowers the best previous held KL by 18.0% (`.366896 -> .300849`). On layer 14 the best arm lowers it by 8.3% (`.488532 -> .447792`). The two improvements are not tied to the same starting allocation, and the held windows all improve for each winning arm. The algorithm does not change rate or online work. This is the first demonstration on these captures that optimizing the *finite* loss over a fixed RoPE-compatible score grammar buys more than using its tangent to allocate ranks. There is still substantial attention damage, and Q/K are not quantized here.

The immediate native-relevant experiment is to learn paid selected-row sub-bit Q/K producers with both heads and the finite causal consumer on **quantized upstream** train text. Keep an equal-byte binary Q/K image and a frozen Fisher-mask control; evaluate held post-O and complete-model gold loss before timing a narrow key cache. Optimizing another original-producer mask on the same validation windows will not resolve the dominant producer interaction.

`fit.py` is CPU-only. Each receipt stores initial/final masks, all accepted exchanges, train cross-entropies, the individual held KL and score-variance windows, and source/model/capture/prior-receipt SHA256 hashes. Reproduce from the Kelana root with the installed model environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-finite-kl/fit.py --layer 0 --output /path/to/workspace/data/kelana-subbit/rope-finite-kl/layer00.json
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-finite-kl/fit.py --layer 14 --output /path/to/workspace/data/kelana-subbit/rope-finite-kl/layer14.json
```

No GPU reservation, Bonsai executable or serving map changed.
