# Exact response-optimal phase for a one-nibble value mass

A previous search fixed one of sixteen prefix-rounding phases per head on train text. On the frozen Qwen3-0.6B narrow-value code, no head crossed the 1e-4 complete post-O switch budget. This experiment instead picks a *query-specific* phase that minimizes that head's paid post-O output metric, exactly within the continuous-phase grammar. It asks whether a cheaper response-aware selector can recover some of the earlier expensive key-exchange fit.

## Finite search and proof

For a probability row `p` on `n` causal keys, let `C_i=15 sum_{j<=i} p_j`. Set `B_0=0`, `B_n=15`, and `B_i(u)=floor(C_i+u)` for interior boundaries and `0<=u<1`. The unsigned-nibble counts are `q_i=B_i-B_{i-1}`. They are nonnegative, sum to fifteen and have at most fifteen nonzero keys on the exact simplex. Each interior boundary changes once, at `u=1-frac(C_i)` if its fraction is nonzero. An exact real-arithmetic search needs at most `n` count vectors, rather than sampling sixteen phases or searching all integer allocations.

There is a useful response update. With signed-nibble cache code `c_i`,

```
S(u) = sum_i q_i(u)c_i
     = 15 c_n + sum_{i=1}^{n-1} B_i(u)(c_i-c_{i+1}).
```

At each event the integer numerator changes by the adjacent code difference `c_i-c_{i+1}`. Group coincident thresholds before scoring; scoring between simultaneous events would admit a count vector no phase produces. For the frozen paid output matrix `L` and coordinate steps `D`, `G=D L^T L D` is positive semidefinite. The sweep maintains the squared error of `S/15` against the floating-probability code response, and updates its gradient by `G(c_i-c_{i+1})/15`. Precomputing those metric differences costs about `n*28²` scalar multiply-adds; evaluating all events costs about `n*28` more products, plus prefix construction, sorting up to `n-1` phases and the original floating target. At 256 keys the dense metric step alone is about 200,704 products per query/head. Computing the target costs another 7,168, the event updates roughly 7,140, and sorting/list construction and the final dot are extra. No transformed code vectors are assumed to exist for free. The preceding three-sweep key-exchange selector had the same 200,704-product metric preparation plus up to 322,560 candidate-score products. This new selector is cheaper in that grammar, but still far costlier than the one-digit dot it might save. Sorting is a serial and irregular dependency for a native lowering.

The optimum is for one phase per query in this grammar, not the best fifteen-count allocation. The identity and finite enumeration assume real normalized probabilities. The replay computes FP64 metrics from paid FP32 decoded O and recorded softmax probabilities; it neither certifies FP32 bit identity nor preserves the 4,095-count map.

## Frozen Qwen replay

The same original-producer captures, paid rank-28 factors, signed-nibble steps and heads 7/12 as the [key-exchange study](../value-mass-discrepancy/README.md) are replayed. Eight train and four already-inspected validation windows contribute four causal positions each. Each row chooses its own phase from its probabilities and codes without a fitted parameter. The reported squared post-O response error is against that head's 4,095-count response and normalized by its squared energy. The selector instead minimizes error against the floating-probability response. The exchange control uses the earlier three-sweep implementation and identical rows.

| Layer, split | Prefix 15 | Optimal query phase | Three-sweep exchanges | Phase events |
| --- | ---: | ---: | ---: | ---: |
| 0 train | .00060829 | .00024321 | .00024321 | 5,088 |
| 0 inspected validation | .00006709 | .00006096 | .00004790 | 2,544 |
| 14 train | .00136620 | .00083914 | .00044641 | 5,088 |
| 14 inspected validation | .00046388 | .00028060 | .00028369 | 2,544 |

Layer 14's phase reduces its head-only train/held error by 38.6%/39.5% from prefix, and narrowly beats the exchange arm on inspected held rows despite losing substantially on train. It does not qualify a one-digit head for the complete 1e-4 mixed-head budget, which uses every query and both output heads. Layer 0's identical train aggregates conceal individual count choices; its held phase loses to exchange. These rows have been inspected in several prior experiments, so this is a finite-family and cost result, not fresh generalization or model loss. The code and count cache have the same bytes and direct nibble-dot work as the previous one-digit arm, but the phase selector is activation- and cache-dependent. There is no GPU timing or Bonsai runtime change.

The useful next search is a code/basis and mass policy learned together on quantized-producer text, with an online selector that does not build a 28-by-28 metric vector for every key and query. This exact phase search supplies a bounded target for any cheaper phase predictor. Fitting another static grid on the same frozen codes is unlikely to matter.

`measure.py` reproduces the two CPU panels. Rowwise errors, phase choices, event/support counts and source/model/capture/factor/cache/parent hashes are in `/path/to/workspace/data/kelana-subbit/value-adaptive-phase/layer{00,14}.json`.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-adaptive-phase/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-adaptive-phase/measure.py --layer 14
```
