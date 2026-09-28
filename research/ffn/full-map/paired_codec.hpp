#pragma once
#include <cstdint>
#include <cstring>
#include <vector>
#include <stdexcept>

namespace kelana_ffn {
constexpr int PAIR_BLOCK_BYTES = 1088;
constexpr int PAIR_CODES_BYTES = 1024;
constexpr uint16_t PAIR_HALF[9] = {
    0xe800, 0xe7ff, 0xe7fe, 0xbc00, 0x3c00, 0x67fe, 0x67ff, 0x6800, 0x0000
};
inline uint8_t pair_code(int gate, int up) {
    if (gate < -1 || gate > 1 || up < -1 || up > 1)
        throw std::runtime_error("pair_code requires ternary weights");
    int i = (up + 1) * 3 + gate + 1;
    return i == 4 ? 12 : i - (i > 4);
}

inline void pack_pair_row(uint8_t *dst, int r, const int8_t *gate, const int8_t *up,
                          uint16_t gs, uint16_t us) {
    int ng = 0, nu = 0;
    for (int j = 0; j < 128; ++j) {
        int g = gate[j], u = up[j];
        auto code = pair_code(g, u);
        ng += g != 0; nu += u != 0;
        int off = (j / 16) * 128 + r * 8 + (j % 16) / 2;
        dst[off] |= code << (4 * (j & 1));
    }
    if (ng > 127 || nu > 127)
        throw std::runtime_error("pair WMMA needs <=127 nonzeros in each scale block");
    std::memcpy(dst + PAIR_CODES_BYTES + r * 4, &gs, 2);
    std::memcpy(dst + PAIR_CODES_BYTES + r * 4 + 2, &us, 2);
}

// Input [hidden][K], scales [hidden][K/128]. Output [hidden/16][K/128]
// with eight [16 rows][16 nibble codes] slices followed by 16 pairs of fp16 scales.
inline std::vector<uint8_t> pack_pair_weights(const int8_t *gate, const int8_t *up,
        const uint16_t *gs, const uint16_t *us, int hidden, int kdim) {
    if (hidden % 16 || kdim % 128) throw std::runtime_error("pair weight geometry");
    int nb = kdim / 128;
    std::vector<uint8_t> out(size_t(hidden / 16) * nb * PAIR_BLOCK_BYTES, 0);
    for (int tile = 0; tile < hidden / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            auto *dst = out.data() + (size_t(tile) * nb + b) * PAIR_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                int row = tile * 16 + r;
                size_t p = size_t(row) * kdim + b * 128;
                pack_pair_row(dst, r, gate + p, up + p, gs[row * nb + b], us[row * nb + b]);
            }
        }
    return out;
}
}

#ifdef __HIPCC__
#include <hip/hip_runtime.h>
namespace kelana_ffn {
using half16 = _Float16 __attribute__((ext_vector_type(16)));
using uint8v = unsigned __attribute__((ext_vector_type(8)));
using float8 = float __attribute__((ext_vector_type(8)));

__device__ __forceinline__ unsigned byte_selectors(unsigned x) {
    x = (x | (x << 8)) & 0x00ff00ffu;
    return (x | (x << 4)) & 0x0f0f0f0fu;
}

// Codes 0..7 select a nonzero coefficient; selector 12 supplies zero without a ninth LUT byte.
__device__ __forceinline__ uint2 decode_four(unsigned codes) {
    unsigned s = byte_selectors(codes & 0xffffu);
    unsigned lo = __builtin_amdgcn_perm(0x00fffe00u, 0x00feff00u, s);
    unsigned hi = __builtin_amdgcn_perm(0x6867673cu, 0xbce7e7e8u, s);
    return make_uint2(__builtin_amdgcn_perm(hi, lo, 0x05010400u),
                      __builtin_amdgcn_perm(hi, lo, 0x07030602u));
}
__device__ __forceinline__ half16 decode_sixteen(uint2 codes) {
    uint8v r;
    uint2 a = decode_four(codes.x), b = decode_four(codes.x >> 16);
    uint2 c = decode_four(codes.y), d = decode_four(codes.y >> 16);
    r = {a.x, a.y, b.x, b.y, c.x, c.y, d.x, d.y};
    return __builtin_bit_cast(half16, r);
}
__device__ __forceinline__ float plane_partner(float x) {
    return __int_as_float(__builtin_amdgcn_update_dpp(0, __float_as_int(x), 0x168, 15, 15, true));
}
__device__ __forceinline__ void unpair(float p, float &g, float &u) {
    u = __builtin_rintf(p * (1.0f / 2047.0f));
    g = __builtin_rintf(__builtin_fmaf(-2047.0f, u, p));
}
}
#endif
