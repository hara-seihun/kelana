# Sharing an integer value dot between GQA heads

Two Qwen3-0.6B query heads read the same paid 28-coordinate signed-byte value row, but use different causal attention masses. The [paired-head transfer study](../value-transfer-commutation/README.md) correctly rejects replacing one attended value with the other's. There is still an exact middle ground: compute one head's integer value dot, then dot the *signed difference* of their count rows with the same packed value codes. The second head's result is their sum. No per-key value is reconstructed, no code or stored cache byte changes, and the original 4,095-unit probability map is preserved.

Let `a_k,b_k >= 0`, each summing to 4,095, and `q_kj` be one group's signed-byte value code. For every coordinate `j`,

```
 A_j = sum_k a_k q_kj
 B_j = A_j + sum_k (b_k-a_k) q_kj.
```

The first dot uses an unsigned byte `min(a_k,255)` plus the existing sparse `a_k-255` corrections. The difference uses a signed byte `clip(b_k-a_k,-128,127)` plus corrections `b_k-a_k-clip(...)`. Each correction list is bounded at any context: at most 15 first-head keys have `a_k>255`; since `sum |b-a| <= 8190`, at most `floor(8190/128)=63` difference keys exceed the signed-byte range. The first complete integer response is bounded by `4095*127=520065`, and the difference by `8190*127=1040130`, within int32. Both heads then take their own paid FP16 coordinate scales and O columns, as before. This is an integer identity followed by the same real-valued scale/output map; a different FP32 reduction schedule need not reproduce old float bits.

On four previously inspected 256-token original-producer validation windows per layer, using exactly the parent's prefix-rounded counts and paid signed-byte cache:

| Layer | Two dense low-byte dots, key uses | First dense plus sparse signed difference, unpadded / 4-key / 32-key | Scalar correction keys, existing / difference reader | Positive equal counts / two-head positive uses |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 2,105,344 | 1,774,660 / 1,787,000 / 1,904,608 | 38,246 / 70,938 | 20,608 / 1,009,996 |
| 14 | 2,105,344 | 1,759,387 / 1,771,756 / 1,886,592 | 40,770 / 56,946 | 85,480 / 1,330,127 |

Thus the ideal first-byte product cut is 15.7%/16.4%, still 9.5%/10.4% when each group's difference list rounds to 32 keys. Each listed key use entails 28 signed-byte coordinate products, or 32 if padded. The extra scalar corrections are real: a signed difference can exceed 127 even where neither original head count exceeds 255. The first-head dot is dense and the second list must be constructed. These counts exclude softmax, count prefix, list compaction, scattered cache access, scales and O. Group-shared code bytes and cache traffic already belong to both heads; the identity does not halve physical value-row reads. No native time or full-model loss is implied.

There is also a tight reason not to pursue a *sparse common positive base* on these frozen counts. If a nonnegative `u_k` is shared and both nonnegative residuals are read separately, with `u_k <= min(a_k,b_k)`, a key with unequal positive counts still needs two products, one for `u` and one residual. A key with equal positive counts can save exactly one. When only one count is positive, no product is saved. Taking `u=min(a,b)` attains the minimum sparse product count, `sum(1[a>0]+1[b>0]-1[a=b>0])`, in this three-stream nonnegative grammar. The observed maximum sparse-product saving is just 2.04%/6.43%; the shared mass amounts to 10.25m/20.09m units but mostly sits at *unequal* counts. This bound does not cover a signed-difference reader, joint codebook changes, other linear combinations or a learned shared-attention map. It explains why a dense first dot plus one *compacted signed difference* is the only frozen-count branch with a worthwhile logical product margin.

The [receipts](/path/to/workspace/data/kelana-subbit/value-cohead-mass-share/) bind the script, pinned model, original-producer capture, parent integer-count hash and every window's counts. The CPU code checks both the signed-byte split identity and the nonnegative shared-base product identity on every key. This is a cost construction and a sparse-family bound, not a GPU speed result; no runtime executable or service changed. A native experiment is warranted only if a paired-head fused count builder can compact the signed difference without another full read/sync and schedule its 63-entry worst-case correction list. Compare its complete count/dot/correction/scale/O reader at occupied context against two-head key-wise sparse overflow and the grouped-label cache. If compaction costs more than the 9–10% padded low-dot margin, fit shared causal attention *together with* the V/O codes instead of squeezing these frozen counts.

From a Kelana writer checkout, each CPU panel is a bounded command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-cohead-mass-share/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
