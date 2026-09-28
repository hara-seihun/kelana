# gfx1151 operations

This directory owns Kelana's pinned instruction references for the Radeon 8060S, AMD target `gfx1151`. It combines the complete AMD RDNA 3.5 compute/graphics ISA inventory with the installed ROCm compiler's gfx1151 feature definitions. It does not restrict the search to WMMA or the instructions Bonsai currently uses.

## Read

- [Mathematical interpretation](MATHEMATICS.md): typed maps, word rings, floating arithmetic, state transitions, WMMA and representation-preservation equations.
- [Complete instruction index](INSTRUCTIONS.md): 1,208 canonical instruction names, descriptions and typed operand signatures, generated from AMD's XML.
- [Inventory summary](summary.json): source hash, document version and counts.
- [Lean instruction layer](lean/README.md): generates `Kelana/Hardware/Catalogue/` from the pinned XML, keeping every instruction name visible with its formalization status and its recorded gfx1151 assembler probes, and owns the modeled integer subset's provenance.
- [Compiler inventory](compiler/README.md): all six gfx1151 WMMA opcodes, wave32/wave64 forms, builtin signatures, target features and reproducible assembly probes. Its [provenance](compiler/PROVENANCE.md) identifies the installed source snapshots.
- [AMD manual](sources/rdna35-isa.pdf) and [searchable text](sources/rdna35-isa.txt): instruction semantics and pseudocode, wave behavior, modifiers, register layout and scheduling. WMMA is in section 7.9, printed pages 74–77, with per-instruction definitions in section 16.10, pages 380–383.
- [Machine-readable specification](sources/amdgpu_isa_rdna3_5.xml): the authoritative source for this catalogue. [Retrieval record](sources/isa-retrieval.json) records the URL, release and hashes. [Manual retrieval](sources/manual-retrieval.json) records the PDF source and hashes. [Documentation-page capture](sources/amd-documentation-page.json) preserves AMD's reference links.

The XML declares 47 encoding layouts, 68 data formats, 35 operand types and 5,056 instruction-encoding records. Those records include literal and operand alternatives; they are not 5,056 distinct hardware operations. Aliases also do not increase the canonical instruction count.

| Group | Instructions |
| --- | ---: |
| VALU | 508 |
| VMEM | 428 |
| SALU | 213 |
| BRANCH | 19 |
| WAVE_CONTROL | 16 |
| SMEM | 14 |
| MESSAGE | 7 |
| TRAP | 2 |
| EXPORT | 1 |

The complete list is AMD's architecture-level public instruction inventory. Compiler pseudos, assembler aliases and model-specific feature flags are different inventories. The compiler notes connect RDNA 3.5 to gfx1151 and separate newer gfx12 WMMA instructions that this device does not support. No CPU ISA or undocumented internal GPU micro-operations are included.

## Query and rebuild

`catalogue.py` uses only Python 3's standard library and reads the pinned XML, not a live URL. It checks unique names and references to encoding, format and operand definitions on every invocation.

```sh
cd hardware/gfx1151
python3 catalogue.py instruction '^V_WMMA'
python3 catalogue.py instruction 'DOT|SAD|PERM|BFE'
python3 catalogue.py format 'WMMA|IU4'
python3 catalogue.py operand '^OPR_VGPR$'
python3 catalogue.py encoding '^ENC_VOP3P$'
python3 catalogue.py summary > summary.json
python3 catalogue.py index > INSTRUCTIONS.md
```

Query results retain all attributes and children of the selected XML records. Repeated children are arrays even when there is only one. This preserves encoding conditions, implicit operands, field offsets, modifier descriptions and aliases without creating another hand-maintained ISA definition. The Markdown index abbreviates the format names and combines identical signatures; consult the JSON/XML for distinctions between encodings.

The instruction index, vendor pseudocode and mathematical notes are the current representation of the operation set. All 1,208 names are now reachable from Lean through [`lean/`](lean/README.md), each carrying an explicit status; fourteen integer VALU instructions have executable lane-local meanings and the rest are marked unformalized rather than given a convenient default. Continue formalization by adding a manifest entry with its pseudocode and modifier coverage, then state its exact hypotheses rather than assigning an unjustified ring instance to hardware arithmetic.

## Sources and updates

AMD publishes the [machine-readable ISA](https://gpuopen.com/machine-readable-isa/) and [architecture manuals](https://gpuopen.com/amd-gpu-architecture-programming-documentation/). The XML is release 2026-02-20, schema 1.1.1, and declares AMD copyright and MIT licensing. The PDF retains AMD's own notices; that XML license does not relicense the PDF. Schema documentation is maintained in [GPUOpen-Tools/isa_spec_manager](https://github.com/GPUOpen-Tools/isa_spec_manager/blob/main/documentation/spec_documentation.md).

For a source update, replace the selected RDNA 3.5 source, refresh its retrieval record and hashes, then regenerate the index and summary. Review the inventory diff and any changed semantics before revising proofs. Keep exact sources in Git so upstream `latest` and mutable compiler tags cannot silently change Kelana's meaning.

These files are research inputs, not a deployed service. The parent [Kelana README](../../README.md) owns repository custody and recovery. Python 3 generates the catalogue; `pdftotext -layout` produces the searchable manual text; installed ROCm/LLVM supplies the optional compiler probes. There are no credentials or model weights here.
