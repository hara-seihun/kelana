import Kelana.Radix

namespace Kelana.Nibble

def low (x : Int) : Int := x % 16

def high (x : Int) : Int := x / 16

theorem split_byte (x : Int) (hx : SignedByte x) :
    0 ≤ low x ∧ low x ≤ 15 ∧ -8 ≤ high x ∧ high x ≤ 7 ∧ x = low x + 16 * high x := by
  unfold SignedByte at hx
  unfold low high
  omega

theorem dot_comm (n : Nat) (a b : Nat → Int) : dot n a b = dot n b a := by
  induction n with
  | zero => simp [dot]
  | succ n ih =>
    change dot n a b + a n * b n = dot n b a + b n * a n
    rw [ih, Int.mul_comm (a n)]

theorem dot_split (n : Nat) (a b : Nat → Int) :
    dot n a b = dot n a (fun k => low (b k)) + 16 * dot n a (fun k => high (b k)) := by
  have hb : b = fun k => pack 16 (low (b k)) (high (b k)) := by
    funext k
    unfold pack low high
    omega
  calc
    dot n a b = dot n (fun k => pack 16 (low (b k)) (high (b k))) a := by
      rw [dot_comm]
      exact congrArg (fun f => dot n f a) hb
    _ = dot n a (fun k => low (b k)) + 16 * dot n a (fun k => high (b k)) := by
      rw [dot_pack]
      unfold pack
      rw [dot_comm n (fun k => low (b k)), dot_comm n (fun k => high (b k))]

theorem two_iu4_mac (n : Nat) (a b : Nat → Int) (c : Int) :
    c + dot n a b =
      (c + dot n a (fun k => low (b k))) + 16 * dot n a (fun k => high (b k)) := by
  rw [dot_split]
  omega

/-- Arithmetic form of the byte-to-nibble gather's selected low byte. -/
theorem gather_two_trits (a b : Nat) (ha : a ≤ 2) (hb : b ≤ 2) :
    (17 * (a + 256 * b) / 16) % 256 = a + 16 * b := by
  have hq : 17 * (a + 256 * b) / 16 = a + 272 * b := by omega
  have hf : (a + 272 * b) / 256 = b := by omega
  rw [hq]
  omega

theorem gather_product_fits_u16 (a b : Nat) (ha : a ≤ 2) (hb : b ≤ 2) :
    17 * (a + 256 * b) < 65536 := by
  omega

end Kelana.Nibble
