import Std

namespace Kelana.CompositionCost

/-- One choice per stage: false is ordinary, true is packed. Both endpoints
are ordinary. At most the first seven stages admit the packed representation. -/
abbrev Plan := List Bool

def packedCount : Plan → Nat
  | [] => 0
  | b :: bs => (if b then 1 else 0) + packedCount bs

def switches (current : Bool) : Plan → Nat
  | [] => if current then 1 else 0
  | b :: bs => (if current = b then 0 else 1) + switches b bs

def Allowed : Nat → Plan → Prop
  | _, [] => True
  | 0, b :: bs => b = false ∧ Allowed 0 bs
  | n+1, _ :: bs => Allowed n bs

/-- The synthetic instruction grammar: ordinary stage 2, packed stage 1,
representation boundary 3. No hardware cycle calibration is claimed. -/
def cost (plan : Plan) : Int :=
  2 * (plan.length : Int) - packedCount plan + 3 * switches false plan

theorem count_le_length (plan : Plan) : packedCount plan ≤ plan.length := by
  induction plan with
  | nil => simp [packedCount]
  | cons b bs ih => cases b <;> simp [packedCount] <;> omega

theorem allowed_count {fuel : Nat} {plan : Plan} (h : Allowed fuel plan) :
    packedCount plan ≤ fuel := by
  induction plan generalizing fuel with
  | nil => simp [packedCount]
  | cons b bs ih =>
    cases fuel with
    | zero =>
      have hb := h.1
      have ht := ih h.2
      subst b
      simp [packedCount]
      omega
    | succ fuel =>
      have ht := ih h
      cases b <;> simp [packedCount] <;> omega

theorem exit_required (plan : Plan) : ∀ current,
    (if current then 1 else 0) ≤ switches current plan := by
  induction plan with
  | nil => intro current; exact Nat.le_refl _
  | cons b bs ih =>
    intro current
    have ht := ih b
    cases current <;> cases b <;> simp_all [switches]

theorem packed_requires_two_boundaries (plan : Plan) (hp : 0 < packedCount plan) :
    2 ≤ switches false plan := by
  induction plan with
  | nil => simp [packedCount] at hp
  | cons b bs ih =>
    cases b with
    | false =>
      simp only [packedCount, Bool.false_eq_true, reduceIte, Nat.zero_add] at hp
      simpa [switches] using ih hp
    | true =>
      have ht := exit_required bs true
      simp [switches] at *
      omega

theorem all_plans_lower_bound (plan : Plan) (h : Allowed 7 plan) :
    2 * (plan.length : Int) - 1 ≤ cost plan := by
  have hc := allowed_count h
  by_cases hp : packedCount plan = 0
  · unfold cost; omega
  · have hb := packed_requires_two_boundaries plan (by omega)
    unfold cost
    omega

theorem short_plans_lower_bound (plan : Plan) (hn : plan.length ≤ 6) :
    2 * (plan.length : Int) ≤ cost plan := by
  have hc := count_le_length plan
  by_cases hp : packedCount plan = 0
  · unfold cost; omega
  · have hb := packed_requires_two_boundaries plan (by omega)
    unfold cost
    omega

theorem false_count (n : Nat) : packedCount (List.replicate n false) = 0 := by
  induction n with
  | zero => rfl
  | succ n ih => simp [List.replicate_succ, packedCount, ih]

theorem false_switches (n : Nat) (current : Bool) :
    switches current (List.replicate n false) = if current then 1 else 0 := by
  induction n generalizing current with
  | zero => rfl
  | succ n ih => cases current <;> simp [List.replicate_succ, switches, ih]

theorem false_allowed (n fuel : Nat) : Allowed fuel (List.replicate n false) := by
  induction n generalizing fuel with
  | zero => trivial
  | succ n ih =>
    cases fuel <;> simp [List.replicate_succ, Allowed, ih]

def best (n : Nat) : Plan :=
  if n ≤ 6 then List.replicate n false
  else List.replicate 7 true ++ List.replicate (n-7) false

theorem prefix_seven (rest : Nat) :
    let p := List.replicate 7 true ++ List.replicate rest false
    Allowed 7 p ∧ packedCount p = 7 ∧ switches false p = 2 := by
  simp [List.replicate_succ, Allowed, packedCount, switches,
    false_allowed, false_count, false_switches]

theorem best_shape (n : Nat) :
    (best n).length = n ∧ Allowed 7 (best n) ∧
    cost (best n) = if n ≤ 6 then 2*(n : Int) else 2*(n : Int)-1 := by
  unfold best
  split <;> rename_i hn
  · simp [cost, false_allowed, false_count, false_switches]
  · have hs :
        Allowed 7 (List.replicate 7 true ++ List.replicate (n-7) false) ∧
        packedCount (List.replicate 7 true ++ List.replicate (n-7) false) = 7 ∧
        switches false (List.replicate 7 true ++ List.replicate (n-7) false) = 2 :=
      prefix_seven (n-7)
    have hl : (List.replicate 7 true ++ List.replicate (n-7) false).length = n := by
      simp
      omega
    constructor
    · exact hl
    constructor
    · exact hs.1
    · unfold cost
      rw [hl, hs.2.1, hs.2.2]
      omega

theorem best_is_optimal (n : Nat) (plan : Plan)
    (hlen : plan.length = n) (h : Allowed 7 plan) : cost (best n) ≤ cost plan := by
  have hb := (best_shape n).2.2
  rw [hb]
  split <;> rename_i hn
  · have hl := short_plans_lower_bound plan (by omega)
    simpa [hlen] using hl
  · have hl := all_plans_lower_bound plan h
    simpa [hlen] using hl

#print axioms best_is_optimal
end Kelana.CompositionCost
