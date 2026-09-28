import Std

/-!
The checked finite aggregation step of the budgeted-odds certificate. The
real-logit outward-envelope inequality and the weighted singular-value
inequality in the study are analytic, not kernel-checked here. Their numerical
instances have rational-log interval certificates in certificate.py.
-/
namespace Kelana.BudgetedOddsGeometry

def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

/-- Once each binary KL cell has a valid nonnegative quadratic minorant,
any independently established weighted residual floor is a KL floor. The
finite index set need not be a complete rectangle or have uniform masses. -/
theorem aggregate_weighted_floor (cells : List I)
    (loss errorSq coefficient : I → Rat) (floor : Rat)
    (hcell : ∀ i ∈ cells, coefficient i * errorSq i ≤ loss i)
    (hresidual : floor ≤ total cells (fun i => coefficient i * errorSq i)) :
    floor ≤ total cells loss := by
  have sum_le : ∀ ys : List I,
      (∀ i ∈ ys, coefficient i * errorSq i ≤ loss i) →
      total ys (fun i => coefficient i * errorSq i) ≤ total ys loss := by
    intro ys
    induction ys with
    | nil => intro _; simp [total]
    | cons i rest ih =>
      intro h
      have hi := h i (by simp)
      have hr : ∀ j ∈ rest, coefficient j * errorSq j ≤ loss j := by
        intro j hj
        exact h j (by simp [hj])
      have ht := ih hr
      simp only [total, List.map_cons, List.sum_cons] at ht ⊢
      grind
  exact Rat.le_trans hresidual (sum_le cells hcell)

end Kelana.BudgetedOddsGeometry
