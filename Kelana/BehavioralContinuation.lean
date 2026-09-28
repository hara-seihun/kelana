import Init

namespace Kelana.BehavioralContinuation

-- Reachability follows one common token history, but each machine updates its own state.
inductive PairReach {S C A : Type} (teacher : S → A → S) (candidate : C → A → C)
    (initialTeacher : S) (initialCandidate : C) : S → C → Prop where
  | initial : PairReach teacher candidate initialTeacher initialCandidate initialTeacher initialCandidate
  | next {s : S} {c : C} (h : PairReach teacher candidate initialTeacher initialCandidate s c)
      (a : A) : PairReach teacher candidate initialTeacher initialCandidate
        (teacher s a) (candidate c a)

def AgreeOnReach {S C A : Type} (teacher : S → A → S) (candidate : C → A → C)
    (initialTeacher : S) (initialCandidate : C)
    (p : S → A → Int) (q : C → A → Int) : Prop :=
  ∀ s c, PairReach teacher candidate initialTeacher initialCandidate s c →
    ∀ a, p s a = q c a

def pathMass {S A : Type} (transition : S → A → S) (emission : S → A → Int)
    (state : S) : List A → Int
  | [] => 1
  | a :: rest => emission state a * pathMass transition emission (transition state a) rest

theorem pathMass_eq_of_agree {S C A : Type}
    (teacher : S → A → S) (candidate : C → A → C)
    (s₀ : S) (c₀ : C) (p : S → A → Int) (q : C → A → Int)
    (agree : AgreeOnReach teacher candidate s₀ c₀ p q) (word : List A) :
    pathMass teacher p s₀ word = pathMass candidate q c₀ word := by
  have more : ∀ (word : List A) (s : S) (c : C),
      PairReach teacher candidate s₀ c₀ s c →
      pathMass teacher p s word = pathMass candidate q c word := by
    intro word
    induction word with
    | nil => intro s c _; rfl
    | cons a rest ih =>
      intro s c h
      simp only [pathMass, agree s c h a,
        ih (teacher s a) (candidate c a) (PairReach.next h a)]
  exact more word s₀ c₀ PairReach.initial

theorem collision_forbids_agreement {S C A : Type}
    (teacher : S → A → S) (candidate : C → A → C)
    (s₀ : S) (c₀ : C) (p : S → A → Int) (q : C → A → Int)
    (s t : S) (c : C) (a : A)
    (hs : PairReach teacher candidate s₀ c₀ s c)
    (ht : PairReach teacher candidate s₀ c₀ t c)
    (different : p s a ≠ p t a) :
    ¬ AgreeOnReach teacher candidate s₀ c₀ p q := by
  intro agree
  exact different ((agree s c hs a).trans (agree t c ht a).symm)

end Kelana.BehavioralContinuation
