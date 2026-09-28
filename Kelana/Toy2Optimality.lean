import Kelana.Toy2

/-!
# A two-instruction online core, and what cannot be done in one

`Kelana.Toy2` proves that two `V_DOT8_I32_IU4` instructions and one shift-or
compute the packed output word.  Granting both sides a free input packing pass
(wires only: every bit of a packed register is a constant or a copy of one input
bit), the online arithmetic of that program is three instructions.

This file proves two things.

* `fused_correct`: one `V_DOT4_I32_IU8` followed by one `V_DOT8_I32_IU4`
  computes the same packed word, for every ternary A, B, C.  The first
  instruction reads the column-1 codes prescaled by sixteen, so an int8 weight
  `16 * k` carries the factor 256 of the output byte position: `16 * k` times
  `16 * u` is `256 * k * u`, and `16 * k` fits int8 exactly when `k` fits int4.
  The second instruction adds the column-0 dot on top through its accumulator
  operand.  Two online instructions, and no shift-or.

* `no_shared_single_dot8`: no single 4-bit-lane dot can do the whole job when
  its wiring and accumulator coefficients are shared across weight matrices.
  Nibble weights over 4-bit lanes span 2760 on one input bit, counting
  within-lane fanout and either signedness choice, while two ternary matrices
  force a spread of 3072 on the column-1 high bit.

The second statement is deliberately narrow: it says nothing about 8-bit-lane
dots, whose reach is large enough that the question stays open.  See
`research/toy2/optimality/NOTES.md` for the model and the open cases.
-/

namespace Kelana.Toy2

/-! ## The prescaled first instruction -/

/-- `V_DOT4_I32_IU8` on the column-1 codes prescaled by sixteen, with the
prepared accumulator `257 * bias`.  Lane values are `16 * (t + 1) ≤ 32`, weights
are `16 * k`. -/
def dot4Column (a : Matrix) (o : Orientation) (b0 b1 c0 c1 : Int) : Int :=
  (16 * coeff0 a o) * (16 * (b0 + 1)) +
  (16 * coeff1 a o) * (16 * (b1 + 1)) +
  (16 * (7 * hi o)) * (16 * (c0 + 1)) +
  (16 * lo o) * (16 * (c1 + 1)) +
  257 * bias a o

/-- Every prescaled weight fits signed int8 whenever the fused coefficients fit
signed int4; `16 * (-8) = -128` is exactly the boundary. -/
theorem dot4_weights_fit (a : Matrix) (o : Orientation) (h : Fits a o) :
    (-128 ≤ 16 * coeff0 a o ∧ 16 * coeff0 a o ≤ 127) ∧
    (-128 ≤ 16 * coeff1 a o ∧ 16 * coeff1 a o ≤ 127) ∧
    (-128 ≤ 16 * (7 * hi o) ∧ 16 * (7 * hi o) ≤ 127) ∧
    (-128 ≤ 16 * lo o ∧ 16 * lo o ≤ 127) := by
  unfold Fits at h
  cases o <;> simp only [hi, lo] at * <;> omega

/-- Every prescaled lane fits an unsigned byte. -/
theorem prescaled_lane_fits (t : Int) (ht : Trit t) : 0 ≤ 16 * (t + 1) ∧ 16 * (t + 1) ≤ 255 := by
  unfold Trit at ht; omega

/-- The prescaled dot yields the shifted column together with the next bias. -/
theorem dot4_column_identity (a : Matrix) (o : Orientation) (b0 b1 c0 c1 : Int) :
    dot4Column a o b0 b1 c0 c1 = 256 * packedColumn a o b0 b1 c0 c1 + bias a o := by
  unfold dot4Column packedColumn
  grind

/-- `V_DOT8_I32_IU4` with four live lanes and an arbitrary accumulator operand. -/
def dot8Column (a : Matrix) (o : Orientation) (b0 b1 c0 c1 acc : Int) : Int :=
  coeff0 a o * (b0 + 1) + coeff1 a o * (b1 + 1) +
    (7 * hi o) * (c0 + 1) + lo o * (c1 + 1) + acc

/-- The whole online core: two instructions, chained through the accumulator. -/
def fusedRun (a b c : Matrix) : Int :=
  dot8Column a (choose a) b.a00 b.a10 c.a00 c.a10
    (dot4Column a (choose a) b.a01 b.a11 c.a01 c.a11)

theorem fused_eq_packedRun (a b c : Matrix) : fusedRun a b c = packedRun a b c := by
  unfold fusedRun packedRun dot8Column
  rw [dot4_column_identity]
  unfold packedColumn
  grind

/-- Two instructions reproduce the specified map with its packed output contract. -/
theorem fused_correct (a b c : Matrix) (ha : Ternary a) (hb : Ternary b) (hc : Ternary c) :
    decode (choose a) (fusedRun a b c) = mac a b c := by
  rw [fused_eq_packedRun]
  exact packed_correct a b c ha hb hc

/-- The chained intermediate stays far inside int32. -/
theorem dot4_column_bounds (a : Matrix) (o : Orientation) (b0 b1 c0 c1 : Int)
    (h : Fits a o)
    (hd0 : -3 ≤ a.a00 * b0 + a.a01 * b1 + c0 ∧ a.a00 * b0 + a.a01 * b1 + c0 ≤ 3)
    (hd1 : -3 ≤ a.a10 * b0 + a.a11 * b1 + c1 ∧ a.a10 * b0 + a.a11 * b1 + c1 ≤ 3) :
    0 ≤ dot4Column a o b0 b1 c0 c1 ∧ dot4Column a o b0 b1 c0 c1 ≤ 12336 := by
  have hbias := bias_bounds a o h
  have hcol := encode_column_bounds o _ _ hd0 hd1
  rw [dot4_column_identity, packed_column_identity]
  omega

/-! ## Online cost -/

/-- Online arithmetic of the incumbent packed core, given a free wire packing. -/
def incumbentOnline (dot8 shiftOr : Nat) : Nat := 2 * dot8 + shiftOr

/-- Online arithmetic of the fused core. -/
def fusedOnline (dot4 dot8 : Nat) : Nat := dot4 + dot8

theorem fused_cheaper (dot4 dot8 shiftOr : Nat) (hd : dot4 ≤ dot8) (hs : 0 < shiftOr) :
    fusedOnline dot4 dot8 < incumbentOnline dot8 shiftOr := by
  unfold fusedOnline incumbentOnline; omega

theorem fused_saving (dot4 dot8 shiftOr : Nat) (hd : dot4 ≤ dot8) :
    fusedOnline dot4 dot8 + ((dot8 - dot4) + shiftOr) = incumbentOnline dot8 shiftOr := by
  unfold fusedOnline incumbentOnline; omega

theorem fused_load_cost_cannot_erase_saving (loadFused loadIncumbent dot4 dot8 shiftOr : Nat)
    (hd : dot4 ≤ dot8) (hs : 0 < shiftOr) :
    ∃ threshold, ∀ n, threshold ≤ n →
      Amortization.total loadFused (fusedOnline dot4 dot8) n <
      Amortization.total loadIncumbent (incumbentOnline dot8 shiftOr) n :=
  Amortization.lower_recurring_eventually_wins _ _ _ _ (fused_cheaper dot4 dot8 shiftOr hd hs)

/-! ## One 4-bit-lane dot cannot serve two weight matrices

A wire-packed source cannot depend on A, so when one instruction must serve many
matrices its lane contents and its accumulator coefficient are fixed and only the
prepared weights move.  The coefficient the instruction gives to one input bit is
then `sum_i w_i * lam_i + alpha`, where `lam_i` is the coefficient that bit has
inside lane `i`, and the reachable spread is bounded by the format.

Two ranges have to be honest here.

* A wire may copy one input bit into several positions of the same lane, so
  `lam_i` is a subset sum of that lane's place values, not a single place value.
  For a 4-bit lane the place values are `1, 2, 4` and either `8` (unsigned lane)
  or `-8` (signed lane), so `lam_i` ranges over `[-8, 15]`
  (`wire_lane_coefficient_range`).
* The opcode's signedness controls are prepared alongside the weights and may
  therefore be chosen per matrix, so the weight range is the union of signed
  int4 `[-8, 7]` and unsigned u4 `[0, 15]`, namely `[-8, 15]`.

Both ranges below are those unions, so the bound covers either signedness choice
and any within-lane fanout.
-/

theorem bounded_product (x y bx byy : Int)
    (hx : -bx ≤ x ∧ x ≤ bx) (hy : -byy ≤ y ∧ y ≤ byy) (hbx : 0 ≤ bx) (hby : 0 ≤ byy) :
    -(bx * byy) ≤ x * y ∧ x * y ≤ bx * byy := by
  have h1 : x.natAbs ≤ bx.natAbs := by omega
  have h2 : y.natAbs ≤ byy.natAbs := by omega
  have h3 : (x * y).natAbs = x.natAbs * y.natAbs := Int.natAbs_mul x y
  have h4 : x.natAbs * y.natAbs ≤ bx.natAbs * byy.natAbs := Nat.mul_le_mul h1 h2
  have h5 : (bx * byy).natAbs = bx.natAbs * byy.natAbs := Int.natAbs_mul bx byy
  have h6 : (x * y).natAbs ≤ (bx * byy).natAbs := by omega
  have h7 : 0 ≤ bx * byy := Int.mul_nonneg hbx hby
  omega

/-- The coefficient one input bit can have inside a single 4-bit lane.  Each of
the four positions independently either holds a copy of that bit or does not, so
the coefficient is a subset sum of the lane's place values: `1, 2, 4` and the top
place, which is `8` for an unsigned lane and `-8` for a signed one. -/
theorem wire_lane_coefficient_range (s0 s1 s2 s3 top : Int)
    (h0 : s0 = 0 ∨ s0 = 1) (h1 : s1 = 0 ∨ s1 = 1)
    (h2 : s2 = 0 ∨ s2 = 1) (h3 : s3 = 0 ∨ s3 = 1)
    (ht : top = 8 ∨ top = -8) :
    -8 ≤ s0 * 1 + s1 * 2 + s2 * 4 + s3 * top ∧
      s0 * 1 + s1 * 2 + s2 * 4 + s3 * top ≤ 15 := by
  rcases h3 with h3 | h3 <;> rcases ht with ht | ht <;> subst h3 <;> subst ht <;> omega

/-- One lane of a 4-bit dot moves a bit's coefficient by at most 345.  The weight
difference of two nibble weights is at most 23 (`15 - (-8)`), and a bit's lane
coefficient lies in `[-8, 15]`. -/
theorem lane_spread (w w' lam : Int)
    (hw : -8 ≤ w ∧ w ≤ 15) (hw' : -8 ≤ w' ∧ w' ≤ 15) (hl : -8 ≤ lam ∧ lam ≤ 15) :
    -345 ≤ w * lam - w' * lam ∧ w * lam - w' * lam ≤ 345 := by
  have hsub : (w - w') * lam = w * lam - w' * lam := by grind
  have := bounded_product (w - w') lam 23 15 (by omega) (by omega) (by omega) (by omega)
  omega

/-- Eight lanes with fixed input coefficients, permitting weight signedness changes.
For input signedness changes as well, use `dot8_variable_signedness_spread`. -/
theorem dot8_shared_spread
    (w0 w1 w2 w3 w4 w5 w6 w7 w0' w1' w2' w3' w4' w5' w6' w7'
     l0 l1 l2 l3 l4 l5 l6 l7 : Int)
    (h0 : -8 ≤ w0 ∧ w0 ≤ 15) (h1 : -8 ≤ w1 ∧ w1 ≤ 15) (h2 : -8 ≤ w2 ∧ w2 ≤ 15)
    (h3 : -8 ≤ w3 ∧ w3 ≤ 15) (h4 : -8 ≤ w4 ∧ w4 ≤ 15) (h5 : -8 ≤ w5 ∧ w5 ≤ 15)
    (h6 : -8 ≤ w6 ∧ w6 ≤ 15) (h7 : -8 ≤ w7 ∧ w7 ≤ 15)
    (h0' : -8 ≤ w0' ∧ w0' ≤ 15) (h1' : -8 ≤ w1' ∧ w1' ≤ 15) (h2' : -8 ≤ w2' ∧ w2' ≤ 15)
    (h3' : -8 ≤ w3' ∧ w3' ≤ 15) (h4' : -8 ≤ w4' ∧ w4' ≤ 15) (h5' : -8 ≤ w5' ∧ w5' ≤ 15)
    (h6' : -8 ≤ w6' ∧ w6' ≤ 15) (h7' : -8 ≤ w7' ∧ w7' ≤ 15)
    (g0 : -8 ≤ l0 ∧ l0 ≤ 15) (g1 : -8 ≤ l1 ∧ l1 ≤ 15) (g2 : -8 ≤ l2 ∧ l2 ≤ 15)
    (g3 : -8 ≤ l3 ∧ l3 ≤ 15) (g4 : -8 ≤ l4 ∧ l4 ≤ 15) (g5 : -8 ≤ l5 ∧ l5 ≤ 15)
    (g6 : -8 ≤ l6 ∧ l6 ≤ 15) (g7 : -8 ≤ l7 ∧ l7 ≤ 15) :
    -2760 ≤ (w0*l0 + w1*l1 + w2*l2 + w3*l3 + w4*l4 + w5*l5 + w6*l6 + w7*l7)
         - (w0'*l0 + w1'*l1 + w2'*l2 + w3'*l3 + w4'*l4 + w5'*l5 + w6'*l6 + w7'*l7) ∧
    (w0*l0 + w1*l1 + w2*l2 + w3*l3 + w4*l4 + w5*l5 + w6*l6 + w7*l7)
         - (w0'*l0 + w1'*l1 + w2'*l2 + w3'*l3 + w4'*l4 + w5'*l5 + w6'*l6 + w7'*l7) ≤ 2760 := by
  have s0 := lane_spread w0 w0' l0 h0 h0' g0
  have s1 := lane_spread w1 w1' l1 h1 h1' g1
  have s2 := lane_spread w2 w2' l2 h2 h2' g2
  have s3 := lane_spread w3 w3' l3 h3 h3' g3
  have s4 := lane_spread w4 w4' l4 h4 h4' g4
  have s5 := lane_spread w5 w5' l5 h5 h5' g5
  have s6 := lane_spread w6 w6' l6 h6 h6' g6
  have s7 := lane_spread w7 w7' l7 h7 h7' g7
  omega

/-- Fixed input coefficients cannot differ by exactly 3072 modulo 2^32.
The full input-signedness and orientation ranges are covered below by
`no_variable_signedness_dot8`.  `wrap` carries the
modular reading: if the instruction's result is only required to agree with the
target modulo `2^32`, the coefficient identity holds up to a multiple of `2^32`,
and that still cannot bridge the gap.  Taking `wrap = 0` is the exact-integer
reading, which is the one in force here because every value the construction and
the incumbent produce lies in `[0, 12336]`. -/
theorem no_shared_single_dot8
    (w0 w1 w2 w3 w4 w5 w6 w7 w0' w1' w2' w3' w4' w5' w6' w7'
     l0 l1 l2 l3 l4 l5 l6 l7 alpha c c' wrap : Int)
    (h0 : -8 ≤ w0 ∧ w0 ≤ 15) (h1 : -8 ≤ w1 ∧ w1 ≤ 15) (h2 : -8 ≤ w2 ∧ w2 ≤ 15)
    (h3 : -8 ≤ w3 ∧ w3 ≤ 15) (h4 : -8 ≤ w4 ∧ w4 ≤ 15) (h5 : -8 ≤ w5 ∧ w5 ≤ 15)
    (h6 : -8 ≤ w6 ∧ w6 ≤ 15) (h7 : -8 ≤ w7 ∧ w7 ≤ 15)
    (h0' : -8 ≤ w0' ∧ w0' ≤ 15) (h1' : -8 ≤ w1' ∧ w1' ≤ 15) (h2' : -8 ≤ w2' ∧ w2' ≤ 15)
    (h3' : -8 ≤ w3' ∧ w3' ≤ 15) (h4' : -8 ≤ w4' ∧ w4' ≤ 15) (h5' : -8 ≤ w5' ∧ w5' ≤ 15)
    (h6' : -8 ≤ w6' ∧ w6' ≤ 15) (h7' : -8 ≤ w7' ∧ w7' ≤ 15)
    (g0 : -8 ≤ l0 ∧ l0 ≤ 15) (g1 : -8 ≤ l1 ∧ l1 ≤ 15) (g2 : -8 ≤ l2 ∧ l2 ≤ 15)
    (g3 : -8 ≤ l3 ∧ l3 ≤ 15) (g4 : -8 ≤ l4 ∧ l4 ≤ 15) (g5 : -8 ≤ l5 ∧ l5 ≤ 15)
    (g6 : -8 ≤ l6 ∧ l6 ≤ 15) (g7 : -8 ≤ l7 ∧ l7 ≤ 15)
    (hc : w0*l0 + w1*l1 + w2*l2 + w3*l3 + w4*l4 + w5*l5 + w6*l6 + w7*l7 + alpha = c)
    (hc' : w0'*l0 + w1'*l1 + w2'*l2 + w3'*l3 + w4'*l4 + w5'*l5 + w6'*l6 + w7'*l7 + alpha = c')
    (hgap : c - c' = 3072 + 4294967296 * wrap) : False := by
  have := dot8_shared_spread w0 w1 w2 w3 w4 w5 w6 w7 w0' w1' w2' w3' w4' w5' w6' w7'
    l0 l1 l2 l3 l4 l5 l6 l7 h0 h1 h2 h3 h4 h5 h6 h7 h0' h1' h2' h3' h4' h5' h6' h7'
    g0 g1 g2 g3 g4 g5 g6 g7
  omega

/-- The separation used above is available from ternary matrices: the fused
coefficient of the first code is at least six in absolute value for
`A = [[1,0],[1,0]]` under every orientation, and zero for `A = 0`.  The column-1
high bit carries `512` times that coefficient, so its absolute spread is 3072 or 4096. -/
theorem separating_matrices (o o' : Orientation) :
    (coeff0 ⟨1, 0, 1, 0⟩ o ≤ -6 ∨ 6 ≤ coeff0 ⟨1, 0, 1, 0⟩ o) ∧
    coeff0 ⟨0, 0, 0, 0⟩ o' = 0 := by
  constructor
  · cases o <;> simp only [coeff0, hi, lo] <;> decide
  · cases o' <;> simp only [coeff0, hi, lo] <;> decide

theorem nibble_product_range {w lam : Int}
    (hw : -8 ≤ w ∧ w ≤ 15) (hl : -8 ≤ lam ∧ lam ≤ 15) :
    -120 ≤ w * lam ∧ w * lam ≤ 225 := by
  by_cases hp : 0 ≤ w <;> by_cases hq : 0 ≤ lam
  · have h1 := Int.mul_nonneg hp hq
    have h2 := Int.mul_le_mul_of_nonneg_right hw.2 hq
    have h3 := Int.mul_le_mul_of_nonneg_left hl.2 (by decide : (0 : Int) ≤ 15)
    omega
  · have h1 := Int.mul_nonpos_of_nonneg_of_nonpos hp (by omega : lam ≤ 0)
    have h2 := Int.mul_le_mul_of_nonneg_left hl.1 hp
    omega
  · have h1 := Int.mul_nonpos_of_nonpos_of_nonneg (by omega : w ≤ 0) hq
    have h2 := Int.mul_le_mul_of_nonneg_right hw.1 hq
    omega
  · have h1 := Int.mul_nonneg_of_nonpos_of_nonpos (by omega : w ≤ 0) (by omega : lam ≤ 0)
    have h2 := bounded_product w lam 8 8 (by omega) (by omega) (by decide) (by decide)
    omega

theorem lane_product_sum (ts : List Int) (h : ∀ t ∈ ts, -120 ≤ t ∧ t ≤ 225) :
    -120 * (ts.length : Int) ≤ ts.sum ∧ ts.sum ≤ 225 * (ts.length : Int) := by
  induction ts with
  | nil => simp
  | cons t ts ih =>
    have ht := h t (by simp)
    have hr := ih (by intro v hv; exact h v (by simp [hv]))
    simp only [List.sum_cons, List.length_cons, Int.natCast_add, Int.natCast_one]
    omega

theorem dot8_variable_signedness_spread (ts us : List Int)
    (htl : ts.length = 8) (hul : us.length = 8)
    (ht : ∀ t ∈ ts, -120 ≤ t ∧ t ≤ 225)
    (hu : ∀ u ∈ us, -120 ≤ u ∧ u ≤ 225) :
    -2760 ≤ ts.sum - us.sum ∧ ts.sum - us.sum ≤ 2760 := by
  have bt := lane_product_sum ts ht
  have bu := lane_product_sum us hu
  simp only [htl, hul] at bt bu
  omega

theorem no_variable_signedness_dot8 (ts us : List Int) (delta wrap : Int)
    (htl : ts.length = 8) (hul : us.length = 8)
    (ht : ∀ t ∈ ts, -120 ≤ t ∧ t ≤ 225)
    (hu : ∀ u ∈ us, -120 ≤ u ∧ u ≤ 225)
    (hdelta : (-4096 ≤ delta ∧ delta ≤ -3072) ∨ (3072 ≤ delta ∧ delta ≤ 4096))
    (he : ts.sum - us.sum = delta + 4294967296 * wrap) : False := by
  have := dot8_variable_signedness_spread ts us htl hul ht hu
  omega

#print axioms no_variable_signedness_dot8
end Kelana.Toy2
