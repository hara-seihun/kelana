import Std

namespace Kelana.IndependentReadout

def sumCells {Label Value : Type} (labels : List Label)
    (cell : Label → Value → Int) (q : Label → Value) : Int :=
  (labels.map (fun l => cell l (q l))).sum

theorem pointwise_minima {Label Value : Type} (labels : List Label)
    (cell : Label → Value → Int) (legal : Label → Value → Prop)
    (qstar : Label → Value)
    (minimal : ∀ l ∈ labels, ∀ v, legal l v → cell l (qstar l) ≤ cell l v)
    (q : Label → Value) (hq : ∀ l ∈ labels, legal l (q l)) :
    sumCells labels cell qstar ≤ sumCells labels cell q := by
  induction labels with
  | nil => simp [sumCells]
  | cons l ls ih =>
    have hhead := minimal l (by simp) (q l) (hq l (by simp))
    have htail := ih (by
      intro j hj v hv
      exact minimal j (by simp [hj]) v hv) (by
      intro j hj
      exact hq j (by simp [hj]))
    simp only [sumCells, List.map_cons, List.sum_cons] at *
    omega

/-- Simultaneous observations may share a cell. Group them by that cell before
minimizing. No independence of the original source operations is required. -/
theorem eliminate_reader {Label Value : Type} (labels : List Label)
    (cell : Label → Value → Int) (legal : Label → Value → Prop)
    (loss : (Label → Value) → Int)
    (grouped : ∀ q, loss q = sumCells labels cell q)
    (qstar : Label → Value)
    (feasible : ∀ l ∈ labels, legal l (qstar l))
    (minimal : ∀ l ∈ labels, ∀ v, legal l v → cell l (qstar l) ≤ cell l v) :
    (∀ l ∈ labels, legal l (qstar l)) ∧
    ∀ q, (∀ l ∈ labels, legal l (q l)) → loss qstar ≤ loss q := by
  refine ⟨feasible, ?_⟩
  intro q hq
  rw [grouped, grouped]
  exact pointwise_minima labels cell legal qstar minimal q hq

def sse (ys : List Int) (q : Int) : Int :=
  (ys.map (fun y => (q-y)*(q-y))).sum

def squares (ys : List Int) : Int := (ys.map (fun y => y*y)).sum

theorem square_expansion (q y : Int) :
    (q-y)*(q-y) = q*q - 2*y*q + y*y := by
  simp only [Int.sub_mul, Int.mul_sub]
  rw [Int.mul_comm q y]
  simp only [Int.mul_assoc]
  omega

/-- Three integer sufficient statistics determine all table-cell scores. -/
theorem sufficient_statistics (ys : List Int) (q : Int) :
    sse ys q = (ys.length : Int)*q*q - 2*ys.sum*q + squares ys := by
  induction ys with
  | nil => simp [sse, squares]
  | cons y ys ih =>
    simp only [sse, List.map_cons, List.sum_cons] at ih ⊢
    rw [square_expansion, ih]
    simp only [List.length_cons, Int.natCast_add, Int.natCast_one,
      List.sum_cons, squares, List.map_cons, Int.add_mul, Int.mul_add,
      Int.one_mul]
    omega

/-- An exact quadratic-grid minimizer is an exact squared-error minimizer. -/
theorem quadratic_minimizer (ys : List Int) (qstar : Int)
    (legal : Int → Prop)
    (minimal : ∀ q, legal q →
      (ys.length : Int)*qstar*qstar - 2*ys.sum*qstar ≤
      (ys.length : Int)*q*q - 2*ys.sum*q) :
    ∀ q, legal q → sse ys qstar ≤ sse ys q := by
  intro q hq
  rw [sufficient_statistics, sufficient_statistics]
  have h := minimal q hq
  omega

/-- A prefix projection prepass cannot reject more than an existing exact
partial-error test at the same trie node and a no-worse incumbent. -/
theorem prepass_prune_is_redundant (floor partialLoss oldIncumbent currentIncumbent : Int)
    (lower : floor ≤ partialLoss) (improved : currentIncumbent ≤ oldIncumbent)
    (pruned : oldIncumbent < floor) : currentIncumbent < partialLoss := by
  omega

#print axioms prepass_prune_is_redundant
#print axioms eliminate_reader
#print axioms sufficient_statistics
#print axioms quadratic_minimizer
end Kelana.IndependentReadout
