# A cold page is not a hot ternary operand

The exact 16-KiB-page Qwen3-0.6B image saves **2,977,841 physical bytes** relative to the independently decoded 125,953,725-byte complete scale-page image, with unchanged 4.498337 held NLL. Does its page coordinate remain cheap when a consumer needs the code stream, rather than only when the image is stored?

`consumer_cost.py` preloads all 197 original and compressed images into host RAM and independently checks every one of the **7,360** pages against the original radix-243 bytes. In six alternating paired passes, both arms compute the same incremental CRC32 of all 119,196,989 code bytes (0x631c8788); the paged arm inflates each page before the same CRC. Another panel shuffles the pages and observes just their first code byte. All pages in this particular image are compressed; every access has an inflation boundary.

| Host CPU/Python/zlib panel, complete image | Raw median | Page median | Median paired excess |
| --- | ---: | ---: | ---: |
| Every code byte once, ordered pages | 22.76 ms | 315.33 ms | **292.48 ms** |
| First code byte of each of 7,360 shuffled pages | 2.97 ms | 303.43 ms | **300.79 ms** |

The full-stream CRC32 is identical in every arm; the shuffled first-byte CRC32 is also identical. For this concrete host consumer, keeping the decoded radix-243 hot image beats repeated page inflation decisively. At one cold query per page, approximately 119 MB is inflated to observe just 7,360 bytes. The page directory makes addresses independent; it does not make the information in a compressed page locally decodable. If a model uses this coordinate, decode once at image load and retain the raw hot codes, or design a genuinely direct page-local map that avoids this boundary. Do **not** substitute this CPU ratio for native GPU inference speed: it includes Python loop overhead and zlib, omits matrix arithmetic, scales, device transfer, cache traffic and code sharing across tokens. A native page decoder could have a different rate and register/scratch cost. The paid physical rate is a storage result, not an online bandwidth saving while the raw hot image is retained.

[The receipt](/path/to/workspace/data/kelana-subbit/ternary/fresh-duration32-code-page-16384/consumer-cost.json) records six raw paired samples per panel, executable source hash, compressed-image receipt and model-manifest hashes, every original/compressed matrix SHA-256, page counts and equal checksums. Reproduce on CPU:

```sh
python3 research/ternary/code-pages/consumer_cost.py --output /path/to/workspace/data/kelana-subbit/ternary/fresh-duration32-code-page-16384/consumer-cost.json
```

This is a measured negative for **cold direct zlib-page access on the complete saved image**, not a bound on all compressed computation. The next representational question is whether a page-local operator can consume code bytes *in their compressed labels* without reconstructing them, with a measured cost against the radix-243 hot reader. For ternary quality, the independent next question is coupled whole-model code/scale recovery on new training/selection text at a paid rate; this exact code coordinate cannot close the BF16 loss gap by itself. No GPU reservation, native executable or service changed.
