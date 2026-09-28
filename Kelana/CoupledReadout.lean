import Std

namespace Kelana.CoupledReadout

/-- One eliminated variable may interact with the entire retained separator. -/
structure Elimination {Rest Value : Type} (energy : Rest → Value → Int)
    (legal : Rest → Value → Prop) where
  message : Rest → Int
  witness : Rest → Value
  feasible : ∀ r, legal r (witness r)
  realized : ∀ r, message r = energy r (witness r)
  lower : ∀ r v, legal r v → message r ≤ energy r v

theorem eliminated_optimum {Rest Value : Type} {energy : Rest → Value → Int}
    {legal : Rest → Value → Prop} (cert : Elimination energy legal)
    (winner : Rest) (optimal : ∀ r, cert.message winner ≤ cert.message r) :
    ∀ r v, legal r v → energy winner (cert.witness winner) ≤ energy r v := by
  intro r v hv
  rw [← cert.realized]
  exact Int.le_trans (optimal r) (cert.lower r v hv)

/-- Factors outside the eliminated variable's bucket survive unchanged. -/
def withResidual {Rest Value : Type} {energy : Rest → Value → Int}
    {legal : Rest → Value → Prop} (cert : Elimination energy legal)
    (residual : Rest → Int) :
    Elimination (fun r v => energy r v + residual r) legal where
  message := fun r => cert.message r + residual r
  witness := cert.witness
  feasible := cert.feasible
  realized := by intro r; rw [cert.realized]
  lower := by intro r v hv; have h := cert.lower r v hv; omega

/-- Splitting a shared variable between buckets relaxes consistency, hence
summing the separate lower messages is admissible, not generally exact. -/
theorem split_bucket_lower {Value : Type} (f g : Value → Int)
    (lf lg : Int) (hf : ∀ v, lf ≤ f v) (hg : ∀ v, lg ≤ g v) :
    ∀ v, lf + lg ≤ f v + g v := by
  intro v
  have a := hf v
  have b := hg v
  omega

def disagree (a b : Bool) : Int := if a == b then 0 else 1

theorem strict_consistency_gap :
    (∀ a : Bool, 0 ≤ disagree a false) ∧
    (∀ a : Bool, 0 ≤ disagree a true) ∧
    (∀ a : Bool, disagree a false + disagree a true = 1) := by
  constructor
  · intro a; cases a <;> decide
  constructor
  · intro a; cases a <;> decide
  · intro a; cases a <;> decide

def spin : Bool → Int | false => 1 | true => -1

theorem spin_mul_self (a : Bool) : spin a * spin a = 1 := by
  cases a <;> rfl

theorem spin_xor (a b : Bool) : spin (a ^^ b) = spin a * spin b := by
  cases a <;> cases b <;> rfl

theorem gauge_involutive (a gauge : Bool) : (a ^^ gauge) ^^ gauge = a := by
  cases a <;> cases gauge <;> rfl

/-- Product-response squared error is an Ising interaction plus a constant. -/
theorem product_square (a b : Bool) (target : Int) :
    (spin a * spin b - target) * (spin a * spin b - target) =
      1 + target * target - 2 * target * (spin a * spin b) := by
  cases a <;> cases b <;>
    simp only [spin, Int.one_mul, Int.mul_one, Int.neg_mul, Int.mul_neg,
      Int.neg_neg, Int.sub_mul, Int.mul_sub] <;> omega

def interaction (weight : Int) (a b : Bool) : Int := -weight * spin a * spin b

/-- A vertex gauge is a bijective change of the stored sign variables. -/
theorem gauge_edge (weight : Int) (a b ga gb : Bool) :
    interaction weight (a ^^ ga) (b ^^ gb) =
      interaction (weight * spin ga * spin gb) a b := by
  cases a <;> cases b <;> cases ga <;> cases gb <;>
    simp [interaction, spin]

theorem attractive_iff_submodular (weight : Int) :
    interaction weight false false + interaction weight true true ≤
      interaction weight false true + interaction weight true false ↔ 0 ≤ weight := by
  simp only [interaction, spin, Int.mul_one, Int.mul_neg, Int.neg_neg]
  omega

/-- Nonnegative interactions are nonnegative cut capacities plus a constant. -/
theorem cut_representation (weight : Int) (a b : Bool) :
    interaction weight a b = -weight + 2 * weight * disagree a b := by
  cases a <;> cases b <;> simp [interaction, spin, disagree] <;> omega

#print axioms eliminated_optimum
#print axioms split_bucket_lower
#print axioms product_square
#print axioms gauge_edge
#print axioms attractive_iff_submodular
#print axioms cut_representation
end Kelana.CoupledReadout
