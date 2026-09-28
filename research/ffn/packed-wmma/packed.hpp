// Packed FP16 WMMA candidate for Bonsai's 32x128x8 ternary tile.
//
// Baseline (bonsai-halo kernels/phases.hpp mvw_rows): two V_WMMA_I32_16X16X16_IU8 per K16 slice,
// 16 per K128 block. The second uses the lane-half swap (v_permlanex16) so one 4-VGPR weight
// fragment feeds 32 logical rows; activation columns 8..15 duplicate 0..7 and are discarded.
//
// Candidate: one V_WMMA_F32_16X16X16_F16 per K16 slice, 8 per K128 block.
//   * two logical weight rows per physical row, coefficient a = w0 + 2047*w1 (exact FP16 integer),
//   * two activation digit planes in the 16 physical columns: cols 0..7 low, 8..15 high.
// Accumulator p = u + 2047*v with |u|,|v| <= 1023, decoded with RNE and recombined across planes.
#pragma once
#include <hip/hip_runtime.h>
#include <cstdint>

typedef _Float16 h16;
typedef h16 v16h __attribute__((ext_vector_type(16)));
typedef float v8f __attribute__((ext_vector_type(8)));
typedef int v4i __attribute__((ext_vector_type(4)));
typedef int v8i __attribute__((ext_vector_type(8)));

#define ROWS 32
#define KDIM 128
#define COLS 8
#define SLICES 8
#define RADIX 2047

// ---------------------------------------------------------------------------- device primitives

// v = round-to-nearest-even(p/2047), u = p - 2047 v. Both stay floats.
// V_WMMA_F32_16X16X16_F16 on gfx1151 is not bit-exact on exactly representable integer operands
// (measured: a few ulp of the accumulator magnitude), so u is rounded as well. The high-component
// boundary has only 0.5 worst-case margin in p. A hardware error bound is still missing; see NOTES.md.
__device__ __forceinline__ void decode_pair(float p, float &u, float &v) {
    v = __builtin_rintf(p * (1.0f / 2047.0f));       // v_mul_f32 + v_rndne_f32
    u = __builtin_rintf(__builtin_fmaf(-2047.0f, v, p));  // v_fma_f32 + v_rndne_f32
}

// lane <-> lane^8 inside each 16-lane DPP row (DPP_ROW_XMASK, dpp_ctrl 0x160|8).
__device__ __forceinline__ float swap8(float x) {
    int r = __builtin_amdgcn_update_dpp(0, __builtin_bit_cast(int, x), 0x168, 0xf, 0xf, true);
    return __builtin_bit_cast(float, r);
}

__device__ __forceinline__ int swap16i(int v) {
    return __builtin_amdgcn_permlanex16(v, v, 0x76543210u, 0xfedcba98u, false, false);
}

// ---------------------------------------------------------------------------- host construction

struct Digits {
    int8_t lo[KDIM][COLS];     // normalized low plane, |.| <= 8
    int8_t hi[KDIM][COLS];     // normalized high plane, |.| <= 8
    int fl[COLS], fh[COLS];    // retained factors, 1 or 8
    int l1lo[COLS], l1hi[COLS];
};

// l = ((q+8) mod 16) - 8 in [-8,7]; h = (q-l)/16 in [-8,8]; q = l + 16 h exactly.
inline void split_digits(const int8_t X[KDIM][COLS], Digits &d) {
    for (int c = 0; c < COLS; ++c) {
        int sl = 0, sh = 0;
        int8_t l[KDIM], h[KDIM];
        for (int k = 0; k < KDIM; ++k) {
            int q = X[k][c];
            int lo = ((q + 8) & 15) - 8;
            int hi = (q - lo) >> 4;
            l[k] = (int8_t) lo; h[k] = (int8_t) hi;
            sl += lo < 0 ? -lo : lo;
            sh += hi < 0 ? -hi : hi;
        }
        d.l1lo[c] = sl; d.l1hi[c] = sh;
        d.fl[c] = (sl == 1024) ? 8 : 1;
        d.fh[c] = (sh == 1024) ? 8 : 1;
        for (int k = 0; k < KDIM; ++k) {
            d.lo[k][c] = (int8_t) (l[k] / d.fl[c]);
            d.hi[k][c] = (int8_t) (h[k] / d.fh[c]);
        }
    }
}

// Candidate A fragment: replicated across lane halves, physical row m = lane%16 carries logical
// rows 2m (unit) and 2m+1 (radix).
inline void pack_weights_f16(const int8_t W[ROWS][KDIM], v16h *af) {
    for (int s = 0; s < SLICES; ++s)
        for (int lane = 0; lane < 32; ++lane) {
            int m = lane & 15;
            for (int e = 0; e < 16; ++e) {
                int k = s * 16 + e;
                int a = W[2 * m][k] + RADIX * W[2 * m + 1][k];
                af[s * 32 + lane][e] = (h16) (float) a;
            }
        }
}

// Candidate B fragment: physical column j = lane%16 is activation column j%8, plane j/8.
inline void pack_digits_f16(const Digits &d, v16h *bf) {
    for (int s = 0; s < SLICES; ++s)
        for (int lane = 0; lane < 32; ++lane) {
            int j = lane & 15, c = j & 7, plane = j >> 3;
            for (int e = 0; e < 16; ++e) {
                int k = s * 16 + e;
                int v = plane ? d.hi[k][c] : d.lo[k][c];
                bf[s * 32 + lane][e] = (h16) (float) v;
            }
        }
}

// Per-lane recombination weights: own plane factor and partner (lane^8) plane factor.
inline void pack_factors(const Digits &d, float *fself, float *fpart) {
    for (int lane = 0; lane < 32; ++lane) {
        int j = lane & 15, c = j & 7, plane = j >> 3;
        float fl = (float) d.fl[c], fh = 16.0f * (float) d.fh[c];
        fself[lane] = plane ? fh : fl;
        fpart[lane] = plane ? fl : fh;
    }
}

// Baseline weight fragment, Bonsai's ternary encoding: unsigned byte w+1, lane l holds tile row l.
inline void pack_weights_iu8(const int8_t W[ROWS][KDIM], v4i *ai) {
    for (int s = 0; s < SLICES; ++s)
        for (int lane = 0; lane < 32; ++lane) {
            uint8_t b[16];
            for (int e = 0; e < 16; ++e) b[e] = (uint8_t) (W[lane][s * 16 + e] + 1);
            v4i r; __builtin_memcpy(&r, b, 16);
            ai[s * 32 + lane] = r;
        }
}

// Baseline activation fragment: column lane%16, activation column (lane%16)%8, signed int8.
inline void pack_acts_iu8(const int8_t X[KDIM][COLS], v4i *bi) {
    for (int s = 0; s < SLICES; ++s)
        for (int lane = 0; lane < 32; ++lane) {
            int c = lane & 7;
            int8_t b[16];
            for (int e = 0; e < 16; ++e) b[e] = X[s * 16 + e][c];
            v4i r; __builtin_memcpy(&r, b, 16);
            bi[s * 32 + lane] = r;
        }
}

inline void reference(const int8_t W[ROWS][KDIM], const int8_t X[KDIM][COLS], int R[ROWS][COLS]) {
    for (int r = 0; r < ROWS; ++r)
        for (int c = 0; c < COLS; ++c) {
            int acc = 0;
            for (int k = 0; k < KDIM; ++k) acc += (int) W[r][k] * (int) X[k][c];
            R[r][c] = acc;
        }
}

// Logical row owned by (lane, accumulator index, half of the packed pair).
// D element r of lane l is output row 2r + l/16, physical column l%16.
inline void cand_owner(int lane, int r, int part, int &row, int &col) {
    int m = 2 * r + (lane >> 4);
    row = 2 * m + part;
    col = lane & 7;
}

// Baseline ownership from phases.hpp: A1 half0 -> row 2r, half1 -> 2r+17;
// A2 (lane halves swapped) half0 -> 2r+16, half1 -> 2r+1.
inline void base_owner(int lane, int r, int which, int &row, int &col) {
    int half = lane >> 4;
    row = which == 0 ? (half ? 2 * r + 17 : 2 * r) : (half ? 2 * r + 1 : 2 * r + 16);
    col = lane & 7;
}
