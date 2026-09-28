import Std

namespace Kelana.ObserverDescent

/-- Exact integer error at the observed outputs. Dyadic coefficients can be
cleared to integers; this is not a floating execution theorem. -/
def energy (xs : List α) (f : α → Int) : Int := (xs.map fun i => f i * f i).sum

def inner (xs : List α) (f g : α → Int) : Int := (xs.map fun i => f i * g i).sum

theorem energy_add (xs : List α) (f g : α → Int) :
    energy xs (fun i => f i + g i) = energy xs f + 2*inner xs f g + energy xs g := by
  induction xs with
  | nil => simp [energy, inner]
  | cons x xs ih =>
    simp only [energy, inner, List.map_cons, List.sum_cons] at *
    grind

theorem inner_add (xs : List α) (f g h : α → Int) :
    inner xs (fun i => f i + g i) h = inner xs f h + inner xs g h := by
  induction xs with
  | nil => simp [inner]
  | cons x xs ih =>
    simp only [inner, List.map_cons, List.sum_cons] at *
    grind

/-- A code change is useful according to its image under the consumer, not its
source-coordinate rounding error. -/
def gain (xs : List α) (residual change : α → Int) : Int :=
  -(2*inner xs residual change + energy xs change)

theorem observed_gain (xs : List α) (residual change : α → Int) :
    energy xs (fun i => residual i + change i) = energy xs residual - gain xs residual change := by
  rw [energy_add]
  unfold gain
  omega

/-- Simultaneous rounding decisions interact through the consumer's Gram matrix. -/
theorem coupled_gain (xs : List α) (residual a b : α → Int) :
    gain xs residual (fun i => a i + b i) =
      gain xs residual a + gain xs residual b - 2*inner xs a b := by
  have hi : inner xs residual (fun i => a i+b i) = inner xs residual a + inner xs residual b := by
    induction xs with
    | nil => simp [inner]
    | cons x xs ih =>
      simp only [inner, List.map_cons, List.sum_cons] at *
      grind
  have h := energy_add xs a b
  unfold gain
  omega

/-- A cheap approximate observer can certify a true improvement only when its
unseen error has a bounded correlation with the proposed change. -/
theorem approximate_observer_certificate (xs : List α) (estimated error change : α → Int)
    (budget : Int)
    (hcorrelation : inner xs error change ≤ budget)
    (hgain : 2*budget < gain xs estimated change) :
    energy xs (fun i => estimated i + error i + change i) <
      energy xs (fun i => estimated i + error i) := by
  have hg := observed_gain xs (fun i => estimated i+error i) change
  have hi := inner_add xs estimated error change
  unfold gain at *
  omega

/-- Each change independently reduces observed squared error, but combining them
can increase it. This is why the CPU search checks each complete update. -/
theorem independent_improvements_can_conflict :
    let xs := [()]
    let r := fun (_ : Unit) => (-2 : Int)
    let a := fun (_ : Unit) => (3 : Int)
    0 < gain xs r a ∧
      energy xs (fun i => r i+a i+a i) > energy xs r := by decide +kernel

/-- Source fidelity and consumer fidelity order representations differently. -/
theorem source_fidelity_not_observer_fidelity :
    let source := [0, 0]
    let largeChange := [100, -100]
    let smallChange := [1, 0]
    source.sum = largeChange.sum ∧ source.sum ≠ smallChange.sum ∧
      energy largeChange id > energy smallChange id := by decide +kernel

/-- Two hidden values are 0.49 on a unit grid. Individually nearest codes give
0+0; coordinated codes give 1+0. Their source error increases while the observed
sum error falls by a factor of 49. All values here are in hundredths. -/
theorem nearest_source_codes_can_lose :
    let original : List Int := [49,49]
    let nearest : List Int := [0,0]
    let coordinated : List Int := [100,0]
    energy [49,49] id < energy [51,-49] id ∧
      (original.sum-coordinated.sum)^2 * 2401 = (original.sum-nearest.sum)^2 := by
  decide +kernel

/-- On a nearest-rounding cell, moving one code by one step cannot improve
its diagonal Gram contribution. `twiceError` clears the factor 1/2. -/
theorem nearest_diagonal_nonnegative (h step twiceError delta : Int)
    (hh : 0 ≤ h) (hs : 0 ≤ step)
    (he : -step ≤ twiceError ∧ twiceError ≤ step)
    (hd : delta = -1 ∨ delta = 1) :
    0 ≤ h * step * (step + delta * twiceError) := by
  have hc : 0 ≤ step + delta * twiceError := by
    rcases hd with hd | hd <;> subst delta <;> omega
  exact Int.mul_nonneg (Int.mul_nonneg hh hs) hc

/-- Any improving single-coordinate move from nearest rounding must exploit
an off-diagonal correlation. Preserving only column norms cannot find it. -/
theorem nearest_gain_requires_correlation (h step twiceError delta correlation : Int)
    (hh : 0 ≤ h) (hs : 0 ≤ step)
    (he : -step ≤ twiceError ∧ twiceError ≤ step)
    (hd : delta = -1 ∨ delta = 1)
    (hgain : h * step * (step + delta * twiceError) +
      2 * step * (delta * correlation) < 0) :
    delta * correlation < 0 := by
  have hdiag := nearest_diagonal_nonnegative h step twiceError delta hh hs he hd
  by_cases hc : delta * correlation < 0
  · exact hc
  · have hc' : 0 ≤ delta * correlation := by omega
    have hp : 0 ≤ 2 * step := by omega
    have hcross := Int.mul_nonneg hp hc'
    omega

end Kelana.ObserverDescent
