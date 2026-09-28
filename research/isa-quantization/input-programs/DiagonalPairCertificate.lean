import Std

/-!
The algebra behind a diagonal producer-covariance minorant. The exact
numeric certificate is independently replayed in verify_diagonal.py.
-/
namespace Kelana.InputPrograms.DiagonalPairCertificate

/-- Clearing the positive denominator in the optimal two-coordinate
quadratic residual leaves precisely the signed column difference. -/
theorem harmonic_identity (di dj a b : Int) :
    (di + dj) * (di * a * a + dj * b * b) -
      (di * a + dj * b) * (di * a + dj * b) =
        di * dj * (a - b) * (a - b) := by
  simp only [Int.add_mul, Int.mul_add, Int.sub_mul, Int.mul_sub]
  simp only [Int.mul_comm, Int.mul_left_comm]
  omega

end Kelana.InputPrograms.DiagonalPairCertificate
