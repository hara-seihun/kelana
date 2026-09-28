# Half-orbit tables for the paid binary-factor consumer

A signed-eight response table need not store both a sign pattern and its negative. Fix the first sign positive, index the relative signs of the other seven coordinates, and apply the first sign after one table read. This gives a direct consumer for **both** existing binary-factor planes at half the full table's live entries. Neither factor image, its stored rate, nor its real-valued two-stage map changes. It is a different, regular competitor to the [routed four-output bucket map](../binary-pair-map/README.md), not a measured native win.

For input block `h[0..7]` and sign vector `s`, write `a=s[0]`, `m_i=1` when `s[i]=a` for `i=1..7`, and

```
T[m] = h[0] - sum(h[1..7]) + sum(2*h[i] for i=1..7 when m_i=1).
response(s,h) = a*T[m].
```

Expanding the two cases for each `i` proves `response=sum(s[i]*h[i])` for every real input and every eight-bit sign image. The packed byte already holds the signs: if bit 0 denotes positive, the seven-bit table index is `(byte >> 1) XOR (bit0 ? 0 : 127)`. The sign is bit 0. No dense eight-weight vector or int4 intermediate enters the consumer. Apply the existing input scales before the first factor and output scales after the second factor; each factor's algebraic reduction remains the same. FP32 reassociation is a *different numerical map*, so a native implementation needs its own quality evidence if it changes the selected operation order.

One construction starts from `T[0]=h0-sum(h1..h7)`, forms seven doubled inputs, then walks the 128 masks in reflected Gray order. Each of the 127 transitions changes one sign and adds or subtracts one doubled input. This costs at most 141 scalar additions per table (seven for the base, seven doubles, 127 transitions), with 128 entries. For exact integer inputs, doubling can be a shift instead. A full 256-entry one-update-per-entry table was previously costed at 255 additions without its seed; the half table reduces that published entry count and its stated update budget by 50% and 44.7%, respectively, before accounting for the half-table's extra per-lookup sign operation. Stream a 512-byte int32 or FP32 table per eight-input group; materializing *all* groups at once is unnecessary.

This entry count is optimal in a precise grammar. Let the eight real inputs be algebraically independent and allow a consumer one table read, followed only by a unary sign change. The 256 signed linear forms are all distinct, and each table entry can represent at most its positive/negative pair. At least 128 entries are required. If an explicit table generator starts with one response and each arithmetic update writes one new entry, it needs at least 127 such updates; our generator has 14 additional additions to form the base and doubles. This is **not** a lower bound on arbitrary multi-read, packed-ISA, or shared-across-block consumers, nor on total native latency.

## What the frozen images pay

`measure.py` reads all sixteen pinned Qwen3-0.6B `.55` binary images at layers 0, 7, 14 and 27. It consumes the actual little-endian packed U/V bits through both tables on a fixed integer activation, checks every first-factor output and every final output against independent signed matrix products, and retains image, source, input, intermediate and output hashes in `/path/to/workspace/data/kelana-subbit/binary-half-table/images.json`. Integer outputs remain within int64; this is an exact integer map check, not model quality or GPU timing. All four shapes repeat on the four layers.

| Projection `N×K`, rank | Tables `K/8+R/8` | Half-table entries | Prep adds upper | Reads, both factors | Row-reduction adds | Quartet signed adds / dynamic routes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| up `3072×1024`, 384 | 176 | 22,528 | 24,816 | 196,608 | 193,152 | 709,632 / 294,912 |
| Q `2048×1024`, 352 | 172 | 22,016 | 24,252 | 135,168 | 132,768 | 555,008 / 180,224 |
| O `1024×2048`, 352 | 300 | 38,400 | 42,300 | 135,168 | 133,792 | 818,176 / 90,112 |
| down `1024×3072`, 384 | 432 | 55,296 | 60,912 | 196,608 | 195,200 | 1,285,120 / 98,304 |

A table read also needs one sign selection/negation and indexed addressing. The read counts are `RK/8 + NR/8`, and row-reduction additions are `R(K/8-1)+N(R/8-1)`. The quartet count includes its first factor's conventional `RK` signed terms and its 28-add-per-quartet output combination; its routes are separate. These counts cannot be compared as if an indexed LDS read, a routed accumulation, a signed add, and a WMMA term were one instruction. For up, the regular consumer replaces 294,912 output routes and eight live per-quartet buckets with 147,456 output table gathers, while paying output table preparation and per-gather sign work. It is the right second arm of a native panel, not a proof that the routed arm loses. A 512-byte table can fit LDS, but divergent index reads, occupancy, first-factor sharing across output rows, and materialization schedule decide whether that is worthwhile.

Next run a same-image, same-activation gfx1151 `mlp_up` panel with the half-table reader, the full-table reader, and routed quartets. Time table build, both reductions, row scales and output writes together at generation and prompt widths. If irregular indexed reads dominate even with half-sized tables, co-train the factor signs into a smaller response alphabet rather than optimize a frozen lookup implementation again. No engine executable or serving default changed here.

Run `OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-half-table/measure.py` to regenerate the source/image-hashed receipt.
