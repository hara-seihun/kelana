// Exact integer algebra for reading a *product* of two packed channels out of one packed value,
// without recovering either channel.
//
// A packed value is p = g + R*u with integer channels g (low) and u (high). The claim under test:
//
//   p^2 = g^2 + 2*R*g*u + R^2*u^2
//
// so if 2*R = 2^s and g^2 < 2^s, the field of low32(p^2) starting at bit s holds g*u modulo the
// field width, and the R^2*u^2 term only touches bits at or above 2*log2(R). Both cases below are
// signed bitfield extracts from one 32-bit product:
//
//   R = 65536: low32(p^2) = g^2 + 2^17*g*u   (mod 2^32; R^2 = 2^32 vanishes identically)
//              exact iff g^2 < 2^17 and g*u fits signed 15 bits -> sbfe(low32(p*p), 17, 15)
//   R = 1024:  p^2       = g^2 + 2^11*g*u + 2^20*u^2
//              exact iff g^2 < 2^11 and g*u fits signed 9 bits  -> sbfe(p*p, 11, 9)
//
// The gate sign is also directly observable in p without reconstructing g: for R = 65536 and
// |g| < 128, bit 15 of p is 1 exactly when g < 0; for R = 1024 and |g| < 17, bit 9 of p is.
#pragma once
#include <cstdint>

namespace kelana_dc {

struct Radix {
    int r;          // R
    int prod_start; // bit offset of the g*u field in low32(p*p)
    int prod_width; // field width in bits
    int chan_width; // signed width that recovers g from p (log2 R)
    int sign_bit;   // bit of p that is set exactly when g < 0, for the claimed |g| bound
};

inline constexpr Radix wide{65536, 17, 15, 16, 15};
inline constexpr Radix narrow{1024, 11, 9, 10, 9};

inline constexpr int32_t pack(const Radix &R, int g, int u) { return int32_t(g) + int32_t(R.r) * u; }

// Signed bitfield extract, the v_bfe_i32 semantics: take `width` bits starting at `start`, sign
// extend. Implemented on the low 32 bits of the value, as the instruction does.
inline constexpr int32_t sbfe(uint32_t v, int start, int width) {
    uint32_t f = (v >> start) & ((1u << width) - 1u);
    uint32_t sign = 1u << (width - 1);
    return int32_t((f ^ sign) - sign);
}

// The two-operation consumer: one 32-bit square, one signed extract.
inline constexpr int32_t fused_product(const Radix &R, int32_t p) {
    uint32_t sq = uint32_t(p) * uint32_t(p);
    return sbfe(sq, R.prod_start, R.prod_width);
}

// The gate sign read straight out of p.
inline constexpr bool gate_negative(const Radix &R, int32_t p) { return (uint32_t(p) >> R.sign_bit) & 1u; }

inline constexpr int32_t fused_gated_product(const Radix &R, int32_t p) {
    return gate_negative(R, p) ? 0 : fused_product(R, p);
}

// Decode-both-then-multiply on the same packed input, the consumer this is meant to replace.
inline constexpr int32_t decode_gate(const Radix &R, int32_t p) { return sbfe(uint32_t(p), 0, R.chan_width); }
inline constexpr int32_t decode_up(const Radix &R, int32_t p) {
    return int32_t(p + (1 << (R.chan_width - 1))) >> R.chan_width;
}
inline constexpr int32_t decoded_product(const Radix &R, int32_t p) {
    return decode_gate(R, p) * decode_up(R, p);
}
inline constexpr int32_t decoded_gated_product(const Radix &R, int32_t p) {
    int32_t g = decode_gate(R, p);
    return (g > 0 ? g : 0) * decode_up(R, p);
}

} // namespace kelana_dc
