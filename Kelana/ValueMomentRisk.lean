import Kelana.ValueErrorMoment

namespace Kelana.ValueMomentRisk

open ValueErrorFeedback (prefixSum prefixSum_congr)

private theorem congr_below (f g : Nat → Rat) (n : Nat)
    (h : ∀ i, i < n → f i = g i) : prefixSum f n = prefixSum g n := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [prefixSum]
    rw [ih (fun i hi => h i (by omega)), h n (by omega)]

private theorem add_sum (f g : Nat → Rat) (n : Nat) :
    prefixSum (fun i => f i+g i) n = prefixSum f n+prefixSum g n := by
  induction n with
  | zero => simp only [prefixSum]; grind +ring
  | succ n ih => simp only [prefixSum]; grind +ring

private theorem mul_sum (a : Rat) (f : Nat → Rat) (n : Nat) :
    prefixSum (fun i => a*f i) n = a*prefixSum f n := by
  induction n with
  | zero => simp [prefixSum]
  | succ n ih => simp only [prefixSum]; grind +ring

private theorem exchange (f : Nat → Nat → Rat) (m n : Nat) :
    prefixSum (fun i => prefixSum (f i) n) m =
      prefixSum (fun j => prefixSum (fun i => f i j) m) n := by
  induction m with
  | zero =>
    simp only [prefixSum]
    induction n with
    | zero => rfl
    | succ n ih => simp only [prefixSum]; grind +ring
  | succ m ih =>
    simp only [prefixSum]
    rw [ih, add_sum]

/-- Query coefficients need not be normalized or even nonnegative for the
finite identities. For attention they are actual probabilities of aged keys. -/
def mass (p : Nat → Nat → Rat) (n w : Nat) := prefixSum (p w) n

def response (p : Nat → Nat → Rat) (e : Nat → Rat) (n w : Nat) :=
  prefixSum (fun i => p w i*e i) n

def expectation (mu : Nat → Rat) (f : Nat → Rat) (q : Nat) :=
  prefixSum (fun w => mu w*f w) q

def risk (mu : Nat → Rat) (p : Nat → Nat → Rat) (e : Nat → Rat)
    (q n : Nat) := expectation mu (fun w => response p e n w*response p e n w) q

/-- Each row sum of the query second-moment matrix is E[P p_i]. -/
def massMoment (mu : Nat → Rat) (p : Nat → Nat → Rat) (q n i : Nat) :=
  expectation mu (fun w => mass p n w*p w i) q

theorem mass_response (mu : Nat → Rat) (p : Nat → Nat → Rat)
    (e : Nat → Rat) (q n : Nat) :
    expectation mu (fun w => mass p n w*response p e n w) q =
      prefixSum (fun i => massMoment mu p q n i*e i) n := by
  unfold massMoment
  unfold expectation response
  calc
    _ = prefixSum (fun w => prefixSum (fun i => mu w*mass p n w*p w i*e i) n) q := by
      apply prefixSum_congr
      intro w
      have hc : prefixSum (fun i => mu w*mass p n w*p w i*e i) n =
          prefixSum (fun i => (mu w*mass p n w)*(p w i*e i)) n := by
        apply prefixSum_congr; intro i; grind +ring
      rw [hc, mul_sum]
      grind +ring
    _ = prefixSum (fun i => prefixSum (fun w => mu w*mass p n w*p w i*e i) q) n := exchange _ _ _
    _ = _ := by
      apply prefixSum_congr
      intro i
      have hm := mul_sum (e i) (fun w => mu w*(mass p n w*p w i)) q
      have hc : prefixSum (fun w => mu w*mass p n w*p w i*e i) q =
          prefixSum (fun w => e i*(mu w*(mass p n w*p w i))) q := by
        apply prefixSum_congr; intro w; grind +ring
      rw [hc, hm]
      grind +ring

theorem centered_response (p : Nat → Nat → Rat) (e : Nat → Rat)
    (c : Rat) (n w : Nat) :
    response p (fun i => e i-c) n w = response p e n w-c*mass p n w := by
  induction n with
  | zero => simp only [response, mass, prefixSum]; grind +ring
  | succ n ih =>
    simp only [response, mass, prefixSum] at ih ⊢
    grind +ring

/-- Exact risk change, with the mean-removal coefficient fixed rather than
selected from query outcomes. This expansion does not presume improvement. -/
theorem risk_change (mu : Nat → Rat) (p : Nat → Nat → Rat)
    (e : Nat → Rat) (c : Rat) (q n : Nat) :
    risk mu p e q n - risk mu p (fun i => e i-c) q n =
      2*c*expectation mu (fun w => mass p n w*response p e n w) q -
      c*c*expectation mu (fun w => mass p n w*mass p n w) q := by
  induction q with
  | zero => simp [risk, expectation, prefixSum]
  | succ q ih =>
    simp only [risk, expectation, prefixSum] at ih ⊢
    rw [centered_response]
    grind +ring

/-- Balanced second-moment row sums suffice; full exchangeability, iid query
weights and diagonal covariance are unnecessary. `ncount` is the actual finite
key count expressed as a rational sum. -/
theorem balanced_mass_gain (mu : Nat → Rat) (p : Nat → Nat → Rat)
    (e : Nat → Rat) (c kappa : Rat) (q n : Nat)
    (balanced : ∀ i, i < n → massMoment mu p q n i = kappa)
    (center : prefixSum e n = prefixSum (fun _ => 1) n*c) :
    risk mu p e q n - risk mu p (fun i => e i-c) q n =
      c*c*expectation mu (fun w => mass p n w*mass p n w) q := by
  have hmean := mass_response mu p e q n
  have hc : prefixSum (fun i => massMoment mu p q n i*e i) n =
      kappa*prefixSum e n := by
    have he := congr_below _ _ n (fun i hi => congrArg (fun x : Rat => x*e i) (balanced i hi))
    rw [he, mul_sum]
  rw [hc, center] at hmean
  have hmass := mass_response mu p (fun _ => 1) q n
  have hr : ∀ w, response p (fun _ => 1) n w = mass p n w := by
    intro w
    unfold response mass
    apply prefixSum_congr; intro i; grind +ring
  simp only [hr] at hmass
  have hk : prefixSum (fun i => massMoment mu p q n i*1) n =
      kappa*prefixSum (fun _ => 1) n := by
    have he := congr_below _ _ n (fun i hi => congrArg (fun x : Rat => x*1) (balanced i hi))
    rw [he, mul_sum]
  rw [hk] at hmass
  rw [risk_change, hmean, hmass]
  grind +ring

private theorem square_nonneg (x : Rat) : 0 ≤ x*x := by
  rcases Rat.le_total (a := 0) (b := x) with h | h
  · exact Rat.mul_nonneg h h
  · have hn : 0 ≤ -x := by grind
    have hm := Rat.mul_nonneg hn hn
    simpa only [Rat.neg_mul, Rat.mul_neg, Rat.neg_neg] using hm

/-- Nonnegative outcome weights make the mass second moment nonnegative;
no normalization or independence assumption is used. -/
theorem mass_square_nonneg (mu : Nat → Rat) (p : Nat → Nat → Rat)
    (q n : Nat) (hmu : ∀ w, 0 ≤ mu w) :
    0 ≤ expectation mu (fun w => mass p n w*mass p n w) q := by
  induction q with
  | zero => simp [expectation, prefixSum]
  | succ q ih =>
    have h := Rat.mul_nonneg (hmu q) (square_nonneg (mass p n q))
    simp only [expectation, prefixSum] at ih ⊢
    grind

/-- The exact mean correction is a nonincreasing expected scalar error under
the balanced mass-moment law. For arbitrary selective laws this hypothesis
cannot be inferred from cache error means or residual stability. -/
theorem balanced_mass_nonincrease (mu : Nat → Rat) (p : Nat → Nat → Rat)
    (e : Nat → Rat) (c kappa : Rat) (q n : Nat)
    (hmu : ∀ w, 0 ≤ mu w)
    (balanced : ∀ i, i < n → massMoment mu p q n i = kappa)
    (center : prefixSum e n = prefixSum (fun _ => 1) n*c) :
    risk mu p (fun i => e i-c) q n ≤ risk mu p e q n := by
  have hid := balanced_mass_gain mu p e c kappa q n balanced center
  have hpos := Rat.mul_nonneg (square_nonneg c) (mass_square_nonneg mu p q n hmu)
  grind

end Kelana.ValueMomentRisk
