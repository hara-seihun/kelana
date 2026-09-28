import Std

/-!
Cleared-denominator squares for the shared output-vector covariance dual.
The dataset PSD, 8,128 edge cones, and strict scalar-Q4 comparison are checked
separately by verify.py with integer arithmetic.
-/
namespace Kelana.FullPairCovariance

/-- Shifting a coordinate's teacher weight by a common dual vector incurs
one subtraction of the dual-vector norm even for an unmatched coordinate. -/
theorem shifted_coordinate (d w a p : Int) :
    d * (d * (w - a) * (w - a) + 2 * p * (w - a)) + p * p =
      (d * (w - a) + p) * (d * (w - a) + p) := by
  simp only [show ∀ x : Int, 2 * x = x + x by intro x; omega]
  simp only [Int.add_mul, Int.mul_add, Int.sub_mul, Int.mul_sub]
  simp only [Int.mul_comm, Int.mul_left_comm]
  omega

/-- A positive covariance mode is paid once for the whole error map, not once
per selected pair. This is the numerator of its Fenchel square. -/
theorem shared_mode (beta error dual : Int) :
    beta * (beta * error * error - 2 * dual * error) + dual * dual =
      (beta * error - dual) * (beta * error - dual) := by
  simp only [show ∀ x : Int, 2 * x = x + x by intro x; omega]
  simp only [Int.add_mul, Int.mul_add, Int.sub_mul, Int.mul_sub]
  simp only [Int.mul_comm, Int.mul_left_comm]
  omega

end Kelana.FullPairCovariance
