import Kelana.ValueErrorFeedback

namespace Kelana.ValueErrorMoment

open ValueErrorFeedback (prefixSum)

/-- The decoded-minus-source error of unchanged codes is centered only at the
reader. The encoder accumulates its negative as a separate moment. -/
theorem centered_weights (p e : Nat → Rat) (a : Rat) (n : Nat) :
    prefixSum (fun i => p i * e i) n - a * prefixSum e n =
      prefixSum (fun i => (p i - a) * e i) n := by
  induction n with
  | zero => simp only [prefixSum]; grind +ring
  | succ n ih =>
    simp only [prefixSum]
    grind +ring

/-- Finite cumulative source-minus-decoded state, including update defects.
This is not feedback into a later code: `e` stays the independent-code error. -/
theorem accumulated_moment (e d s : Nat → Rat)
    (h0 : s 0 = 0) (step : ∀ i, s (i+1) = s i - e i + d i) (n : Nat) :
    s n = -prefixSum e n + prefixSum d n := by
  induction n with
  | zero => simp only [prefixSum]; grind +ring
  | succ n ih =>
    rw [step n, ih]
    simp only [prefixSum]
    grind +ring

/-- Reading the actual stored moment leaves a centered-weight error and
an explicit accumulated-defect term. Here `a` is the aged probability mass
per encoded token; keeping it a parameter also covers exact rational scaling. -/
theorem moment_reader (p e d s : Nat → Rat) (a : Rat)
    (h0 : s 0 = 0) (step : ∀ i, s (i+1) = s i - e i + d i) (n : Nat) :
    prefixSum (fun i => p i * e i) n + a * s n =
      prefixSum (fun i => (p i - a) * e i) n + a * prefixSum d n := by
  rw [accumulated_moment e d s h0 step n]
  have hc := centered_weights p e a n
  grind +ring

/-- For equal weights on the encoded subset the error is just the stored
moment's accumulated arithmetic defect. Recent exact values are not changed. -/
theorem uniform_reader (e d s : Nat → Rat) (a : Rat)
    (h0 : s 0 = 0) (step : ∀ i, s (i+1) = s i - e i + d i) (n : Nat) :
    prefixSum (fun i => a * e i) n + a * s n =
      a * prefixSum d n := by
  have hc := moment_reader (fun _ => a) e d s a h0 step n
  have hz : ∀ m, prefixSum (fun i => (a-a) * e i) m = 0 := by
    intro m
    induction m with
    | zero => rfl
    | succ m ih => simp only [prefixSum, ih]; grind +ring
  rw [hz] at hc
  grind +ring

/-- Removing a fixed center has the exact finite second-moment expansion. -/
theorem centered_energy (e : Nat → Rat) (c : Rat) (n : Nat) :
    prefixSum (fun i => (e i-c)*(e i-c)) n =
      prefixSum (fun i => e i*e i) n - 2*c*prefixSum e n +
      prefixSum (fun _ => 1) n*c*c := by
  induction n with
  | zero => simp only [prefixSum]; grind +ring
  | succ n ih => simp only [prefixSum]; grind +ring

/-- For the actual arithmetic mean, the removed unweighted energy is exactly
count times squared mean. Apply coordinatewise after any fixed linear O map;
this says nothing about the selective-query coefficients. -/
theorem mean_energy (e : Nat → Rat) (c : Rat) (n : Nat)
    (hmean : prefixSum e n = prefixSum (fun _ => 1) n*c) :
    prefixSum (fun i => (e i-c)*(e i-c)) n =
      prefixSum (fun i => e i*e i) n - prefixSum (fun _ => 1) n*c*c := by
  rw [centered_energy, hmean]
  grind +ring

/-- Error centering is not a pointwise guarantee for a selective observer,
even with strictly positive normalized weights and an exact moment. -/
theorem selective_reversal :
    let p : Nat → Rat := fun i => if i = 0 then 1/10 else 9/10
    let e : Nat → Rat := fun i => if i = 0 then 1 else 0
    prefixSum p 2 = 1 ∧
    prefixSum (fun i => p i * e i) 2 = 1/10 ∧
    prefixSum (fun i => p i * e i) 2 - (1/2) * prefixSum e 2 = -2/5 := by
  decide +kernel

end Kelana.ValueErrorMoment
