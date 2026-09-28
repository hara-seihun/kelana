import Std

namespace Kelana.PositiveKernelGauge

/-- All sums in this module are finite, exact rational sums. -/
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

private theorem total_comm (xs : List I) (ys : List J) (f : I → J → Rat) :
    total xs (fun i => total ys (f i)) =
      total ys (fun j => total xs (fun i => f i j)) := by
  induction xs with
  | nil =>
    simp only [total, List.map_nil, List.sum_nil]
    induction ys with
    | nil => rfl
    | cons j ys ih => simp only [List.map_cons, List.sum_cons]; grind
  | cons i xs ih =>
    change total ys (f i) + total xs (fun k => total ys (f k)) =
      total ys (fun j => f i j + total xs (fun k => f k j))
    rw [ih, total_add]

private theorem square_nonneg (x : Rat) : 0 ≤ x * x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

private theorem total_nonneg (xs : List I) (f : I → Rat)
    (h : ∀ i ∈ xs, 0 ≤ f i) : 0 ≤ total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, 0 ≤ f j := by grind
    change 0 ≤ f i + total xs f
    grind [ih ht]

/-- Exact key translation is a query-dependent row shift. Thus normalized
    exact softmax weights are unchanged, although feature-estimator variance
    need not be unchanged. -/
theorem key_translation_dot {D : Nat} (q k c : Fin D → Rat) :
    total (List.finRange D) (fun i => q i * (k i - c i)) =
      total (List.finRange D) (fun i => q i * k i) -
      total (List.finRange D) (fun i => q i * c i) := by
  calc
    _ = total (List.finRange D) (fun i => q i * k i - q i * c i) := by
      apply total_congr (List.finRange D)
      intro i hi
      grind +ring
    _ = _ := total_sub _ _ _

/-- Pairwise score differences, the directly observable row-gauge invariant. -/
theorem key_translation_difference {D : Nat} (q k₁ k₂ c : Fin D → Rat) :
    total (List.finRange D) (fun i => q i * (k₁ i - c i)) -
      total (List.finRange D) (fun i => q i * (k₂ i - c i)) =
    total (List.finRange D) (fun i => q i * k₁ i) -
      total (List.finRange D) (fun i => q i * k₂ i) := by
  rw [key_translation_dot, key_translation_dot]
  grind +ring

private theorem scalar_centroid_square (xs : List I) (w x : I → Rat)
    (hsum : total xs w = 1) (c : Rat) :
    let μ := total xs (fun i => w i * x i)
    total xs (fun i => w i * ((x i - c) * (x i - c))) =
      total xs (fun i => w i * ((x i - μ) * (x i - μ))) +
        (c - μ) * (c - μ) := by
  dsimp only
  let μ := total xs (fun i => w i * x i)
  have hcenter : total xs (fun i => w i * (x i - μ)) = 0 := by
    calc
      _ = total xs (fun i => w i * x i - μ * w i) := by
        apply total_congr xs
        intro i hi
        grind +ring
      _ = total xs (fun i => w i * x i) -
          total xs (fun i => μ * w i) := total_sub _ _ _
      _ = μ - μ * total xs w := by rw [total_mul]
      _ = 0 := by rw [hsum]; grind +ring
  calc
    _ = total xs (fun i =>
        w i * ((x i - μ) * (x i - μ)) +
        (2 * (μ - c)) * (w i * (x i - μ)) +
        ((c - μ) * (c - μ)) * w i) := by
      apply total_congr xs
      intro i hi
      grind +ring
    _ = total xs (fun i => w i * ((x i - μ) * (x i - μ))) +
        (2 * (μ - c)) * total xs (fun i => w i * (x i - μ)) +
        ((c - μ) * (c - μ)) * total xs w := by
      rw [total_add, total_add, total_mul, total_mul]
    _ = _ := by rw [hcenter, hsum]; grind +ring

/-- Squared Euclidean norm and the positive-pair weighted centroid of vectors
    `q+k` (or any supplied rational vectors `x`). -/
def squaredNorm {D : Nat} (x : Fin D → Rat) : Rat :=
  total (List.finRange D) (fun i => x i * x i)

def centroid {D : Nat} (samples : List (Rat × (Fin D → Rat))) : Fin D → Rat :=
  fun i => total samples (fun p => p.1 * p.2 i)

def meanSquaredDistance {D : Nat} (samples : List (Rat × (Fin D → Rat)))
    (c : Fin D → Rat) : Rat :=
  total samples (fun p => p.1 * squaredNorm (fun i => p.2 i - c i))

private theorem energy_by_coordinates {D : Nat}
    (samples : List (Rat × (Fin D → Rat))) (c : Fin D → Rat) :
    meanSquaredDistance samples c =
      total (List.finRange D) (fun i =>
        total samples (fun p =>
          p.1 * ((p.2 i - c i) * (p.2 i - c i)))) := by
  unfold meanSquaredDistance
  calc
    _ = total samples (fun p => total (List.finRange D) (fun i =>
        p.1 * ((p.2 i - c i) * (p.2 i - c i)))) := by
      apply total_congr samples
      intro p hp
      simp only [squaredNorm]
      exact (total_mul (List.finRange D) p.1
        (fun i => (p.2 i - c i) * (p.2 i - c i))).symm
    _ = _ := total_comm samples (List.finRange D) _

/-- Weighted centroid Pythagoras for *every* rational center and dimension.
    Positive pair weights are useful in the application, but the identity
    requires only that their sum is one; even signed weights obey the algebra. -/
theorem centroid_pythagoras {D : Nat}
    (samples : List (Rat × (Fin D → Rat)))
    (hsum : total samples (fun p => p.1) = 1)
    (c : Fin D → Rat) :
    meanSquaredDistance samples c =
      meanSquaredDistance samples (centroid samples) +
        squaredNorm (fun i => c i - centroid samples i) := by
  rw [energy_by_coordinates samples c,
    energy_by_coordinates samples (centroid samples)]
  unfold squaredNorm
  calc
    _ = total (List.finRange D) (fun i =>
        total samples (fun p =>
          p.1 * ((p.2 i - centroid samples i) *
            (p.2 i - centroid samples i))) +
        (c i - centroid samples i) * (c i - centroid samples i)) := by
      apply total_congr (List.finRange D)
      intro i hi
      exact scalar_centroid_square samples (fun p => p.1)
        (fun p => p.2 i) hsum (c i)
    _ = _ := total_add _ _ _

/-- Global attainment/minimality of the centroid; no premise that the
    desired final inequality is true is smuggled into the identity. -/
theorem centroid_minimizes {D : Nat}
    (samples : List (Rat × (Fin D → Rat)))
    (hsum : total samples (fun p => p.1) = 1)
    (c : Fin D → Rat) :
    meanSquaredDistance samples (centroid samples) ≤
      meanSquaredDistance samples c := by
  rw [centroid_pythagoras samples hsum c]
  have hnonneg : 0 ≤ squaredNorm (fun i => c i - centroid samples i) := by
    apply total_nonneg (List.finRange D)
      (fun i => (c i - centroid samples i) * (c i - centroid samples i))
    intro i hi
    exact square_nonneg _
  grind

end Kelana.PositiveKernelGauge
