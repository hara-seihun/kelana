# One byte dot for each paired-value correction list

The duplicate-label GQA value reader computes two 4,095-count signed-byte responses through a base dot and a signed head-difference dot. Its existing correction arm multiplies each count outside byte range by 28 scalar code coordinates. A radix-256 split turns each correction list into one more packed byte dot. No int4 weights or floating value rows appear. This is an exact **integer** map and an instruction candidate, not measured native speed.

Let `b_i >= 0` be the counts for the chosen base head, `a_i >= 0` those of its partner, and `d_i=a_i-b_i`, after identical signed-byte V rows have been grouped. Both count rows sum to 4,095. The base head is B in the measured arm. For each label's 28-byte code `c_i`, define

```
u_i = b_i & 255                  H_i = b_i >> 8
l_i = ((d_i + 128) & 255) - 128  D_i = (d_i - l_i) / 256
B = dot_u8_s8(u, c) + 256 dot_u8_s8(H, c)
A = B + dot_s8_s8(l, c) + 256 dot_s8_s8(D, c).
```

The first and third terms consume the ordinary dense base and compacted difference lists. The second and fourth run only over nonzero high bytes. `H` is 0..15 and `D` is -16..16 throughout the conserved-count domain, so both fit byte operands. `H` is nonzero exactly when `b_i > 255`; `D` is nonzero exactly when `d_i` lies outside `[-128,127]`. The latter remains true for negative counts because the signed low byte uses Euclidean remainder, not C-style truncated division. At most 15 base highs and 62 signed difference highs occur at **any** context length; the parent's 62 bound is tight. Integer accumulations and the factor-256 combination fit signed 32 bits: `|B| <= 4095*127 = 520065` and `|A-B| <= 8190*127 = 1040130`. This proof is coefficientwise and survives duplicate grouping and singleton bypass. It does not promise bit-identical FP32 rounding after scales and the paid O map.

The previous saturating low bytes cannot use a single byte high dot: their excess `b-min(b,255)` and `d-clip(d,-128,127)` can exceed one byte. Changing the low digit to a modular byte is what makes both high lists byte-dot-ready without changing either integer response. Count/list construction must generate the modular low bytes, high bytes and packed addresses. The image, 4,095-mass quality map, 224-byte raw cache rows and paid output map are unchanged.

## Captured logical-work panel

Four previously inspected, separate Qwen3-0.6B original-producer 256-token validation windows, all 16 heads and every causal query per layer. The script reconstructs both integer responses and checks the parent's complete response hash, count hash, codes and inputs. Each high list can issue in groups of four signed-byte coefficients on a dot4 reader. This table counts **label rows**, not cycles or cache lines. A list with zero entries consumes no correction dot.

| Layer | Base + difference low rows | High rows, base + difference | High rows rounded separately to 4 | High rows rounded separately to 16 | To 32 | Maximum base / difference list |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 1,081,333 | 18,746 + 50,264 = 69,010 | 37,280 + 61,760 = 99,040 | 256,848 | 513,600 | 9 / 17 |
| 14 | 1,759,387 | 19,950 + 36,105 = 56,055 | 35,808 + 48,412 = 84,220 | 255,200 | 510,400 | 8 / 15 |

Four-row padding makes correction row uses 43.5%/50.2% higher than the old scalar *entry* count. On a 32-coordinate padded code, the correction dot's modeled dot4 instruction count is `8 * padded_high_rows / 4`, or 198,080/168,440 instructions for these whole layer panels. The old scalar arm has `28 * high_rows`, or 1,932,280/1,569,540 coordinate multiplications, plus its code gathers. These are unlike instructions, not a latency ratio. The extra four-padded high rows are 8.16%/4.46% of the parent's base-plus-32-padded-difference low row work. Padding high lists to 16 or 32 wastes most of their dot slots, so a native reader needs a short subgroup loop, not a fixed 32/64-row tail for every query. Both high dot streams need a factor-256 integer combine, which can share each list's post-dot reduction. Packing, subgroup routing, code gathers, histograms, paid O and occupancy may dominate.

The result narrows the next native comparison: under the same signed-byte codes, paid output, occupied context and producer, compare a fused B-first grouped reader with four-row high-byte dots against its scalar-correction reader, then against two raw signed-byte heads and E4M3. Count creation and duplicate routing cannot be moved outside timing. If four-row high dots lose once the lists and gathers are paid, learn more shared V labels or head-coupled attention rather than widen the correction tile. No GPU, model loss, executable or service changed here.

[CPU receipts](/path/to/workspace/data/kelana-subbit/value-shortlist-radix/README.md) include per-window counts and source, parent, model, capture, paid-image, code, count and exact integer-response hashes. From a Kelana writer checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-shortlist-radix/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
