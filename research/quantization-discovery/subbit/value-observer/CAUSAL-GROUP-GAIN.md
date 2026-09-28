# What eight paid group gains can and cannot repair

The new right-basis layer-14 image has a striking gap: causal post-O squared error is .00825 on four quantized-producer train windows and .33655 on four separate validation windows. Before changing codes again, I asked whether the existing scale slots could cheaply correct a mismatch shared across each GQA group's two heads. This is a complete causal-map fit, not a V-row reconstruction fit.

For fixed packed right and left codes, let `R_g(x)` be the full 1,024-dimensional output contribution of group `g`, including its BF16-rounded narrow value cache and the two distinct original-Q/K attention distributions. Fit eight nonnegative gains against the original V/O teacher on the same quantized upstream:

```
min_{c >= 0} || sum_g c_g R_g - Y ||_F^2
G_gh = <R_g,R_h>, b_g = <R_g,Y>
objective = c^T G c - 2 b^T c + ||Y||^2.
```

`G` contains every cross-group term. Cholesky turns this into an eight-variable nonnegative least-squares problem. This is the global optimum over real nonnegative group gains for the fixed responses, not a local coordinate search. Both train Grams are positive definite, with smallest eigenvalues 61,586 and 61,805 before normalization. The one-gain control has optimum `max(0, sum(b)/sum(G))`. Gains multiply the existing FP16 left-row scales for both heads of each group; this adds no code byte, factor term, cache element or online multiplication. FP16 rounding is checked by reopening and rescoring the paid image. The real optimum does not certify an optimum after that rounding.

| Fixed 183,552-byte layer-14 V/O image | Four train windows | Four held windows | Held-only oracle, not selected |
| --- | ---: | ---: | ---: |
| Selected 192, untouched | .00825094 | .33655065 | |
| Selected 192, train-fitted common gain | .00825056 | .33641887 | .32344851 |
| Selected 192, train-fitted eight gains | .00824753 | .33618243 | .31263899 |
| Uniform 192, untouched | .00900518 | .33617511 | |
| Uniform 192, train-fitted common gain | .00900444 | .33595348 | .31814580 |
| Uniform 192, train-fitted eight gains | .00900067 | .33563354 | .30856062 |

The paid FP16 images score .33618638 selected and .33563656 uniform on the same held windows, a change of at most 0.000004 from the real-gain score. All four selected held windows improve, from [.304919, .611981, .310459, .114353] before the fit to [.304707, .611185, .310034, .114308] after it. Train gains are only .9960 to 1.0011. The held-only optimal gains are much larger, roughly .73 to 1.00 for selected and .73 to .95 for uniform. Choosing those on held data would be leakage, not an image improvement. Their score is a capacity diagnostic: the existing eight scale slots *could* lower held error by .02391 selected or .02761 uniform, but these four train windows drive them almost nowhere. The train/held producer distribution and the post-O observer, not a missing independent group-gain optimizer, determine this failure. On these inputs another sweep of the same frozen-image train quadratic is exhausted.

This is a restricted result. It fixes the layer-14 192-coordinate paid images, four 256-token train and four disjoint validation windows, original layer-14 Q/K, CPU FP32 output reductions, BF16 narrow-cache rounding and squared post-O response. The original V/O teacher receives the same quantized upstream input. It says nothing about gold NLL, native latency, changing right codes, or other layers. The next construction should train shared right codes and both O consumers on broader, independent quantized-producer *continuations*, with gold or teacher language loss. A more elaborate eight-gain solver on this same capture is not the missing repair.

`causal_group_gain.py selected192` and `causal_group_gain.py uniform192` regenerate the two paid images and JSON receipts under `/path/to/workspace/data/kelana-subbit/value-observer/layer14-quantized-upstream-causal-gain-*`. Each receipt contains the full eight gains, Gram spectrum, stationarity residual, all four held-window errors, model/input/source/image hashes and paid replay. Run with `OPENBLAS_NUM_THREADS=1` and `/path/to/workspace/data/fish-s2-pro/venv/bin/python`. This was CPU work; the GPU reservation, Bonsai executable and serving defaults did not move.
