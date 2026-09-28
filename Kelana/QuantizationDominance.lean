import Std

namespace Kelana.QuantizationDominance

/-- A prefix has paid storage/execution cost and a consumer-visible state. -/
structure Prefix (S : Type) where
  state : S
  paid : Nat

/-- The cheaper prefix pays for every possible loss caused by changing state.
This is directed dominance, not approximate equality. -/
def Dominates {S : Type} (distance : S → S → Nat) (weight : Nat)
    (a b : Prefix S) : Prop :=
  a.paid + weight * distance a.state b.state ≤ b.paid

theorem reflexive {S : Type} (distance : S → S → Nat)
    (zero : ∀ s, distance s s = 0) (weight : Nat) (a : Prefix S) :
    Dominates distance weight a a := by
  simp [Dominates, zero]

theorem transitive {S : Type} (distance : S → S → Nat)
    (triangle : ∀ a b c, distance a c ≤ distance a b + distance b c)
    (weight : Nat) {a b c : Prefix S}
    (hab : Dominates distance weight a b)
    (hbc : Dominates distance weight b c) :
    Dominates distance weight a c := by
  have h := Nat.mul_le_mul_left weight (triangle a.state b.state c.state)
  rw [Nat.mul_add] at h
  unfold Dominates at *
  omega

/-- Only suffixes legal for both prefixes can use this rule. The hypothesis is
one-sided Lipschitz continuity of the COMPLETE remaining observed loss. -/
theorem suffix_dominance {S U : Type} (distance : S → S → Nat)
    (weight : Nat) (loss : S → U → Nat) (suffixCost : U → Nat)
    (stable : ∀ a b u, loss a u ≤ distance a b + loss b u)
    {a b : Prefix S} (h : Dominates distance weight a b) (u : U) :
    a.paid + suffixCost u + weight * loss a.state u ≤
      b.paid + suffixCost u + weight * loss b.state u := by
  have hl := Nat.mul_le_mul_left weight (stable a.state b.state u)
  rw [Nat.mul_add] at hl
  unfold Dominates at h
  omega

/-- A contracted simulation also supports suffixes with different numeric
states. State equality is sufficient, but not necessary, for safe pruning. -/
theorem same_state {S : Type} (distance : S → S → Nat)
    (zero : ∀ s, distance s s = 0) (weight : Nat) {a b : Prefix S}
    (hs : a.state = b.state) (hc : a.paid ≤ b.paid) :
    Dominates distance weight a b := by
  simpa [Dominates, hs, zero] using hc

def intDistance (a b : Int) : Nat := (a - b).natAbs

theorem intDistance_zero (a : Int) : intDistance a a = 0 := by
  simp [intDistance]

theorem intDistance_triangle (a b c : Int) :
    intDistance a c ≤ intDistance a b + intDistance b c := by
  have h := Int.natAbs_add_le (a - b) (b - c)
  have he : (a - b) + (b - c) = a - c := by omega
  simpa [intDistance, he] using h

theorem intDistance_translate (a b suffix : Int) :
    intDistance (a + suffix) (b + suffix) = intDistance a b := by
  unfold intDistance
  congr 1
  omega

theorem scalar_suffix_stable (target a b suffix : Int) :
    intDistance (a + suffix) target ≤
      intDistance a b + intDistance (b + suffix) target := by
  have h := intDistance_triangle (a + suffix) (b + suffix) target
  simpa [intDistance_translate] using h

/-- Sup distance over an explicit observation list. Observations can be full
finite-domain responses, calibration inputs, or any declared boundary. -/
def observedDistance {I : Type} (indices : List I) (a b : I → Int) : Nat :=
  match indices with
  | [] => 0
  | i :: rest => max (intDistance (a i) (b i)) (observedDistance rest a b)

theorem observedDistance_zero {I : Type} (indices : List I) (a : I → Int) :
    observedDistance indices a a = 0 := by
  induction indices with
  | nil => rfl
  | cons i rest ih => simp [observedDistance, intDistance_zero, ih]

theorem observedDistance_triangle {I : Type} (indices : List I)
    (a b c : I → Int) :
    observedDistance indices a c ≤
      observedDistance indices a b + observedDistance indices b c := by
  induction indices with
  | nil => simp [observedDistance]
  | cons i rest ih =>
    have h := intDistance_triangle (a i) (b i) (c i)
    simp only [observedDistance]
    omega

theorem observedDistance_translate {I : Type} (indices : List I)
    (a b suffix : I → Int) :
    observedDistance indices (fun i => a i + suffix i) (fun i => b i + suffix i) =
      observedDistance indices a b := by
  induction indices with
  | nil => rfl
  | cons i rest ih => simp [observedDistance, intDistance_translate, ih]

theorem vector_suffix_stable {I : Type} (indices : List I)
    (target a b suffix : I → Int) :
    observedDistance indices (fun i => a i + suffix i) target ≤
      observedDistance indices a b +
        observedDistance indices (fun i => b i + suffix i) target := by
  have h := observedDistance_triangle indices
    (fun i => a i + suffix i) (fun i => b i + suffix i) target
  simpa [observedDistance_translate] using h

/-- Paying the same transition charge preserves dominance when the response
transition is nonexpansive. This is the induction step for arbitrary schedules. -/
theorem transition_preserves {S : Type} (distance : S → S → Nat)
    (weight charge : Nat) (step : S → S)
    (nonexpansive : ∀ a b, distance (step a) (step b) ≤ distance a b)
    {a b : Prefix S} (h : Dominates distance weight a b) :
    Dominates distance weight ⟨step a.state, a.paid + charge⟩
      ⟨step b.state, b.paid + charge⟩ := by
  have hd := Nat.mul_le_mul_left weight (nonexpansive a.state b.state)
  unfold Dominates at *
  dsimp at *
  omega

/-- A finite set of prefixes may represent others without equal numeric states. -/
def Covers {S : Type} (distance : S → S → Nat) (weight : Nat)
    (kept original : List (Prefix S)) : Prop :=
  ∀ b ∈ original, ∃ a ∈ kept, Dominates distance weight a b

theorem covers_transitive {S : Type} (distance : S → S → Nat)
    (triangle : ∀ a b c, distance a c ≤ distance a b + distance b c)
    (weight : Nat) {a b c : List (Prefix S)}
    (hab : Covers distance weight a b) (hbc : Covers distance weight b c) :
    Covers distance weight a c := by
  intro z hz
  obtain ⟨y, hy, hyz⟩ := hbc z hz
  obtain ⟨x, hx, hxy⟩ := hab y hy
  exact ⟨x, hx, transitive distance triangle weight hxy hyz⟩

/-- A floor proved on the surviving prefixes transfers to every discarded
prefix and every common suffix, not just the calibration-optimal suffix. -/
theorem cover_transfers_lower {S U : Type} (distance : S → S → Nat)
    (weight : Nat) (loss : S → U → Nat) (suffixCost : U → Nat)
    (stable : ∀ a b u, loss a u ≤ distance a b + loss b u)
    {kept original : List (Prefix S)} (cover : Covers distance weight kept original)
    (lower : Nat)
    (floor : ∀ a ∈ kept, ∀ u, lower ≤ a.paid + suffixCost u + weight * loss a.state u) :
    ∀ b ∈ original, ∀ u, lower ≤ b.paid + suffixCost u + weight * loss b.state u := by
  intro b hb u
  obtain ⟨a, ha, hab⟩ := cover b hb
  exact Nat.le_trans (floor a ha u)
    (suffix_dominance distance weight loss suffixCost stable hab u)

/-- Exact output distinctions can differ and still be safely dominated. -/
theorem unequal_states_can_be_dominated :
    Dominates intDistance 3 ⟨0, 2⟩ ⟨1, 5⟩ := by
  unfold Dominates intDistance
  decide

/-- The usual same-cost tolerance merge is not licensed by this rule. -/
theorem closeness_alone_is_not_dominance :
    ¬ Dominates intDistance 3 ⟨0, 2⟩ ⟨1, 2⟩ := by
  unfold Dominates intDistance
  decide

def absInt (x : Int) : Int := max x (-x)

/-- For ordered scalar responses, the difference of absolute-error losses is
monotone in the common suffix. The remaining suffix set can have arbitrary holes. -/
theorem scalar_advantage_monotone (a b s u target : Int)
    (ordered : b ≤ a) (suffix_order : s ≤ u) :
    absInt (a+s-target) - absInt (b+s-target) ≤
      absInt (a+u-target) - absInt (b+u-target) := by
  unfold absInt
  omega

/-- Checking both attainable suffix extrema is sufficient for exact scalar
prefix dominance. Unlike metric slack, it can prune unequal states at equal cost. -/
theorem scalar_endpoints_dominate (a b costA costB price low high target : Int)
    (price_nonnegative : 0 ≤ price)
    (atLow : costA + price * absInt (a+low-target) ≤
      costB + price * absInt (b+low-target))
    (atHigh : costA + price * absInt (a+high-target) ≤
      costB + price * absInt (b+high-target)) :
    ∀ suffix, low ≤ suffix → suffix ≤ high →
      costA + price * absInt (a+suffix-target) ≤
        costB + price * absInt (b+suffix-target) := by
  intro suffix hlo hhi
  by_cases horder : b ≤ a
  · have h := scalar_advantage_monotone a b suffix high target horder hhi
    have hp := Int.mul_le_mul_of_nonneg_left h price_nonnegative
    simp only [Int.mul_sub] at hp
    omega
  · have horder' : a ≤ b := by omega
    have h := scalar_advantage_monotone b a low suffix target horder' hlo
    have hp := Int.mul_le_mul_of_nonneg_left h price_nonnegative
    simp only [Int.mul_sub] at hp
    omega

/-- If the suffix extrema are actually attainable, the two endpoint checks are
also necessary: this is the COMPLETE scalar dominance test for the suffix set. -/
theorem scalar_dominance_iff_endpoints (a b costA costB price low high target : Int)
    (allowed : Int → Prop) (price_nonnegative : 0 ≤ price)
    (low_allowed : allowed low) (high_allowed : allowed high)
    (bounded : ∀ s, allowed s → low ≤ s ∧ s ≤ high) :
    (∀ s, allowed s → costA + price * absInt (a+s-target) ≤
      costB + price * absInt (b+s-target)) ↔
    (costA + price * absInt (a+low-target) ≤ costB + price * absInt (b+low-target)) ∧
    (costA + price * absInt (a+high-target) ≤ costB + price * absInt (b+high-target)) := by
  constructor
  · intro h
    exact ⟨h low low_allowed, h high high_allowed⟩
  · rintro ⟨hl, hh⟩ s hs
    obtain ⟨hlo, hhi⟩ := bounded s hs
    exact scalar_endpoints_dominate a b costA costB price low high target
      price_nonnegative hl hh s hlo hhi

/-- The fixed continuation domain can prefer unequal states at equal cost. -/
theorem endpoint_rule_strictly_extends_metric :
    (∀ s : Int, 0 ≤ s → s ≤ 4 → 2 + absInt (1+s-10) ≤ 2 + absInt (0+s-10)) ∧
    ¬ Dominates intDistance 1 ⟨1, 2⟩ ⟨0, 2⟩ := by
  constructor
  · intro s hlo hhi
    unfold absInt
    omega
  · unfold Dominates intDistance
    decide

/-- An unbounded family where exact equality leaves n+1 response states,
while cost-funded dominance retains only the all-zero prefix. -/
theorem zero_dominates_count_family (n k : Nat) :
    Dominates intDistance 2 ⟨0, n⟩ ⟨(2 * k : Nat), n + 5 * k⟩ := by
  simp [Dominates, intDistance]
  omega

/-- Intervals admit the odd target, but every completion has even response. -/
theorem parity_family_floor (m k : Nat) :
    2 * m + 1 ≤ 2 * m + intDistance (2 * (k : Int)) (2 * (m : Int) + 1) := by
  have hn : 2 * (k : Int) - (2 * (m : Int) + 1) ≠ 0 := by omega
  have hp := Int.natAbs_pos.mpr hn
  unfold intDistance
  omega

theorem parity_family_attains (m : Nat) :
    2 * m + intDistance (2 * (m : Int)) (2 * (m : Int) + 1) = 2 * m + 1 := by
  have h : 2 * (m : Int) - (2 * (m : Int) + 1) = -1 := by omega
  simp [intDistance, h]

#print axioms suffix_dominance
#print axioms transitive
#print axioms vector_suffix_stable
#print axioms scalar_dominance_iff_endpoints
#print axioms endpoint_rule_strictly_extends_metric
end Kelana.QuantizationDominance
