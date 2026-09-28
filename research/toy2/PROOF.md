# A packed implementation of the 2×2 ternary matrix multiply-add

## Result in one paragraph

For `D = AB + C`, where every entry of the 2×2 matrices A, B and C is in `{-1,0,1}`, we constructed an exact gfx1151 implementation that uses **two native int4 dot instructions instead of four**. Each dot computes an encoded pair of output entries. Both implementations have identical packed input and output contracts. The specified baseline uses 13 vector instructions; the construction uses 9, deleting two dot instructions and two multiply-add instructions without adding another instruction type. Lean checks the algebra, representation bounds and symbolic cost improvement. This proves an improvement over that baseline, not global optimality.

## 1. The problem and cost boundary

Let

```
A = [a00 a01]    B = [b00 b01]    C = [c00 c01]
    [a10 a11]        [b10 b11]        [c10 c11]
```

All twelve input entries are trits. The required output is ordinary integer matrix arithmetic:

```
d00 = a00*b00 + a01*b10 + c00
d10 = a10*b00 + a11*b10 + c10
d01 = a00*b01 + a01*b11 + c01
d11 = a10*b01 + a11*b11 + c11.
```

Each output lies in `[-3,3]`. We preserve those seven values exactly. There is no rounding, saturation or ternary requantization.

A is an arbitrary weight input. A load transformation may prepare coefficients and representation metadata once. B and C are changing inputs. For N uses of one loaded A, the objective is limiting average execution-unit work:

```
limsup(N → infinity) [finite preparation cost + recurring work for N uses] / N.
```

Finite one-time preparation therefore costs zero in this objective. Nothing in the theorem assumes a particular literal A. Both implementations count the same recurring input expansion and produce the same packed output. Loads, stores and launch overhead are outside the arithmetic cores and common to the comparison.

This is a per-lane packed-word experiment using native dot instructions, not a mostly empty 16×16 WMMA.

## 2. Common dynamic input format

Encode a trit t by the unsigned two-bit value `u=t+1`, which is 0, 1 or 2.

One 16-bit word contains eight such codes, ordered from least significant field upward as

```
b00, b10, c00, c10, b01, b11, c01, c11.
```

The lower byte is one B/C column; the upper byte is the other. Bits above bit 15 are zero.

Both programs expand this word into eight unsigned int4 lanes with the same network:

```c
x = (x | (x << 8)) & 0x00ff00ff;
x = (x | (x << 4)) & 0x0f0f0f0f;
x = (x | (x << 2)) & 0x33333333;
```

On gfx1151, each line is one `V_LSHL_OR_B32` and one `V_AND_B32`: six instructions total. No input code changes value. The eight nibbles are still in the order above.

The improvement below does **not** eliminate this shared expansion. It changes what the arithmetic instructions compute.

## 3. Encode a pair of outputs in radix 7

Consider one output column and abbreviate its entries by d0 and d1:

```
d0 = a00*b0 + a01*b1 + c0
d1 = a10*b0 + a11*b1 + c1.
```

Choose signs `h,l ∈ {-1,+1}` and define

```
P = (l*d1 + 3) + 7*(h*d0 + 3).
```

Because each d is in `[-3,3]`, both parenthesized quantities are digits in `[0,6]`. Hence

```
0 <= P <= 48.
```

The encoding is lossless:

```
d0 = h * (floor(P / 7) - 3)
d1 = l * ((P mod 7) - 3).
```

To see this, the low digit `l*d1+3` is smaller than 7, so division and remainder recover the two digits separately. Also `h*h = l*l = 1`.

The output word is

```
P_column0 | (P_column1 << 8).
```

The bytes do not overlap because each P is at most 48. The signs h and l are explicit metadata in the prepared weight representation, shared by both implementations. A consumer interprets the output using that metadata. If an application requires a different output format, its decoding/conversion cost must be added to both sides.

## 4. Compute P directly

Substitute the matrix formulas into the encoding:

```
P = l*(a10*b0 + a11*b1 + c1) + 3
    + 7*h*(a00*b0 + a01*b1 + c0) + 21.
```

Collect coefficients:

```
k0 = l*a10 + 7*h*a00
k1 = l*a11 + 7*h*a01

P = k0*b0 + k1*b1 + 7*h*c0 + l*c1 + 24.
```

The dynamic operands are the unsigned trit codes, so replace each t by `(t+1)-1`:

```
bias = 24 - (k0 + k1 + 7*h + l)

P = k0*(b0+1) + k1*(b1+1)
    + (7*h)*(c0+1) + l*(c1+1) + bias.
```

This expression computes P without first computing either d0 or d1. It is exactly a signed-weight/unsigned-input dot product with four live lanes and a constant accumulator.

The remaining issue is whether all four coefficients fit signed int4.

## 5. A sign orientation always makes the coefficients fit

Signed int4 represents `[-8,7]`. Since the weights are trits, each `k = l*a_low + 7*h*a_high` lies in `[-8,8]`. Only the value +8 is invalid.

Try the following orientations in order:

1. `(h,l) = (+1,+1)`.
2. `(h,l) = (+1,-1)`.
3. `(h,l) = (-1,+1)`.

Choose the first for which both k0 and k1 are in `[-8,7]`.

**Proof that one succeeds:**

- The first orientation fails in a column only when `a_high=+1` and `a_low=+1`.
- The second fails in a column only when `a_high=+1` and `a_low=-1`.
- A single column cannot cause both failures. Thus if both orientations fail, the two columns must have high entries +1 and opposite low entries +1 and -1.
- Under the third orientation, the coefficients are then `a_low-7`, giving -6 and -8. Both fit.

The other coefficients are `7*h` and l, which always fit signed int4. Preparation depends only on A.

Across the 81 possible A matrices, the implementation selects the first orientation 64 times, the second 15 times and the third twice. Those counts are a finite check, not the basis of the proof.

Radix 7 matters. With radix 8, the matrix `[[1,1],[1,-1]]` produces a coefficient +9 or -9 under every row-sign choice. Signed int4 cannot represent it.

## 6. Map the formula to gfx1151 instructions

`V_DOT8_I32_IU4` multiplies eight packed 4-bit lanes and adds an int32 accumulator. Its input signedness controls are independent.

Use:

- signed int4 weight lanes;
- unsigned int4 activation/C lanes;
- no clamp;
- the prepared bias as the accumulator.

For the first column, pack the signed coefficients

```
[k0, k1, 7*h, l, 0, 0, 0, 0].
```

For the second column, pack

```
[0, 0, 0, 0, k0, k1, 7*h, l].
```

Both dot instructions read the same expanded dynamic input word. Their results are the two P values. One shift-or joins the output bytes.

The prepared bias lies in `[0,48]`. All products and partial sums are far inside int32 range. The final P values lie in `[0,48]`, so neither arithmetic overflow nor output-packing carries affect the result.

The packed arithmetic core is therefore:

```
6 instructions: common two-bit-to-four-bit input expansion
2 instructions: native signed-i4 × unsigned-u4 dot products
1 instruction:  combine output bytes
9 total.
```

The individual d00, d10, d01 and d11 exist in the mathematical specification, but the packed program never materializes them as four int32 results.

## 7. The baseline is not deliberately wasteful

The baseline computes each oriented output digit independently with one int4 dot. It already folds C into a dot lane and all trit-code offsets into a prepared bias.

For the high row:

```
coefficients = [h*a00, h*a01, h, 0]
bias_high = 3 - h*(a00 + a01 + 1)
```

The dot result is `h*d0+3`.

For the low row:

```
coefficients = [l*a10, l*a11, 0, l]
bias_low = 3 - l*(a10 + a11 + 1)
```

The dot result is `l*d1+3`.

Apply those two dots to each column, then construct the same radix-7 output bytes. Each byte uses one `V_MAD_U32_U24` for `low + 7*high`, followed by one common shift-or to join the bytes. The operands of those multiply-adds are at most 7, so the 24-bit multiply semantics introduce no truncation.

The baseline is:

```
6 instructions: common input expansion
4 instructions: one native int4 dot per matrix entry
2 instructions: radix-7 output-pair construction
1 instruction:  combine output bytes
13 total.
```

## 8. Unit-cycle comparison

Let the nonnegative per-instruction execution-unit charges be

```
S = charge of V_LSHL_OR_B32
A = charge of V_AND_B32
D = charge of V_DOT8_I32_IU4
M = charge of V_MAD_U32_U24.
```

Then

```
baseline = 4*S + 3*A + 4*D + 2*M
packed   = 4*S + 3*A + 2*D
saving   = 2*D + 2*M.
```

The construction removes operations without exchanging them for a differently priced operation. Thus it is strictly cheaper in this additive unit-cycle model whenever the dot charge is positive. No equality between opcode charges is assumed.

This is not a claim of a 13/9 wall-clock speed ratio. The model measures total charged work, not latency, scheduling stalls or a benchmark's throughput. Both programs use the same input/output interface and a common termination instruction. The candidate also needs fewer prepared coefficient words and fewer result temporaries.

For any finite preparation costs Lp and Lb, the strict recurring saving eventually dominates:

```
Lp + N*packed < Lb + N*baseline
```

for sufficiently large N. Lean proves this consequence as well.

## 9. Worked example

Take

```
A = [1  1]    B = [1 -1]    C = [ 1 0]
    [1 -1]        [0  1]        [-1 1].
```

The reference result is

```
D = [2  0]
    [0 -1].
```

Preparation chooses `h=-1`, `l=+1`, giving

```
k0 = -6
k1 = -8
coefficients = [-6,-8,-7,+1]
bias = 44.
```

The dynamic input word is `0x9826`. Its nibble expansion is `0x21200212`.

For column zero, the input codes are `[2,1,2,0]`:

```
P0 = -6*2 - 8*1 - 7*2 + 1*0 + 44 = 10.
```

For column one, the input codes are `[0,2,1,2]`:

```
P1 = -6*0 - 8*2 - 7*1 + 1*2 + 44 = 23.
```

The packed output is `0x170A`. Division and remainder by 7, followed by the prepared row signs, recover exactly `[[2,0],[0,-1]]`.

## 10. Formal and executable evidence

The repository is `/path/to/workspace/projects/kelana`.

### Lean

`Kelana/Toy2.lean` contains:

- `chosen_fits`: one of the three orientations fits signed int4.
- `packed_column_identity`: the fused dot computes the required encoded column.
- `baseline_equals_packed`: equality with the independently computed output digits.
- `bias_bounds`, `encode_column_bounds`: representation bounds.
- `decode_column`, `packed_correct`: lossless decoding and the complete matrix identity.
- `exact_saving`, `strictly_cheaper`: the symbolic cost comparison.
- `load_cost_cannot_erase_saving`: finite setup cannot erase the limiting improvement.

`Kelana/Amortization.lean` formalizes vanishing setup cost through reciprocal tolerances, without introducing a floating-point approximation or an assumed asymptotic axiom.

The project uses Lean 4.33.0 and the standard library. The checked proofs contain no `sorry` or custom axioms. The arithmetic proofs model the instruction operations mathematically; they are not a formally verified assembler or hardware circuit.

### Exhaustive checks

`research/toy2/check.py` independently compares the reference matrix calculation, baseline and packed construction over all **531,441** valid A/B/C combinations. It also checks the input expansion over all **65,536** 16-bit words. `check-results.json` records the counts and script hash.

### Real instruction encodings

`research/toy2/kernels.s` gives both gfx1151 cores. `assemble.py` runs LLVM's actual gfx1151 assembler and disassembler and checks the opcode counts. `assembly-results.json` records 13 versus 9 instructions and the source hash.

### Native GPU check

`gpu_check.cpp` provides an exhaustive native-instruction correctness check. It compiled, but shared GPU admission denied execution because resident reservations left insufficient headroom. `gpu-status.json` records this. There is no native GPU execution or timing result in this bundle.

Reproduction commands, from the repository root:

```sh
lake build
lake env lean research/Audit.lean
python3 research/toy2/check.py
python3 research/toy2/assemble.py
bash research/toy2/gpu-check.sh
```

## 11. Scope and next questions

This result establishes that a representation-aware construction can compute the same map with strictly less charged recurring work than the specified elementwise int4 baseline. It is an example of composing two logical results inside an existing instruction, not a new matrix-multiplication complexity result.

It does not prove:

- that nine instructions is globally minimal;
- that input expansion is necessary;
- that the dot-instruction family is best;
- that a different output contract has the same saving;
- that a larger model inherits this improvement;
- a measured wall-clock speedup.

The next search can replace the shared expansion, exploit another instruction family, or compose this output encoding directly with its consumer. Any lower-bound argument must allow those alternatives rather than impose the baseline's intermediate matrix values.
