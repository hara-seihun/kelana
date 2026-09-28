# Complete real-route census closes frozen Q4 gate/up fragment sharing

On the pinned Qwen3.6-35B-A3B installed GGUF, **all forty layers** and both disjoint actual 64-token route captures, the most generous same-K, same-byte 4-byte Q4_K gate/up code-fragment reuse saves at most **114,356.375 code bytes/token** on held routes: **0.00435446%** of the conditional 2,626,187,904-byte complete one-read weight stream. Layer 0 contributes **99.8547%** of these repeated uses. At eight bytes the held ceiling is **13,282.125 bytes/token / 0.000505757%**, 99.9209% from layer 0; at sixteen bytes it is 345 bytes/token, all at layer 0. **No entire 144-byte Q4_K block repeats within any of the 5,120 observed eight-expert layer/token routes in either split.** This extends the prior [three-layer synthetic-route study](../code-sharing/README.md) to every actual layer and route. The layer-0 byte coincidences do not generalize to the complete model.

| Frozen same-K operand grammar | Train repeats across 40 × 64 × 2 banks | Held repeats | Held optimistic saved bytes/token | Held fraction of complete one-read bytes |
| --- | ---: | ---: | ---: | ---: |
| 4-byte low-code fragments | 1,830,293 | 1,829,702 | 114,356.375 | 0.00435446% |
| 8-byte low-code fragments | 112,586 | 106,257 | 13,282.125 | 0.000505757% |
| 16-byte low-code fragments | 1,687 | 1,380 | 345 | 0.0000131369% |
| Full Q4_K blocks, including all metadata | 0 | 0 | 0 | 0 |

## What is bounded

At each fixed gate or up code-fragment position of a selected route, sorting eight 4-, 8- or 16-byte low-nibble labels leaves `8 - number_of_distinct_labels` surplus uses. One identical code fragment could in principle share its activation-dependent integer dot for those surplus experts **if** its activation operand and all omitted high-bit/scale handling permitted it. We grant zero routing, lookup, storage, synchronization and decoder costs, and count even repeats with different quantization metadata as savings. Each reused n-byte fragment receives an optimistic n-byte logical code-stream saving, not a measured physical DRAM saving. This is a finite upper bound in the *same-K unchanged-code direct fragment reuse grammar*; it neither bounds an ISA program on newly learned joint codes nor a whole-sum observation that never forms those dots. Full-block identity would give a stronger exact same-weight candidate but occurs zero times on these routes. The existing grouped native expert consumer is the control, not a proposed grouping improvement.

All 80 inspected tensors are Q4_K and have 4,096 144-byte blocks per expert, 128 low-code bytes per block. The scanner compares the last 128 bytes of each block at matching block/fragment offsets across the eight actual selected expert IDs. It reads the real model via the inventoried GGUF offsets and verifies its header SHA-256; it hashes both route files for each layer and verifies their ID range and uniqueness. The 64 train and 64 held token sequences are separate real-text native callback captures; the result does not extrapolate to all possible routes or generated-token trajectories. The complete 2.626-GB one-read denominator includes nonexperts and all selected routed banks, not only Q4 gate/up; code reuse does not remove Q4 metadata or down/expert work. Neither these logical-byte fractions nor zero full-block duplicates are whole-model TPS measurements, and no model, runtime, service or GPU state changed.

## Evidence and next question

[The aggregate receipt](/path/to/workspace/data/qwen-moe/code-sharing-all-route/receipt.json) binds the pinned model hash, inventory/header, actual producer-capture receipt, scanner and aggregator hashes and twelve individually hashed source/route shard receipts. Each shard records all 64 per-token counts per split, layer and bank, source offsets and route-file hashes. Recompute without a GPU from the Kelana root:

```sh
for start in 0 4 8 12 16 20 24 28 32 36; do
  stop=$((start+4))
  OPENBLAS_NUM_THREADS=1 python3 research/moe/code-sharing-all-route/measure.py \
    --start "$start" --stop "$stop" \
    --out "/path/to/workspace/data/qwen-moe/code-sharing-all-route/layers-$start-$((stop-1)).json"
done
python3 research/moe/code-sharing-all-route/summarize.py
```

Use shards of at most three or four layers within a short attended command; the 10-layer and final four-layer trials exceeded the 55-second foreground budget without producing a receipt. The retained twelve successful shards cover each layer exactly once. The stronger next question is a **changed** paid expert code/activation coordinate trained on broad real routes and selected by disjoint complete-model language loss, with direct packed-consumer timing against native grouped MMQ/MMVQ. Another frozen-byte dictionary cannot close the Q8/expert physical-time gap; independent native graph-on complete-head timing remains useful.
