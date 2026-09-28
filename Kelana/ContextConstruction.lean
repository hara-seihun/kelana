import Std

namespace Kelana.ContextConstruction

/-- Count a canonical list of identities; repeating an identity in `assets`
would count it twice, so callers use one occurrence per physical asset. -/
def charge {I : Type} (assets : List I) (weight : I → Nat)
    (paid : I → Bool) : Nat :=
  (assets.map fun i => if paid i then weight i else 0).sum

def extra {I : Type} (assets : List I) (weight : I → Nat)
    (paid used : I → Bool) : Nat :=
  (assets.map fun i => if used i && !paid i then weight i else 0).sum

/-- Union charging is a current total plus only the not-yet-paid uses. -/
theorem charge_union {I : Type} (assets : List I) (weight : I → Nat)
    (paid used : I → Bool) :
    charge assets weight (fun i => paid i || used i) =
      charge assets weight paid + extra assets weight paid used := by
  induction assets with
  | nil => rfl
  | cons i rest ih =>
    simp only [charge, extra, List.map_cons, List.sum_cons] at ih ⊢
    have point : (if paid i || used i then weight i else 0) =
        (if paid i then weight i else 0) +
        (if used i && !paid i then weight i else 0) := by
      cases (paid i) <;> cases (used i) <;> simp
    rw [point, ih]
    omega

/-- A prefix need not remember paid identities outside the *future-use
incidence*: same base bytes and same payment status on every possibly used
identity imply identical static cost for every legal suffix. -/
theorem future_incidence_sufficient {I : Type} (assets : List I)
    (weight : I → Nat) (future paidA paidB used : I → Bool)
    (base : charge assets weight paidA = charge assets weight paidB)
    (profile : ∀ i, future i = true → paidA i = paidB i)
    (restricted : ∀ i, used i = true → future i = true) :
    charge assets weight (fun i => paidA i || used i) =
      charge assets weight (fun i => paidB i || used i) := by
  rw [charge_union, charge_union, base]
  congr 1
  unfold extra
  congr 1
  apply List.map_congr_left
  intro i hi
  by_cases hu : used i = true
  · have h := profile i (restricted i hu)
    simp [hu, h]
  · cases hused : used i <;> simp_all

/-- A stage-indexed deterministic program grammar. The state `S` may be the
full reachable numeric map across all producer inputs. -/
structure Machine (S A R : Type) where
  legal : Nat → S → A → Prop
  step : Nat → S → A → S
  output : S → R
  used : Nat → S → A → Nat
  online : Nat → S → A → Nat

/-- The two charges here are *incremental*; a full static identity-set charge
can be put in `used` after conditioning on the prefix's paid-incidence profile. -/
inductive Run {S A R : Type} (m : Machine S A R) :
    Nat → S → List A → R → Nat → Nat → Prop where
  | done (s : S) : Run m 0 s [] (m.output s) 0 0
  | more {h : Nat} {s : S} {a : A} {tail : List A}
      {r : R} {bytes work : Nat} (hl : m.legal (h+1) s a)
      (ht : Run m h (m.step (h+1) s a) tail r bytes work) :
      Run m (h+1) s (a::tail) r
        (m.used (h+1) s a + bytes) (m.online (h+1) s a + work)

/-- Exact one-step dynamic-programming recurrence on complete suffix traces.
Union the outcomes from all legal first actions, adding that action's charges;
Pareto-pruning only outcomes with the *same* terminal response is safe. -/
theorem run_step_iff {S A R : Type} (m : Machine S A R)
    {h : Nat} {s : S} {a : A} {tail : List A} {r : R}
    {bytes work : Nat} :
    Run m (h+1) s (a::tail) r bytes work ↔
      ∃ b w, m.legal (h+1) s a ∧
        Run m h (m.step (h+1) s a) tail r b w ∧
        bytes = m.used (h+1) s a + b ∧
        work = m.online (h+1) s a + w := by
  constructor
  · intro hr
    cases hr with
    | more hl ht => exact ⟨_, _, hl, ht, rfl, rfl⟩
  · rintro ⟨b, w, hl, ht, hb, hw⟩
    subst bytes
    subst work
    exact Run.more hl ht

/-- Sufficient local separator contract: legality, transition, and both
resource increments factor through a stage-specific abstract state. -/
structure Separator {S A R K : Type} (m : Machine S A R)
    (alpha : Nat → S → K) where
  terminal : ∀ s t, alpha 0 s = alpha 0 t → m.output s = m.output t
  legal : ∀ h s t a, alpha (h+1) s = alpha (h+1) t →
    (m.legal (h+1) s a ↔ m.legal (h+1) t a)
  next : ∀ h s t a, alpha (h+1) s = alpha (h+1) t →
    alpha h (m.step (h+1) s a) = alpha h (m.step (h+1) t a)
  used : ∀ h s t a, alpha (h+1) s = alpha (h+1) t →
    m.used (h+1) s a = m.used (h+1) t a
  online : ∀ h s t a, alpha (h+1) s = alpha (h+1) t →
    m.online (h+1) s a = m.online (h+1) t a

/-- A bisimilar separator carries every complete continuation with the same
word, response, bytes, and work. In particular, its residual-program
simulation does not enumerate suffix words. -/
theorem replay_on_separator {S A R K : Type} (m : Machine S A R)
    (alpha : Nat → S → K) (sep : Separator m alpha)
    {h : Nat} {s t : S} {word : List A} {r : R} {bytes work : Nat}
    (equiv : alpha h s = alpha h t)
    (run : Run m h s word r bytes work) :
    Run m h t word r bytes work := by
  induction run generalizing t with
  | done s =>
    have ho := sep.terminal s t equiv
    simpa [ho] using (Run.done (m := m) t)
  | @more h s a tail r bytes work hl ht ih =>
    have hl' := (sep.legal h s t a equiv).mp hl
    have hn := sep.next h s t a equiv
    have hu := sep.used h s t a equiv
    have hw := sep.online h s t a equiv
    simpa [hu, hw] using (Run.more hl' (ih hn))

end Kelana.ContextConstruction
