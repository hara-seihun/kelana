# An exact attention gauge changes positive-feature approximation geometry

The [uncentered real-source experiment](../qwen-positive-kernel/README.md) has huge Gaussian-feature variance exponents and poor complete output. That exponent is **not an invariant of the attention map**. A common key translation preserves every normalized probability and value output, while changing the geometry faced by this particular finite feature program. Representation must be chosen jointly with approximation; the source's key origin is not mandatory.

## Exact map, changed sampling law

For a common vector c, replace all keys by `k'=k-c`. For every query,

```
q dot k' = q dot k - q dot c,
exp(q dot k') = exp(-q dot c) exp(q dot k).
```

The factor is constant across the permitted prior/self keys of that row. It cancels in the denominator and numerator, including causal masks, arbitrary values and any unchanged linear O consumer. The exact attention program need not compute `q dot c` to undo it. The same c can serve all queries/heads; a different c for each query generally prevents sharing one online key-prefix state. This is an exact ideal-real statement. Centering an already rounded key and then rounding again is a distinct numeric program.

For independent `omega_f ~ N(0,I)`, define the standard positive feature `phi_f(x)=exp(omega_f dot x-||x||²/2)`. The r-sample kernel estimator is

```
Khat_c(q,k) = (1/r) sum_f phi_f(q) phi_f(k-c).
E Khat_c = exp(q dot (k-c)),
Var(Khat_c)/(E Khat_c)² = [exp(||q+k-c||²)-1]/r.       (1)
```

Indeed, for `u=q+k-c`, the Gaussian moment-generating identity gives first moment `exp(||u||²/2-(||q||²+||k-c||²)/2)` and second moment `exp(2||u||²-(||q||²+||k-c||²))`; dividing by the squared first moment leaves `exp(||u||²)`. Independence divides relative variance by r. The actual committed FP16 Gaussian table is finite and deterministic; (1) describes its generating ideal iid estimator, not a per-image probability certificate, and it is **not** a lower bound on normalized output error. Numerator and denominator errors are correlated.

There is a simple source-defined coordinate choice. For any declared positive pair measure mu of total mass1, let `u=q+k` and `c*=E_mu u`. Then

```
E_mu log(1+r*relative_variance_c)
 = E_mu ||u-c||²
 = E_mu ||u-c*||² + ||c-c*||².                       (2)
```

Thus the centroid uniquely minimizes this **mean log-variance statistic**. It need not minimize mean variance `E exp(||u-c||²)`, worst-cell variance, fixed-table error, KL, or the final value output. Those are different objectives. For mean variance, the first-order condition instead reweights every u by `exp(||u-c||²)`; a centroid theorem cannot be substituted for that optimization. The pair measure matters: uniform causal pairs, uniform queries then uniform prior, and teacher-probability weighting do not agree. No held data is needed to specify (2).

`Kelana/PositiveKernelGauge.lean` proves finite rational dot translation, preservation of row score differences, the arbitrary-dimensional weighted centroid square identity and minimization. Real Gaussian moments, exponentials, normalization and the claim of a unique real centroid are analytic here; finite FP16 table behavior remains executable evidence, not a Lean theorem.

## Exact family and a fixed finite feature reader

Use scalar queries `q in {-1/2,+1/2}`, keys `B-1,B+1`, and corresponding values0,1. The teacher output is `sigmoid(2q)` for **every B**. At c=0, the worst variance exponent for B>=0 is `(B+3/2)²`; with c=B it is **9/4**, independent of B. Under the uniform four-pair law, the mean exponent changes from `B²+5/4` to **5/4**. Arbitrarily bad uncentered sampling geometry therefore coexists with an unchanged simple target map.

The runnable witness uses the single declared B=8 and a fixed two-feature table `omega=(-1,+1)`, not a selected Gaussian sample or a rank/seed sweep. It computes both frozen finite-kernel readers by stable log-sum-exp and observes their final scalar value response. The centered approximation changes, while the exact teacher score differences do not. The stored center is an actual two-byte FP16 field consumed by the shifted reader. Source coordinates and the generic two-feature program are common; extra subtraction, reading the center, exponentials, online moment scales and reader code all count. A strong direct teacher reader evaluates `sigmoid(2q)` and is cheaper/exact on this family, so the example is **not** an inference frontier win. Its purpose is to refute a coordinate-invariant interpretation of uncentered feature variance.

## Actual source geometry without another candidate fit

The independent [Qwen gauge screen](../qwen-kernel-gauge-screen/README.md) uses one shared centroid over both heads and all eight train windows, uniform over their permitted causal pairs. It reduces mean exponent **3357.770→395.244** on train and **3525.875→429.194** on the same inspected held panel, with no held selection. The squared centroid norm2962.526 equals the train reduction, as (2) requires. Most mean geometry was a removable row gauge, but centered exponents remain large. Only a diagnostic FP64 center is stored in that study; a rounded paid center and actual shifted kernel output have not yet been evaluated. Neither the original enormous exponent nor its reduction decides the complete approximation frontier.

A shifted online implementation must retain the center's description, apply it before each feature insertion, and pay any stable prefix rescaling. It may fold a constant into a suitable existing affine producer, but a norm/RoPE boundary does not automatically permit that fold. Query-dependent centers can destroy shared-prefix reuse. The next experiment, if undertaken, must freeze the source-defined center and compare its actual finite reader against the same paid conventional cache controls, rather than choose another center after seeing held outputs.

```sh
python3 research/isa-quantization/positive-kernel-gauge/witness.py
lake env lean Kelana/PositiveKernelGauge.lean
```
