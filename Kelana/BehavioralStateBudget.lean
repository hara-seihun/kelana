import Init

namespace Kelana.BehavioralStateBudget

/-- A fractional allocation of one source state's mass to two candidate labels
    cannot beat assigning all its mass to its cheaper label when emissions are fixed. -/
theorem deterministic_le_split (leftMass rightMass leftLoss rightLoss : Nat) :
    (leftMass + rightMass) * min leftLoss rightLoss ≤
      leftMass * leftLoss + rightMass * rightLoss := by
  rw [Nat.add_mul]
  exact Nat.add_le_add
    (Nat.mul_le_mul_left leftMass (Nat.min_le_left leftLoss rightLoss))
    (Nat.mul_le_mul_left rightMass (Nat.min_le_right leftLoss rightLoss))

/-- The sum of individually cheapest labels is no worse than any split
    channel at fixed shared emission laws. Optimizing the laws afterward
    preserves the comparison, since deterministic channels are admissible. -/
theorem deterministic_le_splits (rows : List (Nat × Nat × Nat × Nat)) :
    (rows.map fun (n₀, n₁, x, y) => (n₀+n₁)*min x y).sum ≤
      (rows.map fun (n₀, n₁, x, y) => n₀*x+n₁*y).sum := by
  induction rows with
  | nil => simp
  | cons row rest ih =>
      rcases row with ⟨n₀, n₁, x, y⟩
      simp only [List.map_cons, List.sum_cons]
      exact Nat.add_le_add (deterministic_le_split n₀ n₁ x y) ih

end Kelana.BehavioralStateBudget
