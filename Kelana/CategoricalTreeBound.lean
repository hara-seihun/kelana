import Std

namespace Kelana.CategoricalTreeBound

/-- Masses add up the vocabulary tree. Potentials will represent log mass ratios
in the analytic application; the telescoping identity needs only field algebra. -/
inductive MassTree where
  | leaf (mass potential : Rat)
  | branch (potential : Rat) (left right : MassTree)

def mass : MassTree → Rat
  | .leaf m _ => m
  | .branch _ l r => mass l + mass r

def potential : MassTree → Rat
  | .leaf _ p => p
  | .branch p _ _ => p

def leafScore : MassTree → Rat
  | .leaf m p => m*p
  | .branch _ l r => leafScore l + leafScore r

def edgeScore : MassTree → Rat
  | .leaf _ _ => 0
  | .branch p l r => edgeScore l + edgeScore r +
      mass l * (potential l - p) + mass r * (potential r - p)

theorem tree_telescope (t : MassTree) :
    edgeScore t = leafScore t - mass t * potential t := by
  induction t with
  | leaf m p => simp [edgeScore, leafScore, mass, potential, Rat.sub_self]
  | branch p l r hl hr =>
      simp only [edgeScore, leafScore, mass, potential, hl, hr,
        Rat.sub_eq_add_neg, Rat.mul_add, Rat.mul_neg, Rat.add_mul]
      grind

/-- Each node may use a different relaxed label assignment. A common candidate
assignment is still bounded below by the sum of the separate node certificates. -/
theorem component_floor {Node Assignment : Type} (nodes : List Node)
    (cost : Node → Assignment → Rat) (lower : Node → Rat)
    (bound : ∀ n a, lower n ≤ cost n a) (a : Assignment) :
    (nodes.map lower).sum ≤ (nodes.map fun n => cost n a).sum := by
  induction nodes with
  | nil => simp
  | cons n ns ih =>
      simp only [List.map_cons, List.sum_cons]
      exact Rat.le_trans (Rat.add_le_add_right.mpr (bound n a))
        (Rat.add_le_add_left.mpr ih)

/-- Merging two node groups cannot weaken the bound when the merged minimum
is attained at a common assignment. -/
theorem merge_strengthens {Assignment : Type} (f g : Assignment → Rat)
    (lf lg merged : Rat) (hf : ∀ a, lf ≤ f a) (hg : ∀ a, lg ≤ g a)
    (witness : Assignment) (attained : merged = f witness + g witness) :
    lf + lg ≤ merged := by
  rw [attained]
  exact Rat.le_trans (Rat.add_le_add_right.mpr (hf witness))
    (Rat.add_le_add_left.mpr (hg witness))

/-- Inconsistent independently optimal labels need not realize a shared state. -/
def mismatch (a b : Bool) : Rat := if a == b then 0 else 1

theorem consistency_gap :
    mismatch false false = 0 ∧ mismatch true true = 0 ∧
    ∀ a, mismatch a false + mismatch a true = 1 := by
  constructor
  · rfl
  constructor
  · rfl
  intro a
  cases a <;> decide +kernel

end Kelana.CategoricalTreeBound
