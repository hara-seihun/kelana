import Kelana.CovarianceCompletion

namespace Kelana.MetricResidualGauge

open Kelana.CovarianceCompletion (total quadratic response gram gram_quadratic norm2)

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

private theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i + g i) = total xs f + total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a * f i) = a * total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_mul_right (xs : List I) (f : I → Rat) (a : Rat) :
    total xs (fun i => f i * a) = total xs f * a := by
  calc
    _ = total xs (fun i => a * f i) := by
      apply total_congr xs; intro i hi; exact Rat.mul_comm _ _
    _ = a * total xs f := total_mul xs _ _
    _ = _ := Rat.mul_comm _ _

private theorem total_comm (xs : List I) (ys : List J) (f : I → J → Rat) :
    total xs (fun i => total ys (f i)) =
      total ys (fun j => total xs (fun i => f i j)) := by
  induction xs with
  | nil =>
    simp only [total, List.map_nil, List.sum_nil]
    induction ys with
    | nil => rfl
    | cons j ys ih => simp only [List.map_cons, List.sum_cons]; grind
  | cons i xs ih =>
    change total ys (f i) + total xs (fun k => total ys (f k)) =
      total ys (fun j => f i j + total xs (fun k => f k j))
    rw [ih, total_add]

/-- `U` is the inverse residual-coordinate map: old x = U z. -/
def metric (old : List I) (U : I → J → Rat) (j k : J) : Rat :=
  total old (fun i => U i j * U i k)

/-- Congruence pulls the *signed* final gain into the shared new coordinate.
    There is no positivity assumption on gamma. -/
def gain (old : List I) (gamma : I → Rat)
    (U : I → J → Rat) (j k : J) : Rat :=
  total old (fun i => gamma i * U i j * U i k)

/-- The transported norm is a genuine Gram form and is PSD. It can be dense
    even if the old norm was Euclidean and the final gain is diagonal. -/
theorem metric_energy (old : List I) (new : List J)
    (U : I → J → Rat) (z : J → Rat) :
    quadratic new (metric old U) z =
      norm2 old (fun i => total new (fun j => z j * U i j)) := by
  exact gram_quadratic new old (fun j i => U i j) z

/-- Weighted finite Fubini; the gain identity works equally for positive and
    negative diagonal entries. -/
theorem gain_energy (old : List I) (new : List J)
    (gamma : I → Rat) (U : I → J → Rat) (z : J → Rat) :
    quadratic new (gain old gamma U) z =
      total old (fun i => gamma i *
        (total new (fun j => z j * U i j)) *
        (total new (fun j => z j * U i j))) := by
  unfold quadratic gain
  calc
    _ = total new (fun j => total new (fun k => total old (fun i =>
        gamma i * (z j * U i j) * (z k * U i k)))) := by
      apply total_congr new; intro j hj
      apply total_congr new; intro k hk
      calc
        _ = total old (fun i => z j * (gamma i * U i j * U i k) * z k) := by
          rw [← total_mul, ← total_mul_right]
        _ = _ := by apply total_congr old; intro i hi; grind +ring
    _ = total old (fun i => total new (fun j => total new (fun k =>
        gamma i * (z j * U i j) * (z k * U i k)))) := by
      calc
        _ = total new (fun j => total old (fun i => total new (fun k =>
            gamma i * (z j * U i j) * (z k * U i k)))) := by
          apply total_congr new; intro j hj; exact total_comm new old _
        _ = _ := total_comm new old _
    _ = _ := by
      apply total_congr old; intro i hi
      calc
        _ = total new (fun j => (gamma i * (z j * U i j)) *
            total new (fun k => z k * U i k)) := by
          apply total_congr new; intro j hj; exact total_mul new _ _
        _ = total new (fun j => gamma i * (z j * U i j)) *
            total new (fun k => z k * U i k) := total_mul_right new _ _
        _ = gamma i * (total new (fun j => z j * U i j)) *
            total new (fun k => z k * U i k) := by rw [total_mul]

/-- If the old vector is explicitly recovered as U applied to z, these are
    exactly its Euclidean norm and signed final-gain quadratic, respectively.
    This is the algebra used at *every* residual RMSNorm, not just the last. -/
theorem transported_norm_and_gain (old : List I) (new : List J)
    (gamma : I → Rat) (U : I → J → Rat)
    (x : I → Rat) (z : J → Rat)
    (recovers : ∀ i ∈ old, x i = total new (fun j => z j * U i j)) :
    quadratic new (metric old U) z = norm2 old x ∧
    quadratic new (gain old gamma U) z =
      total old (fun i => gamma i * x i * x i) := by
  constructor
  · rw [metric_energy]
    apply total_congr old
    intro i hi
    rw [recovers i hi]
  · rw [gain_energy]
    apply total_congr old
    intro i hi
    rw [recovers i hi]

/-- Two distinct old gains: if both the pulled norm metric and pulled gain
    remain diagonal, the inverse-map columns cannot mix both old axes. -/
theorem distinct_gain_diagonal_metric (g₁ g₂ a b c d : Rat)
    (different : g₁ ≠ g₂)
    (metric_off : a*c + b*d = 0)
    (gain_off : g₁*a*c + g₂*b*d = 0) :
    a*c = 0 ∧ b*d = 0 := by
  have h : (g₁-g₂) * (a*c) = 0 := by grind +ring
  have hprod := Rat.mul_eq_zero.mp h
  rcases hprod with hzero | hzero
  · exact False.elim (different (by grind))
  · constructor
    · exact hzero
    · grind

/-- With an invertible 2×2 inverse gauge, diagonal metric and diagonal
    distinct-gain endpoint force an axis scaling or an axis swap. -/
theorem two_axis_no_mix (g₁ g₂ a b c d : Rat)
    (different : g₁ ≠ g₂) (det : a*d - b*c ≠ 0)
    (metric_off : a*c + b*d = 0)
    (gain_off : g₁*a*c + g₂*b*d = 0) :
    (b = 0 ∧ c = 0) ∨ (a = 0 ∧ d = 0) := by
  obtain ⟨hac, hbd⟩ := distinct_gain_diagonal_metric g₁ g₂ a b c d
    different metric_off gain_off
  rcases Rat.mul_eq_zero.mp hac with ha | hc
  · rcases Rat.mul_eq_zero.mp hbd with hb | hd
    · exact False.elim (det (by grind +ring))
    · exact Or.inr ⟨ha, hd⟩
  · rcases Rat.mul_eq_zero.mp hbd with hb | hd
    · exact Or.inl ⟨hb, hc⟩
    · exact False.elim (det (by grind +ring))

/-- Exact mixed-sign 2D witness. U=[[5/3,4/3],[4/3,5/3]] has determinant 1;
    it retains the signed diagonal gain (1,-1) but makes the norm metric
    [[41/9,40/9],[40/9,41/9]]. The folded row (5/3,-4/3) has zero second
    column after multiplying by U. Thus orthogonality, not tied gain alone,
    caused the earlier exact slice obstruction. -/
theorem mixed_sign_paid_slice :
    let U : Bool → Bool → Rat := fun old new =>
      if old = new then 5/3 else 4/3
    let gamma : Bool → Rat := fun i => if i then -1 else 1
    let folded : Bool → Rat := fun i => if i then -(4/3) else 5/3
    (U false false * U true true - U false true * U true false = 1) ∧
    (gain [false, true] gamma U false false = 1) ∧
    (gain [false, true] gamma U true true = -1) ∧
    (gain [false, true] gamma U false true = 0) ∧
    (metric [false, true] U false false = 41/9) ∧
    (metric [false, true] U false true = 40/9) ∧
    (metric [false, true] U true true = 41/9) ∧
    (total [false, true] (fun i => folded i * U i true) = 0) ∧
    (total [false, true] (fun i => folded i * U i false) = 1) := by
  decide +kernel

end Kelana.MetricResidualGauge
