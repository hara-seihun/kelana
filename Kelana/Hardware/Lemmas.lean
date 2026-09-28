/-
Lemmas and boundary cases for the gfx1151 integer subset.

The `example`s are transcribed from the manual's pseudocode by hand and evaluated against
the Lean definitions, so a transcription slip in `Kelana.Hardware.IntOps` shows up as a
failed build rather than as a plausible-looking definition. The named theorems are the
facts Kelana's packing code needs.
-/
import Std.Tactic.BVDecide
import Kelana.Hardware.IntOps

namespace Kelana.Hardware

/-! ## Shift counts are masked

A 32-bit shift uses `S[4:0]`, so a count of 32 or more wraps round instead of clearing the
register. This is the boundary that C's undefined shift behavior hides.
-/

theorem lshlrev_count_32 (x : BitVec 32) : v_lshlrev_b32 {} 32 x = .ok x := by
  rw [v_lshlrev_b32_plain]; simp [shiftCount]

theorem lshrrev_count_33 (x : BitVec 32) : v_lshrrev_b32 {} 33 x = .ok (x >>> 1) := by
  rw [v_lshrrev_b32_plain]; simp [shiftCount]

example : v_ashrrev_i32 {} 31 0x80000000 = .ok 0xffffffff := by decide
example : v_lshrrev_b32 {} 31 0x80000000 = .ok 1 := by decide

/-! ## Packing and unpacking a 32-bit word

`V_LSHL_OR_B32` inserts a field and `V_BFE_U32` reads one back. The extract recovers the
inserted field exactly when the field is narrow enough, and the low field survives the
insertion because the shifted operand only sets bits above the shift.
-/

/-- Shift-and-merge at bit 4, with the fields the packed word then holds. -/
theorem lshl_or_4 (s0 s2 : BitVec 32) :
    v_lshl_or_b32 {} s0 4 s2 = .ok ((s0 <<< 4) ||| s2) := rfl

theorem bfe_4_4 (x : BitVec 32) : v_bfe_u32 {} x 4 4 = .ok ((x >>> 4) &&& 0xf) := rfl

theorem bfe_0_4 (x : BitVec 32) : v_bfe_u32 {} x 0 4 = .ok (x &&& 0xf) := rfl

/-- Insert a nibble at bit 4 above an existing low nibble, then read it back. -/
theorem bfe_lshl_or_nibble (hi lo : BitVec 32) (h : lo &&& 0xfffffff0 = 0) :
    (do
      let packed ← v_lshl_or_b32 {} hi 4 lo
      v_bfe_u32 {} packed 4 4) = .ok (hi &&& 0xf) := by
  rw [lshl_or_4]
  show v_bfe_u32 {} ((hi <<< 4) ||| lo) 4 4 = _
  rw [bfe_4_4, Except.ok.injEq]
  have mask : (0xf : BitVec 32) = (BitVec.allOnes 4).setWidth 32 := by decide
  have maskHi : (0xfffffff0 : BitVec 32) = ~~~((BitVec.allOnes 4).setWidth 32) := by decide
  rw [mask]
  rw [maskHi] at h
  apply BitVec.eq_of_getLsbD_eq_iff.mpr
  intro i hi
  simp only [BitVec.getLsbD_and, BitVec.getLsbD_or, BitVec.getLsbD_ushiftRight,
    BitVec.getLsbD_shiftLeft, BitVec.getLsbD_setWidth, BitVec.getLsbD_allOnes]
  by_cases h4 : i < 4
  · have hj : 4+i < 32 := by omega
    have hn : ¬ 4+i < 4 := by omega
    have hz := congrArg (fun x : BitVec 32 => x.getLsbD (4+i)) h
    simp only [BitVec.getLsbD_and, BitVec.getLsbD_not, BitVec.getLsbD_setWidth,
      BitVec.getLsbD_allOnes] at hz
    simp [hj, hn] at hz
    simp [hi, h4, hj, hn, Nat.add_sub_cancel_left, hz]
  · simp [hi, h4]

/-- The low field survives the insertion of a field above it, with no hypothesis needed. -/
theorem bfe_lshl_or_low (hi lo : BitVec 32) :
    (do
      let packed ← v_lshl_or_b32 {} hi 4 lo
      v_bfe_u32 {} packed 0 4) = .ok (lo &&& 0xf) := by
  rw [lshl_or_4]
  show v_bfe_u32 {} ((hi <<< 4) ||| lo) 0 4 = _
  rw [bfe_0_4, Except.ok.injEq]
  have mask : (0xf : BitVec 32) = (BitVec.allOnes 4).setWidth 32 := by decide
  rw [mask]
  apply BitVec.eq_of_getLsbD_eq_iff.mpr
  intro i hi
  simp only [BitVec.getLsbD_and, BitVec.getLsbD_or, BitVec.getLsbD_shiftLeft,
    BitVec.getLsbD_setWidth, BitVec.getLsbD_allOnes]
  by_cases h4 : i < 4 <;> simp [hi, h4]

/-- A byte read with `V_BFE_U32` is the byte `V_PERM_B32` calls `in[1]`. -/
theorem bfe_byte_eq_byte32 (x : BitVec 32) :
    v_bfe_u32 {} x 8 8 = .ok ((byte32 x 1).setWidth 32) := by
  have plain : v_bfe_u32 {} x 8 8 = .ok ((x >>> 8) &&& 0xff) := rfl
  rw [plain, Except.ok.injEq, byte32]
  have mask : (0xff : BitVec 32) = (BitVec.allOnes 8).setWidth 32 := by decide
  rw [mask]
  apply BitVec.eq_of_getLsbD_eq_iff.mpr
  intro i hi
  simp only [BitVec.getLsbD_and, BitVec.getLsbD_ushiftRight,
    BitVec.getLsbD_setWidth, BitVec.getLsbD_allOnes]
  simp [hi, Bool.and_comm]

/-- Width zero extracts nothing: `(1 << 0) - 1 = 0`. -/
example (x : BitVec 32) : v_bfe_u32 {} x 8 0 = .ok 0 := by
  rw [v_bfe_u32_plain]; simp [shiftCount]

/-- The widest single extract is 31 bits, because the width field is five bits. -/
example : v_bfe_u32 {} 0xffffffff 0 31 = .ok 0x7fffffff := by decide

/-! ## Byte permute

`{S0, S1}` puts S0 in the *high* half, so selectors 4..7 read S0 and 0..3 read S1.
-/

example : v_perm_b32 {} 0xaabbccdd 0x11223344 0x07060504 = .ok 0xaabbccdd := by decide
example : v_perm_b32 {} 0xaabbccdd 0x11223344 0x03020100 = .ok 0x11223344 := by decide
example : v_perm_b32 {} 0xaabbccdd 0x11223344 0x0c0c0c0c = .ok 0x00000000 := by decide
example : v_perm_b32 {} 0xaabbccdd 0x11223344 0x0d0d0d0d = .ok 0xffffffff := by decide
example : v_perm_b32 {} 0xaabbccdd 0x11223344 0xffffffff = .ok 0xffffffff := by decide

/-- Selector 8 replicates the sign bit of `in[1]`, the second byte of S1. -/
example : v_perm_b32 {} 0 0x0000ff00 0x08080808 = .ok 0xffffffff := by decide
example : v_perm_b32 {} 0 0x00007f00 0x08080808 = .ok 0x00000000 := by decide

/-- Selector 11 replicates the sign bit of `in[7]`, the top byte of S0. -/
example : v_perm_b32 {} 0x80000000 0 0x0b0b0b0b = .ok 0xffffffff := by decide

/-! ## No-carry arithmetic and saturation

CLAMP is a different operation, not a formality: it is the only way these opcodes stop
wrapping, and Kelana models it for the two opcodes whose manual note and assembler form
both support it.
-/

example : v_add_nc_u32 {} 0xffffffff 5 = .ok 4 := by decide
example : v_add_nc_u32 { clamp := true } 0xffffffff 5 = .ok 0xffffffff := by decide
example : v_sub_nc_u32 {} 3 5 = .ok 0xfffffffe := by decide
example : v_sub_nc_u32 { clamp := true } 3 5 = .ok 0 := by decide
example : v_mul_lo_u32 {} 0x00010000 0x00010000 = .ok 0 := by decide

/-- `V_MUL_LO_U32` has no clamp form, so the model refuses rather than ignoring the field. -/
example : (v_mul_lo_u32 { clamp := true } 3 4).isOk = false := by decide

/-- Neither do the bitwise opcodes. -/
example : (v_and_b32 { clamp := true } 3 4).isOk = false := by decide

/-- A DPP form reads another lane's data, which no lane-local function can express. -/
example : (v_lshlrev_b32 { dpp := true } 1 1).isOk = false := by decide

/-! ## Packed integer dot products

Signedness comes from `NEG[0]` and `NEG[1]`, so one opcode computes four different
functions. Each case below is evaluated from the packed elements by hand.
-/

/-- Unsigned: `4*1 + 3*2 + 2*3 + 1*4 = 20`, plus `C = 1`. -/
example : v_dot4_i32_iu8 {} 0x01020304 0x04030201 1 = .ok 21 := by decide

/-- Both signed: four `(-1) * 1` products. -/
example : v_dot4_i32_iu8 { neg := 3 } 0xffffffff 0x01010101 0 = .ok 0xfffffffc := by decide

/-- S0 signed, S1 unsigned: `(-1) * 255` four times. -/
example :
    v_dot4_i32_iu8 { neg := 1 } 0xffffffff 0xffffffff 0 = .ok (BitVec.ofInt 32 (-1020)) := by
  decide

/-- The same bits read unsigned on both sides: `255 * 255 * 4 = 260100`. -/
example : v_dot4_i32_iu8 {} 0xffffffff 0xffffffff 0 = .ok 260100 := by decide

/-- Unsigned nibbles `0..7` against `1`: `0+1+2+3+4+5+6+7 = 28`. -/
example : v_dot8_i32_iu4 {} 0x76543210 0x11111111 0 = .ok 28 := by decide

/-- Signed nibbles: `0xf` reads as `-1`, eight times. -/
example :
    v_dot8_i32_iu4 { neg := 3 } 0xffffffff 0x11111111 0 = .ok (BitVec.ofInt 32 (-8)) := by
  decide

/-- Both signed at the negative extreme: `(-8) * (-8) * 8 = 512`. -/
example : v_dot8_i32_iu4 { neg := 3 } 0x88888888 0x88888888 0 = .ok 512 := by decide

/-- Mixed: S0 signed `-8`, S1 unsigned `8`, eight times. -/
example :
    v_dot8_i32_iu4 { neg := 1 } 0x88888888 0x88888888 0 = .ok (BitVec.ofInt 32 (-512)) := by
  decide

/-- The modifiers the manual does not define for these opcodes have no meaning here. -/
example : (v_dot4_i32_iu8 { clamp := true } 1 1 0).isOk = false := by decide
example : (v_dot4_i32_iu8 { neg := 4 } 1 1 0).isOk = false := by decide
example : (v_dot8_i32_iu4 { opSelHi := 0 } 1 1 0).isOk = false := by decide

/--
The accumulator is 32 bits wide and the model wraps in it. When the exact integer value of
the dot product fits, the wrapped result carries it exactly; that hypothesis is what a
Kelana proof about accumulated dot products has to discharge, and it is not a property of
the instruction at arbitrary magnitudes.
-/
theorem dot4_eq_exact_sum (s0 s1 s2 : BitVec 32) (a b : Bool) (sum : Int)
    (hsum : sum = s2.toInt
      + (dotOperand a (byte32 s0 0) * dotOperand b (byte32 s1 0)
        + (dotOperand a (byte32 s0 1) * dotOperand b (byte32 s1 1)
          + (dotOperand a (byte32 s0 2) * dotOperand b (byte32 s1 2)
            + (dotOperand a (byte32 s0 3) * dotOperand b (byte32 s1 3) + 0)))))
    (hfits : -2 ^ 31 ≤ sum ∧ sum < 2 ^ 31) :
    ∃ d : BitVec 32,
      v_dot4_i32_iu8 { neg := BitVec.ofBoolListLE [a, b, false] } s0 s1 s2 = .ok d
        ∧ d.toInt = sum := by
  refine ⟨BitVec.ofInt 32 sum, ?_, ?_⟩
  · cases a <;> cases b <;>
      simp [v_dot4_i32_iu8, Vop3P.dotFields, BitVec.ofBoolListLE, hsum, List.range,
        List.range.loop, dotOperand, Functor.map, Except.map]
  · rw [BitVec.toInt_ofInt]
    simp [Int.bmod]
    omega

/-- A compositional law of the plain modular profile, including overflowing inputs.
This is not a law of every modifier setting bearing the same opcode name. -/
theorem plain_add_sub_cancels (x y : BitVec 32) :
    (do
      let z ← v_add_nc_u32 {} x y
      v_sub_nc_u32 {} z y) = .ok x := by
  rw [v_add_nc_u32_plain]
  show v_sub_nc_u32 {} (x+y) y = .ok x
  rw [v_sub_nc_u32_plain, Except.ok.injEq]
  bv_decide

/-- CLAMP destroys the inverse relationship on overflowing inputs. -/
example :
    (do
      let z ← v_add_nc_u32 { clamp := true } 0xffffffff 1
      v_sub_nc_u32 {} z 1) = .ok 0xfffffffe := by decide

#print axioms plain_add_sub_cancels
end Kelana.Hardware
