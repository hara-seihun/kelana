/-
Queries over the generated gfx1151 instruction catalogue.

`Kelana.Hardware.Catalogue.all` is the complete AMD RDNA 3.5 architecture-level instruction
inventory, generated from the pinned XML. The counts checked here are the ones the pinned
sources report: 1,208 canonical instruction names against 5,056 encoding records, which
include literal and operand variants rather than distinct operations.
-/
import Kelana.Hardware.Catalogue.Index
import Kelana.Hardware.Catalogue.Linkage

namespace Kelana.Hardware.Catalogue

def find? (name : String) : Option Instruction :=
  all.find? (·.name == name)

/-- Instructions whose functional group is `g`. -/
def group (g : Group) : Array Instruction :=
  all.filter (·.group == g)

/-- Instructions with an executable Lean meaning in `Kelana.Hardware.IntOps`. -/
def formalized : Array Instruction :=
  all.filter Instruction.isFormalized

/-- Instructions with a recorded gfx1151 assembler probe, accepted or rejected. -/
def probed : Array Instruction :=
  all.filter (!·.gfx1151Probes.isEmpty)

/-- The modifier settings each formalized instruction declines to give a meaning to. -/
def unmodeledModifiers : Array (String × String) :=
  formalized.filterMap fun i =>
    match i.status with
    | .laneBitVec _ _ _ unmodeled => some (i.name, unmodeled)
    | .unformalized => none

#guard all.size = 1208
#guard provenance.instructionCount = 1208
#guard provenance.encodingRecordCount = 5056
#guard (group .valu).size = 508
#guard (group .vmem).size = 428
#guard (group .salu).size = 213
#guard all.all (fun i => (all.filter (·.name == i.name)).size == 1)
#guard formalized.size = 14
#guard formalized.all (·.group == .valu)
#guard formalized.all Instruction.assembledOnGfx1151
#guard (find? "V_WMMA_F32_16X16X16_F16").isSome
#guard (find? "V_WMMA_F32_16X16X16_F16").all (!·.isFormalized)
#guard probed.all (fun i => i.gfx1151Probes.all (fun p => p.detail ≠ ""))

end Kelana.Hardware.Catalogue
