# Weight-informed shared output on actual Qwen routes

A short actual-output capture made a train-fitted common output basis look good on its own 113 tokens and poor on 126 held tokens. Can the **full 256-expert down-weight bank** supply directions that generalize better than that tiny sample? I decoded the pinned layer-0 Q5_K down bank, sampled four or eight columns from every expert with a fixed seed, and took the leading left singular vectors. The consumer is granted the exact orthogonal projection of each captured routed sum. That is an unattainable free coefficient oracle for this basis, so its error is a lower bound on any implementation whose final output stays in these coordinates.

| Surrogate for the common basis | Sampled weight columns | Rank 512 train RMS | Rank 512 held RMS | Rank 768 held RMS |
| --- | ---: | ---: | ---: | ---: |
| Uniform full-bank columns | 4/expert | .809 | .821 | .748 |
| Uniform full-bank columns | 8/expert | .813 | .813 | .737 |
| Train route-score and hidden-energy diagonal | 4/expert | not defined | not defined | not defined |
| Train route-score and hidden-energy diagonal | 8/expert | .816 | .820 | .742 |
| Prior train-weighted *actual output* basis | 904 response vectors | .088 | .709 | .637 |

The comparison uses the same local FP64 sum of eight captured FP32 GGUF down outputs times their normalized router scores. A rank-512 fixed basis is not close to a faithful routed sum even with perfect online coefficients. Sampling twice as many bank columns did not close the gap. The route-energy weighting is a train-only diagonal surrogate, not a covariance of the whole nonlinear expert sum; at eight columns per expert it slightly worsens held error. At four columns its sampled matrix has numerical rank **424**. Its rank-256 held error is .895, and rank 512 is undefined. A previous receipt mistakenly included nullspace singular vectors at higher ranks; the corrected receipt and table remove those outputs. Every expert receives its own uniformly sampled column indices. For the route-energy arm, column `j` receives amplitude proportional to the square root of `sum_(train token, routed slot for expert) score² * hidden_j²`; unseen experts receive zero amplitude. The sample is *not* a claim that the full-bank weight Gram has the same leading eigenvectors. The result rejects these sampled-basis constructions, not a complete weight-informed covariance or jointly learned code.

At rank 512, a hypothetical factor with the same effective bytes per weight coefficient as the Q5_K image saves at most 6.55% of the modeled whole-model weight stream if all forty layers behave like layer 0. That conditional margin is from [the preceding output-rank study](../real-sum-rank/README.md); it does not charge the common basis separately at a different quantization rate, scale metadata, routing, preparation or synchronization. The new bases preserve no selected inference arithmetic contract. Projection in FP64 changes both the map and reduction order. We did not build a factor image, measure model language loss or run the GPU.

The next experiment should not increase this sketch's column count by itself. Fit the **composed routed-sum covariance**, including cross-expert terms and quantized producer behavior, from more independent tokens across layers or a weight-derived covariance with an explicit activation model. Then compare complete-model held NLL and paid image bytes before implementing a native packed consumer. The small dense sub-bit pilot already found that local response accuracy can misrank complete images.

## Reproduce and evidence

From Kelana root, using the existing Python environment, run the four CPU arms separately with `OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4`:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for variant in uniform route-energy; do
  for columns in 4 8; do
    "$P" research/moe/weight-informed/measure.py --variant "$variant" --columns "$columns" \
      --output "/path/to/workspace/data/qwen-moe/weight-informed/${variant}-${columns}.json"
  done
done
```

[Data receipts](/path/to/workspace/data/qwen-moe/weight-informed/README.md) hold exact per-rank train/held RMS, all sampled indices, script, bank, decoder and capture hashes, plus the model acquisition SHA-256. Their inputs are the same installed-runtime layer-0 producer captures documented in [Bonsai's route report](/path/to/workspace/projects/bonsai-halo/docs/qwen-moe-routes.md). The pinned Q5_K decoder comes from the installed `libggml-base.so`. The CPU study did not touch either service or selected executable.
