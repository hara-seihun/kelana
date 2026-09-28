# gfx1151 in LLVM and ROCm

The installed ROCm 7.2.3 compiler treats `gfx1151` as GFX11.5.1. Its WMMA instruction set is the six original GFX11 opcodes. There is no gfx1151-only WMMA opcode or operand form in LLVM.

## Hardware WMMA inventory

Every instruction computes the collective matrix operation `D = A * B + C` with shape `16x16x16`. The opcode is an 8-bit field in an 8-byte VOP3P instruction.

| Assembly mnemonic | Opcode | A and B values | C and D values | Wave32 VGPR spans `D,A,B,C` | Wave64 VGPR spans `D,A,B,C` |
|---|---:|---|---|---|---|
| `v_wmma_f32_16x16x16_f16` | `0x40` | f16 | f32 | `8,8,8,8` | `4,8,8,4` |
| `v_wmma_f32_16x16x16_bf16` | `0x41` | bf16 payloads | f32 | `8,8,8,8` | `4,8,8,4` |
| `v_wmma_f16_16x16x16_f16` | `0x42` | f16 | f16 | `8,8,8,8` | `4,8,8,4` |
| `v_wmma_bf16_16x16x16_bf16` | `0x43` | bf16 payloads | bf16 payloads | `8,8,8,8` | `4,8,8,4` |
| `v_wmma_i32_16x16x16_iu8` | `0x44` | packed i8 or u8 | i32 | `8,4,4,8` | `4,4,4,4` |
| `v_wmma_i32_16x16x16_iu4` | `0x45` | packed i4 or u4 | i32 | `8,2,2,8` | `4,2,2,4` |

Wave32 and wave64 use the same mnemonic and instruction encoding. The active wave mode changes the legal destination and accumulator tuple width. `_w32` and `_w64` are compiler builtin and internal pseudo suffixes, not assembly suffixes.

A and B must be VGPR tuples. C can be a VGPR tuple or a legal inline value. LLVM marks D as early-clobber. A and B cannot overlap D. C may equal D or be separate, but it cannot partially overlap D.

The floating forms expose packed `neg_lo` and `neg_hi` input modifiers. Opcodes `0x42` and `0x43` also use `op_sel` to choose a 16-bit half. The integer forms reuse the A and B modifier bits as independent signedness controls and expose `clamp`. Clang presents these controls as immediate `bool` arguments rather than separate mnemonics.

## Clang builtin types

The table below rewrites Clang's compact builtin type strings into C-like types. `short` carries bf16 bits in these GFX11 builtins. The type does not mean an integer matrix multiplication.

| Operation | Wave32 signature | Wave64 signature |
|---|---|---|
| f16 to f32 | `float8 (half16 A, half16 B, float8 C)` | `float4 (half16 A, half16 B, float4 C)` |
| bf16 to f32 | `float8 (short16 A, short16 B, float8 C)` | `float4 (short16 A, short16 B, float4 C)` |
| f16 to f16 | `half16 (half16 A, half16 B, half16 C, bool high)` | `half8 (half16 A, half16 B, half8 C, bool high)` |
| bf16 to bf16 | `short16 (short16 A, short16 B, short16 C, bool high)` | `short8 (short16 A, short16 B, short8 C, bool high)` |
| iu8 to i32 | `int8 (bool signA, int4 A, bool signB, int4 B, int8 C, bool clamp)` | `int4 (bool signA, int4 A, bool signB, int4 B, int4 C, bool clamp)` |
| iu4 to i32 | `int8 (bool signA, int2 A, bool signB, int2 B, int8 C, bool clamp)` | `int4 (bool signA, int2 A, bool signB, int2 B, int4 C, bool clamp)` |

Clang defines 16 gfx11 WMMA builtin names:

- six operations with a `_w32` suffix
- the same six with a `_w64` suffix
- `_tied_w32` and `_tied_w64` variants for each of the f16-result and bf16-result operations

The four `tied` builtins do not name new hardware instructions. They select the same `0x42` or `0x43` encoding while telling LLVM that D reuses C. For a tied 16-bit operation, the unselected register half is preserved from C. The ordinary intrinsic leaves that half undefined.

## Pseudos and real encodings

LLVM creates wave-specific `_twoaddr` and `_threeaddr` machine pseudos for register allocation:

- `_twoaddr` ties D to C, the common accumulate-in-place form.
- `_threeaddr` permits separate D and C tuples.
- both lower to the one real opcode listed above.
- the `tied` intrinsic only creates the tied pseudo.

None of those internal names is an assembler alias. The public assembler accepts only the six unsuffixed mnemonics.

The many FP8, BF8, `16x16x32`, sparse `v_swmmac_*`, scaled, and mixed-format WMMA definitions visible later in current LLVM's `VOP3PInstructions.td` are gated by `gfx12-insts` or `gfx1250-insts`. They are not gfx1151 operations. The installed assembler rejects an FP8 WMMA and a `v_swmmac_*` probe for `-mcpu=gfx1151`.

## gfx1151 target features

`GCNProcessors.td` maps `gfx1151` to `FeatureISAVersion11_5_1`. That set consists of the shared GFX11 features, the GFX11.5 additions, and two model additions.

The GFX11.5 additions are:

- scalar ALU floating-point instructions
- SGPR source 1 for DPP instructions
- required export-priority handling

GFX11.5.1 then adds:

- `allocate1_5xvgprs`, described by LLVM as 50 percent more physical VGPRs and a 50 percent larger allocation granule
- point-sampling acceleration

This separates the nearby models:

| CPU | Difference from GFX11.5 common |
|---|---|
| `gfx1150` | point-sampling acceleration |
| `gfx1151` | point-sampling acceleration and 1.5x VGPR allocation |
| `gfx1152` | point-sampling acceleration |
| `gfx1153` | no additions |

`gfx11-generic` is deliberately conservative. LLVM adds several GFX11.0 workarounds and requires code object v6 for that target. It should not be read as the exact gfx1151 feature list.

None of the gfx1151 model additions gates WMMA. The six WMMA encodings require GFX11 and a matching wave-size feature, so their compiler inventory is the same on `gfx1100` and `gfx1151`. The checked assembly examples emit identical bytes on both CPUs. Clang defaults gfx1151 to wave32 and defines `__GFX11__`, not a separate `__GFX1151__` macro.

## Files

- `wmma-wave32.s` and `wmma-wave64.s` contain one legal instance of each hardware opcode.
- `probe-wmma.sh` assembles both sets, compares gfx1151 with gfx1100, checks opcodes `0x40` through `0x45`, and checks three rejected non-gfx1151 forms.
- `source-excerpts/` holds the short installed-source ranges behind the inventory.
- `PROVENANCE.md` records package paths, source hashes, and upstream URLs.

Run the probe with:

```sh
hardware/gfx1151/compiler/probe-wmma.sh
```
