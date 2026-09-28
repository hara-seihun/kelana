import Kelana.ValuePairCoupling

namespace Kelana.ValuePairEnvelope

open ValueCoordinateGauge (total total_append total_perm)
open SharedSketchCovariance (total_congr total_add total_mul total_nonneg)
open ValuePairCoupling (legal lower upper quadratic)

private theorem absolute_bounds (x : Rat) : -x.abs ≤ x ∧ x ≤ x.abs := by
  by_cases h : 0 ≤ x
  · rw [Rat.abs_of_nonneg h]; grind
  · rw [Rat.abs_of_nonpos (by grind)]; grind

/-- A finite box product bound, proved from ordered multiplication. -/
theorem product_lower (x y M N : Rat) (_hM : 0 ≤ M) (hN : 0 ≤ N)
    (hx : -M ≤ x ∧ x ≤ M) (hy : -N ≤ y ∧ y ≤ N) :
    -(M*N) ≤ x*y := by
  by_cases h : 0 ≤ x
  · have h1 := Rat.mul_le_mul_of_nonneg_left hy.1 h
    have h2 := Rat.mul_le_mul_of_nonneg_right hx.2 hN
    grind +ring
  · have hx' : 0 ≤ -x := by grind
    have h1 := Rat.mul_le_mul_of_nonneg_left hy.2 hx'
    have h2 := Rat.mul_le_mul_of_nonneg_right (a := -x) (b := M) (c := N) (by grind) hN
    grind +ring

/-- Every legal Bernoulli coupling's covariance lies in this symmetric
relaxation of its exact Frechet interval. -/
def radius (p q : Rat) := max (p*q-lower p q) (upper p q-p*q)

theorem covariance_bounds (p q t : Rat) (ht : legal p q t) :
    -radius p q ≤ t-p*q ∧ t-p*q ≤ radius p q := by
  unfold legal at ht
  unfold radius lower upper
  grind

theorem radius_nonneg (p q : Rat) (hp : 0 ≤ p ∧ p ≤ 1) (hq : 0 ≤ q ∧ q ≤ 1) :
    0 ≤ radius p q := by
  have h := ValuePairCoupling.independent_between p q hp hq
  unfold radius
  grind

/-- Bound either sign of the shared-head polynomial using positive masses.
The separate absolute coefficients deliberately relax sign cancellations. -/
theorem polynomial_bounds (A B D u v : Rat) (hu : 0 ≤ u) (hv : 0 ≤ v) :
    -(A.abs*u*u+B.abs*u*v+D.abs*v*v) ≤ quadratic A B D u v ∧
      quadratic A B D u v ≤ A.abs*u*u+B.abs*u*v+D.abs*v*v := by
  have hA := absolute_bounds A
  have hB := absolute_bounds B
  have hD := absolute_bounds D
  have huu := Rat.mul_nonneg hu hu
  have huv := Rat.mul_nonneg hu hv
  have hvv := Rat.mul_nonneg hv hv
  have a0 := Rat.mul_le_mul_of_nonneg_right hA.1 huu
  have a1 := Rat.mul_le_mul_of_nonneg_right hA.2 huu
  have b0 := Rat.mul_le_mul_of_nonneg_right hB.1 huv
  have b1 := Rat.mul_le_mul_of_nonneg_right hB.2 huv
  have d0 := Rat.mul_le_mul_of_nonneg_right hD.1 hvv
  have d1 := Rat.mul_le_mul_of_nonneg_right hD.2 hvv
  unfold quadratic
  grind +ring

/-- Upper bound for any pair's improvement over independent covariance.
`gap` is the product of the two nonnegative actual decoded widths. -/
theorem pair_gain_upper (p q t gap A B D u v : Rat)
    (hp : 0 ≤ p ∧ p ≤ 1) (hq : 0 ≤ q ∧ q ≤ 1)
    (ht : legal p q t) (hg : 0 ≤ gap) (hu : 0 ≤ u) (hv : 0 ≤ v) :
    -2*gap*(t-p*q)*quadratic A B D u v ≤
      2*gap*radius p q*(A.abs*u*u+B.abs*u*v+D.abs*v*v) := by
  have hn : 0 ≤ A.abs*u*u+B.abs*u*v+D.abs*v*v := by
    have ha := Rat.mul_nonneg (Rat.mul_nonneg (Rat.abs_nonneg (x := A)) hu) hu
    have hb := Rat.mul_nonneg (Rat.mul_nonneg (Rat.abs_nonneg (x := B)) hu) hv
    have hd := Rat.mul_nonneg (Rat.mul_nonneg (Rat.abs_nonneg (x := D)) hv) hv
    grind
  have hm := radius_nonneg p q hp hq
  have hprod := product_lower (t-p*q) (quadratic A B D u v)
    (radius p q) (A.abs*u*u+B.abs*u*v+D.abs*v*v) hm hn
    (covariance_bounds p q t ht) (polynomial_bounds A B D u v hu hv)
  have hscaled := Rat.mul_le_mul_of_nonneg_left hprod (c := 2*gap) (by grind)
  grind +ring

def endpoints : List (I × I) → List I
  | [] => []
  | (i,j)::edges => i::j::endpoints edges

theorem endpoint_sum (edges : List (I × I)) (M : I → Rat) :
    total (endpoints edges) M = total edges (fun e => M e.1+M e.2) := by
  induction edges with
  | nil => rfl
  | cons e edges ih =>
    rcases e with ⟨i,j⟩
    change M i+(M j+total (endpoints edges) M) = M i+M j+total edges (fun e => M e.1+M e.2)
    rw [ih]
    grind

/-- A partition into disjoint pairs and singletons counts each matched
vertex twice only through its two incident endpoint bounds, never through
all possible edges. The explicit permutation is the matching's cover. -/
theorem matching_benefit_bound (vertices : List I) (edges : List (I × I))
    (singletons : List I) (M : I → Rat) (benefit : I × I → Rat)
    (partition : vertices.Perm (endpoints edges ++ singletons))
    (hM : ∀ i ∈ singletons, 0 ≤ M i)
    (hedge : ∀ e ∈ edges, benefit e ≤ M e.1 ∧ benefit e ≤ M e.2) :
    2*total edges benefit ≤ total vertices M := by
  have hd : 0 ≤ total edges (fun e => M e.1+M e.2-2*benefit e) := by
    apply total_nonneg edges
    intro e he
    have h := hedge e he
    grind
  have heq : total edges (fun e => M e.1+M e.2-2*benefit e) +
      2*total edges benefit = total edges (fun e => M e.1+M e.2) := by
    rw [← total_mul, ← total_add]
    apply total_congr edges
    intro e he
    grind +ring
  have hs := total_nonneg singletons M hM
  rw [total_perm M partition, total_append, endpoint_sum]
  grind

/-- Row envelopes may be formed separately for the three nonnegative mass
monomials, admitting even a different oracle pairing for each query. -/
theorem separated_row_bound (a b d ma mb md u v : Rat)
    (ha : a ≤ ma) (hb : b ≤ mb) (hd : d ≤ md) (hu : 0 ≤ u) (hv : 0 ≤ v) :
    a*u*u+b*u*v+d*v*v ≤ ma*u*u+mb*u*v+md*v*v := by
  have h0 := Rat.mul_le_mul_of_nonneg_right ha (Rat.mul_nonneg hu hu)
  have h1 := Rat.mul_le_mul_of_nonneg_right hb (Rat.mul_nonneg hu hv)
  have h2 := Rat.mul_le_mul_of_nonneg_right hd (Rat.mul_nonneg hv hv)
  grind +ring

/-- The nonnegative-variance intersection sharpens a loose matching envelope.
The equality is the actual variance reduction, not a quality assumption. -/
theorem risk_floor (bias independent coupled benefitUpper : Rat)
    (hc : 0 ≤ coupled) (hb : independent-coupled ≤ benefitUpper) :
    bias+max 0 (independent-benefitUpper) ≤ bias+coupled := by
  grind

end Kelana.ValuePairEnvelope
