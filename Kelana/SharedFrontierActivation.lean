import Std

namespace Kelana.SharedFrontierActivation

/-- Conditional saving at one region when a new executable family is available. -/
private theorem conditional_min (a b : Int) :
    min a b = a - max 0 (a - b) := by
  by_cases h : a ≤ b
  · rw [Int.min_eq_left h, Int.max_eq_left (show a - b ≤ 0 by omega)]
    omega
  · have hb : b ≤ a := by omega
    rw [Int.min_eq_right hb, Int.max_eq_right (show 0 ≤ a - b by omega)]
    omega

def incumbent : List (Int × Int) → Int
  | [] => 0
  | (a, _) :: rest => a + incumbent rest

def withFamily : List (Int × Int) → Int
  | [] => 0
  | (a, b) :: rest => min a b + withFamily rest

def savings : List (Int × Int) → Int
  | [] => 0
  | (a, b) :: rest => max 0 (a - b) + savings rest

private theorem accounting (regions : List (Int × Int)) :
    withFamily regions = incumbent regions - savings regions := by
  induction regions with
  | nil => rfl
  | cons pair rest ih =>
      obtain ⟨a, b⟩ := pair
      simp only [withFamily, incumbent, savings, ih, conditional_min]
      omega

/-- For a fixed installed set and additive scalarized objective, opening one
new family wins exactly when its setup bill is less than the sum of positive
conditional per-region savings. The incumbent may already be the best fitted
scalar, direct table, or another installed family. -/
theorem activation_iff (regions : List (Int × Int)) (setup : Int) :
    setup + withFamily regions < incumbent regions ↔
      setup < savings regions := by
  rw [accounting]
  omega

/-- The four-dimensional vector (3,11,5,4) has no supporting nonzero
nonnegative weight: two feasible endpoints have a strictly cheaper midpoint
whenever a resource is priced, while an exact direct image wins when only
error is priced. Products below are linear because witness coordinates are
fixed constants. -/
theorem unsupported_by_any_nonzero_weights
    (errorWeight byteWeight workWeight preparedWeight : Nat)
    (nonzero : 0 < errorWeight + byteWeight + workWeight + preparedWeight) :
    (0 * errorWeight + 14 * byteWeight + 6 * workWeight + 0 * preparedWeight <
        3 * errorWeight + 11 * byteWeight + 5 * workWeight + 4 * preparedWeight) ∨
    (2 * errorWeight + 12 * byteWeight + 5 * workWeight + 0 * preparedWeight <
        3 * errorWeight + 11 * byteWeight + 5 * workWeight + 4 * preparedWeight) ∨
    (4 * errorWeight + 9 * byteWeight + 4 * workWeight + 0 * preparedWeight <
        3 * errorWeight + 11 * byteWeight + 5 * workWeight + 4 * preparedWeight) := by
  omega

end Kelana.SharedFrontierActivation
