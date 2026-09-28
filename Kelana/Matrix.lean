import Kelana.Radix
import Kelana.Information

namespace Kelana.Matrix

abbrev Tile := Nat → Nat → Int
abbrev ByteTile := Nat → Nat → Nat

def mul (a b : Tile) (i j : Nat) : Int := Kelana.dot 16 (a i) (fun k => b k j)
def identity : Tile := fun i k => if i = k then 1 else 0

def encodeI8 (x : Int) : Nat := (x % 256).toNat
def decodeI8 (x : Nat) : Int := if x < 128 then (x : Int) else (x : Int) - 256

def prepare (a : Tile) : ByteTile := fun i k => encodeI8 (a i k)

/-- Integer denotation of the signed IU8 instruction, with layout maps abstracted separately. -/
def iu8 (a b : ByteTile) (c : Tile) (i j : Nat) : Int :=
  Kelana.dot 16 (fun k => decodeI8 (a i k)) (fun k => decodeI8 (b k j)) + c i j

def Ternary (a : Tile) : Prop := ∀ i k, i < 16 → k < 16 → Kelana.Trit (a i k)
def Bytes (b : Tile) : Prop := ∀ k j, k < 16 → j < 16 → Kelana.SignedByte (b k j)

theorem encode_fits (x : Int) : encodeI8 x < 256 := by
  unfold encodeI8
  omega

theorem decode_encode (x : Int) (hx : Kelana.SignedByte x) : decodeI8 (encodeI8 x) = x := by
  unfold Kelana.SignedByte at hx
  unfold decodeI8 encodeI8
  split <;> omega

theorem dot_congr (n : Nat) (a a' b b' : Nat → Int)
    (ha : ∀ k, k < n → a k = a' k) (hb : ∀ k, k < n → b k = b' k) :
    Kelana.dot n a b = Kelana.dot n a' b' := by
  induction n with
  | zero => rfl
  | succ n ih =>
    have hprev := ih (fun k hk => ha k (by omega)) (fun k hk => hb k (by omega))
    simp only [Kelana.dot, hprev, ha n (by omega), hb n (by omega)]

/-- Arbitrary ternary weight inputs can be loaded directly into signed byte operands. -/
theorem prepared_iu8_correct (a b c : Tile) (ha : Ternary a) (hb : Bytes b)
    (i j : Nat) (hi : i < 16) (hj : j < 16) :
    iu8 (prepare a) (prepare b) c i j = mul a b i j + c i j := by
  unfold iu8 mul prepare
  congr 1
  apply dot_congr
  · intro k hk
    apply decode_encode
    have h := ha i k hi hk
    unfold Kelana.Trit at h
    constructor <;> omega
  · intro k hk
    exact decode_encode _ (hb k j hk hj)

theorem dot_byte_bound (n : Nat) (a b : Nat → Int)
    (ha : ∀ k, k < n → Kelana.Trit (a k))
    (hb : ∀ k, k < n → Kelana.SignedByte (b k)) :
    -128 * (n : Int) ≤ Kelana.dot n a b ∧ Kelana.dot n a b ≤ 128 * (n : Int) := by
  induction n with
  | zero => simp [Kelana.dot]
  | succ n ih =>
    have hp := ih (fun k hk => ha k (by omega)) (fun k hk => hb k (by omega))
    have hta := ha n (by omega)
    have htb := hb n (by omega)
    have cases : a n = -1 ∨ a n = 0 ∨ a n = 1 := by
      unfold Kelana.Trit at hta; omega
    have ht : -128 ≤ a n * b n ∧ a n * b n ≤ 128 := by
      unfold Kelana.SignedByte at htb
      rcases cases with h | h | h <;> rw [h] <;>
        simp only [Int.neg_mul, Int.one_mul, Int.zero_mul] <;> omega
    simp only [Kelana.dot]
    omega

theorem product_fits_i32 (a b : Tile) (ha : Ternary a) (hb : Bytes b)
    (i j : Nat) (hi : i < 16) (hj : j < 16) :
    -2048 ≤ mul a b i j ∧ mul a b i j ≤ 2048 := by
  exact dot_byte_bound 16 (a i) (fun k => b k j)
    (fun k hk => ha i k hi hk) (fun k hk => hb k j hk hj)

theorem dot_delta (n i : Nat) (b : Nat → Int) :
    Kelana.dot n (fun k => if i = k then 1 else 0) b = if i < n then b i else 0 := by
  induction n with
  | zero => simp [Kelana.dot]
  | succ n ih =>
    simp only [Kelana.dot, ih]
    by_cases heq : i = n
    · subst i; simp
    · by_cases hlt : i < n
      · simp [heq, hlt, show i < n + 1 by omega]
      · simp [heq, hlt, show ¬ i < n + 1 by omega]

theorem identity_mul (b : Tile) (i j : Nat) (hi : i < 16) :
    mul identity b i j = b i j := by
  change Kelana.dot 16 (fun k => if i = k then 1 else 0) (fun k => b k j) = b i j
  rw [dot_delta]
  simp [hi]

def prefixWeights : Tile := fun i k => Kelana.prefixOnes (i + 1) k

theorem prefix_weights_ternary : Ternary prefixWeights := by
  intro i k _ _
  unfold prefixWeights Kelana.prefixOnes
  split <;> constructor <;> omega

theorem dot_gated (n m : Nat) (b : Nat → Int) :
    Kelana.dot n (Kelana.prefixOnes m) b = Kelana.dot (min n m) (fun _ => 1) b := by
  induction n with
  | zero => simp [Kelana.dot]
  | succ n ih =>
    by_cases h : n < m
    · have hn : min n m = n := Nat.min_eq_left (by omega)
      have hs : min (n + 1) m = n + 1 := Nat.min_eq_left (by omega)
      simp [Kelana.dot, ih, hn, hs, Kelana.prefixOnes, h]
    · have hn : min n m = m := Nat.min_eq_right (by omega)
      have hs : min (n + 1) m = m := Nat.min_eq_right (by omega)
      simp [Kelana.dot, ih, hn, hs, Kelana.prefixOnes, h]

theorem prefix_mul (b : Tile) (i j : Nat) (hi : i < 16) :
    mul prefixWeights b i j = Kelana.dot (i + 1) (fun _ => 1) (fun k => b k j) := by
  unfold mul prefixWeights
  rw [dot_gated, Nat.min_eq_right (by omega)]

def difference (d : Tile) : Tile :=
  fun i j => if i = 0 then d 0 j else d i j - d (i - 1) j

theorem difference_prefix (b : Tile) (i j : Nat) (hi : i < 16) :
    difference (mul prefixWeights b) i j = b i j := by
  cases i with
  | zero => simp [difference, prefix_mul b 0 j (by decide), Kelana.dot]
  | succ i =>
    simp only [difference, Nat.add_eq_zero_iff, Nat.one_ne_zero, and_false, ↓reduceIte,
      Nat.add_sub_cancel, prefix_mul b (i + 1) j hi, prefix_mul b i j (by omega), Kelana.dot,
      Int.one_mul]
    omega

theorem identity_ternary : Ternary identity := by
  intro i k _ _
  unfold identity
  split <;> constructor <;> omega

def observe (b : Tile) : List Int :=
  List.ofFn (fun k : Fin 256 => b (k.val / 16) (k.val % 16))

def fromBytes (x : Fin (256 ^ 256)) : Tile :=
  fun i j => (Information.expand 256 x).getD (i * 16 + j) 0

theorem fromBytes_valid (x : Fin (256 ^ 256)) : Bytes (fromBytes x) := by
  intro i j hi hj
  have hlen : (Information.expand 256 x).length = 256 := by
    simp only [Information.expand, List.length_map, Information.bytes_length]
  have hidx : i * 16 + j < (Information.expand 256 x).length := by omega
  apply Information.expand_values 256 x
  unfold fromBytes
  simp only [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hidx, Option.getD_some]
  exact List.getElem_mem hidx

theorem observe_fromBytes (x : Fin (256 ^ 256)) :
    observe (fromBytes x) = Information.expand 256 x := by
  apply List.ext_getElem
  · simp only [observe, List.length_ofFn, Information.expand, List.length_map, Information.bytes_length]
  · intro i hi hj
    simp only [observe, List.getElem_ofFn, fromBytes]
    have hidx : i / 16 * 16 + i % 16 = i := by omega
    rw [hidx]
    simp [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hj]

theorem observe_identity (b : Tile) : observe (mul identity b) = observe b := by
  unfold observe
  congr 1
  funext k
  apply identity_mul
  have hk := k.isLt
  omega

/-- The identity is an admissible ternary weight matrix, so a universal engine
    must preserve all 2048 activation bits across any sole information cut. -/
theorem universal_matrix_cut (bits : Nat)
    (encode : Fin (256 ^ 256) → Fin (2 ^ bits))
    (decode : Fin (2 ^ bits) → List Int)
    (correct : ∀ x, decode (encode x) = observe (mul identity (fromBytes x))) :
    2048 ≤ bits := by
  apply Information.byte_cut_lower_bound 256 bits encode decode
  intro x
  simpa only [observe_identity, observe_fromBytes] using correct x

end Kelana.Matrix
