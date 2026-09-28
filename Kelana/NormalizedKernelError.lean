import Std

namespace Kelana.NormalizedKernelError

/-- Exact finite rational sums, with no distributional assumptions. -/
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

private theorem total_nonneg (xs : List I) (f : I → Rat)
    (hf : ∀ i ∈ xs, 0 ≤ f i) : 0 ≤ total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := hf i (by simp)
    have ht : ∀ j ∈ xs, 0 ≤ f j := by grind
    change 0 ≤ f i + total xs f
    grind [ih ht]

private theorem total_zero (xs : List I) :
    total xs (fun _ => (0:Rat)) = 0 := by
  induction xs with
  | nil => rfl
  | cons i rest ih =>
    change 0 + total rest (fun _ => (0:Rat)) = 0
    grind

private theorem total_pos (xs : List I) (f : I → Rat)
    (hne : xs ≠ []) (hf : ∀ i ∈ xs, 0 < f i) : 0 < total xs f := by
  cases xs with
  | nil => contradiction
  | cons i rest =>
    have hi := hf i (by simp)
    have ht : ∀ j ∈ rest, 0 ≤ f j := by
      intro j hj
      exact Rat.le_of_lt (hf j (by simp [hj]))
    have htail := total_nonneg rest f ht
    change 0 < f i + total rest f
    grind

private theorem square_nonneg (x : Rat) : 0 ≤ x*x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

/-- Weighted Cauchy over a finite list, proved inductively by adjoining one
    observation. The induction remainder is a sum of nonnegative pairwise
    squares `w_i*w_j*(x_i*z_j-x_j*z_i)^2`. -/
theorem weighted_cauchy (xs : List I) (w x z : I → Rat)
    (hw : ∀ i ∈ xs, 0 ≤ w i) :
    (total xs (fun i => w i*x i*z i)) *
      (total xs (fun i => w i*x i*z i)) ≤
    (total xs (fun i => w i*(x i*x i))) *
      (total xs (fun i => w i*(z i*z i))) := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hwi : 0 ≤ w i := hw i (by simp)
    have htail : ∀ j ∈ xs, 0 ≤ w j := by grind
    have ih' := ih htail
    let A := total xs (fun j => w j*(x j*x j))
    let B := total xs (fun j => w j*(z j*z j))
    let M := total xs (fun j => w j*x j*z j)
    have hterms : 0 ≤ total xs (fun j =>
        (w i*w j) * ((x i*z j-x j*z i)*(x i*z j-x j*z i))) := by
      apply total_nonneg xs (fun j =>
        (w i*w j) * ((x i*z j-x j*z i)*(x i*z j-x j*z i)))
      intro j hj
      exact Rat.mul_nonneg (Rat.mul_nonneg hwi (htail j hj))
        (square_nonneg _)
    have hterm_eq : total xs (fun j =>
        (w i*w j) * ((x i*z j-x j*z i)*(x i*z j-x j*z i))) =
        (w i*(x i*x i))*B + (w i*(z i*z i))*A -
          (2*w i*x i*z i)*M := by
      calc
        _ = total xs (fun j =>
            ((w i*(x i*x i))*(w j*(z j*z j)) +
             (w i*(z i*z i))*(w j*(x j*x j))) -
              (2*w i*x i*z i)*(w j*x j*z j)) := by
          apply total_congr xs
          intro j hj
          grind +ring
        _ = _ := by
          rw [total_sub, total_add, total_mul, total_mul, total_mul]
    change (w i*x i*z i + M)*(w i*x i*z i + M) ≤
      (w i*(x i*x i) + A)*(w i*(z i*z i) + B)
    have hidentity :
        (w i*(x i*x i) + A)*(w i*(z i*z i) + B) -
          (w i*x i*z i + M)*(w i*x i*z i + M) =
        (A*B-M*M) + total xs (fun j =>
          (w i*w j)*((x i*z j-x j*z i)*(x i*z j-x j*z i))) := by
      rw [hterm_eq]
      grind +ring
    have hgap : 0 ≤ A*B-M*M := by
      dsimp [A, B, M]
      grind
    grind

def teacher (xs : List I) (p v : I → Rat) : Rat :=
  total xs (fun i => p i*v i)

def meanRatio (xs : List I) (p r : I → Rat) : Rat :=
  total xs (fun i => p i*r i)

def candidate (xs : List I) (p r v : I → Rat) : Rat :=
  total xs (fun i => p i*r i*v i) / meanRatio xs p r

def weightedVariance (xs : List I) (p x : I → Rat) (μ : Rat) : Rat :=
  total xs (fun i => p i*((x i-μ)*(x i-μ)))

/-- Finite positive probabilities and positive ratios give an actual
    strictly positive normalizing denominator. -/
theorem meanRatio_pos (xs : List I) (p r : I → Rat)
    (hp : ∀ i ∈ xs, 0 < p i)
    (hr : ∀ i ∈ xs, 0 < r i)
    (hsum : total xs p = 1) : 0 < meanRatio xs p r := by
  have hne : xs ≠ [] := by
    intro hempty
    subst xs
    simp [total] at hsum
  unfold meanRatio
  apply total_pos xs (fun i => p i*r i) hne
  intro i hi
  exact Rat.mul_pos (hp i hi) (hr i hi)

/-- Exact cancellation of shared kernel-ratio scale. The only error is
    weighted ratio/value covariance about their respective teacher means. -/
theorem normalized_error_identity (xs : List I) (p r v : I → Rat)
    (hp : ∀ i ∈ xs, 0 < p i)
    (hr : ∀ i ∈ xs, 0 < r i)
    (hsum : total xs p = 1) :
    let y := teacher xs p v
    let rbar := meanRatio xs p r
    candidate xs p r v - y =
      total xs (fun i => p i*(r i-rbar)*(v i-y)) / rbar := by
  dsimp only
  let y := teacher xs p v
  let rbar := meanRatio xs p r
  let numerator := total xs (fun i => p i*r i*v i)
  let corr := total xs (fun i => p i*(r i-rbar)*(v i-y))
  have hcorr : corr = numerator - y*rbar := by
    calc
      _ = total xs (fun i =>
          (p i*r i*v i - y*(p i*r i)) -
            (rbar*(p i*v i) - (rbar*y)*p i)) := by
        apply total_congr xs
        intro i hi
        grind +ring
      _ = (numerator - y*rbar) - (rbar*y - (rbar*y)*total xs p) := by
        simp only [total_sub, total_mul]
        dsimp [numerator, y, rbar, teacher, meanRatio]
      _ = _ := by rw [hsum]; grind +ring
  have hpos : 0 < rbar := meanRatio_pos xs p r hp hr hsum
  have hn := Rat.div_mul_cancel (Rat.ne_of_gt hpos) (a := numerator)
  have hc := Rat.div_mul_cancel (Rat.ne_of_gt hpos) (a := corr)
  change numerator / rbar - y = corr / rbar
  apply Rat.le_antisymm
  · apply Rat.le_of_mul_le_mul_right (c := rbar) ?_ hpos
    grind +ring
  · apply Rat.le_of_mul_le_mul_right (c := rbar) ?_ hpos
    grind +ring

/-- Squared self-normalized output error is controlled by *centered* ratio
    variability times teacher value variability, not raw kernel variance. -/
theorem normalized_error_bound (xs : List I) (p r v : I → Rat)
    (hp : ∀ i ∈ xs, 0 < p i)
    (hr : ∀ i ∈ xs, 0 < r i)
    (hsum : total xs p = 1) :
    let y := teacher xs p v
    let rbar := meanRatio xs p r
    (candidate xs p r v - y)*(candidate xs p r v - y) ≤
      (weightedVariance xs p r rbar / (rbar*rbar)) *
        weightedVariance xs p v y := by
  dsimp only
  let y := teacher xs p v
  let rbar := meanRatio xs p r
  let corr := total xs (fun i => p i*(r i-rbar)*(v i-y))
  let A := weightedVariance xs p r rbar
  let B := weightedVariance xs p v y
  have hrpos : 0 < rbar := meanRatio_pos xs p r hp hr hsum
  have hr2 : 0 < rbar*rbar := Rat.mul_pos hrpos hrpos
  have hcauchy : corr*corr ≤ A*B := by
    dsimp [corr, A, B, weightedVariance]
    have h := weighted_cauchy xs p (fun i => r i-rbar)
      (fun i => v i-y) (by
        intro i hi
        exact Rat.le_of_lt (hp i hi))
    simpa only [Rat.mul_assoc] using h
  have hid := normalized_error_identity xs p r v hp hr hsum
  dsimp only at hid
  change candidate xs p r v - y = corr/rbar at hid
  rw [hid]
  have hdivcorr := Rat.div_mul_cancel (Rat.ne_of_gt hrpos) (a := corr)
  have hdivA := Rat.div_mul_cancel (Rat.ne_of_gt hr2) (a := A)
  apply Rat.le_of_mul_le_mul_right (c := rbar*rbar) ?_ hr2
  change (corr/rbar)*(corr/rbar)*(rbar*rbar) ≤
    (A/(rbar*rbar))*B*(rbar*rbar)
  have hleft : (corr/rbar)*(corr/rbar)*(rbar*rbar) = corr*corr := by
    calc
      _ = ((corr/rbar)*rbar)*((corr/rbar)*rbar) := by grind +ring
      _ = corr*corr := by rw [hdivcorr]
  have hright : (A/(rbar*rbar))*B*(rbar*rbar) = A*B := by
    calc
      _ = ((A/(rbar*rbar))*(rbar*rbar))*B := by grind +ring
      _ = A*B := by rw [hdivA]
  rw [hleft, hright]
  exact hcauchy

/-- Exact two-key formula: only relative kernel-ratio distortion and
    value separation matter. A common positive ratio contributes no error. -/
theorem two_key_error (p q r₀ r₁ v₀ v₁ : Rat)
    (hp : 0 < p) (hq : 0 < q) (hmass : p+q=1)
    (hr₀ : 0 < r₀) (hr₁ : 0 < r₁) :
    (p*r₀*v₀+q*r₁*v₁)/(p*r₀+q*r₁) - (p*v₀+q*v₁) =
      (p*q*(r₀-r₁)*(v₀-v₁))/(p*r₀+q*r₁) := by
  have hden : 0 < p*r₀+q*r₁ := by
    have h₀ := Rat.mul_pos hp hr₀
    have h₁ := Rat.mul_pos hq hr₁
    grind
  have hn := Rat.div_mul_cancel (Rat.ne_of_gt hden)
    (a := p*r₀*v₀+q*r₁*v₁)
  have hc := Rat.div_mul_cancel (Rat.ne_of_gt hden)
    (a := p*q*(r₀-r₁)*(v₀-v₁))
  have halgebra :
      (p*r₀*v₀+q*r₁*v₁) - (p*v₀+q*v₁)*(p*r₀+q*r₁) =
        p*q*(r₀-r₁)*(v₀-v₁) := by
    calc
      _ = (p+q)*(p*r₀*v₀+q*r₁*v₁) -
          (p*v₀+q*v₁)*(p*r₀+q*r₁) := by rw [hmass]; grind +ring
      _ = _ := by grind +ring
  have hcross :
      ((p*r₀*v₀+q*r₁*v₁)/(p*r₀+q*r₁) - (p*v₀+q*v₁)) *
          (p*r₀+q*r₁) =
        ((p*q*(r₀-r₁)*(v₀-v₁))/(p*r₀+q*r₁)) * (p*r₀+q*r₁) := by
    calc
      _ = (p*r₀*v₀+q*r₁*v₁) -
          (p*v₀+q*v₁)*(p*r₀+q*r₁) := by grind +ring
      _ = p*q*(r₀-r₁)*(v₀-v₁) := halgebra
      _ = _ := hc.symm
  apply Rat.le_antisymm
  · apply Rat.le_of_mul_le_mul_right (c := p*r₀+q*r₁) ?_ hden
    rw [hcross]
    grind
  · apply Rat.le_of_mul_le_mul_right (c := p*r₀+q*r₁) ?_ hden
    rw [hcross]
    grind

/-- A common positive multiplicative kernel ratio has exactly zero output
    error; it must not be charged as an independently noisy pair. -/
theorem constant_ratio_exact (xs : List I) (p v : I → Rat) (a : Rat)
    (hp : ∀ i ∈ xs, 0 < p i) (ha : 0 < a)
    (hsum : total xs p = 1) :
    candidate xs p (fun _ => a) v = teacher xs p v := by
  have hident := normalized_error_identity xs p (fun _ => a) v hp
    (by intro i hi; exact ha) hsum
  dsimp only at hident
  have hrbar : meanRatio xs p (fun _ => a) = a := by
    unfold meanRatio
    calc
      _ = total xs (fun i => a * p i) := by
        apply total_congr xs
        intro i hi
        exact Rat.mul_comm _ _
      _ = a * total xs p := total_mul _ _ _
      _ = a := by rw [hsum]; grind
  rw [hrbar] at hident
  have hzero : total xs (fun i => p i*(a-a)*(v i-teacher xs p v)) = 0 := by
    calc
      _ = total xs (fun _ => (0:Rat)) := by
        apply total_congr xs
        intro i hi
        grind +ring
      _ = 0 := total_zero xs
  rw [hzero] at hident
  have hz : (0:Rat)/a = 0 := by grind +ring
  rw [hz] at hident
  have heq : candidate xs p (fun _ => a) v - teacher xs p v = 0 := hident
  grind

end Kelana.NormalizedKernelError
