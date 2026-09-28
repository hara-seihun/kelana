import Std

namespace Kelana.ReciprocalAttentionGauge

abbrev Pair := Rat × Rat

def scale (a : Rat) (v : Pair) : Pair := (a * v.1, a * v.2)
def hadamard (a v : Pair) : Pair := (a.1 * v.1, a.2 * v.2)
def rotate (cos sin : Rat) (v : Pair) : Pair :=
  (cos * v.1 - sin * v.2, sin * v.1 + cos * v.2)
def dot (u v : Pair) : Rat := u.1 * v.1 + u.2 * v.2

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

private theorem total_le (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i ≤ g i) : total xs f ≤ total xs g := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j ≤ g j := by grind
    change f i + total xs f ≤ g i + total xs g
    grind [ih ht]

/-- A scalar shared by both coordinates of a RoPE pair commutes with *any*
    linear pair rotation, without needing sine/cosine or unit-length facts. -/
theorem rotate_scale (cos sin a : Rat) (v : Pair) :
    rotate cos sin (scale a v) = scale a (rotate cos sin v) := by
  apply Prod.ext
  · simp only [rotate, scale]
    grind +ring
  · simp only [rotate, scale]
    grind +ring

theorem scale_hadamard (a : Rat) (γ v : Pair) :
    scale a (hadamard γ v) = hadamard (scale a γ) v := by
  apply Prod.ext
  · simp only [scale, hadamard]
    grind +ring
  · simp only [scale, hadamard]
    grind +ring

/-- Algebraic realization of moving pairwise scale through gamma, after RMS
    normalization and before RoPE. No dense norm metric is transported. -/
theorem gamma_fold (cos sin a : Rat) (γ v : Pair) :
    rotate cos sin (hadamard (scale a γ) v) =
      scale a (rotate cos sin (hadamard γ v)) := by
  rw [← scale_hadamard, rotate_scale]

private theorem dot_scale (a b : Rat) (u v : Pair) :
    dot (scale a u) (scale b v) = (a * b) * dot u v := by
  simp only [dot, scale]
  grind +ring

/-- Opposite per-pair gamma scales leave that pair's ideal attention score
    exactly unchanged, regardless of the RoPE phase and base Q/K vectors. -/
theorem pair_reciprocal_score (cosQ sinQ cosK sinK ell : Rat) (hell : ell ≠ 0)
    (γq γk q k : Pair) :
    dot (rotate cosQ sinQ (hadamard (scale ell γq) q))
        (rotate cosK sinK (hadamard (scale ell⁻¹ γk) k)) =
      dot (rotate cosQ sinQ (hadamard γq q))
        (rotate cosK sinK (hadamard γk k)) := by
  rw [gamma_fold, gamma_fold, dot_scale,
    Rat.mul_inv_cancel ell hell, Rat.one_mul]

/-- The same exact cancellation for an arbitrary number of RoPE pairs and
    pair-specific phases/scales, including shared GQA keys. -/
theorem all_pair_reciprocal_score {N : Nat}
    (cosQ sinQ cosK sinK ell : Fin N → Rat) (hell : ∀ j, ell j ≠ 0)
    (γq γk q k : Fin N → Pair) :
    total (List.finRange N) (fun j =>
      dot (rotate (cosQ j) (sinQ j)
          (hadamard (scale (ell j) (γq j)) (q j)))
        (rotate (cosK j) (sinK j)
          (hadamard (scale (ell j)⁻¹ (γk j)) (k j)))) =
      total (List.finRange N) (fun j =>
        dot (rotate (cosQ j) (sinQ j) (hadamard (γq j) (q j)))
          (rotate (cosK j) (sinK j) (hadamard (γk j) (k j)))) := by
  apply total_congr (List.finRange N)
  intro j hj
  exact pair_reciprocal_score (cosQ j) (sinQ j) (cosK j) (sinK j) (ell j) (hell j)
    (γq j) (γk j) (q j) (k j)

/-- Unit rotations also preserve the pair dot itself. This is separate from
    scalar commutation, which did not require this normalization premise. -/
theorem rotation_dot (cos sin : Rat) (hunit : cos * cos + sin * sin = 1)
    (u v : Pair) : dot (rotate cos sin u) (rotate cos sin v) = dot u v := by
  simp only [rotate, dot]
  grind +ring

private theorem square_nonneg (x : Rat) : 0 ≤ x * x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

/-- One pair's *positive* part of the shifted positive-feature exponent.
    This is not its full exponent: query/key cross covariance can be negative. -/
def pairCost (a b ell : Rat) : Rat := a * (ell * ell) + b / (ell * ell)

/-- If a rational `t>0` witnesses `b=a*t²`, the exact square residual proves
    the lower bound `2*a*t` at every positive scale. No square root of a
    general rational b/a is manufactured. -/
theorem pair_cost_square (a b t ell : Rat)
    (hell : 0 < ell) (hb : b = a * (t * t)) :
    pairCost a b ell =
      2 * a * t + a * ((ell - t / ell) * (ell - t / ell)) := by
  have hell0 := Rat.ne_of_gt hell
  have hell2 : 0 < ell * ell := Rat.mul_pos hell hell
  have hden := Rat.div_mul_cancel (Rat.ne_of_gt hell2) (a := b)
  have htd := Rat.div_mul_cancel hell0 (a := t)
  have hprod : pairCost a b ell * (ell * ell) =
      (2 * a * t + a * ((ell - t / ell) * (ell - t / ell))) * (ell * ell) := by
    unfold pairCost
    rw [hb] at hden ⊢
    grind +ring
  apply Rat.le_antisymm
  · apply Rat.le_of_mul_le_mul_right (c := ell * ell) ?_ hell2
    rw [hprod]
    grind
  · apply Rat.le_of_mul_le_mul_right (c := ell * ell) ?_ hell2
    rw [hprod]
    grind

theorem pair_cost_lower (a b t ell : Rat)
    (ha : 0 ≤ a) (hell : 0 < ell) (hb : b = a * (t * t)) :
    2 * a * t ≤ pairCost a b ell := by
  rw [pair_cost_square a b t ell hell hb]
  have hsq := square_nonneg (ell - t / ell)
  have hnonneg := Rat.mul_nonneg ha hsq
  grind

/-- When the minimizing scale has a rational witness `u` with `u²=t`, it
    attains the bound exactly. The real fourth-root statement is not claimed. -/
theorem witnessed_pair_optimum (a b t u : Rat)
    (hu : 0 < u) (ht : t = u * u) (hb : b = a * (t * t)) :
    pairCost a b u = 2 * a * t := by
  rw [pair_cost_square a b t u hu hb]
  have hdiv := Rat.mul_div_cancel (Rat.ne_of_gt hu) (a := u)
  rw [ht]
  have hsq : u - (u * u) / u = 0 := by rw [Rat.mul_div_cancel (Rat.ne_of_gt hu)]; grind
  rw [hsq]
  grind +ring

/-- If the squared scale is within a factor of two of its optimum, the
    dimensionless positive cost is at most 5/2 times the optimum term.
    The bound does NOT multiply a possibly cancellation-dominated total
    exponent/variance by 5/4. -/
theorem ratio_two_bound (r : Rat)
    (hlo : (1 / 2 : Rat) ≤ r) (hhi : r ≤ 2) :
    r + 1 / r ≤ 5 / 2 := by
  have hr : 0 < r := by grind
  have hl : 0 ≤ 2 * r - 1 := by grind +ring
  have hh : 0 ≤ 2 - r := by grind
  have hproduct : 0 ≤ (2 * r - 1) * (2 - r) := Rat.mul_nonneg hl hh
  have hinv := Rat.div_mul_cancel (Rat.ne_of_gt hr) (a := (1:Rat))
  apply Rat.le_of_mul_le_mul_right (c := 2*r) ?_ (Rat.mul_pos (by decide) hr)
  grind +ring

/-- Dimensionless cost `a*t*(r+1/r)` when `r=ell²/t` and `b=a*t²`.
    This theorem is algebraic; it does not assert a rounding algorithm. -/
theorem pair_cost_ratio (a b t ell r : Rat)
    (ht : 0 < t) (hell : 0 < ell)
    (hb : b = a * (t*t)) (hr : r = (ell*ell)/t) :
    pairCost a b ell = a * t * (r + 1/r) := by
  have hell2 : 0 < ell * ell := Rat.mul_pos hell hell
  have hrpos : 0 < r := by
    rw [hr]
    exact (Rat.lt_div_iff ht).mpr (by simpa only [Rat.zero_mul] using hell2)
  have hrr := Rat.div_mul_cancel (Rat.ne_of_gt ht) (a := ell*ell)
  have hinv := Rat.div_mul_cancel (Rat.ne_of_gt hrpos) (a := (1:Rat))
  have hdiv := Rat.div_mul_cancel (Rat.ne_of_gt hell2) (a := b)
  have hprod : pairCost a b ell * (ell*ell) * r * t =
      (a*t*(r+1/r)) * (ell*ell) * r * t := by
    unfold pairCost
    rw [hb] at hdiv ⊢
    grind +ring
  have hpositive : 0 < (ell*ell)*r*t :=
    Rat.mul_pos (Rat.mul_pos hell2 hrpos) ht
  apply Rat.le_antisymm
  · apply Rat.le_of_mul_le_mul_right (c := (ell*ell)*r*t) ?_ hpositive
    have heq : pairCost a b ell * ((ell*ell)*r*t) =
        (a*t*(r+1/r))*((ell*ell)*r*t) := by
      simpa only [Rat.mul_assoc] using hprod
    rw [heq]
    grind
  · apply Rat.le_of_mul_le_mul_right (c := (ell*ell)*r*t) ?_ hpositive
    have heq : pairCost a b ell * ((ell*ell)*r*t) =
        (a*t*(r+1/r))*((ell*ell)*r*t) := by
      simpa only [Rat.mul_assoc] using hprod
    rw [heq]
    grind

/-- Independent pair scales give a global additive lower bound on the
    positive part of the feature exponent. This statement does not include
    the invariant cross-covariance term. -/
theorem all_pair_cost_lower {N : Nat}
    (a b t ell : Fin N → Rat)
    (ha : ∀ j, 0 ≤ a j) (hell : ∀ j, 0 < ell j)
    (hb : ∀ j, b j = a j * (t j * t j)) :
    total (List.finRange N) (fun j => 2 * a j * t j) ≤
      total (List.finRange N) (fun j => pairCost (a j) (b j) (ell j)) := by
  apply total_le (List.finRange N)
  intro j hj
  exact pair_cost_lower (a j) (b j) (t j) (ell j)
    (ha j) (hell j) (hb j)

/-- At most 25% above the *positive pair term* `2*a*t`, conditional on
    squared-scale ratio `r` lying in `[1/2,2]`. No analogous multiplicative
    bound on the full exponent follows when cross covariance cancels it. -/
theorem pair_cost_factor_two (a b t ell r : Rat)
    (ha : 0 ≤ a) (ht : 0 < t) (hell : 0 < ell)
    (hb : b = a * (t*t)) (hr : r = (ell*ell)/t)
    (hlo : (1/2:Rat) ≤ r) (hhi : r ≤ 2) :
    pairCost a b ell ≤ (5/2:Rat) * a * t := by
  rw [pair_cost_ratio a b t ell r ht hell hb hr]
  have hnonneg : 0 ≤ a * t := Rat.mul_nonneg ha (Rat.le_of_lt ht)
  have hratio := ratio_two_bound r hlo hhi
  have hscaled := Rat.mul_le_mul_of_nonneg_left hratio hnonneg
  grind +ring

end Kelana.ReciprocalAttentionGauge
