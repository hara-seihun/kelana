import Kelana.Composition

namespace Kelana.ObserverAutomata

variable {State Op Output : Type}

def run (step : Op → State → State) : List Op → State → State
  | [], state => state
  | op :: rest, state => run step rest (step op state)

/-- The observation includes only the external result, not the whole state. -/
def FutureEq (step : Op → State → State) (observe : State → Output)
    (a b : State) : Prop :=
  ∀ word, observe (run step word a) = observe (run step word b)

theorem future_refl (step : Op → State → State) (observe : State → Output)
    (a : State) : FutureEq step observe a a := by
  intro word
  rfl

theorem future_symm {step : Op → State → State} {observe : State → Output}
    {a b : State} (h : FutureEq step observe a b) : FutureEq step observe b a := by
  intro word
  exact (h word).symm

theorem future_trans {step : Op → State → State} {observe : State → Output}
    {a b c : State} (hab : FutureEq step observe a b)
    (hbc : FutureEq step observe b c) : FutureEq step observe a c := by
  intro word
  exact (hab word).trans (hbc word)

theorem future_observes {step : Op → State → State} {observe : State → Output}
    {a b : State} (h : FutureEq step observe a b) : observe a = observe b :=
  h []

theorem future_stable {step : Op → State → State} {observe : State → Output}
    {a b : State} (h : FutureEq step observe a b) (op : Op) :
    FutureEq step observe (step op a) (step op b) := by
  intro word
  exact h (op :: word)

/-- Any observation-respecting, transition-stable relation is contained in future
    equivalence. Thus future equivalence is the coarsest reusable quotient. -/
theorem greatest_stable_relation (step : Op → State → State) (observe : State → Output)
    (rel : State → State → Prop)
    (observes : ∀ a b, rel a b → observe a = observe b)
    (stable : ∀ op a b, rel a b → rel (step op a) (step op b)) :
    ∀ a b, rel a b → FutureEq step observe a b := by
  intro a b hab word
  induction word generalizing a b with
  | nil => exact observes a b hab
  | cons op rest ih => exact ih (step op a) (step op b) (stable op a b hab)

/-- Adding possible continuations can only require more distinctions. -/
theorem restrict_operations {OtherOp : Type}
    (step : Op → State → State) (other : OtherOp → State → State)
    (embed : Op → OtherOp) (same : ∀ op state, other (embed op) state = step op state)
    (observe : State → Output) {a b : State}
    (h : FutureEq other observe a b) : FutureEq step observe a b := by
  apply greatest_stable_relation step observe (FutureEq other observe)
  · intro x y hxy
    exact future_observes hxy
  · intro op x y hxy
    have hs := future_stable hxy (embed op)
    simpa only [same] using hs
  · exact h

/-- A fixed remaining region asks for only one word, not a reusable interface. -/
theorem fixed_word_is_weaker {step : Op → State → State} {observe : State → Output}
    {a b : State} (h : FutureEq step observe a b) (word : List Op) :
    observe (run step word a) = observe (run step word b) :=
  h word

/-- Preserving every external observation does not force an arbitrary finer
    encoding to be transition-stable. The chosen carrier may retain gratuitous
    distinctions that the next step cannot reconstruct. -/
theorem future_sufficiency_does_not_imply_carrier_closure :
    (∀ a b : Nat, a / 2 = b / 2 →
      FutureEq (fun (_ : Unit) n => n + 1) (fun _ => (0 : Nat)) a b) ∧
    (¬ ∃ h : Nat → Nat, ∀ n, h (n / 2) = (n + 1) / 2) := by
  constructor
  · intro a b _ word
    rfl
  · rintro ⟨h, correct⟩
    have h0 := correct 0
    have h1 := correct 1
    simp at h0 h1
    omega

end Kelana.ObserverAutomata
