# Complete a calibration quadratic from a source-defined producer law

The [full-row QuIP/scalar comparison](../quip-full-row-slab/README.md) reverses on held states. The [fixed-image diagnosis](../quip-covariance-transfer/README.md) identifies the missing premise: repeated calibration tokens leave a large kernel, and the structured image puts more coefficient error there. This report derives a **parameter-free quadratic completion**, conditional on a separately justified source reference moment. It is not another quantizer fit or a claim that uniform vocabulary equals language traffic.

## A source moment and an observed subspace

Let `H = E_cal[x xᵀ]` be the empirical, uncentered calibration second moment, normalized per input observation. Write `R=range(H)` and `N=ker(H)`, so in orthonormal R/N coordinates

```
H = [ H_R  0 ],       H_R > 0.
    [  0   0 ]
```

Suppose a source-defined reference producer law supplies a positive definite second moment G, in the same units and coordinates. The [layer-0 token-producer study](../quip-token-producer/README.md) now supplies a complete uniform-ID moment from all 151,936 source embeddings and the actual RMSNorm path. Its capture-equivalent CPU realization matches all captured entries. Uniform ID remains a chosen source law, not a claim about language frequency or every GPU reduction order. Partition G into R/N blocks and define

```
B = G_NR G_RR^(-1),
S = G_NN - G_NR G_RR^(-1) G_RN,
L = [ I 0 ].
    [ B I ]
```

Both `G_RR` and the Schur complement S are positive definite. Define the completed metric

```
M = L diag(H_R,S) Lᵀ
  = [ H_R         H_R Bᵀ       ].
    [ B H_R       S+B H_R Bᵀ   ]
```

This preserves the *supported block* `M_RR=H_R`, not every empirical zero involving unobserved coordinates. For a coefficient error column `(r,n)` its cost is

```
(r,n)ᵀ M (r,n) = (r+Bᵀn)ᵀ H_R (r+Bᵀn) + nᵀ S n.
```

It therefore retains source-reference coupling between visible and unseen error directions, instead of independently damping every unseen coordinate. If `H_R=AᵀA` and `S=CᵀC`, this is the actual Gram response norm

```
||A(r+Bᵀn)||² + ||Cn||².
```

It is positive definite when A and C have trivial respective kernels, and equals the calibration cost for n=0. No producer Gaussianity is needed for these algebraic statements.

The coordinate-free formula uses the orthogonal projector P onto R and the inverse of `PGP` on R (Moore–Penrose inverse on the whole space):

```
V = G P (P G P)^+,
S0 = G - G P (P G P)^+ P G,
M = V H Vᵀ + S0
  = G + V (H-PGP) Vᵀ.
```

This is invariant under changing orthonormal bases within the two subspaces. If H has full rank, it returns H. If its supported block equals the reference block, it returns G. It introduces no fitted damping constant and no additional inference image fields; any quantizer using it still pays its ordinary stored representation and execution. Its eigenspace/Gram preparation is not free runtime work.

## Why this particular completion?

It is the unique positive definite matrix with supported block H_R minimizing the matrix divergence

```
D(M||G) = 1/2 [ tr(G^(-1)M) - log det(G^(-1)M) - d ].
```

This is a variational criterion on second moments. Equivalently it is KL between *auxiliary zero-mean Gaussian distributions* with those covariances, but it does **not** assert that the actual source producer is Gaussian (the earlier function-kernel study explicitly falsified that premise).

Proof: any feasible positive definite candidate has cross block `F H_R` and conditional block `T>0`, hence equals `[[H_R,H_R Fᵀ],[F H_R,T+F H_R Fᵀ]]`. The block trace/determinant identity, or Gaussian chain rule applied only to these auxiliary distributions, decomposes its divergence as

```
D(H_R||G_RR)
 + 1/2 [tr(S^(-1)T) - log det(S^(-1)T) - dim(N)]
 + 1/2 tr(S^(-1)(F-B)H_R(F-B)ᵀ).
```

The second term is nonnegative because every positive eigenvalue obeys `t-log(t)-1>=0`, with equality only at T=S. The last term is a squared Frobenius norm, zero only at F=B. The first is fixed. This proves existence, uniqueness and the displayed formula, not predictive optimality for an unknown data distribution.

## Exact finite discriminator, including a wrong-prior control

[`witness.py`](witness.py) uses rational arithmetic only. With one supported coordinate,

```
H_R=4,  G=[[1,4/5],[4/5,1]],
M=[[4,16/5],[16/5,73/25]],
e_A=(0,1/5),  e_B=(1/10,-1/5).
```

Both legal error maps may be regarded as equal-priced finite program choices. The matrices are error metrics, not paid inference fields.

| Metric | e_A | e_B | Choice |
| --- | ---: | ---: | --- |
| Calibration H | 0 | 1/25 | A |
| Independent diagonal fill diag(4,1) | 1/25 | 2/25 | A |
| Conditional completion M | 73/625 | 18/625 | B |
| Reference G | 1/25 | 9/500 | B |
| Opposite-correlation reference G' | 1/25 | 41/500 | A |

The example distinguishes conditional completion from merely removing the kernel with an independent penalty. The final row is indispensable: an incorrect reference correlation can make completion choose the worse program. Nothing here guarantees that a source-uniform law is the actual deployment law.

## What this gives the investigation

A source-defined, complete producer moment would change the calibration premise without another arbitrary ridge ladder or validation-selected fit. The first decision is whether the actual producer factorizes as claimed and whether a meaningful complete-source moment is available. Only then does one predeclared comparison merit running, with **both** named structured and scalar controls supplied the same metric, all byte fields retained, and the already inspected validation named as such.

This is not permission to replace calibrated error by a free decoder or to select the metric from held winners. If the reference fails to match the actual producer, it does not repair the quantizer. If G is singular, this positive-definite construction requires restricting to its true reachable support and checking calibration containment; silently adding an arbitrary identity is a different method.

Proof scope: the matrix completion and divergence argument above are analytic. The finite rational Gram/zero-energy foundation is proved in [`Kelana/CovarianceCompletion.lean`](../../../Kelana/CovarianceCompletion.lean): explicit finite Gram assembly, completed energy identity, PSD, supported-block preservation and kernel characterization. It does not formalize the logarithmic variational argument. The exact witness is runnable in milliseconds and makes no trained-model accuracy claim.
