# One byte of state through eight ternary residual maps

A small exact CPU construction tests whether a packed state can stay packed across several nonlinear operations. It can. On this machine, a byte label for three trits passes through eight AVX-512 VBMI `VPERMB` lookups without reconstructing a gate, suppressor, or trit between steps. But this particular state space is so small that the stronger control is to compose all eight maps *before* inference and use just one lookup. Conditional routing does not rescue the staged construction when all 256 routes fit in 16 KiB.

## Contract and construction

The state is `x ∈ {-1,0,1}³`, encoded once as `q=(x0+1)+3(x1+1)+9(x2+1)`, an integer from 0 to 26. For each of eight stages, two fixed ternary 3×3 matrices define

```
x'_i = clip[-1,1](x_i + relu(G_i · x) - relu(U_i · x)).
```

The residual, two competing responses, nonlinearities and quantizer are part of the complete observed map. `experiment.cpp` stores the matrices and constructs the exact 27-entry map of each stage, with zero padding to a 64-byte register. For 64 independent streams sharing the same stage, `VPERMB(table, q)` produces the *same* byte label for the next stage. No internal decoder runs. Each stage costs one 512-bit permute and a prepared 64-byte table; the output remains in the original coordinate system. The random seed was chosen only to avoid immediate collapse: after stages 1 through 8, respectively, the 27 possible initial states still give 14, 10, 9, 9, 9, 8, 8, 7 distinct states. These are exact integer maps, not fitted Qwen weights.

The fully fused control composes all eight transitions offline, using a **64-byte** table and one permute online. A routed version decides independently whether to execute each stage, using one eight-bit route mask per group of 64 streams. There are 256 masks. The routed staged program has up to eight lookups and 512 bytes of stage tables. The routed fused program pays **16,384 bytes** for 256 prepared tables but still uses one online permute. Preparing them by the direct recipe makes 256×27×8/2 = **27,648** stage-map evaluations, plus 256×27 output writes; staged preparation needs 8×27 = **216** stage-map evaluations. These costs and tables are outside the timed online loop. This is a finite-route trade, not a free whole-map oracle.

Three other boundaries matter. The test begins with one byte label per stream, not three trits in separate registers. The direct SIMD control decodes that input with three register permutes and encodes its final three trits back to the same byte contract; it *does not* decode or encode at each internal stage. It compiles the fixed ternary matrices to byte-vector add/sub, max and min, so it is a serious resident-input arithmetic control, not a scalar loop. The eight matrices occupy 144 bytes as literal int8 coefficients in the source; an ideal packed trit copy would take ceil(144×log₂3/8) = 29 bytes, before decoding that format. The label-table image is 512 bytes for the staged route, 64 bytes for fixed fusion, or 16 KiB for all conditional routes. Input/output bytes, any upstream state encoder, table preparation and independent per-lane routes are not made free by these timings.

## Result

GCC 15.3.0, `-O3 -std=c++20 -march=native`, Ryzen AI MAX+ 395 with AVX512VBMI. Each trial runs 4,096 groups of 64 differently labeled states. The five recorded trials are in [results.json](results.json); numbers below are median nanoseconds per group. These are warmed, single-thread, register-table microbenchmarks, not model inference speed.

| Contract | Compiled ternary SIMD | Byte labels, staged | Byte labels, fused |
| --- | ---: | ---: | ---: |
| Fixed eight stages | 27.03 | 1.707 | **1.707** |
| Eight conditional execute/skip stages | 14.326 | 3.796 | **1.711** |

The fixed program's staged/fused times are indistinguishable at the measurement floor, though disassembly of `run_staged` contains eight `vpermb` instructions and `run_fused` contains one. In the conditional experiment, fusion wins by 2.22× over staged lookup at a 32× table-byte cost. Staged lookup is 3.77× faster than the direct SIMD control, under this narrow shared-route contract. Timing is not an instruction-throughput proof; fixed batches are small enough for loop overhead and cache residency to dominate.

The scalar table builder and a separately compiled AVX-512 direct implementation agree on all 27 fixed inputs and all 256×27 routed cases for all three methods. There is no lossy relabeling in this example: the carrier is a bijection on the 27 input states. The structural identity is exact at every reachable state, the table-building budget is explicit, and the online comparison includes the input/output conversion only for the direct baseline. The `VPERMB` tables hold the output *in the encoding of the next stage*, not an ordinary integer observation that must be decoded between stages.

## Why this is not the previous lookup result

[Whole-map search](../../discovery/whole-map-search/README.md) already showed one gfx1151 gather for a three-input **scalar output** and shared address reuse for many independent consumers. [Finite speculative maps](../../speculative-maps/finite/README.md) already showed that byte-labeled CPU function composition can be native, while [learned transition maps](../../speculative-maps/native-learned/README.md) showed that constructing all successors can erase that gain. This experiment instead measures a *quantized residual recurrence* in which the output label is the next input, includes a compiled ternary arithmetic control under an identical byte-to-byte contract, and puts a full route-table fusion control against repeated lookups. No novelty is claimed for `VPERMB` or the algebra of composition.

The bounded lesson is blunt. For 27 states and eight shared conditional bits, complete fusion fits in L1-sized storage and defeats a multistage interpretation. The next discriminating experiment should increase a *real* quantized residual region's reachable state and route diversity until composed tables exceed cache, then compare streamed packed continuation with arithmetic under matched quality and a paid state encoder. A large model's activation state is vastly larger than 27, and its gates are continuous before quantization. This toy neither compresses Qwen weights nor predicts its NLL or throughput. A cheap exact small-region ISA map is only worth carrying forward when the larger reachable map and producer can be paid for.

## Reproduce

```sh
cd research/ternary-toys/packed-realization
c++ -O3 -std=c++20 -march=native experiment.cpp -o /tmp/packed-realization-experiment
/tmp/packed-realization-experiment 5
```

The program refuses to time mismatched endpoints. It requires AVX512VBMI and emits compact JSON; trial order is fixed, so small timing gaps should not be interpreted as performance wins.
