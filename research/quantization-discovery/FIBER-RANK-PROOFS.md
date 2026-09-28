# Fiber rank proofs

`Kelana/FiberRank.lean` proves the suffix-DP ranker used by the lossless response-fiber codec. It imports only `Std` and works for any signed integer probe, including repeated and zero coefficients.

## Definitions

`Trit` has exactly three constructors in codec order:

```text
neg, zero, pos
```

Their integer values are `-1`, `0`, and `1`. Using this type makes the ternary-alphabet condition intrinsic.

For a probe suffix `q` and requested response `s`, `count q s` is defined by

```text
count [] s = if s = 0 then 1 else 0
count (a :: q) s =
  count q (s + a) + count q s + count q (s - a).
```

The three terms count rows whose next trit is `-1`, `0`, and `+1`. The formula still holds when `a = 0`. In that case the three branch intervals have equal response labels but remain disjoint rank intervals because the next trit differs.

`rank q s w` traverses those branches in the same order. It adds no earlier interval for `-1`, adds the negative interval for `0`, and adds both earlier intervals for `+1`. It then updates the target to `s + a`, `s`, or `s - a`.

`unrank q s r` performs the inverse interval decisions. It compares `r` with the negative count, subtracts that count when needed, then compares with the zero count. The remaining interval is the positive branch.

## The proved contracts

`InFiber weights probe target` records both required input conditions: the lists have equal length and their integer dot product is `target`. `InFiber.spec` extracts those ordinary conditions. `inFiber_of_spec` constructs the evidence from an equal-length hypothesis and `response weights probe = target`.

The core induction proves:

```text
rank_lt_count:
  InFiber w q s -> rank q s w < count q s

unrank_rank:
  InFiber w q s -> unrank q s (rank q s w) = w
```

The public forms `rank_lt_count_of_response` and `unrank_rank_of_response` require only `weights.length = probe.length`; they use the computed dot product as the fiber response.

Two converse results show that the recurrence counts exactly the rank intervals rather than merely upper-bounding them:

```text
unrank_inFiber:
  r < count q s -> InFiber (unrank q s r) q s

rank_unrank:
  r < count q s -> rank q s (unrank q s r) = r
```

Together these theorems give a bijection between the natural numbers below `count q s` and the ternary rows in response fiber `s`. They also prove fiber-rank injectivity, the remaining rank hypothesis used by `Kelana/FiberCodec.lean`.

The proofs are symbolic inductions over the probe and weight lists. Lean does not evaluate the recurrence at width 128. A memoized implementation may replace the reference recursion because it computes the same recurrence and uses the same branch counts.

## Query residual identity

`queryResidual alpha q x` computes `x - alpha*q` coordinatewise. `response_queryResidual` proves, under matching lengths,

```text
dot(w, x) =
  alpha * dot(w, q) + dot(w, x - alpha*q).
```

The theorem allows arbitrary integer `alpha`, not only `-1`, `0`, or `1`. A consumer already knows `dot(w,q)` from the response prefix. It therefore needs weight trits only where the residual query is nonzero. If the residual becomes zero after some coordinate, suffix unranking contributes nothing to the residual dot product and can stop there. This is still one unconditional codec. It does not retain or select an original-weight fallback.

## Implementation correspondence

A memoized ranker or unranker must preserve these details:

1. Its DP key is `(suffixPosition, residualResponse)` and stores the exact natural-number count.
2. Its base row is one only for residual response zero.
3. It keeps branch order `-1`, `0`, `+1` everywhere.
4. Ranking adds complete earlier-branch counts before descending.
5. Unranking subtracts the same counts before descending.
6. Zero probe coefficients still create three separate branches and must not be collapsed.

Those conditions are sufficient to instantiate the slot-code proofs. No finite enumeration or probabilistic test is part of the argument.
