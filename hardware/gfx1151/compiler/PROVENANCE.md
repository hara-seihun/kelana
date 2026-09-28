# Source provenance

## Installed compiler

The inventory uses the ROCm LLVM tools installed on this host:

- `llvm-mc`: `/nix/store/ycryi9hkqjvc3b5zsdv64cj5md8mmx2q-llvm-22.0.0-rocm/bin/llvm-mc`
- version banner: `AOMP-18.0-12`, LLVM `22.0.0`
- banner source ID: `18.0-12-ce1873ac686bb90ddec72bb99889a4e80e2de382`
- ROCm Clang: `/nix/store/r5qz2q0hmgvxzv1xf06k0cf8f6vmml4w-rocm-toolchain/bin/clang`
- Clang banner: `nixpkgs-AMD clang version 22.0.0`, ROCm `7.2.3`

The installed package's exact source outputs are:

- LLVM: `/nix/store/zisvx5002pwvnf87rpcpizy78s78ggd4-llvm-src-22.0.0-rocm`
- Clang: `/nix/store/xgh4010d397sn8nw2bgjsbbv2ca1fgni-clang-src-22.0.0-rocm`

The Nix derivations identify those outputs as the sources of the installed LLVM and Clang packages. The extracts in `source-excerpts/` came from those paths, not from a later web snapshot.

## Files and hashes

| Source file | SHA-256 |
|---|---|
| `llvm/lib/Target/AMDGPU/GCNProcessors.td` | `c063a962d2e7924b949c335d38365113351eb1dc50a53c432f2e61c87f461009` |
| `llvm/lib/Target/AMDGPU/AMDGPU.td` | `8d35dffa25414ccfd74f61e11a4266298b3d255fa1df857db113ba547ffb289b` |
| `llvm/lib/Target/AMDGPU/VOP3PInstructions.td` | `9916f0622335522c5bf8dc46092220c55ed73e57ac8dd0e07a6790f49dede40a` |
| `llvm/include/llvm/IR/IntrinsicsAMDGPU.td` | `40a1ebc80a008f44ee76de433aa13c05b50a3f5b18949f8dfd2880a5a492ea26` |
| `clang/include/clang/Basic/BuiltinsAMDGPU.def` | `6721af8307cee68e181b40676567f30f75ffe28121c6b92f34f3363e32ca4898` |

Upstream locations:

- <https://github.com/ROCm/llvm-project/blob/rocm-7.2.3/llvm/lib/Target/AMDGPU/GCNProcessors.td>
- <https://github.com/ROCm/llvm-project/blob/rocm-7.2.3/llvm/lib/Target/AMDGPU/AMDGPU.td>
- <https://github.com/ROCm/llvm-project/blob/rocm-7.2.3/llvm/lib/Target/AMDGPU/VOP3PInstructions.td>
- <https://github.com/ROCm/llvm-project/blob/rocm-7.2.3/llvm/include/llvm/IR/IntrinsicsAMDGPU.td>
- <https://github.com/ROCm/llvm-project/blob/rocm-7.2.3/clang/include/clang/Basic/BuiltinsAMDGPU.def>
- <https://github.com/ROCm/llvm-project/blob/rocm-7.2.3/llvm/test/MC/AMDGPU/gfx11_asm_wmma.s>

On inspection, the annotated upstream tag `rocm-7.2.3` resolved through tag object `c63a5877f16a2ef3fbc251013ffa91b468fc4039` to commit `f58b06dce1f9c15707c5f808fd002e18c2accf7e`. Its files were not byte-identical to the installed Nix source snapshot. The conclusions here follow the installed source and installed binaries. The upstream URLs remain useful for context, but they do not define this machine's compiler bit for bit.

All copied LLVM and Clang excerpts retain the upstream `Apache-2.0 WITH LLVM-exception` identifier.
