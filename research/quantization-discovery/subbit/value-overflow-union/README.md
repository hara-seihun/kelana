# Share narrow-value overflow rows across heads

The [one-dot signed-byte V reader](../value-mass-overflow/README.md) replaces its second dense dot with exact sparse corrections. Its correction list was counted per head. The two heads in a GQA group read the *same* 28-byte V code at a key, and all eight groups' codes live in one contiguous 224-byte cache row. Merging the exception keys before gathering changes neither the 4,095-count map nor its paid V/O image.

For query `s`, group `g`, head `h`, let `E[g,h] = {t : n[g,h,t] > 255}` and `e[g,h,t] = n[g,h,t]-255`. Scan the sorted union `U[g] = E[g,0] ∪ E[g,1]`; load each `q[g,t,:]` once and add `e[g,h,t] q[g,t,:]` to the corresponding head's 28 integer accumulators when that excess is positive. The dense dot still uses `min(n,255)`. Distributivity proves that both head responses equal the original full-count integer dot. Scaling and the paid post-O consumer stay as before. There is no FP32-bit-identity claim against floating attention.

Each head has at most `floor(4095/256)=15` exceptions, so `|U[g]|≤30`. Across the sixteen heads, at most 240 key/group pairs and 240 distinct keys need correction. A fixed 30-entry group list, or two 15-entry lists merged during the correction, suffices at any context. With contiguous 224-byte rows, a conservative cold-read upper bound is four 64-byte lines per distinct key, at most 960 lines/query. This is an upper bound on **extra correction reads**, not a cache-miss prediction: the preceding dense dot may leave those rows cached. The list builder must still inspect counts, although it can emit exceptions while producing the byte operand.

On the four previously inspected 256-token original-producer Qwen3-0.6B validation windows, the parent's exact count reconstruction yields:

| Layer | Head correction key uses | Group-merged 28-byte gathers | Same-key head overlap | Cold lines counted independently/head | Unique cold lines/query summed over panel | Largest group union/query |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 38,246 | 31,820 | 6,426 | 52,051 | 27,679 | 14 |
| 14 | 40,770 | 28,652 | 12,118 | 55,843 | 25,625 | 11 |

The union saves 16.8%/29.7% of independent 28-byte gathers. At 64-byte line granularity, merging within each group gives 43,545/39,805 counted lines, and coalescing the eight groups' addresses per query gives 27,679/25,625 distinct lines. Those are 46.8%/54.1% fewer than summing independent per-head lines, under a cold per-query model without reuse across queries. It does **not** lower the 1,070,888/1,141,560 correction integer products, nor does it reduce the first causal dot. It introduces a key-union and two-head mask selection. The CPU receipts hash the regenerated count tensor and parent image/count provenance; the sum of head exceptions matches the parent exactly.

This resolves a consumer-layout question: make the sparse correction workgroup own a GQA group rather than a head if the native implementation otherwise refetches the same 28-byte codes. A physical row is shared even across groups, but making one workgroup own all eight groups could cost synchronization and registers. Native timing must price count creation, union/compaction, one byte dot, correction, scaling and O against the matched two-dot reader at occupied contexts. A code cache row already warm from the dense pass could erase the cold-line advantage. Model quality and stored rate are unchanged, and no GPU or runtime code changed.

Run from a Kelana checkout with `OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-overflow-union/measure.py --layer 0` and again for layer 14. [Raw receipts](/path/to/workspace/data/kelana-subbit/value-overflow-union/README.md) retain each window and hash.
