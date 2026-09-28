// Three ternary weight channels in one FP16 WMMA operand: radix ladders, host packing, and the
// device decoder.
//
// The integer algebra for the minimal ladder is proved in Kelana/TriplePacking.lean (main): with
// ternary activations of L1 weight at most 16, `a + 33 b + 1089 c` decodes by peeling from the
// top, the operand stays within +-1123 and the accumulator within +-17968. This header adds what a
// kernel needs on top of that: the choice of ladder, the fragment layout, and the FP32 decoder
// whose tolerance to native accumulator error ../feasibility.cpp measures exhaustively.
//
// Why two ladders. [1, 33, 1089] is minimal and leaves 0.5 of separation margin in the
// accumulator. [1, 60, 1987] fills the FP16 operand exactly to its last exact integer, 2048, and
// leaves 14. Since v_wmma_f32_16x16x16_f16 is not bit-exact on integer operands, the second is the
// one to deploy; the first is kept so the probe can measure what the tight choice actually risks.
#pragma once
#if defined(__HIPCC__) || defined(__CUDACC__)
#define KELANA_TRIPLE_HD __host__ __device__ __forceinline__
#else
#define KELANA_TRIPLE_HD inline
#endif
#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <vector>

namespace kelana_triple {

constexpr int KB = 128;               // scale block along K
constexpr int SLICES = KB / 16;       // WMMA K16 slices per block
constexpr int ROWS_PER_TILE = 48;     // three channels of 16 physical rows

struct Ladder {
    int R1, R2;
    constexpr int pack(int w0, int w1, int w2) const { return w0 + R1 * w1 + R2 * w2; }
    constexpr int operand_max() const { return 1 + R1 + R2; }
    // Separation margin in accumulator units at digit bound B.
    constexpr double margin(int B) const {
        const double m1 = 0.5 * R1 - B, m2 = 0.5 * R2 - double(B) * (1 + R1);
        return m1 < m2 ? m1 : m2;
    }
    // Peel from the top. rint on both divisions is mandatory: the native accumulator is not
    // integral even on exactly representable integer operands. v0 is left as the float residual --
    // a kernel multiplies it by a float scale anyway, so rounding it would only discard accuracy.
    KELANA_TRIPLE_HD void decode(float p, float & v0, float & v1, float & v2) const {
        v2 = __builtin_rintf(p * (1.0f / float(R2)));
        const float r = __builtin_fmaf(-float(R2), v2, p);
        v1 = __builtin_rintf(r * (1.0f / float(R1)));
        v0 = __builtin_fmaf(-float(R1), v1, r);
    }
};

constexpr Ladder MINIMAL{33, 1089};
constexpr Ladder OPTIMAL{60, 1987};

// ---------------------------------------------------------------- host packing (untimed prepare)

// One block is 16 physical rows x 128 K of three channels, so 48 real weight rows:
//   4096 bytes of codes, eight 512-byte K16 slices of 16 rows x 16 FP16 operands,
//    128 bytes of scales, 16 rows x four FP16 (channel 0, 1, 2 scale, then padding).
//
// The operand is stored as FP16 rather than as two-bit codes expanded in registers. Three ternary
// weights per 16-bit operand is 0.667 bytes per weight against 0.25 for two-bit storage; the
// register expansion that would recover the difference needs an FP16 multiply-add ladder per
// operand, which is more VALU work than the decode this map is already trying to afford. The
// projection probe streams both images so the traffic difference is in the measurement.
constexpr int TRIPLE_BLOCK_BYTES = 4224;
constexpr int TRIPLE_CODES_BYTES = 4096;

inline uint16_t f32_to_f16_exact(int v) {
    // Exact for |v| <= 2048; every operand value is in that range by construction.
    if (v == 0) return 0;
    uint16_t sign = v < 0 ? 0x8000 : 0;
    int m = v < 0 ? -v : v;
    int e = 0;
    while (m >= 2048) { m >>= 1; ++e; }        // unreachable for |v| <= 2048 except v == 2048
    int shift = 0;
    while (m < 1024) { m <<= 1; --shift; }
    const int exponent = 10 + e + shift + 15;
    return uint16_t(sign | (exponent << 10) | (m & 0x3ff));
}

// `w` is [rows][kdim] ternary, row-major, padded by the caller to a multiple of 48 rows.
// `scales` is [rows][kdim/KB] FP16 block scales in the same row order.
inline std::vector<uint8_t> pack_triple(const int8_t * w, const uint16_t * scales,
                                        int rows, int kdim, const Ladder & lad) {
    if (rows % ROWS_PER_TILE) throw std::runtime_error("triple map needs rows padded to 48");
    const int nb = kdim / KB, tiles = rows / ROWS_PER_TILE;
    std::vector<uint8_t> out(size_t(tiles) * nb * TRIPLE_BLOCK_BYTES, 0);
    for (int t = 0; t < tiles; ++t)
        for (int b = 0; b < nb; ++b) {
            uint8_t * dst = out.data() + (size_t(t) * nb + b) * TRIPLE_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                const int8_t * s0 = w + size_t(t * ROWS_PER_TILE + 0 + r) * kdim + b * KB;
                const int8_t * s1 = w + size_t(t * ROWS_PER_TILE + 16 + r) * kdim + b * KB;
                const int8_t * s2 = w + size_t(t * ROWS_PER_TILE + 32 + r) * kdim + b * KB;
                for (int j = 0; j < KB; ++j) {
                    const uint16_t h = f32_to_f16_exact(lad.pack(s0[j], s1[j], s2[j]));
                    std::memcpy(dst + (j / 16) * 512 + (r * 16 + (j % 16)) * 2, &h, 2);
                }
                for (int c = 0; c < 3; ++c)
                    std::memcpy(dst + TRIPLE_CODES_BYTES + (r * 4 + c) * 2,
                                scales + size_t(t * ROWS_PER_TILE + 16 * c + r) * nb + b, 2);
            }
        }
    return out;
}

}  // namespace kelana_triple
