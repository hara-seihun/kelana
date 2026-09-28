# Residual transport is paired with differences of observer weights

The [frozen selectivity diagnostic](../value-feedback-selectivity/README.md) establishes a concrete mismatch: chronological feedback preserves uniform cancellation in contextual layer1 but worsens the actual selective V response. Replacing temporal adjacency by a different causal residual route changes the error map. It is not justified merely by calling a route key-local. This note states the exact observer obligation and the pending-state cost before any such code image is evaluated.

## Finite flow identity and the pending mask

Consider one KV head at a fixed query. Some visible tokens have already been quantized; the recent tokens have not. Let P be the former set and let `w_i=p_i` on P, zero otherwise. An emitted edge `i→j` carries a vector residual `u_ij` from a processed token to a later token. Its source is in P; its destination may still be recent. At an active quantized token, decoded-minus-source error is incoming residual minus outgoing residual plus an explicit arithmetic defect. Tokens skipped by a route retain their ordinary independent quantization error. Summing the actual finite divergence gives

```
weighted V error
 = sum_(emitted i→j) (w_j-w_i) u_ij
   + sum_(processed i) p_i defect_i
   + sum_(skipped processed i) p_i ordinary_error_i.
```

This is discrete integration by parts, not a new mathematical principle. Temporal first-order feedback is the chain `i→i+1`. A single outstanding-residual route is another increasing chain that can skip tokens; skipping does **not** make their original V errors disappear. Arbitrary splitting graphs would require additional residual records, routing identities and accumulation work.

The mask is indispensable. If j is already quantized, the edge coefficient is `p_j-p_i`. If j is merely an arrived **recent** token, the coefficient is **`-p_i`**, even though its current attention probability p_j is positive and its K/V are visible. Its incoming residual lives in the encoder; the unchanged BF16 recent V has not yet acquired that error. Adding `p_j*u_ij` early would invent output cancellation. The same obligation persists at an end-of-window pending recipient.

For a shared KV head, each Q head has a distinct p and O column block. The actual output coefficient of edge residual u is

```
C_ij = sum_(Q heads sharing this KV) (w_head,j-w_head,i) O_head.
```

Sum all edge, defect, ordinary-error and pre-existing K/source-offset vectors **before** squaring. The complete Gram contains cross-edge and cross-head terms. An isolated distance or per-head norm does not replace that objective.

The finite rational statements are proved in [`Kelana/ValueResidualTransport.lean`](../../../Kelana/ValueResidualTransport.lean). `weighted_divergence` derives the edge identity from unique covering enumeration via `ValueRecordQuotient.regroup`, rather than assuming a sum-exchange result. `masked_error_with_baseline` uses the actual quantized/recent mask and retains ordinary skipped errors inside it; the separate active-node formulation `observed_error` instead assigns skipped nodes to its ordinary-error branch. `emitted_edge_cost` proves the processed/pending split. Fixed coordinate/head linear pushforward is proved as well. These are exact rational algebra, not claims about source rounding, routing optimality or the observed program.

## When a key distance can help—and when it cannot

If both endpoints are quantized, their exact positive softmax probabilities obey

```
|p_i-p_j| = (p_i+p_j) * tanh(|score_i-score_j|/2),
score_i-score_j = q·(k_i-k_j)/sqrt(head_dim).
```

These use the **actual keys read by this query**, with its common normalization. Thus a small directional key difference can bound an interior edge response. Euclidean nearest-key routing is only a direction-independent proxy, and neither the probability mass `p_i+p_j` nor the projected residual disappears. For a pending endpoint the edge instead pays `p_i`; key proximity supplies no interior cancellation yet. Furthermore, a recent BF16 key may later be replaced by its K2 chunk reconstruction. A distance measured when the route is selected is not automatically the distance seen when that recipient ages or at later queries.

## One source-only screen, not a candidate ladder

A bounded source screen examines the existing eight contextual **train** streams without Q/O/teacher or held scores. At an active original V33 flush, after that step's K32 flush, it compares the oldest token's actual stored K to the 32 younger already-arrived V tokens' actual stored K representations. One deterministic squared-Euclidean nearest choice, earliest-position tie, defines the next recipient. Other V flushes would retain original codes while the residual waits. The [completed screen](../key-local-value-transport/README.md) reports paired immediate-versus-selected distances at the same source/time, the fraction of V events visited, waiting lengths, pending endpoint debt and distance drift after the target's K quantization. Selected distance sums fall to40.565% of immediate-successor sums, but only1,037/14,336 flushes are visited, with mean wait14.45 and64 outstanding end debts. Of973 completed targets,367 change K before their own V flush. The [paid consumer](../key-local-value-feedback/README.md) now measures the unchanged rule: validation SSE106.236 versus V34 106.488, but train209.967 versus206.290, at784B extra state and routing work. The geometry alone did not establish this mixed V/O outcome.

A prospective single-outstanding-record realization would carry 4,096 B residual plus eight u16 recipient indices (16 B) per sequence at this 256-token horizon. Its nominal cache-plus-state peak would be **308,880 B**, versus original304,768 B and unchanged-code V34 control308,096 B. That is only a representation bill, not an exported candidate. Reading/decoding up to33 key vectors and evaluating32 distances per active head, address arithmetic and temporary source/candidate vectors are online encoding costs. The source already owns the keys, but their reads and arithmetic are not free. No residual bank, skipped errors, future-key field or pending-state correction may be hidden in the geometry result.

## A distinct reader can expose the pending residual

There is an algebraic alternative to pretending pending debt has already canceled: explicitly add its **source-weighted** contribution to the query. For every pending edge i→j, adding `p_i u_ij` cancels the `-p_i u_ij` boundary term. `pending_read_correction` proves that the remaining transport sum contains only completed edges `(p_j-p_i)u_ij`; skipped ordinary errors and arithmetic defects remain. For one outstanding edge per KV head, the residual vector already exists, but the reader additionally needs the source token identity (eight u16 fields =16 B at this horizon), the actual source attention probabilities for both Q heads, and up to16×128 multiply-adds before the unchanged O map. It must read the FP32 residual, synchronize its query-visible preflush state and include the source-offset/cross terms. Neither the ordinary feedback reader nor the current key-local consumer performs this correction.

For the **already frozen temporal** encoder, the last encoded source is simply the number of quantized V tokens. It is determined by the existing chronology, so no extra source-index field is required. With n+1 encoded tokens in zero-based notation, [`ValueErrorFeedback.source_visible_residual`](../../../Kelana/ValueErrorFeedback.lean) proves

```
sum_(i<=n) p_i e_i + p_n r_(n+1)
 = p_0 r_0 + sum_(i<n) (p_(i+1)-p_i) r_(i+1)
             + sum_(i<=n) p_i eta_i.
```

The actual prequery carried residual—not the residual after the current query's flush—is needed. `recurrence_uniform_visible` proves that constant weights leave only the accumulated update defects when r_0=0. The [separately frozen reader](../kivi-feedback-visible-residual/README.md) now evaluates this exact source-weighted completion on existing temporal donor states: full contextual CPU queries and the eight retained layer0 queries, with FP32 multiply/add before the original O map. Its persistent state remains308864B peak/253952B final, including the existing4096B residual. It still pays residual traffic, separate head probabilities and2048 products/adds per query. No source or encoder regeneration, reader gain or routing choice is involved.

This is a changed reader map, not a free interpretation of the same cache or an observed improvement. In particular, smaller boundary error alone need not improve total error: it can destroy cancellation with completed edges, skipped errors or K/source offsets. The two distinct contracts are explicit: the key-local candidate changes the encoder and keeps the reader unchanged; the temporal visible-residual candidate keeps its encoder unchanged and changes the reader. The latter improves contextual feedback SSE0.547% train/0.416% validation, still behind the smaller V34 control, and worsens retained layer0 pooled SSE0.0117%. These are complete CPU outcomes, not GPU results. A [different state premise](MOMENT.md) retains the errors of unchanged independent codes as a moment, rather than redistributing those errors into later codes.
