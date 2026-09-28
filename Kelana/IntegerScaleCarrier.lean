import Kelana.ScaledTrit

namespace Kelana.IntegerScaleCarrier
open Lean.Grind

/-- A single outer scale makes the accumulator itself the carried representation.
No block boundary appears in this algebraic specification. -/
theorem whole_projection {R : Type} [CommRing R]
    (weights activations : List R) (rowScale tokenScale : R) :
    Kelana.ScaledTrit.block
      (weights.map (fun w => rowScale * w))
      (activations.map (fun x => tokenScale * x)) =
    (rowScale * tokenScale) * Kelana.ScaledTrit.block weights activations :=
  Kelana.ScaledTrit.absorb_block_scales weights activations rowScale tokenScale

/-- Uniform per-term bounds cover every order and every prefix of a finite sum. -/
theorem sum_bounds (xs : List Int) (B : Int)
    (h : ∀ x ∈ xs, -B ≤ x ∧ x ≤ B) :
    -(xs.length : Int) * B ≤ xs.sum ∧ xs.sum ≤ (xs.length : Int) * B := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
    have hx := h x (by simp)
    have ht := ih (by intro y hy; exact h y (by simp [hy]))
    simp only [List.length_cons, List.sum_cons, Int.natCast_add, Int.natCast_one]
    constructor <;> grind

/-- An IU8 product fits this interval; the proof does not use observed weights. -/
theorem product_bounds (w x : Int)
    (hw : -127 ≤ w ∧ w ≤ 127) (hx : -127 ≤ x ∧ x ≤ 127) :
    -16129 ≤ w*x ∧ w*x ≤ 16129 := by
  have a := Int.mul_nonneg (show 0 ≤ w + 127 by omega) (show 0 ≤ x + 127 by omega)
  have b := Int.mul_nonneg (show 0 ≤ 127 - w by omega) (show 0 ≤ 127 - x by omega)
  have c := Int.mul_nonneg (show 0 ≤ w + 127 by omega) (show 0 ≤ 127 - x by omega)
  have d := Int.mul_nonneg (show 0 ≤ 127 - w by omega) (show 0 ≤ x + 127 by omega)
  constructor <;> grind

/-- This applies to any prefix whose length is at most the larger projection K.
It proves integer range only, not the fitted scales or floating-point boundary. -/
theorem projection_int32_safe (terms : List Int)
    (hlen : terms.length ≤ 17408)
    (hterm : ∀ x ∈ terms, -16129 ≤ x ∧ x ≤ 16129) :
    -2147483648 ≤ terms.sum ∧ terms.sum < 2147483648 := by
  have h := sum_bounds terms 16129 hterm
  omega

end Kelana.IntegerScaleCarrier
