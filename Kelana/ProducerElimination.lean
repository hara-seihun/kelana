import Std

/-!
# Exact elimination of closed objective factors

A factor records one scalar absolute-value term in a robust objective. Its
`radius` may already include the global loss price. The factor list may contain
repeated factors, so the results apply to lists as well as finite sets.

A stage may close a factor only when every legal future action contributes zero
to it. The closed absolute-value charge can then move into `paid`. Two prefixes
with the same live sums and the same legal continuations differ only in this
resulting paid cost.
-/

namespace Kelana.ProducerElimination

structure Model (Factor Action : Type) where
  factors : List Factor
  closed : Factor → Bool
  radius : Factor → Nat
  contribution : Action → Factor → Int
  actionCost : Action → Nat

structure Prefix (Factor : Type) where
  paid : Nat
  sum : Factor → Int

variable {Factor Action : Type}

def contributionSum (m : Model Factor Action) : List Action → Factor → Int
  | [], _ => 0
  | action :: actions, factor =>
      m.contribution action factor + contributionSum m actions factor

def futureCost (m : Model Factor Action) : List Action → Nat
  | [] => 0
  | action :: actions => m.actionCost action + futureCost m actions

def penalty (m : Model Factor Action) (factor : Factor) (value : Int) : Nat :=
  m.radius factor * value.natAbs

def penalties (m : Model Factor Action) : List Factor → (Factor → Int) → Nat
  | [], _ => 0
  | factor :: factors, values =>
      penalty m factor (values factor) + penalties m factors values

def closedFactors (m : Model Factor Action) : List Factor :=
  m.factors.filter fun factor => m.closed factor

def liveFactors (m : Model Factor Action) : List Factor :=
  m.factors.filter fun factor => Bool.not (m.closed factor)

def closedPenalty (m : Model Factor Action) (p : Prefix Factor) : Nat :=
  penalties m (closedFactors m) p.sum

def closePaid (m : Model Factor Action) (p : Prefix Factor) : Nat :=
  p.paid + closedPenalty m p

def objective (m : Model Factor Action) (p : Prefix Factor)
    (actions : List Action) : Nat :=
  p.paid + futureCost m actions +
    penalties m m.factors fun factor =>
      p.sum factor + contributionSum m actions factor

def reducedObjective (m : Model Factor Action) (p : Prefix Factor)
    (actions : List Action) : Nat :=
  closePaid m p + futureCost m actions +
    penalties m (liveFactors m) fun factor =>
      p.sum factor + contributionSum m actions factor

/-- The exact stage condition for closing factors. It talks about the actual
future action list, so a caller may derive it from a stronger stage invariant. -/
def ClosedFactorsStable (m : Model Factor Action) (actions : List Action) : Prop :=
  ∀ action ∈ actions, ∀ factor, m.closed factor = true →
    m.contribution action factor = 0

/-- The DP key after closure consists of the live sums. The paid comparison is
made after all newly closed charges have been added. -/
def ReducedDominates (m : Model Factor Action)
    (a b : Prefix Factor) : Prop :=
  closePaid m a ≤ closePaid m b ∧
    ∀ factor, m.closed factor = false → a.sum factor = b.sum factor

/-- Equality version of the reduced-state key. -/
def ReducedEquivalent (m : Model Factor Action)
    (a b : Prefix Factor) : Prop :=
  closePaid m a = closePaid m b ∧
    ∀ factor, m.closed factor = false → a.sum factor = b.sum factor

/-- Two prefixes have the same legal future actions. This is separate from
numeric state equivalence because legality may depend on other search state. -/
def SameLegalFutures (legal : Prefix Factor → List Action → Prop)
    (a b : Prefix Factor) : Prop :=
  ∀ actions, legal a actions ↔ legal b actions

theorem contributionSum_closed (m : Model Factor Action) (actions : List Action)
    (stable : ClosedFactorsStable m actions) (factor : Factor)
    (closed : m.closed factor = true) :
    contributionSum m actions factor = 0 := by
  induction actions with
  | nil => rfl
  | cons action actions ih =>
      simp only [contributionSum]
      have head : m.contribution action factor = 0 :=
        stable action (by simp) factor closed
      have tailStable : ClosedFactorsStable m actions := by
        intro next hnext
        exact stable next (by simp [hnext])
      rw [head, ih tailStable]
      rfl

theorem penalties_congr (m : Model Factor Action) (factors : List Factor)
    (a b : Factor → Int)
    (equal : ∀ factor ∈ factors, a factor = b factor) :
    penalties m factors a = penalties m factors b := by
  induction factors with
  | nil => rfl
  | cons factor factors ih =>
      simp only [penalties]
      rw [equal factor (by simp)]
      rw [ih (fun next hnext => equal next (by simp [hnext]))]

theorem penalties_partition (m : Model Factor Action) (values : Factor → Int) :
    penalties m m.factors values =
      penalties m (closedFactors m) values + penalties m (liveFactors m) values := by
  unfold closedFactors liveFactors
  induction m.factors with
  | nil => rfl
  | cons factor factors ih =>
      cases h : m.closed factor <;>
        simp [penalties, h, ih, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]

theorem closedPenalty_after_future (m : Model Factor Action)
    (p : Prefix Factor) (actions : List Action)
    (stable : ClosedFactorsStable m actions) :
    penalties m (closedFactors m) (fun factor =>
      p.sum factor + contributionSum m actions factor) = closedPenalty m p := by
  unfold closedPenalty closedFactors
  apply penalties_congr
  intro factor member
  have closed : m.closed factor = true := by
    exact (List.mem_filter.mp member).2
  rw [contributionSum_closed m actions stable factor closed]
  omega

/-- Closure identity. Every closed term is independent of the legal future, so
it can be charged now and removed from the remaining objective. -/
theorem closure_identity (m : Model Factor Action) (p : Prefix Factor)
    (actions : List Action) (stable : ClosedFactorsStable m actions) :
    objective m p actions = reducedObjective m p actions := by
  unfold objective reducedObjective closePaid
  rw [penalties_partition]
  rw [closedPenalty_after_future m p actions stable]
  omega

theorem livePenalty_eq (m : Model Factor Action) (a b : Prefix Factor)
    (actions : List Action)
    (liveEqual : ∀ factor, m.closed factor = false →
      a.sum factor = b.sum factor) :
    penalties m (liveFactors m) (fun factor =>
      a.sum factor + contributionSum m actions factor) =
    penalties m (liveFactors m) (fun factor =>
      b.sum factor + contributionSum m actions factor) := by
  apply penalties_congr
  intro factor member
  have live : m.closed factor = false := by
    have notClosed : Bool.not (m.closed factor) = true :=
      (List.mem_filter.mp member).2
    cases h : m.closed factor <;> simp_all
  rw [liveEqual factor live]

/-- Keeping the least resulting paid cost for a live-state key is safe for every
common continuation whose closed-factor contributions are zero. -/
theorem reduced_dominance_preserves_objective (m : Model Factor Action)
    {a b : Prefix Factor} (dominates : ReducedDominates m a b)
    (actions : List Action) (stable : ClosedFactorsStable m actions) :
    objective m a actions ≤ objective m b actions := by
  rw [closure_identity m a actions stable, closure_identity m b actions stable]
  obtain ⟨paid, sums⟩ := dominates
  have live := livePenalty_eq m a b actions sums
  unfold reducedObjective
  rw [live]
  exact Nat.add_le_add_right (Nat.add_le_add_right paid _) _

/-- Dominance may prune a history only when both histories admit the same legal
future actions. The theorem states legality and cost preservation together. -/
theorem reduced_dominance_preserves_legal_futures
    (m : Model Factor Action) (legal : Prefix Factor → List Action → Prop)
    {a b : Prefix Factor} (sameLegal : SameLegalFutures legal a b)
    (dominates : ReducedDominates m a b)
    (stable : ∀ actions, legal a actions → ClosedFactorsStable m actions) :
    ∀ actions,
      (legal a actions ↔ legal b actions) ∧
      (legal a actions → objective m a actions ≤ objective m b actions) := by
  intro actions
  refine ⟨sameLegal actions, ?_⟩
  intro allowed
  exact reduced_dominance_preserves_objective m dominates actions
    (stable actions allowed)

/-- Equal reduced keys preserve the objective exactly on every legal future. -/
theorem reduced_equivalence_preserves_legal_futures
    (m : Model Factor Action) (legal : Prefix Factor → List Action → Prop)
    {a b : Prefix Factor} (sameLegal : SameLegalFutures legal a b)
    (equivalent : ReducedEquivalent m a b)
    (stable : ∀ actions, legal a actions → ClosedFactorsStable m actions) :
    ∀ actions,
      (legal a actions ↔ legal b actions) ∧
      (legal a actions → objective m a actions = objective m b actions) := by
  intro actions
  refine ⟨sameLegal actions, ?_⟩
  intro allowed
  apply Nat.le_antisymm
  · exact reduced_dominance_preserves_objective m
      ⟨Nat.le_of_eq equivalent.1, equivalent.2⟩ actions (stable actions allowed)
  · have reverseStable : ClosedFactorsStable m actions := stable actions allowed
    exact reduced_dominance_preserves_objective m
      ⟨Nat.le_of_eq equivalent.1.symm, fun factor live =>
        (equivalent.2 factor live).symm⟩ actions reverseStable

/-- Exact minimum over a finite action menu. Empty menus have no minimum. -/
def finiteMinimum (menu : List Action) (cost : Action → Nat) : Option Nat :=
  (menu.map cost).min?

theorem finiteMinimum_eq_some_iff (menu : List Action) (cost : Action → Nat)
    (best : Nat) :
    finiteMinimum menu cost = some best ↔
      (∃ action, action ∈ menu ∧ cost action = best) ∧
      ∀ action, action ∈ menu → best ≤ cost action := by
  unfold finiteMinimum
  rw [List.min?_eq_some_iff]
  simp only [List.mem_map]
  constructor
  · rintro ⟨⟨action, member, rfl⟩, lower⟩
    refine ⟨⟨action, member, rfl⟩, ?_⟩
    intro next nextMember
    exact lower (cost next) ⟨next, nextMember, rfl⟩
  · rintro ⟨⟨action, member, costEq⟩, lower⟩
    refine ⟨⟨action, member, costEq⟩, ?_⟩
    intro value valueMember
    obtain ⟨next, nextMember, nextEq⟩ := valueMember
    rw [← nextEq]
    exact lower next nextMember

/-- One exact finite-menu Bellman step. The continuation can encode every later
stage; no independence or relaxation assumption is made here. -/
def bellman (menu : List Action) (stageCost : Action → Nat)
    (continuation : Action → Nat) : Option Nat :=
  finiteMinimum menu fun action => stageCost action + continuation action

theorem bellman_eq_some_iff (menu : List Action) (stageCost : Action → Nat)
    (continuation : Action → Nat) (best : Nat) :
    bellman menu stageCost continuation = some best ↔
      (∃ action, action ∈ menu ∧
        stageCost action + continuation action = best) ∧
      ∀ action, action ∈ menu →
        best ≤ stageCost action + continuation action := by
  exact finiteMinimum_eq_some_iff menu
    (fun action => stageCost action + continuation action) best

#print axioms closure_identity
#print axioms reduced_dominance_preserves_legal_futures
#print axioms reduced_equivalence_preserves_legal_futures
#print axioms bellman_eq_some_iff

end Kelana.ProducerElimination
