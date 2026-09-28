# Causal K-near residual recipient: one fixed train-source screen

**Finite geometry, not an output win.** Across eight existing train windows of the layer-1 CPU source, a single outstanding residual per KV head routes to the closest already-arrived younger V token by *actual causal K-cache* squared distance. At the same active source/timestamp, selected distance is **317,522.58** vs **782,742.99** for the immediate successor (sum over 1,037 decisions; ratio 0.40565). However the chain touches only **1,037 / 14,336 = 7.2335%** of original V flush events; the other 13,299 tokens receive original V codes. Nothing here measures V error or query output, and improved K proximity does not imply an attention benefit. No candidate V codes, teacher, Q/O, validation/held source, fitting, GPU or model replay was used.

## Causal rule and pending debt

Positions are one-based. At arrival/query `t`, original K holds up to 32 BF16 recent tokens, then flushes the full chunk after query. Original V holds up to 33 BF16 recent tokens, then flushes its oldest after query. The routing decision occurs **after that K flush and at the V flush**, not in the query's preflush image. For each active V flush `t=33…256`, oldest/source `i=t−32` has its K in an already-emitted K2 time chunk; all 32 younger recent-V candidates `j=i+1…t` have actually arrived. Their K is read as stored then: K2 if its chunk was emitted, otherwise BF16 from the recent K cache. Use minimum 128-coordinate squared Euclidean distance and earliest token position on a tie. Choose the recipient after encoding the source token; until that recipient becomes oldest at timestamp `j+32`, every intervening V flush uses the original V code and the one residual remains outstanding. On the recipient flush the encoder would apply its single head residual and route the new residual again. This screen makes **no** V-code or residual update: selection and visit scheduling are the only measured operations. At `t256` a new recipient is selected but remains unflushed/recent in all 64 head-window streams; its debt is pending, not a current-query correction.

The source `i` is always in K2 because the chunk containing `i` ended by `t=i+32`. The selection needs no predictive key and no extra key retention. Source and candidate address use `(position−1)//32` and `(position−1)%32` for K2; only positions beyond `32*chunk_count` address recent BF16 K. K2 decoding uses the recorded 1,024-B two-bit row-major chunk digits and 512-B FP16 per-channel `(origin,step)` fields; BF16 recent is shifted to FP32. Subtractions and squares are FP32, with FP64 sum for deterministic distance comparison. [`screen.py`](screen.py) hashes each existing source NPZ and K array against source receipts, binds the original manifest and per-head original chronological event logs, consumes the 8 K events and 224 V events per head in timestamp order, and replays K arrivals. No K value is read before arrival or replaced with its eventual chunk code. The first route is at `t33`. [`summary.json`](summary.json) pins every train source/K/manifest/event and ledger SHA; [`train-*.json`](train-0.json) preserve the decisions, selected-key diagnostic hashes, completion drift and endpoint snapshots.

## Geometry and aging

| Quantity over eight train windows, eight KV heads | Observed |
|---|---:|
| V flushes / routes / skipped | 14,336 / 1,037 / 13,299 |
| Non-immediate choices; wait mean / median / maximum | 908 / 1,037; 14.45 / 13 / 32 V flushes |
| Eligible younger-token appearances at active decisions | 33,184 (`1,037×32`); each head's union spans positions 2…256 |
| Paired selected vs successor squared-distance sums | 317,522.58 vs 782,742.99 |
| Completed targets / pending at end | 973 / 64 |
| Completed targets whose K changed by own V flush | 367 / 973 |
| Completed target selected vs at-target-flush distance sums | 298,840.03 vs 320,603.24 |
| At `t128` before V flush: changed pending target keys; distance selected → current sum | 60 / 64; 19,110.30 → 22,353.94 |
| At `t256` before V flush: changed pending target keys; distance selected → current sum | 55 / 64; 17,244.63 → 19,883.86 |

The endpoint rows inspect the **then-current K** for each pending target, including targets not yet due to flush (4 due at `t128`, 9 at `t256`). Selection's key digest and selected scalar distance are diagnostic receipts only. The source key is re-read from the unchanged old K2 chunk when checking drift; the target is re-read from its causal K representation at the endpoint or own V flush. A target initially BF16 may become K2 when its chunk ages; no static selection-distance certificate survives that transition. The nearest-vs-successor comparison is paired at one identical active source/time, not the eventual post-aging distance or a comparison over different visited sets. Detailed waits, per-route distances and both endpoint snapshots are in the ledger.

## Paid boundary

Only the route recipient `u16` per KV head (16 B total) is new persistent *routing* identity; the proposed encoder already carries one full layer FP32 residual `8×128×4 = 4,096 B`, not one residual per skipped/waiting V token. No extra persistent K or source array is allowed. A straightforward streaming decision needs a 512-B decoded source and one 512-B candidate per active head, plus a scalar FP64 distance/best-index, 32 candidate comparisons and 32×128 FP32 subtractions/squares plus FP64 accumulation. The exact eight-window route decisions perform **34,221** K vector address/read/decode operations: 19,449 K2 and 14,772 BF16; conservatively rereading the 512-B shared channel fields for *each* K2 vector costs **14,361,888 B** total (622,368 B packed digits + 9,957,888 B fields + 3,781,632 B recent BF16). There are **4,247,552** coordinate distance subtractions and squares (`1,037×32×128`), with up to that many FP64 accumulation steps. The key decodes additionally convert 19,449×256 FP16 fields and 14,772×128 BF16 coordinates to FP32; the packed digit extraction/decode performs 19,449×128 coordinate operations. Sharing field loads within a scan could reduce reads, but is not credited here. Chunk/position address computation is 34,221 lookups; a V flush checks the recipient identity even when inactive. Key read/decode and distance work occur only on the 1,037 active scans. The separate drift audit adds 2,202 causal packed-K vector reads (1,197,888 B with per-vector fields) and 1,101 distance evaluations, billed in `summary.json`; it is **not** a required online routing operation.

Existing K/V cache, K/V source arrivals, original V quantizer's work on all V events, residual updates on visited events, source projections, and downstream query work are not replaced or discounted by this geometry screen. Selected-key SHA and numerical ledger records are offline evidence, not resident encoder fields. A recipient selected at final flush still holds a pending full residual and cannot correct that final query. No native latency or output-quality claim follows.

Recreate from already-held sources/events (one process per window, each under 55 s):

```sh
cd /path/to/workspace/projects/kelana
for w in 0 1 2 3 4 5 6 7; do OPENBLAS_NUM_THREADS=1 python research/isa-quantization/key-local-value-transport/screen.py train "$w"; done
OPENBLAS_NUM_THREADS=1 python research/isa-quantization/key-local-value-transport/aggregate.py
```
