# Choose the carrier and consumer together

This experiment replaces a constructed family of gated networks with a shared integer carrier and a factored consumer. No gate value, up value or original hidden unit is recovered. The source networks have three ternary inputs, ternary gate and up weights, and prepared integer output weights. They are not fitted Bonsai weights.

The result is an exact six-parameter family, an assembled gfx1151 data region, and a reusable exact-linear-algebra search. There is no native timing result.

The [fixed trained-region follow-up](TRAINED.md) now tests this carrier on real weights from layers 0 and 10. It fails exact transfer, with most approximation error already forced by its collisions. The follow-up also provides a program-independent lossy-capacity bound and compares the smooth region with its quantized continuation.

## The search tool

Enumerate the reachable inputs once. Let the columns of `A` be source functions evaluated there. A candidate carrier `h` and a consumer feature list give a matrix `B`, with columns `phi_j(h(x))`. These features can be instruction truth tables, tuple-carrier functions, or polynomials. The tool does not require recognizable source intermediates.

Compute a left annihilator `L` of `A`, so `ker L = image A`. Then solve

```
L B u = 0.
```

Every solution gives both a consumer and a source expression for the same function. A basis of `B ker(LB)` describes the whole shared family at once. Solving one source network after another is unnecessary.

There is a trap: `dim ker(LB)` counts coefficient vectors, not functions. On a ternary carrier, `h^3-h=0` adds a null direction without adding any computation. `joint.py` takes an independent basis of the evaluated image and supplies source and consumer coefficient witnesses. Tests compare its dimension with the separate identity

```
dim(image A ∩ image B) = rank A + rank B - rank [A B].
```

For a fixed target, `target_coefficients` tests membership in the supplied feature space. `collision_witness` gives a stronger rejection when two inputs have equal carrier values but different target values. That rules out every deterministic decoder of that carrier, not just the declared feature list.

The method is exact over rational values on the enumerated domain. It does not enumerate all ISA programs or minimize their cost. Numeric labels remain in the search: equal fibers do not make polynomial or instruction consumers interchangeable.

## The construction

Supply the input already packed as

```
q = (x+1) + 3(y+1) + 9(z+1),   x,y,z ∈ {-1,0,1}.
```

The producer is

```
h = signed_bfe32(27*q - 320, 6, 4)
  = floor(27*q/64) - 5.
```

It has eleven reachable states, `-5..5`, and is odd under input negation. The original 19-component source basis distinguishes all 27 inputs. This is genuine information loss, not a bijection of the original hidden vector.

The following functions all belong to the source space:

```
h, h^3, h^5, h^7, h^9,
e(h) = [h != 0] + 2[abs(h) == 5].
```

The sixth has a useful identity:

```
e(h(x,y,z)) = y² + yz + z².
```

Consequently every function

```
F_a = a0*h + a1*h³ + a2*h⁵ + a3*h⁷ + a4*h⁹ + a5*e(h)
```

is exactly a bias-free ReLU-gated network `sum c_i relu(g_i·x) x_j`. `results.json` contains the 19 source atoms and the full 19×6 coefficient matrix. The output coefficients can be large; this is not a claim that the source down weights remain ternary.

The coefficient search finds dimension six even when the consumer may assign *arbitrary* rational labels to the eleven states. Our six observers therefore exhaust the source functions that this particular carrier preserves. This is an exact rank calculation, not an ISA optimality claim. All odd labelings on `-5..5` interpolate in the five odd powers over Q. The remaining preserved even direction is `e`.

The family contains `h`, so jointly its consumers distinguish all eleven carried states. No smaller deterministic carrier can preserve the entire family. A particular choice of coefficients may need fewer states.

A concrete exclusion prevents overgeneralizing. Inputs `(-1,-1,-1)` and `(0,-1,-1)` both give `h=-5`, but the original atom `relu(-x-y-z)*x` gives `-3` and `0`. It cannot be recovered, and is never recovered by this program. Arbitrary source output weights cannot pass through this interface.

## The consumer and its instructions

Evaluate the odd part as

```
z = h*h
p = a4
p = z*p + a3
p = z*p + a2
p = z*p + a1
p = z*p + a0
odd = h*p
```

That is six multiply/MAD data instructions. Together with the producer, the five-parameter subfamily takes eight data instructions in `region.s`.

For the sixth observable, two-bit entries in the fixed 22-bit word `0x355157` encode `e(-5)..e(5)`. It takes a shift-add for the bit address and one BFE, followed by a MAD to add `a5*e`. `full-region.s` has eleven data instructions for the six-parameter family. This register lookup computes a required observable directly; it does not restore hidden units or trits.

Both files assemble for gfx1151. Each lane owns one input. The odd variant uses registers `v0..v7`; the full variant adds `v8` for `a5` and reuses the square register for the sixth observer. The constants `-320` and `0x355157` use literal encodings. These are straight-line data regions, not launchable kernels or measured cycle counts. Packing the input, placing coefficients, loading and storing values, dependency scheduling and reuse across outputs are additional costs.

For integer `a_i ∈ [-7,7]`:

- `|h| ≤ 5` and `h² ≤ 25`.
- Every Horner multiplicand is bounded by `7(1+25+25²+25³+25⁴) = 2,848,307 < 2²³`.
- The complete output is bounded by `14,241,556 < 2³¹`.

Thus signed24 multiply/MAD operand truncation and 32-bit result wrapping are inert in this box. The scalar instruction emulator checks 8,019 endpoint/zero coefficient cases. This finite check supplements the range argument; it is not exhaustive over all `15^6` coefficient settings. Outside that box the mathematical identity remains valid while this particular native lowering can overflow or truncate.

## What was searched and proved

`discover.py` reuses the declared 1,565-map producer grid from `observer-search/inverse_labels.py`, centers each numeric map at the zero input, and searches consumers in `span(h,h²,h³)`. It requires 3 to 26 reachable carrier states and dependence on each of the three input coordinates. Nineteen numeric maps preserve at least two independent functions. Some are differently labelled versions of the same partition; they are deliberately not merged into one cost claim. The selected multiplier-27 map supports the wider family above. Its centering folds into the producer's immediate, avoiding an extra subtraction.

[`JointObserver.lean`](../../../Kelana/JointObserver.lean) is generated from the exact source coefficient witnesses. Lean checks all six basis networks on all 27 inputs, including the packed producer and register-table observable. It then proves the whole-region identity for arbitrary integer family coefficients using an algebraic Horner identity. The proof is about those explicit bitvector observations and integer arithmetic, not GPU execution or latency.

```
make reproduce   # ~3 seconds: exact search, assembly, targeted Lean build
make test        # seven regression tests, ~0.2 seconds
```

Dependencies are Python with SymPy, LLVM's AMDGPU assembler, and the repository's pinned Lean toolchain. All prepared artifacts live here or in the linked Lean module. No data directory or GPU state is needed.

## What this buys the larger investigation

We now have a search that chooses a boundary representation *with its continuation*, and returns an entire family of source functions it replaces. It also says which source functions cannot cross that boundary. The next fixed-weight experiment can ask whether a required region lies in one of these families instead of assuming every original hidden channel must survive.

The present match is a constructed three-input ReLU family. It supplies neither a Bonsai SiLU identity nor a new full-model TPS number. The trained follow-up rejects this eleven-state carrier for exact transfer and quantifies its losses. A different representation must preserve the required distinctions before a native comparison is warranted. Enumeration still scales with the finite domain; extending to large regions needs factored constraints or symbolic identities rather than a full `3^n` table.
