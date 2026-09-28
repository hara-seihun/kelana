import Std

namespace Kelana.ResidualGauge

/-- Transport an arbitrary nonlinear branch through a single additive residual
coordinate. Both sides of the residual sum must carry the same label. -/
theorem transported_residual (encode decode branch : Int → Int)
    (additive : ∀ x y, encode (x + y) = encode x + encode y)
    (inverse : ∀ z, encode (decode z) = z) (z : Int) :
    encode (decode z + branch (decode z)) =
      z + encode (branch (decode z)) := by
  rw [additive, inverse]

/-- In a two-coordinate orthogonal plane, diagonality of the conjugated
non-scalar gamma forbids mixing: its off-diagonal is `(a-b)*c*s`. -/
theorem distinct_gamma_forbids_plane_mixing (a b c s : Int)
    (distinct : a ≠ b) (diagonal : (a-b)*c*s = 0) : c = 0 ∨ s = 0 := by
  have difference : a-b ≠ 0 := by omega
  rcases Int.mul_eq_zero.mp diagonal with h | h
  · exact Or.inl ((Int.mul_eq_zero.mp h).resolve_left difference)
  · exact Or.inr h

end Kelana.ResidualGauge
