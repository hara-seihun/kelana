# Does knowing the eight routed experts save the common down-output rank?

For the pinned Qwen3.6-35B-A3B official BF16 layer-0 experts 0–15, route-specific output bases are a useful *oracle*, but not a practical frozen representation. At rank 512, the optimal basis fitted separately to each of three eight-expert routes loses .606, .582 and .599 relative RMS under independent isotropic expert hidden vectors. The one basis fitted to all sixteen loses .673, .675 and .675 on those routes. Route knowledge buys about seven to nine RMS points, but still discards 34–37% of squared response energy in the best possible orthogonal rank-512 output projection for this input model. Rank 1024 loses .342, .310 and .332 with an oracle route basis, and already takes 75% of the direct down MAC count before routing, scatter or shared-expert work.

## Exact family statement

Fix an eight-expert route `S`, nonzero router weights `a_e`, and independent `h_e ~ N(0,I_512)`. Let `W_e` be the exact real matrix represented by each BF16 down tensor. The required real output is `y = sum_{e in S} a_e W_e h_e`. A consumer that emits `C z` for an orthonormal `C` with `r` columns, with no restriction on how it computes `z`, has minimum squared error

`min_z E||y-Cz||² = tr(G_S) - sum_{j=1}^r lambda_j(G_S)`, where `G_S = sum_{e in S} a_e² W_e W_e.T` and eigenvalues are ordered largest first.

The proof is pointwise orthogonal projection: `z=C.T y` attains the minimum, and `E yy.T=G_S` by independent zero-mean hiddens. Ky Fan's principle gives the leading eigenspace. This even permits a free route-dependent basis, so it is an optimistic family bound. Exactness for unrestricted independent hiddens and nonzero coefficients requires `span(C)` to contain the column span of the concatenated selected matrices. Correlated, producer-reachable expert hiddens can have a different covariance and are **outside** this result. Even a full-rank real identity does not establish bit-identical native FP32 reductions.

The experiment fixes equal coefficients. Their common scale cancels in relative RMS, so the three panels are not predictions for real router scores. In fact, a rank-512 basis can include *all* columns of the highest-scored expert. For independent isotropic hiddens, its squared relative error is then no more than the other seven experts' fraction of `sum_e a_e² ||W_e||_F²`. This construction can become good when one expert dominates that weighted energy; we have not measured that fraction on actual routes. It uses three named routes, not a sample of model routing: experts 0–7, 8–15 and even IDs from 0–14. It also fits one universal basis to all sixteen as a frozen control. The optimization domain is the complete 2048-output vector. It does not include the next layer's observation or permit a nonlinear decoded carrier, and thus says nothing about every whole-map representation.

| Basis fitted on | Relative RMS on route 0, rank 512 | Route 1 | Route 2 | Rank 1024 on its own route |
| --- | ---: | ---: | ---: | ---: |
| All sixteen | .6730 | .6749 | .6747 | .4386 / .4431 / .4391 |
| Route 0 only | .6056 | .8346 | .7042 | .3423 |
| Route 1 only | .8373 | .5815 | .7489 | .3103 |
| Route 2 only | .7087 | .7422 | .5993 | .3325 |

Route-conditioned bases are expensive to store. Within *just* these sixteen experts there are `C(16,8)=12,870` routes. At BF16, one rank-512 `[2048,512]` basis per route takes 2 MiB, or 26.99 GB before any route-dependent factors. The sixteen original BF16 down matrices together take 33.55 MB. This is not an information-theoretic minimum; a compressed basis generator might trade online work against storage, which this experiment has not priced. The ordinary shared-factor rank-512 arithmetic is `8*512*512 + 2048*512 = 3,145,728` MACs against `8*2048*512 = 8,388,608` direct routed down MACs. If the basis varies by route, expert factors `C_S.T W_e` must also vary or be formed online; counting only those MACs and ignoring the basis/factor selection would be dishonest. The shared expert, gate/up, router, nonexpert projections, materialization and FP32 contraction are excluded from these down-only counts.

## Receipt and next question

Run from the Kelana root with NumPy and SciPy, one panel per bounded command:

```sh
for panel in all16 route0 route1 route2; do
  OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 python3 research/moe/route-rank/measure.py \
    /path/to/workspace/data/qwen-moe/experts/layer-0-0-16/down_proj.bf16 \
    --panel "$panel" --output "/path/to/workspace/data/qwen-moe/route-rank/$panel.json"
done
```

The four JSON receipts under `/path/to/workspace/data/qwen-moe/route-rank/` contain every rank-256/512/1024 fit and cross-route projection, input and source hashes and the cost arithmetic. The raw BF16 down payload SHA-256 is `dedf89a870022529f6eb3990e3ee6aa74a9e26fa490a5e7b1d4a7e33c9e32cd6`; its range-acquisition manifest is `/path/to/workspace/data/qwen-moe/experts/layer-0-0-16/down_proj.json`. No GPU, real-route observation, complete-model quality or runtime changed.

A more expensive frozen route-basis catalogue is not earned by this bound. The next useful input is native traces of producer-reachable routed hiddens and scores on separate train and held text. Test whether their *composed* covariance has a substantially sharper spectrum, against the actual mixed-quantized model and complete quality before designing a packed consumer. The dense sub-bit pilot showed that even held isolated response improvements may lose complete-model NLL.
