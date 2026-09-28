import Std

/-!
Rational algebra at the live two-position value/output boundary. This module
checks the multiplicative transfer and the fixed-value active-mask theorem.
It does not claim to formalize real sigmoid/logit, real matrix rank or the
analytic arbitrary-dimension pole argument in the accompanying report.
-/
namespace Kelana.LiveValueTransfer

def observed (p current prior : Rat) : Rat := current + p * (prior - current)

/-- With unchanged current and prior values, a nonzero value gap makes the
binary probability identifiable from the live output. -/
theorem fixed_values_identify_probability (p q current prior : Rat)
    (gap : prior - current ≠ 0) :
    observed p current prior = observed q current prior ↔ p = q := by
  unfold observed
  constructor
  · intro h
    have product : (p - q) * (prior - current) = 0 := by
      grind +ring
    have hp := (Rat.mul_eq_zero.mp product)
    rcases hp with hleft | hright
    · grind
    · exact False.elim (gap hright)
  · intro h
    simp [h]

/-- The probability is unobservable precisely when the live value gap is
zero; this assertion also applies after a linear output projection. -/
theorem silent_gap (p q current : Rat) :
    observed p current current = observed q current current := by
  unfold observed
  grind +ring

/-- A genuinely changed key-value carrier can exactly absorb separable
probability variation, even when every value gap is nonzero. -/
theorem multiplicative_value_transfer (query key : Rat) :
    observed (query * key) 0 1 = observed query 0 key := by
  unfold observed
  grind +ring

/-- When the current output is a, all prior projected values have the same
fixed value b, and teacher probabilities factor as s(x)*t(y), a row-only
candidate with prior projected values a+t(y)*(b-a) is output-exact. -/
theorem affine_value_transfer (a b query key : Rat) :
    observed (query * key) a b =
      observed query a (a + key * (b-a)) := by
  unfold observed
  grind +ring

/-- For a row-only attention law, the current value cancels from every
prior-key difference, even if values are jointly changed from the teacher. -/
theorem row_key_difference (q current left right : Rat) :
    observed q current left - observed q current right = q * (left - right) := by
  unfold observed
  grind +ring

/-- Every centered 2×2 output minor of a rank-zero (query-only)
probability reader vanishes; the query values are arbitrary and the prior
values are arbitrary but shared across query labels. -/
theorem query_only_centered_minor (q₁ q₂ a₁ a₂ b₀ b₁ b₂ : Rat) :
    (observed q₁ a₁ b₁ - observed q₁ a₁ b₀) *
      (observed q₂ a₂ b₂ - observed q₂ a₂ b₀) =
    (observed q₁ a₁ b₂ - observed q₁ a₁ b₀) *
      (observed q₂ a₂ b₁ - observed q₂ a₂ b₀) := by
  rw [row_key_difference, row_key_difference, row_key_difference,
    row_key_difference]
  grind +ring

/-- Sum the live output of a fixed finite list of independently coded heads. -/
def headsObserved (heads : List H) (query : H → X → Rat)
    (current : H → X → Rat) (prior : H → Y → Rat) (x : X) (y : Y) : Rat :=
  (heads.map (fun h => observed (query h x) (current h x) (prior h y))).sum

/-- The same key-only difference carrier serves every query for each head,
regardless of jointly chosen current values. The output rows therefore lie
in the span of at most `heads.length` key-difference rows. -/
theorem heads_key_difference (heads : List H) (query : H → X → Rat)
    (current : H → X → Rat) (prior : H → Y → Rat)
    (x : X) (y z : Y) :
    headsObserved heads query current prior x y -
      headsObserved heads query current prior x z =
    (heads.map (fun h => query h x * (prior h y - prior h z))).sum := by
  induction heads with
  | nil => simp [headsObserved]; grind +ring
  | cons h hs ih =>
      simp only [headsObserved, List.map_cons, List.sum_cons]
      have hd := row_key_difference (query h x) (current h x) (prior h y) (prior h z)
      dsimp [headsObserved] at ih
      grind +ring

end Kelana.LiveValueTransfer
