# A norm-only stopping certificate for the routed sum

The selected Qwen3.6-35B-A3B GGUF routes eight experts per token. Can a consumer stop after the high-score experts when it needs the layer-0 weighted sum to a stated local relative tolerance? This experiment grants an impossible advantage: each not-yet-evaluated expert's **actual output norm**, per token, is available for free. It never reads the omitted direction. The result is a bound on a narrow decision family, not a model-quality result or a native speedup.

Let `v_e = score_e * down_e(hidden_e)`, `p_k = sum_{e<k} v_e`, and `B_k = sum_{e>=k} ||v_e||_2`. All sums and norms in this study use FP64 on the captured FP32 values. Since the unknown remainder `r` has norm at most `B_k`, the target `y = p_k + r` has norm at least `||p_k|| - B_k`. Thus, when that denominator is positive,

```
||y - p_k|| / ||y|| <= B_k / (||p_k|| - B_k).
```

Stopping at the first `k` whose right-hand side is at most the requested tolerance certifies a *local real-arithmetic Euclidean error*, conditional on valid upper bounds for the missing output norms. Unlike a guessed shortlist, the decision uses only the partial sum, router order and scalar norm metadata. With exact omitted norms this is an optimistic version of this triangle certificate: an implementable upper bound on norms can only be looser. Computing exact omitted norms ordinarily requires the very expert work being skipped. Different directions might give a better certificate if they can be bounded cheaply, but that is a different information contract.

The two captured real-text splits contain 113 train and 126 held layer-0 token routes. The input is the installed 256-expert mixed Q4_K/Q5_K GGUF, including actual routed producer hiddens and scores. The observer uses graph callbacks, which have changed batched numerical maps in a separate diagnostic; these captures are not asserted to reproduce an uninstrumented serving graph. Router-score order is available before expert computation. Contribution-norm order requires the full output norm of every expert and is a hindsight control. Here are the **held** earliest-stop counts and conditional savings if every layer happened to behave like layer 0:

| Local tolerance | Order | Tokens stopping before eight | Mean experts skipped | One-read whole-model weight bytes saved, maximum |
| ---: | --- | ---: | ---: | ---: |
| 1% | router score or free norm | 0 / 126 | 0 | 0% |
| 5% | router score | 40 / 126 | .3651 | 1.063% |
| 5% | free output norm | 51 / 126 | .4683 | 1.363% |
| 10% | router score | 80 / 126 | .9127 | 2.657% |
| 10% | free output norm | 96 / 126 | 1.1111 | 3.234% |

One expert's assumed stream is 76,439,552 bytes, one eighth of 611,516,416 routed bytes. The complete conditional weight stream is 2,626,187,904 bytes/token. The last column multiplies the layer-0 skipped fraction across all forty layers; it is **not** a measured whole-model saving or a valid prediction for the other 39 layers. It grants zero cost for norms, route decisions, partial-sum materialization and extra launches, ignores native grouped-dispatch cache effects, and is before any observed-language-quality check. Prompt and decode routes need separate captures. No runtime change follows.

A useful contrast is the true error, which this certificate deliberately cannot inspect. On held, omitting the eighth expert in router order leaves .08363 aggregate routed-sum RMS; the norm-informed order leaves .06324. Even hindsight choosing the weakest output on each token leaves .06324 RMS, with only 53/126 tokens below 5% true relative error. At five percent, the norm certificate stops on 40/126 router-ordered tokens; at one percent it stops on none. The train split also certifies no 1% stops, and at five percent only 29/113 router-ordered tokens. At six retained experts, held five-percent certification succeeds on 5/126 router-ordered tokens or 7/126 with free norm order. The eighth expert is not generally a negligible vector.

This rejects this triangle-certificate policy as a large tight-tolerance opportunity on these captures. A sharper norm-only geometric certificate or a different observer is not ruled out. It does not rule out a learned replacement vector, a downstream observer less sensitive to this output, or a cheaper exact packed computation of all eight experts. The next useful MoE question is whether a consumer-aware representation can replace missing vector directions at a paid rate and pass complete-model loss; another scalar norm threshold will not deliver a large gain at tight local fidelity. Exact scheduling improvements should preserve the selected FP32 map rather than use this approximate stop.

`study.py` recomputes both panels and writes a source-, text-, token- and array-hashed receipt. The raw inputs and receipt live in `/path/to/workspace/data/qwen-moe/route-capture/` and `/path/to/workspace/data/qwen-moe/score-order/`. Run:

```sh
python3 research/moe/score-order/study.py /path/to/workspace/data/qwen-moe/route-capture \
  --out /path/to/workspace/data/qwen-moe/score-order/receipt.json
```

No GPU was used in this iteration. The original GPU-produced capture and its selected-runtime provenance are recorded in [Bonsai's route report](../../../../bonsai-halo/docs/qwen-moe-routes.md).
