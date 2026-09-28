import Kelana.CollisionPacking

namespace Kelana.ContextConfusability

/-! Producer-dependent live contexts: a reader knows the context t, but its
upstream label g(s) is chosen before t. These results formalize the exact
zero-fit relation and a three-context weighted collision obstruction. KL and
real logarithms enter only when a concrete pair floor is supplied. -/

variable {Source Context Label Law : Type}

/-- Two sources conflict exactly when some live context sees both and asks for
different categorical laws. Context distributions themselves need not agree. -/
def conflicts (active : Source → Context → Prop) (p : Source → Context → Law)
    (s r : Source) : Prop :=
  ∃ t, active s t ∧ active r t ∧ p s t ≠ p r t

/-- A fixed upstream labeling has an exact, context-dependent decoder iff it
properly colors the co-visibility conflict graph. An inactive source/context
cell imposes no decoder requirement. This is the algebraic zero-KL condition. -/
theorem exact_decoder_iff_coloring [Inhabited Law]
    (active : Source → Context → Prop) (p : Source → Context → Law)
    (g : Source → Label) :
    (∃ q : Label → Context → Law,
      ∀ s t, active s t → q (g s) t = p s t) ↔
    (∀ s r, conflicts active p s r → g s ≠ g r) := by
  classical
  constructor
  · rintro ⟨q, hq⟩ s r ⟨t, hs, hr, different⟩ same
    apply different
    calc
      p s t = q (g s) t := (hq s t hs).symm
      _ = q (g r) t := by rw [same]
      _ = p r t := hq r t hr
  · intro coloring
    have consistent : ∀ s r t, active s t → active r t →
        g s = g r → p s t = p r t := by
      intro s r t hs hr same
      apply Classical.byContradiction
      intro different
      exact coloring s r ⟨t,hs,hr,different⟩ same
    let q : Label → Context → Law := fun c t =>
      if h : ∃ s, active s t ∧ g s = c then
        p (Classical.choose h) t else default
    refine ⟨q, ?_⟩
    intro s t hs
    have h : ∃ r, active r t ∧ g r = g s := ⟨s,hs,rfl⟩
    change (if h' : ∃ r, active r t ∧ g r = g s then
      p (Classical.choose h') t else default) = p s t
    rw [dif_pos h]
    exact consistent (Classical.choose h) s t
      (Classical.choose_spec h).1 hs (Classical.choose_spec h).2

structure LiveEdge (Source Context : Type) where
  left : Source
  right : Source
  context : Context

/-- Pack arbitrary graph-coloring obstructions, charging each source-context
cell at most once across witnesses. `forced` is a graph theorem (for example,
an odd cycle under two colors); `edgePaid` is the conditional pair-divergence
lemma. Distinct contexts of the same source remain distinct mass cells. -/
theorem packed_graph_obstructions
    [DecidableEq (Source × Context)]
    (cells : List (Source × Context))
    (obstructions : List (List (Source × Context)))
    (graph : List (Source × Context) → List (LiveEdge Source Context))
    (share floor : List (Source × Context) → Rat)
    (edgeFloor : LiveEdge Source Context → Rat)
    (cost : Source × Context → Rat) (g : Source → Label)
    (nonnegative : ∀ cell, 0 ≤ cost cell)
    (loads : ∀ cell ∈ cells, CollisionPacking.load obstructions share cell ≤ 1)
    (shares : ∀ H ∈ obstructions, 0 ≤ share H)
    (forced : ∀ H ∈ obstructions, ∃ e ∈ graph H, g e.left = g e.right)
    (edgePaid : ∀ H ∈ obstructions, ∀ e ∈ graph H,
      g e.left = g e.right →
      edgeFloor e ≤
        (cells.map fun cell => if cell ∈ H then cost cell else 0).sum)
    (least : ∀ H ∈ obstructions, ∀ e ∈ graph H, floor H ≤ edgeFloor e) :
    (obstructions.map fun H => share H * floor H).sum ≤
      (cells.map cost).sum := by
  apply CollisionPacking.packed_collision_floor cells obstructions share floor cost
    nonnegative loads shares
  intro H hH
  rcases forced H hH with ⟨e,he,mono⟩
  exact Rat.le_trans (least H hH e he) (edgePaid H hH e he mono)

/-- Distinct source-context cells have separate occupancy budgets. A triangle
of pair contexts each carries two source-specific charges; with two upstream
labels, some edge is monochromatic. We never add two pair penalties against
the same cell in this certificate. -/
theorem triangle_context_floor (g : Fin 3 → Fin 2)
    (c01a c01b c12a c12b c20a c20b : Rat)
    (d01 d12 d20 floor : Rat)
    (nonnegative : 0 ≤ c01a ∧ 0 ≤ c01b ∧ 0 ≤ c12a ∧
      0 ≤ c12b ∧ 0 ≤ c20a ∧ 0 ≤ c20b)
    (pair01 : g 0 = g 1 → d01 ≤ c01a + c01b)
    (pair12 : g 1 = g 2 → d12 ≤ c12a + c12b)
    (pair20 : g 2 = g 0 → d20 ≤ c20a + c20b)
    (floor01 : floor ≤ d01) (floor12 : floor ≤ d12)
    (floor20 : floor ≤ d20) :
    floor ≤ c01a + c01b + c12a + c12b + c20a + c20b := by
  rcases CollisionPacking.triple_two_labels g with same | same | same
  · have h := Rat.le_trans floor01 (pair01 same)
    grind
  · have h := Rat.le_trans floor20 (pair20 same.symm)
    grind
  · have h := Rat.le_trans floor12 (pair12 same)
    grind

end Kelana.ContextConfusability
