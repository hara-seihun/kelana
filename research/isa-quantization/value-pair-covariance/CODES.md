# Deterministic pair codes and the omitted-response boundary

The [pair-rounding envelope](../value-rounding-risk/PAIR_ENVELOPE.md) fixes adjacent unbiased coordinate means. It does not exclude a deterministic biased assignment. The [one paid pair-code program](../kivi-pair-value-codes/README.md) makes that distinction executable: retain original source/fields and the source-defined disjoint matching, but minimize a stored2×2 quadratic over all16 digit pairs. This is not a new random coupling.

## What the source metric proves

Stack the two same-KV original O-head blocks into rows. For a coordinate pair with columns a,b, source error(x,y) has isolated response energy

```
Σ_o(a_o*x+b_o*y)² = A*x²+2B*x*y+C*y²,
A=Σa², B=Σab, C=Σb².
```

[`Kelana/ValuePairCode.lean`](../../../Kelana/ValuePairCode.lean) proves this finite Gram identity. Its actual finite scan keeps the first equal-scoring candidate and proves membership and energy≤every listed candidate. Including original digits therefore guarantees nonincrease in the selected local quadratic. The proof does not assume a desired local minimum. The conditional square identity

```
C*energy(x,y)=(C*y+B*x)²+(A*C-B²)*x²
```

also isolates the one-dimensional nearest-residual problem when the first digit is fixed and C>0.

The experiment stores A,B,C once in FP32 and evaluates with FP64 arithmetic. Those represented fields, exhaustive finite decisions and source bytes are independently replayed. The rational finite proof is not a proof of floating argmin/tie behavior or that rounded fields equal exact O Gram coefficients.

## Exactly when omitted responses cannot reverse the gain

Let x,y be old/new complete-output responses from the changed coordinates, with all attention weights already included. Write the remaining response as A*r. The finite identity is

```
||A*r+y||²-||A*r+x||²
 = D+2Σ_i r_i c_i,
D=||y||²-||x||²,
c_i=<y-x,A_i>.
```

The same Lean module derives this from actual output-coordinate sums, distributivity and Fubini. With distinct outside coordinates, it proves the exact iff:

```
∀ rational r, ||A*r+y||²≤||A*r+x||²
  iff D≤0 and ∀i, c_i=0.
```

Necessity is constructive. If c_j≠0, choose only
`r_j=(1-D)/(2*c_j)` nonzero; the complete SSE increase is exactly1, regardless of a finite local gain. This witness ranges over arbitrary rational outside errors in the stated span. It is not a claim that the witness is produced by a particular source/quantizer, nor an impossibility theorem for the paid candidate. It identifies what a universal local-surrogate claim would need. Fixed K/source bias, other pairs, tokens and shared heads are genuine omitted responses in the measured observer; their actual values must be retained.

## Paid outcome

All3,072 contextual queries and eight retained layer0 queries were independently replayed. Local represented energy decreased on all panels, but contextual validation complete SSE **107.923584→107.944003** worsened; train **209.016698→208.741073** and layer0 **.832658→.822787** improved slightly. A fixed original-code V36 delay4 control wins all three pooled panels at **311,424B peak**, versus **312,480B** for candidate cache plus7,712B static map/metric. Thus this particular program is rejected on the single-sequence error/state comparison, without claiming that every pair assignment or shared-sequence placement is dominated. No native work or larger-pair/metric sweep follows.

Direct `lake env lean Kelana/ValuePairCode.lean` exits0. This owner links the exact algebra; the consumer owns images, numeric source contract and cost receipts.
