/-
Modifier records and the lane-result type shared by Kelana's gfx1151 instruction meanings.

Every meaning in `Kelana.Hardware.IntOps` is a *lane-local* function: it maps the source
values seen by one lane to the value that lane writes. It says nothing about EXEC, about
which lanes execute, about VCC or the status registers, about lane-crossing data movement
(DPP, SDWA, permlane), or about the whole-wave state transition.

A modifier configuration this layer does not model produces `Except.error`, never a
silently inherited result. The reason string names the field and the source-level question
that would have to be answered to model it.
-/

namespace Kelana.Hardware

/-- A modifier configuration, or an architectural effect, that Kelana does not model. -/
structure Unmodeled where
  instruction : String
  field : String
  reason : String
deriving Repr, DecidableEq, Inhabited

/-- The value one lane writes, or the reason this layer declines to give it a meaning. -/
abbrev Lane (α : Type) := Except Unmodeled α

deriving instance DecidableEq for Except

/-- Lane result of a 32-bit VALU destination. -/
abbrev Lane32 := Lane (BitVec 32)

/--
Modifier fields of `ENC_VOP3` (RDNA 3.5 manual, section 7.1: ABS, CLAMP, NEG, OMOD, OP_SEL),
plus a flag for the DPP8/DPP16 forms of the same opcode.

All-default is the `ENC_VOP2` behavior of the same opcode: VOP2 carries no modifier fields.
-/
structure Vop3 where
  clamp : Bool := false
  omod : BitVec 2 := 0
  neg : BitVec 3 := 0
  abs : BitVec 3 := 0
  opSel : BitVec 4 := 0
  dpp : Bool := false
deriving Repr, DecidableEq, Inhabited

/--
Modifier fields of `ENC_VOP3P` (CLAMP, NEG, NEG_HI, OP_SEL, OP_SEL_HI).

The defaults are the fields the installed assembler emits for a bare VOP3P dot instruction:
`llvm-mc -arch=amdgcn -mcpu=gfx1151` encodes `v_dot4_i32_iu8 v0, v1, v2, v3` as
`[0x00,0x40,0x16,0xcc,0x01,0x05,0x0e,0x1c]`, i.e. OP_SEL_HI = 0b111 with every other
modifier field clear.
-/
structure Vop3P where
  clamp : Bool := false
  neg : BitVec 3 := 0
  negHi : BitVec 3 := 0
  opSel : BitVec 3 := 0
  opSelHi : BitVec 3 := 7
deriving Repr, DecidableEq, Inhabited

namespace Vop3

/--
Reject the VOP3 input modifiers and the lane-crossing forms.

ABS/NEG/OMOD are defined for floating-point operands only ("NEG, ABS, and OMOD fields (for
floating point only)", section 7.1), OP_SEL "may only be used for 16-bit operands, and must
be zero for any other operands/results", and DPP selects another lane's data, which a
lane-local function cannot express.
-/
def integerFields (insn : String) (m : Vop3) : Lane Unit :=
  if m.dpp then
    .error ⟨insn, "DPP", "DPP8/DPP16 read another lane's source; this layer is lane-local"⟩
  else if m.neg ≠ 0 then
    .error ⟨insn, "NEG", "NEG is defined for floating-point operands only"⟩
  else if m.abs ≠ 0 then
    .error ⟨insn, "ABS", "ABS is defined for floating-point operands only"⟩
  else if m.omod ≠ 0 then
    .error ⟨insn, "OMOD", "OMOD is defined for floating-point operands only"⟩
  else if m.opSel ≠ 0 then
    .error ⟨insn, "OP_SEL", "OP_SEL must be zero for operands that are not 16-bit"⟩
  else
    .ok ()

/-- Additionally reject CLAMP, for opcodes whose assembler form has no clamp operand. -/
def noModifiers (insn : String) (m : Vop3) : Lane Unit := do
  integerFields insn m
  if m.clamp then
    .error ⟨insn, "CLAMP", "this opcode has no clamp form; the gfx1151 assembler rejects it"⟩
  else
    .ok ()

end Vop3

namespace Vop3P

/--
Reject the VOP3P fields whose effect on the 32-bit-source dot opcodes the manual does not
define, and CLAMP, whose position relative to the 32-bit accumulate is not defined either.

Section 7.5 lists OP_SEL/OP_SEL_HI as present "on src0/1" for `DOT4_I32_IU8` and
`DOT8_I32_IU4` while the section 16.10 pseudocode reads all 32 bits of S0 and S1 with no
OP_SEL term, so only the assembler's default field values are modeled. NEG[0] and NEG[1]
are the documented signedness controls; NEG[2] and NEG_HI appear in no dot pseudocode.
-/
def dotFields (insn : String) (m : Vop3P) : Lane Unit :=
  if m.clamp then
    .error ⟨insn, "CLAMP",
      "the dot pseudocode does not say whether saturation applies to an exact sum or to the wrapped 32-bit accumulate"⟩
  else if m.neg.getLsbD 2 then
    .error ⟨insn, "NEG[2]", "the dot pseudocode uses NEG[0] and NEG[1] only"⟩
  else if m.negHi ≠ 0 then
    .error ⟨insn, "NEG_HI", "NEG_HI does not appear in the dot pseudocode"⟩
  else if m.opSel ≠ 0 then
    .error ⟨insn, "OP_SEL", "the dot pseudocode has no OP_SEL term; only the assembler default 0 is modeled"⟩
  else if m.opSelHi ≠ 7 then
    .error ⟨insn, "OP_SEL_HI", "the dot pseudocode has no OP_SEL_HI term; only the assembler default 0b111 is modeled"⟩
  else
    .ok ()

end Vop3P

end Kelana.Hardware
