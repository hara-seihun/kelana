# Paged coordinate streams do not buy an appendable V cache

The frozen rank-28 signed-nibble Qwen3-0.6B value cache has a 100.540 B/token independently parsed coordinate Huffman image at layer 14, but the packed image cannot append a new key without moving later streams. Its fixed no-overflow slots need at least 361.504 B/token at a 256-key restart. I tested the intermediate option: let each of 224 coordinate streams append into its own chain of small pages. This is a working exact code, not a byte count that ignores pointers or the mutable write cursor. It loses to the 112 B/token static nibble cache on both inspected layers.

Each 256-key block has a 112-byte absolute anchor and a four-byte page-arena offset. The first page of each coordinate has an implicit index; each allocated page holds `P` payload bytes and a two-byte next-page index, with `0xffff` as the terminator. The block also has 224 two-byte tail-page indices and 224 two-byte tail-bit cursors. Thus the header is 1,012 bytes per block, including the anchor, and appending a new label touches its current page, tail cursor and, on overflow, one link plus a newly allocated page. Old pages never move. A query follows the chain and parses the known number of canonical codewords; no stored stream length or terminator code is needed. Four entropy-ranked tables per GQA group, their bucket assignments and their 676 static bytes are exactly the preceding trained codec. The maximum number of pages over *any* signed-nibble history, derived from the preceding 16-state max-plus length bound, fits the two-byte indices for every reported block and page size.

The script appends all held codewords bit by bit, follows the links to decode them, and compares every recovered difference. The direct integer suffix-mass identity of the parent therefore remains available: `a Σm_t + Σ_{j>0} d_j Σ_{t≥j}m_t`, without reconstructing absolute values. A floating accumulator can round differently. No native reader or model loss is measured.

| Layer | Restart keys | Best payload `P` over every integer 1–255 | Complete B/token | Offline packed coordinate B/token | Static nibble B/token |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 32 | 17 | 171.093 | 112.600 | 112 |
| 14 | 32 | 17 | 170.072 | 109.799 | 112 |
| 0 | 256 | 23 | 125.219 | 103.422 | 112 |
| 14 | 256 | 23 | 121.898 | 100.540 | 112 |

The exact fixed-page sweep uses the observed bit length of **every** stream, not a mean length: for capacity `P`, the allocated count is `Σ ceil(L_i/(8P))`, and charged bytes are `(P+2)` times this count plus 1,012 bytes per block and 676 static bytes per layer image, divided by 1,024 inspected tokens. At 256-key restarts, the best layer-14 fixed-page image spends 21.358 B/token more than the offline coordinate image, and 9.898 more than static nibble. With `P=20`, the checked encoder allocates 5,464 pages and writes 4,568 overflow links for the 1,024 layer-14 tokens. At width 32, even the best page costs 170.072 B/token: a first page for every coordinate on each restart block dominates. These optima apply to this *fixed-size coordinate-page grammar and charged metadata*; they are not an impossibility result for a shared arena, a different append unit or learned codes.

More importantly, a query seeking a late coordinate difference must follow up to `ceil(L_i/(8P))` links and parse earlier codewords within that coordinate. At width 256, the worst serial chain still covers 255 symbols, before the backward suffix-mass work. No cache-byte win remains to pay those loads. The next construction should change the append unit to independently decodable **key rows** or jointly train a difference-producing V basis and post-O decoder. A per-key row can append without relocating earlier rows and can offer a short bounded parser; its row addresses, tables and direct suffix work still have to be charged. Do not build a native reader for this frozen paged-coordinate image.

`measure.py --layer 0` and `--layer 14` run from a Kelana checkout using the pinned CPU environment. `/path/to/workspace/data/kelana-subbit/value-paged-entropy/layer{00,14}.json` holds all 1–255 page sweeps, per-window allocated pages and pointer writes for checked capacities, table assignments, page payload hashes and source, capture, factor and parent hashes. Training uses eight WikiText train windows and the measurement uses four previously inspected validation windows on original-producer captures.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-paged-entropy/measure.py --layer 14
```
