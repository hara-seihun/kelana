import Kelana.SharedSketchCovariance

namespace Kelana.ValueRoundingRisk

open ValueCoordinateGauge (total)
open SharedSketchCovariance

/-- Two adjacent decoded levels, not ideal unrounded affine fields. -/
def upperProbability (lo hi x : Rat) : Rat := (x-lo)/(hi-lo)

theorem adjacent_probability_bounds (lo hi x : Rat)
    (hlt : lo < hi) (hx : lo ≤ x) (xh : x ≤ hi) :
    0 ≤ upperProbability lo hi x ∧ upperProbability lo hi x ≤ 1 := by
  have hd : 0 < hi-lo := by grind
  have hne : hi-lo ≠ 0 := by grind
  have hp : upperProbability lo hi x*(hi-lo) = x-lo := Rat.div_mul_cancel hne
  constructor
  · apply Rat.le_of_mul_le_mul_right (c := hi-lo) _ hd
    rw [Rat.zero_mul, hp]
    grind
  · apply Rat.le_of_mul_le_mul_right (c := hi-lo) _ hd
    rw [Rat.one_mul, hp]
    grind

theorem adjacent_mean (lo hi x : Rat) (hne : hi-lo ≠ 0) :
    (1-upperProbability lo hi x)*lo + upperProbability lo hi x*hi = x := by
  have h := Rat.div_mul_cancel (a := x-lo) hne
  unfold upperProbability
  grind +ring

theorem adjacent_variance (lo hi x : Rat) (hne : hi-lo ≠ 0) :
    (1-upperProbability lo hi x)*(lo-x)*(lo-x) +
      upperProbability lo hi x*(hi-x)*(hi-x) = (x-lo)*(hi-x) := by
  have h := Rat.div_mul_cancel (a := x-lo) hne
  unfold upperProbability
  grind +ring

/-- The variance gap against adjacent rounding is an actual finite expected
quadratic. It is not an assumed optimality property of a quantizer. -/
theorem grid_variance_gap (outcomes : List Ω) (mu Y : Ω → Rat)
    (lo hi x : Rat) (hmu : total outcomes mu = 1)
    (hmean : total outcomes (fun w => mu w*Y w) = x) :
    total outcomes (fun w => mu w*((Y w-x)*(Y w-x))) =
      (x-lo)*(hi-x) + total outcomes (fun w => mu w*((Y w-lo)*(Y w-hi))) := by
  have hpoint : total outcomes (fun w => mu w*((Y w-x)*(Y w-x))) =
      total outcomes (fun w => mu w*((Y w-lo)*(Y w-hi)) +
        (lo+hi-2*x)*(mu w*Y w) + (x*x-lo*hi)*mu w) := by
    apply total_congr outcomes
    intro w hw
    grind +ring
  rw [hpoint, total_add, total_add, total_mul, total_mul, hmu, hmean]
  grind +ring

/-- Any grid-supported law with mean x has at least the variance of the
adjacent interpolation. No grid point lies strictly between lo and hi. -/
theorem adjacent_minimum_variance (outcomes : List Ω) (mu Y : Ω → Rat)
    (lo hi x : Rat) (hlohi : lo ≤ hi) (hmu : total outcomes mu = 1)
    (hpos : ∀ w ∈ outcomes, 0 ≤ mu w)
    (hmean : total outcomes (fun w => mu w*Y w) = x)
    (hgrid : ∀ w ∈ outcomes, Y w ≤ lo ∨ hi ≤ Y w) :
    (x-lo)*(hi-x) ≤ total outcomes (fun w => mu w*((Y w-x)*(Y w-x))) := by
  rw [grid_variance_gap outcomes mu Y lo hi x hmu hmean]
  have hg : 0 ≤ total outcomes (fun w => mu w*((Y w-lo)*(Y w-hi))) := by
    apply total_nonneg outcomes
    intro w hw
    apply Rat.mul_nonneg (hpos w hw)
    rcases hgrid w hw with hl | hh
    · have ha : 0 ≤ lo-Y w := by grind
      have hb : 0 ≤ hi-Y w := by grind
      have h := Rat.mul_nonneg ha hb
      have he : (Y w-lo)*(Y w-hi) = (lo-Y w)*(hi-Y w) := by grind +ring
      rw [he]
      exact h
    · exact Rat.mul_nonneg (by grind) (by grind)
  grind

/-- The actual expected centered response vanishes by exchanging finite sums.
No independence between attention heads is used or wanted. -/
theorem mean_response_zero (outcomes : List Ω) (keys : List I)
    (mu : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat) (o : O)
    (hm : ∀ i ∈ keys, mean outcomes mu E i = 0) :
    total outcomes (fun w => mu w*response keys A E w o) = 0 := by
  unfold response
  rw [total_weighted_comm]
  calc
    _ = total keys (fun i => A o i*mean outcomes mu E i) := by
      apply total_congr keys
      intro i hi
      unfold mean
      have h := total_mul outcomes (A o i) (fun w => mu w*E w i)
      rw [← h]
      apply total_congr outcomes
      intro w hw
      grind +ring
    _ = total keys (fun _ => 0) := by
      apply total_congr keys
      intro i hi
      rw [hm i hi]
      grind
    _ = 0 := total_zero keys

/-- Deterministic bias includes source/K error and any endpoint clipping.
It does not disappear merely because the interior rounding law is unbiased. -/
def affineRisk (outcomes : List Ω) (keys : List I) (outputs : List O)
    (mu : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat) (b : O → Rat) : Rat :=
  total outcomes (fun w => mu w * total outputs (fun o =>
    (b o+response keys A E w o)*(b o+response keys A E w o)))

theorem affine_bias_variance (outcomes : List Ω) (keys : List I) (outputs : List O)
    (mu : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat) (b : O → Rat)
    (hmu : total outcomes mu = 1)
    (hm : ∀ i ∈ keys, mean outcomes mu E i = 0) :
    affineRisk outcomes keys outputs mu E A b =
      total outputs (fun o => b o*b o) + expectedSquared outcomes keys outputs mu E A := by
  unfold affineRisk expectedSquared
  rw [total_weighted_comm, total_weighted_comm]
  rw [← total_add]
  apply total_congr outputs
  intro o ho
  have hz := mean_response_zero outcomes keys mu E A o hm
  have hpoint : total outcomes (fun w =>
      mu w*((b o+response keys A E w o)*(b o+response keys A E w o))) =
      total outcomes (fun w => (b o*b o)*mu w +
        (2*b o)*(mu w*response keys A E w o) +
        mu w*(response keys A E w o*response keys A E w o)) := by
    apply total_congr outcomes
    intro w hw
    grind +ring
  rw [hpoint, total_add, total_add, total_mul, total_mul, hmu, hz]
  grind +ring

private theorem total_absent [DecidableEq I] (xs : List I) (i : I)
    (f : I → Rat) (hi : i ∉ xs) :
    total xs (fun j => if j = i then f j else 0) = 0 := by
  induction xs with
  | nil => rfl
  | cons j xs ih =>
    have hj : j ≠ i := by grind
    have ht : i ∉ xs := by grind
    change (if j = i then f j else 0) + total xs (fun k => if k = i then f k else 0) = 0
    rw [if_neg hj, ih ht]
    grind

theorem total_at [DecidableEq I] (xs : List I) (i : I)
    (f : I → Rat) (hn : xs.Nodup) (hi : i ∈ xs) :
    total xs (fun j => if j = i then f j else 0) = f i := by
  induction xs with
  | nil => simp at hi
  | cons j xs ih =>
    have hnodup : xs.Nodup := List.nodup_cons.mp hn |>.2
    have hjnot : j ∉ xs := List.nodup_cons.mp hn |>.1
    change (if j = i then f j else 0) + total xs (fun k => if k = i then f k else 0) = f i
    by_cases h : j = i
    · subst j
      rw [if_pos rfl, total_absent xs i f hjnot]
      grind
    · have ht : i ∈ xs := by grind
      rw [if_neg h, ih hnodup ht]
      grind

/-- Pairwise zero cross moments suffice. Product independence is a way to
supply this premise, not independence of the two readers of one shared KV. -/
theorem diagonal_expected_risk [DecidableEq I]
    (outcomes : List Ω) (keys : List I) (outputs : List O)
    (mu : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat) (b : O → Rat)
    (variance : I → Rat) (hn : keys.Nodup)
    (hmu : total outcomes mu = 1)
    (hm : ∀ i ∈ keys, mean outcomes mu E i = 0)
    (hcov : ∀ i ∈ keys, ∀ j ∈ keys,
      rawMoment outcomes mu E i j = if i = j then variance i else 0) :
    affineRisk outcomes keys outputs mu E A b =
      total outputs (fun o => b o*b o) +
        total keys (fun i => variance i*outputGram outputs A i i) := by
  rw [affine_bias_variance outcomes keys outputs mu E A b hmu hm,
    expectedSquared_eq_rawGram]
  congr 1
  apply total_congr keys
  intro i hi
  calc
    _ = total keys (fun j => if j = i then variance j*outputGram outputs A j j else 0) := by
      apply total_congr keys
      intro j hj
      rw [hcov i hi j hj]
      by_cases h : i = j
      · subst j
        grind +ring
      · have h' : j ≠ i := by grind
        rw [if_neg h, if_neg h']
        grind
    _ = variance i*outputGram outputs A i i := total_at keys i _ hn hi

/-- A coordinatewise variance lower bound pushes through the full observer.
For independent grid rounding, adjacent_minimum_variance supplies `hlo`.
This is a family bound, not a claim about correlated rounding programs. -/
theorem independent_grid_risk_lower [DecidableEq I]
    (outcomes : List Ω) (keys : List I) (outputs : List O)
    (mu : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat) (b : O → Rat)
    (variance lower : I → Rat) (hn : keys.Nodup)
    (hmu : total outcomes mu = 1)
    (hm : ∀ i ∈ keys, mean outcomes mu E i = 0)
    (hcov : ∀ i ∈ keys, ∀ j ∈ keys,
      rawMoment outcomes mu E i j = if i = j then variance i else 0)
    (hlo : ∀ i ∈ keys, lower i ≤ variance i) :
    total outputs (fun o => b o*b o) +
      total keys (fun i => lower i*outputGram outputs A i i) ≤
        affineRisk outcomes keys outputs mu E A b := by
  rw [diagonal_expected_risk outcomes keys outputs mu E A b variance hn hmu hm hcov]
  have hgram : ∀ i, 0 ≤ outputGram outputs A i i := by
    intro i
    exact total_nonneg outputs _ (fun o _ => square_nonneg (A o i))
  have hdelta : 0 ≤ total keys (fun i => (variance i-lower i)*outputGram outputs A i i) := by
    apply total_nonneg keys
    intro i hi
    exact Rat.mul_nonneg (by have h := hlo i hi; grind) (hgram i)
  have he : total keys (fun i => variance i*outputGram outputs A i i) =
      total keys (fun i => lower i*outputGram outputs A i i) +
      total keys (fun i => (variance i-lower i)*outputGram outputs A i i) := by
    rw [← total_add]
    apply total_congr keys
    intro i hi
    grind +ring
  rw [he]
  grind

/-- Independent binary centered errors have zero cross moment. These four
weights are the two-coordinate product marginal of the finite product law. -/
theorem bernoulli_cross_zero (p q x0 x1 y0 y1 : Rat)
    (hx : (1-p)*x0+p*x1 = 0) (_hy : (1-q)*y0+q*y1 = 0) :
    (1-p)*(1-q)*x0*y0 + (1-p)*q*x0*y1 +
      p*(1-q)*x1*y0 + p*q*x1*y1 = 0 := by
  grind +ring

/-- Two query heads sharing one V record must be summed before squaring. -/
theorem shared_head_coefficient (p q a b : Rat) :
    (p*a+q*b)*(p*a+q*b) = p*p*a*a+2*p*q*a*b+q*q*b*b := by
  grind +ring

end Kelana.ValueRoundingRisk
