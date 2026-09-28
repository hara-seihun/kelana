# Fit the routed sum after the producer changes

A joint trit choice can tolerate larger errors in individual experts if their weighted outputs cancel. The route used to arrange that cancellation must be the route the quantized producer will actually take. In this finite example, fitting the sum with the original producer's routes loses 40% of its held squared-error advantage to that mismatch: its held MSE is .15439, versus .09284 when the same 19,683 code triples are fitted with quantized-producer routes. The conditional fit beats the fixed-route fit in all 12 independently sampled train/held panels. This is an exact search within a small code family, not a model-quality claim.

## The map and exhaustive fit

Each input has two shared real coordinates, uniform on `[-1.7, 1.7]`. The teacher producer applies `P = [[1,.35],[-.35,1]]`; the quantized producer applies `Q = .83 I`, a diagonal ternary matrix with one scale. Both the router and all three experts consume their respective producer's output. Router logits are affine in that output. The router takes the top two experts and normalizes their exponentiated logits over those two only. On held inputs, changing the producer changes the selected pair on 14.91% of tokens. Scores also change when the selected pair stays the same.

For expert `e`, the teacher computes `d_e SiLU(g_e z0 + G2_e z1) (u_e z0 + U2_e z1)`. The student keeps `G2_e` and `U2_e` fixed and chooses `(g_e,u_e,d_e)` from three trits, with a fixed per-expert down scale. Thus each expert has 27 candidates, and the exhaustive search checks all `27^3 = 19,683` global trit tuples. The second-coordinate coefficients, down scales, router and producer are all specified in `oracle.py` and `results.json`. This deliberately quantizes only part of each expert. No claim about a fully ternary expert follows from it.

The target is the original-producer weighted expert sum, not three separately observed expert labels. The conditional objective is the squared error of the *quantized-producer* routed sum against that target. A fixed-route control fits the same target and candidate book but weights the student responses by the original producer's routes during fitting, then deploys them on the quantized routes. Two independent controls fit each candidate expert to the teacher expert under original or quantized route weights. All four use 96 training inputs, the same candidate trits and unchanged router, producer and scales. Each of 12 RNG seeds draws 1,024 disjoint held inputs. The held oracle searches those inputs directly; it is a capacity diagnostic, not a deployable selection rule.

| Fit | Mean train MSE | Mean held MSE | Held MSE, same top two | Held MSE, changed top two |
| --- | ---: | ---: | ---: | ---: |
| Independent, original routes | .16521 | .18367 | .19026 | .14270 |
| Independent, quantized routes | .15069 | .16861 | .17869 | .11004 |
| Joint, original routes | .14497 | .15439 | .16533 | .09139 |
| Joint, quantized routes | **.09045** | **.09284** | **.10478** | **.02466** |
| Held joint oracle | .09259 | .09136 | .10428 | .01748 |

These are means of per-seed MSEs, not pooled predictions. Mean teacher held squared output is .36543; the teacher experts evaluated under the quantized route alone have .01774 MSE against the original routed sum. On held data, the quantized-route joint fit reduces MSE by 39.87% versus the strongest fixed-route joint control and 44.94% versus the strongest independent fit. It nearly reaches the held code oracle in this small stable codebook, with no held inputs used to select its trits.

The joint fit does not improve each expert separately. With quantized route weights, its mean sum of *individual* squared expert errors is .14464, worse than the quantized-route independent fit's .12038. Its pairwise cross-expert contribution is -.02415 versus +.00814 for that independent fit. More importantly, the cross term between local expert error and the producer-induced route drift is -.04539 versus +.02235. Adding those terms and the common .01774 route-only term gives the measured held sum errors. The codes compensate a conditional output error, not each expert's local error.

## Transfer criterion

Write `a` for original routing, `a'` for quantized routing, `t` for teacher expert outputs and `s` for student outputs. The serving error is exactly

`a'·s - a·t = a'·(s-t) + (a'-a)·t`.

A fixed-route fit instead controls `a·s - a·t`. The difference between that training residual and the serving residual is `(a'-a)·s`. Small fixed-route fit loss alone cannot bound that term. The practical criterion is an improvement on independent held text in the *actual composed routed output*, evaluated after the quantized upstream producer and router, against equal-code and equal-scale budgets. Check both route-switch and unchanged-pair tokens, since score drift matters on unchanged pairs. Next, record real Qwen MoE quantized-producer route IDs/scores and shared expert inputs, then compare a joint code update against matched independently fitted and fixed-route updates under complete-model NLL. The existing whole-model scale-only winner is the necessary broader control. A local MSE win that worsens composed NLL would reject transfer, as in the earlier ternary reconstruction work.

The oracle prices no extra serving weights relative to either trit control: nine chosen trits total, the same fixed coefficients and scales, the same top-two router and two expert evaluations. Exhaustive search is offline, about 19,683 combinations of three candidate-response vectors per panel. This is neither a full-storage image nor a native timing study. A real converter must charge unchanged coefficients, router, producer and scales, and must make the fit affordable across far larger expert banks.

Run from the repository root with one BLAS thread:

```sh
OPENBLAS_NUM_THREADS=1 python3 research/ternary-toys/routed-sums/oracle.py --seeds 12 > research/ternary-toys/routed-sums/results.json
```

`results.json` retains each seed's code tuples, split errors, route-switch rates and error decomposition. No model weights or GPU are needed.
