# The fifteen-choice query fit has a one-choice fast path

The preceding [joint three-dot query](../shared-query-joint-round/README.md) improves held causal attention KL with an exact coordinatewise fit, but its implementation tries all fifteen difference nibbles. That enumeration is unnecessary. Completing the square gives a certified interval of possible winners. On the frozen Qwen3-0.6B paid Q/K captures, this interval contains one nibble for more than 97% of layer-14 coordinates and more than 99% of layer-0 coordinates. The quality and three packed key dots do not change.

| Layer | Split | One / two / three eligible coordinates | Mean candidates | Candidate fits per query rather than 3,840 |
| ---: | --- | ---: | ---: | ---: |
| 0 | eight train windows | 520,311 / 3,977 / 0 | 1.007586 | 257.942 |
| 0 | four inspected validation windows | 260,312 / 1,832 / 0 | 1.006989 | 257.789 |
| 14 | eight train windows | 512,418 / 11,867 / 3 | 1.022646 | 261.797 |
| 14 | four inspected validation windows | 256,054 / 6,089 / 1 | 1.023235 | 261.948 |

Each split has 256 prepared query coordinates per query and 2,048/1,024 query rows across its 256-token windows. The joint fit's train-selected base head and weight for each group are frozen. The script checks its interval result against all fifteen choices at every one of the 1,572,864 measured coordinates. It counts candidate fits, not CPU time. Relative to fifteen fits per coordinate, the conditional fit uses 93.28%/93.18% fewer fits on held layers 0/14, but interval construction adds a square root, divisions, integer endpoints and a branch per coordinate. There is no native latency or complete-model quality result.

## Proof and executable map

For one prepared query coordinate let `a0` be the base query, `a1` the other head, `delta=a1-a0`, `d>0` the fixed base scale, `e>0` the fixed difference scale, and `lambda>0` the fixed head weight. The candidate has integer `u` in `[-119,119]` and integer `v` in `[-7,7]`, with objective

```
L(u,v) = (a0-d*u)^2 + lambda*(a1-d*u-e*v)^2
       = (1+lambda)*(d*u - (a0+lambda*(a1-e*v))/(1+lambda))^2
         + lambda/(1+lambda)*(delta-e*v)^2.
```

Choose `v0=clip(round(delta/e),-7,7)`, and let `u0` be the rounded, clipped conditional minimizer for `v0`. Its actual objective `U=L(u0,v0)` is a feasible upper bound even at a clipped base endpoint. Every candidate `v` has objective at least `lambda/(1+lambda)*(delta-e*v)^2`. Therefore **all global minimizers** lie in the integer interval

```
max(-7, ceil((delta - sqrt(U*(1+lambda)/lambda))/e))
    <= v <=
min( 7, floor((delta + sqrt(U*(1+lambda)/lambda))/e)).
```

Evaluate the clipped nearest `u` only for integers in this interval. It always contains `v0`; equality stays in the interval, so ties are retained. This is an exact real-arithmetic reduction for the fixed-scale diagonal squared-error family, valid for any finite prepared queries and positive scales. The measured FP64 script uses a 1e-12 additive cost guard and checks the resulting minima against full enumeration. A native floating implementation needs a conservative outward-rounded interval if it promises the same choice at boundaries; a naked FP32 square root is not an exactness proof.

The interval is contiguous, so the online program need not scan fifteen lower bounds. One incumbent fit, a square root and two integer endpoints replace fourteen unconditional weighted candidate fits; on the measured inputs, only 0.7%/2.3% of held coordinates need another candidate. The existing score consumer still reads 128 packed K-cache bytes/token/layer and spends 768 signed-nibble products/key/layer. This changes only query preparation. Its held attention KL remains .278049/.333448 at layers 0/14 under the parent's selected joint map, against .278608/.334929 for independent shared rounding. These are repeatedly inspected original-producer windows, not quantized-producer text or native speed.

`measure.py` replays the parent's selected policies, paid query producer and pinned captures. Its source/model/capture/paid-image/parent hashes, group histograms and aggregate counts are in `/path/to/workspace/data/kelana-subbit/shared-query-pruning/layer{00,14}.json`. Run one layer with the installed CPU environment:

```sh
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/quantization-discovery/subbit/shared-query-pruning/measure.py --layer 14 \
  --output /path/to/workspace/data/kelana-subbit/shared-query-pruning/layer14.json
```

This removes the fifteen-way search objection to *representing* the joint fit, but not its online cost objection. Next compare a native query preparation plus fused three-dot score at occupied context against independent rounding and four dots, after checking whether the held quality survives quantized-producer text. A cheaper approximate interval without a certified boundary is a different map and needs its own quality evidence.
