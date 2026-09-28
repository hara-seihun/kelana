#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>

extern "C" __global__ void float_contract_fixture(
    float *out, int acc, unsigned short scale16_bits, float source_scale,
    float previous, float gate, float up, float sign, float a, float b) {
    const float block_scale = __half2float(__ushort_as_half(scale16_bits)) * source_scale;
    out[0] = fmaf((float)acc, block_scale, previous);

    const float silu = gate / (1.0f + __expf(-gate));
    out[1] = silu * up * sign;
    out[2] = a + b;
    out[3] = a - b;

    const float maximum = fmaxf(fabsf(a), fabsf(b));
    const float inverse_scale = maximum > 0.0f ? 127.0f / maximum : 0.0f;
    out[4] = maximum / 127.0f;
    out[5] = (float)__float2int_rn(a * inverse_scale);
    out[6] = rsqrtf(a);
}
