# Accumulation and representation search: integrated results

This comparison combines the [dense operand](dense-consumer/README.md), [scale carrier](scale-carrier/README.md) and [tile ownership](tile-ownership/README.md) work in one executable. All recurring work from FP32 residual input to FP32 residual output is timed. These are whole-FFN results, not full-model tokens per second.

## What became faster without changing its numerical map

Each row below names its own numerical baseline. The candidates have identical output hashes to that baseline at all three batch sizes on both layers. A4, IU8/A8 and scaled-FP16/A8 are different numerical families; equality within one family does not equate the families.

Round-geometric speed ratios, layer 0 / layer 10:

| representation and schedule | baseline | 32 rows | 128 rows | 256 rows |
|---|---|---:|---:|---:|
| IU8 wide loads + adaptive shared-tile ownership | arithmetic IU8/A8 | 1.144 / 1.140 | 1.092 / 1.106 | 1.102 / 1.120 |
| scaled-FP16 wide loads, original ownership | compact-scaled FP16/A8 | 1.236 / 1.202 | 1.049 / 1.035 | 1.012 / 1.008 |
| scaled-FP16 adaptive ownership, slice loads | compact-scaled FP16/A8 | 1.024 / 0.996 | 1.105 / 1.094 | 1.042 / 1.035 |
| dense five-trit storage | arithmetic IU4/A4 | 1.975 / 1.938 | 0.981 / 0.970 | 0.982 / 0.967 |
| two-trit nibble codes + wide loads | arithmetic IU4/A4 | 1.771 / 1.757 | 1.373 / 1.366 | 1.297 / 1.285 |

The useful choices are the IU8 wide/adaptive candidate, scaled-FP16 wide at 32 and adaptive at larger batches, and dense A4 at 32 versus pair-code A4 above. These are measured choices among separate candidates, not a deployed automatic selector or a proved optimum. A selector needing two weight images must count both images.

Layer-0 median milliseconds:

| numerical family | existing baseline, 32 / 128 / 256 | selected new candidate, 32 / 128 / 256 |
|---|---|---|
| IU8/A8 | 1.086 / 2.250 / 4.419 | 0.938 / 2.064 / 4.010 |
| scaled-FP16/A8 | 1.087 / 2.278 / 4.008 | 0.878 / 2.061 / 3.844 |
| IU4/A4 | 0.990 / 1.707 / 3.323 | 0.501 / 1.245 / 2.555 |

The dense result uses 26 code bytes per 128 weights, 1.625 code bits per weight. Including the FP16 block scale gives 1.750 total bits per weight. It consumes stored labels as selectors for the instruction's operand bytes. The larger-batch winner instead keeps two-bit storage but changes the pair labels and load layout. Density is a useful coordinate here, not a universal winner or a reason to force scalar decoding.

## The whole-K integer carrier

The direct palette removes unnecessary intermediates from the earlier grouped-scale IU8 map, preserving all its output bits while speeding it up 1.08–1.16x in its matched experiments.

Extending it over the entire projection removes every intermediate scaling boundary. Fit `weight = L[row] * integer_weight`, produce `activation = c[token] * integer_activation`, accumulate one int32 state and scale once at the end. The largest possible partial-sum magnitude is 280,773,632, inside int32. [IntegerScaleCarrier.lean](../../../Kelana/IntegerScaleCarrier.lean) proves the algebraic factoring and integer range statement.

This version changes the fitted scales and the activation quantizer. At 256 rows its residual RMS error against the engine is 0.113% / 0.167% on layers 0 / 10, versus 0.0158% / 0.0194% for scaled-FP16/A8. It originally beat compact-scaled by about 4%, but the new precision-preserving ownership schedule largely erases that advantage:

| layer | whole-K integer, 256 rows | new scaled-FP16 adaptive, 256 rows |
|---|---:|---:|
| 0 | 3.866 ms | 3.844 ms |
| 10 | 3.864 ms | 3.875 ms |

So the higher-error carrier is not the preferred large-batch result from this round. Its representation and range proof remain useful. A separate wide-load variant wins at 32 rows, 0.781 ms, but loses at larger sizes even without spills. No full-model quality or TPS result exists for it.

## What generalized

- Build the instruction's required operand directly from the stored label. A two-trit selector or a scaled-byte palette can replace a sequence that first reconstructs named weights.
- A representation can persist through an entire sum when every term shares an outer scale. The range bound must cover every prefix, not merely the observed final sums.
- ISA instruction counts are not a runtime model. The dense map adds operand work; the whole-K wide-load map loses at large batches without spilling. Neither fact licenses a universal lower bound on other representations.
- Layout and ownership interact. Independent speed ratios cannot be multiplied. The cross-products were measured, and several combinations lost.

## Evidence and scope

The integrated records are [layer 0](tile-ownership/results/integrated-layer0.json) and [layer 10](tile-ownership/results/integrated-layer10.json). Each has 40 calls per candidate, ten randomized rounds, a two-second workload ramp before each batch, source fingerprints including local headers, raw timing samples, GPU telemetry and DRM clients. `hardware-run` serializes participating GPU experiments; the resident server and browser are outside that lock. No samples were discarded.

The adjacent `integrated-layer*-vs-*.json` files hold round-bootstrap intervals. For example, IU8 wide/adaptive at 256 rows is 1.102 [1.088,1.118] on layer 0 and 1.120 [1.112,1.129] on layer 10. Scaled-FP16 adaptive is 1.042 [1.036,1.048] and 1.035 [1.026,1.043]. Each wins all ten rounds.

The native permutation follow-up exhausts selectors on discriminating source vectors and compares constant-folded versus runtime calls. They agree. The initial worker explanation of a compiler discrepancy was wrong and has been removed; the corrected evidence is in [dense-consumer/results/perm-semantics.json](dense-consumer/results/perm-semantics.json).

No new full-model TPS is claimed. The A4 candidates preserve an already lossy A4 map, whose quality tradeoff remains separate. For engine adoption, retain the engine's producer semantics and measure the schedules at the actual batch sizes and contexts. The existing full-model A8 routing results in the parent README have not changed.
