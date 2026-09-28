// Device kernels for the three-channel ternary packing and its matched native IU4 baseline.
//
// Shared by the whole-FFN candidate in candidates/triple_maps.hip and by the standalone
// projection checker proj_check.hip, so the numbers in the bench table and the correctness proof
// come from the same code.
#pragma once
#include <hip/hip_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include "radix.hpp"

namespace kelana_triple_kernels {
using namespace kelana_triple;


using half16 = _Float16 __attribute__((ext_vector_type(16)));
using int8v = int __attribute__((ext_vector_type(8)));
using int2v = int __attribute__((ext_vector_type(2)));
using float8 = float __attribute__((ext_vector_type(8)));

constexpr int NT = 256;            // prep threads per 1024-element chunk
constexpr int NW = 4;              // waves per projection workgroup
constexpr float NORM_EPS = 1e-5f;
constexpr Ladder LAD = OPTIMAL;    // [1, 60, 1987]: fills the FP16 operand, 14 of separation margin

inline void check(hipError_t e, const char *what) {
    if (e != hipSuccess) { std::fprintf(stderr, "triple: %s: %s\n", what, hipGetErrorString(e)); std::abort(); }
}

__device__ __forceinline__ float h2f(unsigned bits) {
    unsigned short u = (unsigned short) bits; _Float16 h;
    __builtin_memcpy(&h, &u, 2); return (float) h;
}
__device__ __forceinline__ float silu(float x) { return x / (1.0f + __expf(-x)); }
__device__ __forceinline__ float warp_sum(float v) {
    for (int b = 1; b < 32; b <<= 1) v += __shfl_xor(v, b, 32);
    return v;
}
__device__ __forceinline__ float block_sum(float v, float *red) {
    v = warp_sum(v);
    int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    if (lane == 0) red[wave] = v;
    __syncthreads();
    float t = 0;
#pragma unroll
    for (int w = 0; w < NT / 32; ++w) t += red[w];
    return t;
}

// 16 two-bit ternary codes -> 16 int4 nibbles, from ../arithmetic/maps.hpp. Code 0 is 0, 1 is +1,
// 3 is -1, so only code 3 needs its nibble's high bits set.
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

// ------------------------------------------------------------------ activation producer

// One workgroup per (row, 1024-chunk). Same normalisation, sign folding and Hadamard order as the
// deployed prep_chunk_r; the quantiser is ternary and the destination is a WMMA B fragment.
// TRIPLE writes FP16 fragments, otherwise int4 nibbles.
template <bool TRIPLE, bool NORM, bool HAS_SIGN>
__global__ __launch_bounds__(NT) void k_prep(const float *__restrict__ x, const float *__restrict__ kvec,
        void *__restrict__ Bout, float *__restrict__ cscale, int n, int Npad) {
    __shared__ __attribute__((aligned(16))) float s[1024];
    __shared__ float red[NT / 32];
    const int nchunks = n / 1024, tid = threadIdx.x, lane = tid & 31, wave = tid >> 5;
    const int row = blockIdx.x / nchunks, chunk = blockIdx.x - row * nchunks;
    const int e0 = wave * 128 + lane * 4, base = chunk * 1024 + e0;
    const size_t rb = (size_t) row * n;
    float inv = 1.0f;
    if constexpr (NORM) {
        float ss = 0.0f;
        for (int i = tid * 4; i < n; i += NT * 4) {
            float4 t = *(const float4 *) (x + rb + i);
            ss = fmaf(t.x, t.x, ss); ss = fmaf(t.y, t.y, ss);
            ss = fmaf(t.z, t.z, ss); ss = fmaf(t.w, t.w, ss);
        }
        ss = block_sum(ss, red);
        inv = rsqrtf(ss / (float) n + NORM_EPS);
    }
    float4 v = *(const float4 *) (x + rb + base);
    if constexpr (HAS_SIGN) {
        float4 k = *(const float4 *) (kvec + base);
        v.x *= inv * k.x; v.y *= inv * k.y; v.z *= inv * k.z; v.w *= inv * k.w;
    }
    { float p0 = v.x + v.y, p1 = v.x - v.y, p2 = v.z + v.w, p3 = v.z - v.w;
      v.x = p0 + p2; v.y = p1 + p3; v.z = p0 - p2; v.w = p1 - p3; }
#pragma unroll
    for (int bit = 1; bit < 32; bit <<= 1) {
        bool upper = (lane & bit) != 0;
        float ox = __shfl_xor(v.x, bit, 32), oy = __shfl_xor(v.y, bit, 32);
        float oz = __shfl_xor(v.z, bit, 32), ow = __shfl_xor(v.w, bit, 32);
        v.x = upper ? ox - v.x : v.x + ox; v.y = upper ? oy - v.y : v.y + oy;
        v.z = upper ? oz - v.z : v.z + oz; v.w = upper ? ow - v.w : v.w + ow;
    }
    *(float4 *) (s + e0) = v;
    __syncthreads();
    if (tid < 128) {
        float u[8];
#pragma unroll
        for (int m = 0; m < 8; ++m) u[m] = s[tid + 128 * m];
#pragma unroll
        for (int len = 1; len < 8; len <<= 1)
#pragma unroll
            for (int m = 0; m < 8; ++m) if ((m & len) == 0) {
                float x0 = u[m], x1 = u[m + len]; u[m] = x0 + x1; u[m + len] = x0 - x1;
            }
#pragma unroll
        for (int m = 0; m < 8; ++m) s[tid + 128 * m] = u[m] * 0.03125f;
    }
    __syncthreads();
    v = *(const float4 *) (s + e0);
    // Ternary quantiser over the 128-element block this warp owns. Threshold at 0.7 of the mean
    // magnitude, then the represented level is the mean magnitude of the entries that survive.
    const float a0 = fabsf(v.x), a1 = fabsf(v.y), a2 = fabsf(v.z), a3 = fabsf(v.w);
    const float thr = 0.7f * warp_sum(a0 + a1 + a2 + a3) * (1.0f / 128.0f);
    const float av[4] = {a0, a1, a2, a3};
    const float vv[4] = {v.x, v.y, v.z, v.w};
    int q[4]; float kept = 0; int nkept = 0;
#pragma unroll
    for (int j = 0; j < 4; ++j) {
        const bool on = av[j] > thr;
        q[j] = on ? (vv[j] > 0.f ? 1 : -1) : 0;
        kept += on ? av[j] : 0.f; nkept += on ? 1 : 0;
    }
    const float ksum = warp_sum(kept), kcnt = warp_sum((float) nkept);
    const float level = kcnt > 0.f ? ksum / kcnt : 0.f;
    const int kslice = base >> 4, slot = base & 15;
    if constexpr (TRIPLE) {
        _Float16 *dst = (_Float16 *) Bout + (size_t(kslice) * Npad + row) * 16 + slot;
#pragma unroll
        for (int j = 0; j < 4; ++j) dst[j] = (_Float16) q[j];
    } else {
        uint8_t *dst = (uint8_t *) Bout + (size_t(kslice) * Npad + row) * 8 + slot / 2;
        dst[0] = uint8_t((q[0] & 0xf) | ((q[1] & 0xf) << 4));
        dst[1] = uint8_t((q[2] & 0xf) | ((q[3] & 0xf) << 4));
    }
    if (lane == 0) cscale[(size_t) row * (n / KB) + (base >> 7)] = level;
}

// ------------------------------------------------------------------ triple-packed projection

// A wave owns 16 physical weight rows, which are 48 real rows, and TT token tiles.
//
// The decode is the whole point of the experiment. It cannot move out of the slice loop: three
// channels at radices below the FP16 operand limit leave the accumulator no room for a second
// instruction (../feasibility.cpp), so the two divisions and three accumulations run for every one
// of the eight accumulator elements after every WMMA.
//
// EPI selects the epilogue: 0 adds the incoming residual (the down projection), 1 stores a gate
// result on its own, 2 reads that stored gate back and completes silu(gate) * up * sign. Gate and
// up run as separate passes rather than together in one wave. Three decoded channels need three
// times the per-block accumulator state of a native map; carrying both matrices at once spilled
// 165 VGPRs at two token tiles and never reached four. One extra read-modify-write of the hidden
// buffer buys four token tiles, which is what the weight stream needs.
template <int TT, int EPI>
__global__ __launch_bounds__(NW * 32) void k_proj_triple(
        const uint8_t *__restrict__ W, const half16 *__restrict__ B,
        const float *__restrict__ cscale, const float *__restrict__ signs,
        const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride, int outrows, int ntiles) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    if (tile >= ntiles) return;          // 48 real rows per tile rarely divides by the wave count
    const uint8_t *base = W + size_t(tile) * nb * TRIPLE_BLOCK_BYTES;
    const float inv1 = 1.0f / float(LAD.R1), inv2 = 1.0f / float(LAD.R2);
    for (int tg = tg0; tg < Npad; tg += tstride) {
        float y[3][TT][8];
#pragma unroll
        for (int c = 0; c < 3; ++c)
#pragma unroll
            for (int t = 0; t < TT; ++t)
#pragma unroll
                for (int r = 0; r < 8; ++r) y[c][t][r] = 0.f;
        for (int blk = 0; blk < nb; ++blk) {
            const uint8_t *wb = base + size_t(blk) * TRIPLE_BLOCK_BYTES;
            // Three row scales per physical row, broadcast to the eight rows this lane owns.
            const uint16_t *sc = (const uint16_t *) (wb + TRIPLE_CODES_BYTES + col * 8);
            float sl[3], sr[3][8];
#pragma unroll
            for (int c = 0; c < 3; ++c) sl[c] = h2f(sc[c]);
#pragma unroll
            for (int c = 0; c < 3; ++c)
#pragma unroll
                for (int r = 0; r < 8; ++r) sr[c][r] = __shfl(sl[c], 2 * r + half, 32);
            // Per-block channel accumulators in the order the decode produces them: p[0] is the
            // residual, still carrying channel 0 plus R1 times channel 1.
            float8 p[3][TT];
#pragma unroll
            for (int c = 0; c < 3; ++c)
#pragma unroll
                for (int t = 0; t < TT; ++t) p[c][t] = float8{};
#pragma unroll 1
            for (int s = 0; s < SLICES; ++s) {
                const half16 wf = *(const half16 *) (wb + s * 512 + col * 32);
#pragma unroll
                for (int t = 0; t < TT; ++t) {
                    const half16 bf = B[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                    const float8 Z = {};
                    const float8 P = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(wf, bf, Z);
#pragma unroll
                    for (int r = 0; r < 8; ++r) {
                        const float v2 = __builtin_rintf(P[r] * inv2);
                        const float rr = __builtin_fmaf(-float(LAD.R2), v2, P[r]);
                        const float v1 = __builtin_rintf(rr * inv1);
                        p[0][t][r] += rr; p[1][t][r] += v1; p[2][t][r] += v2;
                    }
                }
            }
            // Channel 0 emerges once per block, when channel 1 is removed from the residual.
            // Rounding it is not cosmetic: the residual carries the native WMMA's deviation from
            // the exact integer, eight slices' worth, and without the rint the block result is off
            // by about 1e-4 relative. Same rounding the paired map needs on its recovered low
            // component, at one instruction per eight slices here.
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                const float cs = cscale[size_t(tg + t * 16 + col) * nb + blk];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    const float d0 = __builtin_rintf(__builtin_fmaf(-float(LAD.R1), p[1][t][r], p[0][t][r]));
                    y[0][t][r] = __builtin_fmaf(d0, sr[0][r] * cs, y[0][t][r]);
                    y[1][t][r] = __builtin_fmaf(p[1][t][r], sr[1][r] * cs, y[1][t][r]);
                    y[2][t][r] = __builtin_fmaf(p[2][t][r], sr[2][r] * cs, y[2][t][r]);
                }
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            const int token = tg + t * 16 + col;
            if (token >= rows) continue;
#pragma unroll
            for (int c = 0; c < 3; ++c)
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    const int row = tile * ROWS_PER_TILE + 16 * c + 2 * r + half;
                    if (row >= outrows) continue;
                    const size_t o = size_t(token) * outstride + row;
                    if constexpr (EPI == 1) out[o] = y[c][t][r];
                    else if constexpr (EPI == 2) out[o] = silu(out[o]) * y[c][t][r] * signs[row];
                    else out[o] = resid[o] + y[c][t][r];
                }
        }
    }
}

// ------------------------------------------------------------------ matched native IU4 projection

template <int TT, bool FUSE>
__global__ __launch_bounds__(NW * 32) void k_proj_iu4(
        const uint8_t *__restrict__ Wa, const uint8_t *__restrict__ Wb,
        const int2v *__restrict__ B, const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const float *__restrict__ cscale, const float *__restrict__ signs,
        const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride, int outrows, int ntiles) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    if (tile >= ntiles) return;
    const uint8_t *abase = Wa + size_t(tile) * nb * 512;
    const uint8_t *bbase = Wb ? Wb + size_t(tile) * nb * 512 : nullptr;
    for (int tg = tg0; tg < Npad; tg += tstride) {
        float ya[TT][8], yb[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { ya[t][r] = 0.f; if (FUSE) yb[t][r] = 0.f; }
        for (int blk = 0; blk < nb; ++blk) {
            const int row = tile * 16 + col;
            const float asl = h2f(sa[size_t(row) * nb + blk]);
            const float bsl = FUSE ? h2f(sb[size_t(row) * nb + blk]) : 0.f;
            float asr[8], bsr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                asr[r] = __shfl(asl, 2 * r + half, 32);
                if (FUSE) bsr[r] = __shfl(bsl, 2 * r + half, 32);
            }
            int8v aa[TT], ab[TT];
#pragma unroll
            for (int t = 0; t < TT; ++t) { aa[t] = int8v{}; if (FUSE) ab[t] = int8v{}; }
#pragma unroll 1
            for (int s = 0; s < SLICES; ++s) {
                const int2v wa = expand_i4(*(const unsigned *) (abase + size_t(blk) * 512 + s * 64 + col * 4));
                const int2v wbf = FUSE ? expand_i4(*(const unsigned *) (bbase + size_t(blk) * 512 + s * 64 + col * 4))
                                       : int2v{};
#pragma unroll
                for (int t = 0; t < TT; ++t) {
                    const int2v bf = B[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                    aa[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wa, true, bf, aa[t], false);
                    if constexpr (FUSE)
                        ab[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wbf, true, bf, ab[t], false);
                }
            }
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                const float cs = cscale[size_t(tg + t * 16 + col) * nb + blk];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    ya[t][r] = __builtin_fmaf(float(aa[t][r]), asr[r] * cs, ya[t][r]);
                    if constexpr (FUSE) yb[t][r] = __builtin_fmaf(float(ab[t][r]), bsr[r] * cs, yb[t][r]);
                }
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            const int token = tg + t * 16 + col;
            if (token >= rows) continue;
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                const int row = tile * 16 + 2 * r + half;
                if (row >= outrows) continue;
                const size_t o = size_t(token) * outstride + row;
                if constexpr (FUSE) out[o] = silu(ya[t][r]) * yb[t][r] * signs[row];
                else out[o] = resid[o] + ya[t][r];
            }
        }
    }
}


// Two-bit ternary codes, 512 bytes per (16 rows x 128 K), as ../arithmetic/maps.hpp packs them.
inline std::vector<uint8_t> pack_two_bit(const int8_t *w, int rows, int kdim) {
    const int nb = kdim / 128;
    std::vector<uint8_t> out(size_t(rows / 16) * nb * 512, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            uint8_t *dst = out.data() + (size_t(tile) * nb + b) * 512;
            for (int r = 0; r < 16; ++r) {
                const int8_t *s = w + size_t(tile * 16 + r) * kdim + b * 128;
                for (int sl = 0; sl < 8; ++sl) {
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

}  // namespace kelana_triple_kernels
