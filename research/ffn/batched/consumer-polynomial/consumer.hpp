#pragma once
#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>

namespace kelana_consumer {
// 0: deployed expression; 1: half boundary with exact SiLU; 2/3: half degree6/8;
// 4: float degree8. Projection accumulation is not changed by this intervention.
__device__ __forceinline__ float consume(float gate, float up, int mode) {
    if (mode == 0) return (gate / (1.f + __expf(-gate))) * up;
    if (mode == 4) {
        if (fabsf(gate) > 3.5f) return consume(gate, up, 0);
        float z = gate*gate;
        float t = fmaf(z, -0.000026285648345947266f, 0.0010166168212890625f);
        t = fmaf(z, t, -0.0176849365234375f);
        t = fmaf(z, t, 0.246826171875f);
        return fmaf(z, t, 0.5f*gate)*up;
    }
    __half g = __float2half_rn(gate), u = __float2half_rn(up);
    float gf = __half2float(g);
    __half s;
    if (mode == 1 || fabsf(gf) > 3.5f) {
        s = __float2half_rn(gf / (1.f + __expf(-gf)));
    } else {
        __half z = __hmul(g,g), t;
        if (mode == 2) {
            t = __hfma(z, __float2half_rn(0.00041222572326660156f),
                          __float2half_rn(-0.0135345458984375f));
            t = __hfma(z, t, __float2half_rn(0.2388916015625f));
        } else {
            t = __hfma(z, __float2half_rn(-0.000026285648345947266f),
                          __float2half_rn(0.0010166168212890625f));
            t = __hfma(z, t, __float2half_rn(-0.0176849365234375f));
            t = __hfma(z, t, __float2half_rn(0.246826171875f));
        }
        s = __hfma(z,t,__hmul(__float2half_rn(.5f),g));
    }
    return __half2float(__hmul(s,u));
}
}
