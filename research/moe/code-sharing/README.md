# Exact packed-code reuse on Qwen routed experts

The pinned GGUF has a tempting layer-0 coincidence: many *four-byte* Q4 gate/up code fragments recur at the same position in different experts. It does not turn into a useful identical-operand route. Among sixteen seeded uniform eight-of-256 selections, matching fragments account for only 1.75% of layer-0 gate and 1.48% of up four-byte uses. At eight bytes those figures fall to .209% and .169%; at sixteen, .0047% and .0038%. In the inspected middle layer almost none match even at four bytes. These are generous code-only matches, **not** equal quantized contributions: metadata, high bits and possibly other operand bytes still differ.

This closes one cheap exact reuse proposal: dictionary or common-subexpression lookup of *unchanged* Q4/Q5/Q6 code fragments across selected experts. It does not bound other packed instruction compositions, learned shared labels, cross-token reuse or approximate recoding. The useful next question is a jointly designed expert code and shared consumer on actual routes and producer activations, compared against the grouped HIP implementation, not a dictionary over frozen bytes.

## Observation and conditional bound

For a fixed tensor, block number and byte fragment, sort its 256 expert labels. If `c` distinct labels occur among eight selected experts, at most `8-c` of those eight identical-code operand uses can be replaced by one lookup or dot **in the direct identical-byte reuse grammar**. This is a combinatorial upper bound on that grammar's eliminated code-fragment uses, even granting zero cost for dictionary construction, selection, decoding, routing and sharing, and granting that equal low-bit bytes suffice despite differing scales and Q5/Q6 high bits. It is not an ISA-independent lower bound on the whole weighted expert sum. A fragment's positional identity ensures the *putative* shared input is the same token coordinate; a repeated code at another position would not license a shared activation-dependent result.

The script reads the actual packed expert banks through GGUF header offsets and 32-byte alignment, checks the inventory header SHA-256, then compares code fragments independently at each fixed block/fragment coordinate across all 256 experts. Q4_K blocks are 144 bytes, Q5_K 176 and Q6_K 210. It discards scales/mins and compares the 128-byte low-nibble plane, deliberately favoring collisions. It separately compares full physical blocks, including metadata and high bits. The source-layout contract is `ggml-common.h` in the pinned HIP checkout. Sixteen uniform routes are generated with NumPy seed 20260923, without replacement. They are synthetic, not Qwen router traces. Each receipt records exact IDs, every fraction, source/inventory/header hashes and the pinned whole-file model SHA-256 from acquisition. The source-hash and pinned model SHA are provenance, not a fresh whole-file rehash in each invocation.

| Layer, bank | Full 256-weight block duplicates | 32-byte low-code duplicates / total | 16-byte low-code duplicates / total | 8-byte mean eight-route reusable fraction | 4-byte mean eight-route reusable fraction |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 down Q5_K | 0 | 0 / 1,048,576 | 0 / 2,097,152 | 0 | .00012% |
| 0 gate Q4_K | 0 | 26 / 4,194,304 | 15,686 / 8,388,608 | .20920% | 1.75472% |
| 0 up Q4_K | 0 | 20 / 4,194,304 | 12,708 / 8,388,608 | .16924% | 1.47671% |
| 19 down/gate/up | 0 each | 0 each | 0 each | 0 each | 0 / 0 / .00001% |
| 39 down/gate/up | 0 each | 0 each | 0 each | 0 each | 0 each |

The four-byte same-position duplicate count over *all* 256 experts is much larger at layer 0: gate 6,191,224 and up 5,889,012 among 33,554,432 fragment uses per bank. That number is misleading for a token that only sees eight experts. At layer 19 the corresponding counts are 9 and 4, and at layer 39 they are 79 and 25; neither middle nor final inspected layer admits a useful static common-byte reader. These are three sampled layers, not a claim about all forty.

Even the layer-0 eight-byte gate upper bound removes fewer than one in 477 code-fragment uses before indexing and gathering. A per-fragment label consumes at least one byte for any dictionary with more than one entry, already 12.5% of an eight-byte fragment's payload before its dictionary and metadata. That simple fixed-width index cannot repay a .209% *route-local* reuse fraction if it replaces every eight-byte fragment; selective labeling retains the original data plus exceptional metadata and does not offer a free global rate reduction. The four-byte case has higher match rates but a one-byte label is 25% of its bytes. These are storage-accounting statements within the named grammar, not native timing claims. No engine changes or GPU measurements resulted.

## Reproduction

```sh
OPENBLAS_NUM_THREADS=1 python3 research/moe/code-sharing/measure.py --layer 0 --output /path/to/workspace/data/qwen-moe/code-sharing/layer0-256.json
OPENBLAS_NUM_THREADS=1 python3 research/moe/code-sharing/measure.py --layer 19 --output /path/to/workspace/data/qwen-moe/code-sharing/layer19-256.json
OPENBLAS_NUM_THREADS=1 python3 research/moe/code-sharing/measure.py --layer 39 --output /path/to/workspace/data/qwen-moe/code-sharing/layer39-256.json
```

The three JSON receipts are the raw measurement record under the [Qwen data owner](/path/to/workspace/data/qwen-moe/README.md). The selected model and its GGUF inventory are owned by [Bonsai's Qwen report](/path/to/workspace/projects/bonsai-halo/docs/qwen-moe.md). The CPU comparison changes neither the arithmetic contract nor the installed executable. An exact native consumer would still have to preserve Q4_K scale/min handling, high-bit reconstruction where applicable, and floating-point reduction order if it claimed bit identity.
