import Std

namespace Kelana.JointResidualReader

/-- A complete-map residual is evaluated after adding the correction to the base. -/
theorem joint_error (teacher base correction : Rat) :
    teacher - (base + correction) = (teacher - base) - correction := by
  simp only [Rat.sub_eq_add_neg, Rat.neg_add]
  ac_rfl

/-- Product-reader errors include the mixed term. Separately minimizing gate
and up coefficient errors does not minimize the complete product response. -/
theorem product_difference (gate up dgate dup : Rat) :
    (gate + dgate) * (up + dup) - gate * up =
      gate * dup + dgate * up + dgate * dup := by
  simp only [Rat.sub_eq_add_neg, Rat.add_mul, Rat.mul_add]
  have rearrange :
      gate * up + dgate * up + (gate * dup + dgate * dup) + -(gate * up) =
      (gate * up + -(gate * up)) + (gate * dup + dgate * up + dgate * dup) := by ac_rfl
  rw [rearrange, Rat.add_neg_cancel, Rat.zero_add]

/-- Equal and opposite source errors can cancel at the complete endpoint. -/
theorem cancellation (a : Rat) : a + -a = 0 := Rat.add_neg_cancel a

end Kelana.JointResidualReader
