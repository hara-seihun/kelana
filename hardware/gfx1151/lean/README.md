# Lean instruction layer

Generates Kelana's Lean view of the gfx1151 instruction set from the pinned sources in the
parent directory. Two claims live here and stay separate: what AMD's RDNA 3.5 architecture
contains, and what this machine's toolchain accepts for `gfx1151`.

## What is generated

`generate.py` reads [`../sources/amdgpu_isa_rdna3_5.xml`](../sources/amdgpu_isa_rdna3_5.xml),
[`formalization.json`](formalization.json) and [`eligibility.json`](eligibility.json), and writes
`Kelana/Hardware/Catalogue/{VALU,VMEM,SALU,Other,Index,Linkage}.lean`. All 1,208 canonical
instruction names appear there with their functional group, aliases, encoding names and
deduplicated operand signatures, so an operation Kelana has no meaning for is still visible by
name from Lean. Full operand records stay in the XML behind
`Instruction.catalogueCommand`; the Lean records carry the link, not a second copy.

Every entry carries a status. `Status.unformalized` is the default and means exactly that
Kelana does not know what the instruction computes: no identity, no axiom, no placeholder.
`Status.laneBitVec` names the Lean declaration, the pseudocode line it transcribes, and the
modifier settings it covers and declines. `Linkage.lean` elaborates a reference to each named
declaration, so a status entry cannot survive the deletion or renaming of its meaning.

```sh
python3 hardware/gfx1151/lean/generate.py          # rewrite the Lean modules
python3 hardware/gfx1151/lean/generate.py --check  # fail if they are stale
hardware/gfx1151/lean/probe-eligibility.sh         # re-record the assembler probes
lake build Kelana.Hardware                         # ~1s from clean caches
```

`Catalogue.provenance` carries the XML, manual, manifest and probe SHA-256 hashes along with
the regeneration command, so a source update that changes meaning cannot pass unnoticed:
change a source, regenerate, and the recorded hash moves with it.

## Architecture inventory is not gfx1151 eligibility

Presence in the catalogue is an architecture-level claim from AMD's machine-readable ISA.
Whether this machine's assembler accepts a form is a separate observation, recorded by
`probe-eligibility.sh` feeding each line of [`forms.txt`](forms.txt) to `llvm-mc -mcpu=gfx1151`
and keeping the encoding bytes or the diagnostic. An instruction with no probe has an empty
`gfx1151Probes`, which claims nothing either way.

Rejections are evidence too. `v_mul_lo_u32 ... clamp` and `v_and_b32_e64 ... clamp` are
rejected, which is why the Lean meanings for those opcodes refuse a set CLAMP field instead of
quietly computing the unclamped result. The compiler-side inventory of gfx1151 WMMA opcodes,
target features and builtins is in [`../compiler/README.md`](../compiler/README.md).

## Meanings

[`Kelana/Hardware/IntOps.lean`](../../../Kelana/Hardware/IntOps.lean) holds lane-local `BitVec`
meanings for fourteen integer VALU instructions: no-carry add and subtract, low-word multiply,
the three reversed shifts, the three bitwise operations, fused shift-or, unsigned bitfield
extract, byte permute, and the signed/unsigned `DOT4_I32_IU8` and `DOT8_I32_IU4`. Each is a
function from one lane's sources to the value that lane writes. EXEC, VCC, status flags,
exceptions, lane-crossing modifiers and execution cost are outside the model, and a modifier
configuration outside the model returns `Except.error` naming the field.

[`Kelana/Hardware/Lemmas.lean`](../../../Kelana/Hardware/Lemmas.lean) holds the packing
facts Kelana needs and small concrete cases transcribed from the pseudocode by hand, including
the masked shift counts, the five-bit bitfield width, and the `V_PERM_B32` selector constants.
`plain_add_sub_cancels` gives a compositional law of the unclamped modular profile; a clamped
counterexample shows why the opcode name alone is not enough. The packing lemmas use explicit
bit-level kernel proofs, without native SAT-checker axioms. `research/Audit.lean` lists the
axioms used by the exported packing and composition theorems.

## Unresolved

`Catalogue.openQuestions` carries them in Lean, and `formalization.json` is their source. They
include the undefined effect of OP_SEL/OP_SEL_HI on the 32-bit-source dot opcodes, CLAMP on
those opcodes, and the measured behavior of native F16 WMMA on this part: it returns
-1.000000119 where the exact result is -1, so its floating-point semantics and error bound are
open and no Lean definition here claims otherwise. Execution cost is not modeled; on this part
the IU8 and F16 WMMA issue at the same rate, so instruction counts do not predict it.
