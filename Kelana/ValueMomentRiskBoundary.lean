import Kelana.ValueMomentRisk

namespace Kelana.ValueMomentRiskBoundary

open ValueErrorFeedback (prefixSum prefixSum_congr)
open ValueMomentRisk

private theorem sum_add (f g : Nat → Rat) (n : Nat) :
    prefixSum (fun k => f k + g k) n = prefixSum f n + prefixSum g n := by
  induction n with
  | zero => simp only [prefixSum]; grind +ring
  | succ n ih => simp only [prefixSum]; rw [ih]; grind +ring

private theorem sum_mul (a : Rat) (f : Nat → Rat) (n : Nat) :
    prefixSum (fun k => a * f k) n = a * prefixSum f n := by
  induction n with
  | zero => simp [prefixSum]
  | succ n ih => simp only [prefixSum]; rw [ih]; grind +ring

private theorem sum_outside (a : Nat → Rat) (n i : Nat) (hi : n ≤ i) :
    prefixSum (fun k => if k = i then a k else 0) n = 0 := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [prefixSum]
    have hn : n ≠ i := by omega
    simp only [hn, ↓reduceIte]
    rw [ih (by omega)]
    grind +ring

private theorem sum_spike (a : Nat → Rat) (n i : Nat) (hi : i < n) :
    prefixSum (fun k => if k = i then a k else 0) n = a i := by
  induction n with
  | zero => omega
  | succ n ih =>
    simp only [prefixSum]
    by_cases h : i = n
    · subst i
      rw [sum_outside a n n (Nat.le_refl n)]
      grind +ring
    · have hi' : i < n := by omega
      rw [ih hi']
      grind +ring

/-- A mean-one error whose only nonconstant coordinates are opposite spikes. -/
def witness (i j : Nat) (lambda : Rat) (k : Nat) : Rat :=
  1 + lambda * (if k = i then 1 else 0) - lambda * (if k = j then 1 else 0)

private theorem weighted_witness (a : Nat → Rat) (n i j : Nat)
    (hi : i < n) (hj : j < n) (lambda : Rat) :
    prefixSum (fun k => a k * witness i j lambda k) n =
      prefixSum a n + lambda * (a i - a j) := by
  have hpoint : ∀ k, a k * witness i j lambda k =
      a k + lambda * (if k = i then a k else 0) +
        (-lambda) * (if k = j then a k else 0) := by
    intro k; unfold witness; split <;> split <;> grind +ring
  calc
    _ = prefixSum (fun k => a k + lambda * (if k = i then a k else 0) +
        (-lambda) * (if k = j then a k else 0)) n := prefixSum_congr hpoint n
    _ = _ := by
      rw [sum_add, sum_add, sum_mul, sum_mul, sum_spike a n i hi,
        sum_spike a n j hj]
      grind +ring

/-- The witness has exact arithmetic mean one on the legal slots. -/
theorem witness_mean (n i j : Nat) (hi : i < n) (hj : j < n) (lambda : Rat) :
    prefixSum (witness i j lambda) n = prefixSum (fun _ => (1 : Rat)) n := by
  have h := weighted_witness (fun _ => (1 : Rat)) n i j hi hj lambda
  have hz : lambda * ((1 : Rat) - 1) = 0 := by grind +ring
  rw [hz] at h
  change prefixSum (fun k => witness i j lambda k) n = _
  grind +ring

/-- The finite query expectation sees precisely the difference of the two
mass-moment row sums, rather than just the cache-wide arithmetic mean. -/
theorem witness_mass_response (mu : Nat → Rat) (p : Nat → Nat → Rat)
    (q n i j : Nat) (hi : i < n) (hj : j < n) (lambda : Rat) :
    expectation mu (fun w => mass p n w * response p (witness i j lambda) n w) q =
      expectation mu (fun w => mass p n w * mass p n w) q +
        lambda * (massMoment mu p q n i - massMoment mu p q n j) := by
  rw [mass_response]
  have h := weighted_witness (massMoment mu p q n) n i j hi hj lambda
  rw [h]
  have hmass := mass_response mu p (fun _ => 1) q n
  have hr : ∀ w, response p (fun _ => 1) n w = mass p n w := by
    intro w
    unfold response mass
    apply prefixSum_congr
    intro k
    simp
  simp only [hr] at hmass
  have hc : prefixSum (fun k => massMoment mu p q n k * 1) n =
      prefixSum (massMoment mu p q n) n := by
    apply prefixSum_congr; intro k; simp
  rw [hc] at hmass
  rw [hmass]

/-- If two legal slots carry different query-mass moments, there is a rational
mean-one arbitrary error for which exact mean removal increases squared
response risk by exactly one. No quantizer-grid or source-realizability claim
is made about this error vector. -/
theorem unequal_mass_moment_worsens (mu : Nat → Rat) (p : Nat → Nat → Rat)
    (q n i j : Nat) (hi : i < n) (hj : j < n)
    (hne : massMoment mu p q n i ≠ massMoment mu p q n j) :
    ∃ e : Nat → Rat,
      prefixSum e n = prefixSum (fun _ => (1 : Rat)) n ∧
      risk mu p e q n - risk mu p (fun k => e k - 1) q n = -1 := by
  let A := expectation mu (fun w => mass p n w * mass p n w) q
  let d := massMoment mu p q n i - massMoment mu p q n j
  have hd : d ≠ 0 := by
    intro h
    apply hne
    dsimp [d] at h
    grind +ring
  let lambda : Rat := -(A + 1) / (2 * d)
  refine ⟨witness i j lambda, witness_mean n i j hi hj lambda, ?_⟩
  rw [risk_change, witness_mass_response mu p q n i j hi hj lambda]
  have htwo : (2 : Rat) * d ≠ 0 := by
    intro h
    have hz : d = 0 := by grind +ring
    exact hd hz
  have hcancel : lambda * (2 * d) = -(A + 1) := by
    dsimp [lambda]
    exact Rat.div_mul_cancel htwo
  dsimp [A, d] at *
  grind +ring

/-- For a nonempty finite prefix under nonnegative query weights, balanced
mass moments are exactly the condition for all-error mean-correction safety.
The quantifier is over arbitrary rational error vectors, not a source grid. -/
theorem universal_nonincrease_iff (mu : Nat → Rat) (p : Nat → Nat → Rat)
    (q n : Nat) (hn : 0 < n) (hmu : ∀ w, 0 ≤ mu w) :
    (∀ (e : Nat → Rat) (c : Rat),
      prefixSum e n = prefixSum (fun _ => 1) n*c →
      risk mu p (fun i => e i-c) q n ≤ risk mu p e q n) ↔
    (∃ kappa : Rat, ∀ i, i < n → massMoment mu p q n i = kappa) := by
  constructor
  · intro safe
    refine ⟨massMoment mu p q n 0, ?_⟩
    intro i hi
    by_cases h : massMoment mu p q n i = massMoment mu p q n 0
    · exact h
    · obtain ⟨e, he, hr⟩ := unequal_mass_moment_worsens mu p q n i 0 hi hn h
      have he' : prefixSum e n = prefixSum (fun _ => 1) n*(1 : Rat) := by
        simpa using he
      have hs := safe e 1 he'
      grind +ring
  · intro hb e c center
    obtain ⟨kappa, balanced⟩ := hb
    exact balanced_mass_nonincrease mu p e c kappa q n hmu balanced center

end Kelana.ValueMomentRiskBoundary
