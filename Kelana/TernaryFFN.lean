import Kelana.TernaryAlgebra

namespace Kelana.TernaryFFN
open Lean.Grind
open Kelana.TernaryAlgebra

variable {R : Type} [CommRing R]

def linear {n : Nat} : List (R × Fin n) → Expr R n
  | [] => .lit 0
  | (w,i)::ws => .plus (.times (.lit w) (.var i)) (linear ws)

theorem linear_neg {n : Nat} (ws : List (R × Fin n)) (x : Fin n → R) :
    (linear ws).eval (fun i => -x i) = -(linear ws).eval x := by
  induction ws with
  | nil => simp [linear, Expr.eval]; grind
  | cons w ws ih => simp only [linear, Expr.eval, ih]; grind

structure Unit (R : Type) (n : Nat) where
  gate : List (R × Fin n)
  up : List (R × Fin n)
  consumer : R

def unit {n : Nat} (activation : R → R) (w : Unit R n) (x : Fin n → R) : R :=
  w.consumer * activation ((linear w.gate).eval x) * (linear w.up).eval x

def network {n : Nat} (activation : R → R) (ws : List (Unit R n)) (x : Fin n → R) : R :=
  (ws.map (fun w => unit activation w x)).sum

def quadratic {n : Nat} : List (Unit R n) → Expr R n
  | [] => .lit 0
  | w::ws => .plus (.times (.lit w.consumer) (.times (linear w.gate) (linear w.up))) (quadratic ws)

/-- The arbitrary-width FFN's antipodal sum is quadratic before quantization.
The activation is otherwise unrestricted; SiLU and ReLU satisfy this reflection
identity in real arithmetic. This theorem does not move through a quantizer. -/
theorem network_reflection {n : Nat} (activation : R → R)
    (ha : ∀ t, activation t-activation (-t)=t)
    (ws : List (Unit R n)) (x : Fin n → R) :
    network activation ws x + network activation ws (fun i => -x i) =
      (quadratic ws).eval x := by
  induction ws with
  | nil => simp [network, quadratic, Expr.eval]; grind
  | cons w ws ih =>
    have h := ha ((linear w.gate).eval x)
    simp only [network, List.map_cons, List.sum_cons] at *
    simp only [unit, linear_neg] at ih
    simp only [unit, linear_neg, quadratic, Expr.eval]
    grind

theorem neg_grid {n : Nat} (x : Fin n → R) (hx : TernaryGrid x) :
    TernaryGrid (fun i => -x i) := by
  intro i
  change Trit (-x i)
  rcases hx i with h | h | h <;> rw [h] <;> unfold Trit <;> grind

/-- The reflection law becomes equality of coefficients, not just an agreement
on sampled inputs. The normalizer computes the quadratic side without expanding
or tabulating the activation. -/
theorem canonical_even_part {n : Nat} (activation : R → R)
    (ha : ∀ t, activation t-activation (-t)=t)
    (half : R) (hh : 2*half=1)
    (cancelTwo : ∀ a b : R, 2*a=2*b → a=b)
    (ws : List (Unit R n)) :
    let p := interpolate half n (network activation ws)
    add p (reflect p) = (quadratic ws).normalize := by
  apply coefficients_unique cancelTwo
  intro x hx
  rw [evaluate_add, evaluate_reflect,
    interpolate_correct half hh n _ x hx,
    interpolate_correct half hh n _ _ (neg_grid x hx),
    normalize_correct _ x (ternary_is_cubic x hx)]
  exact network_reflection activation ha ws x

/-- Any absent even coefficient of the quadratic is absent from the whole FFN.
The statement applies at every input arity and hidden width. -/
theorem absent_even_coefficient {n : Nat} (activation : R → R)
    (ha : ∀ t, activation t-activation (-t)=t)
    (half : R) (hh : 2*half=1)
    (cancelTwo : ∀ a b : R, 2*a=2*b → a=b)
    (ws : List (Unit R n)) (e : Fin n → Fin 3)
    (he : oddDegree e=false)
    (hq : coefficient (quadratic ws).normalize e=0) :
    coefficient (interpolate half n (network activation ws)) e=0 := by
  exact even_coefficient_vanishes cancelTwo _ _
    (canonical_even_part activation ha half hh cancelTwo ws) e he hq

end Kelana.TernaryFFN
