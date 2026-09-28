import Std

namespace Kelana.ContractedFFN
open Lean.Grind

variable {R : Type} [CommRing R]

structure Unit (R : Type) where
  gate0 : R
  gate1 : R
  up0 : R
  up1 : R
  consumer : R

def unit (s : R → R) (w : Unit R) (x y : R) : R :=
  w.consumer * s (w.gate0*x+w.gate1*y) * (w.up0*x+w.up1*y)

def network (s : R → R) (ws : List (Unit R)) (x y : R) : R :=
  (ws.map fun w => unit s w x y).sum

/-- The only analytic property used. SiLU over the reals and ReLU both satisfy
this reflection identity. This file proves the consequences, not the real exp lemma. -/
def Reflects (s : R → R) : Prop := ∀ t, s t - s (-t) = t

theorem unit_antipodal (s : R → R) (hs : Reflects s) (w : Unit R) (x y : R) :
    unit s w x y + unit s w (-x) (-y) =
      w.consumer * (w.gate0*x+w.gate1*y) * (w.up0*x+w.up1*y) := by
  have h := hs (w.gate0*x+w.gate1*y)
  unfold unit
  grind

theorem unit_corners (s : R → R) (hs : Reflects s) (w : Unit R) :
    unit s w 1 1 + unit s w (-1) (-1) +
      unit s w 1 (-1) + unit s w (-1) 1 =
    2*(unit s w 1 0 + unit s w (-1) 0 + unit s w 0 1 + unit s w 0 (-1)) := by
  have h1 := unit_antipodal s hs w 1 1
  have h2 := unit_antipodal s hs w 1 (-1)
  have h3 := unit_antipodal s hs w 1 0
  have h4 := unit_antipodal s hs w 0 1
  grind

theorem network_corners (s : R → R) (hs : Reflects s) (ws : List (Unit R)) :
    network s ws 1 1 + network s ws (-1) (-1) +
      network s ws 1 (-1) + network s ws (-1) 1 =
    2*(network s ws 1 0 + network s ws (-1) 0 + network s ws 0 1 + network s ws 0 (-1)) := by
  induction ws with
  | nil => simp only [network, List.map_nil, List.sum_nil]; grind
  | cons w ws ih =>
    have h := unit_corners s hs w
    simp only [network, List.map_cons, List.sum_cons] at *
    grind

structure Coefficients (R : Type) where
  x : R
  y : R
  xx : R
  yy : R
  xy : R
  xxy : R
  xyy : R

def compile (f : R → R → R) : Coefficients R where
  x := 2*(f 1 0-f (-1) 0)
  y := 2*(f 0 1-f 0 (-1))
  xx := 2*(f 1 0+f (-1) 0)
  yy := 2*(f 0 1+f 0 (-1))
  xy := f 1 1-f 1 (-1)-f (-1) 1+f (-1) (-1)
  xxy := f 1 1-f 1 (-1)+f (-1) 1-f (-1) (-1)-2*(f 0 1-f 0 (-1))
  xyy := f 1 1+f 1 (-1)-f (-1) 1-f (-1) (-1)-2*(f 1 0-f (-1) 0)

def evaluate (c : Coefficients R) (x y : R) : R :=
  c.x*x+c.y*y+c.xx*x*x+c.yy*y*y+c.xy*x*y+c.xxy*x*x*y+c.xyy*x*y*y

def Trit (x : R) : Prop := x = -1 ∨ x = 0 ∨ x = 1

/-- A seven-coefficient arithmetic program, independent of hidden width.
The factor four avoids assuming that 2 is invertible in the coefficient ring. -/
theorem seven_coefficients (f : R → R → R) (zero : f 0 0 = 0)
    (corners : f 1 1+f (-1) (-1)+f 1 (-1)+f (-1) 1 =
      2*(f 1 0+f (-1) 0+f 0 1+f 0 (-1)))
    (x y : R) (hx : Trit x) (hy : Trit y) :
    evaluate (compile f) x y = 4*f x y := by
  rcases hx with rfl | rfl | rfl <;> rcases hy with rfl | rfl | rfl <;>
    simp [evaluate, compile] <;> grind

theorem network_zero (s : R → R) (ws : List (Unit R)) : network s ws 0 0 = 0 := by
  induction ws with
  | nil => simp [network]
  | cons w ws ih =>
    simp only [network, List.map_cons, List.sum_cons, unit] at *
    grind

theorem contracted_network (s : R → R) (hs : Reflects s) (ws : List (Unit R))
    (x y : R) (hx : Trit x) (hy : Trit y) :
    evaluate (compile (network s ws)) x y = 4*network s ws x y := by
  exact seven_coefficients (network s ws) (network_zero s ws)
    (network_corners s hs ws) x y hx hy

/-- The seven monomials are independent on the nine input states. This is
coefficient uniqueness, not a lower bound of seven hardware instructions. -/
theorem coefficients_unique (a b : Coefficients Int)
    (h : ∀ x y, Trit x → Trit y → evaluate a x y = evaluate b x y) : a = b := by
  have h10 := h 1 0 (by simp [Trit]) (by simp [Trit])
  have hm10 := h (-1) 0 (by simp [Trit]) (by simp [Trit])
  have h01 := h 0 1 (by simp [Trit]) (by simp [Trit])
  have h0m1 := h 0 (-1) (by simp [Trit]) (by simp [Trit])
  have h11 := h 1 1 (by simp [Trit]) (by simp [Trit])
  have h1m1 := h 1 (-1) (by simp [Trit]) (by simp [Trit])
  have hm11 := h (-1) 1 (by simp [Trit]) (by simp [Trit])
  have hm1m1 := h (-1) (-1) (by simp [Trit]) (by simp [Trit])
  cases a
  cases b
  simp only [evaluate] at *
  congr <;> omega

def relu (x : Int) : Int := max x 0

theorem relu_reflects : Reflects relu := by
  intro x
  unfold relu
  omega

/-- The input alphabet is essential, even for one hidden unit. -/
theorem outside_domain_counterexample :
    let f := network relu [⟨1, 0, 1, 0, 1⟩]
    evaluate (compile f) 2 0 = 12 ∧ 4*f 2 0 = 16 := by decide

end Kelana.ContractedFFN
