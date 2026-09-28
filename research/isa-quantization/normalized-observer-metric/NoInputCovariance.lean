import Std

namespace Kelana.NormalizedObserverMetric

/-! Two-token exact rational witness for the differential squared response of
    F(z) = diag(2,3) z / sqrt((z₁²+z₂²)/2 + 1), with teacher W = I and
    equiprobable inputs e₁,e₂. At each input, radial and tangent squared
    derivatives are 8/27 and 2/3 respectively. Multiplying the two output
    gamma squares gives this rank-one perturbation response matrix. The common
    source probability 1/2 is omitted; it does not affect rank. -/

private def radial : Rat := 8 / 27
private def tangent : Rat := 2 / 3

def response11 : Rat := 4 * radial
def response12 : Rat := 4 * tangent
def response21 : Rat := 9 * tangent
def response22 : Rat := 9 * radial

/-- The mixed minor is nonzero even with positive epsilon and learned gamma. -/
theorem response_minor_nonzero :
    response11 * response22 ≠ response12 * response21 := by
  native_decide

private theorem rational_mul_left_comm (a b c : Rat) :
    a * (b * c) = b * (a * c) := by
  calc
    a * (b * c) = (a * b) * c := (Rat.mul_assoc a b c).symm
    _ = (b * a) * c := by rw [Rat.mul_comm a b]
    _ = b * (a * c) := Rat.mul_assoc b a c

/-- Every input/output-separable quadratic response has zero probe minor;
    therefore it cannot reproduce all four exact witness responses. -/
theorem no_separable_input_output_metric
    (c₁ c₂ q₁ q₂ : Rat)
    (h11 : q₁ * c₁ = response11)
    (h12 : q₁ * c₂ = response12)
    (h21 : q₂ * c₁ = response21)
    (h22 : q₂ * c₂ = response22) : False := by
  apply response_minor_nonzero
  calc
    response11 * response22 = (q₁ * c₁) * (q₂ * c₂) := by rw [h11, h22]
    _ = (q₁ * c₂) * (q₂ * c₁) := by
      simp only [rational_mul_left_comm, Rat.mul_comm]
    _ = response12 * response21 := by rw [h12, h21]

end Kelana.NormalizedObserverMetric
