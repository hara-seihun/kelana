# Three calibration states beat 10,000 random draws in a gated toy

The conversion question here is whether calibration needs many typical states or a small set that exposes the choice between discrete codes. On this finite model, three deliberately selected teacher queries recover the exact population-optimal ternary code. Ten thousand iid queries still choose the other code 22.0% of the time. This is an exact sampling calculation, not a simulated success rate.

## Model and comparison

The branch output is `ReLU(w1*a + w2*b - 0.5) * (50.5 + 49.5*b)`; a residual skip would add the same `a` to teacher and candidate, leaving every squared error below unchanged. The teacher gate has weights `(1.49, -0.6)`. The candidate keeps the bias and up branch fixed and stores two gate trits in `{-1,0,1}` at scale one. Thus the nonlinear gate can cross a routing boundary when a trit changes, and the up branch amplifies the rare route. All candidates have the same two-trit gate storage and the same runtime operation count. No extra online table or exception is given to the cover method.

The reachable input support and its population probabilities are:

| State | `(a,b)` | Probability | Teacher branch output |
| --- | --- | ---: | ---: |
| A | `(1,-1)` | .899 | 1.59 |
| B | `(-1,-1)` | .100 | 0 |
| C | `(1,1)` | .001 | 39 |

For each of the nine gate codes, `experiment.py` evaluates exact squared output error. The two relevant candidates have this error vector:

| Gate trits | A | B | C | Population risk |
| --- | ---: | ---: | ---: | ---: |
| `(1,-1)`, nearest teacher weights | .0081 | 0 | 1521 | 1.5282819 |
| `(1,0)`, exact population winner | 1.1881 | 0 | 121 | 1.1891019 |

One of these two codes weakly dominates each other candidate on **every** reachable state. Hence the conversion decision only needs their loss difference. Its population sufficient statistic is `1.18*p(A) - 1400*p(C) = -0.33918`. A probability-weighted teacher query at each of A, B and C obtains the exact risk for every code, selecting `(1,0)` with three queries. B has zero loss for both nondominated codes; after proving dominance, only A and C need teacher queries for their comparison. The full three-state cover makes no assumption about that dominance beforehand.

The iid control enumerates all nine codes and minimizes empirical squared composed-output error. It resolves ties in favor of the nearest-weight code `(1,-1)`. Since the remaining codes are dominated, it chooses the population winner exactly when `1400*N_C > 1.18*N_A`. Conditional on `N_C`, `N_A` is binomial with probability `.899/.999` over the remaining samples. The script sums those binomial probabilities, including rare-state count fluctuation. The expected selected risk averages the true population risk of the selected code over calibration samples, rather than reporting training error.

| Iid teacher queries | Probability of wrong code | Expected population risk | Probability C never appears |
| ---: | ---: | ---: | ---: |
| 100 | .904792 | 1.495989 | .904792 |
| 1,000 | .367695 | 1.313817 | .367695 |
| 10,000 | .220085 | 1.263750 | .000045 |
| 100,000 | .005463 | 1.190955 | effectively zero |
| 3 weighted support witnesses | 0 | 1.189102 | 0 |

The 10,000-query failure is mainly misweighting a rare but high-loss route, not failing to encounter it. Rounding the teacher gate weights to their nearest trits also picks `(1,-1)` and suffers 1.528282 population risk. An exhaustive true-risk oracle over the nine codes picks `(1,0)` and ties the weighted cover; it cannot do better within this finite code family. This controls for both weight rounding and an unrestricted search over the same paid codes.

## What transfers and what does not

The mechanism resembles composed ternary conversion: one trit change alters a ReLU gate, and a downstream multiplier makes the rare gate error consequential even though average gate activity looks benign. It does **not** establish that a real Qwen activation corpus admits a three-state cover, that its probabilities are known, or that synthetic rare activations have realistic downstream state and labels. The 100-fold up gain and the skewed three-point input distribution are deliberately severe. The fixed full-precision up branch, squared response loss and two-trit search omit whole-model gold loss, residual propagation, joint scales, and storage for learning or describing real witnesses. The gain is offline teacher-query efficiency, not an inference speedup or a better representation.

A discriminating transfer test would freeze a layer's producer states from the existing train capture, cluster them by actual gate-boundary and downstream-loss differences between a small set of competing ternary edits, then compare probability-weighted representatives with an equal-query random calibration on **held complete-model NLL**. Account for the metadata needed to estimate cluster mass and to find the representatives. If the representatives improve only local response loss, the proposed transfer has failed in exactly the way earlier reconstruction experiments did.

Run `python research/ternary-toys/calibration-sufficiency/experiment.py` to regenerate [`results.json`](results.json). It uses SciPy for the binomial tail and finishes in seconds on one CPU thread.
