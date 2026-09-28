# Query-only base selection misses the causal-score opportunity

The frozen paid Q/K image admits two three-dot programs per GQA group. Either query head can supply the two-dot signed-byte base score; the other gets a one-dot signed-nibble difference correction. A fixed base is chosen on train text in the [shared-query study](../shared-query-base/README.md). I asked whether the current query could choose between those two programs without reading cached keys or teacher scores. This would keep the 768 signed-nibble products/key/layer and 128-byte signed-nibble key cache fixed, although the decision itself must be paid.

It cannot choose well using the natural full-covariance score-error objective. Both original-producer Qwen3-0.6B layers get worse on four inspected validation windows:

| Layer | Static train-KL base | Query-only covariance choice | Held per-query teacher oracle | Four-dot control |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .278608 | .282715 | .269235 | .275431 |
| 14 | .334929 | .335671 | .324255 | .332396 |

These are mean teacher-to-candidate causal attention KL over two heads, eight groups, four 256-token validation windows. The oracle chooses a base separately at each query/group by comparing both candidate rows against the teacher. It is **not** an executable selector. It shows .009373/.010674 KL of conditional headroom under unchanged key labels and three key dots, but even a full train-key covariance detects the better base on only 52.39%/49.57% of held query/group positions. The covariance policy switches away from the fixed base on 47.38%/49.32% of positions. It loses on train too, .257970→.262085 and .299321→.299962.

## Conditional calculation and cost

For each group, let `a_0,a_1` be the two step-scaled real queries and `c` its signed-nibble key. For each base `b`, round `a_b` dynamically to signed eight bits and `a_(1-b)-a_b` to one signed nibble. Denote the resulting errors of the two reconstructed query vectors by `e_b, e_(1-b)`. The score errors against this *same-code floating-query* map are `e_h · c / sqrt(128)`. If a centered cached key is drawn independently of the query from the train distribution, the sum of conditional squared score errors is exactly

```
(e_0^T C e_0 + e_1^T C e_1) / 128,
C = E[(c-E[c])(c-E[c])^T].
```

The policy selects the lower of those two quadratics, with the covariance fitted from eight train windows. Centering removes only a score constant under softmax when the same offset applies to all keys. This is an exact least-squared-score decision under the **independent stationary-key** assumption; it does not minimize causal softmax KL. The actual causal prefix selects keys dependent on query position, softmax weights emphasize a few keys, and the teacher itself includes projection errors. A second-order causal Fisher metric would depend on the occupied prefix and the predicted scores. Its online cost must be counted, not moved outside the query.

The selected score program still uses two base nibble dots and one correction nibble dot per key, plus an addition for the non-base head. The new selector evaluates *both* candidate query roundings, forms four 32-dimensional residuals per group and scores their 32-by-32 quadratics: 32 dense quadratic forms, roughly 32,768 scalar matrix-vector products per token/layer before choosing the base. Eight full FP64 train covariances take 65,536 bytes as fitted; an FP16 deployment would take 16,384 bytes and has not been evaluated. There is no native speed, complete-model NLL or new weight BPW result. The eight-bit base is split into two signed-nibble dots as in the parent. This CPU replay does not claim bit-identical FP32 scheduling.

`measure.py` reloads the frozen binary Q/K images, the train-selected 32-coordinate signed-nibble K image and original-producer captures, then computes both score maps per query. Receipts at `/path/to/workspace/data/kelana-subbit/shared-query-adaptive-base/layer{00,14}.json` retain per-window/group static, covariance and teacher-oracle KL, decision agreement, key/work costs, and SHA-256 of source, original model, capture, paid factors, key image and parent. Reproduce in the installed CPU PyTorch environment:

```sh
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
    research/quantization-discovery/subbit/shared-query-adaptive-base/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/shared-query-adaptive-base/layer$(printf '%02d' "$layer").json"
done
```

Do not add this selector to the native score reader. The oracle gap makes a different question worthwhile: fit the paid query/key labels and a cheap, causal-aware base policy together on quantized-producer text, or derive a prefix summary that predicts the softmax-weighted *difference* of the two candidate errors for less work than the fourth dot. A better stationary key covariance alone is not the missing instruction.
