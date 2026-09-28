// Extracted from llvm/lib/Target/AMDGPU/VOP3PInstructions.td.
// Installed ROCm 7.2.3 source. SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Ranges: 1303-1335, 1394-1459, and 2482-2512.
class VOPProfileWMMA<VOPProfile P, string Suffix, RegisterOperand _Src01RC64, bit _HasClamp, bit _HasOpSel> : VOP3P_Profile<P> {
  let DstRC = !if(!eq(Suffix, "_w32"), VDst_256, VDst_128);
  let Src0RC64 = _Src01RC64;
  let Src1RC64 = _Src01RC64;
  let Src2RC64 = !if(!eq(Suffix, "_w32"), VISrc_256_f64, VISrc_128_f32);
  let HasClamp = _HasClamp;
  let HasOpSel = _HasOpSel;
  let IsPacked = 1;
  let IsWMMA = 1;
}

def VOP_V8F32_V16F16_V16F16_V8F32 : VOPProfile <[v8f32, v16f16, v16f16, v8f32]>;
def VOP_V8F32_V16I16_V16I16_V8F32 : VOPProfile <[v8f32, v16i16, v16i16, v8f32]>;
def VOP_V16F16_V16F16_V16F16_V16F16 : VOPProfile <[v16f16, v16f16, v16f16, v16f16]>;
def VOP_V16I16_V16I16_V16I16_V16I16 : VOPProfile <[v16i16, v16i16, v16i16, v16i16]>;
def VOP_V8I32_V4I32_V4I32_V8I32 : VOPProfile <[v8i32, v4i32, v4i32, v8i32]>;
def VOP_V8I32_V2I32_V2I32_V8I32 : VOPProfile <[v8i32, v2i32, v2i32, v8i32]>;

def VOP_V4F32_V16F16_V16F16_V4F32 : VOPProfile <[v4f32, v16f16, v16f16, v4f32]>;
def VOP_V4F32_V16I16_V16I16_V4F32 : VOPProfile <[v4f32, v16i16, v16i16, v4f32]>;
def VOP_V8F16_V16F16_V16F16_V8F16 : VOPProfile <[v8f16, v16f16, v16f16, v8f16]>;
def VOP_V8I16_V16I16_V16I16_V8I16 : VOPProfile <[v8i16, v16i16, v16i16, v8i16]>;
def VOP_V4I32_V2I32_V2I32_V4I32 : VOPProfile <[v4i32, v2i32, v2i32, v4i32]>;


class WMMAType <bits<2> val> {
  bit hasClamp = val{0};
  bit hasOpsel = val{1};
}

def WMMARegular      : WMMAType<0b00>;
def WMMAUIClamp      : WMMAType<0b01>;
def WMMAOpSel        : WMMAType<0b10>;

// ----- pseudo definitions and operand profiles -----
// The WMMA instruction has extra constraints:
// Matrices A and B cannot overlap with D. C cannot partially overlap with D,
// but it is OK for them to be the same (which is a typical case).
//
// We implement it as follows:
// 1) Map the intrinsic to the pseudo where D is tied to C ($vdst = $src2).
// 2) The pass twoaddressinstruction checks if src2 is live and if that is the case
//    it converts the default pseudo to the pseudo where src2 is not the same as vdst.
// 3) @earlyclobber on the destination satisfies the constraint during RA.

multiclass WMMAInst<string Suffix, string Instr, VOPProfile P, SDPatternOperator node = null_frag, RegisterOperand _Src01RC64 = VRegSrc_256, WMMAType Type, bit convertibleTo3Addr> {

  defvar WMMAConstraints2Addr = "@earlyclobber $vdst,$vdst = $src2";
  defvar WMMAConstraints3Addr = "@earlyclobber $vdst";

  defvar WMMAProfile = VOPProfileWMMA<P, Suffix, _Src01RC64, Type.hasClamp, Type.hasOpsel>;
  let Mnemonic = Instr, mayRaiseFPException = 0, ReadsModeReg = 0 in {
    let Constraints = WMMAConstraints2Addr, isConvertibleToThreeAddress = convertibleTo3Addr in {
      def _twoaddr # Suffix : VOP3P_Pseudo<Instr # Suffix, WMMAProfile>;
    }
  }
  if convertibleTo3Addr then {
    let Mnemonic = Instr, mayRaiseFPException = 0, ReadsModeReg = 0 in {
      let Constraints = WMMAConstraints3Addr, SchedRW = [Write32Bit, Write32Bit] in {
        def _threeaddr # Suffix : VOP3P_Pseudo<Instr # Suffix, WMMAProfile>;
      }
    }
    def : WMMAOpcodeMapping<!cast<Instruction>(NAME # _twoaddr # Suffix),
                          !cast<Instruction>(NAME # _threeaddr # Suffix)>;
  }

  let SubtargetPredicate = isGFX11Only in {
    if !eq(Type, WMMAOpSel) then {
      def : WMMAOpSelPat<!cast<Instruction>(NAME # _twoaddr # Suffix), node, P>;
    } else if !eq(Type, WMMAUIClamp) then {
      def : WMMAUIClampPat<!cast<Instruction>(NAME # _twoaddr # Suffix), node, P>;
    } else {
      def : WMMARegularPat<!cast<Instruction>(NAME # _twoaddr # Suffix), node, P>;
    }
  }
}



let WaveSizePredicate = isWave32 in {
  defm V_WMMA_F32_16X16X16_F16   : WMMAInst<"_w32", "v_wmma_f32_16x16x16_f16",  VOP_V8F32_V16F16_V16F16_V8F32, int_amdgcn_wmma_f32_16x16x16_f16, VRegSrc_256, WMMARegular, 1>;
  defm V_WMMA_F32_16X16X16_BF16  : WMMAInst<"_w32", "v_wmma_f32_16x16x16_bf16", VOP_V8F32_V16I16_V16I16_V8F32, int_amdgcn_wmma_f32_16x16x16_bf16, VRegSrc_256, WMMARegular, 1>;
  defm V_WMMA_F16_16X16X16_F16   : WMMAInst<"_w32", "v_wmma_f16_16x16x16_f16",   VOP_V16F16_V16F16_V16F16_V16F16, int_amdgcn_wmma_f16_16x16x16_f16, VRegSrc_256, WMMAOpSel, 1>;
  defm V_WMMA_BF16_16X16X16_BF16 : WMMAInst<"_w32", "v_wmma_bf16_16x16x16_bf16", VOP_V16I16_V16I16_V16I16_V16I16, int_amdgcn_wmma_bf16_16x16x16_bf16, VRegSrc_256, WMMAOpSel, 1>;
  defm V_WMMA_F16_16X16X16_F16_TIED   : WMMAInst<"_w32", "v_wmma_f16_16x16x16_f16",   VOP_V16F16_V16F16_V16F16_V16F16, int_amdgcn_wmma_f16_16x16x16_f16_tied, VRegSrc_256, WMMAOpSel, 0>;
  defm V_WMMA_BF16_16X16X16_BF16_TIED : WMMAInst<"_w32", "v_wmma_bf16_16x16x16_bf16", VOP_V16I16_V16I16_V16I16_V16I16, int_amdgcn_wmma_bf16_16x16x16_bf16_tied, VRegSrc_256, WMMAOpSel, 0>;
  defm V_WMMA_I32_16X16X16_IU8   : WMMAInst<"_w32", "v_wmma_i32_16x16x16_iu8",   VOP_V8I32_V4I32_V4I32_V8I32, int_amdgcn_wmma_i32_16x16x16_iu8, VRegSrc_128, WMMAUIClamp, 1>;
  defm V_WMMA_I32_16X16X16_IU4   : WMMAInst<"_w32", "v_wmma_i32_16x16x16_iu4",   VOP_V8I32_V2I32_V2I32_V8I32, int_amdgcn_wmma_i32_16x16x16_iu4, VRegSrc_64,  WMMAUIClamp, 1>;
}

let WaveSizePredicate = isWave64 in {
  defm V_WMMA_F32_16X16X16_F16   : WMMAInst<"_w64", "v_wmma_f32_16x16x16_f16",   VOP_V4F32_V16F16_V16F16_V4F32, int_amdgcn_wmma_f32_16x16x16_f16, VRegSrc_256, WMMARegular, 1>;
  defm V_WMMA_F32_16X16X16_BF16  : WMMAInst<"_w64", "v_wmma_f32_16x16x16_bf16",  VOP_V4F32_V16I16_V16I16_V4F32, int_amdgcn_wmma_f32_16x16x16_bf16, VRegSrc_256, WMMARegular, 1>;
  defm V_WMMA_F16_16X16X16_F16   : WMMAInst<"_w64", "v_wmma_f16_16x16x16_f16",   VOP_V8F16_V16F16_V16F16_V8F16, int_amdgcn_wmma_f16_16x16x16_f16, VRegSrc_256, WMMAOpSel, 1>;
  defm V_WMMA_BF16_16X16X16_BF16 : WMMAInst<"_w64", "v_wmma_bf16_16x16x16_bf16", VOP_V8I16_V16I16_V16I16_V8I16, int_amdgcn_wmma_bf16_16x16x16_bf16, VRegSrc_256, WMMAOpSel, 1>;
  defm V_WMMA_F16_16X16X16_F16_TIED   : WMMAInst<"_w64", "v_wmma_f16_16x16x16_f16",   VOP_V8F16_V16F16_V16F16_V8F16, int_amdgcn_wmma_f16_16x16x16_f16_tied, VRegSrc_256, WMMAOpSel, 0>;
  defm V_WMMA_BF16_16X16X16_BF16_TIED : WMMAInst<"_w64", "v_wmma_bf16_16x16x16_bf16", VOP_V8I16_V16I16_V16I16_V8I16, int_amdgcn_wmma_bf16_16x16x16_bf16_tied, VRegSrc_256, WMMAOpSel, 0>;
  defm V_WMMA_I32_16X16X16_IU8   : WMMAInst<"_w64", "v_wmma_i32_16x16x16_iu8",   VOP_V4I32_V4I32_V4I32_V4I32, int_amdgcn_wmma_i32_16x16x16_iu8, VRegSrc_128, WMMAUIClamp, 1>;
  defm V_WMMA_I32_16X16X16_IU4   : WMMAInst<"_w64", "v_wmma_i32_16x16x16_iu4",   VOP_V4I32_V2I32_V2I32_V4I32, int_amdgcn_wmma_i32_16x16x16_iu4, VRegSrc_64, WMMAUIClamp, 1>;

}

// ----- GFX11 real encodings -----
//===----------------------------------------------------------------------===//
// GFX11
//===----------------------------------------------------------------------===//

multiclass VOP3P_Real_gfx11_gfx12<bits<8> op> :
   VOP3P_Real_Base<GFX11Gen, op>, VOP3P_Real_Base<GFX12Gen, op>;

defm V_DOT4_I32_IU8  : VOP3P_Real_gfx11_gfx12<0x16>;
defm V_DOT8_I32_IU4  : VOP3P_Real_gfx11_gfx12<0x18>;
defm V_DOT2_F32_BF16 : VOP3P_Realtriple_gfx11_gfx12<0x1a>;

let AssemblerPredicate = isGFX11Plus in {
  def : AMDGPUMnemonicAlias<"v_dot4_i32_i8", "v_dot4_i32_iu8">;
  def : AMDGPUMnemonicAlias<"v_dot8_i32_i4", "v_dot8_i32_iu4">;
}

multiclass VOP3P_Real_WMMA <bits<8> op> {
  let WaveSizePredicate = isWave32, DecoderNamespace = "GFX11" in {
    defm _twoaddr_w32 : VOP3P_Real_Base <GFX11Gen, op>;
  }
  let WaveSizePredicate = isWave64, DecoderNamespace = "GFX11W64" in {
    defm _twoaddr_w64 : VOP3P_Real_Base <GFX11Gen, op>;
  }
}

defm V_WMMA_F32_16X16X16_F16   : VOP3P_Real_WMMA <0x040>;
defm V_WMMA_F32_16X16X16_BF16  : VOP3P_Real_WMMA <0x041>;
defm V_WMMA_F16_16X16X16_F16   : VOP3P_Real_WMMA <0x042>;
defm V_WMMA_BF16_16X16X16_BF16 : VOP3P_Real_WMMA <0x043>;
defm V_WMMA_I32_16X16X16_IU8   : VOP3P_Real_WMMA <0x044>;
defm V_WMMA_I32_16X16X16_IU4   : VOP3P_Real_WMMA <0x045>;
