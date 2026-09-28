import Std

/-!
Cleared-denominator weighted two-coordinate carrier identity. The numerical
Gram eigenvalue and response certificates are separate from this algebra.
-/
namespace Kelana.WeightedInputPairs

/-- For carrier xᵢ + ratio*xⱼ and a free output coefficient, completing the
square leaves the weighted discrepancy ratio*wᵢ-wⱼ. -/
theorem weighted_pair_identity (di dj ratio a b : Int) :
    (di + dj * ratio * ratio) * (di * a * a + dj * b * b) -
      (di * a + dj * ratio * b) * (di * a + dj * ratio * b) =
        di * dj * (ratio * a - b) * (ratio * a - b) := by
  simp only [Int.add_mul, Int.mul_add, Int.sub_mul, Int.mul_sub]
  simp only [Int.mul_comm, Int.mul_left_comm]
  omega

end Kelana.WeightedInputPairs
