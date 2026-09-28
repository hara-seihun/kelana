import Std

namespace Kelana.ContinuationContext

/-- A live machine state and the identities of static assets already paid for. -/
structure Prefix (S I : Type) where
  state : S
  paid : List I
  work : Nat

/-- An entire continuation is one program, shared across all input observations.
`response` can itself be a complete finite-domain map or tuple of consumer maps. -/
structure Grammar (S I U R : Type) [DecidableEq I] where
  legal : S → U → Prop
  response : S → U → R
  uses : U → List I
  suffixWork : S → U → Nat
  size : I → Nat

variable {S I U R : Type} [DecidableEq I] (g : Grammar S I U R)

def bytes (p : Prefix S I) (u : U) : Nat :=
  ((p.paid ++ g.uses u).eraseDups.map g.size).sum

def work (p : Prefix S I) (u : U) : Nat :=
  p.work + g.suffixWork p.state u

/-- A directed, target-independent residual-program simulation. The witnessing
continuation may differ from the one being replaced, but is chosen once for
all inputs of its complete response map. Static assets are charged by union. -/
def Simulates (a b : Prefix S I) : Prop :=
  ∀ u, g.legal b.state u → ∃ v, g.legal a.state v ∧
    g.response a.state v = g.response b.state u ∧
    bytes g a v ≤ bytes g b u ∧ work g a v ≤ work g b u

def Achieves (p : Prefix S I) (loss : R → Nat)
    (errorBudget byteBudget workBudget : Nat) : Prop :=
  ∃ u, g.legal p.state u ∧
    loss (g.response p.state u) ≤ errorBudget ∧
    bytes g p u ≤ byteBudget ∧ work g p u ≤ workBudget

theorem simulation_preserves_all_budgets {a b : Prefix S I}
    (h : Simulates g a b) (loss : R → Nat) (e n w : Nat) :
    Achieves g b loss e n w → Achieves g a loss e n w := by
  rintro ⟨u, hu, he, hn, hw⟩
  obtain ⟨v, hv, hr, hbn, hww⟩ := h u hu
  refine ⟨v, hv, ?_, ?_, ?_⟩
  · rw [hr]; exact he
  · exact Nat.le_trans hbn hn
  · exact Nat.le_trans hww hw

/-- Mutual simulation is strictly weaker than numeric-state equality, yet
preserves every error/bytes/work budget region, hence every Pareto frontier. -/
theorem mutual_simulation_iff_budgets {a b : Prefix S I}
    (hab : Simulates g a b) (hba : Simulates g b a)
    (loss : R → Nat) (e n w : Nat) :
    Achieves g a loss e n w ↔ Achieves g b loss e n w := by
  constructor
  · exact simulation_preserves_all_budgets g hba loss e n w
  · exact simulation_preserves_all_budgets g hab loss e n w

/-- A same-suffix implementation can forget paid identities once their complete
future union-charge profile agrees. Equality of today's paid total alone does
not establish this hypothesis. -/
theorem same_suffix_profile (a b : Prefix S I)
    (state : a.state = b.state) (online : a.work ≤ b.work)
    (static : ∀ u, bytes g a u ≤ bytes g b u) : Simulates g a b := by
  intro u hu
  refine ⟨u, ?_, ?_, static u, ?_⟩
  · simpa [state] using hu
  · simp [state]
  · simp only [work, state]
    exact Nat.add_le_add_right online _

/-- The converse is sharp: arbitrary terminal loss functions and independent
byte/work budgets can isolate any particular residual response and cost box.
No coarser directed relation can preserve ALL of those feasibility regions. -/
theorem simulation_of_all_budgets [DecidableEq R] {a b : Prefix S I}
    (h : ∀ (loss : R → Nat) e n w,
      Achieves g b loss e n w → Achieves g a loss e n w) :
    Simulates g a b := by
  intro u hu
  let target := g.response b.state u
  let isolated : R → Nat := fun r => if r = target then 0 else 1
  have hb : Achieves g b isolated 0 (bytes g b u) (work g b u) := by
    refine ⟨u, hu, ?_, Nat.le_refl _, Nat.le_refl _⟩
    simp [isolated, target]
  obtain ⟨v, hv, he, hn, hw⟩ := h isolated 0 (bytes g b u) (work g b u) hb
  have hr : g.response a.state v = g.response b.state u := by
    by_cases eq : g.response a.state v = target
    · exact eq
    · simp [isolated, eq] at he
  exact ⟨v, hv, hr, hn, hw⟩

theorem simulation_iff_all_budgets [DecidableEq R] {a b : Prefix S I} :
    Simulates g a b ↔
      ∀ (loss : R → Nat) e n w,
        Achieves g b loss e n w → Achieves g a loss e n w := by
  constructor
  · intro h loss e n w; exact simulation_preserves_all_budgets g h loss e n w
  · exact simulation_of_all_budgets g

/-- A finite constant-observer grammar identifies two distinct numeric states:
there is no need to carry machine distinctions erased by every continuation. -/
private def erased : Grammar Bool Bool Unit Bool where
  legal := fun _ _ => True
  response := fun _ _ => false
  uses := fun _ => []
  suffixWork := fun _ _ => 0
  size := fun _ => 1

private def low : Prefix Bool Bool := ⟨false, [], 0⟩
private def high : Prefix Bool Bool := ⟨true, [], 0⟩

theorem strictly_coarser_than_numeric :
    low.state ≠ high.state ∧ Simulates erased low high ∧ Simulates erased high low := by
  constructor
  · decide
  constructor
  · intro u _; exact ⟨(), trivial, rfl, Nat.le_refl _, Nat.le_refl _⟩
  · intro u _; exact ⟨(), trivial, rfl, Nat.le_refl _, Nat.le_refl _⟩

/-- When a zero-work continuation can directly observe the numeric state,
residual simulation cannot merge distinct labels. With arbitrarily many such
reachable labels this yields no universal strict state-count reduction. -/
private def exposing (T : Type) : Grammar T Bool Unit T where
  legal := fun _ _ => True
  response := fun s _ => s
  uses := fun _ => []
  suffixWork := fun _ _ => 0
  size := fun _ => 1

theorem exposure_obstructs_quotient {T : Type} (a b : Prefix T Bool)
    (h : Simulates (exposing T) a b) : a.state = b.state := by
  obtain ⟨_, _, hr, _, _⟩ := h () trivial
  exact hr

/-- Paid-set identities cannot be replaced by their current total byte count.
The only legal suffix reuses asset false, making the two prefixes unequal. -/
private def reuse : Grammar Bool Bool Unit Bool where
  legal := fun _ _ => True
  response := fun _ _ => false
  uses := fun _ => [false]
  suffixWork := fun _ _ => 0
  size := fun _ => 1

private def paidFalse : Prefix Bool Bool := ⟨false, [false], 0⟩
private def paidTrue : Prefix Bool Bool := ⟨false, [true], 0⟩

theorem unrelated_paid_identities_can_merge :
    paidFalse.paid ≠ paidTrue.paid ∧
    Simulates erased paidFalse paidTrue ∧ Simulates erased paidTrue paidFalse := by
  constructor
  · decide
  constructor
  · intro u _; exact ⟨(), trivial, rfl, Nat.le_refl _, Nat.le_refl _⟩
  · intro u _; exact ⟨(), trivial, rfl, Nat.le_refl _, Nat.le_refl _⟩

theorem shared_identity_separates :
    (paidFalse.paid.map reuse.size).sum = (paidTrue.paid.map reuse.size).sum ∧
    bytes reuse paidFalse () = 1 ∧ bytes reuse paidTrue () = 2 := by
  decide

end Kelana.ContinuationContext
