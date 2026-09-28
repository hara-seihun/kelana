import Std

/-!
Algebraic centering identity: after clearing the denominator, the freely
chosen output intercept contributes one nonnegative square. The exact
captured-panel covariance, PSD and edge inequalities live in verify.py.
-/
namespace Kelana.AffinePairCovariance

/-- If `sum` is the total of n response residuals and `sumsq` their squared
sum, the best free intercept is `sum/n` for n>0. -/
theorem intercept_square (n sum sumsq intercept : Int) :
    n * (sumsq - 2 * intercept * sum + n * intercept * intercept) =
      n * sumsq - sum * sum +
        (n * intercept - sum) * (n * intercept - sum) := by
  simp only [show ∀ x : Int, 2 * x = x + x by intro x; omega]
  simp only [Int.add_mul, Int.mul_add, Int.sub_mul, Int.mul_sub]
  simp only [Int.mul_comm, Int.mul_left_comm]
  omega

end Kelana.AffinePairCovariance
