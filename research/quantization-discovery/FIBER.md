# A lossless code that exposes the consumer response first

The [local producer enclosure](ENCLOSURE.md) found a five-byte weight replacement, but its literal guard was larger than the source weight block. This round changes what the packet stores. It keeps a useful response at the front and an exact description of the remaining ambiguity behind it. The original weights are recoverable for every other query.

This is an **unconditional lossless representation**, with a conditional shortcut. A query outside the shortcut does not need an original-weight copy, a remote model, or permission to exceed an error bound.

## The representation

Fix a shared integer probe `q` of length `n`. Partition all ternary weight rows by their response

```
S = sum_i w_i q_i,       w_i in {-1,0,1}.
```

Let `N_S` be the number of rows in response class `S`. The payload stores:

1. a prefix identifying `S`;
2. the row's exact rank among the `N_S` rows with that response.

For query `q`, the prefix is already the answer. For `-q`, negate it. For another query, recover the trits from the within-class rank and evaluate normally. The original FP16 weight scale is stored unchanged, so the integer response and scale can rejoin the existing consumer boundary without changing its floating-point accumulation tree.

These classes are the fibers of the response map. Enumerative coding supplies the rank. Neither fiber decomposition nor enumerative coding is a novelty claim. The implementation combines them with a fixed-width dyadic allocation and a plane layout chosen for partial consumption.

## One extra bit above the fixed-length ternary floor

For each nonempty fiber choose

```
b_S = ceil(log2 N_S),
P = sum_S 2^b_S,
C = ceil(log2 P).
```

Allocate disjoint slots of size `2^b_S`, largest first. The start of each slot is then aligned to its size. Encode a row as

```
code = slot_offset_S + rank_within_S.
```

The low `b_S` bits hold the rank; the high `C-b_S` bits identify the slot. These variable-length response prefixes are prefix-free because their aligned slots are disjoint. Every row still occupies exactly `C` bits, so it needs no per-row length or offset table.

Since `N_S <= 2^b_S < 2 N_S`,

```
P < 2 sum_S N_S = 2 * 3^n,
C <= ceil(log2(3^n)) + 1.
```

This is a general storage bound, independent of the particular probe or weight row. The one-bit overhead is relative to the minimum fixed-width code for arbitrary ternary rows. It is not a claim that this is the optimal entropy code for a trained model.

[The slot proofs](FIBER-PROOFS.md) establish injection, left inversion, alignment, high/low decomposition and the capacity bound in [FiberCodec.lean](../../Kelana/FiberCodec.lean).

## Exact counts without enumerating `3^n` rows

For the remaining probe suffix, use

```
count([], S) = 1 if S=0, otherwise 0
count(a::rest, S) = count(rest, S+a)
                   + count(rest, S)
                   + count(rest, S-a).
```

Rank and unrank follow the three disjoint first-trit branches, in order `-1,0,1`. Zero and negative probe entries work without special semantic assumptions. The implementation first divides the probe by its positive common divisor, if any, so it does not store impossible residue classes; response labels are multiplied back at the boundary.

Memoization needs `O(n sum |q_i/gcd(q)|)` integer cells and arithmetic operations. Counts have at most `ceil(n log2 3)` bits. This is pseudo-polynomial in the numeric probe range, not a polynomial-time recipe for arbitrary executable consumers. Rank or unrank then visits `n` suffix decisions per row.

[The rank proof](FIBER-RANK-PROOFS.md) connects this recursion to arbitrary-length ternary rows in [FiberRank.lean](../../Kelana/FiberRank.lean). The byte layout and Python implementation remain separate executable obligations.

## The actual Bonsai block

The [fixture](instances/bonsai-layer00-down-block0.npz) contains all **5,120 output rows**, each with 128 trits and its exact FP16 scale, for layer 0 down-projection input block 0. It is not a sample of output rows. The shared probe is the first real captured hidden operand block.

The root count table has 6,727 reachable responses. The payload width is **204 bits per weight row**, versus 208 weight bits in HALO. Scales add 16 bits in both formats.

| Stored component | Bytes |
|---|---:|
| Complete 204-bit row payloads | 130,560 |
| Original FP16 scales | 10,240 |
| Shared probe | 128 |
| Header | 20 |
| **Complete self-contained image** | **140,948** |
| Original HALO representation | 143,360 |
| **Reduction** | **2,412 bytes, 1.68%** |

Every one of the **655,360 trits** and every scale bit round-trips. No original HALO data is required by either query route after encoding. The modest size reduction is unsurprising: this block's trit histogram is nearly uniform, at 1.58486 empirical bits/trit, close to `log2(3)`.

The complete image is [bonsai-layer00-down-block0.fiber](instances/bonsai-layer00-down-block0.fiber). Its header and the shared probe are counted, not supplied by an unpriced external dictionary.

## Layout makes the readable prefix useful

A row-major 220-bit record would scatter short prefixes across almost the entire weight image. Reading fewer semantic bits would not imply reading fewer memory lines.

The wire format instead stores all rows' leading 16 payload bits together, then the next 16-bit plane, and so on. The last plane has 12 bits per row. FP16 scales occupy their own contiguous plane. No row-offset array is needed.

For the real block, 5,104 rows resolve their response in the first payload plane; 16 need the second. Maximum used prefix length is 22 bits. Including all FP16 scales, the matching query touches **20,512 row-data bytes** rather than the source's 143,360 bytes. At a modeled 64-byte line granularity it touches **337 lines**, or 21,568 bytes, before codebook and guard traffic.

Those are address-footprint counts, not measured GPU bandwidth or a TPS result. The guard reads the 128-byte input block and shared 128-byte reference. Prefix decoding requires comparisons and index accesses. The runtime report counts them separately where available.

## Warm and cold costs

[FastImage](fiber_fast.py) builds a **336-byte** canonical prefix index, keeps the encoded image, and drops the suffix-count workspace. Image plus packed index is **141,284 bytes**, still 2,076 bytes below HALO. Python object overhead is additional. It does not retain decoded original weights. A matching query uses only the prefix index and leading payload planes, with 16,387 index comparisons across this block.

On a miss it builds the exact suffix-count table and reconstructs weights from this same image. That cold path supports **every** bounded integer query, not only captured activations. It is expensive in this prototype and is not presented as an inference speedup.

For this probe the suffix DP has 452,363 cells. Its integer bit payload is about 5.74 MB; the Python list/int allocation estimate is about **21.3 MB**, plus slot dictionaries and interpreter overhead. This is transient construction or miss-path workspace, not serialized model information. It is still a real operational cost. The warm object does not keep it.

All eight captured queries and sign/zero controls agree exactly with the source integer matvec. Only the chosen capture takes the prefix shortcut among the eight distinct captures. The other seven reconstruct correctly. No workload hit-rate claim follows from choosing a reference out of these eight rows.

### A miss need not reconstruct every weight

For any integer `alpha`, the exact identity is

```
dot(w,x) = alpha * dot(w,q) + dot(w,x-alpha*q).
```

`FiberRank.response_queryResidual` proves it for arbitrary equal-length lists. Once the residual query suffix is zero, unranking may stop. The executable chooses among `alpha = 0, 1, -1` by the required prefix length, then sparsity.

Changing only the first coordinate of the reference needs **one decoded trit per row**, 5,120 rather than 655,360 trits. It retains only suffix-count depths zero and one, 13,354 cells with a 732,952-byte Python list/int estimate. The slot objects add about 0.99 MB and dictionaries add further overhead. The constructor still computes the suffix recurrence, discarding deeper tables as it proceeds. Dense misses retain all depths. Both routes read complete row codes; selective unranking reduces reconstruction work, not the stored payload or necessarily its memory traffic.

The recorded Python run took about 0.085 seconds to build the full count book, 0.38 seconds to encode, 0.74 seconds to reconstruct every row, and 0.19 seconds for this one-coordinate query including temporary book construction. These are prototype wall times, not GPU comparisons. [fiber-results.json](fiber-results.json) records each query and its workspace.

The performance obstacle is now visible: a rare prefix hit cannot justify an expensive reconstruction on nearly every token. A native cheap miss path, a better shared response family, or demonstrated repeated-query reuse is needed before this becomes an inference format rather than a storage/representation result.

## Reproduce

```
lake build Kelana.FiberCodec Kelana.FiberRank
python3 research/quantization-discovery/fiber_experiments.py
python3 research/quantization-discovery/check_fiber.py
```

[fiber_codec.py](fiber_codec.py) owns counts, rank/unrank, slots and the plane wire format. [fiber_fast.py](fiber_fast.py) owns the warm prefix index and exact miss route. [fiber_experiments.py](fiber_experiments.py) owns the run and [fiber-results.json](fiber-results.json); [check_fiber.py](check_fiber.py) replays custody and both routes. [fiber_fixture.py](fiber_fixture.py) rebuilds the source [fixture provenance](instances/bonsai-layer00-down-block0.json) using the existing HALO decoder.

The Python codec itself uses the standard library. NumPy loads the fixture and checks against the source matrix in the experiment. Tests enumerate small complete ternary families, including zero probes and nontrivial common divisors, reject padding ranks and malformed image lengths, and round-trip the full real block. Every command is bounded below a minute. No GPU, serving configuration, or inference binary changes in this round.

## What changed

The previous packet threw away distinctions that its guarded consumer did not need. This packet moves those distinctions behind the useful response instead of deleting them. That removes the need for a narrow upstream validity contract and an original-weight fallback, while retaining partial evaluation on a matching query.

The [direct-consumer follow-up](DIRECT.md) addresses total online cost with smaller independent ternary chunks and query-dependent lookup tables. It supports every input without whole-row ranking, and measures native preparation plus execution. Its scalar-index implementation is faster than scalar packed extraction but loses to dense CPU execution. The subsequent [sign-orbit SIMD implementation](SIMD.md) beats the dense CPU block control while explicitly paying a small storage increase relative to HALO.

The unconditional storage gain here is real but small. The prefix data footprint is much smaller on a hit, but a semantic shortcut is not automatically a fast hardware instruction.
