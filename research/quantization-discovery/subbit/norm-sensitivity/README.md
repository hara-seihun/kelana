# The wider paid score mask changes the sparse K norm's safe support

The 128-plane Q/K observer fills its existing eight 64-byte key-cache lines. Its [positive sparse denominator](../cache-slack-norm/README.md) emits 384 of 1,024 raw K rows per layer: 256 score rows and sixteen additional norm rows per group. I asked whether the lowest fitted norm coefficients still need their raw rows. This is a producer-work question. The cached keys, paid binary Q/K factors, selected planes, group affine and two-head score are fixed.

The answer differs by layer. At layer 0, a train-only causal-CE rule drops five four-row strata, leaving 364 raw rows and lowering the four-window mean held causal KL from .253286 to .253040. At layer 14, the rule keeps all 384. Deleting one stratum with coefficient .0732 raises its group's held KL from .227814 to .244497 without refit and .234948 after refit. The same kind of trap appeared at 112 planes, but that result could not be transferred to these new masks: the score-selected rows and denominator features have changed.

| Layer | Candidate strata with coefficient at most .1 | Train-accepted deletions | Raw K rows | Signed factor terms/token | Held two-head KL before / after |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 5 | 5 | 384 to 364 | 360,448 to 355,328 | .253286 / .253040 |
| 14 | 2 | 0 | 384 | 360,448 | .325664 / .325664 |

The layer-0 per-window means move `[.256872, .270101, .240045, .246124]` to `[.256757, .269877, .239721, .245806]`. Three of four candidate groups improve held KL after refit; group 3 worsens .240492 to .241596 despite improving smooth train CE 2.460538 to 2.459200. The train rule accepted it, and the aggregate still improves. Layer-14 group 1's refit improves its held KL .313457 to .313008, but its smooth train CE rises 2.888777 to 2.888795, so the rule rejects it. Group 4's train CE rises more decisively, 2.142080 to 2.146828. Neither held comparison chose the support.

## Why a small coefficient is not a row certificate

For one query, let `b_k` be its paid score numerator for key `k`, `d_k>0` the sparse squared-norm denominator, `z_k=b_k/sqrt(d_k)`, `t_k` the teacher attention probability and `p_k=softmax(z)_k`. On causal keys, the smooth cross-entropy has the exact derivative

`d CE / d d_k = (t_k - p_k) z_k / (2 d_k)`.

A deleted stratum changes many `d_k` at once. Its influence depends on teacher-versus-candidate probability error, the signed score and the key's norm, not just on its fitted positive coefficient or its contribution to mean squared energy. Softmax also couples all keys in a query. This derivative is for the smooth FP32 fitting map; held evaluation rounds the raw and normalized K values to BF16, so it is not a proof of BF16 finite-loss monotonicity. It does give a cheap train-side ranking for a future support search. A threshold on coefficients alone cannot certify a safe deletion.

The fit follows the parent observer's eight train windows and sixteen strided query positions per window. For each candidate group I zero all four row outputs of every stratum at or below .1, refit the surviving coefficients with the parent's bounded L-BFGS-B finite causal objective, round coefficients to FP16, and keep the deletion only if its *unpenalized smooth train* CE does not exceed the original. The held replay computes BF16-normalized full causal attention on four already inspected validation windows. These windows are not fresh model selection data. The refit is not a globally optimal support search. This experiment did not change Q/K codes, the norm-row sampler, or upstream hidden states.

A packed layer-0 K output factor would remove 20 output sign rows, 640 sign bytes and 5,120 signed output terms/token compared with the 384-row parent. The input factor still costs 262,144 signed terms/token, so this is only 1.42% of that producer's total. Sampled-row indices lose 20 bytes and five FP16 coefficients lose 10 bytes. The logical 256-coordinate score cache, its 512-byte line-padded payload and 512 two-head products per key do not change. The full factor was retained for CPU replay; no native time or whole-model language loss was measured. Layer 14 retains its parent cost. This modest gain does not justify a native producer on its own.

The more useful next question is whether score-selected rows, norm support and binary K output codes can be learned together on **quantized-upstream** train text, then frozen for independent post-O and gold-loss evaluation against an equal-paid-rate control. A fixed parent whose best layer-14 deletion costs causal KL says not to transplant a row support from an easier layer or narrower mask.

## Reproduction and custody

`measure.py` replays only the six groups with coefficients at or below .1; unchanged groups are read from the hashed parent. `summarize.py` checks all eight parent identities and candidate hashes and writes per-window means, selected supports and cost totals. Group and summary receipts are in `/path/to/workspace/data/kelana-subbit/norm-sensitivity/`. Each group receipt includes the source, model, capture, Q/K images and parent hashes, its coefficients, unpenalized train CE and four held KL values. From the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/norm-sensitivity
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=2 "$P" "$D/measure.py" --layer 14 --group 4 --refit --output /path/to/workspace/data/kelana-subbit/norm-sensitivity/layer14-group4.json
python3 "$D/summarize.py"
```

CPU original-producer study only. The Bonsai executable, GPU and service were unchanged.
