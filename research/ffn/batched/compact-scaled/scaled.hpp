// Compact ternary storage that becomes SCALED FP16 weights in registers.
//
// The deployed weight is a trit t in {-1,0,+1} with an FP16 scale s per (row, 128-block). Its FP16
// product t*s is exactly one of three bit patterns: 0x0000, the bits of s, or the bits of s with
// bit 15 flipped. No multiplication is involved, so an A operand of scaled weights costs the same
// kind of work as the int8 or int4 expansions the other maps use - a few byte permutes - and the
// projection can then accumulate one FP32 sum across the entire K instead of draining an integer
// accumulator every 128 elements to apply the scale.
//
// Storage stays two bits per weight, the same 512 bytes per (16 rows x 128 K) block the integer
// maps read. The register expansion below is what changes.
//
// Kelana/ScaledTrit.lean carries the construction as a proof over raw half bits; this header is its
// packed byte-permute realisation with the codes this directory stores (0 -> 0, +1 -> 1, -1 -> 3).
#pragma once
#include <cstdint>
#include <cstring>
#include <vector>

namespace kelana_scaled {

constexpr int KB = 128;              // scale block along K
constexpr int SLICES = KB / 16;      // WMMA K16 slices per block
constexpr int BLOCK_BYTES = 512;     // 16 rows x 128 K of two-bit codes

// Two-bit ternary codes, eight 64-byte slices of 16 rows x one 32-bit word, byte-identical to the
// layout the arithmetic worker's integer maps read. Code 0 is 0, code 1 is +1, code 3 is -1: both
// nonzero codes have bit 0 set and only -1 has bit 1 set, which is what makes the selector below
// cheap.
inline std::vector<uint8_t> pack_two_bit(const int8_t *w, int rows, int kdim) {
    const int nb = kdim / KB;
    std::vector<uint8_t> out(size_t(rows / 16) * nb * BLOCK_BYTES, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            uint8_t *dst = out.data() + (size_t(tile) * nb + b) * BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                const int8_t *s = w + size_t(tile * 16 + r) * kdim + b * KB;
                for (int sl = 0; sl < SLICES; ++sl) {
                    uint32_t word = 0;
                    for (int j = 0; j < 16; ++j) {
                        const int v = s[sl * 16 + j];
                        word |= uint32_t(v == 0 ? 0 : (v > 0 ? 1 : 3)) << (2 * j);
                    }
                    std::memcpy(dst + sl * 64 + r * 4, &word, 4);
                }
            }
        }
    return out;
}

// Scale bits in the order a wave reads them: [tile][block][16 rows]. Kept as raw FP16 bits, never
// converted to float: the register expansion consumes the bit pattern directly.
inline std::vector<uint16_t> tile_major(const std::vector<uint16_t> &s, int rows, int nb) {
    std::vector<uint16_t> out(s.size());
    for (int row = 0; row < rows; ++row)
        for (int b = 0; b < nb; ++b)
            out[(size_t(row / 16) * nb + b) * 16 + row % 16] = s[size_t(row) * nb + b];
    return out;
}

} // namespace kelana_scaled

#ifdef __HIPCC__
#include <hip/hip_runtime.h>
namespace kelana_scaled {

using half16 = _Float16 __attribute__((ext_vector_type(16)));
using uint8v = unsigned __attribute__((ext_vector_type(8)));
using float8 = float __attribute__((ext_vector_type(8)));

// One lane holds one weight row for the whole 128-block, so its scale is one FP16 value for all 128
// weights. Build the two byte tables the expansion permutes from, once per block:
//
//   tlo bytes: [0x00, s_lo, s_lo, s_lo]          index c gives the low byte of t*s
//   thi bytes: [0x00, s_hi, s_hi, s_hi ^ 0x80]   index c gives the high byte of t*s
//
// with c the stored code. Index 2 is never selected. The XOR is the sign flip, correct whatever the
// stored scale's own sign is.
__device__ __forceinline__ void scale_tables(unsigned s16, unsigned &tlo, unsigned &thi) {
    const unsigned lo = s16 & 0xffu, hi = (s16 >> 8) & 0xffu;
    unsigned a = lo << 8;  a |= a << 8;  tlo = a | (a << 8);
    unsigned b = hi << 8;  b |= b << 8;  thi = (b & 0x00ffff00u) | ((hi ^ 0x80u) << 24);
}

// 16 two-bit codes -> 16 scaled FP16 weights, nine instructions per four weights.
//
// The four codes of one source byte spread into four bytes holding 0, 1 or 3. The intermediate
// 0x000f000f mask the integer expansions use is unnecessary here: the source is eight bits, so the
// two shifted copies cannot collide inside the bit pairs 0x03030303 keeps.
//
// Selecting the low byte of a half from table tlo and its high byte from table thi makes the
// selector byte for the high position the code plus four, so one OR and one interleaving permute
// build a selector pair and one more permute produces two finished halves.
__device__ __forceinline__ half16 expand_scaled(unsigned codes, unsigned tlo, unsigned thi) {
    uint8v r;
#pragma unroll
    for (int j = 0; j < 4; ++j) {
        const unsigned v = (codes >> (8 * j)) & 0xffu;
        const unsigned t = v | (v << 12);
        const unsigned c = (t | (t << 6)) & 0x03030303u;      // four code bytes
        const unsigned cp = c | 0x04040404u;                  // the same codes, indexing thi
        r[2 * j + 0] = __builtin_amdgcn_perm(thi, tlo, __builtin_amdgcn_perm(cp, c, 0x05010400u));
        r[2 * j + 1] = __builtin_amdgcn_perm(thi, tlo, __builtin_amdgcn_perm(cp, c, 0x07030602u));
    }
    return __builtin_bit_cast(half16, r);
}

// The whole projection operand in one call, so a consumer that wants this arithmetic gets the
// weight side without copying the kernel: one wave lane holds one weight row, `col` is its row
// within the 16-row tile, and the tables come from scale_tables for the current 128-block.
__device__ __forceinline__ half16 weight_operand(const uint8_t *tile_base, int blk, int slice,
                                                 int col, unsigned tlo, unsigned thi) {
    return expand_scaled(*(const unsigned *) (tile_base + size_t(blk) * BLOCK_BYTES + slice * 64 + col * 4),
                         tlo, thi);
}

} // namespace kelana_scaled
#endif
