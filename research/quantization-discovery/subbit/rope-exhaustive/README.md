# Exhausting the finite RoPE-plane exchanges

The preceding [finite-KL fit](../rope-finite-kl/README.md) shortlisted twelve single-plane exchanges by the derivative of causal attention cross-entropy. That derivative ranks infinitesimal moves, while removing one entire plane is finite. I evaluated **every** remove/add pair for each group's frozen plane count, accepted the best strict improvement, and repeated until no single exchange improved the sampled train loss. This asks whether the shortcut left a material same-rate improvement on the table.

For each train row, the target distribution is the original producer's full Q/K causal attention. The loss of a selected mask is `logsumexp(s_mask) - E_teacher[s_mask]`; teacher entropy is constant. The search examines `r(64-r)` exact finite candidates per iteration for a group of rank `r`. Each group keeps both query heads, sixteen strided queries per 256-token train window, all their causal keys, and its original plane count. The eight groups share a total of 112 planes, at most sixteen per group. The key payload remains eight padded 64-byte lines per token/layer, with 448 scalar score products per key across both heads. No mask is a paid Q/K weight image.

I started from the best held arm of the earlier run at each layer, using the held data **only for that inherited starting choice**, not to select an exchange here. The four validation windows have already been inspected by earlier studies; this is a same-capture method comparison, not a fresh estimate of model quality.

| Layer | Extra exchanges by group | Mean sampled-train cross-entropy before → after | Full held attention KL before → after | Held-window outcome |
| ---: | --- | ---: | ---: | --- |
| 0 | 0,0,5,2,0,1,1,0 | 2.340274 → 2.331924 | .300849 → .301353 | Two better, two worse |
| 14 | 1,1,2,0,1,3,3,1 | 2.509445 → 2.484207 | .447792 → **.432293** | All four better |

The layer-14 result is a 3.46% held KL reduction at the same rate and online score work. The layer-0 result is more important as a stop sign: exact local optimization of this small sampled-train objective slightly worsens its held average despite lowering train loss. There are no further improving one-plane exchanges on the sampled train rows in any of the sixteen resulting group masks, with an absolute loss threshold of `1e-7`. This is **not** global mask optimality, nor even local optimality for the full train attention rows. The numeric objective uses FP32 captured RoPE contributions and NumPy exponentials; it is not a bit-identity claim for native FP32/BF16 inference.

The next question should change the producer and observation boundary rather than iterate this mask optimizer again. Fit paid selected-row sub-bit Q/K projections jointly on quantized-upstream train continuation, and compare finite attention, post-O and gold loss to an equal-byte binary Q/K control on fresh text. Layer 0's train/held reversal argues for wider train coverage and a separate selection split. The current result gives a stronger equal-cost original-producer mask control at layer 14, not an end-to-end speed or quality win.

`fit.py` is CPU-only. The receipts at `/path/to/workspace/data/kelana-subbit/rope-exhaustive/layer{00,14}.json` retain all masks, exchanges, sampled-train losses, four individual full-validation KL and variance scores, source/model/capture/prior-receipt hashes and local-optimality flags. From the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-exhaustive/fit.py --layer 0 --output /path/to/workspace/data/kelana-subbit/rope-exhaustive/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-exhaustive/fit.py --layer 14 --output /path/to/workspace/data/kelana-subbit/rope-exhaustive/layer14.json
```

No GPU, Bonsai executable or resident service changed.
