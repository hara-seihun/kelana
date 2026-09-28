import Std

namespace Kelana.Composition

/-- Related states need not contain the same information or have the same shape.
A relation can include range, layout, scale, or reachable-state conditions. -/
def Simulates {A B R S : Type} (before : A → R → Prop) (after : B → S → Prop)
    (spec : A → B) (impl : R → S) : Prop :=
  ∀ a r, before a r → after (spec a) (impl r)

theorem compose {A B C R S T : Type}
    {ra : A → R → Prop} {rb : B → S → Prop} {rc : C → T → Prop}
    {f : A → B} {g : B → C} {h : R → S} {k : S → T}
    (hf : Simulates ra rb f h) (hg : Simulates rb rc g k) :
    Simulates ra rc (g ∘ f) (k ∘ h) := by
  intro a r har
  exact hg (f a) (h r) (hf a r har)

/-- Only the endpoints are observed. Internal state representations may differ. -/
theorem observed_equal {A B R S O : Type}
    {ra : A → R → Prop} {rb : B → S → Prop}
    {f : A → B} {h : R → S} {encode : A → R}
    {observe : B → O} {finish : S → O}
    (start : ∀ a, ra a (encode a)) (body : Simulates ra rb f h)
    (last : ∀ b s, rb b s → finish s = observe b) :
    ∀ a, finish (h (encode a)) = observe (f a) := by
  intro a
  exact last _ _ (body a (encode a) (start a))

def execute {A : Type} : List (A → A) → A → A
  | [], a => a
  | f :: fs, a => execute fs (f a)

/-- A whole chain remains in one representation. No inverse codec appears
between its stages. The relation includes every invariant needed for validity. -/
theorem chain {A R : Type} (rel : A → R → Prop)
    (steps : List ((A → A) × (R → R)))
    (valid : ∀ step ∈ steps, Simulates rel rel step.1 step.2) :
    Simulates rel rel (execute (steps.map Prod.fst)) (execute (steps.map Prod.snd)) := by
  induction steps with
  | nil => intro a r har; exact har
  | cons step rest ih =>
    have first := valid step (by simp)
    have tail : ∀ s ∈ rest, Simulates rel rel s.1 s.2 := by
      intro s hs; exact valid s (by simp [hs])
    intro a r har
    exact ih tail (step.1 a) (step.2 r) (first a r har)

/-- Equality of the remaining observation, not equality of intermediate values. -/
def SameFuture {A O : Type} (observe : A → O) (a b : A) : Prop := observe a = observe b

def FactorsThrough {A R O : Type} (observe : A → O) (encode : A → R) : Prop :=
  ∃ finish : R → O, ∀ a, finish (encode a) = observe a

/-- The representation type contains only reachable encodings. Without that
surjectivity condition, the same statement can be made on the encoder's image.
Existence says nothing about the computational cost of the resulting function. -/
theorem factors_iff {A R O : Type} (observe : A → O) (encode : A → R)
    (onto : ∀ r, ∃ a, encode a = r) :
    FactorsThrough observe encode ↔
      ∀ a b, encode a = encode b → SameFuture observe a b := by
  constructor
  · rintro ⟨finish, correct⟩ a b he
    unfold SameFuture
    rw [← correct a, ← correct b, he]
  · intro respects
    classical
    let representative : R → A := fun r => Classical.choose (onto r)
    have rep_ok : ∀ r, encode (representative r) = r := fun r => Classical.choose_spec (onto r)
    refine ⟨fun r => observe (representative r), ?_⟩
    intro a
    exact respects (representative (encode a)) a (rep_ok (encode a))

/-- A reduced representation supports an operation precisely when that operation
respects its fibres. This is a semantic existence criterion, not a cheap lowering. -/
theorem operation_descends_iff {A R : Type} (encode : A → R) (f : A → A)
    (onto : ∀ r, ∃ a, encode a = r) :
    (∃ h : R → R, ∀ a, h (encode a) = encode (f a)) ↔
      ∀ a b, encode a = encode b → encode (f a) = encode (f b) :=
  factors_iff (encode ∘ f) encode onto

/-- Future equivalence pulls back through a stage, with no requirement that the
stage itself preserve a previously chosen equivalence. -/
theorem pullback {A B O : Type} (f : A → B) (observe : B → O) (a b : A) :
    SameFuture observe (f a) (f b) ↔ SameFuture (observe ∘ f) a b := Iff.rfl

/-- An early floor-to-half loses information that a later doubling can expose. -/
theorem early_rounding_does_not_descend :
    ¬ ∃ h : Nat → Nat, ∀ x, h (x / 2) = (2 * x) / 2 := by
  rintro ⟨h, correct⟩
  have h0 := correct 0
  have h1 := correct 1
  simp at h0 h1
  omega

/-- Restrict proofs to producer-reachable states when proving a whole composition.
A stronger theorem on all intermediate values is unnecessary. -/
theorem reachable_rewrite {X A O : Type} (producer : X → A) (f g : A → O)
    (h : ∀ a, (∃ x, producer x = a) → f a = g a) :
    ∀ x, f (producer x) = g (producer x) := by
  intro x
  exact h (producer x) ⟨x, rfl⟩

/-- The first stage (x,y) ↦ (x,2y) cannot operate on the sum-only representation.
The second stage (x,y) ↦ (2x,y) restores closure of the whole two-stage map.
Requiring an implementation after every source operation would miss this. -/
theorem compound_closure_without_stage_closure :
    (¬ ∃ h : Int → Int, ∀ x y, h (x+y) = x+2*y) ∧
    (∀ x y : Int, 2*x+2*y = 2*(x+y)) := by
  constructor
  · rintro ⟨h, hh⟩
    have a := hh 1 0
    have b := hh 0 1
    simp at a b
    omega
  · intro x y
    omega

/-- Approximate closeness is not an equivalence relation and must not be fed
into exact equality saturation as though it were one. -/
def Within (budget a b : Int) : Prop := -budget ≤ a-b ∧ a-b ≤ budget

theorem approximation_budgets_compose {e f a b c : Int}
    (hab : Within e a b) (hbc : Within f b c) : Within (e+f) a c := by
  unfold Within at *
  omega

theorem tolerance_is_not_transitive :
    Within 1 0 1 ∧ Within 1 1 2 ∧ ¬ Within 1 0 2 := by
  unfold Within
  decide

#print axioms compound_closure_without_stage_closure
#print axioms chain
#print axioms factors_iff
#print axioms operation_descends_iff
#print axioms observed_equal
end Kelana.Composition
