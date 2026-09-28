import Std

/-!
# Gate sign-classes in a paired gate/up network

A SwiGLU hidden unit is `z i = s (g i) * u i` with `s` the gate nonlinearity.  The only
property of SiLU used here is the reflection identity `s t - s (-t) = t`, which holds for
`t ↦ t * sigmoid t` over the reals.  Everything below is the algebra that identity forces,
stated over `Int` so that the ambient commutative ring is part of core Lean; no analytic
fact about `Real.exp` is claimed or needed.

The consequence: inside one gate sign-class (all gate rows equal to a common row up to a
whole-row sign) the class' contribution to any linear consumer is one nonlinear evaluation
against a combined up row, plus one bilinear term.  The nonlinear term disappears exactly
when the combined up row vanishes.
-/

namespace Kelana.GateClass

/-- One hidden unit of a gate sign-class: its consumer coefficient, its up value at the
current input, and whether its gate row is the negated class representative. -/
structure Member where
  c : Int
  u : Int
  flipped : Bool
deriving Repr

/-- What the class contributes to one consumer output, evaluated unit by unit. -/
def out (s : Int → Int) (g : Int) : List Member → Int
  | [] => 0
  | w :: rest => w.c * s (if w.flipped then -g else g) * w.u + out s g rest

/-- Coefficient of the surviving nonlinear evaluation: `Σ c i * u i` over the whole class. -/
def combined : List Member → Int
  | [] => 0
  | w :: rest => w.c * w.u + combined rest

/-- Coefficient of the bilinear correction: `Σ c i * u i` over the negated members. -/
def flippedPart : List Member → Int
  | [] => 0
  | w :: rest => (if w.flipped then w.c * w.u else 0) + flippedPart rest

theorem reflect (s : Int → Int) (hs : ∀ t, s t - s (-t) = t) (g : Int) :
    s (-g) = s g - g := by
  have := hs g
  omega

/-- Class collapse.  Any number of units sharing one gate row up to sign need one
evaluation of `s` and one multiplication by `g`, whatever their up values and consumer
coefficients are. -/
theorem collapse (s : Int → Int) (hs : ∀ t, s t - s (-t) = t) (g : Int) (ws : List Member) :
    out s g ws = s g * combined ws - g * flippedPart ws := by
  induction ws with
  | nil => simp [out, combined, flippedPart]
  | cons w rest ih =>
    obtain ⟨c, u, flip⟩ := w
    have hneg : s (-g) = s g - g := reflect s hs g
    cases flip <;>
      simp only [out, combined, flippedPart, ih, reduceIte, hneg, Bool.false_eq_true] <;>
      simp only [Int.mul_add, Int.mul_sub, Int.sub_mul] <;>
      simp only [Int.mul_comm, Int.mul_left_comm] <;>
      omega

/-- The class is nonlinearity-free exactly when its combined up coefficient vanishes: the
contribution is then a product of two linear forms of the input. -/
theorem bilinear_of_combined_zero (s : Int → Int) (hs : ∀ t, s t - s (-t) = t)
    (g : Int) (ws : List Member) (h : combined ws = 0) :
    out s g ws = -(g * flippedPart ws) := by
  rw [collapse s hs g ws, h]
  omega

/-- An opposing pair with opposite consumer coefficients and equal up values is exactly
bilinear: the two SiLU evaluations and one of the two up rows are removable. -/
theorem pair_bilinear (s : Int → Int) (hs : ∀ t, s t - s (-t) = t) (g c u : Int) :
    out s g [⟨c, u, false⟩, ⟨-c, u, true⟩] = g * (c * u) := by
  have h : combined [(⟨c, u, false⟩ : Member), ⟨-c, u, true⟩] = 0 := by
    simp [combined, Int.neg_mul]
    omega
  rw [bilinear_of_combined_zero s hs g _ h]
  simp [flippedPart, Int.neg_mul, Int.mul_neg]

/-- Duplicate gate rows with proportional consumer columns merge into one unit. -/
theorem duplicate_merge (s : Int → Int) (g c u v lam : Int) :
    out s g [⟨c, u, false⟩, ⟨lam * c, v, false⟩] = out s g [⟨c, u + lam * v, false⟩] := by
  simp only [out, Int.mul_add]
  simp only [Int.mul_comm, Int.mul_left_comm, Int.mul_assoc]
  omega

end Kelana.GateClass
