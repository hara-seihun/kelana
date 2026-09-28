# Direct packed-consumer proofs

`Kelana/DirectConsumer.lean`, namespace `Kelana.DirectConsumer.ChunkTable`, formalizes an exact response table for short ternary weight chunks. The construction works for every integer query. It does not compare the query with a probe and has no fallback path.

## Encoding and response

`ChunkTable.Trit` has values `-1`, `0`, and `1`. For a chunk `w`, `code w` is its most-significant-trit-first base-3 integer, with digits `0`, `1`, and `2` in constructor order:

```text
code []       = 0
code (t :: w) = digit(t) * 3^length(w) + code(w)
```

For equal-length `w` and `q`, `response w q` is their integer dot product.

The code is genuinely dense. `code_lt_pow` proves that a width-`k` code is below `3^k`. `decode k i` constructs a width-`k` ternary chunk, and `code_decode` proves

```text
i < 3^k -> code (decode k i) = i.
```

Thus every array index from zero through `3^k - 1` names a chunk. This is stronger than proving only that encoded chunks fit in the array.

## Recursive table construction

For an integer query chunk, `table` is defined by

```text
table []       = [0]
table (q :: s) = map (fun x => x - q) (table s)
                  ++ table s
                  ++ map (fun x => x + q) (table s).
```

These are the `-q`, `0`, and `+q` copies of the suffix table. `table_cons` exposes that recurrence, and `table_length` proves that a width-`k` table has exactly `3^k` entries.

The main contract is:

```text
table_lookup
  (sameLength : weights.length = query.length) :
  (table query)[code weights]? = some (response weights query)
```

The proof follows the encoded head trit into the first, second, or third block and applies the induction hypothesis to the suffix code. The `some` result proves both index validity and exact response. Query coordinates have type `Int` and carry no range, sign, or equality hypotheses.

A runtime can therefore build one table for a query chunk and serve any number of packed rows by loading `table[code]`. The lookup does not reconstruct the chunk's individual trits. The Lean theorem specifies the mathematical table and lookup; it does not certify a native parser, array layout, vectorized load, or cache behavior.

## Adjacent chunks

The code and response compose across list concatenation:

```text
code_append:
  code (a ++ b) = code a * 3^length(b) + code b

response_append:
  response (a ++ b) (x ++ y) = response a x + response b y
```

`table_lookup_append` combines these facts. It proves that the direct combined index returns the sum of the two chunk responses. Implementations need not allocate the exponentially larger combined table: they may look up the two smaller tables and add the results, using `response_append` as the mathematical justification.

## Construction and reuse counts

A width-`k` table contains `3^k` integer responses. In the direct recurrence, extending a suffix table of length `3^j` computes two shifted copies. This uses `2 * 3^j` integer additions or subtractions. The recurrence

```text
A(0)     = 0
A(j + 1) = A(j) + 2 * 3^j
```

gives `A(k) = 3^k - 1` shift operations for one table. `shiftOps_capacity` proves `shiftOps k + 1 = 3^k` for this recurrence. It counts arithmetic shifts, not runtime allocation or copies.

For `R` row lookups sharing one query and uniform width `k`, a simple build-plus-lookup proxy per original coordinate is

```text
(R + 3^k - 1) / k.
```

After clearing the positive denominators, moving from width `k` to width `k + 1` improves or ties this proxy exactly when

```text
(2*k - 1) * 3^k <= R - 1.
```

`neighbor_cost` proves the cleared comparison for arbitrary integer `k`, `R`, and table-size parameter `p`, instantiated here with `p=3^k`. `threshold_growth` proves that the crossover threshold increases strictly for `k>=1` and `p>0` when the next width triples `p`.

The planner charges one abstract lookup-accumulation unit per row and chunk. That groups a memory lookup and response accumulation into one proxy unit; it is not one machine instruction. Table-copy traffic, allocation, packed-code extraction, SIMD width, cache effects, and instruction latency are not priced. This is not a cycle estimate.

## Difference from response-fiber coding

`FiberRank` stores a response to one chosen probe and uses that response while ranking or unranking a fiber. Its residual identity helps when a later query is related to the probe.

This result uses a different trade. The row stores only a dense base-3 chunk code. Each actual query supplies a fresh response table, and `table_lookup` proves the answer for that query directly. Every integer query is supported. There is no single-probe equality guard and no claim that the query-dependent table is free to build.
