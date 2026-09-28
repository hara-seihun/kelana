import Kelana.Halo

namespace Kelana.PeelLanes

def pack3 (a b c : Nat) : Nat := a + 1024 * b + 1048576 * c

def digits (m : Nat) : Nat :=
  (m / 256 % 4) + 1024 * (m / 262144 % 4) + 1048576 * (m / 268435456 % 4)

def remainders (m : Nat) : Nat :=
  m % 256 + 1024 * (m / 1024 % 256) + 1048576 * (m / 1048576 % 256)

theorem multiplication_fits_word (a b c : Nat) (ha : a < 256) (hb : b < 256) (hc : c < 256) :
    3 * pack3 a b c < 4294967296 := by
  unfold pack3
  omega

theorem three_peels (a b c : Nat) (ha : a < 256) (hb : b < 256) (hc : c < 256) :
    digits (3 * pack3 a b c) = pack3 (Halo.peel a).1 (Halo.peel b).1 (Halo.peel c).1 ∧
    remainders (3 * pack3 a b c) = pack3 (Halo.peel a).2 (Halo.peel b).2 (Halo.peel c).2 := by
  have h₀ : 3 * pack3 a b c / 256 = 3 * a / 256 + 12 * b + 12288 * c := by
    unfold pack3; omega
  have h₁ : 3 * pack3 a b c / 262144 = 3 * b / 256 + 12 * c := by
    unfold pack3; omega
  have h₂ : 3 * pack3 a b c / 268435456 = 3 * c / 256 := by
    unfold pack3; omega
  have h₃ : 3 * pack3 a b c / 1024 = 3 * b + 3072 * c := by
    unfold pack3; omega
  have h₄ : 3 * pack3 a b c / 1048576 = 3 * c := by
    unfold pack3; omega
  have ha' : 3 * a / 256 < 4 := by omega
  have hb' : 3 * b / 256 < 4 := by omega
  have hc' : 3 * c / 256 < 4 := by omega
  unfold digits remainders Halo.peel
  simp only [h₀, h₁, h₂, h₃, h₄]
  simp [pack3, Nat.add_mod, Nat.mul_mod, Nat.mod_eq_of_lt ha',
    Nat.mod_eq_of_lt hb', Nat.mod_eq_of_lt hc', Nat.mod_eq_of_lt ha]

def CarryIsolated (width : Nat) : Prop := 3 * 255 < 2 ^ width

theorem minimum_width : CarryIsolated 10 ∧ ∀ w, CarryIsolated w → 10 ≤ w := by
  constructor
  · unfold CarryIsolated; decide
  · intro w hw
    by_cases h : 10 ≤ w
    · exact h
    have hpow : 2 ^ w ≤ 2 ^ 9 := Nat.pow_le_pow_right (by decide) (by omega)
    unfold CarryIsolated at hw
    omega

/-- Three is the maximum number of complete, uniform, carry-isolated byte lanes
    in a 32-bit multiply-by-three word. This is not an all-ISA lower bound. -/
theorem maximum_lanes :
    CarryIsolated 10 ∧ 3 * 10 ≤ 32 ∧
      ∀ lanes width : Nat, CarryIsolated width → lanes * width ≤ 32 → lanes ≤ 3 := by
  refine ⟨minimum_width.1, by decide, ?_⟩
  intro lanes width hw hfit
  have hwidth := minimum_width.2 width hw
  have hmul : lanes * 10 ≤ lanes * width := Nat.mul_le_mul_left lanes hwidth
  omega

end Kelana.PeelLanes
