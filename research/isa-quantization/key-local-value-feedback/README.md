# Fixed causal key-local residual: complete contextual layer-1 observer

**One paid program, no output-driven revision.** Train-only geometry was fixed at `d16b32399c944aaa827eeadda00611473f9d5610`; the original CPU source and four successful controls at `ae0395afff62042fb402c8931917cd965e2a359c`. The frozen arithmetic/acceptance contract was sent before the new scores. This is original layer-0 residual → CPU layer-1 **teacher-forced**, not a model rollout or GPU forward. All 256 actual query outputs/window from eight train and four previously inspected validation windows use saved source Q/K/V, saved teacher and the original SHA-pinned full O. No source forward, tuning, new teacher, read-time residual correction or variant was performed.

| Panel / pooled all-coordinate SSE | Original K2/V2 | Sequential V feedback | Original-code V34 delay2 | K2/V4 | **Key-local** |
|---|---:|---:|---:|---:|---:|
| Train (2,048 queries; teacher norm² 13,465.224624) | 209.016698 | 239.739259 | 206.290397 | 158.179727 | **209.967414** |
| Inspected validation (1,024; norm² 6,793.961378) | 107.923584 | 120.417466 | 106.487853 | 77.840169 | **106.236018** |

Relative squared error: train **0.0155933094**, validation **0.0156368298**. Against original K2/V2, this program worsens pooled train SSE by **0.455%** but improves inspected validation by **1.564%**; against cheaper V34 delay2 it worsens train by **1.783%** and improves validation by **0.236%**. It beats original on 885/2048 train and 557/1024 validation queries, delay2 on 699/2048 and 427/1024, sequential feedback on 1498/2048 and 733/1024, and K2/V4 on only 21/2048 and 9/1024. This exact fixed program does **not** establish a train pooled-output gain or a state/work win over V34. Validation is inspected, not a held-out basis for selecting a new variant. Geometry alone did not predict this output outcome.

## Arithmetic, record and time contract

One FP32 residual128 and u16 recipient per KV head start at zero and one. At each arrival `t`, append source BF16 K/V and score Q against the **preflush** actual K/V image through original O. Then emit the unchanged 32-token K2 record on K32 flush. At V33 after-query flush `i=t−32`, if `i != recipient`, emit the **byte-identical** original V2 record and leave both outstanding fields untouched. If equal, use the frozen sequential-feedback donor arithmetic: source BF16 V's four G32 min/max extrema define grid `/3` and unchanged FP16 `(origin,step)` fields; quantize the FP32 `v+residual` to nearest-even clamped 2-bit digits, decode those digits with **stored FP16 fields in FP32**, update `residual=FP32(v+previous−decode)`. Select the next recipient among `i+1…t` by nearest actual **post-K-flush** causal K cache: FP32 coordinate subtraction and square, FP64 distance sum, earliest position tie. Source K is already K2, younger candidates are K2 if emitted and otherwise the *then-current* BF16 recent K. The read uses actual packed K digits/FP16 fields, including key aging; it does not consult future K records. No recent BF16 V is ever patched with pending debt. The last selection leaves a recipient and residual outstanding after query 256, not a recovered correction.

The encoder [`build.py`](build.py) consumes original K/V event logs and source, reuses the **exact** frozen donor `val` routine, copies K and skipped V bytes, writes actual packed event logs, preflush t128/t256 images, final images, all 256 pre/post cache hashes, residual hashes and recipient fields. The independent [`replay.py`](replay.py) parses its own event bytes, checks source arrivals and per-event original K and V fields/digits, exact skipped V records and prefix/images, recomputes each selection by an independent key decoder/distance loop (not the builder decision function), reconstructs residual from actual stored-field V decode, and scores every full 1024-coordinate O output from the actual preflush packed cache. The retained [`summary.json`](summary.json) pins the source, original manifests/results, geometry train ledgers, own manifests/results, original O and per-window results. Train routes match all 1,037 frozen geometry decisions. Validation's 554 routes were applied once from keys alone; neither validation route nor outcome was fitted. Source and control receipts were reused, not rerun. Per-window receipts include every query output SHA, squared error and teacher squared norm, route, skipped error and pending debt; actual event/image files are the replay inputs, not merely assertions in a builder manifest.

## State and work, not just routing distance

| Eight KV heads per sequence | Peak before flush | Final after flush |
|---|---:|---:|
| Original K2/V2 | 304,768 B | 249,856 B |
| Sequential residual feedback | 308,864 B | 253,952 B |
| Original-code V34 delay2 | **308,096 B** | **253,184 B** |
| K2/V4 | 361,856 B | 307,200 B |
| **Key-local** | **308,880 B** | **253,968 B** |

Key-local adds exactly 8×512=4,096 B outstanding FP32 residuals and 8×2=16 B recipient identities to the unchanged original cache. These are exported as actual4,112-byte `*-t128-encoder.bin`, `*-t256-encoder.bin` and `*-final-encoder.bin` images, head-major with512B little-endian FP32 residual followed by2B little-endian recipient. Combining one such image with its eight cache images gives the complete paid continuation state. `*-encoder-images.json` binds their SHA256 and original manifest. Parent materialized these from the independently verified frozen chronological replay, not a new encoding choice or query rerun; both builder and normal replay now write/check the same byte layout. It costs **784 B more** than V34 delay2 at both boundaries. The already-shared common counter, source Q/K/V/teacher and static O are not counted as cache savings. Preflush images have recent original BF16 V and thus no future-debt correction.

Train has 14,336 original V flushes, **1,037** visited residual updates and **13,299** exact original-code skips; validation has 7,168, **554** and **6,614**. On visited events the encoder still computes original source extrema/FP16 fields, but additionally performs 128 FP32 residual additions, 128 stored-field decodes and 128 FP32 residual subtractions, plus 512 B residual write, digit assignment and a recipient write. For conservative unshared routing reads, train performs 19,449 packed K2-vector decodes and 14,772 recent BF16-vector reads = **14,361,888 B** (K2 vectors reread 32 digit+512 field bytes; recent BF16 256 B). Validation performs 11,116 and 7,166 = **7,881,600 B**. There are respectively **4,247,552** and **2,269,184** FP32 coordinate subtractions/squares with FP64 accumulation, plus candidate comparisons and 1,037/554 source-vector decodes; each active scan needs a 512-B source and 512-B candidate, scalar FP64 accumulator, and visited V encoding needs a 512-B target, 512-B decoded vector and 128-B digit buffer. Sharing chunk fields can lower actual reads, but is not credited. Decoder scratch expands up to 2×8×256×128×4=2,097,152 B during offline query replay, outside resident producer cache. No native latency has been measured.

Summed *unweighted source-vector* V squared errors expose the debt rather than claim a correction: train visited 433.506402, skipped 3256.863701, pending final FP32 residual squared norm 12.840226; validation visited 246.890950, skipped 1629.907490, pending residual norm² 5.645857. Skipped original errors are untouched; 8 residual128 vectors per window remain payable until a future recipient flush, and at the t256 boundary every head has such pending debt. These unweighted errors are not output SSE and cannot be subtracted from it. Source-key aging is re-evaluated by the independent replay at each actual recipient decision, not assumed from the frozen selection snapshot.

## Reproduction and custody

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for p in train validation; do
  n=8; [ "$p" = validation ] && n=4
  for w in $(seq 0 $((n-1))); do
    "$PY" research/isa-quantization/key-local-value-feedback/build.py "$p" "$w"
    "$PY" research/isa-quantization/key-local-value-feedback/replay.py "$p" "$w"
  done
done
"$PY" research/isa-quantization/key-local-value-feedback/aggregate.py
```

Each invocation takes under 55 s. All replay and source/controls are CPU-only, with one BLAS/Torch thread. To reconstruct only the actual encoder-state companions without rerunning the successful query observer, run `replay.py PANEL WINDOW --materialize-state`; it still checks every original prefix, packed event, residual and recipient before writing those companions. The 12×8 event, endpoint and final binaries, 36 encoder-state companions, 12 encoder-image manifests, 12 original manifests, 12 full-query result receipts and summary are immutable evidence in this subtree; the two scripts plus aggregator are their reproduction path. Original files remain owned by `contextual-value-feedback`, geometry by `key-local-value-transport`.
