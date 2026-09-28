# Causal probability odds, not an unreachable score matrix

A score-kernel rank is not automatically an attention lower bound. In causal self-attention, relative position zero pairs a token with itself; off-diagonal token pairs at that relative position need not be reachable. Also softmax ignores a common query-row logit shift. This study gives a **reachable two-position probability-odds** construction and an all-rank finite-error bound that respects both facts. It supports the independent [rotary score-factor study](../rotary-score-factor/README.md), not a claim to exclude all nonlinear attention programs.

## The legal candidate family and observed histories

Choose a finite set of current-token labels x and prior-token labels y. For each pair consider the actual length-two history `[y,x]`, observing the current query's probability of attending to the prior position versus itself. Write this probability p_xy and its log odds

```
L_xy = log(p_xy/(1-p_xy)) = prior_score(x,y) - self_score(x).
```

All pairs are reachable histories in this declared finite source family. The two-position construction is not an extension of a position-zero matrix to impossible off-diagonal pairs. In a layer-zero token producer the source query/key labels depend only on the token and position before attention; later-layer histories need not have that property.

The candidate class uses an r-dimensional shared prior-key carrier phi(y), a current-token/position-only query psi(x), and a query-only offset b(x):

```
Lhat_xy = psi(x)^T phi(y) + b(x).
```

Fixed rotary transforms and scale can be absorbed into psi/phi at these two positions. Learned normalization can be part of each token feature; its representation and computation are not presumed free. The candidate's own self term, biases and common row shifts are covered by b. Arbitrary functions of each separate label are allowed, not just linear source weight maps.

A different program whose query feature can depend on the prior token y, whose key has access to future x, or whose reader is a nonseparable table need not belong to this class. An r-component floating carrier is not r bits: arbitrary nonlinear decoding of a compact code can produce rank larger than its code dimension. The theorem is about the **separable dot/readout family**, not all encodings, attention state machines or ISA programs.

Let C=I-11ᵀ/n center over the n prior labels. Then

```
Lhat C = Psi (C Phi)^T,          rank(Lhat C) <= r.
```

The row offset disappears exactly. Thus exact probability preservation requires `rank(L C)<=r`. Rank of uncentered logits, or an unreachable raw-score extension, is not sufficient. On actual dyadic labels, the rotary study proves a stronger source certificate: 129 prior K rows augmented with ones have rank129 and selected position-one Q rows have rank128. Their **prior-key differences** therefore span128, giving a rank128 causal-odds obstruction after self/row-shift cancellation under that precise current-query/prior-key contract. This does not impose an approximate-error threshold by itself.

## A quantitative bound with no candidate logit cap

Suppose teacher probabilities are strictly between zero and one and let

```
v = min_xy p_xy(1-p_xy) > 0,
N = number of query/prior pairs,
R_r² = sum_{j>r} sigma_j(L C)²,
h(t) = t-1+exp(-t),     t>=0.
```

Every finite-logit candidate in the above family satisfies the **complete binary attention-distribution** bound

```
mean_xy KL(Bern(p_xy) || Bern(phat_xy)) >= (v/N) h(R_r).       (1)
```

No restriction on candidate probabilities, logits, emission grids or a tangent radius is used. An endpoint probability zero or one gives infinite KL for these positive teachers and satisfies the result by limit. The bound is positive whenever the centered rank exceeds r, but may be weak if rare teacher probabilities make v tiny or the relaxation can concentrate error.

Proof:

1. Put E=Lhat-L. Centering is a Frobenius contraction. Eckart–Young applied to the centered rank-r candidate gives `||E||_F >= ||E C||_F >= R_r`. Candidate row biases cannot evade this.
2. At each pair, the existing [finite-edit softmax variance inequality](../observation-loss/README.md) with binary logit edit `(E_xy,0)` gives `KL >= p_xy(1-p_xy) h(|E_xy|)`. This is an exact finite-edit inequality, not Fisher's quadratic extrapolation.
3. The function `g(s)=h(sqrt(s))` is increasing, concave on nonnegative s, and g(0)=0. For t>0, its second derivative has the sign of `(t+1)exp(-t)-1 <=0`. Concavity and zero value imply `g(a)+g(b)>=g(a+b)` for a,b>=0 (or integrate its decreasing derivative). Consequently `sum h(|E_xy|) >= h(sqrt(sum E_xy²)) >= h(R_r)`.
4. Multiply by v and divide by N.

A common mistake would replace h(R) by R²/2 globally. Large candidate logit errors have only linear KL growth; that quadratic lower bound is false without an extra range constraint. Conversely, averaging h(|E|) through an incorrect Jensen direction would overstate the bound. Equation (1) deliberately allows the error to concentrate and charges it only once.

Equation (1) is stated for uniform finite histories, not implicitly for language frequency. It is a local two-position attention-law result, not an autoregressive language-model or gold-NLL bound.

### Local rectangles and heterogeneous history mass

The same rank constraint holds after restricting to any query-by-prior rectangle A. For general nonnegative history weights a_xy, let R_A be the tail norm after centering within that rectangle, and `v_A=min_(x,y in A) a_xy p_xy(1-p_xy)`. Its unnormalized local loss is at least `v_A h(R_A)`. No separable assumption on history weights is needed: the minimum is taken only after restriction, and zero-mass rectangles simply give zero.

For any nonnegative rectangle shares lambda_A with per-cell load `sum_(A containing(x,y)) lambda_A <=1`, summing gives

```
sum_xy a_xy KL_xy >= sum_A lambda_A v_A h(R_A).
```

This is an immediate application of the existing [fractional cover charging theorem](../../../Kelana/PartialLabelCapacity.lean), not a new independent information inequality. It can preserve a useful balanced subrectangle when a rare near-deterministic cell destroys a global variance minimum. Rectangles overlap only through that explicitly budgeted charge. Certified rational lower endpoints and rational shares fit the existing finite Lean interface; the local real-log/rank premise is still analytic. No rectangle optimizer or improved numerical optimum is claimed here.

## Exact two-query / three-prior witness

Take a teacher with log-odds coefficient matrix

```
L = log(2) * [[1,0,-1], [0,1,-1]].
```

These are valid two-position histories: give the two current labels zero self-key score and query features e1/e2; prior features are `log(2)*(1,0)`, `log(2)*(0,1)`, `log(2)*(-1,-1)`. Current and prior label sets may be disjoint. Assign V=1 to the prior labels and V=0 to current labels with identity output; the live value/output response is exactly the prior probability, so these distinctions do reach a consumer.

The teacher probability matrix is `[[2/3,1/2,1/3],[1/2,2/3,1/3]]`. Rows are already mean-zero in log odds. Its rational coefficient Gram is `[[2,1],[1,2]]`, with eigenvalues3 and1. Therefore `R_1=log(2)` and v=2/9. Every rank-one separable key program, even with unrestricted real features and query offsets, has

```
mean binary KL >= (log(2)-1/2)/27 = .00715359928...
```

This is not the exact optimum. A legal shared-key-only probability reader with rows both `(7/12,7/12,1/3)` gives **.00957506104**; uniform probability gives .03775534. The arbitrary-real rank-one optimum is bracketed by the first two values, with no factor search. The strictly positive floor concerns this declared observer/domain/class, not a larger transformer.

### Actual small byte readers, with a strong direct control

[`witness.py`](witness.py) emits and independently parses two fixed-shape readers:

* [`direct.bin`](direct.bin): one format bit plus six two-bit probability indices, **2 physical bytes**, exact teacher error zero.
* [`shared-key.bin`](shared-key.bin): one format bit plus three two-bit probability indices, **1 physical byte**, ignoring the current-label selector and attaining the .00957506 value. It belongs to the rank-one family by taking psi(x)=1, phi(y)=logit(p_y), b=0; its executable reader returns the equivalent probability directly and never needs source Q/K vectors.
* [`probability-table.bin`](probability-table.bin): four positive rational values `{1/3,1/2,7/12,2/3}`, each a one-byte numerator and denominator, **8 generic bytes paid once**. Both readers consume these actual bytes. Thus their standalone data sizes are10 and9 bytes, excluding the common fixed-shape dispatch program. The upper padding bits are checked zero.

The generic alphabet is explicit and toy-specific; it is not a free learned dictionary or a model baseline. The smaller reader's higher loss is expected and does not make it dominated by the larger direct image. This is a transparent achievable witness for a universal family floor, not a new quantizer or native speed claim. Rational log intervals are reused from the existing causal-capacity certificate; the source reports exact interval endpoints and hashes in [`results.json`](results.json).

## Proof boundary and operations

The finite rational centering/factor foundation is supplied separately in `Kelana/CausalOddsRank.lean`: actual finite sums, bias removal, centered feature realization and squared-error contraction. Real matrix rank, Eckart–Young, real logs and the h/concavity argument in (1) are analytic here. The dyadic real-source rank receipts remain owned by the rotary study. Neither a numerical rank tolerance nor a finite sampled Gaussian producer establishes a whole reachable-domain claim.

```sh
python3 research/isa-quantization/causal-odds-rank/witness.py
lake env lean Kelana/CausalOddsRank.lean
```

The numerical witness runs in milliseconds. A candidate still needs an actual paid program and a comparable-size control before this lower bound can exclude it from an error/bytes/work frontier.
