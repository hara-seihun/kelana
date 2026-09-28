import Kelana.NormalizedKernelError

namespace Kelana.JointCacheError

open NormalizedKernelError (total weighted_cauchy)

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

/-- Output values may already include any fixed linear output map. No
    assumption on softmax, quantization mechanism, or distribution is used. -/
def keyError (xs : List I) (p a v : I → Rat) : Rat :=
  total xs (fun i => (a i-p i)*v i)

def valueError (xs : List I) (p d : I → Rat) : Rat :=
  total xs (fun i => p i*d i)

def interaction (xs : List I) (p a d : I → Rat) : Rat :=
  total xs (fun i => (a i-p i)*d i)

def jointError (xs : List I) (p a v d : I → Rat) : Rat :=
  total xs (fun i => a i*(v i+d i)) - total xs (fun i => p i*v i)

/-- Exact joint K/V identity. The final interaction term is the value
    perturbation reweighted by the *changed* key probabilities. -/
theorem joint_error_decomposition (xs : List I) (p a v d : I → Rat) :
    jointError xs p a v d =
      keyError xs p a v + valueError xs p d + interaction xs p a d := by
  unfold jointError keyError valueError interaction
  calc
    _ = total xs (fun i => a i*v i + a i*d i) -
        total xs (fun i => p i*v i) := by
      congr 1
      apply total_congr xs
      intro i hi
      grind +ring
    _ = total xs (fun i => a i*v i - p i*v i) +
          total xs (fun i => p i*d i) +
          total xs (fun i => a i*d i - p i*d i) := by
      rw [total_add, total_sub, total_sub]
      grind +ring
    _ = _ := by
      have hK : total xs (fun i => a i*v i-p i*v i) =
          total xs (fun i => (a i-p i)*v i) := by
        apply total_congr xs; intro i hi; grind +ring
      have hX : total xs (fun i => a i*d i-p i*d i) =
          total xs (fun i => (a i-p i)*d i) := by
        apply total_congr xs; intro i hi; grind +ring
      rw [hK, hX]

/-- Joint squared output error is not the sum of separately measured K/V
    squared errors. Both the K–V and interaction cross terms are exact. -/
theorem joint_squared_error (xs : List I) (p a v d : I → Rat) :
    let EK := keyError xs p a v
    let EV := valueError xs p d
    let X := interaction xs p a d
    (jointError xs p a v d)*(jointError xs p a v d) =
      EK*EK + EV*EV + X*X + 2*EK*EV + 2*EK*X + 2*EV*X := by
  dsimp only
  rw [joint_error_decomposition]
  grind +ring

/-- The exact criterion for cancellation of all joint output error,
    regardless of the sizes of the separate K and V errors. -/
theorem joint_zero_iff (xs : List I) (p a v d : I → Rat) :
    jointError xs p a v d = 0 ↔
      keyError xs p a v + valueError xs p d + interaction xs p a d = 0 := by
  rw [joint_error_decomposition]

/-- Equal probability mass makes the interaction invariant under shifting
    all value changes by the same constant. -/
theorem interaction_centered (xs : List I) (p a d : I → Rat)
    (hp : total xs p = 1) (ha : total xs a = 1) (c : Rat) :
    total xs (fun i => (a i-p i)*(d i-c)) = interaction xs p a d := by
  have hzero : total xs (fun i => a i-p i) = 0 := by
    rw [total_sub, ha, hp]
    grind
  calc
    _ = total xs (fun i => (a i-p i)*d i - c*(a i-p i)) := by
      apply total_congr xs
      intro i hi
      grind +ring
    _ = total xs (fun i => (a i-p i)*d i) -
        c*total xs (fun i => a i-p i) := by
      rw [total_sub, total_mul]
    _ = interaction xs p a d := by
      rw [hzero]
      unfold interaction
      grind +ring

private theorem weighted_div_cancel (p u : Rat) (hp : 0 < p) :
    p*(u/p) = u := by
  rw [Rat.mul_comm]
  exact Rat.div_mul_cancel (Rat.ne_of_gt hp)

private theorem weighted_div_square (p u : Rat) (hp : 0 < p) :
    p*((u/p)*(u/p)) = (u*u)/p := by
  have hpinv : p*p⁻¹ = 1 := Rat.mul_inv_cancel p (Rat.ne_of_gt hp)
  change p*((u*p⁻¹)*(u*p⁻¹)) = (u*u)*p⁻¹
  grind +ring

/-- The K/V interaction is controlled by chi-square key-weight change
    times teacher-centered value-change variability. This is an exact
    rational weighted Cauchy consequence, not a softmax derivative bound. -/
theorem interaction_cauchy (xs : List I) (p a d : I → Rat)
    (hpPos : ∀ i ∈ xs, 0 < p i)
    (hp : total xs p = 1) (ha : total xs a = 1) :
    let mean := valueError xs p d
    (interaction xs p a d)*(interaction xs p a d) ≤
      (total xs (fun i => ((a i-p i)*(a i-p i))/p i)) *
      (total xs (fun i => p i*((d i-mean)*(d i-mean)))) := by
  dsimp only
  let mean := valueError xs p d
  have hbase := weighted_cauchy xs p
    (fun i => (a i-p i)/p i) (fun i => d i-mean)
    (by intro i hi; exact Rat.le_of_lt (hpPos i hi))
  have hleft : total xs (fun i =>
      p i*((a i-p i)/p i)*(d i-mean)) = interaction xs p a d := by
    calc
      _ = total xs (fun i => (a i-p i)*(d i-mean)) := by
        apply total_congr xs
        intro i hi
        have hc := weighted_div_cancel (p i) (a i-p i) (hpPos i hi)
        grind +ring
      _ = _ := interaction_centered xs p a d hp ha mean
  have hright : total xs (fun i =>
      p i*(((a i-p i)/p i)*((a i-p i)/p i))) =
      total xs (fun i => ((a i-p i)*(a i-p i))/p i) := by
    apply total_congr xs
    intro i hi
    exact weighted_div_square (p i) (a i-p i) (hpPos i hi)
  rw [hleft, hright] at hbase
  exact hbase

end Kelana.JointCacheError
