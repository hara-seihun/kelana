#pragma once
#include <hip/hip_runtime.h>
#include <cstring>
#include <stdexcept>

namespace kelana_batch {
struct Geometry {int hip_processors, wgps, cus, simds;};
// gfx1151 HIP exposes WGPs in multiProcessorCount. RDNA3.5 ISA terminology:
// each WGP contains two CUs, each CU two SIMD32 units. This host's KFD node
// confirms simd_count=80 and simd_per_cu=2, while HIP reports 20 processors.
// Do not apply this mapping to another architecture without checking it.
inline Geometry geometry(const hipDeviceProp_t &p) {
    if(std::strncmp(p.gcnArchName,"gfx1151",7)!=0)
        throw std::runtime_error("GPU processor-unit mapping is defined only for gfx1151");
    return {p.multiProcessorCount,p.multiProcessorCount,2*p.multiProcessorCount,4*p.multiProcessorCount};
}
}
