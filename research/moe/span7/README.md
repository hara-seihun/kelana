# Can seven routed outputs reconstruct the eighth?

At layer 0 of the pinned Qwen3.6-35B-A3B GGUF, I treated the eight captured score-weighted expert outputs as vectors in 2,048 dimensions. The observation is their FP64 sum. For every token and every choice of one missing expert, I projected the complete sum onto the span of the seven retained vectors. This gives a *free hindsight* coefficient oracle: it already knows the missing output and chooses seven real coefficients per token. A real inference program cannot implement that choice without learning or predicting it.

| Layer-0 local relative RMS | 113 train tokens | 126 held tokens |
| --- | ---: | ---: |
| Best choice of seven, free per-token coefficients | .07036 | .06257 |
| Top seven by score, free per-token coefficients | .10186 | .08228 |
| Top seven, seven rank-wise gains fitted on train | .10313 | .08334 |
| Top seven, plus 32 train-learned directions, free per-token coefficients | .04762 | .08096 |

**No token on either split reaches 1% local relative error with *any* seven retained vectors**, even with the missing output in hand while solving. At 5%, the best-choice seven-vector oracle reaches 53/126 held tokens; fixed top-seven reaches 43/126. If each of forty layers behaved alike, those 53 skipped assignments would save at most 1.224% of a conditional whole-model one-read weight stream, before discovering which tokens qualify or paying for coefficient prediction. This is a one-expert-at-most family, not an adaptive multiple-omission ceiling. The prior [subset oracle](../subset-oracle/README.md) saves 73 assignments at 5% by allowing more than one omission on some tokens without replacement; the two questions should not be conflated.

I also learned one, eight and 32 shared output directions by SVD of train residuals after projecting the lowest-scored vector away from the top seven. The held evaluator grants hindsight coefficients for all seven retained vectors *and* the learned directions. Held RMS is .08226/.08193/.08096 at ranks 1/8/32; all three still have zero tokens below 1%. Train rank 32 improves to .04762 and eleven tokens below 1%, so this small capture strongly overfits a global residual basis. At FP16, 32 directions need 131,072 bytes per layer before scales, a tiny image compared with an expert, but applying and predicting their coefficients is not free. The 32-direction arm fails even with those online costs set to zero. This rejects a global train-residual SVD repair of the score-prefix omission on these captures, not a route-specific or nonlinear replacement trained on more data.

The rank-wise train-fit gains are 1.0068 to 1.0172. They barely change held RMS from the .08228 hindsight top-seven floor to .08334, and a fixed gain is not an input-specific replacement for the missing direction. More rank-wise scale training is the wrong next experiment. Capture disjoint, substantially larger real routes across layers, then fit a route-conditional predictor of *missing vector directions*, evaluate complete-model held loss at the paid image rate, and only then price a native consumer. An independent exact-engine question is still the unprofiled Q8 and routed Q4/Q5 phase gap.

The [hashed receipt](/path/to/workspace/data/qwen-moe/span7/receipt.json) identifies this script, train/held token/text/score/down captures, per-threshold counts and conditional bytes. The [capture provenance](../../../../bonsai-halo/docs/qwen-moe-routes.md) owns the model and installed observer. Recompute on CPU without a GPU reservation:

```sh
OPENBLAS_NUM_THREADS=1 python3 research/moe/span7/study.py \
  /path/to/workspace/data/qwen-moe/route-capture \
  --out /path/to/workspace/data/qwen-moe/span7/receipt.json
```

The proof of the oracle is elementary but matters: any linear combination of the retained outputs lies in their column span. Least squares finds its orthogonal projection of the full sum, so its squared Euclidean residual is no greater than that of any predicted coefficient rule using only these seven vectors. The direction arm projects the omitted residual onto the components of the fixed SVD directions orthogonal to the retained span. It is exact for that augmented span under FP64 linear algebra, not a claim of bit-identical native FP32 execution. The layer-0 callback can change graph arithmetic; these captured output vectors and their FP64 recombination define the measured local domain. No full-model loss, runtime speed, service or selected weights changed.
