import Kelana.ValueRoundingRisk
import Kelana.ValueErrorFeedback

namespace Kelana.ValueGroupRounding

open ValueErrorFeedback (prefixSum)
open ValueCoordinateGauge (total)
open SharedSketchCovariance

/-- The systematic common-threshold increment in original coordinate order. -/
def increment (f : Nat → Rat) (u : Rat) (i : Nat) : Rat :=
  ((prefixSum f (i+1)+u).floor : Rat) - ((prefixSum f i+u).floor : Rat)

/-- For a legal upper probability, a single threshold changes the floor by
zero or one. This holds pointwise, without a random-number assumption. -/
theorem increment_binary (f : Nat → Rat) (u : Rat) (i : Nat)
    (hlo : 0 ≤ f i) (hhi : f i ≤ 1) :
    increment f u i = 0 ∨ increment f u i = 1 := by
  have h0 : (prefixSum f i+u).floor ≤ (prefixSum f (i+1)+u).floor := by
    apply Rat.floor_monotone
    simp only [prefixSum]
    grind
  have h1 : (prefixSum f (i+1)+u).floor ≤ (prefixSum f i+u).floor+1 := by
    have h := Rat.floor_monotone (a := prefixSum f (i+1)+u) (b := prefixSum f i+u+1)
      (by simp only [prefixSum]; grind)
    rw [Rat.floor_add_one] at h
    exact h
  have h : (prefixSum f (i+1)+u).floor = (prefixSum f i+u).floor ∨
      (prefixSum f (i+1)+u).floor = (prefixSum f i+u).floor+1 := by omega
  rcases h with h | h
  · left; unfold increment; rw [h]; grind
  · right; unfold increment; rw [h, Rat.intCast_add]; grind

/-- Group count telescoping, rather than a chronology across future tokens. -/
theorem count_telescopes (f : Nat → Rat) (u : Rat) (n : Nat) :
    prefixSum (increment f u) n =
      ((prefixSum f n+u).floor : Rat) - (u.floor : Rat) := by
  induction n with
  | zero =>
    change 0 = ((0+u).floor : Rat)-(u.floor : Rat)
    rw [Rat.zero_add]
    grind
  | succ n ih =>
    change prefixSum (increment f u) n + increment f u n = _
    rw [ih]
    unfold increment
    grind +ring

private theorem unit_floor_zero (u : Rat) (hu : 0 ≤ u) (hu1 : u < 1) : u.floor = 0 := by
  have h0 : (0 : Int) ≤ u.floor := Rat.le_floor_iff.mpr (by simpa using hu)
  have h1 : u.floor < (1 : Int) := Rat.floor_lt_iff.mpr (by simpa using hu1)
  omega

/-- Any threshold in the unit interval balances the group indicator count to
strictly less than one. It does not balance an arbitrary O-weighted response. -/
theorem count_discrepancy (f : Nat → Rat) (u : Rat) (n : Nat)
    (hu : 0 ≤ u) (hu1 : u < 1) :
    -1 < prefixSum (increment f u) n-prefixSum f n ∧
      prefixSum (increment f u) n-prefixSum f n < 1 := by
  rw [count_telescopes, unit_floor_zero u hu hu1]
  have hlo := Rat.floor_le (prefixSum f n+u)
  have hhi := Rat.lt_floor_add_one (prefixSum f n+u)
  simp only [Rat.intCast_add] at hhi
  grind

/-- An integer sum of upper probabilities gives exact group-count balance.
Actual value-error balance additionally requires a common decoded gap. -/
theorem integer_count_exact (f : Nat → Rat) (u : Rat) (n : Nat) (k : Int)
    (hk : prefixSum f n = (k : Rat)) (hu : 0 ≤ u) (hu1 : u < 1) :
    prefixSum (increment f u) n = prefixSum f n := by
  rw [count_telescopes, hk, unit_floor_zero u hu hu1]
  have hc : (k : Rat)+u = u+(k : Rat) := by grind
  rw [hc, Rat.floor_add_intCast, unit_floor_zero u hu hu1]
  simp only [Int.zero_add]
  grind

/-- Arbitrary within-record coupling retains the entire covariance Gram.
Only the diagonal can be reused from the independent-rounding risk law. -/
theorem coupled_risk (outcomes : List Ω) (keys : List I) (outputs : List O)
    (mu : Ω → Rat) (E : Ω → I → Rat) (A : O → I → Rat) (b : O → Rat)
    (hmu : total outcomes mu = 1)
    (hm : ∀ i ∈ keys, mean outcomes mu E i = 0) :
    ValueRoundingRisk.affineRisk outcomes keys outputs mu E A b =
      total outputs (fun o => b o*b o) +
      total keys (fun i => total keys (fun j =>
        outputGram outputs A i j*rawMoment outcomes mu E i j)) := by
  rw [ValueRoundingRisk.affine_bias_variance outcomes keys outputs mu E A b hmu hm,
    expectedSquared_eq_rawGram]

/-- For two half-probability coordinates, systematic rounding is antithetic:
one is high and one low. Its response variance may exceed the independent
variance even though its unweighted group error is exactly zero. -/
theorem two_coordinate_variance (a b : Rat) :
    ((a/2-b/2)*(a/2-b/2) + (-a/2+b/2)*(-a/2+b/2))/2 =
      (a-b)*(a-b)/4 := by grind +ring

theorem two_coordinate_gain (a b : Rat) :
    (a*a+b*b)/4 - (a-b)*(a-b)/4 = a*b/2 := by grind +ring

theorem opposite_observer_worsens :
    ((1 : Rat)-(-1))*((1 : Rat)-(-1))/4 = 1 ∧
    ((1 : Rat)*1+(-1)*(-1))/4 = 1/2 := by grind +ring

end Kelana.ValueGroupRounding
