import Std

namespace Kelana.ConsumerGeometry

abbrev Triple := Int × Int × Int
abbrev Pair := Int × Int

def consume (x : Triple) : Pair := (x.1+x.2.2, x.2.1+x.2.2)
def move (x : Triple) (t : Int) : Triple := (x.1-t, x.2.1-t, x.2.2+t)

theorem invisible_move (x : Triple) (t : Int) :
    consume (move x t) = consume x := by
  apply Prod.ext <;> simp [consume, move] <;> omega

-- A bounded coefficient can move to a face without changing either output.
-- This is a constructive instance, not the arbitrary-matrix vertex theorem.
theorem reaches_face (r x y z : Int)
    (hx : -r ≤ x ∧ x ≤ r) (hy : -r ≤ y ∧ y ≤ r)
    (hz : -r ≤ z ∧ z ≤ r) :
    let t := min (x+r) (min (y+r) (r-z))
    0 ≤ t ∧
    (-r ≤ x-t ∧ x-t ≤ r) ∧
    (-r ≤ y-t ∧ y-t ≤ r) ∧
    (-r ≤ z+t ∧ z+t ≤ r) ∧
    (x-t = -r ∨ y-t = -r ∨ z+t = r) := by
  dsimp
  omega

def inputEnergy (x y : Triple) : Int :=
  (x.1-y.1)^2 + (x.2.1-y.2.1)^2 + (x.2.2-y.2.2)^2

def outputEnergy (x y : Triple) : Int :=
  ((consume x).1-(consume y).1)^2 + ((consume x).2-(consume y).2)^2

-- Common denominator 100. Ordinary coordinate rounding selects (0,0,0).
-- (0,0,100) is farther in the input metric but 2401 times better in output energy.
theorem nearest_input_can_lose :
    inputEnergy (49,49,49) (0,0,0) = 7203 ∧
    inputEnergy (49,49,49) (0,0,100) = 7403 ∧
    outputEnergy (49,49,49) (0,0,0) = 19208 ∧
    outputEnergy (49,49,49) (0,0,100) = 8 := by decide

-- The mixed terms, not just each channel's individual variance, decide
-- whether downstream errors cancel. This is exact, with no small-error limit.
theorem consumer_error_energy (a b c : Int) :
    (a+c)^2 + (b+c)^2 = a*a+b*b+2*c*c+2*a*c+2*b*c := by grind

theorem correlated_error_disappears (e : Int) :
    outputEnergy (e,e,-e) (0,0,0) = 0 ∧
    inputEnergy (e,e,-e) (0,0,0) = 3*e*e := by
  simp [outputEnergy, inputEnergy, consume]
  grind

-- For a fixed multiplier vector m, consumer fitting has loss
-- c - 2*L*n + L^2*d, where d=mᵀCm, n=mᵀCλ, c=λᵀCλ.
-- Clearing denominators exposes the nonnegative square around L=n/d.
theorem scale_fit_square (d n c l : Int) :
    d*(c-2*l*n+d*l*l) = d*c-n*n+(d*l-n)*(d*l-n) := by grind

theorem scale_fit_lower_numerator (d n c l : Int) :
    d*c-n*n ≤ d*(c-2*l*n+d*l*l) := by
  have h := Int.sq_nonneg (d*l-n)
  have identity := scale_fit_square d n c l
  grind

end Kelana.ConsumerGeometry
