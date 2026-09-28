# Fiber codec proofs

`Kelana/FiberCodec.lean` proves the arithmetic core of the response-fiber codec using only `Std`.

Fix a probe `q` and partition ternary rows by

```text
S(w) = dot(w, q).
```

For a response `S`, let `N_S` be its exact fiber population and set

```text
b_S = ceil(log2 N_S)
W_S = 2^b_S.
```

Order the nonempty fibers by decreasing `b_S`. Their slots are consecutive. The offset of a fiber is the sum of the widths before it, and its code is

```text
code(w) = offset(S(w)) + rank_S(w).
```

Here `rank_S` ranges from `0` through `N_S - 1`.

## What Lean proves

`encode_injective` is the main losslessness theorem. It applies to any object type and any natural-number fiber labels. It needs three facts:

* every rank is smaller than its slot width;
* slots do not overlap;
* rank is injective within each fiber.

No fact about ternary weights is hidden in this theorem. If two complete codes agree, disjointness first forces their fiber labels to agree, then fiber-rank injectivity forces the original objects to agree.

`decode_encode` gives the corresponding executable left-inverse statement. A slot locator recovers the fiber label from a complete code. A fiber unranker then receives exactly the stored rank after offset subtraction and returns the original object.

The dyadic layout lemmas discharge the slot arithmetic:

* `dyadicOffset_append_slot` expands a later prefix offset.
* `earlier_code_lt_later_offset` proves that every valid code in one slot lies below every later slot.
* `dyadicOffset_aligned` proves that decreasing powers of two align the current offset to the current width.
* `dyadic_low_bits` proves `code mod 2^b_S = rank_S(w)`.
* `dyadic_high_bits` proves `code / 2^b_S = offset_S / 2^b_S`.

Thus the high `C - b_S` bits are the response prefix and the low `b_S` bits are the within-fiber rank. The consecutive disjoint intervals let a decoder identify which response prefix contains the code. For the distinguished probes `q` and `-q`, the consumer can use `S` or `-S` without unranking the weights. The row's FP16 scale is unchanged and multiplies that response exactly as it does in the source representation.

## Size bound

The file represents a fiber table as a list of `(N_S, b_S)` pairs. `payload` is

```text
P = sum_S 2^b_S.
```

`payload_lt_twice_population` sums the per-fiber inequalities

```text
N_S <= 2^b_S < 2 N_S
```

and proves

```text
P < 2 sum_S N_S.
```

When the fibers partition all ternary rows, `sum_S N_S = 3^n`, so `payload_lt_twice_ternary` gives

```text
P < 2 * 3^n.
```

`payload_fits_one_extra_bit` packages the bit consequence without importing real logarithms. If `3^n <= 2^k`, then `P <= 2^(k+1)`. `least_payload_bits_le` proves that the least whole-row width `C` therefore satisfies

```text
C <= k + 1.
```

Taking `k = ceil(n log2 3)` recovers

```text
C <= ceil(n log2 3) + 1.
```

For `n = 128`, this is `C <= 204`, compared with the 208 weight bits in the HALO row representation.

## Remaining executable obligations

The implementation must establish the hypotheses at the concrete row width. None requires a search over all `3^n` rows.

1. The suffix DP must compute exact `N_S` values and show that their sum is `3^n`. The standard recurrence is the disjoint split on the next trit, so the count proof can follow the same recurrence.
2. The ranker must prove `rank_S(w) < N_S`. At each coordinate, it adds the DP counts of lexicographically earlier feasible branches and descends through the branch chosen by `w`.
3. The ranker must be injective within one response fiber. Equivalently, the unranker must consume those same branch counts and prove `unrank_S(rank_S(w)) = w`.
4. The table builder must exclude empty fibers, choose each `b_S` with `N_S <= 2^b_S < 2 N_S`, sort by decreasing `b_S`, and form offsets by prefix sums. The Lean lemmas then supply alignment and separation.
5. The slot locator must return `S` for every produced code. A monotone search over the offset endpoints is enough; its proof is the interval membership supplied by the rank bound and consecutive offsets.
6. The wire width `C` must satisfy `P <= 2^C`. Unused codes from `P` through `2^C - 1` need no decoding contract.

For arbitrary input queries, the codec follows the proved `locate`, subtract, and `unrank` path before the ordinary weight consumer runs. For `q` and `-q`, it stops after locating the response prefix. This removes the guarded original-row fallback: every ternary row has one code, and every produced code recovers that row.
