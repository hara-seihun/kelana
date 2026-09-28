import Std

namespace Kelana.Approximation

-- Exact identities for stochastic rounding to adjacent grid points. The two
-- errors are -r and d-r, with probability numerators d-r and r and mass d.
theorem adjacent_rounding_unbiased (d r : Int) :
    (d-r)*(-r) + r*(d-r) = 0 := by grind

theorem adjacent_rounding_energy (d r : Int) :
    (d-r)*((-r)*(-r)) + r*((d-r)*(d-r)) = d*r*(d-r) := by grind

theorem adjacent_variance_bound (d r : Int) :
    4*r*(d-r) ≤ d*d := by
  have h := Int.sq_nonneg (d-2*r)
  grind

-- Zero conditional mean before a nonlinear consumer does not imply zero mean
-- after it. This identity exposes the variance term in the square example.
theorem square_bias (x e : Int) :
    (x+e)*(x+e) + (x-e)*(x-e) = 2*x*x + 2*e*e := by grind

def roundHundred (x : Int) : Int := (x+50)/100

theorem rounding_creates_bias :
    51+47 = 2*(49 : Int) ∧
    roundHundred 51 + roundHundred 47 ≠ 2*roundHundred 49 := by decide

def positiveError (depth : Nat) (amplitude : Int) : Int := 2^depth * amplitude
def negativeError (depth : Nat) (amplitude : Int) : Int := -(2^depth * amplitude)
def energy (depth : Nat) (amplitude : Int) : Int :=
  positiveError depth amplitude * positiveError depth amplitude +
  negativeError depth amplitude * negativeError depth amplitude

theorem zero_mean_at_every_depth (depth : Nat) (amplitude : Int) :
    positiveError depth amplitude + negativeError depth amplitude = 0 := by
  unfold positiveError negativeError
  omega

theorem energy_quadruples (depth : Nat) (amplitude : Int) :
    energy (depth+1) amplitude = 4*energy depth amplitude := by
  unfold energy positiveError negativeError
  simp only [Int.pow_succ]
  grind

def sampleMeanNumerator (xs : List Int) : Int := xs.sum
def sampleEnergyNumerator (xs : List Int) : Int := (xs.map (fun x => x*x)).sum

theorem correlation_changes_accumulation :
    sampleMeanNumerator [2,0,0,-2] = 0 ∧
    sampleMeanNumerator [2,-2] = 0 ∧
    sampleEnergyNumerator [2,0,0,-2] = 8 ∧
    sampleEnergyNumerator [2,-2] = 8 := by decide

-- Both examples sum two individually unbiased unit errors. The independent
-- example has four equiprobable outcomes and variance 8/4=2; the correlated
-- example has two equiprobable outcomes and variance 8/2=4.
#print axioms adjacent_rounding_unbiased
#print axioms adjacent_variance_bound
#print axioms square_bias
#print axioms energy_quadruples
end Kelana.Approximation
