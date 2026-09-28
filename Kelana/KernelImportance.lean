import Std

namespace Kelana.KernelImportance

/-- All coordinates, scores, and log densities here are exact rational
    polynomials. Exponentiation and integration are intentionally absent. -/
def total (xs : List I) (f : I → Rat) : Rat := (xs.map f).sum

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

private theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i + g i) = total xs f + total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_sub (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i - g i) = total xs f - total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a * f i) = a * total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_div (xs : List I) (f : I → Rat) (a : Rat) :
    total xs (fun i => f i / a) = total xs f / a := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_nonneg (xs : List I) (f : I → Rat)
    (hf : ∀ i ∈ xs, 0 ≤ f i) : 0 ≤ total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := hf i (by simp)
    have ht : ∀ j ∈ xs, 0 ≤ f j := by grind
    change 0 ≤ f i + total xs f
    grind [ih ht]

private theorem square_nonneg (x : Rat) : 0 ≤ x*x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

private theorem total_half (xs : List I) (f : I → Rat) :
    total xs (fun i => f i / 2) = total xs f / 2 := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_neg (xs : List I) (f : I → Rat) :
    total xs (fun i => -(f i)) = -(total xs f) := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

def dot (xs : List I) (u v : I → Rat) : Rat :=
  total xs (fun i => u i * v i)

def normSq (xs : List I) (u : I → Rat) : Rat := dot xs u u

def logRatio (xs : List I) (w z c : I → Rat) : Rat :=
  dot xs w (fun i => z i - c i) -
    normSq xs (fun i => z i - c i) / 2

def baseLogRatio (xs : List I) (t z : I → Rat) : Rat :=
  dot xs t z - normSq xs z / 2

def logImportance (xs : List I) (c t : I → Rat) : Rat :=
  -(dot xs c t) + normSq xs c / 2

def gaussianLog (xs : List I) (w : I → Rat) : Rat :=
  -(normSq xs w) / 2

theorem key_shift_dot (xs : List I) (w z c : I → Rat) :
    dot xs w (fun i => z i-c i) = dot xs w z - dot xs w c := by
  unfold dot
  calc
    _ = total xs (fun i => w i*z i - w i*c i) := by
      apply total_congr xs
      intro i hi
      grind +ring
    _ = _ := total_sub xs _ _

private theorem logRatio_sum (xs : List I) (w z c : I → Rat) :
    logRatio xs w z c = total xs (fun i =>
      w i*(z i-c i) - ((z i-c i)*(z i-c i))/2) := by
  change total xs (fun i => w i*(z i-c i)) -
      total xs (fun i => (z i-c i)*(z i-c i))/2 = _
  rw [← total_half]
  exact (total_sub xs _ _).symm

private theorem baseLogRatio_sum (xs : List I) (t z : I → Rat) :
    baseLogRatio xs t z = total xs (fun i =>
      t i*z i - (z i*z i)/2) := by
  change total xs (fun i => t i*z i) -
      total xs (fun i => z i*z i)/2 = _
  rw [← total_half]
  exact (total_sub xs _ _).symm

private theorem logImportance_sum (xs : List I) (c t : I → Rat) :
    logImportance xs c t = total xs (fun i =>
      -(c i*t i) + (c i*c i)/2) := by
  change -(total xs (fun i => c i*t i)) +
      total xs (fun i => c i*c i)/2 = _
  rw [← total_neg, ← total_half]
  exact (total_add xs _ _).symm

private theorem gaussianLog_sum (xs : List I) (w : I → Rat) :
    gaussianLog xs w = total xs (fun i => -(w i*w i)/2) := by
  change -(total xs (fun i => w i*w i))/2 = _
  calc
    _ = -(total xs (fun i => (w i*w i)/2)) := by
      rw [total_half]
      grind +ring
    _ = total xs (fun i => -((w i*w i)/2)) :=
      (total_neg xs _).symm
    _ = _ := by
      apply total_congr xs
      intro i hi
      grind +ring

/-- Gaussian log-importance reparametrization: with `t=w+c`, the centered
    feature ratio differs from the uncentered ratio at `t` by exactly the
    change-of-proposal log weight. This is a finite rational identity. -/
theorem ratio_translation (xs : List I) (w z c : I → Rat) :
    logRatio xs w z c =
      baseLogRatio xs (fun i => w i+c i) z +
      logImportance xs c (fun i => w i+c i) := by
  rw [logRatio_sum, baseLogRatio_sum, logImportance_sum]
  rw [← total_add]
  apply total_congr xs
  intro i hi
  grind +ring

/-- The Gaussian quadratic log density changes by the *opposite* amount.
    The result is pointwise; no assertion about Jacobians or Gaussian
    probability measures is needed for the polynomial equality. -/
theorem density_translation (xs : List I) (w c : I → Rat) :
    gaussianLog xs w + logImportance xs c (fun i => w i+c i) =
      gaussianLog xs (fun i => w i+c i) := by
  rw [gaussianLog_sum, logImportance_sum, gaussianLog_sum]
  rw [← total_add]
  apply total_congr xs
  intro i hi
  grind +ring

/-- The cancellation makes the *unnormalized* Gaussian log integrand
    exactly invariant under translation. -/
theorem integrand_translation (xs : List I) (w z c : I → Rat) :
    gaussianLog xs w + logRatio xs w z c =
      gaussianLog xs (fun i => w i+c i) +
        baseLogRatio xs (fun i => w i+c i) z := by
  rw [ratio_translation xs w z c]
  have h := density_translation xs w c
  grind +ring

/-- Finite importance-sampling variance identity. The right side is a
    sum of nonnegative residual squares. It is valid for signed target scores
    `u`; positive `u` is needed only to realize the optimal positive proposal. -/
theorem importance_residual (xs : List I) (u ρ : I → Rat)
    (hρ : ∀ i ∈ xs, 0 < ρ i) (hsum : total xs ρ = 1) :
    let U := total xs u
    total xs (fun i => (u i*u i)/ρ i) - U*U =
      total xs (fun i => ((u i-ρ i*U)*(u i-ρ i*U))/ρ i) := by
  dsimp only
  let U := total xs u
  have hpoint : ∀ i ∈ xs,
      ((u i-ρ i*U)*(u i-ρ i*U))/ρ i =
        (u i*u i)/ρ i - (2*U)*u i + (U*U)*ρ i := by
    intro i hi
    have hp := Rat.ne_of_gt (hρ i hi)
    have hleft := Rat.div_mul_cancel hp
      (a := (u i-ρ i*U)*(u i-ρ i*U))
    have hright := Rat.div_mul_cancel hp (a := u i*u i)
    apply Rat.le_antisymm
    · apply Rat.le_of_mul_le_mul_right (c := ρ i) ?_ (hρ i hi)
      grind +ring
    · apply Rat.le_of_mul_le_mul_right (c := ρ i) ?_ (hρ i hi)
      grind +ring
  symm
  change total xs (fun i => ((u i-ρ i*U)*(u i-ρ i*U))/ρ i) =
    total xs (fun i => (u i*u i)/ρ i) - U*U
  calc
    _ = total xs (fun i =>
        (u i*u i)/ρ i - (2*U)*u i + (U*U)*ρ i) := by
      apply total_congr xs
      intro i hi
      exact hpoint i hi
    _ = total xs (fun i => (u i*u i)/ρ i) -
        (2*U)*total xs u + (U*U)*total xs ρ := by
      rw [total_add, total_sub, total_mul, total_mul]
    _ = total xs (fun i => (u i*u i)/ρ i) - U*U := by
      rw [hsum]
      grind +ring

/-- Finite importance Cauchy. For normalized positive proposal weights,
    the squared target sum cannot exceed the second-moment cost. -/
theorem importance_cauchy (xs : List I) (u ρ : I → Rat)
    (hρ : ∀ i ∈ xs, 0 < ρ i) (hsum : total xs ρ = 1) :
    (total xs u)*(total xs u) ≤
      total xs (fun i => (u i*u i)/ρ i) := by
  have hres := importance_residual xs u ρ hρ hsum
  dsimp only at hres
  have hnonneg :
      0 ≤ total xs (fun i =>
        ((u i-ρ i*total xs u)*(u i-ρ i*total xs u))/ρ i) := by
    apply total_nonneg xs
      (fun i => ((u i-ρ i*total xs u)*(u i-ρ i*total xs u))/ρ i)
    intro i hi
    have hd := Rat.div_mul_cancel (Rat.ne_of_gt (hρ i hi))
      (a := (u i-ρ i*total xs u)*(u i-ρ i*total xs u))
    apply Rat.le_of_mul_le_mul_right (c := ρ i) ?_ (hρ i hi)
    rw [Rat.zero_mul, hd]
    exact square_nonneg _
  grind

/-- Supplied nonnegative magnitudes `g` with `g²=G²` give the usual
    π-weighted importance bound; the proof actually does not need their
    nonnegativity, only the squared-magnitude identities. -/
theorem finite_importance_cauchy (xs : List I)
    (π g G ρ : I → Rat)
    (hρ : ∀ i ∈ xs, 0 < ρ i) (hsum : total xs ρ = 1)
    (hmag : ∀ i ∈ xs, g i*g i = G i*G i) :
    (total xs (fun i => π i*g i))*(total xs (fun i => π i*g i)) ≤
      total xs (fun i => (π i*π i*(G i*G i))/ρ i) := by
  calc
    _ ≤ total xs (fun i => ((π i*g i)*(π i*g i))/ρ i) :=
      importance_cauchy xs (fun i => π i*g i) ρ hρ hsum
    _ = _ := by
      apply total_congr xs
      intro i hi
      rw [← hmag i hi]
      grind +ring

/-- Strictly positive target magnitudes admit the positive proposal
    `ρ_i=u_i/U`, which sums to one and attains the importance Cauchy bound.
    In particular a translation of Gaussian sample coordinates does not
    change the best *arbitrary-proposal* second moment after proper weighting;
    the latter interpretation still needs the real change-of-variables step. -/
theorem importance_optimal (xs : List I) (u : I → Rat)
    (hu : ∀ i ∈ xs, 0 < u i) (hU : 0 < total xs u) :
    let U := total xs u
    let ρ := fun i => u i / U
    total xs ρ = 1 ∧
      total xs (fun i => (u i*u i)/ρ i) = U*U := by
  dsimp only
  let U := total xs u
  let ρ : I → Rat := fun i => u i / U
  have hρ : ∀ i ∈ xs, 0 < ρ i := by
    intro i hi
    dsimp [ρ]
    exact (Rat.lt_div_iff hU).mpr (by simpa only [Rat.zero_mul] using hu i hi)
  have hmass : total xs ρ = 1 := by
    dsimp [ρ]
    rw [total_div]
    have hself := Rat.mul_div_cancel (Rat.ne_of_gt hU) (a := (1:Rat))
    simpa only [Rat.one_mul] using hself
  refine ⟨hmass, ?_⟩
  calc
    _ = total xs (fun i => U*u i) := by
      apply total_congr xs
      intro i hi
      have hρi := Rat.ne_of_gt (hρ i hi)
      have hleft := Rat.div_mul_cancel hρi (a := u i*u i)
      have hright := Rat.div_mul_cancel (Rat.ne_of_gt hU) (a := u i)
      have hproduct : (U*u i)*ρ i = u i*u i := by
        dsimp [ρ]
        grind +ring
      apply Rat.le_antisymm
      · apply Rat.le_of_mul_le_mul_right (c := ρ i) ?_ (hρ i hi)
        grind +ring
      · apply Rat.le_of_mul_le_mul_right (c := ρ i) ?_ (hρ i hi)
        grind +ring
    _ = U*U := by rw [total_mul]

end Kelana.KernelImportance
