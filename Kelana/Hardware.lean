/-
Kelana's gfx1151 hardware layer.

- `Kelana.Hardware.Catalogue`: every AMD RDNA 3.5 architecture-level instruction name with
  its group, encodings, operand signatures, formalization status and recorded gfx1151
  assembler probes, generated from the pinned sources in `hardware/gfx1151/`.
- `Kelana.Hardware.IntOps`: executable lane-local `BitVec` meanings for the integer subset
  Kelana composes, transcribed from the manual's pseudocode.
- `Kelana.Hardware.Lemmas`: the packing facts and the boundary cases those meanings support.

Nothing here models EXEC, wave state, floating-point WMMA, or execution cost.
`Kelana.Hardware.Catalogue.openQuestions` carries what the sources leave unresolved.
-/
import Kelana.Hardware.Catalogue
import Kelana.Hardware.Lemmas
