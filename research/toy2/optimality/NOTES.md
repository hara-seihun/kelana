# Optimality attempt for the exact 2×2 ternary MAC

Working notes. The map, the encodings and the incumbent program are those of
[`../PROOF.md`](../PROOF.md): `D = AB + C` with ternary entries, one output word
holding `p0 = (l*d1+3) + 7*(h*d0+3)` for column 0 in its low byte and `p1` for
column 1 in the next byte, sign metadata `h, l` prepared with A.

The question asked here is the online arithmetic cost when both sides get a free
input packing pass. The incumbent's online core is then three instructions: two
`V_DOT8_I32_IU4` and one `V_LSHL_OR_B32`.

## 1. What a free packing pass is allowed to be

A **wire register** is a 32-bit word in which every bit position holds either a
fixed constant or a copy of one bit of the dynamic input word. Fanout is
allowed: one input bit may be copied to several positions, including several
positions of the same lane. Nothing else is: wires cannot add, carry, or look
at A.

This is exactly what the incumbent's six-instruction expansion network is
(shifts, masks, ors), and it is the weakest definition that keeps the problem
non-vacuous. Arbitrary free functions of the input would let the packing pass
compute the answer, and an A-dependent arithmetic pass would do the same.

A wire register's value is `sum_beta alpha_beta * bit_beta(x) + kappa` with the
binary supports of the `alpha_beta` and of `kappa` pairwise disjoint. Because
the seventeen functions `1, bit_0, ..., bit_15` are linearly independent on the
6561 valid inputs, the affine expansion of any function of the input is unique;
a program's per-bit coefficients must therefore match the target's exactly. All
the searches and proofs below work in that coefficient space.

Two details of that translation matter for the lower bound, and both are stated
where they are used.

* The coefficient a given input bit has **inside one lane** is a subset sum of
  that lane's place values, because fanout may copy the bit into several
  positions of the same lane. For a 4-bit lane the place values are `1, 2, 4`
  and either `8` or `-8`, so that coefficient ranges over `[-8, 15]` — not
  `[-8, 8]`.
* "Exactly" means equality as integers. Every value in play here lies in
  `[0, 12336]`, far inside int32, so the ring is `Z` and nothing wraps. If one
  instead demands only agreement modulo `2^32`, the coefficient identity holds
  up to a multiple of `2^32`; the lower bound below is stated with that multiple
  present, so it covers the modular reading too.

Two packing regimes matter, and they give different answers:

* **shared packing** — one packing serves every weight matrix. The incumbent is
  in this regime, and so is the two-instruction construction below.
* **A-dependent packing** — the wiring may depend on A. Legitimate in the stated
  reuse objective, where A is loaded once and reused indefinitely, so the wiring
  is fixed for the whole run. Strictly weaker as a claim.

## 2. Result: two online instructions, shared packing, every A

```
I1  V_DOT4_I32_IU8  weights 16*k  lanes 16*u(column 1)  acc 257*bias  ->  256*p1 + bias
I2  V_DOT8_I32_IU4  weights k     lanes u(column 0)     acc I1        ->  p0 + 256*p1
```

The point is the prescale. An int8 weight cannot hold `256*k`, and a byte lane
cannot hold a code shifted eight places. Splitting the factor as `16 * 16` puts
half of it in the weight and half in the wiring: `16*k` times `16*u` is
`256*k*u`, and `16*k` fits signed int8 exactly when `k` fits signed int4
(`16 * -8 = -128`). The column-1 dot therefore lands already shifted into the
high byte, and the column-0 dot adds itself on top through its accumulator
operand. No shift-or survives.

Both dynamic operands are wires of the same 16-bit input word, independent of A:

| register | contents |
| --- | --- |
| `I1` lanes | `b01, b11, c01, c11` at bit positions 4, 12, 20, 28 |
| `I2` lanes | `b00, b10, c00, c10` at bit positions 0, 4, 8, 12 |

Preparation is unchanged from the incumbent: the same orientation rule, the same
`k0, k1`, one bias constant `257*bias` instead of `bias`.

Evidence:

* [`construction.py`](construction.py) replays the two instructions with the
  RDNA3.5 pseudocode semantics over all 531441 A/B/C cases and against the
  decoded reference matrix; [`construction-results.json`](construction-results.json)
  records the run. The chained intermediate stays in [32, 12320].
* [`Kelana/Toy2Optimality.lean`](../../../Kelana/Toy2Optimality.lean):
  `fused_correct` (whole map, every ternary A, B, C), `dot4_weights_fit`,
  `prescaled_lane_fits`, `dot4_column_bounds`, and the cost statements
  `fused_cheaper`, `fused_saving`, `fused_load_cost_cannot_erase_saving`.
  Only `propext`, `Classical.choice`, `Quot.sound`.
* [`kernels.s`](kernels.s) and [`assemble.py`](assemble.py) assemble all three
  cores for gfx1151 and check the opcode counts: incumbent 3, fused 2, single 1.

Symbolic cost, with nonnegative per-opcode charges: incumbent `2*D8 + S`, fused
`D4 + D8`, saving `(D8 - D4) + S`. Strict whenever the shift-or has positive
charge and `D4 ≤ D8`; both dots are VOP3P ops of the same class, so we do not
assume they are equal, only ordered.

## 3. Result: one instruction, A-dependent packing

A single `V_DOT4_I32_IU8` computes the whole output word for A = identity:

```
weights   (27, 7, 7, 1)            # int8 lanes, NEG[0]=1 signed, NEG[1]=0 unsigned
lane wire bit b at byte*8+offset: (0,2)<-11 (0,5)<-8 (0,6)<-12 (0,7)<-9
                                  (1,0)<-4  (1,1)<-1 (1,2)<-13 (1,4)<-9
                                  (2,0)<-0  (2,1)<-5 (2,2)<-13 (2,3)<-12
                                  (2,5)<-10 (2,6)<-13 (2,7)<-8
                                  (3,0)<-6  (3,1)<-7 (3,3)<-13 (3,4)<-9
                                  (3,5)<-10 (3,6)<-11 (3,7)<-11
lane constants at (0,4) (1,3) (1,5) (1,6) (1,7)
acc wire  position q <- bit: 0<-2 1<-3 2<-11 3<-12 4<-11 5<-8 6<-11 7<-11
                             8<-14 9<-15 10<-13 11<-13
```

Input bit numbering is `2*field + (0 low, 1 high)` in the field order
`b00, b10, c00, c10, b01, b11, c01, c11`. Verified by replaying the exact
instruction over all 6561 dynamic inputs ([`single_dot.py`](single_dot.py)).

So the incumbent's three online instructions are not a floor: for this A the
whole 2×2 ternary multiply-add with addend, in the fixed packed output form, is
one native instruction.

[`scan_one.py`](scan_one.py) searches per A. With a 0.8 s budget per
configuration it found witnesses for 5 of the first 32 matrices
([`one-instruction.json`](one-instruction.json)); the rest are **not decided** —
the search was cut off, not refuted. Witnesses appear within a second when they
appear at all, so a longer or better-guided search would raise the count. The
known-good matrices include the identity, the zero matrix and all-ones.

Honest cost caveat: these wirings are irregular (22 wired lane positions with
fanout, 12 accumulator positions). Free by the granted model, they would be
expensive to build with real shift/mask instructions. The two-instruction
construction needs only two regular wire registers.

## 4. Lower bounds

**Zero instructions is impossible.** The output word depends on A, and a wire
register does not.

**One 4-bit-lane dot with shared packing is impossible.** With shared wiring,
bit placement and the accumulator bit coefficients are fixed. The weights and lane
signedness can change with A, so the coefficient given to one input bit is
`sum_i w_i*lam_i + alpha`, with both `w_i` and `lam_i` potentially changing.
The fixed accumulator contribution `alpha` cancels between matrices.

* weights: signed int4 `[-8, 7]` together with unsigned u4 `[0, 15]`, so `[-8, 15]`;
* per-lane bit coefficients: subset sums of `1, 2, 4` and `8` or `-8`, so
  `[-8, 15]` (`wire_lane_coefficient_range`).

Each product `w*lam` lies in `[-120, 225]`. Its change is at most
`225 - (-120) = 345`, even when both operands change, and eight lanes give 2760.
The column-1 high bit of the first code carries `512*k0`. For
`A = [[1,0],[1,0]]`, every orientation gives `|k0|` equal to 6 or 8, whereas
`A = 0` gives zero. The required absolute spread is therefore 3072 or 4096.
No multiple of `2^32` moves either signed gap into `[-2760,2760]`, so wrapping
cannot help. Lean: `wire_lane_coefficient_range`, `nibble_product_range`,
`dot8_variable_signedness_spread`, `no_variable_signedness_dot8` and
`separating_matrices`. The fixed-coefficient lemmas remain narrower corollaries.

An earlier version of this note used 960, taking a lane coefficient to be a
single place value and the weights to be signed. Within-lane fanout and
per-matrix signedness each widen the reach; 2760 is the bound that survives both,
and it still separates.

**One 8-bit-lane dot with shared packing: open, with evidence against.** The
reach argument fails here by a wide margin — byte lanes and byte weights give a
per-lane spread near `383 * 255`, so four lanes reach far past 3072 — and
the structural argument that works when the coefficient family has full rank
does not apply: with the orientation held fixed at `(h,l) = (1,1)` only `k0` and
`k1` vary, so the A-dependent coefficient family is 2-dimensional and four lanes
can span it without any single lane carrying the 256 ratio.
[`shared_one.py`](shared_one.py) encodes the whole question — shared wiring,
shared accumulator, weights affine in `(k0, k1)` — for CP-SAT, and 40 s returns
UNKNOWN.

Fixing the weight rule `w = k0*p + k1*q + r` to a concrete `(p, q)` makes each
case tiny, and CP-SAT then decides it in milliseconds.
[`shared_scan.py`](shared_scan.py) scanned 5036 such cases across both lane
signednesses ([`shared-scan.json`](shared-scan.json)), plus about 9000 more in
earlier runs: every one infeasible, none undecided. The scan fixes the weights
as signed int8; unsigned u8 weights were not scanned.  So a single 8-bit-lane dot
with shared wiring and a small affine weight rule does not exist.  That still
leaves weight rules that are not affine in `k`, larger `p, q`, other
orientations, and more accumulator positions, so the case is not closed.

**One instruction per A, other shapes.** [`single.py`](single.py) decides the
same placement problem for a stated list of affine shapes (both dot8 variants,
both dot4 variants, `V_MAD_U32_U24`, `V_MAD_I32_I24`, `V_MUL_LO_U32`, the
add/shift-add/xor family). Every dot8 shape comes back infeasible in
milliseconds for the matrices tried; the dot4 shapes are where the witnesses of
section 3 live. [`fixed_weights.py`](fixed_weights.py) is the fast inner
decision once the weights are fixed, and it is what makes the searches usable.

## 5. What this does not establish

* No claim that two instructions is optimal for 8-bit-lane dots under shared
  packing: that case is open, and if it resolves the other way the answer there
  is one, not two.
* No claim about instructions outside the affine class. Data-dependent control
  (variable shifts, `V_PERM_B32` with a data selector), `V_MED3`/`V_CNDMASK`
  style selection, and bilinear use of both dot operands are excluded by
  hypothesis, not refuted. Selection ops would have to make the result coincide
  pointwise with an affine function of sixteen bits; that looks hopeless but is
  not proved here.
* No claim about the packing cost. With packing charged rather than free, the
  incumbent's nine-instruction total is not beaten by these constructions: the
  fused pair needs one more spread step than the shared expansion network. The
  free-packing model is the one fixed for this comparison, and it is the regime
  the measured register-replay throughput used.
* No timing measurement. The cost statements are instruction counts and
  symbolic per-opcode charges, not cycles.

## 6. Reproduction

```sh
cd research/toy2/optimality
python3 construction.py --output construction-results.json   # 531441 cases
python3 assemble.py --output assembly-results.json           # gfx1151 encodings
python3 single_dot.py --matrices 1,0,0,1                     # one-instruction witness
python3 scan_one.py --start 0 --count 81 --seconds 3 --output one-instruction.json
python3 shared_one.py --seconds 45 --output shared-one.json  # open question
lake build                                                   # Lean, from the repo root
```
