# Frozen K/V rate exchange at the complete layer observer

**Answer:** At approximately the same paid causal peak, allocating the extra code bits to **V** rather than K wins on this eight-state held observer: frozen **K2/V4** has pooled complete post-O squared error **0.000713499** versus **0.001547977** for **K4/V2** (same original teacher denominator **271.317982467**). K2/V4 wins **5/8** individual states; the result is mixed, notably held-1/t256 strongly favors K4/V2. Both exchange arms improve upon K2/V2 (**0.003068937**) but fall far short of K4/V4 (**0.0000426253**). The K2/V4 advantage is 2.17× in pooled SSE, not an all-context or same-bit monotonicity theorem.

The arms were frozen **before scoring**, by copying exact chronological events and BF16 recent arrivals: **A = K2 from [`kivi-two-bit-causal`](../kivi-two-bit-causal/) + V4 from the original full-layer KIVI4**; **B = K4 + V2**. KIVI4 KV group0 is from [`kivi-causal-cache`](../kivi-causal-cache/), groups1–7 from [`skvq-global-gqa`](../skvq-global-gqa/). No code, field, grouping, recent length, setting or quantizer was refit. The source method is a **named KIVI adaptation** (Liu et al., ICML 2024; official `jy-yuan/KIVI@876b4d2`), not a new algorithm or SOTA claim. K groups are per-channel across32 arrivals, V groups per-token across four32-coordinate groups; unsigned min/max codes and FP16 origin/step, BF16 recent vectors. This Qwen CPU adaptation rounds post-RoPE K to BF16 for the cache while the teacher preserves original FP32 post-RoPE K; V is BF16 projected, and Q and full 1024×2048 O are unchanged. K2/V2 and K4/V4 have different precision at the stored digits but share their source, chronology, Q and original complete teacher. Neither native GPU latency nor full-model generation was measured.

## Paid eight-head state and chronology

Every insertion is read for its query *before* flushing. At t256, each head has seven K chunks (224 quantized keys), 32 recent K, 223 quantized V, 33 recent V. Post-query it has eight K chunks, 224 quantized V and 32 recent V. At t128 the corresponding counts are 3 K chunks, 32 recent K, 95 quantized V, 33 recent V. K chunks are 1,536 B (2-bit) or 2,560 B (4-bit), V tokens 48 B or 80 B, recent vectors 256 B. The 2-B common position count and static shared Q/K/V/O/gamma are outside both ledgers. Logs and receipts are audit evidence, not simultaneously retained inference cache.

| Eight KV heads | A K2/V4 | B K4/V2 |
|---|---:|---:|
| t128 preflush / peak through t128 | 230,784 B | 231,040 B |
| t256 preflush / peak through t256 | **361,856 B** | **362,112 B** |
| t256 postflush final | 307,200 B | 315,392 B |
| t256 preflush K codes + fields | 57,344 + 28,672 B | 114,688 + 28,672 B |
| t256 preflush V codes + fields | 114,176 + 28,544 B | 57,088 + 28,544 B |
| t256 preflush K recent + V recent | 65,536 + 67,584 B | 65,536 + 67,584 B |

The **256-B peak difference** is real and retained: these are nearly equal-rate arms, *not* an equality manufactured by dropping fields/recent buffers. They differ by 8,192 B after the t256 flush. The general [chronology/rate theorem](../kivi-two-bit-causal/RATE.md#exchanging-key-and-value-precision-is-not-an-exactly-equal-byte-swap), proved in `Kelana/KVPrecisionExchange.lean`, explains this for every horizon: with equal K group and V recent thresholds, quantized K count is never below V count, so exchanging the larger code allocation onto V never increases this payload ledger. It makes no quality prediction. Both have the identical post-query K32/V33 flush schedule, with 64 K and 1,792 V flush events across eight heads per256-token window. [`results.json`](results.json) records code, field and recent ledgers separately at t128, t256 and final.

## Complete full-O held scores

These are SSEs, not averaged per-state ratios. All four streams × both held prefixes use their **same original Q, teacher, full O**, with KIVI2 and KIVI4 strong control receipts reused from [`kivi-o-aware-values@90357ed`](../kivi-o-aware-values/) and pinned in [`controls.json`](controls.json). Their full256-query panel scores are **not** substituted for retained-state scores. [`controls.py`](controls.py), called by replay and aggregation, verifies the copied control fields against the exact unchanged owner-receipt hashes; its hash-only check requires no output recomputation.

| Held stream / prefix | K2/V4 SSE | K4/V2 SSE | K2/V2 SSE | K4/V4 SSE |
|---|---:|---:|---:|---:|
| 0 / 128 | .014293690 | .005348572 | .023815413 | .000350813 |
| 0 / 256 | .011871515 | .016981585 | .033375713 | .000657315 |
| 1 / 128 | .041487212 | .113957417 | .219059882 | .003403129 |
| 1 / 256 | .030730369 | .002762324 | .035663173 | .000214812 |
| 2 / 128 | .016614791 | .008168933 | .027687015 | .000559700 |
| 2 / 256 | .012962948 | .055243345 | .104052115 | .001370312 |
| 3 / 128 | .036972421 | .071456871 | .166549611 | .001569803 |
| 3 / 256 | .028652069 | .146074853 | .222455007 | .003439130 |
| **Pooled SSE** | **.193585015** | **.419993901** | **.832657928** | **.011565013** |
| **Pooled SSE / teacher²** | **.000713499** | **.001547977** | **.003068937** | **.0000426253** |

K2/V4 beats K4/V2 at five individual points and in the pooled numerator. The original [KIVI2 error decomposition](../kivi-two-bit-error-directions/) identified V and interaction as large contributors, but that attribution alone did not determine this exchange; these are newly measured composed images. A dense O-aware V recoding improved K2/V2 by 8.50% on the same states but paid an additional **524,288-B prepared Gram**, so unchanged K4/V4 at **419,200-B peak** dominates that realization. The present exchange uses only donor KIVI codes and fields, no prepared Gram. K4/V4 has better quality but costs 57,344 B more peak than K2/V4, so this observation is a genuine intermediate rate/quality point, not dominance over the four-bit control.

## Evidence and reproducibility

[`build.py`](build.py) emits two actual timestamped composed event logs, final images and paid t128/t256 images **per KV head per stream** plus 256 pre/post SHA/byte receipts. It never loads Q, teacher, O or checkpoint arrays. It checks both donors' entire every-prefix state hashes, not only the selected arm. [`replay.py`](replay.py) independently parses all donor logs and arrival BF16 bytes, verifies both donors and both compositions at **every** pre/post prefix, checks each emitted code and FP16 field against only source BF16 available at its flush, decodes selected K/V fields and recent bytes at every prefix, checks held paid images and final images, and computes full 16Q/8KV softmax/V/O only at the retained eight states. It loads Q/teacher/O solely from [`kivi-two-bit-dot-native`](../kivi-two-bit-dot-native/) and checks their SHA; no checkpoint forward, source arrays, GPU or missing-Q regeneration. Its CPU query arithmetic uses float32 Torch bmm/softmax/bmm/matmul, decoded BF16 O to float32, and float64 SSE; the common denominator is the successful KIVI4 control receipt (fresh teacher sum agrees within 4×10⁻⁷). Literal replay expands decoded K/V (two 8×256×128 float32 arrays at t256, 2,097,152 B transient) and uses scratch for attention/output; this is **not** represented as the paid cache or a native packed-consumer timing claim. Producer extrema/code assignment, FP16 fields, flush and online decode/read work are real costs.

In this directory, with `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python`, run `build.py W` for W=0…3, then `replay.py W`, then `aggregate.py`. Each call is sub-minute. Builder and reader have independent decoding/field logic; freeze all builders before evaluating any retained score. The manifest, per-state results, images and logs are committed evidence. Parent review corrected the builder's V-timestamp assertion parentheses; the independent replay had already checked every event timestamp correctly. No candidate bytes or successful observations were regenerated for that guard repair. The parent research catalogue/synthesis is owned by the coordinating agent.
