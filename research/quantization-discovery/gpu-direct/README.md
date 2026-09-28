# One-query register lookup on gfx1151

The packed sign-orbit CPU win in [SIMD.md](../SIMD.md) does not transfer to this single-query GPU lowering. The packed consumer takes 9.299 µs for the real 5,120 by 128 integer block; the packed two-bit control takes 3.505 µs and dense int8 takes 3.287 µs. These are paired GPU event intervals per launch on gfx1151, including any gaps between the repeated launches. No serving path changes.

## Different lowering

Earlier [LDS lookup](../../ffn/batched/lookup/README.md) materialized query response tables in shared memory and read them with divergent row indices; [register observer](../../ffn/batched/register-observer/README.md) used `V_PERM_B32` for two-trit groups of bounded A4 inputs. Neither is this program. A wave holds 32 output rows. For each three-trit chunk, lane `i` constructs the response of sign representative `i mod 16` for the current signed-int8 query. The stored five-bit key supplies the representative and orientation. One `__shfl` selects another lane's response directly from registers, and an integer negation applies the sign. There is no LDS table, intermediate trit tensor, second launch, or precomputed input-dependent table. The final two-trit chunk uses four bits. The wave repeats this operation for 43 chunks. The serialized codes form chunk planes, packed across rows; the key load reads at most two bytes and uses shifts and masks. The byte-key arm removes that extraction while keeping the same wave table and lookup.

The signed response of a three-trit chunk is at most 384 in magnitude for any signed-int8 query. Every prefix of the 128-coordinate integer sum has magnitude at most 16,384, so signed32 accumulation is safe. `code` and `26-code` have opposite responses, including the self-reflecting zero at code 13. The tail uses `8-code`. [SignOrbitConsumer.lean](../../../Kelana/SignOrbitConsumer.lean) and [SimdTernaryConsumer.lean](../../../Kelana/SimdTernaryConsumer.lean) cover the integer sign and range facts; the HIP shuffle and serialized byte parser are checked by the native program, not by those proofs. All 655,360 real ternary weights round-trip through the new image. Each GPU method matched an independent host dot product on all 5,120 rows for all eight captured queries plus zero, all +127, all -128, and alternating -128/+127: 48 complete outputs.

## Matched integer-block panel

All methods take the same 128-byte device-resident signed-int8 query and write 5,120 signed32 integer sums (20,480 bytes). The host does not apply FP16 scales during the kernel timer. The controls are native HIP kernels at this exact boundary: dense signed bytes compile to `v_dot4_i32_iu8`; the two-bit row-major ternary control extracts four codes per byte. Both use one thread per row and the same launch dimensions as the candidate. The byte-key arm prices expansion of the *stored* image, not an invisible runtime copy. `results.json` has 108 samples per method, 32 launches per sample, with arm order rotated by query and round. The table reports medians of the 12 query medians over nine rounds.

| Stored weight image | Bytes, weights | Bytes, including unchanged scales | Device µs / launch | Speed / two-bit |
| --- | ---: | ---: | ---: | ---: |
| Packed sign orbit, wave lookup | 136,960 | 147,200 | 9.299 | 0.377x |
| Byte-key sign orbit, wave lookup | 220,160 | 230,400 | 8.025 | 0.437x |
| Packed two-bit ternary | 163,840 | 174,080 | 3.505 | 1.000x |
| Dense signed int8 | 655,360 | 665,600 | 3.287 | 1.066x |

The original HALO block occupies 143,360 bytes including its identical 10,240 bytes of scales. The packed sign orbit adds 3,840 bytes, or 2.68%. No method allocates a query table or LDS scratch. The input is 128 bytes and the output is 20,480 bytes for every arm. The host-side packer and GPU allocations used to benchmark all four formats are outside these per-format counts. The kernel reports 17 registers per thread, zero static shared bytes and 16 theoretical resident 128-thread blocks per multiprocessor. The grid has just 40 blocks over 20 multiprocessors, so it exposes about two blocks, eight waves, per multiprocessor before scheduling imbalance. Resource metadata refers to the one compiled kernel with a runtime mode branch, not separate specialized resource reports.

A second unpinned run gave 10.295 / 8.874 / 3.894 / 3.612 µs in the table's order. [The selected run's telemetry](clock.json) sampled 2,362 MHz median shader clock, 81 W socket and 2.9 busy host cores; the unpinned run sampled 706 MHz, 120 W and 16 busy cores. Pinning the DPM performance level did not fix the clock at its maximum under these short kernels. The paired ratios in the selected run remain between 0.372 and 0.383 for packed sign orbit versus two-bit across the nine rounds. Do not use either absolute timing as a clock-independent roof.

The packed version is 2.65 times slower than the two-bit control despite storing fewer bytes and avoiding an expanded trit array. The byte-key arm saves only 1.274 µs, still 2.29 times slower than the two-bit control. The loop constructs a response, reads an indexed cross-lane register and accumulates it for each of 43 chunks. The byte-key arm shows that removing packed-address extraction alone does not recover competitiveness. This is no universal instruction lower bound. A next candidate should change that recurring work, for example by letting several outputs or tokens share a consumer, rather than merely changing the stored bit count. The batched A4 direct-operand work in [dense-consumer](../../ffn/batched/dense-consumer/README.md) shows such a map can be useful for a *different numerical boundary*. Arbitrary A8 integer sums, original block scales and original FP accumulation must still be priced before a serving change.

## Fixture and reproduction

The [pinned NPZ](../instances/bonsai-layer00-down-block0.npz), SHA-256 `70c7180bd822f2a05e2a76e74df657f575caead2da7d526728fbc92831c4bdee`, came from the real PTQ1_0 layer-0 down-projection block 0. Its [manifest](../instances/bonsai-layer00-down-block0.json) gives the model, source dataset hashes, extraction revision, scale bits and capture source. `fixture.py` exports exactly those trits and queries and appends four full-range controls. The program packs both compact images offline, checks every decoded weight and checks every row of every result. Image preparation is not part of online timing. The online wave table is built inside each timed launch.

From this directory, use bounded foreground commands:

```sh
mkdir -p build
python3 fixture.py export build
hipcc --offload-arch=gfx1151 -O3 -std=c++17 probe.hip -o build/probe
/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 38s --pin-clock \
  --clock-log "$PWD/build/clock.json" --exec "$PWD/build/probe" \
  "$PWD/build/weights.i8" "$PWD/build/queries.i8" "$PWD/build/raw.json"
python3 fixture.py record build/raw.json
```

The wrapper owns GPU admission, a bounded process scope, and resident-service restoration. `build/` is disposable. The output file records every event measurement, resource count, source hash and fixture hash. The initial panel did not retain a binary hash; `fixture.py record` now records the hash of the measured `build/probe` executable too. Each event interval spans 32 ordinary host-submitted launches, not a graph replay, so its average includes any inter-launch gaps. The same submission loop measures every arm. The interval excludes file I/O, offline packing, GPU allocations, host-to-device query transfer and device-to-host output transfer. It includes response construction, packed-key extraction, lookup, sum, and output store. Those excluded shared boundary costs must be added for an end-to-end inference comparison. The integer result is not a proof of equivalence for applying per-block scales or changing FP accumulation order.
