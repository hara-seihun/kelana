# One-byte directories for direct key-score microstreams

The four-row Huffman key-difference segments previously used two-byte lengths because the unconstrained train-fitted tree can assign 16 bits to a symbol. In the complete signed-nibble difference domain, four rows contain 128 symbols, so such a segment can take 256 bytes. It does not fit a one-byte length even though the largest observed layer-14 segment takes only 66 bytes. A length-15 prefix tree instead bounds **every** four-row segment by 240 bytes. Seven directory lengths per group and 32-key block shrink from 14 to seven bytes, with no change to the direct two-head integer score map or its maximum 128-symbol serial parser chain.

Eight Qwen3-0.6B train windows choose a total canonical prefix tree separately for each of eight GQA groups. The constructor examines uniform pseudocounts and chooses the least train-symbol-bit-cost tree whose maximum depth is at most 15. This is an explicit feasible code search, not a proof of optimality among all bounded-length trees. It changes three groups' trees at layer 14 and four at layer 0; the original tables otherwise fit. The same 155 bytes store the 31 five-bit lengths per group. An anchor, block offset, payload, byte alignment and seven one-byte segment lengths are all charged. The final segment ends at the next block offset.

| Frozen paid Q/K cache | Four rows, original two-byte directory | Four rows, bounded one-byte directory | Static mixed key cache | Eight rows, original two-byte directory | Eight rows, depth-7 one-byte directory |
| --- | ---: | ---: | ---: | ---: | ---: |
| Layer 0, bytes/token | 117.863 | 116.112 | 112 | 115.417 | 120.187 |
| Layer 14, bytes/token | 98.831 | **97.079** | 112 | 96.419 | 103.598 |

Four-row layer 14 saves 14.921 bytes/token against static mixed, up from 13.169. The table restriction itself costs almost nothing on these held windows: against the *counterfactual* original code with one-byte lengths, it changes the complete layer-14 image by only minus two bytes across 1,024 tokens and layer 0 by minus one. One byte is not a valid full-domain address field for that original code. Each of the four held layer-14 windows costs 24,791, 24,659, 25,055 and 24,749 bytes before the once-per-layer 155-byte table, all below the 28,672-byte/window static cache.

The same trick does **not** help eight-row segments. They hold up to 256 symbols. Guaranteeing at most 255 bytes forces depth at most seven, and the constrained train-fitted tree needs large smoothing pseudocounts. Its extra symbol bits overwhelm the three-byte-per-group/block directory saving, raising layer-14 rate from 96.419 to 103.598 bytes/token. Thus the native experiment should compare four-row one-byte segments to the unmodified eight-row two-byte option; neither uniform directory width nor parser depth alone orders their costs.

The semantic contract is the parent [direct K-score microstream](../key-entropy-microstreams/README.md): an absolute signed-nibble anchor followed by independently decoded signed differences. For any real prepared query `u`, `u·c_t = u·a + Σ_{r<=t} u·d_r` on every signed-nibble history. The two query heads dot decoded differences and scan scalar scores; no absolute key vector or int4 intermediate is needed. Changing the prefix tree only relabels its serialized differences. `measure.py` encodes and decodes every held segment and checks both integer score scans on first blocks. This is exact integer/real arithmetic, not bit-identical floating-point score order. Dynamic query preparation, two dots, parser lookup and append, scans, softmax, the paid K producer and model quality are unchanged and have no new native timing. Layer 0 still loses to the static mixed byte image.

The next bounded native panel can use the 97.079-byte layer-14 four-row stream and the 96.419-byte eight-row stream at identical frozen labels, measuring fused append, parser, two-head score and softmax against static mixed and fixed-width parallel score readers at occupied contexts. If decode work dominates the 14.921-byte margin, jointly train independently parsed key differences with their paid producer and causal consumer rather than shrinking a directory again.

Run from a Kelana checkout with the installed CPU environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-length-bounded/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-length-bounded/measure.py --layer 14
```

`/path/to/workspace/data/kelana-subbit/key-length-bounded/layer{00,14}.json` retain each window's complete byte bill, segment maxima, selected code lengths, stream hashes and source/model/capture/paid-image hashes. The four-row layer-14 largest observed segment is 66 bytes and the full-domain maximum is 240. No GPU, Bonsai executable, service or serving default changed.
