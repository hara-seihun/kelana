# Fresh-window continuation of frozen Q images

This study tests whether the Q-consumer refinement observed on four pilot test windows transfers to previously unused WikiText-2 raw windows. It changes only `model.layers.0.self_attn.q_proj` in pinned Qwen3-0.6B (`c1899de289a04d12100db370d81485cdf75e47ca`); every other parameter remains BF16. It is **not** an all-layer quantization result. The four candidate images were frozen before selecting these windows; no image is fitted, tuned or selected on this evaluation.

`prepare.py` tokenizes each validation/test split with the pinned local tokenizer (`add_special_tokens=False`), excludes all earlier split-specific 256-token pilot and activation-capture windows, and selects nonoverlapping 256- and 1024-token windows with recorded seeds. Window boundaries and all token IDs are fixed in `manifest.json` and `tokens.npz` (SHA256 `a15ac68d83d34404ae18c929ae56dfd397b482d9a631a85d111791db1662e9d6`). The 256-token panels have 64 test and 32 validation windows; the longer-context panels have eight of each. They are different contexts, not extensions of the 256-token windows. The manifest records the corpus/tokenizer/model identities and starts. A fresh reference forward pass and all four candidates use the same token IDs per window. Each window contributes all positions except the first to next-token NLL, teacher-to-candidate KL and teacher argmax agreement.

The four frozen images are the rank-88 four-bit spectral seed, the same image after four output-coordinate MSE sweeps, the rank-88 four-bit attention-metric refinement, and the stronger rank-352 binary image after four train-response coordinate sweeps. The first three cost 140,704 packed factor/scale/descriptor bytes (.53674 matrix BPW); the binary control costs .53906 matrix BPW. No additional online adapter is used: images are expanded into BF16 dense Q solely to make this a common-model **quality** comparison, not a native speed test. The images and their exact SHA256 values are repeated on every per-window result: seed `4ed54c00e27951d86c1f62696214346527c67e74adcfa7691e0396ae2a10b35a`, MSE sweeps `ae68a137261145d58be529d688d3863247b16d78c8d7afd417802f61fc6e6794`, attention `c4cc8051e4a10e60edacb5010e98967f0b1223b8a0217d61c7c2cdadc250774a`, binary `f6c620ec721b81e50a6bbc6cf98cebc246b0041918ee161cdbea41a33a889f87`. `evaluate.py` switches that single Q weight under `torch.inference_mode()`; teacher probabilities and target labels are computed from the same original BF16 model. GPU jobs run one bounded foreground panel at a time through Bonsai's shared `run-batch-compare` reservation.

`results.json` contains every per-window sum, arm image identities and paired window-bootstrap 95% intervals (5,000 draws, fixed seed). Intervals resample windows, not tokens. They describe variation across these sampled windows; validation and test remain separate, as do 256 and 1024 contexts. The inference panels do not fit a factor or select a hyperparameter.

## Findings

The fresh 64-window test at 256 tokens **reverses the four-window pilot preference**: attention-refined Q and the strong binary control have practically equal NLL (3.61148 vs 3.61078), while teacher KL favors binary (.05807 vs .05278). The attention-minus-binary paired NLL difference is +.00070 nats/token (95% window-bootstrap interval −.00578 to +.00738; 32/64 windows favor attention); KL difference is +.00529 (+.00017 to +.01050). Agreement is 90.257% vs 90.306%. This does not transfer the pilot's attention advantage over the stronger binary control. The 32 fresh validation windows at 256 tokens instead favor attention slightly in NLL, 3.71561 vs 3.72187 (difference −.00626, interval −.01774 to +.00560), but not in KL, .05059 vs .04945. The NLL intervals overlap zero in both splits.

| Fresh split/context | BF16 NLL | Attention NLL | Binary NLL | Attention − binary NLL [95% paired CI] | Attention KL | Binary KL | Attention − binary KL [95% paired CI] |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Test, 64 × 256 | 3.58722 | 3.61148 | 3.61078 | +.00070 [−.00578, +.00738] | .05807 | .05278 | +.00529 [+.00017, +.01050] |
| Validation, 32 × 256 | 3.68829 | 3.71561 | 3.72187 | −.00626 [−.01774, +.00560] | .05059 | .04945 | +.00114 [−.00676, +.00954] |
| Test, 8 × 1024 | 3.33835 | 3.35585 | 3.35799 | −.00214 [−.00701, +.00282] | .03986 | .03739 | +.00247 [−.00274, +.00889] |
| Validation, 8 × 1024 | 3.28404 | 3.30594 | 3.30548 | +.00046 [−.00604, +.00650] | .05259 | .04639 | +.00620 [+.00198, +.01016] |

The eight-window long-context slices have too few independent contexts for a firm NLL ranking. On test at 1024, attention has a small NLL and argmax-agreement lead over binary; on validation at 1024, binary has a small NLL and agreement lead, and its teacher KL advantage is clearer. Both alternatives increase NLL relative to BF16. The seed and MSE-refined rank-88 images fare worse than either consumer-refined image in every fresh split: test 256 NLL 3.63054 and 3.62999, teacher KL .08203 and .08070. Thus the **benefit of targeting the attention consumer over projection MSE survives**, but its previously reported win over the stronger binary image does not reliably survive changed windows. Four plain-MSE output-coordinate sweeps do not recover this gap at the same bytes.

For context, the earlier four-window pilot reported test NLL 3.32228 attention vs 3.34220 binary and teacher KL .04963 vs .05987, whereas its validation had NLL 3.94727 vs 3.94229 and KL .08796 vs .07556. Those were different pilot windows and not pooled here. This larger, disjoint evaluation demonstrates window-dependent ranking, not a new quantizer selection. It still covers one quantized Q projection in a mostly BF16 0.6B model, not all-layer operation or another model family.

## Reproduce

```bash
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/fresh-evaluation
DATA=/path/to/workspace/data/kelana-subbit/fresh-evaluation
$P "$D/prepare.py" --out "$DATA"  # only for generating a NEW fixture, not for reproducing frozen IDs
# Copy the checked-in tokens.npz and manifest.json to DATA for the immutable result fixture.
# For each split, length and disjoint index panel, reserve the shared GPU:
/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 48s --exec \
  "$P" "$D/evaluate.py" --split test --length 256 --start-index 0 --count 2 \
  --data "$DATA" --out "$DATA/panels/test_256_000_001.jsonl"
$P "$D/summarize.py" --data "$DATA" --out "$D/results.json"
```

The fixed fixture lives beside this document, while the larger operational panel files live under `/path/to/workspace/data/kelana-subbit/fresh-evaluation/panels/`. The committed `results.json` includes their full per-window measurements. Do not rerun `prepare.py` over that fixture: it regenerates the `.npz` container and changes its byte hash, even if the token arrays are identical.
