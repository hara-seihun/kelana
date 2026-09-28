# Mathematical view of gfx1151

Kelana's useful abstraction is a typed algebra of maps. An instruction is a map with a domain, codomain and semantics. Different representations can implement the same map. The entire ISA is not a ring or field.

The [instruction index](INSTRUCTIONS.md) gives every canonical instruction in AMD's RDNA 3.5 XML, its description and typed operand signatures. The source includes encoding conditions, aliases, implicit operands and data layouts. Those vendor descriptions are specifications, not Lean definitions or proved theorems. This note gives the mathematical structure in which to formalize them.

## What the types mean

Let `Wₙ = {0, …, 2ⁿ−1}` be a word's bit patterns. Signed interpretation is a separate map:

```
signedₙ(x) = x                    if x < 2ⁿ⁻¹
             x − 2ⁿ             otherwise
wrapₙ(z) = z mod 2ⁿ
satₙ(z) = min(2ⁿ⁻¹−1, max(−2ⁿ⁻¹, z))
laneₚ(x, i) = floor(x / 2^(pi)) mod 2ᵖ
```

The same 32 bits can be `W₃₂`, four unsigned bytes, eight signed nibbles, binary32, a mask or an address. Equal storage size does not make their operations interchangeable. Encoding modifiers select interpretations as well as operations.

| Operations | Mathematical object and law |
| --- | --- |
| Wrapping add, subtract, low multiply | The ring `ℤ/(2ⁿ)`. Not a field for `n > 1`. |
| XOR and AND | Boolean ring `𝔽₂ⁿ`, with componentwise multiplication. Every element is idempotent under AND. |
| Exact bounded integer arithmetic | Restrictions of maps over `ℤ`. Bounds establish when hardware wrap or saturation is irrelevant. |
| Saturating add and multiply | Maps on bounded integers. Do not assume ring laws. |
| Shifts, extraction, insertion, permutation | Maps between bit vectors; some are linear over `𝔽₂`, some discard information. |
| Population counts, SAD, comparisons | Integer-valued maps, metrics or predicates, not ring operations. |
| Floating arithmetic | Maps on floating encodings under a rounding/denormal mode. Not a field and generally not associative. |
| Exact modular matrix arithmetic | Matrices over `ℤ/(2ⁿ)`; fixed-size square matrices form a generally noncommutative ring. |
| Loads, stores, atomics, barriers, branches | State transitions with addressing, execution masks and ordering. |

The ternary set `T = {−1, 0, 1}` is not closed under ordinary addition. `𝔽₃` has three elements but different arithmetic: `1 + 1 = −1` there, while Bonsai needs `1 + 1 = 2`. Use `T ↪ ℤ` and integer accumulation, unless a separate reconstruction theorem justifies modular computation.

## A meaning for every instruction

For a fixed device configuration, describe instruction `I` as a relation

```
⟦I⟧ ⊆ (State × Inputs) × (State × Outputs).
```

State includes registers, EXEC/VCC/SCC, wave size, floating modes, memory, program counter and outstanding memory operations. Legal state predicates include register alignment, lane replication and addressing requirements. A deterministic subset becomes an ordinary state-passing function. Concurrent memory instructions may admit several results; barriers constrain executions rather than produce a useful numeric answer.

This covers every group in the catalogue:

| AMD group | Mathematical interpretation |
| --- | --- |
| SALU | Scalar word/float maps plus scalar flags and special-register updates. |
| VALU | Lane maps lifted over a wave, masked writes, cross-lane maps, packed arithmetic and collective WMMA. |
| SMEM | Scalar address formation and memory/state transitions. |
| VMEM | Per-lane buffer/global/flat/scratch/LDS/image accesses, atomics, address and format conversion. Texture sampling includes its filtering and addressing rules. |
| BRANCH | Program-counter selection, possibly with execution-mask updates. |
| WAVE_CONTROL | Wave-state transitions, waits, synchronization and termination. |
| MESSAGE | Events passed to another hardware component and associated state changes. |
| TRAP | Transfer to trap handling with architectural state. |
| EXPORT | Transfer of selected values to the graphics/export interface. |

The XML's operand list is an interface description, not a complete effect system. An absent implicit EXEC or MODE operand does not mean the instruction ignores that state. Keep the manual's architectural rules alongside the per-instruction record.

Pure mathematics can describe all of this. Purity means we make state explicit; it does not mean we erase it.

## Arithmetic maps worth investigating first

Write results below as exact integers before applying the instruction's specified narrowing or clamp.

```
packed_dot(p, m, a, b, c) = c + Σᵢ<m interpretₚ(laneₚ(a,i)) · interpretₚ(laneₚ(b,i))
sad(p, m, a, b, c)        = c + Σᵢ<m |laneₚ(a,i) − laneₚ(b,i)|
popcount(x)               = Σᵢ<n bit(x,i)
extract(x,o,w)            = floor(x / 2ᵒ) mod 2ʷ
select(mask,a,b)          = (mask AND a) OR ((NOT mask) AND b)
```

Actual shift/width operands have instruction-specific masking and boundary cases. Signed extraction sign-extends. Comparison instructions can produce lane masks rather than scalar Boolean values. Scalar bit operations may also set SCC.

Concrete candidates already in gfx1151's instruction set:

- `V_DOT4_I32_IU8` and `V_DOT8_I32_IU4`: four byte products or eight nibble products plus a 32-bit accumulator. Input signedness matters independently of packed bits.
- `V_PK_MUL_LO_U16`: two independent low-half 16-bit products in a word. This is not ordinary 32-bit multiplication.
- `V_SAD_U8`, `V_SAD_U16`, masked and packed SAD variants: absolute-difference sums, sometimes with sliding windows or narrowing.
- `V_PERM_B32`: byte selection from two words, with extra constant/sign-extension selectors. A representation change can become a shuffle instead of arithmetic.
- `V_PERMLANE16_B32`, `V_PERMLANEX16_B32`, LDS permute instructions: lane redistribution. Include their layout and execution-mask behavior in the map.
- Bitfield, population-count and carry instructions: projections, reductions and carry-aware arithmetic, useful independently of their conventional programming purpose.

Each exact instruction record remains available through `catalogue.py instruction NAME`. A familiar mnemonic is not a license to omit its flags, widths or modifiers.

## WMMA is a map between matrix representations

All six RDNA 3.5 WMMA names describe `16 × 16 × 16` matrix multiply-accumulate:

| A, B element interpretation | C, D element interpretation | Mnemonic suffix |
| --- | --- | --- |
| IEEE binary16 | binary32 | `F32_16X16X16_F16` |
| bfloat16 | binary32 | `F32_16X16X16_BF16` |
| IEEE binary16 | binary16 | `F16_16X16X16_F16` |
| bfloat16 | bfloat16 | `BF16_16X16X16_BF16` |
| signed/unsigned 8-bit integers | 32-bit integer | `I32_16X16X16_IU8` |
| signed/unsigned 4-bit integers | 32-bit integer | `I32_16X16X16_IU4` |

Each name has prefix `V_WMMA_`. IU4 is a native nibble-input operation, not an emulation through IU8. The compiler inventory records the gfx1151 target forms and builtins.

For the integer variants, the mathematical expression of interest is

```
Zᵢⱼ = Cᵢⱼ + Σₖ<16 Aᵢₖ Bₖⱼ.
```

`NEG[0]` and `NEG[1]` independently select signed interpretation for A and B; zero means unsigned. Integer WMMA requires `NEG[2] = 0` and `NEG_HI = 0`. C and D are signed int32, not selected by a third signedness flag. The result map is wrapping int32 without CLAMP, or signed saturation to `[-2³¹, 2³¹−1]` with CLAMP. Thus the manual-level matrix map is `wrap₃₂(Zᵢⱼ)` or the int32 encoding of `sat₃₂(Zᵢⱼ)`. Section 7.5 defines result clamping; section 7.9 and the per-op definitions specify the exceptional WMMA modifier meanings.

A proof over exact integers can avoid overflow distinctions by showing every relevant intermediate stays in range. For ternary A and signed-byte B, each 16-term dot product has magnitude at most `16·128 = 2048`. If `|Cᵢⱼ| + 2048 ≤ 2³¹−1`, every partial sum stays in signed int32 range, regardless of term order. A full-range instruction theorem must retain those clamp and overflow rules rather than silently prove an identity over unbounded integers.

For floating variants, `AB+C` specifies the intended matrix operation, not an equality to real arithmetic or to an arbitrary sequence of scalar FMAs. WMMA supports round-to-nearest-even only. Intermediate precision, accumulation order, denormals, NaNs and signed zeros still belong to the hardware map.

The per-instruction pseudocode saves EXEC, enables all lanes for WMMA, then restores EXEC. It is a whole-wave collective even when the surrounding lane mask is partial. The matrix layout and participating registers must therefore be valid across the whole wave.

### Logical size versus register fragments

AMD's formats require two copies of each A/B matrix in wave32 and four in wave64. A/B per-lane register spans do not change with wave size.

| Element width | Bits in one logical A or B | A or B VGPRs per lane | Wave32 physical bits for A or B |
| --- | ---: | ---: | ---: |
| 4 | 1,024 | 2 | 2,048 |
| 8 | 2,048 | 4 | 4,096 |
| 16 | 4,096 | 8 | 8,192 |

A logical int32 C or D has 8,192 bits. It occupies eight VGPRs per lane in wave32 and four in wave64. C and D may share registers when the implementation permits destructive accumulation; adding their sizes does not establish simultaneous register pressure. Half-precision C/D still use one 32-bit slot per element, with half selection.

Let `L_A`, `L_B`, `L_C`, `L_D` be the specified wave-fragment encodings. A correct native realization satisfies

```
WMMA_hw(L_A(A), L_B(B), L_C(C)) = L_D(WMMA_sem(A,B,C)).
```

The left side operates on lane/register tuples. The right side says what those tuples mean. Replication makes these layouts embeddings into a constrained subset of register states, not bijections onto arbitrary register files. The manual's layout diagram uses column-major A and row-major B/C/D.

Composition also has a scheduling condition. Section 7.9.1 requires one V_NOP or independent VALU instruction when a WMMA result D overlaps the next WMMA's A or B. The usual D-to-C accumulation has different stall rules. A denotational identity alone does not remove a hardware hazard.

For a ternary 16×16 matrix there are `3²⁵⁶` possibilities. Any lossless fixed-length encoding needs at least `ceil(256 log₂ 3) = 406` bits. That is a storage lower bound, not a promise of a 406-bit WMMA input. Current WMMA expects its own layouts. Saving registers or compute requires a new hardware computation on a different representation, not only a better compressor.

IU4 halves the A/B fragment width relative to IU8 while computing the same number of matrix products. It does not by itself establish twice the throughput. Bonsai's activation range also matters: replacing byte weights with nibbles cannot make byte activations fit an IU4 input. Splitting digits, changing scales or using a different identity needs its own equivalence or error argument.

## What we actually want to prove

Let `F : X → Y` be a desired operation, `E_X : X → R_X` and `E_Y : Y → R_Y` be representations, and `H : R_X → R_Y` be a hardware program. The useful theorem is

```
∀ x ∈ Valid, H(E_X(x)) = E_Y(F(x)).
```

This commuting equation lets a following operation consume `E_Y(F(x))` without decoding. A decoder theorem `D_Y ∘ H ∘ E_X = F` alone does not establish that intermediate encoded operations compose. For redundant representations, replace encoding equality by an explicit represents relation.

An isomorphism is available when the encoding is bijective onto its image and the chosen operations are preserved. We usually need less: an embedding, a homomorphism for selected operations, or a simulation between representations. These weaker claims are often exactly what makes unusual hardware use possible.

Example: `E(a,b) = a + 2ˢb`. If `a+a' < 2ˢ` and the whole result fits the machine word, then

```
E(a,b) + E(a',b') = E(a+a', b+b').
```

Without those bounds, carries couple the fields. For multiplication the cross-terms are

```
(a + 2ˢb)(c + 2ˢd) = ac + 2ˢ(ad+bc) + 2²ˢbd.
```

Sometimes these cross-terms are the desired outputs. Sometimes they contaminate them. Polynomial encodings, digit bounds and selected coefficient extraction make the distinction precise. Packed FP constructions also need normalization, rounding and exponent-range hypotheses; the mantissa and exponent are not independently writable arithmetic units.

Lean should express these valid subsets and preservation laws. It can then prove that a different representation, a composed instruction sequence or an omitted operation preserves the requested map. It need not prescribe which construction an agent should try.

Correctness and cost remain separate. To call a construction optimal, define the admitted hardware programs and a cost such as latency, throughput, register occupancy or memory traffic, then prove a lower bound that the construction attains. Instruction count alone cannot establish hardware runtime optimality. Approximate model inference adds a specified observation/distribution and an error theorem, such as a KL bound, above these local maps.
