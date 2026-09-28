import Std

namespace Kelana

def Trit (x : Int) : Prop := -1 ≤ x ∧ x ≤ 1

def SignedByte (x : Int) : Prop := -128 ≤ x ∧ x ≤ 127

def DotResult (x : Int) : Prop := -16 ≤ x ∧ x ≤ 16

def pack (r x y : Int) : Int := x + r * y

def low33 (z : Int) : Int := (z + 16) % 33 - 16

def high33 (z : Int) : Int := (z + 16) / 33

theorem decode33 (x y : Int) (hx : DotResult x) :
    low33 (pack 33 x y) = x ∧ high33 (pack 33 x y) = y := by
  unfold DotResult at hx
  unfold low33 high33 pack
  omega

theorem injective33 (x y x' y' : Int)
    (hx : DotResult x) (hx' : DotResult x')
    (h : pack 33 x y = pack 33 x' y') : x = x' ∧ y = y' := by
  have h₁ := decode33 x y hx
  have h₂ := decode33 x' y' hx'
  rw [h] at h₁
  omega

def low64 (z : Int) : Int := (z + 32) % 64 - 32

def high64 (z : Int) : Int := (z + 32) / 64

theorem decode64 (x y : Int) (hx : DotResult x) :
    low64 (pack 64 x y) = x ∧ high64 (pack 64 x y) = y := by
  unfold DotResult at hx
  unfold low64 high64 pack
  omega

theorem packed_trits64_fit_byte (a b : Int) (ha : Trit a) (hb : Trit b) :
    SignedByte (pack 64 a b) := by
  unfold Trit at *
  unfold SignedByte pack
  omega

theorem packed_trits_fit_byte (a b : Int) (ha : Trit a) (hb : Trit b) :
    SignedByte (pack 33 a b) := by
  unfold Trit at *
  unfold SignedByte pack
  omega

def dot : Nat → (Nat → Int) → (Nat → Int) → Int
  | 0, _, _ => 0
  | n + 1, a, b => dot n a b + a n * b n

theorem dot_pack (n : Nat) (r : Int) (a a' b : Nat → Int) :
    dot n (fun k => pack r (a k) (a' k)) b =
      pack r (dot n a b) (dot n a' b) := by
  induction n with
  | zero => simp [dot, pack]
  | succ n ih =>
    change dot n (fun k => pack r (a k) (a' k)) b + pack r (a n) (a' n) * b n =
      pack r (dot n a b + a n * b n) (dot n a' b + a' n * b n)
    rw [ih]
    simp only [pack, Int.add_mul, Int.mul_add, Int.mul_assoc]
    omega

theorem trit_product_bound (a b : Int) (ha : Trit a) (hb : Trit b) :
    -1 ≤ a * b ∧ a * b ≤ 1 := by
  have ha' : a = -1 ∨ a = 0 ∨ a = 1 := by unfold Trit at ha; omega
  rcases ha' with h | h | h <;> subst a <;> simp_all [Trit] <;> omega

theorem dot_bound (n : Nat) (a b : Nat → Int)
    (h : ∀ k, k < n → -1 ≤ a k * b k ∧ a k * b k ≤ 1) :
    -(n : Int) ≤ dot n a b ∧ dot n a b ≤ (n : Int) := by
  induction n with
  | zero => simp [dot]
  | succ n ih =>
    have hn := h n (by omega)
    have hp := ih (fun k hk => h k (by omega))
    simp only [dot]
    omega

theorem ternary_dot16_bound (a b : Nat → Int)
    (ha : ∀ k, k < 16 → Trit (a k)) (hb : ∀ k, k < 16 → Trit (b k)) :
    DotResult (dot 16 a b) := by
  exact dot_bound 16 a b (fun k hk => trit_product_bound (a k) (b k) (ha k hk) (hb k hk))

def prefixOnes (m k : Nat) : Int := if k < m then 1 else 0

theorem dot_prefix (n m : Nat) :
    dot n (prefixOnes m) (fun _ => 1) = (min n m : Nat) := by
  induction n with
  | zero => simp [dot]
  | succ n ih =>
    simp only [dot, ih, prefixOnes, Int.mul_one]
    split <;> omega

theorem dot_neg (n : Nat) (a b : Nat → Int) :
    dot n (fun k => -(a k)) b = -(dot n a b) := by
  induction n with
  | zero => simp [dot]
  | succ n ih =>
    change dot n (fun k => -(a k)) b + -(a n) * b n = -(dot n a b + a n * b n)
    rw [ih]
    simp [Int.neg_mul, Int.neg_add]

theorem every_dot_result_reachable (x : Int) (hx : DotResult x) :
    ∃ a : Nat → Int, (∀ k, Trit (a k)) ∧ dot 16 a (fun _ => 1) = x := by
  unfold DotResult at hx
  by_cases h : 0 ≤ x
  · refine ⟨prefixOnes x.toNat, ?_, ?_⟩
    · intro k; unfold prefixOnes; split <;> constructor <;> omega
    · rw [dot_prefix]; omega
  · refine ⟨fun k => -(prefixOnes (-x).toNat k), ?_, ?_⟩
    · intro k; by_cases hk : k < (-x).toNat <;> simp [prefixOnes, hk, Trit]
    · rw [dot_neg, dot_prefix]; omega

theorem two_ternary_dots_one_packed_dot (a a' b : Nat → Int)
    (ha : ∀ k, k < 16 → Trit (a k)) (hb : ∀ k, k < 16 → Trit (b k)) :
    let z := dot 16 (fun k => pack 33 (a k) (a' k)) b
    low33 z = dot 16 a b ∧ high33 z = dot 16 a' b := by
  dsimp
  rw [dot_pack]
  exact decode33 _ _ (ternary_dot16_bound a b ha hb)

/-- Six-bit signed extraction implements low64; high64 is add-32 then arithmetic shift. -/
theorem low64_signed_extract (z : Int) :
    low64 z = if z % 64 < 32 then z % 64 else z % 64 - 64 := by
  unfold low64
  split <;> omega

theorem two_ternary_dots_radix64 (a a' b : Nat → Int)
    (ha : ∀ k, k < 16 → Trit (a k)) (hb : ∀ k, k < 16 → Trit (b k)) :
    let z := dot 16 (fun k => pack 64 (a k) (a' k)) b
    low64 z = dot 16 a b ∧ high64 z = dot 16 a' b := by
  dsimp
  rw [dot_pack]
  exact decode64 _ _ (ternary_dot16_bound a b ha hb)

/-- A radix at most 32 cannot separate all pairs of length-16 ternary dot results. -/
theorem small_radix_collision (r : Int) (hr : 1 ≤ r ∧ r ≤ 32) :
    ∃ x y x' y' : Int,
      DotResult x ∧ DotResult y ∧ DotResult x' ∧ DotResult y' ∧
      pack r x y = pack r x' y' ∧ (x ≠ x' ∨ y ≠ y') := by
  refine ⟨-16, 1, r - 16, 0, ?_⟩
  simp only [DotResult, pack, Int.mul_one, Int.mul_zero, Int.add_zero]
  omega

def Separates (r : Int) : Prop :=
  ∀ x y x' y', DotResult x → DotResult y → DotResult x' → DotResult y' →
    pack r x y = pack r x' y' → x = x' ∧ y = y'

theorem minimum_radix_is_33 :
    Separates 33 ∧ ∀ r : Int, 1 ≤ r → Separates r → 33 ≤ r := by
  constructor
  · intro x y x' y' hx _ hx' _ heq
    exact injective33 x y x' y' hx hx' heq
  · intro r hr hs
    by_cases hn : 33 ≤ r
    · exact hn
    apply False.elim
    have hsmall : r ≤ 32 := by omega
    obtain ⟨x, y, x', y', hx, hy, hx', hy', heq, hne⟩ := small_radix_collision r ⟨hr, hsmall⟩
    have hid := hs x y x' y' hx hy hx' hy' heq
    rcases hne with h | h
    · exact h hid.1
    · exact h hid.2

/-- Three balanced radix digits already fail the signed-byte input bound at radix 33. -/
theorem three_digits_do_not_fit (r : Int) (hr : 33 ≤ r) :
    ¬ SignedByte (1 + r + r * r) := by
  have hmul : 33 * r ≤ r * r := Int.mul_le_mul_of_nonneg_right hr (by omega)
  unfold SignedByte
  omega

theorem no_three_digit_separating_byte_radix (r : Int) (hr : 1 ≤ r)
    (hs : Separates r) :
    ¬ ∀ a b c : Int, Trit a → Trit b → Trit c →
      SignedByte (a + r * b + r * r * c) := by
  intro hfit
  have ht : Trit 1 := by constructor <;> decide
  have h := hfit 1 1 1 ht ht ht
  simp only [Int.mul_one] at h
  exact three_digits_do_not_fit r (minimum_radix_is_33.2 r hr hs) h

/-- Universal two-trit packing in a signed byte forces radix at most 126. -/
theorem universal_byte_pack_bound (r : Int)
    (h : ∀ a b, Trit a → Trit b → SignedByte (pack r a b)) : r ≤ 126 := by
  have ht : Trit 1 := by constructor <;> decide
  have hp := h 1 1 ht ht
  unfold SignedByte pack at hp
  omega

def dot2 (a₀ a₁ b₀ b₁ : Int) : Int := a₀ * b₀ + a₁ * b₁

/-- A shared signed-byte activation row destroys any legal positive-radix fusion.
    The two input row pairs are (-1,0),(0,1) and (0,0),(0,0); activations are (r,1).
    Both packed dot results are zero, but the unpacked result pairs differ. -/
theorem byte_activation_collision (r : Int) (hr : 1 ≤ r ∧ r ≤ 126) :
    SignedByte r ∧
    dot2 (pack r (-1) 0) (pack r 0 1) r 1 =
      dot2 (pack r 0 0) (pack r 0 0) r 1 ∧
    (dot2 (-1) 0 r 1, dot2 0 1 r 1) ≠
      (dot2 0 0 r 1, dot2 0 0 r 1) := by
  simp [SignedByte, dot2, pack]
  omega

theorem no_byte_radix_decoder (r : Int) (hr : 1 ≤ r)
    (hfit : ∀ a b, Trit a → Trit b → SignedByte (pack r a b)) :
    ¬ ∃ decode : Int → Int → Int → Int × Int,
      ∀ a₀ a₁ a'₀ a'₁ b₀ b₁ : Int,
        Trit a₀ → Trit a₁ → Trit a'₀ → Trit a'₁ →
        SignedByte b₀ → SignedByte b₁ →
        decode b₀ b₁ (dot2 (pack r a₀ a'₀) (pack r a₁ a'₁) b₀ b₁) =
          (dot2 a₀ a₁ b₀ b₁, dot2 a'₀ a'₁ b₀ b₁) := by
  intro ⟨decode, hdecode⟩
  have hu := universal_byte_pack_bound r hfit
  have hc := byte_activation_collision r ⟨hr, hu⟩
  have hz : Trit 0 := by constructor <;> decide
  have ho : Trit 1 := by constructor <;> decide
  have hn : Trit (-1) := by constructor <;> decide
  have hb : SignedByte 1 := by constructor <;> decide
  have h₁ := hdecode (-1) 0 0 1 r 1 hn hz hz ho hc.1 hb
  have h₂ := hdecode 0 0 0 0 r 1 hz hz hz hz hc.1 hb
  rw [hc.2.1] at h₁
  exact hc.2.2 (h₁.symm.trans h₂)

def two (x y : Int) (k : Nat) : Int := if k = 0 then x else if k = 1 then y else 0

theorem dot_two (a₀ a₁ b₀ b₁ : Int) :
    dot 16 (two a₀ a₁) (two b₀ b₁) = dot2 a₀ a₁ b₀ b₁ := by
  simp [dot, two, dot2]

theorem two_pack (r a₀ a₁ a'₀ a'₁ : Int) :
    (fun k => pack r (two a₀ a₁ k) (two a'₀ a'₁ k)) =
      two (pack r a₀ a'₀) (pack r a₁ a'₁) := by
  funext k
  by_cases h₀ : k = 0 <;> by_cases h₁ : k = 1 <;> simp [two, h₀, h₁, pack]

theorem two_property (P : Int → Prop) (hzero : P 0) (x y : Int) (hx : P x) (hy : P y) :
    ∀ k, P (two x y k) := by
  intro k
  unfold two
  split
  · exact hx
  · split
    · exact hy
    · exact hzero

/-- The collision applies to a full K=16 dot and even a decoder that sees all activations. -/
theorem no_byte_radix_decoder16 (r : Int) (hr : 1 ≤ r)
    (hfit : ∀ a b, Trit a → Trit b → SignedByte (pack r a b)) :
    ¬ ∃ decode : (Nat → Int) → Int → Int × Int,
      ∀ a a' b : Nat → Int,
        (∀ k, k < 16 → Trit (a k)) →
        (∀ k, k < 16 → Trit (a' k)) →
        (∀ k, k < 16 → SignedByte (b k)) →
        decode b (dot 16 (fun k => pack r (a k) (a' k)) b) =
          (dot 16 a b, dot 16 a' b) := by
  intro ⟨decode, hd⟩
  apply no_byte_radix_decoder r hr hfit
  refine ⟨fun b₀ b₁ z => decode (two b₀ b₁) z, ?_⟩
  intro a₀ a₁ a'₀ a'₁ b₀ b₁ ha₀ ha₁ ha'₀ ha'₁ hb₀ hb₁
  have hz : Trit 0 := by constructor <;> decide
  have hzb : SignedByte 0 := by constructor <;> decide
  have h := hd (two a₀ a₁) (two a'₀ a'₁) (two b₀ b₁)
    (fun k _ => two_property Trit hz a₀ a₁ ha₀ ha₁ k)
    (fun k _ => two_property Trit hz a'₀ a'₁ ha'₀ ha'₁ k)
    (fun k _ => two_property SignedByte hzb b₀ b₁ hb₀ hb₁ k)
  simpa only [two_pack, dot_two] using h

end Kelana
