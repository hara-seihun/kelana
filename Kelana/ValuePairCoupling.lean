import Kelana.ValueRoundingRisk

namespace Kelana.ValuePairCoupling

/-- Joint upper/upper probability parametrizes every law with two given
Bernoulli marginals. The other weights are p-t, q-t and 1-p-q+t. -/
def legal (p q t : Rat) : Prop := 0 ≤ t ∧ t ≤ p ∧ t ≤ q ∧ p+q-1 ≤ t

def lower (p q : Rat) : Rat := max 0 (p+q-1)
def upper (p q : Rat) : Rat := min p q

theorem endpoints_legal (p q : Rat) (hp : 0 ≤ p ∧ p ≤ 1) (hq : 0 ≤ q ∧ q ≤ 1) :
    legal p q (lower p q) ∧ legal p q (upper p q) := by
  unfold legal lower upper
  grind

theorem independent_between (p q : Rat) (hp : 0 ≤ p ∧ p ≤ 1) (hq : 0 ≤ q ∧ q ≤ 1) :
    lower p q ≤ p*q ∧ p*q ≤ upper p q := by
  have h0 := Rat.mul_nonneg hp.1 hq.1
  have h1 := Rat.mul_nonneg (a := 1-p) (b := 1-q) (by grind) (by grind)
  have h2 := Rat.mul_nonneg (a := p) (b := 1-q) hp.1 (by grind)
  have h3 := Rat.mul_nonneg (a := q) (b := 1-p) hq.1 (by grind)
  unfold lower upper
  grind +ring

theorem independent_legal (p q : Rat) (hp : 0 ≤ p ∧ p ≤ 1) (hq : 0 ≤ q ∧ q ≤ 1) :
    legal p q (p*q) := by
  have h := independent_between p q hp hq
  unfold legal lower upper at *
  grind

def variance (p q t a b : Rat) : Rat :=
  (1-p-q+t)*(-a*p-b*q)*(-a*p-b*q) +
  (p-t)*(a*(1-p)-b*q)*(a*(1-p)-b*q) +
  (q-t)*(-a*p+b*(1-q))*(-a*p+b*(1-q)) +
  t*(a*(1-p)+b*(1-q))*(a*(1-p)+b*(1-q))

theorem joint_weights (p q t : Rat) (ht : legal p q t) :
    0 ≤ 1-p-q+t ∧ 0 ≤ p-t ∧ 0 ≤ q-t ∧ 0 ≤ t ∧
    (1-p-q+t)+(p-t)+(q-t)+t = 1 ∧ (p-t)+t = p ∧ (q-t)+t = q := by
  unfold legal at ht
  grind +ring

theorem exact_variance (p q t a b : Rat) :
    variance p q t a b = a*a*p*(1-p)+b*b*q*(1-q)+2*a*b*(t-p*q) := by
  unfold variance
  grind +ring

/-- Sign-selected endpoints are optimal over all joint laws with the same
marginals for this scalar pair response, not just better than independence. -/
theorem positive_pair_minimum (p q t a b : Rat)
    (ht : legal p q t) (hab : 0 ≤ a*b) :
    variance p q (lower p q) a b ≤ variance p q t a b := by
  have hlo : lower p q ≤ t := by unfold legal at ht; unfold lower; grind
  have h := Rat.mul_nonneg hab (b := t-lower p q) (by grind)
  rw [exact_variance, exact_variance]
  grind +ring

theorem negative_pair_minimum (p q t a b : Rat)
    (ht : legal p q t) (hab : a*b ≤ 0) :
    variance p q (upper p q) a b ≤ variance p q t a b := by
  have hhi : t ≤ upper p q := by unfold legal at ht; unfold upper; grind
  have h := Rat.mul_nonneg (a := -(a*b)) (b := upper p q-t) (by grind) (by grind)
  rw [exact_variance, exact_variance]
  grind +ring

/-- The shared-head column inner product is a binary quadratic on the
nonnegative attention cone, not simply a single-head Gram sign. -/
def quadratic (A B D u v : Rat) := A*u*u+B*u*v+D*v*v

def copositiveCertificate (A B D : Rat) : Prop :=
  0 ≤ A ∧ 0 ≤ D ∧ (0 ≤ B ∨ B*B ≤ 4*A*D)

theorem certificate_nonnegative (A B D u v : Rat)
    (h : copositiveCertificate A B D) (hu : 0 ≤ u) (hv : 0 ≤ v) :
    0 ≤ quadratic A B D u v := by
  obtain ⟨hA, hD, hB⟩ := h
  rcases hB with hB | hdisc
  · have h0 := Rat.mul_nonneg (Rat.mul_nonneg hA hu) hu
    have h1 := Rat.mul_nonneg (Rat.mul_nonneg hB hu) hv
    have h2 := Rat.mul_nonneg (Rat.mul_nonneg hD hv) hv
    unfold quadratic
    grind
  · by_cases ha : A = 0
    · subst A
      have hb0 := SharedSketchCovariance.square_nonneg B
      have hb2 : B*B = 0 := by grind +ring
      have hb : B = 0 := by
        rcases Rat.mul_eq_zero.mp hb2 with h | h <;> exact h
      subst B
      have h0 := Rat.mul_nonneg (Rat.mul_nonneg hD hv) hv
      unfold quadratic
      grind +ring
    · have hapos : 0 < A := by grind
      have hs := SharedSketchCovariance.square_nonneg (2*A*u+B*v)
      have hd := Rat.mul_nonneg (a := 4*A*D-B*B) (b := v*v)
        (by grind) (SharedSketchCovariance.square_nonneg v)
      have hid : 4*A*quadratic A B D u v =
          (2*A*u+B*v)*(2*A*u+B*v)+(4*A*D-B*B)*(v*v) := by
        unfold quadratic
        grind +ring
      have hc : 0 < 4*A := by grind
      apply Rat.le_of_mul_le_mul_left (c := 4*A) _ hc
      grind +ring

theorem certificate_nonpositive (A B D u v : Rat)
    (h : copositiveCertificate (-A) (-B) (-D)) (hu : 0 ≤ u) (hv : 0 ≤ v) :
    quadratic A B D u v ≤ 0 := by
  have hn := certificate_nonnegative (-A) (-B) (-D) u v h hu hv
  unfold quadratic at *
  grind +ring

/-- The rational certificate is also necessary: an adverse direction can be
chosen rationally, so no real square-root oracle or sampled query is needed. -/
theorem copositive_iff (A B D : Rat) :
    (∀ u v : Rat, 0 ≤ u → 0 ≤ v → 0 ≤ quadratic A B D u v) ↔
      copositiveCertificate A B D := by
  constructor
  · intro h
    have hA : 0 ≤ A := by have h0 := h 1 0 (by decide) (by decide); unfold quadratic at h0; grind +ring
    have hD : 0 ≤ D := by have h0 := h 0 1 (by decide) (by decide); unfold quadratic at h0; grind +ring
    refine ⟨hA, hD, ?_⟩
    by_cases hB : 0 ≤ B
    · exact Or.inl hB
    · right
      have hb : B < 0 := by grind
      by_cases ha : A = 0
      · subst A
        have hx := h (D+1) (-B) (by grind) (by grind)
        have hs := SharedSketchCovariance.square_nonneg B
        unfold quadratic at hx
        grind +ring
      · have hapos : 0 < A := by grind
        have hx := h (-B) (2*A) (by grind) (by grind)
        have hid : quadratic A B D (-B) (2*A) = A*(4*A*D-B*B) := by
          unfold quadratic
          grind +ring
        rw [hid] at hx
        have hc : A*0 ≤ A*(4*A*D-B*B) := by grind +ring
        have hp := Rat.le_of_mul_le_mul_left hc hapos
        grind
  · intro h u v hu hv
    exact certificate_nonnegative A B D u v h hu hv

open ValueCoordinateGauge (total)

def vectorVariance (outputs : List O) (p q t : Rat) (a b : O → Rat) : Rat :=
  total outputs (fun o => variance p q t (a o) (b o))

/-- Summing after both Q-head contributions gives the actual Gram cross
coefficient. The complete pair variance is affine in the coupling mass. -/
theorem vector_variance_difference (outputs : List O) (p q t s : Rat)
    (a b : O → Rat) :
    vectorVariance outputs p q t a b-vectorVariance outputs p q s a b =
      2*(t-s)*total outputs (fun o => a o*b o) := by
  induction outputs with
  | nil => simp [vectorVariance, total]; grind +ring
  | cons o outputs ih =>
    change variance p q t (a o) (b o)+vectorVariance outputs p q t a b -
      (variance p q s (a o) (b o)+vectorVariance outputs p q s a b) =
      2*(t-s)*(a o*b o+total outputs (fun o => a o*b o))
    rw [exact_variance, exact_variance]
    grind +ring

theorem vector_positive_minimum (outputs : List O) (p q t : Rat) (a b : O → Rat)
    (ht : legal p q t) (hab : 0 ≤ total outputs (fun o => a o*b o)) :
    vectorVariance outputs p q (lower p q) a b ≤ vectorVariance outputs p q t a b := by
  have hlo : lower p q ≤ t := by unfold legal at ht; unfold lower; grind
  have hp := Rat.mul_nonneg (a := t-lower p q) (b := total outputs (fun o => a o*b o))
    (by grind) hab
  have hd := vector_variance_difference outputs p q t (lower p q) a b
  grind +ring

theorem vector_negative_minimum (outputs : List O) (p q t : Rat) (a b : O → Rat)
    (ht : legal p q t) (hab : total outputs (fun o => a o*b o) ≤ 0) :
    vectorVariance outputs p q (upper p q) a b ≤ vectorVariance outputs p q t a b := by
  have hhi : t ≤ upper p q := by unfold legal at ht; unfold upper; grind
  have hp := Rat.mul_nonneg (a := upper p q-t) (b := -total outputs (fun o => a o*b o))
    (by grind) (by grind)
  have hd := vector_variance_difference outputs p q t (upper p q) a b
  grind +ring

/-- Exact extraction of the two-head source-column polynomial, within ONE
layer's O tensor. Layer indices are not Q-head indices. -/
theorem shared_head_gram (outputs : List O) (a0 a1 b0 b1 : O → Rat) (u v : Rat) :
    total outputs (fun o => (u*a0 o+v*a1 o)*(u*b0 o+v*b1 o)) =
      quadratic (total outputs (fun o => a0 o*b0 o))
        (total outputs (fun o => a0 o*b1 o+a1 o*b0 o))
        (total outputs (fun o => a1 o*b1 o)) u v := by
  induction outputs with
  | nil => simp [total, quadratic]; grind +ring
  | cons o outputs ih =>
    change (u*a0 o+v*a1 o)*(u*b0 o+v*b1 o) +
      total outputs (fun o => (u*a0 o+v*a1 o)*(u*b0 o+v*b1 o)) =
      quadratic (a0 o*b0 o+total outputs (fun o => a0 o*b0 o))
        (a0 o*b1 o+a1 o*b0 o+total outputs (fun o => a0 o*b1 o+a1 o*b0 o))
        (a1 o*b1 o+total outputs (fun o => a1 o*b1 o)) u v
    rw [ih]
    unfold quadratic
    grind +ring

end Kelana.ValuePairCoupling
