// Extracted from llvm/lib/Target/AMDGPU/GCNProcessors.td lines 273-305.
// Installed ROCm 7.2.3 source. SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Only GFX11 processor mappings are retained.
//===----------------------------------------------------------------------===//

def : ProcessorModel<"gfx1100", GFX11SpeedModel,
  FeatureISAVersion11_0_0.Features
>;

def : ProcessorModel<"gfx1101", GFX11SpeedModel,
  FeatureISAVersion11_0_1.Features
>;

def : ProcessorModel<"gfx1102", GFX11SpeedModel,
  FeatureISAVersion11_0_2.Features
>;

def : ProcessorModel<"gfx1103", GFX11SpeedModel,
  FeatureISAVersion11_0_3.Features
>;

def : ProcessorModel<"gfx1150", GFX11SpeedModel,
  FeatureISAVersion11_5_0.Features
>;

def : ProcessorModel<"gfx1151", GFX11SpeedModel,
  FeatureISAVersion11_5_1.Features
>;

def : ProcessorModel<"gfx1152", GFX11SpeedModel,
  FeatureISAVersion11_5_2.Features
>;

def : ProcessorModel<"gfx1153", GFX11SpeedModel,
  FeatureISAVersion11_5_3.Features
>;
