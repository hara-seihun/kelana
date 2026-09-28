# Exact integer source-gauge optimality by a balanced circulation

The [coupled gamma study](../qwen-coupled-gamma/README.md) selected one integer power-of-two gauge by rounding a continuous matrix balance. **That already frozen gauge is globally optimal among all integer exponent vectors for its stored train matrix**, with that FP64 matrix interpreted as exact dyadic rational data. A balanced circulation proves the result; neither a numerical stationarity tolerance nor a search over a bounded exponent range is needed. The certificate did not change any exponent, gamma field, quantizer code or candidate selection.

This upgrades a finite mathematical objective, not the quality of the [gauged TurboQuant reader](../turboquant-coupled-gauge/README.md). The stored moment matrix is a rounded offline statistic of the actual source; the certificate does not silently promote it to an exact unrounded expectation or claim optimal full-attention error.

## 1. The general discrete theorem

Let `C_ab>=0` on a finite vertex set and choose a base `r>1`. For an integer vector e define

```
F(e) = sum_ab C_ab r^(e_a-e_b),
B_ab = C_ab r^(e_a-e_b).
```

Only exponent differences matter. For a subset S, increasing its exponents by one changes the objective by exactly

```
Delta(S) = (r-1) B(S,S^c) - (1-1/r) B(S^c,S).          (1)
```

The following are equivalent:

1. e globally minimizes F over **all** integer vectors.
2. `Delta(S)>=0` for every subset S.
3. There is a balanced nonnegative directed flow G with `B_ab<=G_ab<=r B_ab` on every edge, including zero edges.

For (1) implies (2), each subset move is an admissible integer vector. For (2) implies (1), use the integer exponential supporting bounds

```
r^k - 1 >= (r-1)k       if integer k>=0,
r^k - 1 >= (1-1/r)k     if integer k<=0.                (2)
```

The first is the finite geometric sum, each term at least one; the second is the negative finite geometric sum, each `r^-j<=r^-1`. For any alternative `e+h`, subtract the minimum of h so h is nonnegative. Write its nested superlevel sets as `S_t={a:h_a>=t}`. Every edge crosses exactly `|h_a-h_b|` such cuts, always in the same direction. Summing (2) edgewise gives

```
F(e+h)-F(e) >= sum_(t=1..max h) Delta(S_t) >= 0.
```

This proof works for arbitrary nonnegative C, including reducible support. Existence of a minimizer is a separate issue; a one-way positive edge can approach zero by an unbounded exponent difference without attaining it. Strongly connected positive support ensures coercivity modulo a common shift and hence attainment.

For (2) equivalent to (3), the bounded-circulation cut criterion is

```
B(S,S^c) <= r B(S^c,S) for every S.
```

Taking complements is exactly (1). It can also be obtained constructively: start at lower flow B, permit extra capacity `(r-1)B`, add a super-source or super-sink at each vertex for its lower-flow imbalance, and require saturation of every supply edge. Max-flow/min-cut supplies either a circulation or a violating cut.

### A compact independently checkable global witness

For r=4 set `f=(3/4)G`. Then balance and bounds give

```
(3/4)B_ab <= f_ab <= 3B_ab,
B_ab(4^k-1) >= f_ab k             for every integer k.
```

The sign of k determines which bound on f is used. Consequently

```
F(e+h)-F(e) >= sum_ab f_ab(h_a-h_b) = 0.
```

The last identity is just equality of each vertex's incoming and outgoing flow. The verifier therefore checks 4,096 simple interval conditions and 64 integer equalities, not exponentially many cuts. The continuous exponential tangent used in [GAUGE.md](../shared-sketch-covariance/GAUGE.md) has only one allowable slope; the discrete objective admits the whole supporting interval `[3B/4,3B]`. That extra interval is why an integer optimum need not have a vanishing continuous gradient.

## 2. One exact minimum-cut discriminator, not an exponent ladder

For r=4, multiply (1) by four:

```
4 Delta(S) = 12 B(S,S^c) - 3 B(S^c,S)
           = 9 B(S,S^c) + sum_(a in S) 3(rowB_a-colB_a).
```

The first term is a directed cut with nonnegative edge capacities `9B_ab`. The signed vertex terms are standard source/sink arcs, plus a constant from negative terms. Thus one minimum cut searches **every** subset move at once. A negative cut is a rigorously improving integer step; a zero minimum certifies global optimality by the theorem above. Under strongly connected support, repeated strict decreases terminate on the finite integer sublevel set modulo shifts. No strongly polynomial iteration bound is claimed here.

[`certify.py`](certify.py) uses exact integer capacities after clearing dyadic denominators. NetworkX is used to find the flow, not trusted by acceptance. The source's selected vector needed **zero** improving-cut steps: its first cut was nonnegative and a circulation existed immediately. This is not a new fit, a larger rounding sweep or a replacement of the already frozen source candidate.

## 3. Actual finite source certificate

Source: `qwen-coupled-gamma/train-pair-moment.npy`, SHA256
`62f68bad90c51b71123ddc2f7d151e093900fb29bb415ab829b38fcdee32c7ac`.
Every positive FP64 entry is converted using its exact integer ratio. It represents the source study's uniform 4,210,688 train causal query/key pairs over all sixteen Q heads and eight windows. No held statistic enters the certificate.

[`certificate.json`](certificate.json) stores the existing integer exponents, a common power-of-two denominator and the 64×64 integer balanced flow. [`verify.py`](verify.py) does not import the optimizer or a graph library: it independently parses the source matrix and certificate, reconstructs each rational `B_ab`, checks `B<=G<=4B`, checks all flow balances and recomputes both objective values. Its receipt is [`verified.json`](verified.json).

The exact global minimum is

```
344025728764016316897 / 36028797018963968
  = 9548.632128431498...
```

It is achieved by the original selected exponents and original 512-byte gamma image. Construction took about0.10s and independent verification about0.05s on one CPU thread. Those timings describe certificate work, not inference.

Reproduce from the repository root:

```
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/integer-gauge-balance/certify.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/integer-gauge-balance/verify.py
```

The certificate's unrestricted minimum also minimizes over any constrained representable-gamma set containing this same vector. It does not optimize arbitrary real scales, source rotations, different source laws, expected full-O risk, or a particular finite sketch's error. Shared matrix-balancing/convex-difference and circulation methods are standard optimization tools; the contribution here is their explicit all-integer source-gauge certificate and unchanged-source witness.

## 4. Formal boundary

[`Kelana/IntegerGaugeBalance.lean`](../../../Kelana/IntegerGaugeBalance.lean) proves the actual rational integer-power inequalities, the one-edge supporting interval, the `Rat.zpow_add` exponent-update identity and **global** cost optimality against every integer alternative from a balanced flow. It also proves common-shift invariance. There is no assumed exponential-support inequality or local-to-global hypothesis. `lake build Kelana.CoupledGaugeCost && lake env lean Kelana/IntegerGaugeBalance.lean` completed with exit0 in the integration writer. The max-flow/circulation equivalence and superlevel-set necessity proof remain the finite combinatorics above; Lean did not run NetworkX or ingest the numeric witness. That witness is checked separately by exact rational Python arithmetic.
