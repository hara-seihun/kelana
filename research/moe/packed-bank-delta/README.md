# Exact cross-expert deltas on routed Qwen images

A parent image and an XOR delta are a plausible way to share a packed expert across the eight experts selected by one token. On the pinned layer-0 GGUF bank, this particular exact route-conditioned format loses to compressing each image independently. The result holds on the first four tokens of each of the two disjoint captured prompts, for every one of the 32 selected-expert instances per split and each of its seven possible co-routed parents. It is a measured negative for the stated codec, not a bound on learned labels or direct packed computation.

The source reads all physical bytes of the Q4_K gate/up and Q5_K down image for each selected expert, including block metadata. Each image is compressed by zlib level 1. The alternative XORs that image with every other expert image in the same eight-expert route, then applies the identical zlib compressor. The favorable comparison gives each child its best parent for free, ignoring parent residency, indices, XOR instructions, decoding and scheduling. A separate one-parent star chooses the smallest total of compressed parent plus seven XOR deltas. All reconstruction bytes were checked by XORing the delta with the parent. The calculation uses the existing grouped runtime's real route IDs, but does not time that runtime or claim physical DRAM savings.

| Four-token split, 32 expert instances | Raw bytes, all three banks | Independent zlib | Best route star | Star excess over independent | Children for which any parent wins |
| --- | ---: | ---: | ---: | ---: | ---: |
| Train | 60,817,408 | 51,946,582 | 55,644,749 | 7.12% | 0 / 96 bank-images |
| Held | 60,817,408 | 51,617,515 | 55,400,071 | 7.33% | 0 / 96 bank-images |

The held independent image is 15.13% smaller than raw. The gate and up Q4_K banks individually compress from 18,874,368 to 14,428,672 and 14,432,612 bytes, respectively; the Q5_K down bank barely compresses, from 23,068,672 to 22,756,231 bytes. XOR deltas lose even with free parent availability. The best star still retains some of standalone compression, but it gives back 3,782,556 bytes over independent coding on held. Because **each** of the seven conditional candidates costs more than the corresponding independent child, no forest using these selected co-routed parents and this codec can save storage on the tested routes, even if its choice of roots and edges is optimal. This follows by replacing every delta edge with its strictly cheaper independent child encoding. It does not hold for a different compressor, expert layout, route or learned code.

Standalone lossless entropy coding has a conditional storage opportunity here, but zlib is not a direct matrix operand. The complete one-read-per-token expert stream is 611.516 MB against 2,626.188 MB of modeled whole-model weights. Extrapolating the held sample's 15.13% *image* saving to all experts and layers would remove at most 92.5 MB, or 3.53% of that modeled stream, before decoder bytes, instructions, metadata and cache effects. That extrapolation is a scenario, not a measured model-wide rate. The existing [same-position code comparison](../code-sharing/README.md) separately rules out useful *identical* Q4 fragments across selected experts; XOR coding is different and now has its own test. A better next construction must alter the weight labels and direct consumer together, or demonstrate a decoded standalone format whose materialized operand traffic costs less than it saves. Testing a larger frozen route set before any native codec is also necessary.

[Train](/path/to/workspace/data/qwen-moe/code-sharing/delta-train.json) and [held](/path/to/workspace/data/qwen-moe/code-sharing/delta-held.json) receipts retain all 8x8 compressed byte comparisons per route and bank, route and input hashes, source hash, pinned whole-model SHA and verified GGUF header hash. `measure.py` reproduces them without GPU:

```sh
python3 research/moe/packed-bank-delta/measure.py --split train --rows 4 --output /path/to/workspace/data/qwen-moe/code-sharing/delta-train.json
python3 research/moe/packed-bank-delta/measure.py --split held --rows 4 --output /path/to/workspace/data/qwen-moe/code-sharing/delta-held.json
```

This is exact reconstruction of the stored GGUF bytes, not a new numerical map or quality comparison. No native image, executable, selected weights or resident service changed.
