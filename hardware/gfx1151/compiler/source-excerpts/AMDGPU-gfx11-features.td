// Extracted from llvm/lib/Target/AMDGPU/AMDGPU.td lines 1563-1584 and 1934-2018.
// Installed ROCm 7.2.3 source. SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// These ranges define the GFX11 base and per-processor feature sets.
def FeatureGFX11 : GCNSubtargetFeatureGeneration<"GFX11",
  "gfx11",
  [FeatureFP64, FeatureAddressableLocalMemorySize65536, FeatureMIMG_R128,
   FeatureFlatAddressSpace, Feature16BitInsts,
   FeatureInv2PiInlineImm, FeatureApertureRegs,
   FeatureCIInsts, FeatureGFX8Insts, FeatureGFX9Insts, FeatureGFX10Insts,
   FeatureGFX10_AEncoding, FeatureGFX10_BEncoding, FeatureGFX10_3Insts,
   FeatureGFX11Insts, FeatureVOP3P, FeatureVOPD, FeatureTrue16BitInsts,
   FeatureMovrel, FeatureFastFMAF32, FeatureDPP, FeatureIntClamp,
   FeatureFlatInstOffsets, FeatureFlatGlobalInsts, FeatureFlatScratchInsts,
   FeatureAddNoCarryInsts, FeatureFmaMixInsts,
   FeatureNoSdstCMPX, FeatureVscnt,
   FeatureVOP3Literal, FeatureDPP8, FeatureExtendedImageInsts,
   FeatureNoDataDepHazard, FeaturePkFmacF16Inst,
   FeatureA16, FeatureFastDenormalF32, FeatureG16,
   FeatureUnalignedBufferAccess, FeatureUnalignedScratchAccess,
   FeatureUnalignedDSAccess, FeatureGDS, FeatureGWS,
   FeatureDefaultComponentZero, FeatureMaxHardClauseLength32,
   FeatureAtomicFMinFMaxF32GlobalInsts, FeatureAtomicFMinFMaxF32FlatInsts,
   FeatureVmemWriteVgprInOrder
  ]
>;

// ----- feature-set definitions -----
def FeatureISAVersion11_Common : FeatureSet<
  [FeatureGFX11,
   FeatureBackOffBarrier,
   FeatureLDSBankCount32,
   FeatureDLInsts,
   FeatureDot5Insts,
   FeatureDot7Insts,
   FeatureDot8Insts,
   FeatureDot9Insts,
   FeatureDot10Insts,
   FeatureDot12Insts,
   FeatureNSAEncoding,
   FeaturePartialNSAEncoding,
   FeatureShaderCyclesRegister,
   FeatureArchitectedFlatScratch,
   FeatureAtomicFaddRtnInsts,
   FeatureAtomicFaddNoRtnInsts,
   FeatureFlatAtomicFaddF32Inst,
   FeatureImageInsts,
   FeaturePackedTID,
   FeatureVcmpxPermlaneHazard,
   FeatureMemoryAtomicFAddF32DenormalSupport,
   FeatureRealTrue16Insts,
   FeatureD16Writes32BitVgpr,
]>;

// There are few workarounds that need to be
// added to all targets. This pessimizes codegen
// a bit on the generic GFX11 target.
def FeatureISAVersion11_Generic: FeatureSet<
  !listconcat(FeatureISAVersion11_Common.Features,
    [FeatureMSAALoadDstSelBug,
     FeatureVALUTransUseHazard,
     FeatureUserSGPRInit16Bug,
     FeatureMADIntraFwdBug,
     FeaturePrivEnabledTrap2NopBug,
     FeatureRequiresCOV6,
     FeatureRequiredExportPriority])>;

def FeatureISAVersion11_0_Common : FeatureSet<
  !listconcat(FeatureISAVersion11_Common.Features,
    [FeatureMSAALoadDstSelBug,
     FeatureVALUTransUseHazard,
     FeatureMADIntraFwdBug,
     FeaturePrivEnabledTrap2NopBug])>;

def FeatureISAVersion11_0_0 : FeatureSet<
  !listconcat(FeatureISAVersion11_0_Common.Features,
    [Feature1_5xVGPRs,
     FeatureUserSGPRInit16Bug])>;

def FeatureISAVersion11_0_1 : FeatureSet<
  !listconcat(FeatureISAVersion11_0_Common.Features,
    [Feature1_5xVGPRs])>;

def FeatureISAVersion11_0_2 : FeatureSet<
  !listconcat(FeatureISAVersion11_0_Common.Features,
    [FeatureUserSGPRInit16Bug])>;

def FeatureISAVersion11_0_3 : FeatureSet<
  !listconcat(FeatureISAVersion11_0_Common.Features,
    [])>;

def FeatureISAVersion11_5_Common : FeatureSet<
  !listconcat(FeatureISAVersion11_Common.Features,
    [FeatureSALUFloatInsts,
     FeatureDPPSrc1SGPR,
     FeatureRequiredExportPriority])>;

def FeatureISAVersion11_5_0 : FeatureSet<
  !listconcat(FeatureISAVersion11_5_Common.Features,
    [FeaturePointSampleAccel])>;

def FeatureISAVersion11_5_1 : FeatureSet<
  !listconcat(FeatureISAVersion11_5_Common.Features,
    [Feature1_5xVGPRs,
     FeaturePointSampleAccel])>;

def FeatureISAVersion11_5_2 : FeatureSet<
  !listconcat(FeatureISAVersion11_5_Common.Features,
    [FeaturePointSampleAccel])>;

def FeatureISAVersion11_5_3 : FeatureSet<
  !listconcat(FeatureISAVersion11_5_Common.Features,
    [])>;
