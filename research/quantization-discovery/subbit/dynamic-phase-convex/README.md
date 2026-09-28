# Convex bounds for moving-scale RoPE cells

The [dynamic-max phase study](../dynamic-phase-cells/README.md) partitions a shared Q/K rotation into cells with fixed rounded codes. The signed-byte query step still changes inside a cell, so testing one angle per cell is not an exact search. Its midpoint Lipschitz certificate leaves a gap of 0.00042816 mean causal KL on the five-key synthetic example. Here a separable convex bound reduces that gap to 0.00000136 without another query/key code evaluation.

## The bound

Use the parent's real-arithmetic map, with fixed teacher probabilities `p_h,t,j`, fixed other-score vector `b_h,t,j`, fixed key step `s`, and query cap `C=119`. In one open event cell the key and query integer codes `c_j,z_h,t` are constant. For query `h,t`, put `a_j=(s/C)<z_h,t,c_j>` and let `M_h,t(theta)` be its changing maximum prepared-query magnitude. Its causal KL is

```
f_h,t(m) = log(sum_j exp(b_j + a_j*m))
           - sum_j p_j*(b_j + a_j*m) + sum_j p_j*log(p_j).
```

Its derivative is `E_softmax(b+a*m)[a] - E_p[a]` and its second derivative is `Var_softmax(b+a*m)[a] >= 0`. Therefore the minimum over an interval of possible `m` occurs at an endpoint or at the unique interior derivative zero, unless all `a_j` agree, when it is constant. This works with any fixed additive scores and all causal prefix lengths. It is a scalar optimization, not a 32-coordinate reconstructed key or a native inference operation.

The event partition fixes which coordinate supplies the maximum and its sign. For a rotated winner, `M(theta)` is `sign*(A cos(theta)+B sin(theta))` on that cell; for an unrotated winner it is constant. Evaluate the endpoints and any stationary angle inside the cell to get its exact range `[m_min,m_max]`. Each query's convex minimum on that range is a lower bound on its loss at every angle in the cell. Sum these minima and divide by the number of queries. Different queries can attain their minima at different angles, so this is generally a strict lower bound, not an attained phase. Evaluate each event angle separately because the tie-rule code image can differ from both neighboring cells. A midpoint upper bound and this lower bound enclose the global optimum after taking the minimum across cells and event points. The existing midpoint Lipschitz lower bound can first discard any cell that cannot beat the incumbent; it does not change the proof.

The mathematical statement assumes exact event roots, real logits and continuous `M` in every open cell. The script uses floating roots, labels, extrema and bisection. Its numbers are numerical evidence, not outward-rounded interval certificates or FP32-bit statements. At an exact event, include that event's separately evaluated loss in the lower-bound minimum. In this fixture the parent's best sample was an interior midpoint, below every sampled event, so the cell bound is already below every event value.

## Replayed example

`fit.py` reads the parent's pinned `receipt.json` rather than regenerating random inputs. It considers the same 32,705 cells and ten causal query rows. The cheap midpoint bound discards 32,189 cells; convex minimization runs on the remaining 516. The minimum cell bound occurs at `[0.651684739544403,0.6518420185921299]`, not in the cell containing the best sampled phase near 5.364. That is precisely why checking only the winning sample's neighborhood does not certify a global answer.

| Bound on mean teacher-to-candidate causal KL | Value | Gap to sampled upper |
| --- | ---: | ---: |
| Parent midpoint Lipschitz lower | 0.0046843903 | 0.0004281614 |
| Convex cell lower | 0.0051111874 | 0.0000013642 |
| Parent midpoint/event sampled upper | 0.0051125516 | 0 |

The interval is about 314 times narrower. This is an offline search reduction for the specified dynamic-max rounded query and fixed key codes. It does not change weight bytes, cache bytes, signed-nibble dots, Qwen model quality or native speed. In particular it is not evidence that the selected synthetic phase transfers to the paid Qwen keys.

From a Kelana checkout run `OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/dynamic-phase-convex/fit.py`. The [receipt](receipt.json) records parent source and input-receipt hashes, this script's hash, counts and bounds. The next useful use is to filter phase events for promising Qwen planes on quantized-upstream train captures and freeze the fitted phase before fresh held causal/post-O loss; only then price append-time angle composition and the whole native two-head score boundary. This bound makes that larger offline search more practical without pretending it solves online cost.
