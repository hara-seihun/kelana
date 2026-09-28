# Bonsai representation proofs

The current [2×2 multiply-add proof](toy2/PROOF.md) establishes a cheaper exact packed computation than its elementwise int4 baseline. This report owns the separate Bonsai codec, peel and larger-tile results.

These results were developed and checked on the main agent thread. They establish exact constructions, two restricted packing bounds and an impossibility result. They do not establish the minimum unit-cycles for an entire ternary WMMA implementation.

The current objective in [PROBLEM.md](PROBLEM.md) treats loading and representation conversion as operations on arbitrary weight inputs. Prepared layouts may be reused for the same weight version or persisted in a new file. The counts below retain their original fixed-source boundary where stated; preparation described as offline means work moved to loading or file preparation, charged once per applicable reuse cohort rather than made free. The [hardware cost report](cost-model.md) and [construction inventory](trit-constructions.md) separately account for instruction service demand and conversion costs.

## 1. The actual Bonsai codec is invertible

[Kelana/Halo.lean](../Kelana/Halo.lean) formalizes the rank-to-byte map

```
p = floor((256q + 242) / 243)
q = floor(243p / 256).
```

For `q < 243`, p fits in a byte. Repeatedly multiplying p by three, taking the high byte as a digit and retaining the low byte returns all five original base-3 digits. `rank5_as_multiply` and `decode_encode` prove this symbolically, not by testing 243 examples.

This matters because the source is not an ordinary base-3 integer stored directly in a byte. Optimizations must preserve the scaled fractional representation that Bonsai actually uses. Source provenance is Bonsai commit `6fcff4c0a881e1fa2f448db630e76a57cb1bf268`, `src/halo_format.h` and `kernels/device.hpp`.

## 2. Three independent byte streams fit one carry-isolated peel word

Bonsai uses two byte streams in 16-bit fields. Instead, put three bytes into 10-bit fields:

```
r = p₀ + 2¹⁰p₁ + 2²⁰p₂
m = 3r
digits     = (m >> 8) & 0x00300C03
remainders = m & 0x0FF3FCFF
```

Each `3pᵢ ≤ 765`, so each product fits ten bits and cannot carry into its neighbor. The resulting digits and remainders stay in the same field positions, ready for the next peel. Multiplication by three can be a shift-add rather than a general multiply.

[Kelana/PeelLanes.lean](../Kelana/PeelLanes.lean) proves:

- the packed product fits a 32-bit word;
- extracting the stated bit fields gives exactly three independent calls to the scalar peel;
- ten bits is the minimum complete carry-isolated field width;
- three is the maximum number of uniform fields of that kind in 32 bits.

The Lean extraction definitions use division and remainder at explicit bit positions. The masks above express those disjoint positions. This is a proof of the arithmetic construction, not a verified compiler lowering.

The fourth byte cannot be included under the same no-carry rule. That is a tight packing bound for this family. Carry-aware encodings, different instructions and other representations remain outside it.

Raw operation accounting is not a 50% speedup. The 10-bit construction needs a logical shift and digit mask where a native packed-16 shift can handle two 16-bit fields in one instruction. Five digits take 19 ordinary word operations for three streams versus 14 packed operations for two streams, under the straightforward lowering and excluding setup. For six streams, that is 38 versus 42 instructions. Actual unit-cycle charges, output assembly and final-stage simplifications decide whether there is any online saving. Input packing moves offline if the file stores each triple in a native 32-bit word, at 32 bits per 15 trits instead of 24. The construction inventory inspects the original runtime-packing costs separately.

## 3. Two all-ternary dot products can share one byte-input dot

For two ternary weight rows a and a' and a shared ternary activation row b, all of length 16, set

```
wₖ = aₖ + 64a'ₖ
z  = Σₖ wₖbₖ = x + 64y
x  = Σₖ aₖbₖ
y  = Σₖ a'ₖbₖ.
```

The packed weights lie in `[-65,65]`, so they fit signed int8. Each output lies in `[-16,16]`. Recover them exactly with

```
x = sign_extend_6(z & 63)
y = (z + 32) arithmetic_shift_right 6.
```

The packed dot has magnitude at most 1040, so these integer operations do not overflow int32. Applying the identity independently to each output row and column lets one IU8 WMMA compute the mathematical outputs of two all-ternary tiles. The statement starts with zero accumulators. Arbitrary independent int32 accumulators must be added after decoding, which costs more instructions; they cannot be silently packed into the same result word.

[Kelana/Radix.lean](../Kelana/Radix.lean) proves the dot-product identity for any length, the length-16 ternary bounds, signed-byte input fit, exact decoders and the signed-six-bit extraction identity. `two_ternary_dots_radix64` composes them.

Each wave32 accumulator fragment has eight VGPRs per lane. A direct output decode uses one signed bitfield extraction, one add and one arithmetic shift per VGPR: 24 wave-level VALU instructions. The complete comparison is therefore

```
ordinary two-tile cost = 2W + ordinary input preparation
fused two-tile cost    = W + fused input preparation + 24V
```

Here W is the chosen IU8 WMMA charge and V is the charge of a full-rate wave32 vector instruction, if those three instructions share that charge. With fixed weights stored prepacked, both weight-preparation terms move offline and fusion wins only if W exceeds the 24V decoding bill, plus any other dynamic differences. We have proved an algebraic fusion, not a unit-cycle improvement. Leaving results encoded is a separate output contract and cannot be used to hide decoding in this fixed-boundary comparison.

### A tight radix bound

The smallest positive integer radix separating every pair in `[-16,16]²` is 33. Every number in that interval is an actual length-16 ternary dot product against the all-ones activation row, as `every_dot_result_reachable` proves.

For any `1 ≤ r ≤ 32`, pairs `(-16,1)` and `(r−16,0)` collide under `x+ry`. Radix 33 separates all pairs. Three balanced digits at any separating radix require a coefficient at least `1+33+33² = 1123`, which cannot fit in signed int8. Therefore two is the exact payload maximum for this uniform balanced-radix byte-input family. `minimum_radix_is_33` and `no_three_digit_separating_byte_radix` prove the lower bound and exclusion.

Radix 64 uses more numeric range than radix 33 but admits cheaper bitwise decoding. Minimum representation range and minimum hardware cost are different objectives.

## 4. The same row fusion is impossible for arbitrary int8 activations

This negative result applies to the primary Bonsai-like operand domain.

Suppose weights are packed as `a + r a'` into signed bytes for every ternary pair, with positive integer r. The input `a=a'=1` forces `r ≤ 126`. Choose activations

```
b = (r, 1, 0, …, 0).
```

Two possible pairs of weight rows are

```
a  = (-1, 0, 0, …),   a' = (0, 1, 0, …)
a  = ( 0, 0, 0, …),   a' = (0, 0, 0, …).
```

Both packed dot products are zero. Their desired output pairs are `(-r,1)` and `(0,0)`. No decoder can distinguish them, even if it also sees the entire activation row. This is a collision, not an overflow or precision problem.

`no_byte_radix_decoder16` proves the impossibility for the full length-16 dot. It rules out every positive fixed-radix signed-byte row fusion of this form. It does not rule out extra output channels, side information about the weights, multiple instructions, non-radix encodings or activation-dependent weight representations.

## 5. An exact IU4 route exists, but does more work in the current construction

For signed int8 x, Euclidean division gives `x = (x mod 16) + 16 floor(x/16)`. The low digit is unsigned u4 and the high digit is signed i4. Two IU4 matrix products therefore recover the exact byte-input product, followed by a shift-add per output. C can be included in the low partial product when its intermediate bounds permit it.

[Kelana/Nibble.lean](../Kelana/Nibble.lean) proves the digit bounds, dot decomposition and accumulator identity. It also proves the construction worker's useful gather identity

```
((17·(a + 256b)) >> 4) mod 256 = a + 16b,   a,b ∈ {0,1,2}.
```

This packs two byte-spaced trits into adjacent nibbles through multiplication and extraction, without individually converting them. The [construction report](trit-constructions.md) assembles all 128 Halo weights this way and records finite checks. Its full post-peel assembly cost is 92 instructions versus 32 for the current unsigned-byte layout. Two IU4 WMMAs also replace one IU8 WMMA. Narrower fragments alone do not make this a lower-unit-cycle construction.

Under the original runtime-repacking boundary, the 10-bit peel saves 16 core peel instructions across 24 source bytes but adds about 28 input-packing instructions, before output gathering. Offline preprocessing removes those input-packing instructions from the online bill, so the candidate is worth reconsidering. It must still beat the stronger baseline of fully predecoded IU8 weights under an explicit storage budget. These comparisons are not optimality proofs for the incumbent.

## Proof custody and remaining work

The Lean project uses Lean 4.33.0 and its standard library, with no Mathlib dependency. From the repository root:

```sh
lake build
lake env lean research/Audit.lean
```

The audit lists theorem axioms. The checked results use Lean's standard `propext`, `Quot.sound` and, for some theorems, `Classical.choice`. They contain no `sorry`, custom axiom or native-computation axiom. These are integer and representation theorems; they do not claim to verify AMD hardware or a compiled HIP kernel.

The open target is a matching upper and lower unit-cycle bound for the complete packed-ternary matrix map. The next useful step is a costed loading-and-computation candidate under a representation budget and reuse pattern, then a lower-bound argument covering its instruction and transformation class. The bounds here remove bad encoding families and identify exact packing opportunities, but they do not yet bound every gfx1151 program.
