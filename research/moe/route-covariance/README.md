# A weight-prior rescue test for routed output rank

The train-fitted rank-512 output basis on Qwen3.6 layer 0 loses 0.708799 relative RMS on held routed sums. I tested whether directions from the *entire installed 256-expert Q5_K down bank* repair the small capture's missing directions. A weak full-bank prior helps by 0.0045 RMS, but even granting a free optimal projection onto the resulting basis leaves 0.704294 RMS. This is not a useful compressed output coordinate for the selected model.

## The map and experiment

For each actual routed token, the local target is `y_t = sum_(e in route_t) a_te d_te`, using the installed model's eight FP32 down outputs and normalized FP32 scores, recombined in FP64. The train split contains 113 tokens and the held split 126. A fixed shared rank-`r` output subspace `C` can only produce `Cz`, regardless of how the expert factors compute `z`. The FP64 orthogonal projection of `y` onto `C` is its least-squares optimum. The error measured here is therefore a *free-coefficient floor* for that fixed output subspace, not the error of a realizable quantized factorization.

The train surrogate has two parts. `S` has all 904 score-weighted individual down outputs as rows; `W` has four seeded, independently sampled decoded Q5_K down-weight columns per expert, including every expert absent from the train route. Both are normalized to equal Frobenius norm, then the leading right singular vectors of `[S; sqrt(lambda) W]` give the basis. `lambda=0` recovers the preceding actual-output study. The weight columns encode an isotropic input-coordinate prior, not the actual hidden covariance. The family does not model cross-expert covariance except indirectly through its held sum evaluation. Its only online observation is the rank-constrained output; neither weight decoding nor SVD is charged as online work because both are offline.

| Prior covariance mass / capture mass | Rank-256 held RMS | Rank-512 train RMS | Rank-512 held RMS | Rank-768 held RMS |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .791587 | .087998 | .708799 | .636991 |
| .03 | .790935 | .092281 | .706115 | .632278 |
| .1 | .789614 | .126802 | .704294 | .631878 |
| .5 | .794400 | .311356 | .715355 | .640415 |

A weak weight prior slightly lowers the held error at rank 512. At .1, 39 held tokens contain at least one expert absent from the train capture: their error changes .763178 to .759500. The remaining 87 change .686074 to .681196. Thus the gain is not merely an unseen-expert rescue. Thirty-five expert IDs appear only on held routes, with 76 of 1,008 held assignments using those IDs. The `.5` arm regresses, while rank 512 with a free projection still discards almost half of the held sum's squared energy. The multipliers were inspected on this held panel; none is a fresh model-quality selection.

The earlier conditional equal-byte rank-512 down-factor saving across all forty layers was at most 6.55% of the modeled complete per-token weight stream, before factor metadata, boundaries or the online work. This local error is far too large to justify those costs. The result closes the cheap sampled-full-bank shrinkage idea on this capture, not an optimal full-weight Gram or a shared code learned against complete-model loss. More independent routed producer tokens and a weight-informed prior using measured hidden covariance are needed before revisiting output coordinates. The dense sub-bit pilot's complete-image failures are a further reason not to infer language quality from this local number.

## Reproduce and custody

The CPU-only source is `measure.py`. The saved 1024-by-2048 sampled-column matrix, its seed/indices and hashes are under `/path/to/workspace/data/qwen-moe/route-covariance/`. Every evaluated multiplier has its own JSON with train/held and seen/unseen errors, source and input SHA-256. The fixed model and capture identities are in the linked prior [actual-route result](../real-sum-rank/README.md). No GPU, serving runtime, selected weights or resident service was changed.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=/path/to/workspace/data/qwen-moe/route-covariance
S=research/moe/route-covariance/measure.py
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" "$S" prepare --output "$D/columns.npy"
for L in 0 0.03 0.1 0.5; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" "$S" evaluate --features "$D/columns.npy" --multiplier "$L" --output "$D/mix-$L.json"
done
```
