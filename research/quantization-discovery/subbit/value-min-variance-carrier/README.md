# Minimum-variance carrier for one-digit value attention

A fifteen-count causal probability row and a signed-nibble narrow-value cache admit a stronger *existence certificate* than sampling keys according to the softmax probabilities. Keep the frozen Qwen3-0.6B rank-28 V/O image and its direct packed-nibble consumer. Change only the probability-to-count assignment.

Let `c_i` be the 28 signed codes for cached key `i`, `p_i >= 0`, `sum p_i = 1`, `mu = sum p_i c_i`, and `G` the positive semidefinite metric induced by the two-bit output decoder and value steps for one head. Solve

```
minimize    sum_i q_i ||c_i - mu||_G^2
subject to  sum_i q_i = 1,  sum_i q_i c_i = mu,  q_i >= 0.
```

The original `p` is feasible, so the optimum cannot raise the preceding [independent-sampling bound](../value-mass-discrepancy/README.md). A basic optimal solution has at most `r+1` nonzero probabilities, where `r` is the affine rank of the codes. Here `r <= 28`, independently of context length. This sparse carrier preserves the *whole continuous code response* exactly in real arithmetic. It need not preserve the original probabilities or any individual key's contribution.

Draw fifteen keys independently from `q`, divide their code sum by fifteen, and compare with `mu`. The expected squared output error is precisely the LP objective divided by fifteen. Thus some conserved unsigned-nibble count assignment attains that bound. It is also constructive without random sampling: with accumulated centered-code sum `S`, choose the next supported code minimizing `||S + c_i - mu||_G^2`. The conditional expectation of the remaining centered sum is zero, and its remaining variance is independent of this choice. Induction gives final squared error at most the optimum variance divided by fifteen. This proof concerns real responses and a frozen code image. It is neither bit-identical FP32 execution nor an optimality claim over all integer count assignments.

## Frozen Qwen replay

The CPU study uses heads 7/12 at layers 0/14, the rank-28 paid V/O factors, original-producer Q/K, eight available train and four previously inspected validation windows, and positions 63/127/191/255 per window. To keep each run bounded, it uses four train windows and four validation windows, sixteen rows per split. Its reference is the frozen 4,095-count response, while the LP and greedy construction target the floating response. The denominator is the sum of reference post-O squared energies for that head. Small FP32 softmax mass errors are removed by normalizing each probability row before the real-domain LP.

| Layer, split | Prefix-15 relative error | Carrier-greedy error | Prior sampling bound | Optimal-carrier bound | LP support |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0, train | .00111254 | .00027380 | .00090953 | .00090105 | 28–29 |
| 0, inspected validation | .00006709 | .00004790 | .00108525 | .00106204 | 28–29 |
| 14, train | .00109625 | .00094056 | .00426944 | .00414774 | 29 |
| 14, inspected validation | .00046388 | .00043989 | .00600344 | .00587344 | 29 |

The optimal variance bound improves the prior bound only 0.9%/2.1% on inspected layer-0/14 validation, and remains far above the actual errors. Sparse carrier alone does not solve one-digit quality. On the identical sixteen held rows, the earlier response-exchange selector scores .00004790/.00028369 at layers 0/14; this carrier-greedy selector ties layer 0 and loses badly at layer 14. A conditional-expectation guarantee is not a good per-query objective when the useful count assignments exploit cancellation rather than iid sampling. The next search should fit the cheap score-and-code-aware phase sketch and V/O codes jointly against quantized-producer complete-model loss, not build an online LP.

The cache still uses 112 logical/128 padded bytes per token/layer, the factor image and one-digit packed-dot contract are unchanged, and no native implementation was selected. This construction would require a per-query LP over up to 256 keys, metric projections for the LP objective, and up to `15*n` candidate scores after the solve. It cannot be counted as a cheaper *online* inference program. The exact-response support theorem is useful for reducing offline candidate search to at most 29 keys, but the measured variance objective is not a sufficient selector.

`measure.py` reproduces each layer in a bounded CPU command from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-min-variance-carrier/measure.py --layer 0 --windows 4
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-min-variance-carrier/measure.py --layer 14 --windows 4
```

`/path/to/workspace/data/kelana-subbit/value-min-variance-carrier/layer{00,14}.json` holds every row's source/model/capture/factor/cache hashes, solver support and response gap, bounds and actual errors. No GPU, Bonsai executable or service changed.
