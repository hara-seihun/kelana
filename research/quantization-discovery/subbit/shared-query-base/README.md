# Share a key-score dot across both GQA query heads

The two query heads in a Qwen3-0.6B GQA group read the same 32 signed-nibble key coordinates. A three-dot score program computes a signed-eight-bit base query against each key, then corrects the other head with **one signed-nibble dot of the difference between the two prepared queries**. It does not decode keys or reconstruct full Q/K rows. On the frozen paid Q/K observer, it comes much closer to the four-dot score than spending the same three dots on independently quantized heads.

| Layer | Two one-dot heads | Independent three dots | Shared three dots | Four dots |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .290584 | .281052 | **.278608** | .275431 |
| 14 | .362763 | .346220 | **.334929** | .332396 |

Numbers are teacher-to-candidate mean causal attention KL across both heads, eight GQA groups and four previously inspected 256-token validation windows, with original-producer inputs. Each group chooses its base head by eight separate train windows, independently for the shared and independent three-dot families. The shared arm beats the independent arm on all four held windows at both layers. The four-dot arm remains better, but the layer-14 shared arm recovers 91.7% of its KL reduction relative to two one-dot heads using three instead of four dot passes. Layer 0 recovers 79.0%. These are CPU score-map results, not native time, model loss or a quality-matched int4 win.

## Construction and contract

Let `c_t` be a 32-coordinate signed-nibble cached key, and let `a_h = q_h * s` be head `h`'s real query multiplied by the same stored key-step vector. For the selected base head `b`, quantize `a_b` to signed integers `u_b` in `[-119,119]` with its own dynamic scale `d_b`. Quantize `a_{1-b}-a_b` to integers `v` in `[-7,7]` with dynamic scale `d_delta`. Scores are

```
B_t = d_b * dot(u_b, c_t) / sqrt(128)
S_b(t) = B_t
S_{1-b}(t) = B_t + d_delta * dot(v, c_t) / sqrt(128).
```

Split each `u_b` as `lo + 16*hi`, with both digits in `[-8,7]`. Thus the base uses two signed-nibble dots and the difference uses one. All inner products are exact signed integers within int32: even the full base dot has absolute value at most `32*119*7=26,656`. Over real arithmetic, if the quantized vectors equal the prepared queries then both scores equal the original selected-key score. For finite query rounding, the non-base score error is the **sum** of the base and difference quantization errors, each bounded coordinatewise by half its own dynamic step; explicitly its absolute score error is at most `(d_b+d_delta)*sum_j |c_tj|/(2*sqrt(128))` when rounding is unclipped. This is a conservative per-key bound, not a teacher-loss bound. The key center cancels from exact causal softmax as before. FP32 additions and scale products need not reproduce a four-dot or floating-query score bitwise.

The independently quantized three-dot control picks, by train KL per group, which head gets the two-pass eight-bit query and gives the other one signed-nibble pass. Its key codes, steps, raw K normalization, causal rows and teacher scores are identical to the shared arm. The shared arm additionally subtracts 256 prepared query coordinates per token/layer and adds one base score for each of eight second-head/key pairs. Both use 512 step multiplies and 16 dynamic maxima/token/layer. With eight groups and two heads, the complete logical key-score work is 768 signed-nibble coordinate products/key/layer for either three-dot arm, against 1,024 for four dots and 512 for two. All retain the 128-byte/token/layer signed-nibble K cache, static step/center metadata, paid binary Q/K images and full raw K RMSNorm producer. One base score reused across heads also changes register lifetime and scheduling; native issued instructions, query preparation, cache reuse, occupancy, softmax and online latency are **unmeasured**.

Why it works here is visible before a teacher comparison. On held captures, the difference's mean max-coordinate magnitude relative to the second head is .834 at layer 0 and .418 at layer 14, averaged over groups and query rows. Its direct one-nibble dot has mean absolute same-code score error .223/.115, versus .303/.319 for a one-nibble second head. The difference has a much better four-bit dynamic range, especially at layer 14. A universal guarantee that two unrelated query heads have a small difference is not claimed.

## Evidence and next experiment

`measure.py` loads the frozen paid binary Q/K factors, original weights for teacher attention, parent signed-nibble key image and four validation/eight train captures. The two files at `/path/to/workspace/data/kelana-subbit/shared-query-base/layer{00,14}.json` contain per-group train/held KL, per-window aggregates, train-chosen heads, query geometry and SHA-256 of source, model, captures, factor images and parent receipts. The script checks the eight-bit digit split against each group's measured keys. Run a layer in the installed CPU PyTorch environment:

```sh
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/quantization-discovery/subbit/shared-query-base/measure.py --layer 14 \
  --output /path/to/workspace/data/kelana-subbit/shared-query-base/layer14.json
```

Next freeze the shared three-dot and four-dot maps on fresh quantized-producer text and compare attention/post-O and complete-model loss. If the three-dot quality survives, a native fused two-head score panel at occupied contexts should time three dots plus difference preparation against four dots, the one-byte K cache and BF16 selected-key scores. The same source programs never justify choosing a faster path from their product counts alone.
