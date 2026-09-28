import Std

/-!
# Additive quantization search bounds

These lemmas justify the scalar interval, residue, and projection-error bounds
used by an additive search. They do not compute minima, maxima, gcds, or nearest
lattice points. A checker supplies those facts for each finite option set.
-/

namespace Kelana.QuantizationBounds

/-- Membership in the affine residue class `base + step * ℤ`. A zero step is the
singleton containing `base`. -/
def InResidue (value base step : Int) : Prop :=
  ∃ k : Int, value = base + step * k

/-- Scalar information about the projection of one independent choice. -/
structure ScalarBound where
  lower : Int
  upper : Int
  base : Int
  step : Int

/-- A projected option satisfies both the interval and residue information. -/
def ScalarBound.Holds (bound : ScalarBound) (value : Int) : Prop :=
  bound.lower ≤ value ∧ value ≤ bound.upper ∧
    InResidue value bound.base bound.step

/-- Divisibility of the difference is the usual certificate for affine residue
membership. In particular, a proved gcd of all option differences discharges
this premise for every option. -/
theorem inResidue_of_dvd_sub {value base step : Int}
    (h : step ∣ value - base) : InResidue value base step := by
  rcases h with ⟨k, hk⟩
  refine ⟨k, ?_⟩
  have hv : value = step * k + base := Int.sub_eq_iff_eq_add.mp hk
  simpa [Int.add_comm] using hv

/-- Local interval endpoints and a difference-divisibility witness establish a
complete scalar bound for one option. -/
theorem ScalarBound.holds_of_dvd_sub (bound : ScalarBound) (value : Int)
    (hlower : bound.lower ≤ value) (hupper : value ≤ bound.upper)
    (hresidue : bound.step ∣ value - bound.base) : bound.Holds value :=
  ⟨hlower, hupper, inResidue_of_dvd_sub hresidue⟩

/-- Residue classes close under addition after weakening both moduli to a common
divisor. -/
theorem inResidue_add {x y baseX baseY stepX stepY common : Int}
    (hx : InResidue x baseX stepX) (hy : InResidue y baseY stepY)
    (hdx : common ∣ stepX) (hdy : common ∣ stepY) :
    InResidue (x + y) (baseX + baseY) common := by
  rcases hx with ⟨kx, rfl⟩
  rcases hy with ⟨ky, rfl⟩
  rcases hdx with ⟨mx, rfl⟩
  rcases hdy with ⟨my, rfl⟩
  refine ⟨mx * kx + my * ky, ?_⟩
  simp [Int.mul_add, Int.mul_assoc, Int.add_assoc, Int.add_left_comm]

/-- One selected scalar option, packaged with the fact that the suffix common
step divides this option set's local step. -/
structure BoundedTerm (commonStep : Int) where
  value : Int
  bound : ScalarBound
  holds : bound.Holds value
  common_dvd_step : commonStep ∣ bound.step

def sumValues (terms : List (BoundedTerm commonStep)) : Int :=
  (terms.map BoundedTerm.value).sum

def sumLowers (terms : List (BoundedTerm commonStep)) : Int :=
  (terms.map (fun term => term.bound.lower)).sum

def sumUppers (terms : List (BoundedTerm commonStep)) : Int :=
  (terms.map (fun term => term.bound.upper)).sum

def sumBases (terms : List (BoundedTerm commonStep)) : Int :=
  (terms.map (fun term => term.bound.base)).sum

/-- A sum of independent choices lies in the sum of their intervals and in the
affine residue class whose step divides every local option-difference step.
The list may have any finite length. -/
theorem sum_bounds (commonStep : Int) (terms : List (BoundedTerm commonStep)) :
    sumLowers terms ≤ sumValues terms ∧
      sumValues terms ≤ sumUppers terms ∧
      InResidue (sumValues terms) (sumBases terms) commonStep := by
  induction terms with
  | nil =>
      refine ⟨by simp [sumLowers, sumValues], by simp [sumValues, sumUppers], ?_⟩
      exact ⟨0, by simp [sumValues, sumBases]⟩
  | cons term rest ih =>
      rcases term.holds with ⟨hlower, hupper, hresidue⟩
      rcases ih with ⟨hlowers, huppers, hresidues⟩
      refine ⟨?_, ?_, ?_⟩
      · simp only [sumLowers, sumValues, List.map_cons, List.sum_cons]
        exact Int.add_le_add hlower hlowers
      · simp only [sumValues, sumUppers, List.map_cons, List.sum_cons]
        exact Int.add_le_add hupper huppers
      · simp only [sumValues, sumBases, List.map_cons, List.sum_cons]
        exact inResidue_add hresidue hresidues term.common_dvd_step
          (Int.dvd_refl commonStep)

/-- The integer linear projection of coordinate errors. -/
def projectionError (terms : List (Int × Int)) : Int :=
  (terms.map (fun term => term.1 * term.2)).sum

/-- The `ℓ₁` norm of the integer probe coefficients. -/
def probeNorm (terms : List (Int × Int)) : Nat :=
  (terms.map (fun term => term.1.natAbs)).sum

/-- If every coordinate error has absolute value at most `E`, then the projected
error is at most the probe's `ℓ₁` norm times `E`. -/
theorem projectionError_le (terms : List (Int × Int)) (E : Nat)
    (bounded : ∀ term ∈ terms, term.2.natAbs ≤ E) :
    (projectionError terms).natAbs ≤ probeNorm terms * E := by
  induction terms with
  | nil => simp [projectionError, probeNorm]
  | cons term rest ih =>
      have hterm : term.2.natAbs ≤ E := bounded term (by simp)
      have hrest : ∀ item ∈ rest, item.2.natAbs ≤ E := by
        intro item hitem
        exact bounded item (by simp [hitem])
      have htail := ih hrest
      calc
        (projectionError (term :: rest)).natAbs
            ≤ (term.1 * term.2).natAbs + (projectionError rest).natAbs := by
                simpa [projectionError] using
                  Int.natAbs_add_le (term.1 * term.2) (projectionError rest)
        _ = term.1.natAbs * term.2.natAbs + (projectionError rest).natAbs := by
              rw [Int.natAbs_mul]
        _ ≤ term.1.natAbs * E + probeNorm rest * E :=
              Nat.add_le_add (Nat.mul_le_mul_left term.1.natAbs hterm) htail
        _ = probeNorm (term :: rest) * E := by
              simp [probeNorm, Nat.add_mul]

/-- Ceiling division, with the search convention that a positive denominator is
supplied by the caller. -/
def ceilDiv (distance norm : Nat) : Nat :=
  (distance + norm - 1) / norm

/-- Cleared-denominator form of the ceiling step. -/
theorem ceilDiv_le_of_le_mul {distance norm E : Nat} (hnorm : 0 < norm)
    (hbound : distance ≤ norm * E) : ceilDiv distance norm ≤ E := by
  unfold ceilDiv
  apply (Nat.div_le_iff_le_mul hnorm).2
  have hbound' : distance ≤ E * norm := by
    simpa [Nat.mul_comm] using hbound
  exact Nat.sub_le_sub_right (Nat.add_le_add_right hbound' norm) 1

/-- A certified lower bound on projected distance yields a lower bound on the
coordinate error budget after ceiling division by the probe norm. -/
theorem projectedDistance_lower_bound (terms : List (Int × Int)) (E distance : Nat)
    (bounded : ∀ term ∈ terms, term.2.natAbs ≤ E)
    (distanceLower : distance ≤ (projectionError terms).natAbs)
    (normPositive : 0 < probeNorm terms) :
    ceilDiv distance (probeNorm terms) ≤ E := by
  apply ceilDiv_le_of_le_mul normPositive
  exact Nat.le_trans distanceLower (projectionError_le terms E bounded)

/-- Signed min-sum dual bound. `selectedBound` is obtained by choosing the
actual option in every per-block minimum. `projectedError` is the one-sided
probe inequality, normally used once for a probe and once for its negation. -/
theorem signedMinSumDual
    (q paid selectedCost errorPrice prefixProjection suffixProjection
      selectedMinSum error : Int)
    (selectedBound : selectedMinSum ≤
      q * selectedCost + errorPrice * suffixProjection)
    (projectedError : prefixProjection + suffixProjection ≤ q * error)
    (priceNonnegative : 0 ≤ errorPrice) :
    q * paid + errorPrice * prefixProjection + selectedMinSum ≤
      q * (paid + selectedCost + errorPrice * error) := by
  have pricedProjection :
      errorPrice * (prefixProjection + suffixProjection) ≤
        errorPrice * (q * error) :=
    Int.mul_le_mul_of_nonneg_left projectedError priceNonnegative
  calc
    q * paid + errorPrice * prefixProjection + selectedMinSum
        ≤ q * paid + errorPrice * prefixProjection +
            (q * selectedCost + errorPrice * suffixProjection) :=
          Int.add_le_add_left selectedBound _
    _ = q * (paid + selectedCost) +
          errorPrice * (prefixProjection + suffixProjection) := by
          simp only [Int.mul_add]
          ac_rfl
    _ ≤ q * (paid + selectedCost) + errorPrice * (q * error) :=
          Int.add_le_add_left pricedProjection _
    _ = q * (paid + selectedCost + errorPrice * error) := by
          simp only [Int.mul_add]
          have hmul : errorPrice * (q * error) = q * (errorPrice * error) := by
            ac_rfl
          rw [hmul]

#print axioms sum_bounds
#print axioms projectionError_le
#print axioms projectedDistance_lower_bound
#print axioms signedMinSumDual

end Kelana.QuantizationBounds
