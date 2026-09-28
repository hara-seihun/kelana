# Exact 2×2 ternary multiply-add in two GPU instructions

## Result and scope

For arbitrary 2×2 matrices A, B and C with entries in {-1,0,1}, compute D = AB + C exactly. Our gfx1151 construction produces a lossless packed representation of all four integer outputs using:

1. `V_DOT4_I32_IU8`
2. `V_DOT8_I32_IU4`

The previous packed core used two DOT8 instructions plus a shift-or. An elementwise int4 baseline uses seven arithmetic instructions for the same output representation. These counts exclude input preparation, memory operations and output decoding.

The two-instruction construction is proved in Lean, exhaustively checked over all 531,441 input triples, and assembled for gfx1151. It is not a global optimality proof or a measured two-instruction throughput result.

## Cost boundary

A is an arbitrary reusable weight matrix. Its load-time preparation may depend on A and is amortized over arbitrarily many uses.

B and C change each use. For this experiment, both implementations receive a free packing pass. The construction needs only A-independent bit wiring: copies of input bits, constants and fanout. Packing does not multiply A by B or compute any output.

Free dynamic packing is an explicit experimental allowance. Unlike one-time weight preparation, its cost would not vanish through reuse if charged. Memory traffic and storage also remain recurring costs in a complete implementation.

## 1. Lossless output representation

Write the output in column j as:

```
d0j = a00*b0j + a01*b1j + c0j
d1j = a10*b0j + a11*b1j + c1j
```

Every d lies in [-3,3]. Choose signs h,l in {-1,+1}, prepared from A, and encode a column as:

```
pj = (l*d1j + 3) + 7*(h*d0j + 3)
```

Both radix-7 digits lie in [0,6], so pj lies in [0,48]. Decoding is exact:

```
d0j = h*(pj // 7 - 3)
d1j = l*(pj % 7 - 3)
```

The returned 32-bit word is:

```
P = p0 + 256*p1
```

Its low two bytes hold the two column codes. The remaining bits are zero. Signs h,l are representation metadata shared with the consumer. Neither construction materializes four individual integer outputs; decoding to another format must be charged to both if required.

## 2. Fuse each column algebraically

Encode each input trit t as u(t)=t+1 in {0,1,2}. Define:

```
k0 = l*a10 + 7*h*a00
k1 = l*a11 + 7*h*a01
k  = [k0, k1, 7*h, l]
b  = 24 - (k0 + k1 + 7*h + l)
uj = [u(b0j), u(b1j), u(c0j), u(c1j)]
```

Substitution gives:

```
pj = dot(k, uj) + b
```

Choose the first orientation in this list for which k0,k1 fit signed int4:

```
(h,l) = (+1,+1), (+1,-1), (-1,+1)
```

One always works. Each coefficient starts in [-8,8], with only +8 disallowed. The first orientation fails only at a column whose two A entries are (+1,+1); the second fails only at (+1,-1). If both fail, the two columns must contain those two patterns. The third then gives coefficients -6 and -8. The other two coefficients, 7*h and l, always fit.

Thus every entry of k lies in [-8,7], and b lies in [0,48]. This orientation proof and the lossless codec were already part of the three-instruction construction.

## 3. Remove the final shift-or

The new observation is to split the output byte-position factor 256 as 16×16, distributing it across both operands of the first dot.

First instruction, signed int8 weights and unsigned byte inputs:

```
r = DOT4_I32_IU8(16*k, 16*u1, 257*b)
  = 256*dot(k,u1) + 257*b
  = 256*p1 + b
```

Second instruction, signed int4 weights and unsigned nibble inputs:

```
P = DOT8_I32_IU4([k,0,0,0,0], [u0,0,0,0,0], r)
  = dot(k,u0) + 256*p1 + b
  = p0 + 256*p1
```

Here `[k,0,0,0,0]` means the four entries of k followed by four zero lanes, likewise for u0.

The first dot writes the accumulator operand consumed by the second. No separate shift, output addition or OR is needed.

### Operand legality

- `16*k` lies in [-128,112], exactly fitting signed int8.
- `16*u1` is 0,16 or32, exactly fitting unsigned bytes.
- k fits signed int4; u0 fits unsigned int4.
- All arithmetic fits int32. A simple bound is `0 <= r <= 256*48+48 = 12336`; the final P has the same bound.
- Clamp is disabled; the input signedness controls are selected independently.

These facts connect the integer algebra to the ISA rather than merely counting abstract dot products.

## 4. Packing is wiring, not hidden computation

Starting with the eight two-bit trit codes in this order:

```
b00, b10, c00, c10, b01, b11, c01, c11
```

prepare two dynamic words:

- Column 0 codes occupy nibble bit positions 0,4,8,12 for the DOT8 operand.
- Column 1 codes occupy byte bit positions 4,12,20,28 for the prescaled DOT4 operand.

All remaining bits are zero. This wiring is identical for every A. The 16× scaling inserts zeros below the codes; it performs no runtime arithmetic under the granted packing model.

## 5. What improvement is established

Let D4 and D8 denote the unit-work charges of the two dot opcodes, and S the shift-or charge:

```
Previous packed core: 2*D8 + S
New packed core:      D4 + D8
Saving:               D8 + S - D4
```

The new core is strictly cheaper if D4 <= D8 and S > 0. Two instructions versus three is unconditional as an instruction count; the unit-cycle comparison is conditional on those hardware charges.

The earlier three-instruction core was GPU-benchmarked against the seven-instruction elementwise baseline. It achieved 1.60–1.78× streaming throughput and 1.79–1.81× register-replay throughput. Those measurements do not benchmark this newer two-instruction core.

When dynamic packing is charged, the new core needs an extra spreading step, so the free-packing instruction improvement does not establish a win for that different boundary.

## 6. Optimality at the byte-pair endpoint remains open

[One signed-byte dot](radix64/README.md) computes the entire exact matrix map
with the same free, A-independent wire-packing allowance when the final consumer
accepts two radix-7 column codes separated by **six** bits rather than eight.
Its result is `p0 + 64*p1`, not this construction's `p0 + 256*p1`;
conversion and dynamic packing must be priced before calling it a native win.
It resolves the whole-map question under that new output observation, not the
fixed byte-pair question here.

We have a restricted lower bound excluding one 4-bit-lane dot with shared input wiring. A wire bit can appear in several positions of one lane; its lane coefficient therefore lies in [-8,15]. A nibble weight also lies in [-8,15] across signedness choices. Their product lies in [-120,225]. Eight lanes can change an input-bit coefficient by at most 2760 between prepared weight matrices.

The required packed map forces an absolute coefficient change of 3072 or4096 between A=0 and A=[[1,0],[1,0]], under the allowed orientations. Neither gap can be hidden by int32 wrapping. This excludes the specified single-DOT8 affine implementation class.

It does not exclude one byte-lane DOT4, nonlinear instructions, different output codecs, or arbitrary GPU programs. One DOT4 with shared wiring is still open. With A-dependent wiring, one-instruction witnesses already exist for particular A matrices, including the identity.

## Reproduction and source custody

Repository: `/path/to/workspace/projects/kelana`.

- `Kelana/Toy2.lean`: codec, orientation existence, original fused-column correctness.
- `Kelana/Toy2Optimality.lean`: `fused_correct`, operand bounds, conditional cost improvement, and restricted lower bounds.
- `research/toy2/optimality/construction.py`: exhaustive replay of all `3^12 = 531441` input triples.
- `research/toy2/optimality/construction-results.json`: recorded exhaustive result.
- `research/toy2/optimality/kernels.s` and `assemble.py`: native instruction forms and opcode-count checks.
- `research/toy2/optimality/NOTES.md`: search model, one-instruction witnesses and unresolved cases.
- `research/toy2/BENCHMARK.md`: measurements of the previous three-instruction construction.

From the repository root:

```sh
lake build
python3 research/toy2/optimality/construction.py
python3 research/toy2/optimality/assemble.py
```

Lean 4.33.0, standard library only. The correctness theorem uses no `sorry`; its reported axioms are `propext`, `Classical.choice` and `Quot.sound`. Exhaustive instruction replay is a separate check from the Lean algebra and from native assembler acceptance.
