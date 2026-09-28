# Value-aware one-nibble attention does not yet buy a cheap map

A conserved 15-count probability row fits one unsigned nibble and multiplies the frozen signed-nibble rank-28 V cache with one packed dot pass. Prefix rounding missed the existing 1e-4 post-O rounding budget even for a single head on Qwen3-0.6B layers 0 and 14. The count allocation, not only the number of units, might be at fault. This experiment replaces the prefix allocation with a response-aware integer allocation while keeping the probability mass, cache codes, V/O image and dot consumer fixed.

For probabilities `p_i`, cached 28-coordinate code vectors `c_i`, paid head output matrix `L`, and diagonal coordinate steps `D`, let `G=D L^T L D` and `mu=sum_i p_i c_i`. We seek nonnegative integers `n_i` with `sum n_i=15` minimizing `||(sum n_i c_i)/15-mu||_G²`. The output response, not probability distance, is the objective. Start with the prefix-rounded `n`. Each of three sweeps replaces each individual unit by the candidate key with the lowest resulting squared error. Every exchange preserves the unsigned-nibble and mass contracts, and the floating-response objective cannot increase. This is coordinate descent, not a global optimum. It needs the current query's softmax row and all cached codes. The measured error below instead uses the frozen 4,095-count code response as reference, so it need not be monotone row by row.

There is also an unconditional existence bound for *any* value codes and positive semidefinite `G`. Draw fifteen keys independently with probabilities `p`, and let `n_i` be their frequencies. Then `E[(sum n_i c_i)/15]=mu` and

```
E ||(sum n_i c_i)/15-mu||_G²
    = (sum_i p_i ||c_i-mu||_G²)/15.
```

Thus at least one conserved unsigned-nibble allocation attains at most that bound. Repeated conditional expectation gives a deterministic construction: after choosing `k` keys with sum `S`, choose the next key minimizing `||S+c_i-(k+1)mu||_G²`; the expected remaining variance falls as `(15-k-1)/15²`. This proves representational feasibility at a specified distortion, not a cheap way of selecting keys. In particular, the bound does not promise the programme's 1e-4 budget.

The CPU replay uses frozen original-producer Q/K and the same paid narrow V/O image as the [prefix one-digit study](../value-nibble-one-digit/README.md). Each split samples positions 63, 127, 191 and 255 from each window. Eight train and four previously inspected validation windows supply 32 and 16 causal rows, respectively. The selected heads are 7 at layer 0 and 12 at layer 14, the preceding best single-head prefix replacements. Each row gets its own value-aware count choice; there is no trained parameter. Errors divide by that head's 4,095-count post-O squared energy over the selected rows. They are **head-only conditional errors**, not full summed attention/O error or model loss.

| Layer, split | Prefix 15 error | Value-aware 15 error | Sampling existence bound | Rows improved against 4,095 | Selected nonzero keys / rows |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 train | .00060829 | .00024321 | .00251255 | 3/32 | 39/32 |
| 0 validation | .00006709 | .00004790 | .00108525 | 1/16 | 24/16 |
| 14 train | .00136620 | .00044641 | .00475267 | 22/32 | 83/32 |
| 14 validation | .00046388 | .00028369 | .00600344 | 11/16 | 45/16 |

The 1e-4 mixed-head budget is normalized by the *whole* O response on all query rows, so these head-only sampled numbers cannot be compared directly with its threshold. The largest reduction is layer-14 train, 67.3%, but the resulting conditional error is still .00044641. The sampling bound is loose by more than an order of magnitude here. The layer-0 held aggregate improves despite only one of sixteen rows improving; that warns against treating this tiny conditional sample as a robust choice of allocator. The result establishes that prefix rounding leaves useful distortion on the table, but does not establish a quality-compatible one-nibble program.

The count selector's online work is the larger obstacle. With `d=28`, `n` occupied keys and 45 individual exchanges at most, computing `G c_i` directly costs `O(n d²)` real operations and rescoring candidates costs `O(45 n d)`, besides the `O(n d)` floating target and the softmax row. At `n=256` this is roughly 200,704 metric-vector scalar products and 322,560 candidate-score scalar products per query/head, before the one-nibble dot, list construction, cache gathers and O. Precomputing a metric-vector per cached key moves work to the producer and adds 28 real coordinates per key; it is not free. Those are program counts, not gfx1151 time. The direct two-/three-nibble consumer retains a cheaper count construction and remains the more credible native target on the frozen image. The next question is a jointly trained value code and *cheap* value-aware mass rule on quantized-producer complete-model text, not another local exchange sweep.

`measure.py` reproduces the replay. `/path/to/workspace/data/kelana-subbit/value-mass-discrepancy/layer{00,14}.json` holds every sampled row's errors, support, sampling bound and source/model/capture/factor/cache/parent hashes. From a Kelana checkout, run each layer in its own bounded CPU command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-discrepancy/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-discrepancy/measure.py --layer 14
```

The proof assumes real arithmetic, nonnegative probabilities summing to one, a positive semidefinite output metric and independent samples. The CPU optimizer uses FP64 metric algebra over floating reconstructed codes. Neither statement proves FP32 output bit identity. No GPU, native kernel, executable or service changed.
