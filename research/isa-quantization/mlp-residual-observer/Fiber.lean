import Std

namespace Kelana.MLPResidualObserver

/-- Squared first-coordinate RMSNorm observation in dimension two, gamma₁=1.
    The runtime observation is its square root with the sign of `a` retained. -/
def firstSquared (eps a b : Rat) : Rat :=
  a*a / (eps + (a*a+b*b)/2)

/-- A complete first-coordinate reader has equal response at two distinct
    residuals, even though epsilon is positive. -/
theorem exact_projected_fiber :
    firstSquared 1 1 4 = firstSquared 1 (1/3) 0 := by
  native_decide

/-- The unobserved coordinate remains distinguishable by a second live reader. -/
theorem second_coordinate_differs : (4 : Rat) ≠ 0 := by
  native_decide

/-- With a genuine skip h=(2,0), the source and alternative branches differ;
    neither was obtained by taking the normalized MLP input as the skip. -/
theorem branch_differs : ((1 : Rat)-2, (4 : Rat)-0) ≠
    (((1/3 : Rat)-2), (0 : Rat)-0) := by
  native_decide

end Kelana.MLPResidualObserver
