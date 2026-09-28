# Block-adaptive direct K-score segments

A 32-key restart has one anchor and 31 difference rows. If eight independent Huffman parsers may consume at most four rows each, the *only* variable partition has seven four-row segments and one three-row segment. There are eight choices. Four parsers of at most eight rows similarly have exactly four choices. This small exact family lets us settle whether choosing the short segment per block is worth its directory and append cost on the frozen paid Qwen3-0.6B key image.

## Exact family and cost

For segment width `S ∈ {4,8}`, `m=32/S`. The sum of the `m` positive segment lengths is 31 and every length is at most `S`. Their total deficit relative to `mS=32` is one, so exactly one segment has length `S-1`. Enumerating its `m` positions is an exact block-local optimum for a fixed Huffman table, not a heuristic segmentation search. The score consumer still dots decoded signed differences against both prepared queries and prefix-scans the two scores. No absolute int4 key vector is required. This is a real/integer identity, not a claim of FP32 bit equality.

We keep the [packed-length directory](../key-segment-frontier/README.md): six-bit fields and inline two-byte exceptional lengths for four-row streams, eight-bit fields for eight-row streams. The last segment length follows from the block boundary. The table costs 155 bytes per layer, and every group/block pays the original 16-byte anchor and four-byte offset. Its short-segment selector can sit in a separate, preallocated slab, three bits for four-row parsers or two bits for eight-row parsers. Eight selectors per group/window occupy exactly three or two bytes. A one-byte in-block selector is a simpler append coordinate but costs more. The script packs and round-trips the selector slabs, independently encodes and decodes every selected segment, reconstructs all 31 difference rows, and checks the integer prefix sums. The original canonical tree and hence its full signed-nibble alphabet and maximum 16-bit code length are unchanged. Complete-domain exceptional lengths still fit 16 bits, since 256 symbols use at most 512 bytes.

## Frozen paid-image measurement

Eight original-producer training windows fix one canonical tree per group. Four previously inspected 256-token validation windows yield 1,024 cached keys per layer. The fixed control places the short segment last, as in the preceding report. The block oracle knows all 31 difference rows before selecting its position; the packed and byte-selector arms charge its decision. The train-fixed arm chooses one position per group on train blocks and charges its three-/two-byte layer table. All columns include the 155-byte Huffman tables.

| Layer | Max rows/parser | Fixed last | Train-fixed | Block oracle, no selector | One-byte selector | Packed selector | Static mixed |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 4 | 116.172 | 116.104 | 115.844 | 116.094 | 115.938 | 112 |
| 0 | 8 | 114.667 | 114.648 | 114.567 | 114.817 | 114.630 | 112 |
| 14 | 4 | 96.837 | 96.846 | 96.686 | 96.936 | 96.779 | 112 |
| 14 | 8 | 95.669 | 95.660 | 95.555 | 95.805 | 95.617 | 112 |

Rates are bytes per cached token per layer, not model-weight BPW. The apparently promising zero-metadata oracle saves 155/117 bytes over 1,024 layer-14 tokens for four/eight-row streams. An ordinary byte selector *loses* 101/139 bytes. Bit-packed selectors retain just 59/53 bytes, or 0.058/0.052 byte per token, against the fixed last arm. At layer 0 the packed four-row arm saves 240 bytes but still loses to the static 112-byte/token cache by 3.938 bytes/token. Each of the four layer-14 windows saves 4–21 bytes on four-row streams after packed selectors and 11–18 bytes on eight-row streams. These tiny gains buy a variable segment boundary and per-block selector read.

The block oracle is not an ordinary append-only writer. Its choice depends on the block's last row, while an attention query may need the earlier keys before that row exists. It must retain an addressable provisional image or stage up to 31 keys and finalize the block when the final row arrives. Staging raw packed labels alone reaches 31 × 16 × 8 = 3,968 bytes per layer per sequence at a full open block, before reading those labels again to encode the chosen segments. A provisional fixed stream plus a later rewrite is another valid program but also spends extra online work. This is not a universal lower bound on every adaptive writer. It is the unpaid work attached to this oracle, against at most 0.058 byte/token of layer-14 saving. The fixed first position is already cheaper than fixed last at layer 0 without staging, though neither beats static there.

The source, per-window bytes and exception counts, all selector histograms and identity hashes are in `measure.py` and `/path/to/workspace/data/kelana-subbit/key-segment-dynamic/layer{00,14}.json`, SHA256 `b10aad2a63bc5010c7088e3b390ea26d15190a50a2079d6f21239a59fb32b4de` and `c89a7c2e710cd841d57f4a4a236366d6d307d53a09685c937d1d5b8d6ff27f44`. Run one layer at a time in the installed CPU environment:

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/key-segment-dynamic/measure.py --layer 14
```

No GPU, native score timing, new model loss, Bonsai executable or serving default changed. Do not build the block-adaptive parser to chase these bytes. The next useful native K-score experiment prices the fixed four-/eight-row append, parser, directory and two-head score at occupied context against static mixed. A larger gain requires new paid labels or a code grammar that reduces parser work, not hindsight placement of one short segment on these frozen labels.
