# Exact minimum preparation for a sign-folded response table

The [direct consumer](../DIRECT.md) computes a ternary chunk's dot product by indexing a table prepared from the current input. Its scalar full-table recurrence counts `3^k - 1` add/subtracts per chunk. The sign-folded consumer needs only codes `0..(3^k-1)/2`; the other half is obtained by changing the sign of the response. Here is a minimum straight-line preparation for that half-table. This is a query-dependent construction, not a timing result or a replacement for the CPU SIMD preparer.

## Contract and lower bound

Let `x_0..x_(k-1)` be independent formal integer inputs. Code `c` has little-endian base-three digits `d_i` and denotes `sum_i (d_i-1)x_i`. The table stores the response for each `c <= (3^k-1)/2`, including the center code whose response is zero. Negating every trit takes `c` to `3^k-1-c`, so the rest of the exact table follows by sign. There are `(3^k-1)/2` distinct, nonzero **formal linear forms** in the stored half, none equal to a supplied positive input `x_i`. Zero and the positive inputs are free; one scalar binary add or subtract produces at most one new form. Thus at least `(3^k-1)/2` add/subtract instructions are required by *every* straight-line program in this grammar, even one that uses coefficients other than ternary along the way. This is a bound for a complete table valid for every integer query, not for one numerical query or only the codes that happen to occur in a trained weight block. A free sign inversion, SIMD fanout, a multi-result instruction, precomputed negated inputs, or a different table representation changes the cost model.

The bound is attained. Start with zero and the `x_i`. At coordinate `j`, form `-x_j = 0-x_j`. For every previously stored nonzero representative `p`, compute `-x_j+p` and `-x_j-p`. The new forms have highest nonzero coordinate `-1`, and their lower coordinates cover both signs of every old orbit. No result repeats. There are `1+2(3^j-1)/2 = 3^j` new forms at stage `j`, giving `sum_(j=0)^(k-1) 3^j = (3^k-1)/2` instructions. Code order is the existing sign-orbit convention: a lower numeric code is the representative, so the highest nonzero trit is negative. The construction does not reconstruct weights or individual weight trits online.

| chunk width | half-table entries including zero | minimum add/sub | full-table minimum in the same grammar | ordinary three-branch recurrence |
| ---: | ---: | ---: | ---: | ---: |
| 2 | 5 | 4 | 6 | 8 |
| 3 | 14 | 13 | 23 | 26 |
| 5 | 122 | 121 | 237 | 242 |
| 6 | 365 | 364 | 722 | 728 |

For 128 coordinates in 42 three-trit chunks and one two-trit tail, the half-table preparation needs exactly **550 scalar add/sub results**; the full-table lower bound is **972**, and the three-branch recurrence counts **1,100**. These counts do not include table stores, input loads, row-index extraction, sign correction, lookup, scale application, or a complete output head. The [existing CPU SIMD consumer](../SIMD.md) creates a 32-lane register image by vector multiplying broadcast query coordinates with compile-time coefficients and adding them, including both signs. Its vector instructions cannot be equated with these scalar result counts. No native speedup is claimed.

For signed-int8 queries and a chunk of at most 255 trits, every intermediate here is a dot product of ternary coefficients with a subset of the query. Its absolute value is at most `128k <= 32640`, so signed16 storage and add/sub do not overflow. This is the same width restriction used by the existing SIMD experiment. It is an **integer** statement; joining the FP16 block scale and FP32 accumulation in Bonsai still requires the original rounding schedule to reproduce exact logits.

## Executable witness and next experiment

`python3 research/quantization-discovery/sign-orbit-prep/prep.py` emits the counts and checks the symbolic DAG, every half-table code through width seven, all queries in `[-2,2]^k` through width three, and twelve signed-int8 queries per larger width. Each query compares *every* full-table code to an independent dot-product evaluation via the sign-orbit address. The structural lower bound above holds for all integer queries; these finite checks guard the implementation and code orientation.

A native comparison should prepare the same 43 tables for each input, including the two-trit tail, then consume all 5,120 real weight rows of the 128-wide fixture. Measure query preparation plus evaluation against the existing SIMD producer under rotating paired order, separately from warm evaluation. On gfx1151, first price the 13-add DAG's register lifetime, 14 response slots, sign correction and lane broadcast; the assembled wave lookup already loses against two-bit WMMA in the [GPU study](../gpu-direct/README.md). Reducing preparation alone does not erase that measured consumption loss. The only reason to revisit it is a shared consumer or several outputs that amortize the table while keeping the query-dependent work in the measured interval.
