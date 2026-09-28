# Frozen chronological KIVI2 V error feedback

**Result:** On four held 256-token streams × the eight already-retained t128/t256 complete Q→softmax→V→original O states, causal first-order value error feedback has pooled original-teacher squared error **0.002139543**, versus unchanged K2/V2 **0.003068937**, delayed-original V retention **0.002973482**, and the previously published K2/V4 **0.000713499**. Feedback beats unchanged K2/V2 in 6/8 states and the lower-state delay control in 6/8; it does not approach K2/V4 (which wins all eight against K2/V2). These are complete observer outputs, not uniform-weight prefix-sum predictions, native timing, a speedup or a full-model result. First-order error feedback/noise shaping is an established technique, not a novelty claim. No gain, precision, clipping, group ordering, extra pass or tuning was tried.

The [observer foundation](THEORY.md) and [`Kelana/ValueErrorFeedback.lean`](../../../Kelana/ValueErrorFeedback.lean) distinguish weighted chronological cancellation from uniform-prefix error. Publication review corrected the prose for held-1/t256 (feedback beats K2/V4 there) and made independent replay/aggregation reject any change to the successful exchange-control receipt through its owning `controls.py`. Numerical receipts and source images were not regenerated.

## Rule frozen before scoring

Original KIVI2 K2/V2 G32/R32 after-query K and V events remain in place. Each KV head carries a 128-coordinate FP32 residual initially zero. At each original V flush, the oldest *arrived* BF16 source vector `v` supplies the four source-based group32 FP32 minima and steps `(max−min)/3` (not extrema of the shifted target); original FP16 origin/step bytes remain unchanged. `target=FP32(v+r)`; codes are nearest-even `clamp(round((target−original_source_min)/original_source_step),0,3)`, with original zero digit when the source step is zero. Decode from **stored FP16** origin/step and emitted digits in FP32, then `r=FP32(target−decoded)`. The initial zero-residual digits equal the original scalar encoder. K events, recent BF16 bytes, Q, teacher, O and query chronology never change. The residual follows the original 224 flushes/head at t33…256 in strictly ascending time. The delayed control starts at t35 and ends with 222 flushes/head. There is no feedback state in the decoder or serialized cache: its 8×128×4=**4096 B** is separately paid per sequence.

A prespecified stronger *lower-state* control copies every original K/V digit and FP16 field byte, changes only V recent threshold from 33 to 35 before popping after the query (the original V event is two timestamps later), and keeps the original K event times. At t256 before query it holds two more recent BF16 V vectors per head and two fewer packed original V records. It does not alter the source codes or replay missing queries. Full eight-head state ledger:

| Program | peak cache | added resident | peak total | final total |
|---|---:|---:|---:|---:|
| original K2/V2 | 304,768 | 0 | 304,768 | 249,856 |
| causal feedback | 304,768 | 4,096 FP32 residual | **308,864** | **253,952** |
| original-code V delay2 | 308,096 | 0 | **308,096** | **253,184** |

The control has **768 B less** peak/final state than feedback. At t128/t256 feedback uses exactly the original before-query cache byte ledger; delay2 uses two additional recent vectors rather than two prior V records. Event logs, source arrival files, query evidence, audit receipts and scoring scratch are not resident cache.

## Eight held complete observers

Squared error against the same original teacher; common teacher squared norm **271.317982467**. Original K2/V2 and K2/V4 are SHA-pinned successful same-state controls from [`kivi-o-aware-values`](../kivi-o-aware-values/) and [`kivi-kv-rate-exchange`](../kivi-kv-rate-exchange/), not reruns or full256-query substitutions. K2/V4 uses substantially more paid peak state (**361,856 B**), so the favorable comparison is not an equal-byte claim.

| held / t | feedback SSE | delay2 SSE | K2/V2 SSE | K2/V4 SSE |
|---|---:|---:|---:|---:|
| 0 / 128 | .025401675 | .023523110 | .023815413 | .014293690 |
| 0 / 256 | .036697601 | .029588794 | .033375713 | .011871515 |
| 1 / 128 | .198589778 | .219143879 | .219059882 | .041487212 |
| 1 / 256 | .028917987 | .035768639 | .035663173 | .030730369 |
| 2 / 128 | .024238940 | .027522185 | .027687015 | .016614791 |
| 2 / 256 | .050415360 | .102423995 | .104052115 | .012962948 |
| 3 / 128 | .101057182 | .146188459 | .166549611 | .036972421 |
| 3 / 256 | .115177952 | .222600022 | .222455007 | .028652069 |
| **pooled SSE** | **.580496474** | **.806759082** | **.832657928** | **.193585015** |
| **pooled SSE / teacher²** | **.002139543** | **.002973482** | **.003068937** | **.000713499** |

Relative to K2/V2, feedback lowers pooled SSE **30.28%**, delay2 **3.11%**; feedback lowers it **28.04%** relative to delay2. Feedback's improvement is not pointwise: it loses at held-0/t128 and held-0/t256 to both lower-rate controls. It beats K2/V4 at held-1/t256 but loses to that higher-rate arm at the other seven states. The independent K4/V4 same-state control is pooled **.0000426253**. The causal residual telescopes unweighted reconstruction errors across a prefix in exact arithmetic, but the actual future query softmax weights are nonuniform and K/O errors remain; there is no mathematical implication of observer improvement.

## Reproduction, provenance and costs

[`build.py`](build.py) reads *only* the four SHA-checked [`kivi-value-intern`](../kivi-value-intern/) held arrival event streams and original [`kivi-two-bit-causal`](../kivi-two-bit-causal/) K2/V2 event logs. It emits actual time-stamped event logs, final cache images and eight before-query paid cache images, plus each **pre/post prefix cache SHA, bytes, and actual residual FP32-state SHA** in four manifests. [`replay.py`](replay.py) independently parses original and new events, verifies all 256 pre/post cache and residual states per head per stream, every original K byte, source-derived V field/nearest-even original digit, feedback digit/FP32 recurrence, unchanged delay digits, arrival source, final bytes and retained images. It checks every original prefix receipt for the feedback arm. It then uses only retained [`kivi-two-bit-dot-native`](../kivi-two-bit-dot-native/) SHA-checked original Q, teacher, O to score 16Q/8KV full softmax and full O in float32 Torch, comparing float64 SSE. [`aggregate.py`](aggregate.py) checks unchanged owner control receipts and publishes [`results.json`](results.json), per-state output SHA and pooled sums. No checkpoint, source arrays, model forward, GPU, recaptured Q or missing query are used.

Each normal command completes in under 60s using `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python`: run `build.py W` for `W=0…3`, then `replay.py W`, then `aggregate.py`. Builder production and reader verification use separate implementations of the source quantizer and feedback update. Across four streams feedback changes **151,686 packed V code bytes**, keeping all 7,168 original V flush timestamps and FP16 fields. The delayed control keeps every original V record byte but has only 7,104 emitted records by t256 over four streams.

Feedback's online extra producer work per emitted V vector is 128 FP32 additions for target, decode from stored fields (128 FP32 multiply/add), 128 FP32 subtractions and a 512-B residual update; original source min/max and 128 digit assignments are retained, now applied to the target. The straightforward builder allocates a 512-B FP32 target, a 512-B FP32 decoded vector and a 128-B digit buffer per flush, besides source/recent data and the 512-B per-head residual (4,096 B per full layer). The independent replay expands decoded K/V as full float32 tensors (2×8×256×128×4=2,097,152 B at t256) plus attention/output scratch. This is CPU verification scratch, not charged as packed resident cache or claimed native latency. Feedback readout uses the original packed format without per-query decode of residual; the delayed control reads two more BF16 recent V records/head and two fewer packed V records/head at retained long prefixes. All future queries' actual softmax weights—not uniform averages—determine the reported outcome.
