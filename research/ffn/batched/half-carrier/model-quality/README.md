# Half accumulation inside the whole model

This experiment runs genuine per-128-block binary16 scale multiplication and
accumulation across all 64 FFNs. It measures full-model logits and compares one
captured FFN with the standalone fast kernel. The two implementations produce
similar-sized perturbations, but they do not produce the same output vectors.
The full-model figures below therefore describe this intervention, not an exact
integration of `hc-rowpair-a4-tt8-down1-rne`.

## Implementation and controls

[`carrier_quality.hip`](carrier_quality.hip) links in place of `halo_rows.o` and
includes the unchanged upstream source. Attention, recurrent state and the head
retain the deployed computation. Two FFN phases are interposed:

- `ph_prep` uses direct symmetric A4 quantization at both FFN boundaries, as in
  [`lossy/quality.hip`](../../lossy/quality.hip).
- `ph_matvec_auto` computes integer block dots, applies half-rounded block scales
  and activation scales, and accumulates in binary16. It derives a dyadic row
  gauge from the actual weight scales and restores the gauge at the output.

This is not a cast of a completed FP32 projection. Counters check changed
quantizer chunks, projection tile groups and declined interventions on every
layer. The driver rejects a run whose counts disagree with its configuration.

The phase reads deployed HALO weights through integer dot4 rather than the
standalone kernel's repacked IU4 WMMA operands. A4 ternary block dots have magnitude
at most 896, so their integer values fit binary16 exactly. A lane accumulates all
blocks sequentially, giving up the deployed K split. This phase is slower by
construction and supplies no throughput result.

The standalone kernel also has its own normalization, Hadamard and consumer
implementation. The intervention uses the deployed `prep_chunk_r`. Association
and intermediate rounding differ. The replay below measures their disagreement.

Configurations are `bits:layers:carrier`:

| Carrier | Changed projections and arithmetic |
|---:|---|
| 0 | None |
| 1 | Gate/up, half accumulation |
| 2 | Gate/up and down, half accumulation |
| 3 | Gate/up and down, FP32 accumulation on the new schedule |
| 4 | As 3, with reversed block accumulation order |
| 5 | Gate/up only, FP32 accumulation on the new schedule |

Carrier 1 uses control 5; carrier 2 uses control 3. Comparing carrier 1 with
control 3 would also change the down schedule and would not isolate gate/up.

## Full-model observations

Two fixed prompts, 64 teacher-forced tokens each, 128 next-token distributions.
The [RNE record](results/model-quality-rne.json) retains configurations, token IDs,
intervention counts and provenance. Mean KL, all 64 layers changed:

| Configuration | From original | From A4 control | From matched FP32 schedule |
|---|---:|---:|---:|
| A8 repeated reference | 0 | | |
| A4 control | 0.0159771 | | |
| A4, new FP32 schedule | 0.0132519 | 0.0258117 | |
| A4, reversed FP32 block order | 0.0134127 | 0.0282253 | 0.0243573 |
| A4, FP32 gate/up schedule only | 0.0141927 | 0.0289105 | |
| A4, half gate/up | 0.0131819 | 0.0267781 | 0.0255604 |
| A4, half gate/up and down | 0.0153558 | 0.0292985 | 0.0264065 |

The A4 control reproduces the earlier lossy experiment's mean KL. That agrees on
this statistic; it is not a proof that two implementations have identical logits.

Reversing FP32 additions changes top-1 at 17 of 128 positions relative to the
forward-order schedule. Half accumulation changes 16. Their mean KLs differ by
about 8%, although the one-layer projection perturbations differ by a factor of
6100. KL is not proportional to local tensor error. These observations do not
establish a noise floor, saturation, error cancellation or a bound on other inputs.

The same comparison at different intervention depths:

| Changed layers | FP32 reverse vs forward | Half vs FP32 forward | A4 vs original |
|---:|---:|---:|---:|
| 1 | 0.000164 | 0.000167 | 0.000192 |
| 8 | 0.000535 | 0.000847 | 0.000623 |
| 64 | 0.0244 | 0.0264 | 0.0160 |

The [truncated-scale run](results/model-quality-truncated-scale.json) gives mean
KL 0.0251762 from A4 and 0.0251896 from the FP32 schedule, versus RNE's 0.0292985
and 0.0264065. This is a measured difference on these prompts, not evidence that
truncation generally improves quality. The standalone block analysis identified
systematic shrinkage from truncation. RNE remains the chosen construction.

A4 rounding boundaries are a plausible source of sensitivity. The capture shows
both perturbations flipping hidden codes, but 343 versus one, not a common
saturated flip count. A perturbation sweep and broader behavioral evaluation have
not been run. The earlier consumer-polynomial KL measurements remain measurements;
this experiment does not invalidate them or let us subtract their errors.

## Capture and replay

`--capture LAYER --capture-prefix P` records one eight-row pass: FFN input,
input codes and scales, gate/up projections, hidden codes and scales, and output
residual. [`replay.cpp`](replay.cpp) compares the intervention configurations and
runs the standalone candidates on the captured input. The 1.6 MB capture binaries
are regenerated; [transfer-layer0.json](results/transfer-layer0.json) records metrics.

The three in-model configurations have identical input residuals and identical
input operands: zero differences among 40960 codes and 320 scales. Their projection
comparison therefore isolates the arithmetic after input quantization.

| Layer 0, eight rows | Half vs FP32 | Reverse FP32 vs forward |
|---|---:|---:|
| Gate/up relative RMS | 9.107e-4 | 1.497e-7 |
| Hidden codes differing | 343 / 139264 | 1 / 139264 |
| Residual relative RMS | 1.926e-3 | 3.254e-5 |

Cross-implementation replay on that same residual:

| Comparison | Relative RMS |
|---|---:|
| Standalone half vs standalone control | 0.1910% |
| In-model half vs in-model FP32 control | 0.1926% |
| Standalone control vs in-model FP32 control | 0.0469% |
| Standalone half vs in-model half | 0.1635% |

The first two norms agree closely. That does **not** establish numerical transfer:
the last row is an actual output disagreement almost as large as the carrier
perturbation itself. Producer/consumer association differences and later quantizer
decisions remain in the comparison. The control mismatch does not bound the half
mismatch or cancel it.

This establishes a genuine half-accumulation full-model experiment and quantifies
the replay gap. It does not establish that the fast standalone candidate inherits
these exact full-model KL figures. Acceptance still needs an integration preserving
the winning kernel's complete numerical map, broader prompts and an explicit
quality threshold. There is no full-model throughput claim here.

## Reproduce

```sh
cd research/ffn/batched/half-carrier/model-quality
python3 run_quality.py --tokens 64 \
  --configs 8:0:0,4:1:0,4:1:3,4:1:4,4:1:2,4:8:0,4:8:3,4:8:4,4:8:2,4:64:0,4:64:3,4:64:4,4:64:5,4:64:1,4:64:2 \
  --out results/model-quality-rne.json
python3 run_quality.py --tokens 64 --truncate-scale \
  --configs 8:0:0,4:64:0,4:64:3,4:64:2 --out results/model-quality-truncated-scale.json

../../hardware-run ./build/carrier-quality --tokens 8 --capture 0 --capture-prefix /tmp/capture \
  --configs 4:64:2,4:64:3,4:64:4
make replay && ../../hardware-run ./build/replay \
  --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
  --prefix /tmp/capture --layer 0 --json results/transfer-layer0.json
```

The runner takes the shared research GPU lock and stamps source, engine-object
and binary hashes. It refuses to stamp a result if those change during the run.
