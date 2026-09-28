// Dense five-trit bytes as a direct operand coordinate for v_wmma_i32_16x16x16_iu4.
//
// The stored object is the HALO five-trit byte: b = ceil(256*q/243) for the radix-3 number
// q = 81*t0 + 27*t1 + 9*t2 + 3*t3 + t4 over trit labels t in {0,1,2}. Nothing here expands a
// byte into five weights. The consumer wants PERM selector bytes, and a selector byte is
// exactly a nine-valued two-trit code, so the byte is read as
//
//     q = 27*A + 3*B + c,    A, B in [0,9) two-trit codes,   c in [0,3) one trit
//
// and A, B come straight out of the stored label with one multiply and one shift each:
//
//     A = (9*b) >> 8,   r = (9*b) & 0xff,   B = (9*r) >> 8,   r' = (9*r) & 0xff,   c = (3*r') >> 8
//
// This is the top-peel identity (b * 3^k) >> 8 = sum_{i<k} t_i 3^(k-1-i) taken two trits at a
// time. No individual weight is ever formed: A and B are already the operand the permute wants.
//
// The code alphabet is chosen so that the permute needs no remap. Nine codes need nine outcomes
// from one selector byte, and V_PERM_B32 gives eight dynamic source bytes plus a sign replicate.
// The exact rule is measured, not quoted: check.hip sweeps all 256 selector values against
// twelve source vectors with runtime operands and records the table in
// results/perm-semantics.json. For __builtin_amdgcn_perm(argA, argB, sel) on gfx1151:
//
//     sel 0..3   -> argB byte 0..3            sel 12     -> 0x00
//     sel 4..7   -> argA byte 0..3            sel 13..255-> 0xff
//     sel 8..11  -> sign bit of source byte 2*(sel-8)+1, replicated, where source byte 0..3 is
//                   argB byte 0..3 and 4..7 is argA byte 0..3. That is the odd byte of each
//                   16-bit half: argB.b1, argB.b3, argA.b1, argA.b3.
//
// So code 8 takes selector 8, which reads argB byte 1, which is code 1's operand byte. Label the
// trits so code 1's byte has a clear top bit and code 8 wants 0x00:
//
//     mu(0) = -1,  mu(1) = +1,  mu(2) = 0
//
// code 1 is then (-1,+1) -> 0x1F, top bit clear, and selector 8 yields the 0x00 that code 8
// (0,0) needs. The natural mu(t) = t - 1 puts 0xFF there and corrupts one pair in nine.
//
// code = 3*mu^-1(w_u) + mu^-1(w_v) then indexes the table below directly, as a selector byte.
#pragma once
#include <cstdint>
#include <cstring>
#include <vector>
#include <algorithm>
#include <stdexcept>
#include "halo_format.h"

namespace kelana_dense {

constexpr int KB = 128;                 // scale block along K
constexpr int SLICES = KB / 16;         // WMMA K16 slices per block

// ---------------------------------------------------------------- the nine-code operand table
//
// selector -> output byte (two int4 ternary nibbles, low nibble is the lower K slot)
//   0 -> 0xFF (-1,-1)   1 -> 0x1F (-1,+1)   2 -> 0x0F (-1, 0)
//   3 -> 0xF1 (+1,-1)   4 -> 0x11 (+1,+1)   5 -> 0x01 (+1, 0)
//   6 -> 0xF0 ( 0,-1)   7 -> 0x10 ( 0,+1)   8 -> 0x00 ( 0, 0)  sign replicate of code 1's 0x1F
constexpr unsigned PERM_S1 = 0xF10F1FFFu;   // bytes 0..3 = codes 0..3
constexpr unsigned PERM_S0 = 0x10F00111u;   // bytes 0..3 = codes 4..7

// weight -> trit label. mu(0)=-1, mu(1)=+1, mu(2)=0.
inline unsigned label(int w) { return w < 0 ? 0u : (w > 0 ? 1u : 2u); }
inline unsigned code2(int wu, int wv) { return 3u * label(wu) + label(wv); }

// The byte a (code, code, trit) triple stores. Trit order is HALO's: t0..t4 most significant first.
inline uint8_t pack_codes(unsigned A, unsigned B, unsigned c) {
    uint8_t t[5] = {uint8_t(A / 3), uint8_t(A % 3), uint8_t(B / 3), uint8_t(B % 3), uint8_t(c)};
    return halo::pack5(t);
}

// Host-side mirror of the device peel, for self-tests.
inline void peel_codes(uint8_t b, unsigned &A, unsigned &B, unsigned &c) {
    unsigned m = unsigned(b) * 9u;  A = m >> 8; m = (m & 0xffu) * 9u;
    B = m >> 8;                     m = (m & 0xffu) * 3u;
    c = m >> 8;
}

// ---------------------------------------------------------------- dense layout
//
// Per (16-row tile, 128-block), 416 bytes in three lane-interleaved sections so every load is
// naturally aligned and coalesced across the sixteen lanes of a wave half:
//
//   S0  offset   0   16 lanes x 16 B   lane reads uint4   bytes 0..15   five trits each
//   S1  offset 256   16 lanes x  8 B   lane reads uint2   bytes 16..23  five trits each
//   S2  offset 384   16 lanes x  2 B   lane reads ushort  bytes 24,25   four trits each
//
// 24*5 + 2*4 = 128 trits in 26 bytes, 1.625 bits per weight against 2.000 for a two-bit image.
//
// Trit routing. Each four-byte group (one dword of S0/S1) carries one whole K16 slice in its A
// and B codes, and contributes its four c trits to a later slice:
//
//   slice i, K slots  0.. 7  <-  A(b0) A(b2) B(b0) B(b2)
//   slice i, K slots  8..15  <-  A(b1) A(b3) B(b1) B(b3)
//
//   slice 6 <- c of S0 dwords 0..3, paired as 3*c(b0)+c(b2) and 3*c(b1)+c(b3)
//   slice 7 <- c of S1 dwords 0..1, then A,B of bytes 24 and 25
constexpr int DENSE_S1_OFF = 256;
constexpr int DENSE_S2_OFF = 384;
constexpr int DENSE_BLOCK_BYTES = 416;

// K slot inside a slice that byte j of a dense dword feeds. which_code 0 = A, 1 = B.
// The gather permute delivers [A(b0) A(b2) B(b0) B(b2)] to K 0..7 and
// [A(b1) A(b3) B(b1) B(b3)] to K 8..15, so:
inline int dense_slot(int j, int which_code) { return (j & 1) * 8 + which_code * 4 + (j >> 1) * 2; }

// K slot inside slice 6 or 7 that the c trit of byte j of dense dword d feeds.
// cc_of pairs (b0,b2) and (b1,b3), and slice_from_cc lays four cc dwords out in order.
inline int dense_cslot(int d, int j) { return 2 * (2 * (d & 3) + (j & 1)) + (j >> 1); }

inline std::vector<uint8_t> pack_dense(const int8_t *w, int rows, int kdim) {
    if (rows % 16 || kdim % KB) throw std::runtime_error("dense5: shape");
    int nb = kdim / KB;
    std::vector<uint8_t> out(size_t(rows / 16) * nb * DENSE_BLOCK_BYTES, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            uint8_t *dst = out.data() + (size_t(tile) * nb + b) * DENSE_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                const int8_t *s = w + size_t(tile * 16 + r) * kdim + b * KB;
                uint8_t byte[26];
                // Six dwords of five-trit bytes: dword d owns slice d, and lends its four c
                // trits to slice 6 (d < 4) or slice 7 (d >= 4).
                for (int d = 0; d < 6; ++d)
                    for (int j = 0; j < 4; ++j) {
                        const int8_t *sl = s + d * 16;
                        int sa = dense_slot(j, 0), sb = dense_slot(j, 1);
                        const int8_t *cs = s + (d < 4 ? 6 : 7) * 16;
                        int cslot = dense_cslot(d, j);
                        byte[d * 4 + j] = pack_codes(code2(sl[sa], sl[sa + 1]),
                                                     code2(sl[sb], sl[sb + 1]), label(cs[cslot]));
                    }
                // Two four-trit bytes finish slice 7 at K slots 8..15:
                // [A(24) A(25) B(24) B(25)] -> K 8,9 / 10,11 / 12,13 / 14,15.
                for (int j = 0; j < 2; ++j) {
                    const int8_t *sl = s + 7 * 16;
                    byte[24 + j] = pack_codes(code2(sl[8 + j * 2], sl[9 + j * 2]),
                                              code2(sl[12 + j * 2], sl[13 + j * 2]), 0);
                }
                std::memcpy(dst + r * 16, byte, 16);
                std::memcpy(dst + DENSE_S1_OFF + r * 8, byte + 16, 8);
                std::memcpy(dst + DENSE_S2_OFF + r * 2, byte + 24, 2);
            }
        }
    return out;
}

// ---------------------------------------------------------------- two-bit control layout
//
// The same nine-valued code, stored one per nibble at two bits per weight, so the permute needs
// only a mask and a shift. Same 512-byte block shape and same addressing as the arithmetic
// worker's two-bit image, so the only difference against that map is the expansion sequence.
constexpr int PAIR_BLOCK_BYTES = 512;

// WIDE lays the same words out so one lane's whole 128-block is 32 contiguous bytes, which is
// two uint4 loads instead of eight dword loads. Dense packing gets that load shape for free,
// because five trits per byte never lines up with a K16 slice, so it has to read the block whole.
// Separating the two effects needs a control that has the wide shape at two bits per weight.
template <bool WIDE>
inline std::vector<uint8_t> pack_paircode(const int8_t *w, int rows, int kdim) {
    if (rows % 16 || kdim % KB) throw std::runtime_error("paircode: shape");
    int nb = kdim / KB;
    std::vector<uint8_t> out(size_t(rows / 16) * nb * PAIR_BLOCK_BYTES, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            uint8_t *dst = out.data() + (size_t(tile) * nb + b) * PAIR_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                const int8_t *s = w + size_t(tile * 16 + r) * kdim + b * KB;
                for (int sl = 0; sl < SLICES; ++sl) {
                    unsigned word = 0;
                    for (int i = 0; i < 4; ++i) {
                        unsigned lo = code2(s[sl * 16 + 2 * i], s[sl * 16 + 2 * i + 1]);
                        unsigned hi = code2(s[sl * 16 + 8 + 2 * i], s[sl * 16 + 9 + 2 * i]);
                        word |= lo << (8 * i);
                        word |= hi << (8 * i + 4);
                    }
                    std::memcpy(dst + (WIDE ? r * 32 + sl * 4 : sl * 64 + r * 4), &word, 4);
                }
            }
        }
    return out;
}

}  // namespace kelana_dense

#ifdef __HIPCC__
#include <hip/hip_runtime.h>
namespace kelana_dense {
using ushort2v = unsigned short __attribute__((ext_vector_type(2)));
using uint2v = unsigned int __attribute__((ext_vector_type(2)));

__device__ __forceinline__ unsigned perm(unsigned s0, unsigned s1, unsigned sel) {
    return __builtin_amdgcn_perm(s0, s1, sel);
}
// Four selector codes in the four bytes of `sel` become eight int4 ternary nibbles.
__device__ __forceinline__ unsigned expand_codes(unsigned sel) { return perm(PERM_S0, PERM_S1, sel); }

// One dense dword: four five-trit bytes -> one whole K16 slice plus four c trits.
struct DenseDword {
    ushort2v A0, B0, C0;   // bytes 0 and 2 of the source dword
    ushort2v A1, B1, C1;   // bytes 1 and 3
};

__device__ __forceinline__ void peel_pair(ushort2v b, ushort2v &A, ushort2v &B, ushort2v &c) {
    const ushort2v nine = {9, 9}, three = {3, 3}, sh = {8, 8}, mask = {0xff, 0xff};
    ushort2v m = b * nine;
    A = m >> sh;
    m = (m & mask) * nine;
    B = m >> sh;
    m = (m & mask) * three;
    c = m >> sh;
}

__device__ __forceinline__ DenseDword peel_dword(unsigned d) {
    DenseDword r;
    ushort2v even = __builtin_bit_cast(ushort2v, d & 0x00ff00ffu);
    ushort2v odd = __builtin_bit_cast(ushort2v, (d >> 8) & 0x00ff00ffu);
    peel_pair(even, r.A0, r.B0, r.C0);
    peel_pair(odd, r.A1, r.B1, r.C1);
    return r;
}

// The gathered selector dwords of the slice this dense dword owns.
__device__ __forceinline__ uint2v slice_of(const DenseDword &r) {
    unsigned s0 = perm(__builtin_bit_cast(unsigned, r.B0), __builtin_bit_cast(unsigned, r.A0), 0x06040200u);
    unsigned s1 = perm(__builtin_bit_cast(unsigned, r.B1), __builtin_bit_cast(unsigned, r.A1), 0x06040200u);
    uint2v out;
    out[0] = expand_codes(s0);
    out[1] = expand_codes(s1);
    return out;
}

// Two c trits per source byte pair fold into one two-trit code without leaving the byte lanes.
// Every byte of g is at most 2, so 3*g cannot carry across a byte and neither can the add.
__device__ __forceinline__ unsigned cc_of(const DenseDword &r) {
    unsigned g = perm(__builtin_bit_cast(unsigned, r.C1), __builtin_bit_cast(unsigned, r.C0), 0x06040200u);
    return g * 3u + (g >> 8);        // bytes 0 and 2 hold 3*c + c'
}

// The two four-trit bytes of section S2, loaded as one ushort, finish slice 7.
__device__ __forceinline__ unsigned tail_codes(unsigned s2) {
    ushort2v bb = __builtin_bit_cast(ushort2v, (s2 & 0xffu) | ((s2 & 0xff00u) << 8));
    ushort2v A, B, c;
    peel_pair(bb, A, B, c);
    return perm(__builtin_bit_cast(unsigned, B), __builtin_bit_cast(unsigned, A), 0x06040200u);
}

// Four cc dwords (codes in bytes 0 and 2) become one K16 slice.
__device__ __forceinline__ uint2v slice_from_cc(unsigned c0, unsigned c1, unsigned c2, unsigned c3) {
    uint2v out;
    out[0] = expand_codes(perm(c1, c0, 0x06040200u));
    out[1] = expand_codes(perm(c3, c2, 0x06040200u));
    return out;
}

// Two-bit control: eight nine-valued nibble codes -> sixteen int4 nibbles.
__device__ __forceinline__ uint2v expand_paircode(unsigned d) {
    uint2v out;
    out[0] = expand_codes(d & 0x0f0f0f0fu);
    out[1] = expand_codes((d >> 4) & 0x0f0f0f0fu);
    return out;
}
}  // namespace kelana_dense
#endif
