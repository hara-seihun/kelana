import Std

namespace Kelana.Amortization

/-- A division-free epsilon definition: work/N is eventually at most 1/k for every k>0. -/
def VanishesPerUse (work : Nat → Nat) : Prop :=
  ∀ k : Nat, 0 < k → ∃ threshold : Nat, 0 < threshold ∧
    ∀ n, threshold ≤ n → k * work n ≤ n

theorem finite_setup_vanishes (setup : Nat) : VanishesPerUse (fun _ => setup) := by
  intro k _
  refine ⟨k * setup + 1, by omega, ?_⟩
  intro n hn
  dsimp
  omega

def total (setup recurring uses : Nat) : Nat := setup + uses * recurring

theorem exact_excess (setup recurring uses : Nat) :
    total setup recurring uses - uses * recurring = setup := by
  unfold total
  omega

/-- This is the selected infinite-reuse rule, not an assumption that weights are literals. -/
theorem recurring_cost_limit (setup recurring : Nat) :
    (∀ n, n * recurring ≤ total setup recurring n) ∧
    VanishesPerUse (fun n => total setup recurring n - n * recurring) := by
  constructor
  · intro n; unfold total; omega
  · simpa only [exact_excess] using finite_setup_vanishes setup

/-- One unit of recurring work per use does not vanish. -/
theorem recurring_work_does_not_vanish : ¬ VanishesPerUse (fun n => n) := by
  intro h
  obtain ⟨threshold, ht, hbound⟩ := h 2 (by decide)
  have hbad := hbound threshold (by omega)
  dsimp at hbad
  omega

/-- Any finite loading bill eventually loses to a strictly smaller recurring bill. -/
theorem lower_recurring_eventually_wins (setup₁ setup₂ cost₁ cost₂ : Nat)
    (hc : cost₁ < cost₂) :
    ∃ threshold : Nat, ∀ n, threshold ≤ n →
      total setup₁ cost₁ n < total setup₂ cost₂ n := by
  refine ⟨setup₁ + 1, ?_⟩
  intro n hn
  have hmul := Nat.mul_le_mul_left n (show cost₁ + 1 ≤ cost₂ by omega)
  simp only [Nat.mul_add, Nat.mul_one] at hmul
  unfold total
  omega

end Kelana.Amortization
