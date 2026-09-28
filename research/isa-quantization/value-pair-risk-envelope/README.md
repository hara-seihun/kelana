# Pairwise-unbiased value rounding: full-O risk lower envelope

This is a **family discriminator**, not a proposed pairing, stochastic sample or online encoder. At the unchanged K2 source/attention and original complete O, it lower-bounds expected squared full-output error for **every partition of each original token/KV-head G32 into independent pairs and singletons**. A pair may use any joint law with the original clipped-unbiased adjacent decoded-grid marginals, including a query-specific oracle partition and covariance endpoint. Different flush events and different pairs remain independent; the same value code is shared by its two same-layer Q heads. Correlation across larger blocks, changed marginals/fields/means, changed K/attention or autoregressive feedback is not covered. The finite theorem is in [`../value-rounding-risk/PAIR_ENVELOPE.md`](../value-rounding-risk/PAIR_ENVELOPE.md) and `Kelana/ValuePairEnvelope.lean`.

## Bound

Let `f_i` be upper-level probability, `d_i≥0` the actual adjacent decoded-level gap after *separate FP32 multiply and add*, and `L_ij=max(0,f_i+f_j-1)`, `U_ij=min(f_i,f_j)`. For the centered binary indicators the joint-upper mass `tau` lies in `[L,U]`, hence `|tau-f_i f_j|≤c_ij=max(f_i f_j-L,U-f_i f_j)`. All four terms are based on original FP16 G32 fields and BF16 source, including deterministic endpoints/clipping. For the two Q heads of **one O layer**, source coefficient rows supply `gamma_ij=A_ij p0²+B_ij p0 p1+D_ij p1²`, where A/B/D are in units `2^-70` and B includes both cross-head dots. There is no layer mixing or independent-head assumption.

For each 32-coordinate group and vertex `i`, take `M_Xi=max_(j≠i) 2d_i d_j c_ij |X_ij|`, for each `X∈{A,B,D}`. A matching uses each vertex at most once, so its variance reduction is at most `½Σ_i(p0² M_Ai+p0 p1 M_Bi+p1² M_Di)` summed over the four G32 groups, all KV heads and aged flush tokens. This separately relaxes signs, pair choice and the triangle inequality; it permits a different oracle matching at *every query*. Let `B` denote that benefit upper, `V` the original independent-law variance, and `m` the unchanged mean-output SSE. The lower bound is `m+max(0,V-B)`; the maximum is justified by nonnegative output variance, **not clipping of the output**. The supplied numbers are FP64 source computations of this exact-law theorem, not outward-rounded interval certificates.

## Fixed source results

| Panel | Queries | Mean SSE `m` | Independent variance `V` | Benefit upper `B` | Risk lower | Original deterministic FP64 SSE | Lower / original |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Layer1 contextual train | 2,048 | 156.152406 | 93.612750 | 12.233834 | **237.531322** | 209.016696 | **1.13642** |
| Layer1 contextual validation | 1,024 | 76.951085 | 50.809169 | 6.579833 | **121.180421** | 107.923582 | **1.12284** |
| Layer0 held t128/t256 | 8 | 0.179568 | 0.337181 | 0.031018 | **0.485730** | 0.832658 | **0.58335** |

Thus even this permissive per-query oracle pairing cannot beat the original deterministic SSE *in aggregate* on either contextual panel under the stated pairwise-independent marginal law. It does **not** exclude the family on the eight layer0 queries. Individual contextual queries can improve (115/2048 train, 94/1024 validation); the aggregate statement is not pointwise. At the early contextual queries the no-aged-token zero-variance floor is exact (`264` train, `132` validation). The contextual benefit upper decomposes into `(A,B,D)` contributions `(4.047329,1.474544,6.711962)` train and `(2.388270,0.732735,3.458828)` validation; held `(0.014835,0.003737,0.012446)`. The independent expected risks in the same source are 249.765157 / 127.760254 / 0.516749. The separately certified fixed map scores 247.816400 / 126.706610 / 0.511393; it is a sanity comparator, **not** selected or fitted here. The original deterministic law has different means, so its SSE is a comparator, not a member of this class.

[`certificate.py`](certificate.py) consumes the exact corrected [source two-Q-head within-layer coefficients](../value-pair-covariance/README.md), the same 16 source windows/retained states and pinned original [independent-risk per-query results](../kivi-value-rounding-risk/README.md). It reconstructs **only** grid gaps/probabilities and fixed attention contraction, not the mean, independent variance or deterministic controls. It checks original source, donor, event, stored-field and O hashes. Each `panel-window.json` retains 224 token × 8 KV-head × 3 upper constants, all per-query bound components and original per-query risk fields. Its t128/t256 diagnostics explicitly build *all* 496 pair edge gains per G32, assert the triangle inequality and compare the direct row envelope against the precontracted upper. The `all_pair_edge_gain_sum_not_a_matching` diagnostic is intentionally **not** compared to the matching bound (it can count 31 incident edges per vertex). The source-certified static pair map's direct covariance reduction is at most both that all-edge sum and the envelope in all 32 retained bounded queries; no new matching optimization is performed. [`summary.json`](summary.json) pins every result and source hash, pooled totals and bounded diagnostics.

Reproduce each window in under a minute on CPU (the source owner's venv supplies NumPy/Torch); parallel windows are independent:

```sh
cd research/isa-quantization/value-pair-risk-envelope
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python certificate.py train 0
# train 0..7, validation 0..3, held 0..3
python aggregate.py
```

This is an **offline source certificate** requiring graph/grid preparation and contraction; it supplies no paid random code, cache encoder, storage or latency result. Its conclusion is conditioned on teacher-forced fixed Q/K and original O, not a changed rollout.
