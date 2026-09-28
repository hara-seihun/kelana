import Kelana.CollisionPacking

namespace Kelana.InformationPacking

/-! Finite algebra of subset information budgets and overlap-safe packing.
The entropy variables below are rational potentials: applying the result to
real Shannon entropy requires the separate real-log identity, the bound
H(G|Y) ≥ 0, and an upper bound on H(G) (such as log C or a heavy-atom cap).
No numerical log is treated as a rational theorem. -/

variable {Source : Type}

private theorem sum_nonnegative {α : Type} (xs : List α) (f : α → Rat)
    (hf : ∀ x ∈ xs, 0 ≤ f x) : 0 ≤ (xs.map f).sum := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
      simp only [List.map_cons, List.sum_cons]
      have hx := hf x (by simp)
      have ht := ih (by intro y hy; exact hf y (by simp [hy]))
      grind

private theorem member_weight_le_sum {α : Type} (xs : List α) (w : α → Rat)
    (nonnegative : ∀ x, 0 ≤ w x) (a : α) (member : a ∈ xs) :
    w a ≤ (xs.map w).sum := by
  induction xs with
  | nil => simp at member
  | cons x xs ih =>
      simp only [List.map_cons, List.sum_cons]
      simp only [List.mem_cons] at member
      rcases member with heq | tail
      · subst x
        have h := sum_nonnegative xs w (by intro y hy; exact nonnegative y)
        grind
      · have h := ih tail
        grind [nonnegative x]

/-- The decoder label containing a heavy source has at least that source's
mass, regardless of how all other sources are aggregated. -/
theorem heavy_label_mass {Label : Type} [DecidableEq Label]
    (sources : List Source) (weight : Source → Rat) (g : Source → Label)
    (nonnegative : ∀ s, 0 ≤ weight s) (heavy : Source)
    (member : heavy ∈ sources) :
    weight heavy ≤
      (sources.map fun s => if g s = g heavy then weight s else 0).sum := by
  let w (s : Source) := if g s = g heavy then weight s else 0
  have hw (s : Source) : 0 ≤ w s := by
    dsimp [w]
    split <;> simp [nonnegative]
  have h := member_weight_le_sum sources w hw heavy member
  simpa [w] using h

/-- In each subset, clustering loss is teacher information not represented by
its common label: H(Y|G)-H(Y|S) = I(S;Y)-I(G;Y). -/
theorem information_budget (outputEntropy sourceConditionalEntropy
    labelEntropy labelConditionalEntropy budget loss : Rat)
    (identity : loss = outputEntropy - sourceConditionalEntropy -
      labelEntropy + labelConditionalEntropy)
    (remaining : 0 ≤ labelConditionalEntropy)
    (capacity : labelEntropy ≤ budget) :
    outputEntropy - sourceConditionalEntropy - budget ≤ loss := by
  rw [identity]
  grind

/-- Allow any collection of possibly overlapping subsets. For every subset,
`balance` is the entropy chain rule, `capacity` upper-bounds its label entropy,
and a proposed floor is either the information-budget difference or zero.
The incidence shares prohibit charging one source repeatedly. -/
theorem packed_information_budget [DecidableEq Source]
    (sources : List Source) (edges : List (List Source))
    (share floor : List Source → Rat) (cost : Source → Rat)
    (outputEntropy sourceConditionalEntropy labelEntropy
      labelConditionalEntropy budget : List Source → Rat)
    (costNonnegative : ∀ s, 0 ≤ cost s)
    (loads : ∀ s ∈ sources,
      CollisionPacking.load edges share s ≤ 1)
    (shares : ∀ e ∈ edges, 0 ≤ share e)
    (balance : ∀ e ∈ edges,
      (sources.map fun s => if s ∈ e then cost s else 0).sum =
        outputEntropy e - sourceConditionalEntropy e -
          labelEntropy e + labelConditionalEntropy e)
    (remaining : ∀ e ∈ edges, 0 ≤ labelConditionalEntropy e)
    (capacity : ∀ e ∈ edges, labelEntropy e ≤ budget e)
    (floorChoice : ∀ e ∈ edges,
      floor e = 0 ∨ floor e ≤ outputEntropy e - sourceConditionalEntropy e - budget e) :
    (edges.map fun e => share e * floor e).sum ≤ (sources.map cost).sum := by
  apply CollisionPacking.packed_collision_floor sources edges share floor cost
    costNonnegative loads shares
  intro e he
  rcases floorChoice e he with hzero | hbound
  · rw [hzero]
    apply sum_nonnegative
    intro s hs
    split <;> simp [costNonnegative]
  · exact Rat.le_trans hbound (information_budget
      (outputEntropy e) (sourceConditionalEntropy e) (labelEntropy e)
      (labelConditionalEntropy e) (budget e)
      ((sources.map fun s => if s ∈ e then cost s else 0).sum)
      (balance e he) (remaining e he) (capacity e he))

end Kelana.InformationPacking
