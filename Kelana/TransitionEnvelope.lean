import Init

namespace Kelana.TransitionEnvelope

-- A missing candidate edge may pick either destination independently at each visit.
-- This is a relaxation of one globally fixed completion, not an implementation.
def relaxedChoice (known : Bool → Bool → Option Bool) (c a : Bool)
    (v : Bool → Nat) : Nat :=
  match known c a with
  | some destination => v destination
  | none => min (v false) (v true)

def relaxed {S : Type} (p : S → Bool → Nat) (teacher : S → Bool → S)
    (cost : S → Bool → Nat) (known : Bool → Bool → Option Bool) :
    Nat → S → Bool → Nat
  | 0, _, _ => 0
  | h + 1, s, c =>
      cost s c +
      p s false * relaxedChoice known c false (relaxed p teacher cost known h (teacher s false)) +
      p s true * relaxedChoice known c true (relaxed p teacher cost known h (teacher s true))

def complete {S : Type} (p : S → Bool → Nat) (teacher : S → Bool → S)
    (cost : S → Bool → Nat) (candidate : Bool → Bool → Bool) :
    Nat → S → Bool → Nat
  | 0, _, _ => 0
  | h + 1, s, c =>
      cost s c +
      p s false * complete p teacher cost candidate h (teacher s false) (candidate c false) +
      p s true * complete p teacher cost candidate h (teacher s true) (candidate c true)

def Extends (known : Bool → Bool → Option Bool) (candidate : Bool → Bool → Bool) : Prop :=
  ∀ c a destination, known c a = some destination → candidate c a = destination

def hasKnownException (known : Bool → Bool → Option Bool) : Prop :=
  ∃ c a destination, known c a = some destination ∧ destination ≠ c

def hasCompleteException (candidate : Bool → Bool → Bool) : Prop :=
  ∃ c a, candidate c a ≠ c

noncomputable def knownTransitionBits (known : Bool → Bool → Option Bool) : Nat := by
  classical
  exact if hasKnownException known then 5 else 1

noncomputable def completeTransitionBits (candidate : Bool → Bool → Bool) : Nat := by
  classical
  exact if hasCompleteException candidate then 5 else 1

theorem transitionBits_le {known : Bool → Bool → Option Bool}
    {candidate : Bool → Bool → Bool} (agrees : Extends known candidate) :
    knownTransitionBits known ≤ completeTransitionBits candidate := by
  have exception_mono : hasKnownException known → hasCompleteException candidate := by
    rintro ⟨c, a, destination, h, different⟩
    refine ⟨c, a, ?_⟩
    simpa [agrees c a destination h] using different
  classical
  unfold knownTransitionBits completeTransitionBits
  by_cases hp : hasKnownException known
  · simp [hp, exception_mono hp]
  · simp only [hp, ↓reduceIte]
    split <;> omega

theorem relaxedChoice_le {known : Bool → Bool → Option Bool}
    {candidate : Bool → Bool → Bool} (agrees : Extends known candidate)
    (c a : Bool) (v : Bool → Nat) :
    relaxedChoice known c a v ≤ v (candidate c a) := by
  unfold relaxedChoice
  cases h : known c a with
  | some destination =>
      have same := agrees c a destination h
      simp only [same]
      exact Nat.le_refl _
  | none =>
      cases candidate c a with
      | false => exact Nat.min_le_left _ _
      | true => exact Nat.min_le_right _ _

theorem relaxed_le_complete {S : Type} (p : S → Bool → Nat)
    (teacher : S → Bool → S) (cost : S → Bool → Nat)
    (known : Bool → Bool → Option Bool) (candidate : Bool → Bool → Bool)
    (agrees : Extends known candidate) (h : Nat) (s : S) (c : Bool) :
    relaxed p teacher cost known h s c ≤
      complete p teacher cost candidate h s c := by
  induction h generalizing s c with
  | zero => exact Nat.le_refl _
  | succ h ih =>
      simp only [relaxed, complete]
      have step (a : Bool) :
          relaxedChoice known c a (relaxed p teacher cost known h (teacher s a)) ≤
          complete p teacher cost candidate h (teacher s a) (candidate c a) := by
        exact Nat.le_trans (relaxedChoice_le agrees c a _) (ih (teacher s a) (candidate c a))
      have left := Nat.mul_le_mul_left (p s false) (step false)
      have right := Nat.mul_le_mul_left (p s true) (step true)
      exact Nat.add_le_add (Nat.add_le_add_left left _) right

end Kelana.TransitionEnvelope
