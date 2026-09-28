# Shared output coordinates on actual Qwen routes

The first actual Qwen3.6-35B-A3B layer-0 producer capture changes the shared-output-rank question. A rank-512 orthogonal basis fitted to all 904 score-weighted expert outputs from 113 train tokens loses **.709 relative RMS on the 126-token held routed sum**. The same basis loses .088 on train. Even the full span of those 904 train outputs leaves .599 held RMS. These are observations of the selected mixed GGUF image with actual normalized scores and post-SwiGLU hiddens, not synthetic isotropic expert inputs. The short capture cannot justify a useful learned common basis. In particular, the train error is a bad predictor of held output quality.

## Map, optimum and what was measured

For each token, let `d_e` be the captured FP32 down output for selected expert `e` and `a_e` its normalized FP32 router score. The local reference is `y = sum_e a_e d_e`, evaluated in FP64 for this study. A common orthonormal output coordinate `C` of rank `r` produces `C z`; even if the consumer may compute `z` with unlimited work and perfect knowledge of `y`, pointwise orthogonal projection `C C.T y` uniquely minimizes its squared error. On train routed sums, the first `r` right singular vectors of the train sum matrix minimize total train squared error in this family. On individual score-weighted outputs, the right singular vectors of the 904-by-2048 matrix minimize the sum of **individual** squared projection errors; that objective deliberately differs from the routed sum because cross-expert covariance matters. We also measured unweighted individual outputs as a control.

The train-sum matrix has rank at most 113, so fitting a rank-512 basis to it would be vacuous. Individual slot responses raise the available sample span to at most 904. The held sum's own top singular vectors are an *unavailable held oracle*, useful only to see how sharply this finite panel can be projected. The full 904-vector train span is a strict family bound: any common output contained in that span leaves at least .599 held RMS, no matter how its coefficients are computed. It is not a bound on a basis learned from more text or from the model weights, on a route-dependent basis, or on a later consumer that needs fewer than 2048 output coordinates.

| Output basis | Rank | Train sum RMS | Held sum RMS |
| --- | ---: | ---: | ---: |
| Train routed sum | 32 | .559 | .916 |
| Train routed sum | 112 | .008 | .845 |
| Train weighted individual slots | 128 | .377 | .848 |
| Train weighted individual slots | 256 | .226 | .792 |
| Train weighted individual slots | 512 | .088 | .709 |
| Train weighted individual slots | 768 | .018 | .637 |
| Entire train weighted-slot span | 904 | 0 | .599 |
| Train unweighted individual slots | 512 | .121 | .711 |
| Held routed sum, unavailable oracle | 32 | .919 | .555 |
| Held routed sum, unavailable oracle | 112 | .859 | .067 |

Each RMS is `||Y - Y C C.T||_F / ||Y||_F`, with the same fitted basis on every held token and the FP64 weighted routed sum as target. The held oracle fits held tokens and has no predictive status. Because it has only 126 columns of data in token space, the tiny rank-112 oracle loss does **not** imply a rank-112 serving map. This captures the difference between a finite observation and a reusable representation. Unlike the earlier [route-rank study](../route-rank/README.md), every selected expert ID among all 256 and its actual route score enters this result. It evaluates output-space capacity and generalization, not an implemented factor code.

## Conditional cost and decision

If an offline factorization gave each expert an `[r,512]` factor and one shared `[2048,r]` basis, rank 512 would use 3,145,728 down MACs per token instead of 8,388,608. At equal effective bytes per coefficient including the common basis, its down image would be .25390625 of the direct image. The pinned GGUF reads 5,767,168 Q5_K down bytes for eight experts in one layer, or 230,686,720 bytes across forty layers under one uncached read. Thus even extending this hypothetical gain to **all** layers and maintaining equal effective coded bytes would remove at most 6.55% of the modeled complete 2,626,187,904-byte/token weight stream. No common-basis quantization, activation preparation, slot scatter, routing, conversion or native timing is included. This number is a conditional byte margin, not a speedup. In particular, a BF16 factor image cannot be compared at the GGUF Q5_K rate.

Do not build a native shared-output consumer from this capture. A new observation should first cover substantially more independent tokens, all routed IDs and more than layer 0, then fit on one text collection and evaluate on genuinely separate prompts. An offline basis built from full-bank quantized down weights could serve as a stronger weight-informed control. Only after held local error is small should a packed factor and complete-model quality panel decide whether the 6.55% conditional weight margin can pay its boundary costs. The dense sub-bit experiment already showed that held local response quality does not guarantee language quality.

## Reproduce

From Kelana root, with NumPy and four BLAS threads:

```sh
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 python3 research/moe/real-sum-rank/measure.py \
  /path/to/workspace/data/qwen-moe/route-capture \
  --traffic /path/to/workspace/data/qwen-moe/traffic.json \
  --out /path/to/workspace/data/qwen-moe/real-sum-rank/receipt.json
```

The [CPU receipt](/path/to/workspace/data/qwen-moe/real-sum-rank/receipt.json) contains all ranks, both split errors, input and source SHA-256 hashes and cost arithmetic. The capture owner identifies the pinned GGUF, native executable, callback source, prompt texts and all raw tensors in [its README](/path/to/workspace/data/qwen-moe/route-capture/README.md). This study required no GPU run, did not change model weights or serving code, and did not measure complete-model quality or latency. FP64 recombination is not a claim of bit-identical native FP32 reduction.
