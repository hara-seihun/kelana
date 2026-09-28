# Whole-map search on three trits

A complete gated ReLU network on three ternary inputs has 27 states. This
directory searches for short straight-line programs producing its exact output,
without preserving gate, up or hidden values. Individual SMT queries exhaust
their declared component multisets when they return unsat; the overall search
has timeouts and unrun queries, so it does not establish a global optimum.

The short answer: **one `ds_bpermute_b32`**, when the producer hands over the
input as a pre-scaled radix-3 word, and **two instructions** from a byte-packed
or dense radix-3 word. These counts are data instructions; table setup and the
required wait are accounted for separately below. The map is checked exactly
on all 27 states for 206 networks, and both shapes are checked on gfx1151.

The bounded negatives are specific. Tested register-window templates from the
[two-trit construction](../../ffn/contracted-map/README.md) fail on two panel
maps. No multiply-by-constant alone turns the two-bit packed input into an
injective gather index. The general single-VALU sweep is incomplete. No
pre-lookup index with exactly the fibers of a non-injective panel target was
found, but some queries remain unexplored. The final lookup's output does have
the exact target fibers whenever the constructed program is correct.

## The family and the map

```
F(x) = sum_i c_i * relu(g_i . x) * (u_i . x),   x in {-1,0,1}^3
```

with `g_i, u_i` ternary, `c_i` in `{-1,+1}`, integer arithmetic, no bias, no
output scale. Width `h` is a parameter and is stated with every result. The
observed result is the integer `F(x)`; nothing else is observed.

[`model.py`](model.py) records the structure this family has on the cube.
The [exact rank certificate](RANK.md) replaces the sampled rank claim: all 676
nonzero ternary gate/up atoms span **exactly 19** dimensions over the 27 points.
The even part `F(x) + F(-x)` is a homogeneous quadratic, the reflection law
[`TernaryFFN.lean`](../../../Kelana/TernaryFFN.lean) proves. Six quadratic
coefficients and thirteen odd pair values give an upper bound of 19; a 19 by 19
atom matrix has determinant 24 modulo 1000003. Evaluating the whole gated map at
19 chosen inputs then reconstructs its other eight nonzero values exactly. This
saves seven of 26 network evaluations during table generation, though it does
not reduce the 27-lane runtime lookup table. In the earlier random panel, width
increases image size while its sampled linear span already attains 19:

| width | 1 | 2 | 4 | 8 | 64 | 256 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| mean distinct values over 27 states | 4.4 | 5.9 | 7.7 | 9.8 | 17.2 | 21.1 |
| max observed | 5 | 9 | 12 | 15 | 23 | 27 |
| rank of the realized maps | 19 | 19 | 19 | 19 | 19 | 19 |

The panel in [`panel.py`](panel.py) is indexed by image size rather than width.
Image size is a useful capacity screen; the arrangement of fibers and the input
encoding also matter, and these searches do not isolate a universal cost law.

## The input word is the coordinate system

Every result names the encoding it starts from. Nothing in the search recovers
an individual trit: the packed word is the input coordinate, and the components
are maps on it.

| contract | word | who pays for it |
| --- | --- | --- |
| `packed2` | signed two-bit codes at bits 0,2,4 (`-1 -> 3, 0 -> 0, +1 -> 1`) | the layout the two-trit observer result uses |
| `bytes` | one signed byte per trit in lanes 0,1,2 | a byte-lane producer |
| `radix3` | dense `q = (x0+1) + 3(x1+1) + 9(x2+1)`, 0..26 | a producer that accumulates in base 3 |
| `radix3x4` | `4q` | the same producer choosing its output codes pre-scaled |
| `balanced4` | `4 * (13 + x0 + 3*x1 + 9*x2)` | same, in balanced ternary |
| `split` | three separate registers, one trit each | no packing done yet |

`radix3x4` and `balanced4` denote the same numeric input encoding. Their
construction starts with that encoding already available; whether a preceding
producer can emit it at no extra cost is a separate integration question. From
`packed2`, conversion is part of the search, not a free operation.

## Constructions

[`construction.py`](construction.py) holds all three and checks them on all 27
states for the six panel networks plus 200 random networks of widths 1 to 256:
**5562 cases, zero mismatches.**

### One instruction, from a pre-scaled radix-3 word

```text
ds_bpermute_b32  v_out, v_addr, v_table
```

Lane `j` of the wave holds `F` at the input whose address selects lane `j`. Each
lane reads the entry its own input names. That is the whole map: no arithmetic,
no selector, no table in memory.

It works because of three facts in the RDNA 3.5 manual, section 12.5.2, all
three confirmed on the device by [`bpermute_probe.hip`](bpermute_probe.hip):
`Dst[0..31] = src[index[0..31]]`, only index bits [6:2] are used, and `offset0`
is added to the index before use. Twenty-seven states fit in 32 lanes with five
to spare, and the ignored low two bits and high bits mean the address arithmetic
may overflow freely outside its five-bit window.

### Two instructions, from byte-packed trits

```text
v_dot4_i32_iu8   v_addr, v_x, 0x00240C04, 52 neg_lo:[1,1]
ds_bpermute_b32  v_out, v_addr, v_table
```

`0x00240C04` is the signed byte word `(4, 12, 36, 0)`, which is `4 * (1, 3, 9)`:
the instruction computes four times the balanced-ternary value of the input,
plus the inline constant `4 * 13`. The coefficient word does not depend on the
network. It is the same constant for every map in the family, so the only
function-specific state in the program is the table VGPR.

The solver found this shape, not a person. It also found
`v_dot4_i32_i8 v_addr, 0x0042C6EC, v_x, v_x`, which feeds the input word in as
the accumulate operand as well, and `v_dot4_u32_u8` reading the trit bytes as
`0, 1, 255`. All three are recorded in
[`results/search-w256i27-bytes-lane5-refine-1.json`](results/).

### Two instructions, from the dense radix-3 word

```text
v_lshlrev_b32    v_addr, 2, v_q
ds_bpermute_b32  v_out, v_addr, v_table
```

Twelve of the 19 explored single instructions work here, because any of them can
scale `q` into the lane field. The list is in
[`results/search-w256i27-radix3-lane5-refine-1.json`](results/).

### What these cost

Per wave, per weight set, amortized over every input the wave processes:

- one table VGPR per lane across a wave32, 1,024 allocated bits, of which
  27 lanes hold 864 bits of function-specific values;
- materializing it, which is one `global_load_b32` with a lane-varying address,
  or a broadcast sequence if the values are computed;
- one 32-bit literal or SGPR for the coefficient word in construction B.

Per input: the instructions listed, plus `s_waitcnt lgkmcnt(0)` before the
result is consumed. `ds_bpermute_b32` issues on the LDS pipe, not the VALU, and
allocates no LDS. The compiled kernel uses 5 VGPRs in wave32. No throughput was
measured, and nothing here is a rate claim.

Two contract details decide whether this is usable at all. The 27 table lanes
must be enabled in EXEC, because a read from a disabled lane returns zero, so a
partially masked wave reads zeros rather than the map. And the construction is
per-wave: every lane must be evaluating the same weight set.

### Native check

[`results/native-probe.json`](results/native-probe.json), from
[`bpermute_probe.hip`](bpermute_probe.hip) on gfx1151 through the existing
research lock:

```json
{"device":"gfx1151","A_one_instruction_mismatches":0,"B_two_instruction_mismatches":0,
 "dot4_address_mismatches":0,"index_bits_6_2_only_mismatches":0,"cases":192}
```

The kernel is written in inline assembly so the instruction-count claim is
literal; the disassembly contains exactly `v_dot4_i32_iu8 v2, v3, v4, 52
neg_lo:[1,1]` followed by `ds_bpermute_b32 v1, v2, v1`.

## Negatives

Each one below is an exhaustive SMT result over a stated grammar, not a failed
attempt. [`synth.py`](synth.py) encodes one component multiset per query, with
location variables covering every wiring and every ordering, and symbolic 32-bit
constants covering every constant. The domain is all 27 states at once, so there
is no sampling and no CEGIS. `unsat` is a negative for that whole multiset.

### Single-VALU searches before the final lookup

The planned sweep has 22 component multisets plus the zero-VALU case, for the
width-256 network whose map takes 27 distinct values. Some cells are incomplete,
as the table records:

| contract | 0 instructions | 1 instruction + lookup |
| --- | --- | --- |
| `packed2` | unsat | unsat on 15 of 22 multisets, 7 unexplored |
| `bytes` | unsat | sat, `v_dot4_i32_iu8` and `v_dot4_u32_u8` |
| `radix3` | unsat | sat, 12 of the 19 explored multisets |
| `radix3x4` | **sat** | sat, all 22 |

### No multiplier at all reaches a lane index from `packed2`

`ds_bpermute_b32` uses bits [6:2] of the address, and
`(raw * M) mod 128 = (raw * (M mod 128)) mod 128`, so the lane index depends only
on `M mod 128`. All 128 residues collide on the 27 valid words; the best reaches
23 distinct lanes out of 27. This covers all 2^32 multipliers by an argument
whose entire search space is 128 cases, and the reduction is checked on 2000
random multipliers in [`negatives.py`](negatives.py).

### The two-trit register-window shape does not extend

The two-trit result reads a nibble field out of one 32-bit constant with
`V_BFE_U32` at a variable offset and feeds it to `V_PERM_B32`. At three trits:

| shape | `packed2` | `radix3` |
| --- | --- | --- |
| `v_bfe_u32` + `v_perm_b32` | unsat | unsat |
| `v_alignbit_b32` + `v_perm_b32` | — | unsat |
| `v_alignbit_b32` + `v_bfe_u32` | — | unsat |
| `v_lshrrev_b32` + `v_and_b32` | — | unsat |
| `v_bfe_u32` + `v_bfe_u32` | — | unsat |

on the image-5 and image-8 networks, the easiest in the panel, 24 queries, none
sat, none unexplored. From
`packed2` the reason is visible: `V_BFE_U32` takes its offset from `S1[4:0]`, so
words 16 and 48 alias, and the maps are not constant on that pair. From `radix3`
there is no such immediate aliasing; the solver still returns unsat for these
specific templates and targets. Overlap couples the window contents. This is
not a general counting proof that 27 windows cannot fit in 64 bits.

### Counting

The family of all byte-valued maps on 27 states with `F(0,0,0) = 0` carries
208 bits of function-choice information. This counts unrestricted maps, not
just gated-network maps or any one fixed target. A
straight-line VALU program of length `L` can name at most `3L` prepared 32-bit
operands, so a **fixed-shape** universal construction needs `L >= 3` for byte
outputs and `L >= 9` for int32 outputs. `ds_bpermute_b32` names 1024 bits of
wave-distributed state in one instruction, which is why the lookup route is not
merely shorter but in a different accounting class. Letting the shape itself
vary with the function adds about 22 bits for length two under this grammar,
which is not enough to forbid length two by counting alone; the length-two
negatives above are structural, from the instruction semantics, not from this
bound.

## Fiber match against refinement

Two different questions, kept apart because they have different answers:

- **refine**: the program's output separates at least what the map separates.
  A general decoder exists. The lane index plus its table is exactly this, and
  the decoder's price is one `ds_bpermute_b32` and one table VGPR.
- **match**: the lane index BEFORE the lookup has exactly the target's fibers,
  so that index and the target differ by a bijective relabeling. The registered
  construction still includes the lookup. Removing it requires a compatible
  consumer and is not implemented by this experiment.

Best total instruction counts found, lookup included, with the unexplored
remainder per cell recorded in [results/summary.json](results/summary.json).
These are found constructions, not minima over incomplete cells. `no hit` is
not an impossibility claim:

```
network   img contract   best found matched index+lookup  unexplored
w1i5        5 balanced4    1 instr      no hit  0
w1i5        5 bytes        2 instr      no hit  7
w1i5        5 packed2      2 instr      no hit  0
w1i5        5 radix3       2 instr      no hit  3
w1i5        5 radix3x4     1 instr      no hit  1
w256i27    27 balanced4    1 instr     1 instr  2
w256i27    27 bytes        2 instr     2 instr  7
w256i27    27 packed2       no hit      no hit  15
w256i27    27 radix3       2 instr     2 instr  6
w256i27    27 radix3x4     1 instr     1 instr  0
w2i8        8 bytes        2 instr      no hit  5
w2i8        8 packed2       no hit      no hit  6
w4i11      11 bytes        2 instr      no hit  7
w4i11      11 packed2       no hit      no hit  10
w64i20     20 balanced4    1 instr      no hit  6
w64i20     20 bytes        2 instr      no hit  9
w64i20     20 packed2       no hit      no hit  12
w64i20     20 radix3       2 instr      no hit  2
w64i20     20 radix3x4     1 instr      no hit  3
w8i14      14 balanced4    1 instr      no hit  2
w8i14      14 bytes        2 instr      no hit  7
w8i14      14 packed2       no hit      no hit  6
w8i14      14 radix3       2 instr      no hit  1
w8i14      14 radix3x4     1 instr      no hit  2
```

The successful index-match cells are the width-256 network, whose map is
injective on the 27 states. No matching index was found for the non-injective
panel maps within the attempted zero/one-VALU grammar; unresolved cells prevent
an exhaustive negative across that panel. Independent rechecking in report.py
now verifies both final values and the pre-lookup index partitions.

From `packed2`, twelve one-VALU prefixes followed by the lookup realize the
image-5 map. No such construction was found for the image-8 and larger panel
maps; their cells contain unexplored queries. From `balanced4`, the universal
gather construction works regardless of hidden width. This illustrates the
importance of the input contract, not an isolated causal law about image size.

A `match` result is reported with its relabeling witness, and a `refine` result
with an observed-to-value table witnessing sufficiency;
both are in the per-job JSON as `relabel_observed_to_map` and
`relabel_is_bijective`.

## One address, many consumers

Once the input word has become a lane address, every further function of the
same three trits costs one more `ds_bpermute_b32` and one more table VGPR. No
second address computation, no decode between consumers, and the relabeling is
shared because the address is the input's own value.
[`baseline.py`](baseline.py) checks 16 independent networks against one shared
address: 17 instructions for 16 complete maps, exact on all 27 states each.

## Baseline accounting

The arithmetic descriptions below use byte-packed input unless a different
contract is named. They assume prepared operands are available. They are not
source-matched emitted kernels and do not include operand loads, wait
instructions or register-capacity effects. From [baseline.py](baseline.py):

| route | instructions | note |
| --- | ---: | --- |
| direct, width 64 | 320 | two dots, ReLU, product, accumulate per unit |
| direct, width 256 | 1280 | |
| 19-monomial canonical form | unpriced | exact identity; coefficients need not fit int4 |
| memory lookup | 2 | different cost class: a VMEM load, not a VALU op |
| this search, from `bytes` | 2 | |
| this search, from `radix3x4` | 1 | |

The 19-monomial identity is exact and checked on all 27 states for every panel
network. Its earlier 41-instruction estimate was invalid: trit-valued features
do not imply integer int4 coefficients. The records now report coefficient
ranges and denominators and leave this lowering unpriced. Every surviving
even monomial has degree 2.

## Method

- [`isa.py`](isa.py): Z3 semantics for 22 gfx1151 integer VALU instructions.
  Twelve transcribe [`Kelana/Hardware/IntOps.lean`](../../../Kelana/Hardware/IntOps.lean);
  the rest quote the manual's pseudocode in their docstring. All 22 assemble for
  gfx1151, checked with the installed assembler.
- [`synth.py`](synth.py): component-based synthesis. One query per multiset,
  covering all wirings, orderings and constants.
- [`emulate.py`](emulate.py): an independent concrete emulator written from the
  same pseudocode in plain Python integers. Every recorded solution is re-run
  through it on all 27 states by [`report.py`](report.py). Current defect count:
  zero.
- [`sweep.py`](sweep.py), [`run_search.py`](run_search.py): resumable drivers.
  Results, including every timeout, are in [`results/`](results/).

The synthesizer was validated by making it rediscover the two-trit observer
result from [`contracted-map`](../../ffn/contracted-map/README.md): given that
map and the two-bit packed word, it produces `v_bfe_u32` + `v_perm_b32` in one
second. It found a width-3 selector where the published construction uses width
4, which the fixed-template search in that directory could not have found.

### Exclusions

These bound every negative above.

- `ds_bpermute_b32` is modeled only as the final instruction, at most one per
  program. A lookup whose result feeds further arithmetic is a different shape
  and was not searched.
- Modeled components are the 22 in `isa.py`. Excluded: VOPD dual-issue forms,
  DPP and permlane modifiers, `v_cndmask_b32` and the compare that feeds it,
  64-bit-destination shifts, SALU, float and transcendental operations, WMMA,
  and memory instructions other than the baseline's load.
- Modifiers are not searched. `neg_lo` is fixed to signed operands for the dot
  products, matching the Lean model; `op_sel`, `clamp` and input modifiers are
  not modeled.
- Constants are symbolic 32-bit values. Encodability is a separate check: the
  gfx1151 inline range is -16..64, one 32-bit literal is allowed per
  instruction, and anything else costs an SGPR or VGPR prepared once per weight
  set. Construction B's `0x00240C04` assembles as a VOP3P literal, verified.
- Constant budgets per search: 2 at size 0, 3 at size 1, 4 at size 2 for
  collision-structure searches, and `3 * size` for exact-value searches so the
  budget is never the binding constraint.
- Per-query solver timeouts are 15 to 90 seconds depending on the job and are
  recorded per job. A timeout is not a negative; the unexplored multisets are
  listed by name in each result file and counted in the matrix above.
- The size-3 sweep was not run; nothing here claims a three-instruction
  exhaustive result or non-result.
- The general two-VALU-instruction exact-value sweep is partial: 150 of 253
  multisets for the image-5 map from `radix3`, 122 unsat and 28 timed out, in
  [`results/search-w1i5-radix3-byte-exact-2.json`](results/). The window shapes
  in the table above are the part of it that finished.

## Where this stops

Three trits is the largest full ternary input domain fitting in one 32-entry
wave table. Four trits give 81 input states, so the same injective-address
construction does not extend to every four-trit map. A particular four-trit map
may still factor through at most 32 states and admit one gather after a cheap
index computation. Multiple gathers or LDS tables are other constructions,
not universal lower bounds. Bonsai's deployed activation codes are not trits.

A cross-lane gather can select from 1,024 bits distributed across a wave; this
is a different operand interface from a per-lane register lookup. Any finite
region with at most 32 required output values can be tabulated this way once a
sufficient lane index is available. Computing that index, loading the table,
keeping its lanes active and sharing one weight set across the wave remain
part of an end-to-end implementation.

## Reproduce

```sh
cd research/discovery/whole-map-search
python3 model.py                 # structure of the family, ~15 s
python3 panel.py                 # the six networks, by seed
python3 construction.py          # 5562 exact cases
python3 negatives.py             # the multiplier and window negatives
python3 baseline.py              # canonical forms, baselines, multi-consumer
python3 sweep.py --budget 45 --workers 30 w256i27-bytes-lane5-refine-1
python3 report.py                # aggregate and re-check every solution
```

Native, from this directory, using the existing research lock:

```sh
mkdir -p build
hipcc --offload-arch=gfx1151 -O3 bpermute_probe.hip -o build/probe
../../ffn/batched/hardware-run ./build/probe > results/native-probe.json
```

`build/` is disposable. Source, results and the recorded native run are owned
here.

## Related work in this repository

[`contracted-map`](../../ffn/contracted-map/README.md) owns the two-trit
observer and the algebraic collapse this starts from.
[`ternary-algebra`](../ternary-algebra/README.md) owns the canonical form used
by the baseline. A parallel search running from the opposite direction, starting
from cheap instruction pairs on dense radix-3 words and solving for output
relabelings that obey the reflection law, is recorded in
`research/discovery/observer-search/`; it is instruction-first where this is
target-first, and the two do not overlap.
