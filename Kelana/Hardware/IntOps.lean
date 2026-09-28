/-
Lane-local meanings for the gfx1151 integer VALU subset Kelana composes.

Each definition transcribes the pseudocode of AMD's "RDNA3.5" Instruction Set Architecture
manual, `hardware/gfx1151/sources/rdna35-isa.txt`, for an instruction that exists in the
pinned machine-readable ISA (`sources/amdgpu_isa_rdna3_5.xml`) and that the installed
gfx1151 assembler accepts. The quoted pseudocode line in each docstring is the source of
truth; the Lean body is a transcription of it, not an idealization of it.

Scope of a definition here: one lane, one destination value, the modifier fields listed in
`Kelana.Hardware.Lane`. EXEC masking, VCC, status flags, exceptions, the whole-wave state
transition, lane-crossing modifiers and execution cost are outside it.
-/
import Kelana.Hardware.Lane

namespace Kelana.Hardware

/-- Byte `i` of a 32-bit source, `S[i * 8 + 7 : i * 8]`. -/
def byte32 (x : BitVec 32) (i : Nat) : BitVec 8 := (x >>> (i * 8)).setWidth 8

/-- Nibble `i` of a 32-bit source, `S[i * 4 + 3 : i * 4]`. -/
def nibble32 (x : BitVec 32) (i : Nat) : BitVec 4 := (x >>> (i * 4)).setWidth 4

/-- `NEG[k] ? signext(v) : zeroext(v)`, the dot instructions' signedness control. -/
def dotOperand {w : Nat} (signed : Bool) (v : BitVec w) : Int :=
  if signed then v.toInt else (v.toNat : Int)

/-- The five-bit shift count a 32-bit shift actually uses: `S[4 : 0]`. -/
def shiftCount (s : BitVec 32) : Nat := (s &&& 31).toNat

/-! ## VOP2/VOP3 integer arithmetic -/

/--
`V_ADD_NC_U32`: `D0.u32 = S0.u32 + S1.u32`.

With CLAMP the manual's note is "Supports saturation (unsigned 32-bit integer domain)" and
the CLMP field description is "Unsigned integer arithmetic: clamp result to [0, +max_uint]".
Without CLAMP the sum wraps in the 32-bit destination; the opcode carries no carry-out.
-/
def v_add_nc_u32 (m : Vop3) (s0 s1 : BitVec 32) : Lane32 := do
  Vop3.integerFields "V_ADD_NC_U32" m
  if m.clamp then
    pure (if s0.toNat + s1.toNat ≥ 2 ^ 32 then BitVec.allOnes 32 else s0 + s1)
  else
    pure (s0 + s1)

/--
`V_SUB_NC_U32`: `D0.u32 = S0.u32 - S1.u32`, saturating to `0` under CLAMP.
-/
def v_sub_nc_u32 (m : Vop3) (s0 s1 : BitVec 32) : Lane32 := do
  Vop3.integerFields "V_SUB_NC_U32" m
  if m.clamp then
    pure (if s1.toNat > s0.toNat then 0 else s0 - s1)
  else
    pure (s0 - s1)

/--
`V_MUL_LO_U32`: `D0.u32 = S0.u32 * S1.u32`, the low 32 bits of the full product.

This opcode has no clamp form: `v_mul_lo_u32 v0, v1, v2 clamp` is rejected by the gfx1151
assembler, so CLAMP is not modeled rather than assumed inert.
-/
def v_mul_lo_u32 (m : Vop3) (s0 s1 : BitVec 32) : Lane32 := do
  Vop3.noModifiers "V_MUL_LO_U32" m
  pure (s0 * s1)

/-! ## Shifts, with the shift count the hardware actually uses -/

/--
`V_LSHLREV_B32`: `D0.u32 = (S1.u32 << S0[4 : 0].u32)`.

The count operand is the *first* source and only its low five bits take part, so a count of
32 shifts by zero. The DPP form modifies the shift count rather than the data, and is not
modeled.
-/
def v_lshlrev_b32 (m : Vop3) (s0 s1 : BitVec 32) : Lane32 := do
  Vop3.noModifiers "V_LSHLREV_B32" m
  pure (s1 <<< shiftCount s0)

/-- `V_LSHRREV_B32`: `D0.u32 = (S1.u32 >> S0[4 : 0].u32)`, logical. -/
def v_lshrrev_b32 (m : Vop3) (s0 s1 : BitVec 32) : Lane32 := do
  Vop3.noModifiers "V_LSHRREV_B32" m
  pure (s1 >>> shiftCount s0)

/-- `V_ASHRREV_I32`: `D0.i32 = (S1.i32 >> S0[4 : 0].u32)`, sign-preserving. -/
def v_ashrrev_i32 (m : Vop3) (s0 s1 : BitVec 32) : Lane32 := do
  Vop3.noModifiers "V_ASHRREV_I32" m
  pure (s1.sshiftRight (shiftCount s0))

/-! ## Bitwise -/

/-- `V_AND_B32`: `D0.u32 = (S0.u32 & S1.u32)`. Input and output modifiers are not supported. -/
def v_and_b32 (m : Vop3) (s0 s1 : BitVec 32) : Lane32 := do
  Vop3.noModifiers "V_AND_B32" m
  pure (s0 &&& s1)

/-- `V_OR_B32`: `D0.u32 = (S0.u32 | S1.u32)`. -/
def v_or_b32 (m : Vop3) (s0 s1 : BitVec 32) : Lane32 := do
  Vop3.noModifiers "V_OR_B32" m
  pure (s0 ||| s1)

/-- `V_XOR_B32`: `D0.u32 = (S0.u32 ^ S1.u32)`. -/
def v_xor_b32 (m : Vop3) (s0 s1 : BitVec 32) : Lane32 := do
  Vop3.noModifiers "V_XOR_B32" m
  pure (s0 ^^^ s1)

/--
`V_LSHL_OR_B32`: `D0.u32 = ((S0.u32 << S1.u32[4 : 0].u32) | S2.u32)`.

The shifted operand is the first source here, unlike the `*REV` shifts.
-/
def v_lshl_or_b32 (m : Vop3) (s0 s1 s2 : BitVec 32) : Lane32 := do
  Vop3.noModifiers "V_LSHL_OR_B32" m
  pure ((s0 <<< shiftCount s1) ||| s2)

/-! ## Bitfield extract and byte permute -/

/--
`V_BFE_U32`: `D0.u32 = ((S0.u32 >> S1[4 : 0].u32) & ((1U << S2[4 : 0].u32) - 1U))`.

Both the offset and the width use five bits only, so the widest field this instruction can
extract is 31 bits and a width of 0 yields 0.
-/
def v_bfe_u32 (m : Vop3) (s0 s1 s2 : BitVec 32) : Lane32 := do
  Vop3.noModifiers "V_BFE_U32" m
  let width := shiftCount s2
  pure ((s0 >>> shiftCount s1) &&& (BitVec.ofNat 32 ((1 <<< width) - 1)))

/--
One byte of `V_PERM_B32`'s selector applied to the 64-bit value `{S0, S1}`.

```
if sel.u32 >= 13U then return 8'0xff
elsif sel.u32 == 12U then return 8'0x0
elsif sel.u32 == 11U then return in[7][7].b8 * 8'0xff
elsif sel.u32 == 10U then return in[5][7].b8 * 8'0xff
elsif sel.u32 ==  9U then return in[3][7].b8 * 8'0xff
elsif sel.u32 ==  8U then return in[1][7].b8 * 8'0xff
else return in[sel]
```

`in[0]` is the least significant byte of the 64-bit value, which comes from S1: the manual
notes that the most significant half is S0, "counterintuitive for a little-endian
architecture".
-/
def bytePermute (data : BitVec 64) (sel : BitVec 8) : BitVec 8 :=
  let inByte (i : Nat) : BitVec 8 := (data >>> (i * 8)).setWidth 8
  let s := sel.toNat
  if s ≥ 13 then 0xff
  else if s = 12 then 0x00
  else if s ≥ 8 then (if (inByte (2 * (s - 8) + 1)).msb then 0xff else 0x00)
  else inByte s

/--
`V_PERM_B32`: each destination byte selects a byte of `{S0, S1}`, a replicated sign bit, or
a constant, under the corresponding byte of S2.
-/
def v_perm_b32 (m : Vop3) (s0 s1 s2 : BitVec 32) : Lane32 := do
  Vop3.noModifiers "V_PERM_B32" m
  let data : BitVec 64 := (s0.setWidth 64 <<< 32) ||| s1.setWidth 64
  let b (i : Nat) : BitVec 8 := bytePermute data (byte32 s2 i)
  pure (((b 3).setWidth 32 <<< 24) ||| ((b 2).setWidth 32 <<< 16)
        ||| ((b 1).setWidth 32 <<< 8) ||| (b 0).setWidth 32)

/-! ## Packed integer dot products

`NEG[0]` and `NEG[1]` select signed (1) or unsigned (0) interpretation of the packed
elements of S0 and S1; the products and the S2 addend are summed in the signed 32-bit
domain. Without CLAMP the accumulator is the pseudocode's 32-bit signed `tmp`, so the
model uses wrapping arithmetic. This is an explicit interpretation of the typed pseudocode;
the unresolved native overflow behavior is recorded in the catalogue. `dot4_eq_exact_sum`
relates the model to the exact integer sum when no overflow occurs.
-/

/--
`V_DOT4_I32_IU8`: `tmp = C; tmp += A[i] * B[i]` over the four packed 8-bit elements, with
`A[i] = NEG[0] ? signext(S0[i*8+7 : i*8]) : zeroext(...)` and likewise `B[i]` under `NEG[1]`.
-/
def v_dot4_i32_iu8 (m : Vop3P) (s0 s1 s2 : BitVec 32) : Lane32 := do
  Vop3P.dotFields "V_DOT4_I32_IU8" m
  let a := m.neg.getLsbD 0
  let b := m.neg.getLsbD 1
  let terms := (List.range 4).map fun i =>
    dotOperand a (byte32 s0 i) * dotOperand b (byte32 s1 i)
  pure (BitVec.ofInt 32 (s2.toInt + terms.sum))

/--
`V_DOT8_I32_IU4`: the same accumulation over eight packed 4-bit elements,
`A[i] = NEG[0] ? signext(S0[i*4+3 : i*4]) : zeroext(...)`.
-/
def v_dot8_i32_iu4 (m : Vop3P) (s0 s1 s2 : BitVec 32) : Lane32 := do
  Vop3P.dotFields "V_DOT8_I32_IU4" m
  let a := m.neg.getLsbD 0
  let b := m.neg.getLsbD 1
  let terms := (List.range 8).map fun i =>
    dotOperand a (nibble32 s0 i) * dotOperand b (nibble32 s1 i)
  pure (BitVec.ofInt 32 (s2.toInt + terms.sum))

/-! ## Plain-form equations

Each equation below is the meaning of the opcode's VOP2/VOP3 form with no modifier field
set, which is what the assembler emits for the bare mnemonic. They are `rfl`, and they keep
proofs from having to unfold the modifier checks.
-/

@[simp] theorem v_add_nc_u32_plain (s0 s1 : BitVec 32) :
    v_add_nc_u32 {} s0 s1 = .ok (s0 + s1) := rfl

@[simp] theorem v_sub_nc_u32_plain (s0 s1 : BitVec 32) :
    v_sub_nc_u32 {} s0 s1 = .ok (s0 - s1) := rfl

@[simp] theorem v_mul_lo_u32_plain (s0 s1 : BitVec 32) :
    v_mul_lo_u32 {} s0 s1 = .ok (s0 * s1) := rfl

@[simp] theorem v_lshlrev_b32_plain (s0 s1 : BitVec 32) :
    v_lshlrev_b32 {} s0 s1 = .ok (s1 <<< shiftCount s0) := rfl

@[simp] theorem v_lshrrev_b32_plain (s0 s1 : BitVec 32) :
    v_lshrrev_b32 {} s0 s1 = .ok (s1 >>> shiftCount s0) := rfl

@[simp] theorem v_ashrrev_i32_plain (s0 s1 : BitVec 32) :
    v_ashrrev_i32 {} s0 s1 = .ok (s1.sshiftRight (shiftCount s0)) := rfl

@[simp] theorem v_and_b32_plain (s0 s1 : BitVec 32) :
    v_and_b32 {} s0 s1 = .ok (s0 &&& s1) := rfl

@[simp] theorem v_or_b32_plain (s0 s1 : BitVec 32) :
    v_or_b32 {} s0 s1 = .ok (s0 ||| s1) := rfl

@[simp] theorem v_xor_b32_plain (s0 s1 : BitVec 32) :
    v_xor_b32 {} s0 s1 = .ok (s0 ^^^ s1) := rfl

@[simp] theorem v_lshl_or_b32_plain (s0 s1 s2 : BitVec 32) :
    v_lshl_or_b32 {} s0 s1 s2 = .ok ((s0 <<< shiftCount s1) ||| s2) := rfl

@[simp] theorem v_bfe_u32_plain (s0 s1 s2 : BitVec 32) :
    v_bfe_u32 {} s0 s1 s2
      = .ok ((s0 >>> shiftCount s1) &&& BitVec.ofNat 32 ((1 <<< shiftCount s2) - 1)) := rfl

@[simp] theorem v_perm_b32_plain (s0 s1 s2 : BitVec 32) :
    v_perm_b32 {} s0 s1 s2 =
      (let data : BitVec 64 := (s0.setWidth 64 <<< 32) ||| s1.setWidth 64
       let b (i : Nat) : BitVec 8 := bytePermute data (byte32 s2 i)
       .ok (((b 3).setWidth 32 <<< 24) ||| ((b 2).setWidth 32 <<< 16)
            ||| ((b 1).setWidth 32 <<< 8) ||| (b 0).setWidth 32)) := rfl

end Kelana.Hardware
