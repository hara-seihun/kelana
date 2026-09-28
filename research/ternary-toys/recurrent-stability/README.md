# A stabilizing link that ternary rounding deletes

A two-state gated recurrence is enough to make one-step weight error a poor selector. The reference uses

```text
h[t+1] = (1-g) h[t] + g (W h[t] + [u[t], 0]),   g = 0.5
W = [[1.0436, 0.0415], [-0.7816, 0.8131]].
```

Its transition has a complex-conjugate pair with radius 0.966655. The small positive `W[0,1]` closes negative feedback through `W[1,0]`. Removing it makes the first coordinate's gain 1.021973 after gating. This is a chosen near-critical counterexample, not a frequency estimate over model weights. It captures recurrent state, a gate, weak cross-channel feedback and long composition. A linear recurrent cell also gives an exact white-input infinite-horizon error; the companion tanh recurrence checks whether bounded activations merely hide the problem.

Each row has one shared FP16 scale and two ternary codes. The one-step control exhaustively picks its row codes and least-squares scales for isotropic state inputs, then rounds scales to FP16. It drops `W[0,1]`; its relative Frobenius error is only 3.064%. I also enumerated all 81 two-row ternary code choices and used four-start bounded continuous optimization of their two scales against the *exact* infinite-horizon white-input squared state error. Scales are rounded to FP16 for evaluation. This is a strong same-rate search, not a proof of global optimality for continuous scales or for other code layouts.

| Image | Bits for 2×2 | Transition radius | White-input squared error / input variance | Last-128 stochastic state RMSE | Last-128 tanh constant-input RMSE |
| --- | ---: | ---: | ---: | ---: | ---: |
| Dense FP16 | 64 | 0.966708 | 0.000505 | 0.000094 | 0.000350 |
| One-step ternary | 39 | 1.021973 | infinite | 1372.56 | 0.455935 |
| Same-code scale search | 39 | 0.927979 | 10.208304 | 0.010456 | 0.013852 |
| All-code scale search | 39 | 0.927979 | 10.208304 | 0.010456 | 0.013852 |
| Ternary plus one FP16 feedback link | 57 | 0.962653 | 0.229601 | 0.001455 | 0.003732 |

The stochastic run has 512 independent Gaussian inputs of standard deviation 0.005. The tanh run holds input at +0.005 for 512 steps, so it stays bounded even when its zero-state Jacobian is unstable. A further tanh test gives a +0.005 pulse for 32 steps then releases to zero: last-128 RMSE is 0.535547 for one-step ternary, versus 0.000000243 for the paid-link image. The unstable code acquires a false persistent state rather than merely accumulating roundoff. A constant-input *linear* run gives last-128 RMSE 7927.41 for one-step ternary, 0.02446 for scale search, and 0.00367 for the paid link. These are absolute state units. The stochastic finite run is one seeded draw; the white-input column is the deterministic impulse-response calculation.

The paid-link image retains the one-step code and two FP16 scales, plus one FP16 exception at the known feedback coordinate. The table charges the four trits as seven bits, the two scales as 32 bits, and the exception and its two-bit position as 18 bits. It also requires one extra multiply-add per step, whose runtime is not measured. Dense FP16 needs 64 bits and four multiplies. On such a tiny cell, the seven-bit saving from the exception is not an attractive compression claim; its purpose is to show which link matters. A scale-only correction repairs stability at 39 bits, but cannot put the missing feedback pole back. The all-code search chose the same trits and scales as the fixed-code search for this objective.

Run `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python research/ternary-toys/recurrent-stability/experiment.py` from the repository root. Python needs NumPy and SciPy. The script writes [results.json](results.json), including matrices, FP16-rounded scales, deterministic seed, fixed points and every reported metric. The ideal dense reference is the decimal matrix above; `dense_fp16` is its paid stored approximation.

## Transfer test

For GDN, compute the actual recurrent-state Jacobian along held sequences and compare its leading modes and state impulse response before and after ternary conversion. Restore a *small, explicitly charged* set of feedback/gate entries or jointly choose codes and scales against multi-step response, then compare at matched bytes with scale-only and dense-recurrent controls on fresh held trajectories. For transformer depth, replace time with layer index and examine the Jacobian product and its effect on gold loss, not individual projection RMS. That analogy does not assert stationary dynamics across different layers. The toy predicts a benefit only if real paths contain sensitive feedback or poorly damped modes that a cheap targeted correction can preserve; a stable held Jacobian and no held-loss gain would kill this route.
