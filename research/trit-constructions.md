# Concrete IU4 constructions for Halo pack5 weights

This note stays at the construction and finite-check level. It does not claim a global optimum or assign gfx1151 cycle costs. The instruction counts below are symbolic issue counts so the hardware-cost work can attach measured costs later. Under the current [staged objective](PROBLEM.md), weight-only conversion may move offline into a new weight file. These fixed-source counts remain useful for identifying which work disappears and which remains input-dependent.

## Exact two-IU4 decomposition of signed int8

Let `w = t - 1` for Halo's stored trit `t in {0,1,2}`. For a signed byte `x`, let `r = x mod 256`, then define

```text
l = r & 15                 unsigned nibble, 0..15
h = signed4(r >> 4)        signed nibble, -8..7
x = l + 16 h
```

A 16 by 16 integer MAC can therefore use two native IU4 WMMAs:

```text
L = WMMA_IU4(signA=1, signB=0, A=w, B=l, C=C)
H = WMMA_IU4(signA=1, signB=1, A=w, B=h, C=0)
D = (H << 4) + L
```

For wave32, `D`, `H`, and `L` each occupy eight i32 VGPRs per lane. Eight `V_LSHL_ADD_U32` instructions implement the final combine, one for each accumulator register. This handles carries as ordinary i32 arithmetic. It does not pack several output elements into one word.

With `C=0`, each output is between -2048 and 2048. The low partial is between -240 and 240, and the high partial is between -128 and 128 before the shift. An incoming `C` needs enough i32 headroom for another 2048 in either direction. Under that condition, unclamped and clamped WMMA have the same integer result.

The low WMMA takes the original accumulator. This avoids a separate addition of `C` after recombination.

The two nibble planes contain the same total payload as the original byte matrix. If quantization writes them directly, no extra device-memory capacity is needed. Converting an already byte-packed B fragment is a real cost and must not be omitted from a comparison. Halo's prep code has `q0` through `q3` as separate integers immediately before byte assembly, so producing the two planes there is the clean candidate.

## Turning unpacked trits into signed i4 in two instructions

An IU4 fragment initially packed with eight unsigned trits has the word

```text
T = sum_i t_i << (4 i),    t_i in {0,1,2}.
```

The signed two's-complement nibble codes for `t_i - 1` are obtained by

```text
W = (T + 0x77777777) XOR 0x88888888.
```

No carry crosses a nibble because every nibble of `T + 0x77777777` is 7, 8, or 9. The XOR maps those values to 15, 0, or 1. Thus one `V_ADD_U32` and one `V_XOR_B32` convert eight weights at once.

This is cheaper than keeping `t` unsigned in the isolated fragment model. Unsigned `t` requires subtracting the activation-column sum from every i32 output. A wave32 output fragment has eight registers, while a signed IU4 A fragment has two registers. Converting both A registers costs four vector instructions and removes eight per-output corrections. This comparison assumes neither correction has already been folded into a useful existing accumulator.

`research/constructions/iu4_radix16.py` checks this mapping over all `3^8 = 6561` input words.

## Packing the first four pack5 digits directly into nibbles

Halo's `peel` accepts two pack5 bytes in the low bytes of two u16 halves. After four peels, write the results as

```text
t0 = [a0, 0, b0, 0]
t1 = [a1, 0, b1, 0]
t2 = [a2, 0, b2, 0]
t3 = [a3, 0, b3, 0]
```

where the brackets show bytes. Form

```text
q01 = (t1 << 4) OR t0
q23 = (t3 << 4) OR t2
```

with two `V_LSHL_OR_B32` instructions. The significant bytes are now

```text
q01 = [a0 | a1<<4, 0, b0 | b1<<4, 0]
q23 = [a2 | a3<<4, 0, b2 | b3<<4, 0].
```

One `V_PERM_B32` selects bytes 0 and 2 from each source to produce the nibble order

```text
[a0, a1, b0, b1, a2, a3, b2, b3].
```

That order is Halo's natural K order for one eight-element `p` group. Do this for `P0`, which contains source bytes 0 and 2, and `P1`, which contains bytes 1 and 3. The two resulting dwords are exactly one row's 16 IU4 weights for the corresponding early K slice.

The assembly cost per pack5 byte pair is three instructions. Halo's byte path uses two `V_LSHL_OR_B32` instructions for the same first four digits, so direct nibble assembly adds one instruction per pair before signed conversion. It halves the live A-fragment width from four to two VGPRs.

The construction applies directly to each of the six 16-wide slices covering K positions 0 through 95. The script checks the proposed order for every pair of canonical pack5 bytes, `243^2 = 59049` cases.

## Packing fifth digits with 0x00110011

After the fifth peel for one Halo source dword, the existing byte assembly produces

```text
F = [a, b, c, d]
```

where each byte is a trit from one of the four pack5 bytes. For either u16 half `z = a + 256 b`, with `a,b <= 2`,

```text
((17 z) >> 4) & 255 = a + 16 b.
```

The `17a` term shifts to `a` because `a < 16`. The `17*256b` term contributes `16b` modulo 256 after the shift. One `V_PK_MUL_LO_U16` with `0x00110011`, followed by `V_PK_LSHRREV_B16 4`, therefore packs both byte pairs in `F` at once.

Apply those two instructions to each of two consecutive `F` words. One `V_PERM_B32` selects bytes 0 and 2 from both shifted words. The result contains eight consecutive fifth digits in nibbles. The cost is five instructions per eight trits after the two existing byte-assembly instructions. Signed conversion adds the same two-instruction `0x77777777` and `0x88888888` transform.

This completes the remaining Halo slices:

- K96 through K111 use four `F` words, two five-instruction gathers, and two signed conversions.
- K112 through K119 use two `F` words and one gather.
- The qh bytes' eight trits use the earlier two-byte pair assembly, in exactly Halo's K120 through K127 order.

For one full 128-weight row, unsigned IU8 uses 32 assembly instructions after the peel cores. Signed IU4 uses 60 instructions for the six early slices, 27 for all fifth digits including their six existing `F` assemblies, and 5 for qh. That is 92, or 60 more preparation instructions. The gain is narrower fragments, not cheaper weight decoding. The script exhausts all `3^4 = 81` inputs to the packed-`0x11` transform.

## Peel operation counts

For one pair of pack5 bytes, Halo's iterative five-digit peel has this symbolic count:

| operation | count |
| --- | ---: |
| `V_PK_MUL_LO_U16` | 5 |
| `V_PK_LSHRREV_B16` | 5 |
| `V_AND_B32` to retain nonterminal remainders | 4 |
| total before digit assembly | 14 |

There is an equal-count, shorter-dependency alternative. From the original packed pair `P`, compute in parallel

```text
Q_j = (P * 3^j) >> 8 per u16 half,  j=1..5
trit_0 = Q_1
trit_j = Q_(j+1) - 3 Q_j,           j=1..4.
```

The constants are `3, 9, 27, 81, 243`. Five packed multiplies and five packed shifts produce the `Q_j`; four `V_PK_MAD_I16` instructions produce the differences. This is also 14 issued instructions, so it is not a total-operation improvement. It exposes independent multiplies and removes the serial remainder chain. That may affect latency but is not evidence of fewer execution-unit cycles.

The scalar equivalents use `V_MUL_HI_U32` with constants

```text
0x03000000, 0x09000000, 0x1b000000, 0x51000000, 0xf3000000
```

because `mul_hi(p, 3^j << 24) = floor(3^j p / 256)`. Scalarizing each byte loses the packed-u16 advantage and is not attractive by instruction count.

## Three 10-bit peel lanes in one dword

Three Halo bytes can occupy 10-bit fields at offsets 0, 10, and 20:

```text
P = p0 | p1 << 10 | p2 << 20
M = 3 P
T = (M >> 8) & 0x00300c03
R = M & 0x0ff3fcff
```

Each `3*pi` is at most 765, so multiplication cannot carry into the next 10-bit field. `T` contains the three next trits at the original field offsets and `R` contains the three 8-bit remainders.

One nonterminal peel stage has four ordinary word operations:

1. `V_LSHL_ADD_U32 P, 1, P` or `V_ADD3_U32 P, P, P` for multiplication by three.
2. `V_LSHRREV_B32 8, M`.
3. `V_AND_B32` with `0x00300c03` for the digits.
4. `V_AND_B32` with `0x0ff3fcff` for the remainders.

The terminal stage omits the remainder AND, so five digits cost 19 issued operations per three source bytes. The current packed-u16 path costs 14 per two bytes. Across Halo's 24 pack5 bytes, the isolated peel cores are 152 operations for eight triples versus 168 for twelve pairs. This is a 16-operation saving before repacking.

`research/constructions/probe_peel3.sh` compiles one stage for gfx1151 at `-O3` and checks the kernel body. The installed compiler emits exactly `V_LSHL_ADD_U32`, `V_LSHRREV_B32`, and two `V_AND_B32` instructions for the arithmetic. It does not emit a general multiply or `V_ADD3_U32`.

The obvious repacking route loses that saving. For three contiguous source bytes in an aligned dword, two `V_BFE_U32`, one AND, and two `V_LSHL_OR_B32` instructions build the 10-bit-field word, five operations. Halo's 24 bytes start triples at byte offsets 0, 3, 2, 1, 0, 3, 2, 1 across six loaded dwords. Six of the eight triples first need a cross-dword align. This route costs about 46 packing operations. The current dword split into `P0` and `P1` costs three operations per four bytes, 18 across the block. Triple packing is therefore 28 operations dearer to save 16 in the peel core, before gathering the 10-bit-spaced trits into WMMA fragments.

This does not rule out a better repacker or a storage layout built around 10-bit fields. Storing eight triples directly as independent 32-bit words increases the 24-byte pack5 payload to 32 bytes. Packing eight 30-bit triples densely would take 30 bytes but would reintroduce runtime extraction into native words. The script checks each byte value in each of the three field positions and 100,000 deterministic random triples.

## Symbolic comparison for one 16 by 16 fragment

This table starts from two canonical pack5 byte pairs per lane, which supply the 16 weights. It excludes loads, activation-plane production, and measured instruction throughput.

| component | unsigned IU8 Halo-style | signed IU4 radix-16 |
| --- | ---: | ---: |
| five-step peel of two byte pairs | 28 | 28 |
| assemble first four digits | 4 | 6 |
| convert A codes to signed | 0 | 4 |
| matrix instructions | 1 IU8 WMMA | 2 IU4 WMMAs |
| combine high and low accumulator fragments | 0 | 8 `V_LSHL_ADD_U32` |
| unsigned-weight activation-sum correction | 8 i32 corrections | 0 |

The IU4 candidate replaces one IU8 WMMA and eight output corrections with two IU4 WMMAs, eight fused shift-adds, and six extra weight-preparation instructions. Activation splitting is additional unless prep stores nibble planes. IU4 also halves each live A or B fragment, though both B planes together occupy the same register payload as one IU8 B fragment.

For Halo's 32-row lane-swap scheme, each 16-wide slice has two output fragments. The A-half swap costs four register swaps for IU8 and two for IU4. The IU4 construction then needs four WMMAs and sixteen accumulator shift-adds versus two WMMAs for IU8. These are operation counts, not cycle totals.

## Exhaustive affine-digit search

The script enumerates coefficient pairs `a,b in [-32,32]` for two digits `p,q in [0,15]`. It records pairs for which

```text
{a p + b q | p,q in [0,15]}
```

contains 256 distinct consecutive integers. The only matches in that range are signed variants and swaps of `(1,16)`. This finite result rules out a smaller recombination coefficient inside that precise two-u4 affine family. It says nothing about mixed coordinates, extra WMMA K slots, table lookups, bit-sliced methods, or other non-affine constructions.

The same script checks all 768 scalar pairs of a ternary weight and signed int8 activation, all 243 pack5 round trips, and 256 deterministic random 16 by 16 matrix products. Its checked output is stored in `research/constructions/iu4_radix16-certificate.json`.

Run it with:

```sh
python3 research/constructions/iu4_radix16.py
```
