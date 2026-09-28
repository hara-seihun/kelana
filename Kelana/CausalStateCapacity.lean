import Kelana.Information

namespace Kelana.CausalStateCapacity

/-- State on a fixed repeated token after `n` transitions. -/
def orbit {X : Type} (step : X → X) (start : X) : Nat → X
  | 0 => start
  | n + 1 => step (orbit step start n)

theorem orbit_add {X : Type} (step : X → X) (start : X) (n k : Nat) :
    orbit step start (n + k) = orbit step (orbit step start n) k := by
  induction k with
  | zero => simp [orbit]
  | succ k ih =>
      change step (orbit step start (n + k)) =
        step (orbit step (orbit step start n) k)
      exact congrArg step ih

/-- C+1 arbitrary histories force a collision in any C-state candidate. -/
theorem prefix_collision (C : Nat) (states : Fin (C + 1) → Fin C) :
    ∃ i j : Fin (C + 1), i ≠ j ∧ states i = states j := by
  classical
  have noninjective : ¬ Function.Injective states := by
    intro injective
    have capacity := Information.injective_capacity states injective
    omega
  by_cases found : ∃ i j : Fin (C + 1), i ≠ j ∧ states i = states j
  · exact found
  · exfalso
    apply noninjective
    intro i j equal
    by_cases same : i = j
    · exact same
    · exact False.elim (found ⟨i, j, same, equal⟩)

/-- The repeated-token orbit forces its *last* state to revisit an earlier one,
    not merely an arbitrary pair of prefixes. This orientation is what forces
    a final changed emission to collide with an earlier law. -/
theorem last_orbit_state_repeats (C : Nat)
    (step : Fin C → Fin C) (start : Fin C) :
    ∃ i : Nat, i < C ∧ orbit step start i = orbit step start C := by
  let f : Fin (C + 1) → Fin C := fun i => orbit step start i.val
  obtain ⟨i, j, neq, equal⟩ := prefix_collision C f
  have distinct : i.val ≠ j.val := by
    intro same
    exact neq (Fin.ext same)
  have order : i.val < j.val ∨ j.val < i.val := by omega
  rcases order with left | right
  · let k := C - j.val
    have range : i.val + k < C := by
      dsimp [k]
      have hi := i.isLt
      have hj := j.isLt
      omega
    have shifted := congrArg (fun z => orbit step z k) equal
    dsimp [f] at shifted
    rw [← orbit_add step start i.val k, ← orbit_add step start j.val k] at shifted
    have end_index : j.val + k = C := by omega
    rw [end_index] at shifted
    exact ⟨i.val + k, range, shifted⟩
  · let k := C - i.val
    have range : j.val + k < C := by
      dsimp [k]
      have hi := i.isLt
      have hj := j.isLt
      omega
    have shifted := congrArg (fun z => orbit step z k) equal.symm
    dsimp [f] at shifted
    rw [← orbit_add step start j.val k, ← orbit_add step start i.val k] at shifted
    have end_index : i.val + k = C := by omega
    rw [end_index] at shifted
    exact ⟨j.val + k, range, shifted⟩

/-- C states cannot emit one stationary law for C repeated-token phases and
    a different law on the next phase. A C+1-state clock realizes both exactly. -/
theorem changed_final_law_impossible {Y : Type} (C : Nat)
    (step : Fin C → Fin C) (start : Fin C) (readout : Fin C → Y)
    (early final : Y) (different : early ≠ final)
    (early_phases : ∀ i, i < C → readout (orbit step start i) = early)
    (last_phase : readout (orbit step start C) = final) : False := by
  obtain ⟨i, within, repeats⟩ := last_orbit_state_repeats C step start
  apply different
  calc
    early = readout (orbit step start i) := (early_phases i within).symm
    _ = readout (orbit step start C) := congrArg readout repeats
    _ = final := last_phase

/-- Deterministic candidate states reached after a shared token suffix remain
    identical. This is the right-congruence obligation behind suffix witnesses. -/
def follow {X A : Type} (transition : X → A → X) (state : X) : List A → X
  | [] => state
  | a :: rest => follow transition (transition state a) rest

theorem follow_congr {X A : Type} (transition : X → A → X)
    (left right : X) (suffix : List A) (equal : left = right) :
    follow transition left suffix = follow transition right suffix := by
  subst right
  rfl

end Kelana.CausalStateCapacity
