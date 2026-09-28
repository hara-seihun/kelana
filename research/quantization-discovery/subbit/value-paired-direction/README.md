# Head order after duplicate-label aggregation

The [paired-label reader](../value-paired-label-difference/README.md) first combines identical paid signed-byte V rows, then reads the two GQA heads with one unsigned-byte base dot and one signed-byte difference dot. Its original implementation chooses head A as the base. The earlier [direction study](../value-cohead-direction/README.md) chose the base on *ungrouped* keys; its correction counts cannot be transferred through label aggregation. This panel makes that choice on the grouped reader itself.

For each causal query and group, let `a_i,b_i` be the aggregated nonnegative counts, both summing to 4,095, and `c_i` the shared 28-coordinate signed-byte code. Singletons remain separate entries. With A first, evaluate `a` through `min(a,255)` and exact excess corrections; then evaluate `b-a` through `clip(b-a,-128,127)` and exact excess corrections. With B first, interchange A and B. Both expressions yield the same pair of *integer* responses on every conserved-count input; the proof is coefficientwise reconstruction, independent of code values. First-dot length, nonzero difference support, four-/32-key padding, histogram scatters and value-cache bytes are invariant under reversal. At most 15 first-count and 62 signed-difference corrections fit a fixed 77-entry list in either direction. Output scaling and paid O remain separate and may have a different floating reduction order.

In the restricted grammar of one complete base byte dot, one compact signed-difference byte dot and one scalar correction at every clipped entry, the minimum of the two correction counts is the per-query optimum. It is *not* a free program: it compares the two counts and routes the result to the original head's O map. The per-group head order can instead be fixed offline, but these four inspected windows are not an independent training split for selecting such an order.

Four separate, previously inspected Qwen3-0.6B original-producer 256-token validation windows per layer, eight groups and every causal query. The same 4,095-count rows, paid rank-28 code rows and exact integer response hashes as the paired-label parent are checked by the source. Entries below are correction **rows**, each with 28 scalar coordinate products, across 8,192 group/query rows. Dot uses are also rows, not GPU instructions.

| Layer | A first | B first | Per-query minimum | Further saving against B | B choices | First + 4-padded difference | First + 32-padded difference |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 76,826 | 69,010 | 64,960 | 4,050 | 5,013 | 1,093,568 | 1,213,880 |
| 14 | 56,946 | 56,055 | 51,215 | 4,840 | 2,939 | 1,771,756 | 1,886,592 |

Static B-first saves 7,816 correction rows on layer 0, more than the ungrouped direction study's 6,302, while duplicate routing and byte-dot work stay fixed. Adaptive ordering saves only another 0.370% of four-padded layer-0 byte-dot row uses, or 0.334% with 32-padding, *before* a per-query selector and output routing. Layer 14 has no repeated rows and reproduces the ungrouped panel. This is a measured negative for paying dynamic routing solely to cut overflow products, not a latency bound or a verdict on a learned head-coupled quantizer.

The next native experiment should fix B first in the grouped candidate and price fused causal append, count creation, duplicate routing, short difference list, byte dot, scalar corrections, scales and both O maps against raw signed-byte and E4M3 at occupied context. If correction count matters on hardware, try an offline per-group orientation with a separate train split before adding query-dependent choice. No GPU, model loss, executable or service changed.

[CPU receipts](/path/to/workspace/data/kelana-subbit/value-paired-direction/README.md) bind source, model, capture, paid code, count, parent and integer output identities. Reproduce from a Kelana writer checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-paired-direction/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
