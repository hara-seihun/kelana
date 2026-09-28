# A SIMD consumer for sign-folded ternary codes

This implements the [sign-orbit representation](DIRECT.md#fold-a-consumer-symmetry-into-the-lookup-address) on the host's AVX-512 instructions. The input is an arbitrary signed-int8 query, not a reference pattern. Original weight trits are neither materialized nor extracted during evaluation.

## Stored representation

Each three-trit chunk has 27 ordinary base-three codes. Pair `c` with `26-c`, store the smaller representative and a sign. Four representative bits and one sign bit give a five-bit code. A final two-trit chunk needs four bits; a one-trit tail needs two.

The image stores chunk planes rather than row-major records. Each plane contains 32-row tiles. A full tile occupies 20 bytes for three-trit chunks. The evaluator works on four tiles together, so the row count is padded to a multiple of 128. The real 5,120-row fixture needs no row padding.

| Format for 5,120 x 128 | Weight bytes | With unchanged FP16 scales |
|---|---:|---:|
| HALO-density base-three chunks | 133,120 | 143,360 |
| Five-bit sign-orbit SIMD image | 136,960 | 147,200 |
| Byte-addressed sign-orbit image | 220,160 | 230,400 |
| Dense int8 control | 655,360 | 665,600 |

The packed SIMD image costs **3,840 additional bytes**, 2.68% above the original block including scales. The byte-index arm explicitly spends more storage to measure the price of unpacking. Neither arm hides an expanded runtime copy behind a smaller serialized-byte claim. Shape and chunk recipes are shared format parameters, as in the previous native block panel; these figures do not include a standalone container header.

## Instructions perform the representation change

For each 32-row tile:

1. A masked load reads its 20 packed bytes.
2. `VPERMB` places each group of eight five-bit codes into a separate 64-bit lane.
3. `VPMULTISHIFTQB` selects the bits for the eight codes in each lane. A mask retains their five meaningful bits.
4. Byte indices widen to 16-bit indices.
5. `VPERMW` reads 32 signed responses from a register table.
6. Signed16 adds accumulate those responses across chunks.

Four independent 32-row accumulators share each table load. The final signed16 results widen to the same int64 output protocol as the controls. There is no per-trit division, multiply or decode in this evaluation loop.

For each query chunk, preparation multiplies broadcast input coordinates by compile-time ternary coefficient vectors and adds the results. This builds all register-table responses with SIMD too, including both signs. The mathematical 14-entry table becomes a 32-entry signed16 register image, including unused slots. The sign bit is therefore part of the lookup address; evaluation needs no separate sign instruction. All 43 chunk tables occupy **2,752 transient data bytes**. C++ vector objects, format descriptors and allocation overhead are additional.

The byte-index arm skips the packed load/permute/multishift sequence. It runs the same table and signed accumulation path from one byte per chunk index.

## Exactness and range

[SignOrbitConsumer.lean](../../Kelana/SignOrbitConsumer.lean) proves code reflection and sign-folded lookup. [SIMD-PROOFS.md](SIMD-PROOFS.md) states the signed response and accumulator contracts from [SimdTernaryConsumer.lean](../../Kelana/SimdTernaryConsumer.lean). A 128-column ternary dot product with full signed-int8 inputs has magnitude at most 16,384. This also bounds partial sums by their consumed coordinate count, so intermediate signed16 accumulation is safe. The executable supports up to 255 columns, whose worst magnitude is 32,640, and rejects wider SIMD blocks.

The intrinsic unpacker is checked on zero and every input-bit basis vector for all three physical widths, 355 input images total. Both wire formats independently reconstruct all **655,360 original trits**. The complete model fixture also checks every output row against NumPy for eight captures and four controls. Additional panels cover partial tiles, one/two/three-trit tails, non-multiple row counts, the -128 input extreme, and the 255-column accumulator boundary. These executable checks do not constitute a Lean proof of the compiler or SIMD intrinsic semantics.

## Measurement contract

The owning native program remains [direct_consumer.cpp](direct_consumer.cpp), with the SIMD implementation in [simd_consumer.hpp](simd_consumer.hpp). [direct_experiments.py](direct_experiments.py) builds and runs all controls and emits [direct-results.json](direct-results.json).

The runner pins itself and the child benchmark to one allowed CPU. By default it samples CPU use for 100 ms and chooses the least-busy SMT sibling group. `KELANA_BENCH_CPU=N` selects an explicit allowed CPU. This avoids known-busy siblings, not all interference from other host jobs.

The acceptance comparison rotates dense, packed SIMD and byte-index SIMD order on each repetition and query. Every SIMD sample includes a fresh table allocation, preparation, evaluation and destruction. Standalone warm-table timings remain in the record but are not substituted for this end-to-end block comparison. "Fresh" describes the table, not a flushed hardware cache.

[The compiler audit](SIMD-CODEGEN.md) confirms that the dense control uses AVX-512 VNNI rather than a scalar loop. The program now keeps `dense_evaluate` out of line so additions to the benchmark do not change its inlining context. Temporary isolated builds of the previous and SIMD sources produced instruction-identical dense functions.

The CPU block does not include FP16 scale application, the surrounding FFN, attention, speculative decoding or serving. It does not measure the GPU kernel that Bonsai ships. Any speed ratio here belongs only to this native integer block and its stated CPU controls.

## Recorded result

The final panel used CPU 15 on the Ryzen AI MAX+ 395, GCC 15.3 with `-O3 -march=native`, and 17 repetitions per input. These are medians of the 12 per-query medians from the rotating paired arm:

| Consumer | Fresh-query time | Speed relative to dense |
|---|---:|---:|
| AVX-512 VNNI dense int8 | 13.464 µs | 1.00x |
| Packed sign-orbit SIMD | **7.835 µs** | **1.72x** |
| Byte-index sign-orbit SIMD | **3.730 µs** | **3.61x** |

Packed SIMD wins while adding 2.68% to HALO block storage. The byte-index variant buys more speed with 60.71% more storage than HALO. It is an explicit point on the storage/speed tradeoff, not a free acceleration of the smaller image.

Standalone SIMD table preparation takes about 0.12 µs. Its hot evaluation takes about 6.49 µs for packed indices and 2.99 µs for byte indices. The paired totals above remain the acceptance numbers because they include fresh table preparation and alternate against the dense control under the same host load. They are not derived from subtracting separately timed stages.

All twelve native methods agree on every row of all twelve inputs. Six additional shape/range panels pass, including 255 columns and a query of all `-128`. Both weight-image roundtrips and all 355 unpack basis checks pass. The generic Lean range and sign contracts compile. No serving binary or GPU kernel changed.

## Reproduce

```
lake build Kelana.SimdTernaryConsumer
python3 research/quantization-discovery/direct_experiments.py
```

The host must support AVX512VBMI, AVX512BW and AVX512VL. The build uses `-march=native`. Each command is bounded below a minute; the runner removes temporary binaries and raw fixture files after completion.
