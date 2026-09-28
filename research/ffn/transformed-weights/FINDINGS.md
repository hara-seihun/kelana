# Absorbing the sign/Hadamard input maps into Bonsai's ternary FFN-down weights

Verdict: absorption is **algebraically exact and a loss on this deployment**. The
transform moves into the weights without any approximation — it lands in a dyadic
integer lattice with one exponent per (row, 1024-block) — but it converts a 1.585-bit
alphabet into a 6.3-bit one across all 5120 output rows in order to delete 0.2% of the
matvec's arithmetic, and it relocates the int8 quantiser out of the basis that was built
for it. The cost side is a bandwidth/arithmetic estimate under stated assumptions (§5),
not an impossibility argument.

All numbers below come from real weights: `blk.10.ffn_down.weight` in
`/path/to/workspace/data/bonsai2/PTQ1_0.gguf`, 512 output rows × four 1024-wide Hadamard
blocks (2,097,152 weights), plus brute-force checks at n = 4, 8.

## 1. The deployed map

From `kernels/phases.hpp` (`prep_chunk_r`, `mvw_rows`) and `halo_rows.hip:206-215`, with
`h = silu(gate) * up` in R^17408, chunked into 17 blocks of 1024:

```
u   = (1/32) H_1024 . diag(s) h              s from prism.hadamard.sign_values (±1)
q_j = round(u_j / c_b),   c_b = amax_b(u)/127        (b = 128-wide block)
y_i = sum_b lam[i,b] * c_b * sum_{j in b} t[i,j] q_j       t in {-1,0,+1}
```

`H_1024/32` is orthogonal, so `T = (1/32) H diag(s)` is a randomised Hadamard rotation.
The weights were ternarised *in that rotated basis*; `lam[i,b]` is one fp16 per output
row per 128 columns.

Index split `j = 1024C + 128g + d`, output column `1024C + 128a + c`, gives
`H_1024 = H_8 ⊗ H_128` aligned exactly with the scale groups (verified,
`kron_split_exact`):

```
32 * M[i, C, a, c] = sum_g H_8[a,g] * lam[i,C,g] * V[i,C,g,c],    V = t . H_128 in Z
```

`H_128` lives inside one scale group, so it is scale-free. `H_8` mixes eight groups with
eight different `lam`. That is the whole commutation story on the weight side.

## 2. Absorption is exact in a dyadic lattice (not approximate)

fp16 `lam = m * 2^(e-11)` with `m` an 11-bit integer. Measured: the eight scales inside a
1024-block **share one binary exponent** in 99.7% of blocks (max spread 1; max/min ratio
mean 1.21, max 1.59). So

```
M[i, C, a, c] = 2^(e[i,C]-16) * Z,    Z = sum_g H_8[a,g] m[i,C,g] V[i,C,g,c] in Z
```

Checked bit-exactly on all 2.1M weights (`exact_dyadic.reconstruct_exact = true`):
|Z| ≤ 594096, 21 bits, order-0 entropy 16.6 bits, gcd 1.

There is no missing residual in the *linear* map. The residual appears only when the
quantiser is put back (§4) or when Z is truncated to a storable width (§5).

## 3. Structure in the transformed alphabet — what is real

| absorbed stages k | 0 (trit) | 3 | 6 | 7 (=H_128) | 10 (=H_1024) |
|---|---|---|---|---|---|
| alphabet | 3 | 17 | 63 | 94 | 307 |
| absmax | 1 | 8 | 36 | 58 | 319 |
| entropy (bits) | 1.585 | 3.26 | 4.76 | 4.40 | 6.32 |
| zero fraction | 32.8% | 16.9% | 6.2% | 8.4% | 2.7% |

Real structure found:

- **Stage law.** Each absorbed butterfly stage replaces a weight by a signed sum of two
  previous weights, so entropy rises ≈ 0.5 bit/stage (1.585 → 6.32 over ten stages).
  Absorption cost is linear in stages; there is no cheap prefix.
- **Parity lemma.** Every transformed coefficient has the parity of `nnz(t)` over the
  absorbed span (brute-forced at n = 4, 8; holds on all real blocks). PTQ1_0 puts
  **exactly 86 nonzeros in 97.5% of 128-blocks** (never fewer; 98.1% even), so
  `t.H_128` is all-even almost everywhere — one free bit, and the k=7 entropy dip in the
  table above.
- **Lattice membership.** `V ∈ H_n Z^n`, i.e. `H V ≡ 0 mod n` and `HV/n` ternary
  (verified). Column differences are always even with `|V_j - V_k|/2 ≤ n/2`.
- **Kronecker basis.** The 1024 transformed values of a row are `H_8` combinations of
  eight 128-vectors. That is a change of basis, not a compression: 1024 values in, 1024
  out.

Structure that is **not** there:

- No useful sparsity. Absorbed values are near-Gaussian: the largest 25% of |M| holds
  73% of the energy, the largest 50% holds 93%. Ternary keeps 100% of its energy in 67%
  of positions.
- No small finite alphabet once real scales are included: 8.8% of the 2.1M absorbed
  values are distinct, essentially none are zero.
- No repeated-value or shared-basis reuse across rows.
- Compressibility is not structure: a 1024-block carries at most 1024·log2(3) = 1623
  bits, while its transformed order-0 code costs 6470 bits. Multiplying by `H` recovers
  that redundancy. Whether a cheaper decoder exists is untested here — the 4× gap is
  measured against an order-0 symbol code, not a lower bound over all codes.

## 4. Obstruction 1: the quantiser sits between the transform and the weights

`Q` (round + per-128 amax scale) is not linear, so for any invertible `P`,
`W Q(P h) ≠ W P Q(h)`. Absorbing `T` moves the quantiser from the transformed basis into
the raw activation basis. The exact residual is

```
y_absorbed - y_deployed = Lam W T (h - h~) - Lam W (u - u~)
```

with each term governed by its block's `amax/127`. The Hadamard's whole job is to shrink
`amax/rms` from the raw crest factor to ≈ sqrt(2 ln 1024) ≈ 3.7. Synthetic check
(`small_examples.py`, 4 outlier channels per 1024, averaged over 20 draws):

| outlier size | 3σ | 6σ | 12σ | 25σ | 50σ |
|---|---|---|---|---|---|
| rel err, deployed | 0.64% | 0.64% | 0.63% | 0.61% | 0.54% |
| rel err, absorbed | 0.65% | 0.93% | 1.46% | 1.94% | 2.17% |
| ratio | 1.03 | 1.44 | 2.34 | 3.18 | 3.99 |

No residual correction repairs this: computing the correction requires the transform you
deleted. The mirror move — absorbing a map applied *after* `Q`, which is exact — fails
for a different reason: the eight 128-blocks in a chunk carry different `c_b`, so an
`H_8` stage does not act on the int8 words at all without rescaling them to ≥ int16.

**Lemma (a class that does cross `Q` exactly).** Let `Q` act on a 128-block by
`c = amax(v)/127`, `q = round(v/c)`. If `P` acts inside the block as `P = alpha * Sigma`
with `alpha != 0` real and `Sigma` a signed permutation, then
`amax(Pv) = |alpha| amax(v)` and
`round(alpha v_sigma(j) / (|alpha| c)) = sgn(alpha) round(v_sigma(j)/c)`, so
`Q(Pv) = sgn(alpha) Sigma Q(v)` with block scale `|alpha| c`. Blockwise compositions of
signed permutations and nonzero scalar rescalings therefore move across the quantiser
exactly, provided the matching column permutation/sign goes onto the weights and the
per-128 weight scale `lam` absorbs `1/alpha`. Positive groupwise rescaling with a scale
adjustment is the useful case and it is free. Ties and the `amax = 0` case round
identically on both sides.

We have not characterised the maximal commuting class. What is clear from the same
argument is why the maps in question are outside it: a map that mixes coordinates inside
a block changes `amax` in a value-dependent way, and a map that mixes across blocks (the
`H_8` stage) meets eight different `c_b`. The deployed sign vector is a signed
permutation, but it sits before `H`, so reaching the weights means conjugating it:
`H diag(s) H^-1` is 94.6% dense.

## 5. Obstruction 2: the transform is amortised over 5120 rows, the weights are not

Assumptions for the numbers in this section: batch 1, weights streamed once per token
with no reuse across tokens, 1 TB/s achieved weight bandwidth, 150 Top/s dense int8,
and `Δbits ≈ 0.5` per absorbed stage as measured in §3. Change any of these — weights
resident in SRAM/cache across many tokens, a much more expensive input map, a different
alphabet — and the comparison moves.

Per butterfly stage, for the down matrix (D=5120, FF=17408):

- saves 17,408 adds per token;
- costs ≈ 0.5 bit on each of 89.1M weights = 5.57 MB extra weight traffic per token.

That is 5.6 µs added against 0.12 ns saved, a loss factor of 4.8e4. Break-even needs
≈ 48,000 tokens sharing one weight read, and at that point the int8 MAC count is
identical for both forms, so nothing is gained there either — under this cost model.

**Cost model (exchange rate), not a theorem.** For `y = W P x` with `P` a fixed input map
shared by `N` output rows, absorbing `P` pays only if the per-element cost of `P` exceeds
`N · Δbits / 8` bytes of weight traffic per element. `Δbits` is whatever the absorption
does to the weight alphabet, and it is not always positive: signed permutations and
blockwise rescalings (§4 lemma) give `Δbits = 0`, and weights already lying in the image
of the map can be unchanged. For the Sylvester–Walsh butterflies on these ternary blocks
it is ≈ 0.5 bit/stage (§3), and with `N` in the thousands that settles it here.

Whole-matrix accounting (`blk.*.ffn_down`, 5120×17408):

| plan | bits/weight | MB | × deployed | adds saved (as fraction of MACs) |
|---|---|---|---|---|
| deployed PTQ1_0 + shared H_1024 | 1.75 | 18.6 | 1.00 | — |
| absorb H_128, keep sign + H_8 shared | 8.125 | 86.3 | 4.64 | 0.137% |
| absorb H_1024, one scale per row-block | 8.016 | 85.2 | 4.58 | 0.195% |
| absorb H_1024, int16 (no clipping) | 16.016 | 170.2 | 9.15 | 0.195% |

Weight error from truncating the exact integer Z to B bits with one fp16 scale per
(row, 1024-block): 6 bits 3.37%, 7 bits 1.66%, **8 bits 0.82%**, 9 bits 0.41%,
10 bits 0.20%, 12 bits 0.05%. Collapsing the eight per-128 scales to one per 1024 costs
6.06% on its own.

## 6. The concrete candidate lowering, and why it is still a loss

Best version of the idea, implementable with no new kernel:

1. Precompute `V = t . H_128` per scale group; `|V| ≤ 58`, fits signed int8 with room.
2. Store `V` scaled into the **existing Q8 halo tile format** (`Q8_TILE_BLOCK_BYTES =
   4160` = 8.125 bits/weight: signed int8 + one fp16 per 128). `mvw_rows`'s `Q8=true`
   path already consumes exactly this, same WMMA instruction count, and `xsum` drops out
   (`xsc = 0`).
3. In `prep_chunk_r`, run only the three `H_8` stages (the cross-wave butterflies) plus
   the sign, then quantise.

Cost: 4.64× weight bytes, 0.137% fewer adds, and quantisation now happens in a
partially transformed basis (§4). If an int8-alphabet absorbed form is ever wanted, this
is the shape it takes; nothing about it is better than the factorised form.

## 6b. Nonzeros per 128-block, whole model

`scan_nnz.py` counts nonzeros per PTQ1_0 block straight from the packed bytes (a
256-entry table per byte kind, no trit decode), so it covers every ternary tensor in
`PTQ1_0.gguf`: 402 tensors, 209,920,000 blocks, 11 s.

- Global range **86 to 128**. Minimum is 86 everywhere; 97.27% of all blocks hold
  exactly 86 nonzeros.
- **Blocks with 128 nonzeros exist: 48 of them** — 43 in `blk.15.attn_q.weight`, 5 in
  `token_embd.weight`. A model-wide "at most 127 nonzeros" premise is false, by 2.3e-7
  of blocks.
- All FFN tensors stay well clear: max 110 (`ffn_down`), 115 (`ffn_gate`), 108
  (`ffn_up`), across 133.7M blocks, with **zero** blocks at 120 or above.

| tensor kind | blocks | max nnz | ≥120 | =128 |
|---|---|---|---|---|
| ffn_down | 44,564,480 | 110 | 0 | 0 |
| ffn_gate | 44,564,480 | 115 | 0 | 0 |
| ffn_up | 44,564,480 | 108 | 0 | 0 |
| attn_qkv | 19,660,800 | 110 | 0 | 0 |
| attn_gate | 11,796,480 | 119 | 0 | 0 |
| ssm_out | 11,796,480 | 117 | 0 | 0 |
| output | 9,932,800 | 114 | 0 | 0 |
| token_embd | 9,932,800 | 128 | 33 | 5 |
| attn_q | 7,864,320 | 128 | 81 | 43 |
| attn_output | 3,932,160 | 124 | 2 | 0 |
| attn_k | 655,360 | 115 | 0 | 0 |
| attn_v | 655,360 | 115 | 0 | 0 |

Tail of the global histogram (counts): 86: 204,185,775 · 87: 2,999,519 ·
88: 1,038,184 · 89: 563,002 · 90: 358,437 · 95: 56,249 · 100: 6,989 · 105: 588 ·
110: 54 · 115: 17 · 120: 11 · 125: 6 · 126: 9 · 127: 16 · 128: 48.
Full histogram and per-tensor min/max/counts in `nnz_all_ptq.json`.

## 7. The move that does pay, from the same analysis

The per-128 scales inside a 1024-block share an exponent and span < 1.6×. Replacing
each fp16 with a shared fp16 maximum per 1024-block plus a short per-group ratio code:

| code bits | weight error | block bytes (from 28) | tensor size |
|---|---|---|---|
| 2 | 5.11% | 26.5 | 0.946× |
| 3 | 2.12% | 26.625 | 0.951× |
| 4 | 0.98% | 26.75 | 0.955× |
| 5 | 0.48% | 26.875 | 0.960× |

4-bit codes buy 4.5% fewer weight bytes for 0.98% weight perturbation — against
absorption's 358% more bytes for 0.82%. The scale blocks, not the transform, are where
the representation still has slack. (This changes the deployed function too; it is a
requantisation proposal, not a rewrite, and it needs a quality check before anyone acts
on it.)

## Reproduce

```
cd research/ffn/transformed-weights
python3 absorb_stats.py --layer 10 --rows 512 --blocks 4      # -> absorb_stats.json
python3 absorb_stats.py --exponent-survey                     # layers 0/10/31/47
python3 small_examples.py                                     # -> small_examples.json
python3 scan_nnz.py --all-ptq --json nnz_all_ptq.json         # every ternary tensor, ~11 s
```

`gguf_read.py` is a read-only GGUF/PTQ1_0 decoder mirroring `src/gguf.cpp` and
`halo_format.h::decode_gguf_ptq1_0`. Nothing here writes to the model or to
`bonsai-halo`.
