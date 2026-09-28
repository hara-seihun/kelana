# Unit-cycle cost evidence

The current proofs use symbolic instruction charges. A numerical all-ISA unit-cycle optimum is not established. Under the current [problem definition](PROBLEM.md), weights remain inputs and loading/conversion is part of the graph. The kernel-only comparisons below exclude preparation explicitly; the finite-run bill adds it once per loaded weight version. The selected infinite-reuse objective gives every finite one-time preparation cost zero weight, while retaining all recurring work and representation-storage constraints.

## What the pinned sources provide

The [AMD ISA manual](../hardware/gfx1151/sources/rdna35-isa.pdf), section 7.9, defines the six WMMA matrix operations, layouts and modifiers. Section 7.9.1 defines scheduling hazards, including the required independent VALU instruction or V_NOP between a result D and a following A/B use. Those rules establish legality, not a complete resource-occupation table.

The installed LLVM source at `/nix/store/zisvx5002pwvnf87rpcpizy78s78ggd4-llvm-src-22.0.0-rocm/llvm/lib/Target/AMDGPU/` supplies compiler scheduling estimates. Its package and upstream provenance are in the [compiler record](../hardware/gfx1151/compiler/PROVENANCE.md).

- `GCNProcessors.td`, lines 291–303, maps gfx1151 and its GFX11.5 neighbors to `GFX11SpeedModel`.
- `SISchedule.td`, lines 140–146, defines `HWWriteRes` by assigning its integer argument to `Latency`, not resource occupancy.
- Lines 406–437 define the GFX11 model. `Write32Bit` has latency 5, `WriteIntMul` latency 8, both referencing `HWVALU` and `HWRC`. These are not five or eight occupied ALU unit-cycles.
- `VOP3PInstructions.td`, lines 1404–1418, defines GFX11 WMMA pseudos; the three-address variant uses two `Write32Bit` scheduling writes. That is not a physical two-cycle WMMA cost theorem.
- Later `Write4PassWMMA`, `Write8PassWMMA` and XDL scheduling entries belong to newer model scopes. Their attractive numbers cannot be copied into gfx1151's cost model.

Compiler scheduling metadata therefore cannot simply be relabeled as measured execution-unit cycles. The source itself questions resource counts and describes some scheduling estimates as approximate. We retain symbolic W8, W4 and per-VALU charges rather than invent a cycle table.

## Current comparisons

For two all-ternary tiles sharing activations, radix-64 fusion has the symbolic online bill `W8 + 24V` after weight-only preparation moves offline. Two ordinary IU8 calls cost `2W8` under the same boundary. The fusion saves charged work precisely when the avoided W8 exceeds decoding and any other dynamic differences. No numeric inequality has been established here.

For arbitrary int8 activations, the exact two-IU4 construction costs `2W4 + 8Vshiftadd`, plus dynamic activation-layout work. A predecoded IU8 baseline costs W8. Narrower register fragments are not a proof that the first bill is smaller.

The three-stream peel replaces 42 isolated word operations with 38 across six source bytes, but packed-16 operations and ordinary word operations need not share charges. Output gathering remains online. Input repacking becomes offline under the [staged objective](PROBLEM.md).

## Remaining evidence

A physical unit-cycle model needs per-resource service demand, issue restrictions and wave-mode effects for the admitted instruction set. Reciprocal-throughput measurements or a documented hardware service model may supply some charges; result latency alone does not. Such measurements are not part of the current proof bundle. The next lower-bound theorem must name the cost model explicitly.
