import Kelana.ScaledTrit
import Kelana.Hardware.IntOps
import Std

namespace Kelana.ScaledTritCodec
open Kelana.Hardware

/-- The native codec uses 0 for zero, 1 for positive and 3 for negative. -/
def tables (s : BitVec 16) : BitVec 32 × BitVec 32 :=
  let w := s.setWidth 32
  let lo := w &&& 0xff
  let hi := (w >>> 8) &&& 0xff
  let a := lo <<< 8
  let a := a ||| (a <<< 8)
  let b := hi <<< 8
  let b := b ||| (b <<< 8)
  (a ||| (a <<< 8), (b &&& 0x00ffff00) ||| ((hi ^^^ 0x80) <<< 24))

def spread (v : BitVec 8) : BitVec 32 :=
  let w := v.setWidth 32
  let t := w ||| (w <<< 12)
  (t ||| (t <<< 6)) &&& 0x03030303

/-- Spreading four two-bit codes costs no arithmetic on their represented values. -/
theorem spread_fields (v : BitVec 8) :
    byte32 (spread v) 0 = v &&& 3 ∧
    byte32 (spread v) 1 = (v >>> 2) &&& 3 ∧
    byte32 (spread v) 2 = (v >>> 4) &&& 3 ∧
    byte32 (spread v) 3 = (v >>> 6) &&& 3 := by
  and_intros <;> apply BitVec.eq_of_getElem_eq <;> intro i hi
  all_goals
    have h : i=0 ∨ i=1 ∨ i=2 ∨ i=3 ∨ i=4 ∨ i=5 ∨ i=6 ∨ i=7 := by omega
    rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
      simp [byte32, spread]

/-- The low/high bytes selected for one code, using the ISA's byte semantics. -/
def selectedHalf (s : BitVec 16) (code : BitVec 8) : BitVec 16 :=
  let ts := tables s
  let data : BitVec 64 := (ts.2.setWidth 64 <<< 32) ||| ts.1.setWidth 64
  (bytePermute data code).setWidth 16 |||
    ((bytePermute data (code ||| 4)).setWidth 16 <<< 8)

theorem selected_zero (s : BitVec 16) : selectedHalf s 0 = 0 := by
  simp [selectedHalf, tables, bytePermute]
  apply BitVec.eq_of_getElem_eq
  intro i hi
  have h : i = 0 ∨ i = 1 ∨ i = 2 ∨ i = 3 ∨ i = 4 ∨ i = 5 ∨ i = 6 ∨ i = 7 ∨ i = 8 ∨ i = 9 ∨ i = 10 ∨ i = 11 ∨ i = 12 ∨ i = 13 ∨ i = 14 ∨ i = 15 := by omega
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> simp

theorem selected_positive (s : BitVec 16) : selectedHalf s 1 = s := by
  simp [selectedHalf, tables, bytePermute]
  apply BitVec.eq_of_getElem_eq
  intro i hi
  have h : i = 0 ∨ i = 1 ∨ i = 2 ∨ i = 3 ∨ i = 4 ∨ i = 5 ∨ i = 6 ∨ i = 7 ∨ i = 8 ∨ i = 9 ∨ i = 10 ∨ i = 11 ∨ i = 12 ∨ i = 13 ∨ i = 14 ∨ i = 15 := by omega
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> simp

theorem selected_negative (s : BitVec 16) : selectedHalf s 3 = s ^^^ 0x8000 := by
  simp [selectedHalf, tables, bytePermute]
  apply BitVec.eq_of_getElem_eq
  intro i hi
  have h : i = 0 ∨ i = 1 ∨ i = 2 ∨ i = 3 ∨ i = 4 ∨ i = 5 ∨ i = 6 ∨ i = 7 ∨ i = 8 ∨ i = 9 ∨ i = 10 ∨ i = 11 ∨ i = 12 ∨ i = 13 ∨ i = 14 ∨ i = 15 := by omega
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> simp

/-- A packed native pair of PERM selectors interleaves code and code+4. -/
theorem selector_interleave (c : BitVec 32) :
    v_perm_b32 {} (c ||| 0x04040404) c 0x05010400 =
      .ok ((byte32 c 0).setWidth 32 |||
        (((byte32 c 0 ||| 4).setWidth 32) <<< 8) |||
        ((byte32 c 1).setWidth 32 <<< 16) |||
        (((byte32 c 1 ||| 4).setWidth 32) <<< 24)) := by
  simp [v_perm_b32, Vop3.noModifiers, Vop3.integerFields,
    byte32, bytePermute, Bind.bind, Pure.pure, Except.pure, Except.bind]
  apply BitVec.eq_of_getElem_eq
  intro i hi
  have h : i=0 ∨ i=1 ∨ i=2 ∨ i=3 ∨ i=4 ∨ i=5 ∨ i=6 ∨ i=7 ∨
    i=8 ∨ i=9 ∨ i=10 ∨ i=11 ∨ i=12 ∨ i=13 ∨ i=14 ∨ i=15 ∨
    i=16 ∨ i=17 ∨ i=18 ∨ i=19 ∨ i=20 ∨ i=21 ∨ i=22 ∨ i=23 ∨
    i=24 ∨ i=25 ∨ i=26 ∨ i=27 ∨ i=28 ∨ i=29 ∨ i=30 ∨ i=31 := by omega
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> simp

/-- The native code assignment and the earlier specification describe the same
operand. This bridges the two encodings instead of assuming they agree. -/
theorem matches_scaled_operand (s : BitVec 16) (c : Fin 3) :
    selectedHalf s (if c=0 then 3 else if c=1 then 0 else 1) =
      Kelana.ScaledTrit.operandBits s c := by
  have hc : c=0 ∨ c=1 ∨ c=2 := by omega
  rcases hc with rfl | rfl | rfl
  · simpa only [ite_true, Kelana.ScaledTrit.negative_operand] using selected_negative s
  · simpa only [show (1:Fin 3) ≠ 0 by decide, ite_false, ite_true,
      Kelana.ScaledTrit.zero_operand] using selected_zero s
  · simpa only [show (2:Fin 3) ≠ 0 by decide, show (2:Fin 3) ≠ 1 by decide,
      ite_false, Kelana.ScaledTrit.positive_operand] using selected_positive s

end Kelana.ScaledTritCodec
