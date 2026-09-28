import Std

namespace Kelana.Halo

/-- Bonsai pack5's byte, with the five digits first interpreted as a base-3 rank. -/
def encode (q : Nat) : Nat := (256 * q + 242) / 243

def peel (p : Nat) : Nat × Nat := (3 * p / 256, 3 * p % 256)

def rank5 (p : Nat) : Nat :=
  let (t₀, p₁) := peel p
  let (t₁, p₂) := peel p₁
  let (t₂, p₃) := peel p₂
  let (t₃, p₄) := peel p₃
  let (t₄, _) := peel p₄
  81 * t₀ + 27 * t₁ + 9 * t₂ + 3 * t₃ + t₄

theorem encode_byte (q : Nat) (hq : q < 243) : encode q < 256 := by
  unfold encode
  omega

theorem recover_rank (q : Nat) : 243 * encode q / 256 = q := by
  unfold encode
  omega

theorem peel_trit (p : Nat) (hp : p < 256) : (peel p).1 < 3 ∧ (peel p).2 < 256 := by
  unfold peel
  simp only
  omega

theorem rank5_as_multiply (p : Nat) : rank5 p = 243 * p / 256 := by
  unfold rank5 peel
  simp only
  omega

theorem decode_encode (q : Nat) : rank5 (encode q) = q := by
  rw [rank5_as_multiply]
  exact recover_rank q

end Kelana.Halo
