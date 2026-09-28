# Finite speculative transition maps

An independent uniform draw at each position turns a conditional distribution into a deterministic successor function on every possible predecessor. For a row with integer masses summing to grid size `G`, set `f_t(s)=inverse_cdf(P_t(·|s), U_t)`, where `U_t` is uniform on `{0,...,G-1}`. The **same** `U_t` is used for all hypothetical predecessors at position `t`; `U_t` and `U_{t+1}` are independent. Along the realized path, conditioning on its current state leaves the fresh `U_t` uniform, so its transition law is exactly the specified row. Counterfactual successors are correlated, which is harmless for a single realized path but matters if a joint branching interpretation needs independent samples at the same position.

A function on 16 states fits in one 64-bit word, with successor `f(s)` in nibble `s`. Composition is `g[f(s)]` directly on these labels. The serial scan has `n` compositions and span `n`; balanced upsweep/downsweep plus leaf observations uses fewer than `3n` compositions and span below `2 ceil(log2(n))+2` in the ideal parallel map-operation model. Both produce **every** prefix function, not only the final state. For the last state alone, balanced reduction needs `n-1` compositions. A pair of such words also carries two sampling streams as a joint 128-bit state; its composition stays componentwise without recovering token paths between stages. This is a joint representation, not a claim of compression or a faster native implementation.

[experiment.py](experiment.py) independently enumerates conditional state paths and all `4^5 = 1024` uniform streams on a three-state, five-step time-varying model. The path laws agree as exact rational numbers for all 102 distinct reachable paths. Every packed serial and balanced prefix is checked against direct inverse-CDF sampling. Another 200 seeded cases check up to 16 states and 33 steps, plus paired packed streams. See [results.json](results.json).

## Branch budget

For a fixed set of verified prefix-tree nodes, let `p(v)` be the probability that the reference path visits node `v`. The expected number of accepted positions before the first missing node is `Σ_{v selected} p(v)`, assuming ancestor closure and one reference draw per position. A node costs one budget unit. Selecting the `K` highest-mass prefixes is optimal: child mass cannot exceed parent mass, so the top `K` can be ancestor-closed. The heap implementation resolves equal masses with the parent before descendants. A single-chain comparator searches the best chain for the **same** node budget by dynamic programming, not just a greedy highest-probability next token. The examples use two first-order states. Rejoining states do not merge tree nodes: different token prefixes still require separate verification slots.

At eight nodes, a balanced 1/2–1/2 branch has exact chain coverage `255/256` and tree coverage `9/4`. A sticky correlated chain with 9/10 probability of staying in its current state has equal optimal coverage `512579511/100000000` for both choices: eight deep nodes on the dominant path beat spending a slot on the rare branch. For an asymmetric two-state branch the tree yields `11893/4096` against the best chain's `176925/65536`. These are expected accepted **positions**, not probability of any acceptance or tokens per second. All budgets and exact fractions are in [results.json](results.json). The toy does not model tree attention, target verification latency, proposal generation cost, or an actual language model.

## Byte labels change the CPU bill

[bench.cpp](bench.cpp) fixes 32 positions, 16 conditional rows, eight uniform values, and 128 seeded fixtures. A row selects the current state or the next cyclic state according to a state- and position-dependent integer threshold. Both representations consume identical rows and uniforms:

- Nibble labels use a 64-bit map and loop over 16 successor fields for composition.
- Byte labels use a 16-byte XMM register. `_mm_shuffle_epi8(right, left)` computes all 16 values of `right[left(s)]` at once with `VPSHUFB`. A byte comparison and blend construct all 16 conditional successors from the 16 threshold bytes and one broadcast uniform. `_mm_shuffle_epi8(map, broadcast(state))` reads the consumed state. The 16-byte map doubles storage against nibbles but is native to this CPU consumer.

Before timing, the program checks every generated map entry and every serial prefix map entry across all 128 cases and 16 states. It checks the composed endpoint and both prefix-scan results against the direct path. Each timed full-construction prefix run builds its maps inside the iteration; prepared runs explicitly exclude construction. Median nanoseconds per 32-step sequence from five samples of 20,000 iterations on an AMD Ryzen AI MAX+ 395, GCC 15.3.0 `-O3 -std=c++20 -march=native`, are in [bench-results.json](bench-results.json):

| CPU operation | 8-byte nibble | 16-byte shuffle |
| --- | ---: | ---: |
| Construct 32 full maps, digest all output bytes | 127.3 | 19.9 |
| Construct maps and consume visited state at each step | 128.8 | 40.9 |
| Construct maps and compose final map | 291.3 | 13.4 |
| Construct maps, serial prefix scan and consume | 297.7 | 14.7 |
| Construct maps, balanced prefix scan and consume | 537.9 | 48.3 |
| Prepared maps, compose endpoint | 210.8 | 8.2 |
| Prepared maps, serial prefix scan and consume | 215.7 | 10.8 |
| Prepared maps, balanced prefix scan and consume | 421.2 | 37.6 |

Directly sampling only the 32 visited rows took 31.5 ns. In this toy, byte labels plus a matching shuffle consumer make the **complete constructed serial prefix scan** faster than that direct path, despite the byte map's doubled size. The packed nibble map loses because each composition loops over 16 fields. The single-thread balanced scan remains slower than serial even with `VPSHUFB`; its parallel-depth advantage needs actual parallel execution to matter. Construction, composition, and consumption are not additive timing components: the compiler optimizes their combined code differently, and prepared arrays have different load costs. These are warmed single-thread CPU timings under one cache-resident threshold fixture, not a model of generating neural conditional distributions. The fixed toy threshold table makes all 16 rows cheap; an actual model must pay to produce those rows. No CPU-to-GPU or inference-speed extrapolation follows.

## Reproduce

From the Kelana repository root:

```sh
python3 research/speculative-maps/finite/experiment.py
c++ -O3 -std=c++20 -march=native research/speculative-maps/finite/bench.cpp -o /tmp/speculative-finite-bench
/tmp/speculative-finite-bench 20000
```

The recorded `bench-results.json` contains five runs and medians; rerun five times to compare machine conditions. Python uses only the standard library. This experiment follows [composition](../../composition/README.md), [the packed radix-64 toy](../../toy2/radix64/README.md), and [observer search](../../discovery/observer-search/PLAN.md): preserve a complete composable representation, then count its actual entry and exit costs. Unlike a single-state sampled chain, a complete function describes every counterfactual predecessor. The byte-label result demonstrates a consumer that exploits this structure on this CPU. Whether a model can produce those labels cheaply remains a separate question.
