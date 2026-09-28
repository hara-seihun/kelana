/-
Types for the generated gfx1151 instruction catalogue.

The catalogue is an inventory of AMD RDNA 3.5 *architecture-level* instructions, generated
from the pinned machine-readable ISA. Presence in it is a claim about the architecture, not
about what the installed gfx1151 toolchain accepts and not about what Kelana can prove; those
are the separate `gfx1151Probes` and `status` fields.
-/

namespace Kelana.Hardware.Catalogue

/-- AMD's functional group for an instruction, as spelled in the XML. -/
inductive Group
  | valu | vmem | salu | branch | waveControl | smem | message | trap | «export»
deriving Repr, DecidableEq, Inhabited

def Group.name : Group → String
  | .valu => "VALU" | .vmem => "VMEM" | .salu => "SALU"
  | .branch => "BRANCH" | .waveControl => "WAVE_CONTROL" | .smem => "SMEM"
  | .message => "MESSAGE" | .trap => "TRAP" | .«export» => "EXPORT"

/-- What Kelana knows about an instruction's meaning. -/
inductive Status
  /-- Inventory only. Kelana has no Lean meaning for this instruction: composing it is not
  supported, and nothing in this repository may treat it as the identity or as an axiom. -/
  | unformalized
  /-- A lane-local `BitVec` meaning exists at `decl`, transcribed from `pseudocode`.
  `modeled` and `unmodeled` name the modifier settings the definition covers and declines. -/
  | laneBitVec (decl : String) (pseudocode : String) (modeled : String) (unmodeled : String)
deriving Repr, DecidableEq, Inhabited

/-- One recorded result of feeding an assembly form to the installed gfx1151 assembler. -/
structure Probe where
  form : String
  accepted : Bool
  detail : String
deriving Repr, DecidableEq, Inhabited

/--
An architecture-level instruction name with its provenance and Kelana's claims about it.

`signatures` and `encodings` are the deduplicated operand signatures and encoding names of
the XML record; `hardware/gfx1151/INSTRUCTIONS.md` and `catalogue.py` hold the full detail
that this summary links to rather than copies.
-/
structure Instruction where
  name : String
  group : Group
  subgroup : Option String
  aliases : Array String
  encodings : Array String
  signatures : Array String
  status : Status
  gfx1151Probes : Array Probe
deriving Repr, DecidableEq, Inhabited

/-- Source hashes and the command that regenerates the catalogue. -/
structure Provenance where
  architecture : String
  releaseDate : String
  schemaVersion : String
  isaXmlSha256 : String
  manualTextSha256 : String
  formalizationManifestSha256 : String
  eligibilityProbeSha256 : String
  command : String
  instructionCount : Nat
  encodingRecordCount : Nat
deriving Repr, DecidableEq, Inhabited

namespace Instruction

/-- Anchor of this instruction's entry in the generated Markdown index. -/
def indexEntry (i : Instruction) : String :=
  "hardware/gfx1151/INSTRUCTIONS.md#" ++ i.name.toLower

/-- Command printing the instruction's full XML record, including every encoding field. -/
def catalogueCommand (i : Instruction) : String :=
  "python3 hardware/gfx1151/catalogue.py instruction '^" ++ i.name ++ "$'"

def isFormalized (i : Instruction) : Bool :=
  match i.status with
  | .unformalized => false
  | .laneBitVec .. => true

/-- Whether the installed gfx1151 assembler was observed to accept some form of this opcode. -/
def assembledOnGfx1151 (i : Instruction) : Bool :=
  i.gfx1151Probes.any (·.accepted)

end Instruction

end Kelana.Hardware.Catalogue
