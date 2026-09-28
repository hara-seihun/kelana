# Paid Q4/Q5 allocation for routed down experts

The installed Qwen3.6-35B-A3B layer-0 down bank is Q5_K. [The train-weighted Q4_K recoding](../down-route-quant/README.md) incurs 0.04611 relative RMS error in the score-weighted eight-expert output on 126 held real producer tokens. This experiment asks whether retaining Q5_K for the experts with the largest observed train error buys a useful middle point. It is a complete 256-expert bank allocation, not a per-token format switch or free side table. The native reader already supports both formats, but no mixed GGUF was built or run.

We recoded each expert once using the earlier train-weighted native GGML Q4_K quantizer. For every real routed train and held slot we saved the score-weighted output difference between decoded Q4_K and decoded installed Q5_K, using the same FP32 BLAS multiplication as the earlier study. Ranking experts by the sum of squared train-slot differences requires no held data. At each paid budget the top-ranked experts keep installed Q5_K and all others take the Q4_K recode. Evaluation adds all eight selected differences per token before squaring, so cancellation is retained. The comparison denominator is the earlier decoded Q5_K weighted output.

| Experts kept Q5_K | Layer down-bank bytes | Held Q4 assignments / 1008 | Train output RMS | Held output RMS | Whole-model one-read saving if repeated over 40 layers |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 150,994,944 | 1008 | .03293 | .04611 | 1.597% |
| 32 | 155,189,248 | 690 | .01596 | .02688 | 1.397% |
| 64 | 159,383,552 | 507 | .00837 | .02291 | 1.198% |
| 128 | 167,772,160 | 207 | .00172 | .00887 | .7985% |
| 192 | 176,160,768 | 49 | 0 | .00743 | .3991% |
| 224 | 180,355,072 | 29 | 0 | .00546 | .1996% |
| 256 | 184,549,376 | 0 | 0 | 0 | 0 |

The cost denominator for the last column is 2,626,187,904 conditional one-read bytes per token. Each Q4_K expert saves 131,072 stored bytes. The fractional whole-model figure assumes the same allocation in all forty layers, not that one layer's measured fidelity transfers to them. It excludes grouping, caches, native Q4/Q5 timing and changes to the sum kernel. Rate is the full expert bank, including experts not observed on either split.

Sparse train routes matter. By 192 retained Q5 experts, every train-assigned expert stays Q5 and train error is exactly zero. The 35 experts seen only on held still receive Q4. Even spending 95.6% of the original down-bank bytes leaves .00743 held RMS because those experts cannot be ranked by this train-only local signal. As a diagnostic, ranking on held error directly gives .01089 held RMS at 64 retained Q5 experts and .00301 at 128. This is hindsight selection, not a deployable optimizer or a lower bound on the best mixed image. Train frequency instead of train error gives .02621 and .01128 at those budgets. The train-error ranking helps, but the small capture does not learn rare-expert priorities.

This result closes a cheap path from local Q4 down recoding to a useful mixed bank. A half-Q4 bank saves only .7985% of the conditional whole-model stream and still changes the layer-0 routed output by .00887 RMS. That does not predict complete-model held language loss. Before implementing a mixed reader or another per-expert ranking rule, obtain broader disjoint producer routes and measure a complete mixed image's held language loss alongside native Q4/Q5 timing. Gate/up recoding offers a larger byte prize than down-only allocation.

The contract is decoded installed Q5_K weights, Q4_K trained only with 113 train tokens, captured 113/126 actual post-SwiGLU inputs and normalized route scores, FP32 CPU BLAS products, and FP64 eight-slot accumulation. This is not bit-identical native FP32 arithmetic. The source and four disjoint hashed shard arrays are in [the receipt](/path/to/workspace/data/qwen-moe/down-rate-allocation/receipt.json); the complete per-budget train and held results are there too. Model and resident service were unchanged and no GPU was used. Reproduce in a registered Kelana checkout with `OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4`:

```sh
for span in '0 32' '32 128' '128 224' '224 256'; do
  set -- $span
  python3 research/moe/down-rate-allocation/experiment.py --first "$1" --last "$2" \
    --output "/path/to/workspace/data/qwen-moe/down-rate-allocation/part-$1-$2.npz"
done
python3 research/moe/down-rate-allocation/experiment.py --summarize
```
