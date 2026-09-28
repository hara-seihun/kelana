import Kelana.Toy2

/-! A single byte-lane dot for the complete 2×2 ternary multiply-add.
The output is a radix-64 column code, not the old radix-256 byte pair.
The online input wire copies column 0's two-bit code into bits 0–1 of each
byte and column 1's into bits 6–7. No additions occur in the wire.
-/
namespace Kelana.Toy2

def radix64Coeff0 (a : Matrix) : Int := a.a10 + 7 * a.a00
def radix64Coeff1 (a : Matrix) : Int := a.a11 + 7 * a.a01
def radix64Bias (a : Matrix) : Int :=
  24 - (radix64Coeff0 a + radix64Coeff1 a + 8)

def radix64Column (a : Matrix) (b0 b1 c0 c1 : Int) : Int :=
  (a.a10 * b0 + a.a11 * b1 + c1 + 3) +
    7 * (a.a00 * b0 + a.a01 * b1 + c0 + 3)

def radix64Dot (a b c : Matrix) : Int :=
  radix64Coeff0 a * ((b.a00 + 1) + 64 * (b.a01 + 1)) +
  radix64Coeff1 a * ((b.a10 + 1) + 64 * (b.a11 + 1)) +
  7 * ((c.a00 + 1) + 64 * (c.a01 + 1)) +
  ((c.a10 + 1) + 64 * (c.a11 + 1)) +
  65 * radix64Bias a

theorem radix64_dot_identity (a b c : Matrix) :
    radix64Dot a b c =
      radix64Column a b.a00 b.a10 c.a00 c.a10 +
      64 * radix64Column a b.a01 b.a11 c.a01 c.a11 := by
  unfold radix64Dot radix64Column radix64Coeff0 radix64Coeff1 radix64Bias
  simp only [radix64Coeff0, radix64Coeff1, Int.mul_add, Int.add_mul,
    Int.mul_left_comm (a.a00) (64 : Int) b.a01,
    Int.mul_left_comm (a.a01) (64 : Int) b.a11,
    Int.mul_left_comm (a.a10) (64 : Int) b.a01,
    Int.mul_left_comm (a.a11) (64 : Int) b.a11,
    Int.mul_assoc]
  omega

theorem radix64_weight_bounds (a : Matrix) (ha : Ternary a) :
    -128 ≤ radix64Coeff0 a ∧ radix64Coeff0 a ≤ 127 ∧
    -128 ≤ radix64Coeff1 a ∧ radix64Coeff1 a ≤ 127 := by
  unfold radix64Coeff0 radix64Coeff1 Ternary Trit at *
  rcases ha with ⟨h00, h01, h10, h11⟩
  omega

/-- Each lane is a disjoint placement of two unsigned trit codes. -/
theorem radix64_lane_bounds (t0 t1 : Int) (h0 : Trit t0) (h1 : Trit t1) :
    0 ≤ (t0 + 1) + 64 * (t1 + 1) ∧
    (t0 + 1) + 64 * (t1 + 1) ≤ 255 := by
  unfold Trit at *
  omega

theorem radix64_column_bounds (a b c : Matrix)
    (ha : Ternary a) (hb : Ternary b) (hc : Ternary c) :
    (0 ≤ radix64Column a b.a00 b.a10 c.a00 c.a10 ∧
      radix64Column a b.a00 b.a10 c.a00 c.a10 ≤ 48) ∧
    (0 ≤ radix64Column a b.a01 b.a11 c.a01 c.a11 ∧
      radix64Column a b.a01 b.a11 c.a01 c.a11 ≤ 48) := by
  have h00 := small_dot_bound _ _ _ _ _ ha.1 ha.2.1 hb.1 hb.2.2.1 hc.1
  have h01 := small_dot_bound _ _ _ _ _ ha.1 ha.2.1 hb.2.1 hb.2.2.2 hc.2.1
  have h10 := small_dot_bound _ _ _ _ _ ha.2.2.1 ha.2.2.2 hb.1 hb.2.2.1 hc.2.2.1
  have h11 := small_dot_bound _ _ _ _ _ ha.2.2.1 ha.2.2.2 hb.2.1 hb.2.2.2 hc.2.2.2
  unfold radix64Column
  omega

def radix64Decode (p : Int) : Matrix :=
  ⟨(p % 64) / 7 - 3, (p / 64) / 7 - 3,
   (p % 64) % 7 - 3, (p / 64) % 7 - 3⟩

theorem radix64_correct (a b c : Matrix)
    (ha : Ternary a) (hb : Ternary b) (hc : Ternary c) :
    radix64Decode (radix64Dot a b c) = mac a b c := by
  let d00 := a.a00 * b.a00 + a.a01 * b.a10 + c.a00
  let d10 := a.a10 * b.a00 + a.a11 * b.a10 + c.a10
  let d01 := a.a00 * b.a01 + a.a01 * b.a11 + c.a01
  let d11 := a.a10 * b.a01 + a.a11 * b.a11 + c.a11
  have h00 := small_dot_bound _ _ _ _ _ ha.1 ha.2.1 hb.1 hb.2.2.1 hc.1
  have h01 := small_dot_bound _ _ _ _ _ ha.1 ha.2.1 hb.2.1 hb.2.2.2 hc.2.1
  have h10 := small_dot_bound _ _ _ _ _ ha.2.2.1 ha.2.2.2 hb.1 hb.2.2.1 hc.2.2.1
  have h11 := small_dot_bound _ _ _ _ _ ha.2.2.1 ha.2.2.2 hb.2.1 hb.2.2.2 hc.2.2.2
  let p0 := radix64Column a b.a00 b.a10 c.a00 c.a10
  let p1 := radix64Column a b.a01 b.a11 c.a01 c.a11
  have hp := radix64_column_bounds a b c ha hb hc
  have hlow : (p0 + 64 * p1) % 64 = p0 := by omega
  have hhigh : (p0 + 64 * p1) / 64 = p1 := by omega
  have hcol0 : p0 = encodeColumn .normal d00 d10 := by
    simp [p0, radix64Column, encodeColumn, hi, lo, d00, d10]
  have hcol1 : p1 = encodeColumn .normal d01 d11 := by
    simp [p1, radix64Column, encodeColumn, hi, lo, d01, d11]
  have hd0 := decode_column .normal d00 d10 h00 h10
  have hd1 := decode_column .normal d01 d11 h01 h11
  rw [radix64_dot_identity]
  change radix64Decode (p0 + 64 * p1) = mac a b c
  change ⟨(p0 + 64 * p1) % 64 / 7 - 3, (p0 + 64 * p1) / 64 / 7 - 3,
    (p0 + 64 * p1) % 64 % 7 - 3, (p0 + 64 * p1) / 64 % 7 - 3⟩ = mac a b c
  rw [hlow, hhigh, hcol0, hcol1]
  simp only [decodeHigh, decodeLow, hi, lo, Int.one_mul] at hd0 hd1
  rw [hd0.1, hd1.1, hd0.2, hd1.2]
  rfl

/-- A weight-independent output wire cannot implement the radix-64 map: the
same dynamic inputs require different results for two prepared matrices. -/
theorem radix64_needs_weight_dependent_work :
    radix64Dot ⟨0, 0, 0, 0⟩ ⟨1, 0, 0, 1⟩ ⟨0, 0, 0, 0⟩ ≠
    radix64Dot ⟨1, 0, 0, 1⟩ ⟨1, 0, 0, 1⟩ ⟨0, 0, 0, 0⟩ := by
  decide

end Kelana.Toy2
