#include <hip/hip_runtime.h>

extern "C" __global__ void nibble_mass_dot(const unsigned *codes, const unsigned *digits, int *out) {
    unsigned c = codes[blockIdx.x];
    unsigned d = digits[blockIdx.x];
    out[blockIdx.x] = __builtin_amdgcn_sudot8(true, c, false, d, 0, false);
}
