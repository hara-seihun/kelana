import Kelana.ValueCoordinateGauge

namespace Kelana.ValueRangeGauge

open ValueCoordinateGauge (total finite_gram_identity)

private theorem total_congr (xs : List I) (f g : I → Rat)
    (h : ∀ i ∈ xs, f i = g i) : total xs f = total xs g := by
  induction xs with
  | nil => rfl
  | cons i xs ih =>
    have hi := h i (by simp)
    have ht : ∀ j ∈ xs, f j = g j := by grind
    simpa only [total, List.map_cons, List.sum_cons, hi] using
      congrArg (fun z : Rat => f i + z) (ih ht)

private theorem total_mul (xs : List I) (a : Rat) (f : I → Rat) :
    total xs (fun i => a*f i) = a*total xs f := by
  induction xs with
  | nil => simp [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind +ring

private theorem total_add (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i+g i) = total xs f+total xs g := by
  induction xs with
  | nil => grind [total]
  | cons i xs ih =>
    simp only [total, List.map_cons, List.sum_cons] at ih ⊢
    grind

private theorem total_sub (xs : List I) (f g : I → Rat) :
    total xs (fun i => f i-g i) = total xs f-total xs g := by
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
    change 0 ≤ f i+total xs f
    grind [ih ht]

private theorem square_nonneg (x : Rat) : 0 ≤ x*x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

/-- A coordinate's unscaled worst-case rounding radius from group cap H,
    K levels-minus-one, and positive pre-quantization coordinate scale. -/
def radius (H K scale : Rat) : Rat := H/(K*scale)

def optimalRadius (M K : Rat) : Rat := M/K

/-- If the scaled calibration range fits the group cap, no coordinate can
    have a radius smaller than its individual ideal `M/K`. -/
theorem radius_lower (H K M scale : Rat)
    (hK : 0 < K) (_hM : 0 < M) (hscale : 0 < scale)
    (hfit : scale*M ≤ H) :
    optimalRadius M K ≤ radius H K scale := by
  have hden : 0 < K*scale := Rat.mul_pos hK hscale
  have hleft := Rat.div_mul_cancel (Rat.ne_of_gt hK) (a := M)
  have hright := Rat.div_mul_cancel (Rat.ne_of_gt hden) (a := H)
  unfold optimalRadius radius
  apply Rat.le_of_mul_le_mul_right (c := K*scale) ?_ hden
  have hcalc : (M/K)*(K*scale) = M*scale := by
    calc
      _ = ((M/K)*K)*scale := by grind +ring
      _ = _ := by rw [hleft]
  rw [hcalc, hright]
  simpa only [Rat.mul_comm] using hfit

/-- Every coordinate can attain its lower bound *simultaneously* by the
    rational equalizing scale H/M. This is a radius/box result, not a claim
    about min/max-code behavior or hardware-representable gamma. -/
theorem radius_attained (H K M : Rat)
    (hH : 0 < H) (hK : 0 < K) (hM : 0 < M) :
    0 < H/M ∧ (H/M)*M = H ∧
      radius H K (H/M) = optimalRadius M K := by
  have hscale : 0 < H/M :=
    (Rat.lt_div_iff hM).mpr (by simpa only [Rat.zero_mul] using hH)
  have hfit := Rat.div_mul_cancel (Rat.ne_of_gt hM) (a := H)
  have hden : 0 < K*(H/M) := Rat.mul_pos hK hscale
  have hleft := Rat.div_mul_cancel (Rat.ne_of_gt hK) (a := M)
  have hright := Rat.div_mul_cancel (Rat.ne_of_gt hden) (a := H)
  refine ⟨hscale, by simpa only [Rat.mul_comm] using hfit, ?_⟩
  unfold radius optimalRadius
  have hcalc : (M/K)*(K*(H/M)) = H := by
    calc
      _ = ((M/K)*K)*(H/M) := by grind +ring
      _ = M*(H/M) := by rw [hleft]
      _ = H := by simpa only [Rat.mul_comm] using hfit
  apply Rat.le_antisymm
  · apply Rat.le_of_mul_le_mul_right (c := K*(H/M)) ?_ hden
    rw [hright, hcalc]
    exact Rat.le_refl
  · apply Rat.le_of_mul_le_mul_right (c := K*(H/M)) ?_ hden
    rw [hright, hcalc]
    exact Rat.le_refl

/-- Symmetric coordinate error box; its definition does not presuppose
    pointwise numerical rounding or an operator-norm estimate. -/
def InBox (coords : List I) (r e : I → Rat) : Prop :=
  ∀ i ∈ coords, -r i ≤ e i ∧ e i ≤ r i

theorem box_subset (coords : List I) (r small e : I → Rat)
    (hsmall : ∀ i ∈ coords, small i ≤ r i)
    (he : InBox coords small e) : InBox coords r e := by
  intro i hi
  obtain ⟨hl, hr⟩ := he i hi
  have hs := hsmall i hi
  constructor <;> grind

/-- The individual optimum box lies in every fitted gauge's error box. -/
theorem optimal_box_contained (coords : List I)
    (H K : Rat) (M scale e : I → Rat)
    (hK : 0 < K)
    (hM : ∀ i ∈ coords, 0 < M i)
    (hscale : ∀ i ∈ coords, 0 < scale i)
    (hfit : ∀ i ∈ coords, scale i*M i ≤ H)
    (he : InBox coords (fun i => optimalRadius (M i) K) e) :
    InBox coords (fun i => radius H K (scale i)) e := by
  exact box_subset coords _ _ e (by
    intro i hi
    exact radius_lower H K (M i) (scale i) hK
      (hM i hi) (hscale i hi) (hfit i hi)) he

def response (coords : List I) (A : O → I → Rat)
    (e : I → Rat) (o : O) : Rat :=
  total coords (fun i => A o i*e i)

def squaredResponse (coords : List I) (outputs : List O)
    (A : O → I → Rat) (e : I → Rat) : Rat :=
  total outputs (fun o => response coords A e o*response coords A e o)

/-- Actual finite quadratic observer/Fubini identity, retaining all mixed
    coordinate terms rather than assuming a diagonal error model. -/
theorem squaredResponse_gram (coords : List I) (outputs : List O)
    (A : O → I → Rat) (e : I → Rat) :
    squaredResponse coords outputs A e =
      total coords (fun i => total coords (fun j =>
        (total outputs (fun o => A o i*A o j))*e i*e j)) := by
  exact finite_gram_identity coords outputs (fun i o => A o i) e

/-- Any observer bound over the optimum box transports to its subset; the
    assertion is about all errors, not just a sampled or realized error. -/
theorem observer_bound_on_subset (coords : List I) (outputs : List O)
    (A : O → I → Rat) (big small : I → Rat) (R : Rat)
    (hsmall : ∀ i ∈ coords, small i ≤ big i)
    (hbound : ∀ e, InBox coords big e →
      squaredResponse coords outputs A e ≤ R)
    (e : I → Rat) (he : InBox coords small e) :
    squaredResponse coords outputs A e ≤ R :=
  hbound e (box_subset coords big small e hsmall he)

/-- If an actual radius is at most twice the equalized radius, halving any
    admissible error puts it inside the optimum box. -/
theorem half_error_in_optimal_box (coords : List I)
    (M : I → Rat) (K : Rat) (r e : I → Rat)
    (hr : ∀ i ∈ coords, r i ≤ 2*optimalRadius (M i) K)
    (he : InBox coords r e) :
    InBox coords (fun i => optimalRadius (M i) K)
      (fun i => e i/2) := by
  intro i hi
  obtain ⟨hl, hu⟩ := he i hi
  have hri := hr i hi
  constructor
  · apply Rat.le_of_mul_le_mul_right (c := (2:Rat)) ?_ (by decide)
    have hd := Rat.div_mul_cancel (by decide : (2:Rat) ≠ 0) (a := e i)
    grind +ring
  · apply Rat.le_of_mul_le_mul_right (c := (2:Rat)) ?_ (by decide)
    have hd := Rat.div_mul_cancel (by decide : (2:Rat) ≠ 0) (a := e i)
    grind +ring

/-- Every output response scales *exactly* by two on doubling a finite
    rational error vector. -/
theorem response_double_half (coords : List I) (A : O → I → Rat)
    (e : I → Rat) (o : O) :
    response coords A e o = 2*response coords A (fun i => e i/2) o := by
  unfold response
  calc
    _ = total coords (fun i => 2*(A o i*(e i/2))) := by
      apply total_congr coords
      intro i hi
      have hd := Rat.div_mul_cancel (by decide : (2:Rat) ≠ 0) (a := e i)
      grind +ring
    _ = _ := total_mul coords 2 _

theorem squaredResponse_four_half (coords : List I) (outputs : List O)
    (A : O → I → Rat) (e : I → Rat) :
    squaredResponse coords outputs A e =
      4*squaredResponse coords outputs A (fun i => e i/2) := by
  unfold squaredResponse
  calc
    _ = total outputs (fun o =>
        4*(response coords A (fun i => e i/2) o*
           response coords A (fun i => e i/2) o)) := by
      apply total_congr outputs
      intro o ho
      rw [response_double_half]
      grind +ring
    _ = _ := total_mul outputs 4 _

/-- Fourfold robust-box comparison for *every* finite linear observer. It
    proves no actual quantizer's min/max behavior or empirical output error. -/
theorem two_radius_four_response_bound (coords : List I) (outputs : List O)
    (A : O → I → Rat) (M : I → Rat) (K : Rat)
    (r : I → Rat) (R : Rat)
    (hr : ∀ i ∈ coords, r i ≤ 2*optimalRadius (M i) K)
    (hbound : ∀ x,
      InBox coords (fun i => optimalRadius (M i) K) x →
      squaredResponse coords outputs A x ≤ R)
    (e : I → Rat) (he : InBox coords r e) :
    squaredResponse coords outputs A e ≤ 4*R := by
  rw [squaredResponse_four_half]
  have h := hbound (fun i => e i/2)
    (half_error_in_optimal_box coords M K r e hr he)
  exact Rat.mul_le_mul_of_nonneg_left h (by decide : (0:Rat) ≤ 4)

/-- A fixed K-error baseline can be included in the complete observer;
    it is not silently discarded when comparing robust boxes. -/
def affineSquaredResponse (coords : List I) (outputs : List O)
    (A : O → I → Rat) (baseline : O → Rat) (e : I → Rat) : Rat :=
  total outputs (fun o =>
    (baseline o+response coords A e o)*
      (baseline o+response coords A e o))

theorem affine_bound_on_subset (coords : List I) (outputs : List O)
    (A : O → I → Rat) (baseline : O → Rat)
    (big small : I → Rat) (R : Rat)
    (hsmall : ∀ i ∈ coords, small i ≤ big i)
    (hbound : ∀ e, InBox coords big e →
      affineSquaredResponse coords outputs A baseline e ≤ R)
    (e : I → Rat) (he : InBox coords small e) :
    affineSquaredResponse coords outputs A baseline e ≤ R :=
  hbound e (box_subset coords big small e hsmall he)

private theorem box_neg (coords : List I) (r x : I → Rat)
    (hx : InBox coords r x) :
    InBox coords r (fun i => -(x i)) := by
  intro i hi
  obtain ⟨hl, hu⟩ := hx i hi
  constructor <;> grind

private theorem response_neg (coords : List I) (A : O → I → Rat)
    (e : I → Rat) (o : O) :
    response coords A (fun i => -(e i)) o =
      -(response coords A e o) := by
  unfold response
  calc
    _ = total coords (fun i => -(A o i*e i)) := by
      apply total_congr coords
      intro i hi
      grind +ring
    _ = -(total coords (fun i => A o i*e i)) := by
      have h := total_mul coords (-1:Rat) (fun i => A o i*e i)
      grind +ring

/-- An exact finite-sum affine identity: the baseline costs three of four
    square terms and thus cannot worsen the factor-four robust comparison. -/
theorem affine_four_identity (coords : List I) (outputs : List O)
    (A : O → I → Rat) (baseline : O → Rat) (e : I → Rat) :
    affineSquaredResponse coords outputs A baseline e +
      3*total outputs (fun o => baseline o*baseline o) =
      3*affineSquaredResponse coords outputs A baseline (fun i => e i/2) +
        affineSquaredResponse coords outputs A baseline (fun i => -(e i/2)) := by
  unfold affineSquaredResponse
  rw [← total_mul, ← total_add, ← total_mul, ← total_add]
  apply total_congr outputs
  intro o ho
  have hscale := response_double_half coords A e o
  have hneg := response_neg coords A (fun i => e i/2) o
  rw [hscale, hneg]
  grind +ring

/-- For any fixed K-error baseline and any finite O-space observer, two
    symmetric optimum-box bounds imply the same fourfold rounded-box bound.
    This is the full affine robust-box result, still not an actual-code claim. -/
theorem two_radius_four_affine_bound (coords : List I) (outputs : List O)
    (A : O → I → Rat) (baseline : O → Rat)
    (M : I → Rat) (K : Rat) (r : I → Rat) (R : Rat)
    (hr : ∀ i ∈ coords, r i ≤ 2*optimalRadius (M i) K)
    (hbound : ∀ x,
      InBox coords (fun i => optimalRadius (M i) K) x →
      affineSquaredResponse coords outputs A baseline x ≤ R)
    (e : I → Rat) (he : InBox coords r e) :
    affineSquaredResponse coords outputs A baseline e ≤ 4*R := by
  have hz := half_error_in_optimal_box coords M K r e hr he
  have hp := hbound (fun i => e i/2) hz
  have hm := hbound (fun i => -(e i/2)) (box_neg coords _ _ hz)
  have hzero : 0 ≤ total outputs (fun o => baseline o*baseline o) := by
    apply total_nonneg outputs (fun o => baseline o*baseline o)
    intro o ho
    exact square_nonneg _
  have heq := affine_four_identity coords outputs A baseline e
  grind +ring

end Kelana.ValueRangeGauge
