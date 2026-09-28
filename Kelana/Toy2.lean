import Kelana.Radix
import Kelana.Amortization
import Kelana.Information

namespace Kelana.Toy2

structure Matrix where
  a00 : Int
  a01 : Int
  a10 : Int
  a11 : Int
  deriving DecidableEq

def Ternary (a : Matrix) : Prop :=
  Trit a.a00 ∧ Trit a.a01 ∧ Trit a.a10 ∧ Trit a.a11

def mac (a b c : Matrix) : Matrix :=
  ⟨a.a00 * b.a00 + a.a01 * b.a10 + c.a00,
   a.a00 * b.a01 + a.a01 * b.a11 + c.a01,
   a.a10 * b.a00 + a.a11 * b.a10 + c.a10,
   a.a10 * b.a01 + a.a11 * b.a11 + c.a11⟩

inductive Orientation where
  | normal
  | flipLow
  | flipHigh
  deriving DecidableEq

def hi : Orientation → Int
  | .normal => 1
  | .flipLow => 1
  | .flipHigh => -1

def lo : Orientation → Int
  | .normal => 1
  | .flipLow => -1
  | .flipHigh => 1

def coeff0 (a : Matrix) (o : Orientation) : Int := lo o * a.a10 + 7 * hi o * a.a00
def coeff1 (a : Matrix) (o : Orientation) : Int := lo o * a.a11 + 7 * hi o * a.a01

def Fits (a : Matrix) (o : Orientation) : Prop :=
  -8 ≤ coeff0 a o ∧ coeff0 a o ≤ 7 ∧ -8 ≤ coeff1 a o ∧ coeff1 a o ≤ 7

instance (a : Matrix) (o : Orientation) : Decidable (Fits a o) :=
  inferInstanceAs (Decidable (_ ∧ _ ∧ _ ∧ _))

def choose (a : Matrix) : Orientation :=
  if Fits a .normal then .normal else if Fits a .flipLow then .flipLow else .flipHigh

/-- At most two sign orientations are forbidden by the two columns of A. -/
theorem chosen_fits (a : Matrix) (ha : Ternary a) : Fits a (choose a) := by
  unfold choose
  split
  · assumption
  · split
    · assumption
    · unfold Fits coeff0 coeff1 hi lo at *
      unfold Ternary Trit at ha
      simp only [Int.one_mul, Int.neg_one_mul] at *
      omega

def bias (a : Matrix) (o : Orientation) : Int :=
  24 - (coeff0 a o + coeff1 a o + 7 * hi o + lo o)

/-- One signed-weight/unsigned-input DOT8 with four live lanes. -/
def packedColumn (a : Matrix) (o : Orientation) (b0 b1 c0 c1 : Int) : Int :=
  coeff0 a o * (b0 + 1) + coeff1 a o * (b1 + 1) +
    (7 * hi o) * (c0 + 1) + lo o * (c1 + 1) + bias a o

def baselineColumn (a : Matrix) (o : Orientation) (b0 b1 c0 c1 : Int) : Int :=
  let d0 := (hi o * a.a00) * (b0 + 1) + (hi o * a.a01) * (b1 + 1) +
    hi o * (c0 + 1) + (3 - hi o * (a.a00 + a.a01 + 1))
  let d1 := (lo o * a.a10) * (b0 + 1) + (lo o * a.a11) * (b1 + 1) +
    lo o * (c1 + 1) + (3 - lo o * (a.a10 + a.a11 + 1))
  d1 + 7 * d0

theorem baseline_equals_packed (a : Matrix) (o : Orientation) (b0 b1 c0 c1 : Int) :
    baselineColumn a o b0 b1 c0 c1 = packedColumn a o b0 b1 c0 c1 := by
  unfold baselineColumn packedColumn bias coeff0 coeff1
  grind

theorem bias_bounds (a : Matrix) (o : Orientation) (h : Fits a o) :
    0 ≤ bias a o ∧ bias a o ≤ 48 := by
  unfold Fits at h
  unfold bias
  cases o <;> simp only [hi, lo] at * <;> omega

def encodeColumn (o : Orientation) (d0 d1 : Int) : Int :=
  (lo o * d1 + 3) + 7 * (hi o * d0 + 3)

def decodeHigh (o : Orientation) (p : Int) : Int := hi o * (p / 7 - 3)
def decodeLow (o : Orientation) (p : Int) : Int := lo o * (p % 7 - 3)

/-- Neither individual matrix output is constructed by packedColumn. -/
theorem packed_column_identity (a : Matrix) (o : Orientation) (b0 b1 c0 c1 : Int) :
    packedColumn a o b0 b1 c0 c1 =
      encodeColumn o (a.a00 * b0 + a.a01 * b1 + c0)
        (a.a10 * b0 + a.a11 * b1 + c1) := by
  unfold packedColumn encodeColumn bias coeff0 coeff1
  grind

theorem small_dot_bound (a0 a1 b0 b1 c : Int)
    (ha0 : Trit a0) (ha1 : Trit a1) (hb0 : Trit b0) (hb1 : Trit b1) (hc : Trit c) :
    -3 ≤ a0 * b0 + a1 * b1 + c ∧ a0 * b0 + a1 * b1 + c ≤ 3 := by
  have h0 := trit_product_bound a0 b0 ha0 hb0
  have h1 := trit_product_bound a1 b1 ha1 hb1
  unfold Trit at hc
  omega

theorem encode_column_bounds (o : Orientation) (d0 d1 : Int)
    (h0 : -3 ≤ d0 ∧ d0 ≤ 3) (h1 : -3 ≤ d1 ∧ d1 ≤ 3) :
    0 ≤ encodeColumn o d0 d1 ∧ encodeColumn o d0 d1 ≤ 48 := by
  cases o <;> simp only [encodeColumn, hi, lo, Int.one_mul, Int.neg_one_mul] <;> omega

theorem decode_column (o : Orientation) (d0 d1 : Int)
    (_h0 : -3 ≤ d0 ∧ d0 ≤ 3) (h1 : -3 ≤ d1 ∧ d1 ≤ 3) :
    decodeHigh o (encodeColumn o d0 d1) = d0 ∧
    decodeLow o (encodeColumn o d0 d1) = d1 := by
  cases o <;> simp only [decodeHigh, decodeLow, encodeColumn, hi, lo,
    Int.one_mul, Int.neg_one_mul] <;> omega

def packedRun (a b c : Matrix) : Int :=
  packedColumn a (choose a) b.a00 b.a10 c.a00 c.a10 +
    256 * packedColumn a (choose a) b.a01 b.a11 c.a01 c.a11

def decode (o : Orientation) (p : Int) : Matrix :=
  ⟨decodeHigh o (p % 256), decodeHigh o (p / 256),
   decodeLow o (p % 256), decodeLow o (p / 256)⟩

/-- Whole toy map, including its common packed output contract. -/
theorem packed_correct (a b c : Matrix) (ha : Ternary a) (hb : Ternary b) (hc : Ternary c) :
    decode (choose a) (packedRun a b c) = mac a b c := by
  have h00 := small_dot_bound _ _ _ _ _ ha.1 ha.2.1 hb.1 hb.2.2.1 hc.1
  have h01 := small_dot_bound _ _ _ _ _ ha.1 ha.2.1 hb.2.1 hb.2.2.2 hc.2.1
  have h10 := small_dot_bound _ _ _ _ _ ha.2.2.1 ha.2.2.2 hb.1 hb.2.2.1 hc.2.2.1
  have h11 := small_dot_bound _ _ _ _ _ ha.2.2.1 ha.2.2.2 hb.2.1 hb.2.2.2 hc.2.2.2
  have hcol0 := encode_column_bounds (choose a) _ _ h00 h10
  have hcol1 := encode_column_bounds (choose a) _ _ h01 h11
  have hd0 := decode_column (choose a) _ _ h00 h10
  have hd1 := decode_column (choose a) _ _ h01 h11
  unfold packedRun
  rw [packed_column_identity, packed_column_identity]
  have hlow : (encodeColumn (choose a) (a.a00 * b.a00 + a.a01 * b.a10 + c.a00)
      (a.a10 * b.a00 + a.a11 * b.a10 + c.a10) +
      256 * encodeColumn (choose a) (a.a00 * b.a01 + a.a01 * b.a11 + c.a01)
      (a.a10 * b.a01 + a.a11 * b.a11 + c.a11)) % 256 =
      encodeColumn (choose a) (a.a00 * b.a00 + a.a01 * b.a10 + c.a00)
      (a.a10 * b.a00 + a.a11 * b.a10 + c.a10) := by omega
  have hhigh : (encodeColumn (choose a) (a.a00 * b.a00 + a.a01 * b.a10 + c.a00)
      (a.a10 * b.a00 + a.a11 * b.a10 + c.a10) +
      256 * encodeColumn (choose a) (a.a00 * b.a01 + a.a01 * b.a11 + c.a01)
      (a.a10 * b.a01 + a.a11 * b.a11 + c.a11)) / 256 =
      encodeColumn (choose a) (a.a00 * b.a01 + a.a01 * b.a11 + c.a01)
      (a.a10 * b.a01 + a.a11 * b.a11 + c.a11) := by omega
  simp only [decode, hlow, hhigh, hd0.1, hd0.2, hd1.1, hd1.2, mac]

/-- Componentwise instruction savings; no assumption equates different opcode costs. -/
def baselineCost (shiftOr andCost dotCost madCost : Nat) : Nat :=
  4 * shiftOr + 3 * andCost + 4 * dotCost + 2 * madCost

def packedCost (shiftOr andCost dotCost : Nat) : Nat :=
  4 * shiftOr + 3 * andCost + 2 * dotCost

theorem exact_saving (s a d m : Nat) :
    baselineCost s a d m = packedCost s a d + 2 * d + 2 * m := by
  unfold baselineCost packedCost
  omega

theorem strictly_cheaper (s a d m : Nat) (hd : 0 < d) :
    packedCost s a d < baselineCost s a d m := by
  rw [exact_saving]
  omega

theorem load_cost_cannot_erase_saving (loadPacked loadBaseline s a d m : Nat) (hd : 0 < d) :
    ∃ threshold, ∀ n, threshold ≤ n →
      Amortization.total loadPacked (packedCost s a d) n <
      Amortization.total loadBaseline (baselineCost s a d m) n := by
  exact Amortization.lower_recurring_eventually_wins _ _ _ _ (strictly_cheaper s a d m hd)

end Kelana.Toy2
