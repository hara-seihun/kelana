# Does one frozen cache predict the other's temporal labels?

The paid Q/K key cache and rank-28 narrow-value cache come from the same token, so a joint encoder might spend fewer bits than two separate ones. On the pinned Qwen3-0.6B layers 0 and 14, a conditional two-table Huffman code barely exploits that relationship. At a 32-key restart, the best tested layer-0 condition saves 886 bytes across 1,024 held tokens in the V stream. The layer-14 conditions all increase the charged rate. None beats the existing separately coded cache at the same access boundary.

This closes a cheap frozen-code side-information route, not the possibility of jointly learned K/V coordinates. In particular, the trained rank-28 V coordinates and selected 32 K coordinates were fitted independently. A common producer could give their labels much more mutual information, but it must preserve both causal scores and post-O responses while paying for its producer and the sequential read dependency.

## Code and observation

The original-producer captures contain eight separate 256-token train windows and four previously inspected validation windows. The key uses the paid binary Q/K factors, group key affine, selected post-RoPE planes, centers and signed-nibble steps from the [key-score entropy study](../key-entropy-direct/README.md). The value uses the paid rank-28 V/O image and fitted nibble steps from the [value entropy study](../value-entropy-ceiling/README.md). Both use exactly their prior code labels. One K group has 32 codes and one V group has 28 codes per token.

Within each restart block, let `dK[t,g,j]` and `dV[t,g,j]` be signed code differences. I tried two binary side conditions, each available from the *other* cache's same-token difference. `same-coordinate` tests whether its coordinate `j mod side_width` is zero; `group-quiet` tests whether fewer than half its group coordinates changed. The encoder and decoder select one of two train-fitted canonical Huffman tables for each group. All 31 possible differences have positive training pseudocounts in every table, so a held code never requires an escape. The side cache must be decoded first. K-before-V and V-before-K are separate alternative schedules, not two independent savings that can be added.

For every key after a block anchor the target stream stores an independently addressed Huffman-coded row. Each row is byte-aligned and has one length byte. A block stores an absolute nibble anchor, 16 bytes for K or 14 for V, and a four-byte offset. Eight unconditional tables cost 155 bytes/layer; sixteen conditional tables cost 310. Those bytes are amortized over the same 1,024 held tokens. The encoded payload is the sum of `ceil(sum_j code_length[d_j, condition]/8)` over every row, group, block and window. Canonical codes with the stored lengths attain that byte count exactly. All anchors, offsets, lengths, table bytes and alignment are in the totals. The bitstreams are variable length and the original suffix-mass V or two-head score K observer would read the decoded differences directly; the real-arithmetic telescoping identities from the two parent reports still apply. This experiment does not run their consumers, claim FP32 bit identity, or change weight BPW and model quality.

| Target | Restart | Unconditional bytes/1,024 tokens | Best conditional bytes | Side rule | Saved bytes |
| --- | ---: | ---: | ---: | --- | ---: |
| K layer 0 | 32 | 127,635 | 127,347 | group-quiet V | 288 |
| V layer 0 | 32 | 117,979 | 117,093 | group-quiet K | 886 |
| K layer 14 | 32 | 108,053 | 108,221 | group-quiet V | -168 |
| V layer 14 | 32 | 116,003 | 116,120 | same-coordinate K | -117 |
| K layer 0 | 256 | 126,651 | 126,358 | group-quiet V | 293 |
| V layer 0 | 256 | 117,123 | 116,225 | group-quiet K | 898 |
| K layer 14 | 256 | 106,474 | 106,639 | same-coordinate V | -165 |
| V layer 14 | 256 | 115,117 | 115,212 | group-quiet K | -95 |

The best layer-0 group-quiet V rule saves payload on all four held windows, 279, 168, 334 and 260 bytes, before its extra 155 table bytes. Its train conditional mutual information is only 0.0365 bits per V difference. On layer 14 the same statistic is 0.0027 bits; the K condition has 0.0002 bits. Byte rounding consumes most of that tiny gain. The coordinate-local rules are still weaker. See the JSON for each group's train information, code lengths and held per-window payload.

At 32-key restarts the unconditional K layer-14 row count reproduces 108,053 bytes in its parent, but its conditional count grows to 108,221. Layer-0 K's best 124.36 bytes/token loses to the static mixed 112. Layer-0 V's best 114.35 bytes/token loses both static nibble 112 and its group-serial Huffman 103.36. Layer-14 V's best 113.40 loses static nibble 112 and group-serial Huffman 101.42. At a 256-key restart even the best conditioned V layer-0 row layout uses 113.50 bytes/token, above static nibble and the parent's 104.13-byte coordinate layout. The serial group layout is not interchangeable with parallel row decoding, but conditioning adds a mandatory other-cache dependency to either one. The group-quiet predicate also costs a 28- or 32-coordinate changed-label count per token/group. No native reader, append path, occupancy result or whole-model loss was measured.

The useful next question is whether a jointly trained K/V producer creates a shared low-entropy event that predicts *both* causal score and post-O value response, and whether its saved cache bytes and direct consumer work pay for decoding that event before either stream. Merely fitting more tables to these independent frozen coordinates is a weak bet.

## Reproduce

The code takes about a few seconds per layer on the installed CPU PyTorch environment. Source, pinned model, capture, paid images and selected-fit files are SHA256-identified in `/path/to/workspace/data/kelana-subbit/joint-kv-entropy/layer{00,14}.json`. The JSON keeps train code lengths and all per-group and per-window byte counts.

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/joint-kv-entropy/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/joint-kv-entropy/measure.py --layer 14
```

No GPU reservation, Bonsai source, installed executable, service or serving default changed.
