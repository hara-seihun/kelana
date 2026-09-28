// Weight and activation representations for the batched ternary projection maps.
//
// Shared host packing plus the device-side operand construction each map needs. Every map computes
// the same logical product: a ternary gate matrix and a ternary up matrix, both [FF][D], against N
// token columns, with an FP16 scale per (row, 128-block) and an FP32 scale per (token, 128-block).
//
//   pairedF16 : one FP16 coefficient g + 2047*u carries a gate and an up row in one matrix row.
//   iu8       : the deployed integer instruction, one logical row per matrix row.
//   iu4       : the int4 instruction, one logical row per matrix row, at half the issue cost.
//
// Weight storage is two bits per ternary weight in every map except `iu4_nibble`, which pays four
// bits to skip the register expansion. Activation width is the map's other axis: eight bits needs
// two digit planes, four bits needs one.
#pragma once
#include <cstdint>
#include <cstring>
#include <vector>
#include <stdexcept>

namespace kelana_arith {

constexpr int KB = 128;              // scale block along K
constexpr int SLICES = KB / 16;      // WMMA K16 slices per block

// ---------------------------------------------------------------- host packing (untimed prepare)

// Paired codes: 1088 bytes per (16 rows x 128 K): eight 128-byte slices of 16 rows x 16 nibbles,
// then 16 FP16 gate/up scale pairs. Identical to full-map/paired_codec.hpp, kept here so this
// experiment can change its own layout without disturbing the one/eight-token maps.
constexpr int PAIR_BLOCK_BYTES = 1088;
constexpr int PAIR_CODES_BYTES = 1024;
constexpr uint16_t PAIR_HALF[9] = {0xe800, 0xe7ff, 0xe7fe, 0xbc00, 0x3c00, 0x67fe, 0x67ff, 0x6800, 0x0000};

inline uint8_t pair_code(int gate, int up) {
    int i = (up + 1) * 3 + gate + 1;
    return i == 4 ? 12 : i - (i > 4);
}

inline std::vector<uint8_t> pack_paired(const int8_t *gate, const int8_t *up,
                                        const uint16_t *gs, const uint16_t *us, int rows, int kdim) {
    int nb = kdim / KB;
    std::vector<uint8_t> out(size_t(rows / 16) * nb * PAIR_BLOCK_BYTES, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            uint8_t *dst = out.data() + (size_t(tile) * nb + b) * PAIR_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                int row = tile * 16 + r;
                const int8_t *g = gate + size_t(row) * kdim + b * KB;
                const int8_t *u = up + size_t(row) * kdim + b * KB;
                int ng = 0, nu = 0;
                for (int j = 0; j < KB; ++j) {
                    ng += g[j] != 0; nu += u[j] != 0;
                    dst[(j / 16) * 128 + r * 8 + (j % 16) / 2] |= pair_code(g[j], u[j]) << (4 * (j & 1));
                }
                if (ng > 127 || nu > 127)
                    throw std::runtime_error("paired map needs <=127 nonzeros per 128-block");
                std::memcpy(dst + PAIR_CODES_BYTES + r * 4, gs + row * nb + b, 2);
                std::memcpy(dst + PAIR_CODES_BYTES + r * 4 + 2, us + row * nb + b, 2);
            }
        }
    return out;
}

// Two-bit ternary codes for the native integer maps: 512 bytes per (16 rows x 128 K), eight
// 64-byte slices of 16 rows x one 32-bit word. Code 0 is 0, code 1 is +1, code 3 is -1, so the
// int4 expansion only has to widen the sign bits of code 3.
inline std::vector<uint8_t> pack_two_bit(const int8_t *w, int rows, int kdim) {
    int nb = kdim / KB;
    std::vector<uint8_t> out(size_t(rows / 16) * nb * 512, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            uint8_t *dst = out.data() + (size_t(tile) * nb + b) * 512;
            for (int r = 0; r < 16; ++r) {
                const int8_t *s = w + size_t(tile * 16 + r) * kdim + b * KB;
                for (int sl = 0; sl < SLICES; ++sl) {
                    uint32_t word = 0;
                    for (int j = 0; j < 16; ++j) {
                        int v = s[sl * 16 + j];
                        word |= uint32_t(v == 0 ? 0 : (v > 0 ? 1 : 3)) << (2 * j);
                    }
                    std::memcpy(dst + sl * 64 + r * 4, &word, 4);
                }
            }
        }
    return out;
}

// Four-bit ternary nibbles: 1024 bytes per (16 rows x 128 K), eight 128-byte slices of
// 16 rows x 8 bytes, ready for v_wmma_i32_16x16x16_iu4 with no register expansion.
inline std::vector<uint8_t> pack_nibble(const int8_t *w, int rows, int kdim) {
    int nb = kdim / KB;
    std::vector<uint8_t> out(size_t(rows / 16) * nb * 1024, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            uint8_t *dst = out.data() + (size_t(tile) * nb + b) * 1024;
            for (int r = 0; r < 16; ++r) {
                const int8_t *s = w + size_t(tile * 16 + r) * kdim + b * KB;
                for (int j = 0; j < KB; ++j)
                    dst[(j / 16) * 128 + r * 8 + (j % 16) / 2] |= uint8_t(s[j] & 0xf) << (4 * (j & 1));
            }
        }
    return out;
}
}

#ifdef __HIPCC__
#include <hip/hip_runtime.h>
namespace kelana_arith {
using half16 = _Float16 __attribute__((ext_vector_type(16)));
using uint8v = unsigned __attribute__((ext_vector_type(8)));
using int8v = int __attribute__((ext_vector_type(8)));
using int4v = int __attribute__((ext_vector_type(4)));
using int2v = int __attribute__((ext_vector_type(2)));
using float8 = float __attribute__((ext_vector_type(8)));

__device__ __forceinline__ unsigned byte_selectors(unsigned x) {
    x = (x | (x << 8)) & 0x00ff00ffu;
    return (x | (x << 4)) & 0x0f0f0f0fu;
}
__device__ __forceinline__ uint2 decode_four(unsigned codes) {
    unsigned s = byte_selectors(codes & 0xffffu);
    unsigned lo = __builtin_amdgcn_perm(0x00fffe00u, 0x00feff00u, s);
    unsigned hi = __builtin_amdgcn_perm(0x6867673cu, 0xbce7e7e8u, s);
    return make_uint2(__builtin_amdgcn_perm(hi, lo, 0x05010400u),
                      __builtin_amdgcn_perm(hi, lo, 0x07030602u));
}
// 16 paired nibble codes -> 16 FP16 coefficients g + 2047*u.
__device__ __forceinline__ half16 decode_paired(uint2 codes) {
    uint2 a = decode_four(codes.x), b = decode_four(codes.x >> 16);
    uint2 c = decode_four(codes.y), d = decode_four(codes.y >> 16);
    uint8v r = {a.x, a.y, b.x, b.y, c.x, c.y, d.x, d.y};
    return __builtin_bit_cast(half16, r);
}

// 16 two-bit ternary codes -> 16 signed bytes, four v_perm lookups from a 4-byte table.
__device__ __forceinline__ int4v expand_i8(unsigned codes) {
    int4v r;
#pragma unroll
    for (int j = 0; j < 4; ++j) {
        unsigned v = (codes >> (8 * j)) & 0xffu;
        unsigned w = (v | (v << 12)) & 0x000f000fu;
        unsigned sel = (w | (w << 6)) & 0x03030303u;
        r[j] = __builtin_amdgcn_perm(0u, 0xff000100u, sel);  // byte 0:0, 1:+1, 3:-1
    }
    return r;
}

// 16 two-bit ternary codes -> 16 int4 nibbles. Each code lands in its own nibble, then the two
// high bits of a nibble are set exactly when the code is 3, which is the int4 encoding of -1.
__device__ __forceinline__ int2v expand_i4(unsigned codes) {
    int2v r;
#pragma unroll
    for (int j = 0; j < 2; ++j) {
        unsigned v = (codes >> (16 * j)) & 0xffffu;
        unsigned x = (v | (v << 8)) & 0x00ff00ffu;
        x = (x | (x << 4)) & 0x0f0f0f0fu;
        x = (x | (x << 2)) & 0x33333333u;
        unsigned h = x & (x >> 1) & 0x11111111u;
        r[j] = int(x | (h << 2) | (h << 3));
    }
    return r;
}

// Radix recovery. rint on both components is mandatory: native WMMA returns fractional deviations
// even on exactly representable integer operands (packed-wmma/NOTES.md).
__device__ __forceinline__ void unpair(float p, float &g, float &u) {
    u = __builtin_rintf(p * (1.0f / 2047.0f));
    g = __builtin_rintf(__builtin_fmaf(-2047.0f, u, p));
}
}
#endif
