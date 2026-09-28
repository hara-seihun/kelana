import Std
import Lean.Elab.Tactic.Omega

namespace Kelana.AlphabetThresholdDecision

/-- Squared distance to an actual decoded rational level. -/
def cost (x level : Rat) : Rat := (x - level) * (x - level)

/-- The first boundary containing the input wins; equality goes to the lower label.
    A zero-step alphabet collapses to label zero before testing boundaries. -/
def select (x l0 l1 l2 l3 : Rat) : Fin 4 :=
  if l0 = l3 then 0
  else if 2*x ≤ l0+l1 then 0
  else if 2*x ≤ l1+l2 then 1
  else if 2*x ≤ l2+l3 then 2
  else 3

def level (l0 l1 l2 l3 : Rat) (j : Fin 4) : Rat :=
  if j = 0 then l0 else if j = 1 then l1 else if j = 2 then l2 else l3

private theorem cost_difference (x a b : Rat) :
    cost x b - cost x a = (b-a)*(a+b-2*x) := by
  unfold cost
  grind +ring

/-- The exact midpoint of decoded levels, rather than an ideal affine midpoint,
    controls the cost comparison. -/
theorem lower_cost_iff (x a b : Rat) (hab : a < b) :
    cost x a ≤ cost x b ↔ 2*x ≤ a+b := by
  have hd := cost_difference x a b
  constructor
  · intro h
    by_cases hb : 2*x ≤ a+b
    · exact hb
    · have hp : a+b-2*x < 0 := by grind
      have hm := Rat.mul_pos (by grind : 0 < b-a) (by grind : 0 < 2*x-a-b)
      grind +ring
  · intro h
    have hp : 0 ≤ a+b-2*x := by grind
    have hm := Rat.mul_nonneg (by grind : 0 ≤ b-a) hp
    grind

theorem upper_cost_strict_iff (x a b : Rat) (hab : a < b) :
    cost x b < cost x a ↔ a+b < 2*x := by
  have hd := cost_difference x a b
  constructor
  · intro h
    by_cases hb : a+b < 2*x
    · exact hb
    · have hp : 0 ≤ a+b-2*x := by grind
      have hm := Rat.mul_nonneg (by grind : 0 ≤ b-a) hp
      grind
  · intro h
    have hp : a+b-2*x < 0 := by grind
    have hm := Rat.mul_pos (by grind : 0 < b-a) (by grind : 0 < 2*x-a-b)
    grind +ring

/-- The selected index minimizes every actual squared distance, and every
    smaller index has strictly greater cost. This is precisely the least-index
    tie rule, including both equality boundaries. -/
theorem select_least_minimizer (x l0 l1 l2 l3 : Rat)
    (h01 : l0 < l1) (h12 : l1 < l2) (h23 : l2 < l3) :
    ∀ j : Fin 4,
      cost x (level l0 l1 l2 l3 (select x l0 l1 l2 l3)) ≤
        cost x (level l0 l1 l2 l3 j) ∧
      (j.val < (select x l0 l1 l2 l3).val →
        cost x (level l0 l1 l2 l3 (select x l0 l1 l2 l3)) <
          cost x (level l0 l1 l2 l3 j)) := by
  have h02 : l0 < l2 := by grind
  have h03 : l0 < l3 := by grind
  have h13 : l1 < l3 := by grind
  have h03ne : l0 ≠ l3 := by grind
  intro j
  have hj : j = 0 ∨ j = 1 ∨ j = 2 ∨ j = 3 := by
    have := j.isLt
    omega
  rcases hj with rfl | rfl | rfl | rfl
  all_goals
    by_cases h0 : 2*x ≤ l0+l1
    · have p01 : cost x l0 ≤ cost x l1 := (lower_cost_iff x l0 l1 h01).2 h0
      have p02 : cost x l0 ≤ cost x l2 :=
        (lower_cost_iff x l0 l2 h02).2 (by grind)
      have p03 : cost x l0 ≤ cost x l3 :=
        (lower_cost_iff x l0 l3 h03).2 (by grind)
      simp [select, level, h03ne, h0] <;> grind
    · have p10 : cost x l1 < cost x l0 :=
        (upper_cost_strict_iff x l0 l1 h01).2 (by grind)
      by_cases h1 : 2*x ≤ l1+l2
      · have p12 : cost x l1 ≤ cost x l2 :=
          (lower_cost_iff x l1 l2 h12).2 h1
        have p13 : cost x l1 ≤ cost x l3 :=
          (lower_cost_iff x l1 l3 h13).2 (by grind)
        simp [select, level, h03ne, h0, h1] <;> grind
      · have p20 : cost x l2 < cost x l0 :=
          (upper_cost_strict_iff x l0 l2 h02).2 (by grind)
        have p21 : cost x l2 < cost x l1 :=
          (upper_cost_strict_iff x l1 l2 h12).2 (by grind)
        by_cases h2 : 2*x ≤ l2+l3
        · have p23 : cost x l2 ≤ cost x l3 :=
            (lower_cost_iff x l2 l3 h23).2 h2
          simp [select, level, h03ne, h0, h1, h2] <;> grind
        · have p30 : cost x l3 < cost x l0 :=
            (upper_cost_strict_iff x l0 l3 h03).2 (by grind)
          have p31 : cost x l3 < cost x l1 :=
            (upper_cost_strict_iff x l1 l3 h13).2 (by grind)
          have p32 : cost x l3 < cost x l2 :=
            (upper_cost_strict_iff x l2 l3 h23).2 (by grind)
          simp [select, level, h03ne, h0, h1, h2] <;> grind

/-- With zero source step all four decoded levels coincide; least label wins. -/
theorem zero_step (x base : Rat) :
    select x base (base+0) (base+2*0) (base+3*0) = 0 ∧
    (∀ j : Fin 4, level base (base+0) (base+2*0) (base+3*0) j = base ∧
      cost x (level base (base+0) (base+2*0) (base+3*0) j) = cost x base) := by
  have h1 : base + (0:Rat) = base := by grind
  simp [select, level, h1]

end Kelana.AlphabetThresholdDecision
