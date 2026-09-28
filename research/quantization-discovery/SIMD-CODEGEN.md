# SIMD benchmark code generation audit

This audit checks whether adding the SIMD consumer changed compiler generation for the existing dense-int8 and scalar packed controls. It compares commit `22af672eae2da8a7dcb21c2df0bfd2e0a5aca221` with the paired SIMD working tree whose `direct_consumer.cpp` SHA-256 was `1638d449a73a4ca48be1e8fb00cd3c8b68b1615b841001e363eb6e50e0a18895` and whose `simd_consumer.hpp` SHA-256 was `3aa6b4557369d49082dc200f8bba87e2b055b6c769d1e8f8efca3735387142d3`.

The compiler was `g++ (GCC) 15.3.0`. Compilation used the runner's flags:

```text
-O3 -march=native -DNDEBUG -std=c++20 -Wall -Wextra -Wpedantic
```

The host CPU was an AMD Ryzen AI MAX+ 395 with AVX-512 VNNI, BW, VL and VBMI available through `-march=native`.

## Dense int8 control

GCC fully inlined `dense_evaluate` and `benchmark_dense` into `run` in both sources. Neither optimized binary retained a dense or dense-benchmark symbol. The added paired benchmark creates a third inlined dense copy. Its vectorization report matches the first two copies.

GCC reported the signed-int32 loop vectorized at 64, 32, 16 and 8-byte widths in both sources. It reported the signed-int64 fallback vectorized at 64, 32 and 16-byte widths.

For the fixture's 128-column signed-int32 route, the old and current 64-byte hot loops use the same operations:

```text
2 x vmovdqu8
4 x vpmovsxbw
2 x vpdpwssd
1 x vpaddd
```

The loop then horizontally reduces the int32 lanes. Each iteration reads 64 weight bytes and 64 query bytes. `vpmovsxbw` sign-extends the int8 values, and signed `vpdpwssd` performs the pairwise int16 products with int32 accumulation. The dense control is therefore genuinely vectorized rather than a scalar loop surrounded by vector setup.

Inlining changed register allocation around the loop. The inspected current copy has one additional `vmovq` per output row and different saved-register handling. The vector loads, extensions, dot products and reduction are unchanged. This does not account for a shift from roughly 9.6 microseconds to 36.4 microseconds.

The complete optimized `run` grew from `0x2824` bytes at `22af672` to `0x5175` bytes after the paired SIMD methods were added. The dense kernel should not depend on register allocation inside that growing function. Adding `[[gnu::noinline]]` to `dense_evaluate` isolates it with one call per timed block evaluation:

```cpp
[[gnu::noinline]] void dense_evaluate(
    const std::vector<std::int8_t>& weights,
    const std::int8_t* query,
    const Dimensions& dimensions,
    std::vector<std::int64_t>& output);
```

Temporary builds with that attribute produced a `0x93e`-byte dense function for both sources. After normalizing instruction and branch addresses, their complete 534-instruction disassemblies matched exactly. The isolated function retained the same vectorization report. This makes the dense control stable against later additions to the benchmark translation unit.

## Scalar packed controls

`benchmark_scalar` remains out of line in both binaries and has the same `0x62f`-byte size. Its inlined `packed_scalar_evaluate` loop is instruction-identical between the two builds. Normalized disassembly differs only at the equivalent templated `method_suffix` call target and a string address outside the measured evaluation loop.

The observed approximately 1.5-fold scalar timing shift did not come from compiler code generation. Paired ordering and CPU-affinity controls should determine whether host load, sibling activity or benchmark order caused it.
