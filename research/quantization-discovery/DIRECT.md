# Exact direct consumption for arbitrary inputs

The [fiber codec](FIBER.md) makes one chosen query cheap but needs expensive rank reconstruction for most other queries. This round changes the partition. Short ternary chunks become direct indices into a table prepared from the current input. Every bounded integer input uses the same algorithm. There is no reference-query guard and no retained decoded weight matrix in the packed consumer.

This is established lookup-based matrix multiplication, applied here as a measured alternative to whole-row fiber ranking. [T-MAC](https://github.com/microsoft/T-MAC) already computes mixed-precision matrix products using lookup tables without weight dequantization, including BitNet support. Kelana's contribution in this round is its exact ternary formulation, proof, storage/work selection and comparison on the same real block. It is not an invention claim for table-based inference.

## What the code means

For a length-`k` ternary weight chunk, its base-three code is a number in `0 .. 3^k-1`. For the current input chunk `x`, prepare

```
T_x[code(w)] = dot(w,x).
```

A row then performs one lookup and accumulation per chunk. The weight's individual trits need not be reconstructed online. The same code serves every query; only the transient response table changes.

Build the table recursively. Given the suffix response table, the three first-trit branches are its entries shifted by `-x_0`, unchanged, and shifted by `+x_0`. Each table entry has a source meaning, rather than being a learned approximation. [DIRECT-PROOFS.md](DIRECT-PROOFS.md) describes the arbitrary-length exact lookup and composition results in [DirectConsumer.lean](../../Kelana/DirectConsumer.lean). Native byte parsing and compiler behavior are separate implementation obligations.

The output here is the exact integer block accumulator. Original FP16 scale bits remain unchanged. To integrate into Bonsai, these integers must rejoin the original scale and floating-point accumulation order. The experiment does not replace that surrounding computation.

## Choose a chunk size by total work

Larger chunks reduce row lookups but increase table preparation exponentially. For `k` trits, the recursive construction uses `3^k-1` add/sub operations if the unchanged branch is copied. Copies and writes still cost time; this count is only an arithmetic proxy.

For `R` row evaluations sharing the prepared table, a uniform chunk's proxy per coordinate is

```
f(k) = (R + 3^k - 1) / k.
```

Cross-multiplication gives the exact neighboring-width comparison

```
f(k+1) <= f(k)  iff  (2*k-1)*3^k <= R-1.
```

The right-hand threshold grows with `k`. The best uniform size is at the first crossing, with a tie when equality holds. This derives a size rule for arbitrary `R`, rather than tuning an unexplained constant. For `R=5120`, the crossing lies between the improvements to widths six and seven, so six minimizes this unconstrained uniform proxy. Physical bit packing, vector instructions and cache behavior can choose differently.

[direct_plan.py](direct_plan.py) handles finite tails and a storage budget by exact dynamic programming. Its state is consumed coordinates and consumed payload bits. A length-`k` edge adds `ceil(log2(3^k))` bits and `3^k-1 + R` proxy work. All edges advance coordinates, so retaining the cheapest path to each state preserves every legal future. The model allows contiguous independent chunks of lengths one through ten. It does not optimize arbitrary executable representations.

For 128 coordinates and 5,120 output rows:

| Weight-bit budget per row | Optimal chunk multiset in this family | Lookup accumulations | Table arithmetic |
|---:|---|---:|---:|
| 204 | No feasible partition | | |
| 205 | 25 of length 5, one of length 3 | 133,120 | 6,076 |
| 206 | 22 of length 5, three of length 6 | 128,000 | 7,508 |
| 208 | 16 of length 5, eight of length 6 | 122,880 | 9,696 |
| 210 | Ten of length 5, 13 of length 6 | 117,760 | 11,884 |
| 214 | 19 of length 6, two of length 7 | 107,520 | 18,204 |

HALO uses 208 weight bits per row for this block, before its unchanged 16-bit scale. Whole-row fiber coding reaches 204, but pays much more to evaluate ordinary inputs. The 204-bit failure in the table is only for this short independent-chunk family.

Query reuse changes the selected representation even at the same 208-bit budget. Eight reuses select 16 chunks of length eight; 64 reuses select eleven of length ten and two of length nine under this proxy. Reuse means the exact same input table is reused. It does not mean arbitrary batched input tokens share a table.

[direct-plan-results.json](direct-plan-results.json) records the complete selected partitions, work, retained and streamed table sizes. The Python planner is checked against exhaustive short partitions. It is not a Lean-verified implementation.

## Fold a consumer symmetry into the lookup address

For base-three code `c` among `N=3^k` rows, negating every trit changes the code to `N-1-c` and negates every linear response. Therefore a response table needs only the representative

```
representative = min(c, N-1-c)
```

plus a sign at the consumer. [SignOrbitConsumer.lean](../../Kelana/SignOrbitConsumer.lean) proves code reflection, response antisymmetry, the representative bound, and exact lookup through an arbitrary antisymmetric table. The result holds for every chunk length and every integer query.

At three trits, 27 rows become **14 sign representatives**. Their indices fit a 16-entry byte-shuffle instruction's address space. A response can reach magnitude 384 for full signed-int8 inputs, so it needs two byte tables or a wider element lookup; a single eight-bit response table would be wrong. Five bits still suffice for representative plus sign, the same capacity as a direct three-trit code. Applying three-trit chunks across 128 coordinates needs 214 weight bits rather than HALO's 208, so instruction fit comes with a storage cost.

The [SIMD follow-up](SIMD.md) implements packed-plane extraction and register lookup. It measures the storage penalty and beats the dense CPU control in paired block timing. [Minimum sign-orbit table preparation](sign-orbit-prep/README.md) proves that a complete three-trit half-table needs exactly 13 scalar add/sub results given the original query coordinates, versus 26 in the full-table recurrence; its checked construction identifies a native preparation experiment but does not price SIMD or GPU latency. [Two-query fusion](paired-consumer/README.md) shares packed-key extraction across two independent response tables: the packed fresh-table pair falls from 11.460 to 6.889 µs on the CPU block. That is a query-batch cost result, not a GPU or model result. Sign symmetry and lookup tables are established techniques; the Lean statement makes the consumer equivalence and its boundary explicit.

## Native experiment

[direct_consumer.cpp](direct_consumer.cpp) owns the C++ CPU consumers. [DIRECT-NATIVE.md](DIRECT-NATIVE.md) records their wire layout and timing contract. [direct_experiments.py](direct_experiments.py) compiles a temporary binary, exports the committed fixture, and checks every native output against an independent NumPy integer matvec. The inputs are all eight captures plus zero, positive extreme, negative extreme and alternating extreme controls.

The panel separates table preparation, evaluation with a newly prepared table, their combined cost, and evaluation reusing a prepared table. Dense int8 and packed scalar extraction are controls. Reported timing is for one CPU thread and one 128-wide integer block across all 5,120 output rows. It is not full-model inference, GPU timing, or a replacement for the shipped tensor kernel.

## Measured outcome

The [recorded panel](direct-results.json) ran on the Ryzen AI MAX+ 395, one CPU thread, with 17 repetitions per input. Values below are medians of the 12 per-query medians. All twelve current methods matched all 12 independent NumPy output checksums. There are 5,120 **output rows**, not 5,120 generation streams.

| Consumer | Weight payload bytes | Prepare table, µs | Evaluate with reused table, µs | Fresh table plus evaluation, µs |
|---|---:|---:|---:|---:|
| Dense int8 control | 655,360 | None | 12.89 | 12.89 |
| Direct five-trit lookup | 131,200 | 5.07 | 145.28 | 148.96 |
| Direct eight-trit lookup | 133,120 | 86.70 | 99.97 | 186.27 |
| Direct mixed five/six lookup | 133,120 | 8.35 | 115.20 | **124.44** |

The same mixed packed layout evaluated by scalar base-three extraction takes **785.36 µs**. Direct lookup with fresh preparation is **6.31 times faster than that scalar packed control**, but still much slower than dense. These are the scalar-index lookup controls. The [SIMD implementation](SIMD.md) adds packed sign-orbit lookup at **7.835 µs** versus **13.464 µs** for dense in the rotating paired arm, a **1.72x** improvement with a 2.68% block-storage penalty relative to HALO. The paired values, not the separately scheduled dense timing in this table, govern that comparison.

Five-trit storage plus unchanged scales is **141,440 bytes**, 1.34% below the original block. Mixed and eight-trit storage plus scales exactly equal the original **143,360 bytes**. These are block payload counts under the shared model shape and fixed format recipe, without a standalone container header. Query tables add 12,204, 19,440 or 209,952 transient data bytes for five-trit, mixed or eight-trit layouts. C++ container objects, chunk descriptors and allocator overhead are additional.

The measured selection agrees with the proxy on the tested alternatives: mixed chunks win when each input needs a fresh table; eight-trit chunks win when the exact table is reused. This agreement does not certify hardware optimality. The C++ table builder uses a base-three carry counter, while the proved cost recurrence counts shifted copies; their semantic tables agree up to digit order, but their machine instruction counts differ.

The Lean table code places the first trit in the most-significant base-three digit. Native packing and the sign-orbit code place it in the least-significant digit. Reversing both the weight chunk and query chunk relates these conventions. The mathematical dot product is unchanged; no claim of a formally verified C++ implementation is made.

Here, "cold" means a newly allocated and constructed response table. It does not mean flushing hardware caches. Repeated weights and inputs are cache-resident, standalone methods run in a fixed order, and the timings exclude FP16 scale application. The added SIMD acceptance arm rotates method order for its paired comparison. No whole-model or GPU comparison follows from them.

The [SIMD follow-up](SIMD.md) implements the instruction-sized sign-orbit candidate and supplies row indices without scalar bit extraction. This separates the loss of the scalar-index implementation from the value of exact table consumption. The resulting CPU win is for this integer block; full-model and GPU integration remain separate work.

## Reproduce

```
lake build Kelana.DirectConsumer
python3 research/quantization-discovery/direct_plan.py
python3 research/quantization-discovery/direct_experiments.py
```

Each command is bounded below a minute. The native runner uses the system C++ compiler and NumPy for fixture loading and independent output checks. It deletes its temporary binary and raw inputs. The committed NPZ, source and result hashes are enough to replay the experiment; no model download or GPU access is needed.
