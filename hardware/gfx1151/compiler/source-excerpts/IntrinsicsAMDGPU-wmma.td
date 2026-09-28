// Extracted from llvm/include/llvm/IR/IntrinsicsAMDGPU.td lines 2959-3023.
// Installed ROCm 7.2.3 source. SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// WMMA (Wave Matrix Multiply-Accumulate) intrinsics
//
// These operations perform a matrix multiplication and accumulation of
// the form: D = A * B + C .

class AMDGPUWmmaIntrinsic<LLVMType AB, LLVMType CD> :
  Intrinsic<
    [CD], // %D
    [
      AB,               // %A
      LLVMMatchType<1>, // %B
      LLVMMatchType<0>, // %C
    ],
    [IntrNoMem, IntrConvergent, IntrWillReturn, IntrNoCallback, IntrNoFree]
>;

class AMDGPUWmmaIntrinsicOPSEL<LLVMType AB, LLVMType CD> :
  Intrinsic<
    [CD], // %D
    [
      AB,               // %A
      LLVMMatchType<1>, // %B
      LLVMMatchType<0>, // %C
      llvm_i1_ty,       // %high (op_sel) for GFX11, 0 for GFX12
    ],
    [IntrNoMem, IntrConvergent, ImmArg<ArgIndex<3>>, IntrWillReturn, IntrNoCallback, IntrNoFree]
>;

class AMDGPUWmmaIntrinsicIU<LLVMType AB, LLVMType CD> :
  Intrinsic<
    [CD], // %D
    [
      llvm_i1_ty,       // %A_sign
      AB,               // %A
      llvm_i1_ty,       // %B_sign
      LLVMMatchType<1>, // %B
      LLVMMatchType<0>, // %C
      llvm_i1_ty,       // %clamp
    ],
    [IntrNoMem, IntrConvergent, ImmArg<ArgIndex<0>>, ImmArg<ArgIndex<2>>, ImmArg<ArgIndex<5>>, IntrWillReturn, IntrNoCallback, IntrNoFree]
>;

// WMMA GFX11Only

// The OPSEL intrinsics read from and write to one half of the registers, selected by the op_sel bit.
// The tied versions of the f16/bf16 wmma intrinsics tie the destination matrix registers to the input accumulator registers.
// The content of the other 16-bit half is preserved from the input.

defset list<Intrinsic> AMDGPUWMMAIntrinsicsGFX11 = {
def int_amdgcn_wmma_f16_16x16x16_f16_tied   : AMDGPUWmmaIntrinsicOPSEL<llvm_anyfloat_ty, llvm_anyfloat_ty>;
def int_amdgcn_wmma_bf16_16x16x16_bf16_tied : AMDGPUWmmaIntrinsicOPSEL<llvm_anyint_ty, llvm_anyint_ty>;

// WMMA GFX11Plus

def int_amdgcn_wmma_f32_16x16x16_f16   : AMDGPUWmmaIntrinsic<llvm_anyfloat_ty, llvm_anyfloat_ty>;
def int_amdgcn_wmma_f32_16x16x16_bf16  : AMDGPUWmmaIntrinsic<llvm_anyint_ty, llvm_anyfloat_ty>;
def int_amdgcn_wmma_i32_16x16x16_iu8   : AMDGPUWmmaIntrinsicIU<llvm_anyint_ty, llvm_anyint_ty>;
def int_amdgcn_wmma_i32_16x16x16_iu4   : AMDGPUWmmaIntrinsicIU<llvm_anyint_ty, llvm_anyint_ty>;

// GFX11: The OPSEL intrinsics read from and write to one half of the registers, selected by the op_sel bit.
//        The content of the other 16-bit half is undefined.
// GFX12: The op_sel bit must be 0.
def int_amdgcn_wmma_f16_16x16x16_f16   : AMDGPUWmmaIntrinsicOPSEL<llvm_anyfloat_ty, llvm_anyfloat_ty>;
def int_amdgcn_wmma_bf16_16x16x16_bf16 : AMDGPUWmmaIntrinsicOPSEL<llvm_anyint_ty, llvm_anyint_ty>;
}
