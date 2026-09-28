# How much information can two collisions discard?

The fixed trained-region experiment establishes 27 distinct output vectors on each of 36 three-coordinate cubes. Its 26-state lower bound is tight, but it did not price the next collision. Here the decoder is completely free and each input may receive an arbitrary carrier label. Even under that generous contract, reducing the carrier to 25 states costs **10.69% to 19.02% of output-variation RMS** across the 36 tables. At 26 states the exact range is 7.56% to 13.38%. No tested 25-state carrier can meet a 10% variation-RMS target on any table. These are region variation errors, not errors over the full FFN update or full-model quality results.

The new result is exact for each *computed* float64 output table, up to the rounding of its distance calculations. It requires no instruction-grammar restriction and no particular trit representation. It assumes the carrier is all the input-dependent state available to the continuation. A second dynamic register carrying the distinction changes the state count.

## Why the search is complete

For outputs `y_i`, a decoder minimizing squared error on a carrier class `S` returns their mean. Its cost is `sum_{i<j in S} ||y_i-y_j||² / |S|`. A partition of 27 inputs into 26 classes has exactly one pair and 25 singleton classes. The optimum is half the smallest pair distance squared. This also explains why the existing closest-pair lower bound at capacity 26 is exactly tight.

A partition into 25 classes has either one triple and 24 singletons, or two disjoint pairs and 23 singletons. `exact.py` enumerates all 2,925 triples and all disjoint pair combinations, computes their mean-decoder costs, and retains the winning input indices. Further mergers have nonnegative cost, so an at-most-25-class carrier cannot improve by using fewer classes. `test_exact.py` compares the algorithm against an independent enumeration of every set partition on six-point problems and replays those carriers through the explicit mean decoder. The trained tables are regenerated from the captured inputs and real HALO weights using the existing CPU evaluation; each of the 36 output byte hashes must match its published trained-region record before its optimum is accepted.

Every winner at 25 states consists of two disjoint pairs, one being the optimal 26-state pair. No triple wins. The pair indices and full squared-error fractions are in the four JSON records here.

| hidden quantizer | exact 26-state variation RMS | exact 25-state variation RMS |
| --- | ---: | ---: |
| none | 7.56–9.55% | 10.69–13.51% |
| A8 | 8.84–12.44% | 12.55–17.62% |
| A4 | 12.18–13.38% | 17.25–19.02% |

The scale of the difference matters: a 10% *regional* variation tolerance sometimes permits one collision without hidden quantization, but none of these 36 cases permits two. Quantization changes which distinctions are cheap to merge; a smooth surrogate is not a certificate that its quantized continuation preserves them. This settles the near-lossless 25-state capacity question for these cubes, rather than extrapolating a rank or a nearest-neighbor relaxation.

## Reproduction and next experiment

From this directory run `python3 test_exact.py`. To regenerate one of the four records, run `OPENBLAS_NUM_THREADS=4 python3 exact.py --layer 0 --anchor 0 > layer00-anchor000.json`, choosing layer 0 or 10 and anchor 0 or 127. The records bind to the existing trained-region JSON by SHA-256 and each output table by the independently recorded byte digest. They use the same CPU float64 operations as `trained.py`, not native FP32 execution. Each invocation regenerates nine tables without the earlier polynomial/producer scan.

The result suggests a sharper native construction: retain all 27 input states in the existing five-bit radix-3 coordinate and search a consumer that operates on that coordinate across the quantizer cells. If a region-wide sideband is proposed instead, count the product of carrier and sideband states. Eleven main states plus a side alphabet do not inherit an eleven-state capacity claim. A candidate must price online side-code construction, quantization, the down projection and the boundary conversion before a GPU timing means anything. This experiment contributes a semantic capacity limit, not an executable cost or a whole-model throughput result.
