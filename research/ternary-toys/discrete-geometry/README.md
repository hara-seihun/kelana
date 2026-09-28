# Pair barriers in a tiny ternary gated map

A real two-coordinate flip can improve composed probability loss even when *both* component flips make it worse. A continuous code gradient can pick an especially bad single flip. This is an argument for measuring a small joint neighborhood before another broad STE update, not evidence that a full-model ternary image improves.

## The finite experiment

The binary teacher and student use a residual logit

`z(x) = 0.3 x[0] + sum_j d[j] sigmoid(g[j] · x) (u[j] · x)`, with `d = (1.25, -1.1)`.

The eight student coefficients in the two gate and two up rows are trits. Teacher coefficients are real. We minimize mean expected Bernoulli NLL, `log(1+exp(z)) - p_teacher*z`, so the forward pass includes both gates and the final probability. No random label draws cloud the geometry. Each of 40 independent seeds draws the teacher near a ternary anchor, then 48 train and 384 held inputs. `x = (1.7a, a+0.5b)` for independent standard normal `a,b`: the input coordinates correlate about 0.89, and their variances differ. The starting trits round the teacher. Scales, residual and down coefficients stay fixed, and every candidate uses the same eight-trit storage.

For each seed, the exact oracle scores all `3^8 = 6,561` assignments on train inputs. The practical searches score actual composed loss on their candidate neighbors and accept only strict train improvements. One-flip steepest descent tests 16 alternatives per visit. Radius-two steepest descent tests those 16 plus 112 simultaneous two-coordinate changes. The STE-like control differentiates the continuous student loss, picks the one-trit alternative with the best predicted linear gain, then checks only that candidate; a rejected proposal ends the search. The oracle never selects on held data. The `results.json` evaluation counts include rejected candidates but exclude the current-state forward, gradient/backward, and repeated evaluations, so they are a fair *proposal-count* comparison, not a runtime benchmark.

| Search | Mean train NLL | Mean held NLL | Train oracle reached | Mean scored proposals |
| --- | ---: | ---: | ---: | ---: |
| Rounded start | .580016 | .583029 | 1/40 | 0 |
| STE-ranked single proposal | .572648 | .577179 | 1/40 | 1.32 plus gradients |
| Exact one-flip descent | .550497 | .553739 | 6/40 | 40.0 |
| Exact radius-two descent | .547791 | .551065 | 16/40 | 329.6 |
| Full train oracle | .545922 | .549026 | 40/40 | 6,561 |

Radius two lowers held NLL by .002674 versus one-flip descent across the 40 cases. A seed-resampling percentile interval for that *mean paired difference* is [.001286, .004281]. It improves 21 cases, ties 17 and worsens 2 on held inputs. After exact one-flip descent, 18/40 cases admit a beneficial pair, and 14 of those have a strictly positive best one-flip barrier. The STE-ranked single proposal is eventually rejected despite a predicted improvement in all 40 cases. The one-flip exhaustive control is much stronger than that gradient selection; pair search still improves it. Radius-two search does not reach the oracle in 24 cases, so pairwise moves are not an exact optimizer.

Seed 27 makes the interaction concrete. One-flip descent stops at `[-1,1,-1,-1,1,-1,0,-1]`, train NLL .55782819, with a best single-flip increase of .00285087. Changing up coefficient 4 from 1 to 0 alone adds .03673492 train NLL; changing up coefficient 6 from 0 to -1 alone adds .01574183. Changing both *subtracts* .01545089, an exact mixed finite difference of -.06792764 relative to the sum of the isolated changes. These are two channels with opposite down signs and correlated inputs; jointly altering their contributions can repair the output logit without paying either isolated error. The radius-two route reaches the oracle at train .54237730 and held .53672363, versus the one-flip held .55503027. Its continuous gradient at the rounded start predicts -.06227911 for its favorite single flip, but the real change adds .34617862 train NLL.

This toy keeps quantized gate/up coefficients, coupled nonlinear channels, correlated inputs, residual composition and a probability loss. It omits deep layer interactions, trainable scales, a tied head and hard next-token labels. No packed-consumer timing or extra bits are implied; all searched images have the same code budget. The exact oracle is only affordable because there are eight trits.

## Transfer condition

On a frozen complete-model image, find a **small** set of candidate trits whose output sensitivities collide through the same downstream probability map, preferably on correlated activation directions and channels of opposing sign. Measure `Δ_i`, `Δ_j` and `Δ_ij` with *whole-model* NLL on one independent train check panel. Joint acceptance matters when `Δ_i >= 0`, `Δ_j >= 0`, but `Δ_ij < 0`; the mixed difference `Δ_ij - Δ_i - Δ_j` must be negative enough to cross both barriers. Select candidates on a separate proposal panel, compare against exhaustive single-coordinate checks at the same image bytes, and report untouched held loss. A cheap subset of 16 candidates needs 480 pair alternatives, not a full-model all-pairs sweep. If the joint gain vanishes on the independent check, or held NLL fails to beat single-coordinate search and scale-only recovery, this mechanism does not transfer. The large image's 256 accepted trit changes and unchanged held loss make that last test essential.

Run in about two seconds on one CPU thread:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 research/ternary-toys/discrete-geometry/experiment.py
```

`results.json` contains the aggregate, all 40 per-seed losses and proposal counts, and the seed-27 codes and exact pair witness. NumPy is the only dependency. The source computes both oracle and local objectives through the same forward map; proposal counts simulate the local algorithm, while exact enumeration supplies the reference.
