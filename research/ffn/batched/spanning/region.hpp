// Batched FFN region: gate/up projection -> SiLU product/sign -> Hadamard -> int8 quantisation ->
// down projection, at 32/64/128/256 real token rows.
//
// One kernel, three spanning schedules over the same arithmetic, the same HALO weight format and
// the same per-(row, output) floating accumulation order as the deployed engine:
//
//   phases   : every hidden chunk's gate/up, then every chunk's nonlinearity and quantiser, then
//              down. This is the deployed phase structure, batched. The FP32 hidden image is
//              B * 17408 * 4 bytes wide and is written and re-read through memory.
//   chunked  : the same phases blocked over groups of 1024-wide hidden chunks, so the producer's
//              output is consumed while it is still in cache. The image is never wider than
//              group_chunks * 1024 * B * 4 bytes.
//   fused    : reserved for the in-workgroup variant (see README); not a schedule here.
//
// Token panels are the second representation choice. A panel of TP = 16 * NTOK tokens is what one
// work unit's accumulators can hold; tile-major unit order makes the panels of one weight tile
// consecutive so a split batch re-reads that tile out of cache rather than DRAM.
#pragma once
#include <hip/hip_runtime.h>
#include "halo_kernels.h"
#include "device.hpp"
#include "phases.hpp"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <vector>

namespace kelana_span {
using namespace halo;

// ---------------------------------------------------------------------------------------------
// HALO block decode, lifted unchanged from phases.hpp mvw_rows so the trit order and the scale
// are the deployed ones.

__device__ __forceinline__ void halo_decode(uint4 qa, uint2 qb, unsigned tail, unsigned tr[32], float & wscale) {
    const unsigned dw[6] = { qa.x, qa.y, qa.z, qa.w, qb.x, qb.y };
    #pragma unroll
    for (int d = 0; d < 6; d++) {
        unsigned P0 = dw[d] & 0x00ff00ffu, P1 = (dw[d] >> 8) & 0x00ff00ffu;
        unsigned t0 = peel(P0), t1 = peel(P0), t2 = peel(P0), t3 = peel(P0), t4 = peel_last(P0);
        unsigned u0 = peel(P1), u1 = peel(P1), u2 = peel(P1), u3 = peel(P1), u4 = peel_last(P1);
        tr[4 * d] = t0 | (t1 << 8); tr[4 * d + 1] = t2 | (t3 << 8);
        tr[4 * d + 2] = u0 | (u1 << 8); tr[4 * d + 3] = u2 | (u3 << 8);
        tr[24 + d] = t4 | (u4 << 8);
    }
    unsigned P = (tail & 0xffu) | ((tail << 8) & 0xff0000u);
    unsigned h0 = peel(P), h1 = peel(P), h2 = peel(P), h3 = peel_last(P);
    tr[30] = h0 | (h1 << 8); tr[31] = h2 | (h3 << 8);
    wscale = __half2float(__ushort_as_half((unsigned short) (tail >> 16)));
}

typedef int v4i __attribute__((ext_vector_type(4)));
typedef int v8i __attribute__((ext_vector_type(8)));
__device__ __forceinline__ int swap16b(int v) {
    return __builtin_amdgcn_permlanex16(v, v, 0x76543210u, 0xfedcba98u, false, false);
}

// One wave, one 32-row weight tile, NBLK consecutive K blocks, NTOK token fragments of 16 columns.
// The A fragments are decoded once per block and reused by every token fragment: the decode cost
// per useful column falls as NTOK grows, which is the batching the deployed 8-row kernel cannot do.
//
// PACKED selects the activation layout the quantiser produced. In the canonical row-major layout a
// fragment's sixteen columns are sixteen 16-byte pieces one row stride apart, so one load touches
// sixteen cache lines. In the panel layout the quantiser has already placed those sixteen pieces
// next to each other, so the same load is 256 contiguous bytes. Both carry identical bytes; only
// the address arithmetic differs.
template <int NBLK, int NTOK, bool PACKED>
__device__ __forceinline__ void mvb_rows(const uint8_t * __restrict__ run, int lane,
                                         const int8_t * __restrict__ xq, int wb, int tok0,
                                         const float * xs, const int * xsum, int nb_all, int batch,
                                         float * scl, float y1[NTOK][8], float y2[NTOK][8]) {
    constexpr int BB = TILE_BLOCK_BYTES;
    const int half = lane >> 4, col = lane & 15;
    uint4 qa = *(const uint4 *) (run + tile_off_qs_a(lane));
    uint2 qb = *(const uint2 *) (run + tile_off_qs_b(lane));
    unsigned tail = *(const unsigned *) (run + tile_off_tail(lane));
    const int8_t * xb0[NTOK];
    #pragma unroll
    for (int f = 0; f < NTOK; f++)
        xb0[f] = PACKED ? xq + ((size_t) ((tok0 + f * 16) >> 4) * nb_all + wb) * 2048 + col * 16
                        : xq + (size_t) (tok0 + f * 16 + col) * nb_all * 128 + (size_t) wb * 128;

    #pragma unroll 1
    for (int b = 0; b < NBLK; b++) {
        uint4 nqa = qa; uint2 nqb = qb; unsigned ntail = tail;
        if (b + 1 < NBLK) {
            const uint8_t * nrun = run + (b + 1) * BB;
            nqa = *(const uint4 *) (nrun + tile_off_qs_a(lane));
            nqb = *(const uint2 *) (nrun + tile_off_qs_b(lane));
            ntail = *(const unsigned *) (nrun + tile_off_tail(lane));
        }
        unsigned tr[32];
        float wscale;
        halo_decode(qa, qb, tail, tr, wscale);
        scl[(lane & 1) * 16 + (lane >> 1)] = wscale;

        v8i C1[NTOK], C2[NTOK];
        #pragma unroll
        for (int f = 0; f < NTOK; f++) { C1[f] = (v8i) {0,0,0,0,0,0,0,0}; C2[f] = (v8i) {0,0,0,0,0,0,0,0}; }
        #pragma unroll
        for (int kb = 0; kb < 8; kb++) {
            const v4i A = { (int) tr[4 * kb], (int) tr[4 * kb + 1], (int) tr[4 * kb + 2], (int) tr[4 * kb + 3] };
            const v4i As = { swap16b(A.x), swap16b(A.y), swap16b(A.z), swap16b(A.w) };
            #pragma unroll
            for (int f = 0; f < NTOK; f++) {
                const int4 bx = PACKED ? *(const int4 *) (xb0[f] + (size_t) b * 2048 + kb * 256)
                                       : *(const int4 *) (xb0[f] + b * 128 + kb * 16);
                const v4i B = { bx.x, bx.y, bx.z, bx.w };
                C1[f] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, A, true, B, C1[f], false);
                C2[f] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, As, true, B, C2[f], false);
            }
        }
        const float4 * s1p = (const float4 *) (scl + half * 16 + 8 * half);
        const float4 * s2p = (const float4 *) (scl + half * 16 + 8 * (half ^ 1));
        const float4 s1a = s1p[0], s1b = s1p[1], s2a = s2p[0], s2b = s2p[1];
        const float s1[8] = { s1a.x, s1a.y, s1a.z, s1a.w, s1b.x, s1b.y, s1b.z, s1b.w };
        const float s2[8] = { s2a.x, s2a.y, s2a.z, s2a.w, s2b.x, s2b.y, s2b.z, s2b.w };
        #pragma unroll
        for (int f = 0; f < NTOK; f++) {
            const int t = tok0 + f * 16 + col;
            const int xsc = PACKED ? xsum[(size_t) (wb + b) * batch + t] : xsum[(size_t) t * nb_all + wb + b];
            const float xsb = PACKED ? xs[(size_t) (wb + b) * batch + t] : xs[(size_t) t * nb_all + wb + b];
            #pragma unroll
            for (int r = 0; r < 8; r++) {
                y1[f][r] = fmaf((float) (C1[f][r] - xsc), s1[r] * xsb, y1[f][r]);
                y2[f][r] = fmaf((float) (C2[f][r] - xsc), s2[r] * xsb, y2[f][r]);
            }
        }
        qa = nqa; qb = nqb; tail = ntail;
    }
}

// Batched matvec over a tile range, in two wave splits that both reproduce the deployed floating
// accumulation order for every (output, token):
//
//   WSPLIT = 8 : the deployed split. Wave w owns block group w and the eight partials combine in
//                ascending wave order. A unit's token panel is 16*NTOK.
//   WSPLIT = 1 : every wave walks all eight groups and owns its own tokens instead. The group sums
//                are accumulated separately and combined in the same ascending left-nested order,
//                so the result is unchanged; the panel becomes 128*NTOK and a 256-token batch reads
//                each weight tile once.
template <int NB, int KS, int NTOK, int WSPLIT, bool PACKED, bool OUT_T = false>
__device__ __forceinline__ void mv_seg(Ctx & c, const uint8_t * wbase, float * out, int outN,
                                       int tile_lo, int tile_hi, int add,
                                       const int8_t * xq, const float * xs, const int * xsum,
                                       int npanels, bool tile_major, int batch) {
    using G = Geom<NB, KS>;
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5, half = lane >> 4, col = lane & 15;
    const int ntiles = tile_hi - tile_lo;
    const int total = ntiles * KS * npanels;
    constexpr int TP = (WSPLIT == 8 ? 16 : 128) * NTOK;
    float * red = c.lds;                                       // [7][8][32]
    float * scl = c.lds + (NW - 1) * 8 * 32 + wave * 32;       // per-wave scale table
    for (int u = blockIdx.x; u >= 0 && u < total; u = next_unit(c, total)) {
        c.dirty = true;
        // Part major over the whole range, as the deployed dispatch orders it, so a K-split
        // segment's two atomic contributions keep arriving in the deployed order.
        const int part = u / (ntiles * npanels);
        const int r = u - part * ntiles * npanels;
        int tile, panel;
        if (tile_major) { tile = r / npanels; panel = r - tile * npanels; }
        else            { panel = r / ntiles; tile = r - panel * ntiles; }
        tile += tile_lo;
        const int wb0 = (part == 0 ? 0 : (G::SPECIAL ? G::A_BLOCKS : part * G::PART));
        const int pw = (part == 0 || !G::SPECIAL) ? G::PW_A : G::PW_B;
        const int tok0 = panel * TP + (WSPLIT == 1 ? wave * 16 * NTOK : 0);
        const int gw = (WSPLIT == 8 ? wave : 0);

        float t1[NTOK][8], t2[NTOK][8];
        #pragma unroll
        for (int f = 0; f < NTOK; f++)
            #pragma unroll
            for (int rr = 0; rr < 8; rr++) { t1[f][rr] = 0.0f; t2[f][rr] = 0.0f; }

        if (WSPLIT == 8) {
            // One group, accumulated straight into the result registers.
            const int wb = wb0 + gw * pw;
            const uint8_t * run = wbase + ((size_t) tile * NB + wb) * TILE_BLOCK_BYTES;
            if (part == 0 || !G::SPECIAL)
                mvb_rows<G::PW_A, NTOK, PACKED>(run, lane, xq, wb, tok0, xs, xsum, NB, batch, scl, t1, t2);
            else
                mvb_rows<G::PW_B, NTOK, PACKED>(run, lane, xq, wb, tok0, xs, xsum, NB, batch, scl, t1, t2);
        } else {
            #pragma unroll 1
            for (int g = 0; g < NW; g++) {
                const int wb = wb0 + g * pw;
                const uint8_t * run = wbase + ((size_t) tile * NB + wb) * TILE_BLOCK_BYTES;
                float y1[NTOK][8], y2[NTOK][8];
                #pragma unroll
                for (int f = 0; f < NTOK; f++)
                    #pragma unroll
                    for (int rr = 0; rr < 8; rr++) { y1[f][rr] = 0.0f; y2[f][rr] = 0.0f; }
                if (part == 0 || !G::SPECIAL)
                    mvb_rows<G::PW_A, NTOK, PACKED>(run, lane, xq, wb, tok0, xs, xsum, NB, batch, scl, y1, y2);
                else
                    mvb_rows<G::PW_B, NTOK, PACKED>(run, lane, xq, wb, tok0, xs, xsum, NB, batch, scl, y1, y2);
                #pragma unroll
                for (int f = 0; f < NTOK; f++)
                    #pragma unroll
                    for (int rr = 0; rr < 8; rr++) {
                        t1[f][rr] = g == 0 ? y1[f][rr] : t1[f][rr] + y1[f][rr];
                        t2[f][rr] = g == 0 ? y2[f][rr] : t2[f][rr] + y2[f][rr];
                    }
            }
        }

        #pragma unroll
        for (int f = 0; f < NTOK; f++) {
            #pragma unroll
            for (int pass = 0; pass < 2; pass++) {
                float * y = pass ? t2[f] : t1[f];
                if (WSPLIT == 8) {
                    if (wave > 0) {
                        #pragma unroll
                        for (int rr = 0; rr < 8; rr++) red[((wave - 1) * 8 + rr) * 32 + lane] = y[rr];
                    }
                    __syncthreads();
                }
                if (WSPLIT == 1 || wave == 0) {
                    const int t = tok0 + f * 16 + col;
                    #pragma unroll
                    for (int rr = 0; rr < 8; rr++) {
                        float v = y[rr];
                        if (WSPLIT == 8) {
                            #pragma unroll
                            for (int w = 1; w < NW; w++) v += red[((w - 1) * 8 + rr) * 32 + lane];
                        }
                        const int row = pass ? (half ? 2 * rr + 1 : 2 * rr + 16) : (half ? 2 * rr + 17 : 2 * rr);
                        float * o = OUT_T ? out + ((size_t) tile * 32 + row) * batch + t
                                          : out + (size_t) t * outN + (size_t) tile * 32 + row;
                        if (KS > 1) atomicAdd(o, v);
                        else if (add) *o += v;
                        else *o = v;
                    }
                }
                if (WSPLIT == 8) __syncthreads();
            }
        }
    }
    end_phase(c);
}

// ---------------------------------------------------------------------------------------------
// The same element work with the quantiser's store redirected into the panel layout its consumer
// reads. Everything before the store -- the scale, the sign vector, the SiLU product, the
// Hadamard butterflies, the block maximum, the rounding and the block sum -- is the deployed code
// in the deployed order, so the bytes are identical and only their addresses change.
//
//   value layout  xq[(token/16 * nblocks + block) * 2048 + kb * 256 + (token%16) * 16 + byte]
//   scale layout  xs[block * batch + token], xsum likewise

__device__ __forceinline__ size_t panel_off(int nb_all, int row, int e) {
    const int tg = row >> 4, tl = row & 15;
    return ((size_t) tg * nb_all + (e >> 7)) * 2048 + (size_t) ((e >> 4) & 7) * 256 + (size_t) tl * 16 + (e & 15);
}

template <bool SILU, bool PACKED, bool GU_T = false>
__device__ __forceinline__ void prep_chunk_span(const float * x, const float * x2, const float * kvec,
                                                int n, int nb_all, int batch, int row, int chunk, float inv,
                                                float * s, int8_t * xq, float * xs, int * xsum) {
    const int tid = threadIdx.x, lane = tid & 31, wave = tid >> 5;
    const int e0 = wave * 128 + lane * 4;
    const int base = chunk * 1024 + e0;
    const size_t rb = (size_t) row * n;
    const float4 k = *(const float4 *) (kvec + base);
    float4 v;
    if (GU_T) {
        // Hidden held as [hidden][token], the layout a WMMA C fragment writes without scattering.
        const size_t o = (size_t) base * batch + row;
        v = make_float4(x[o], x[o + batch], x[o + 2 * batch], x[o + 3 * batch]);
        const float4 u = make_float4(x2[o], x2[o + batch], x2[o + 2 * batch], x2[o + 3 * batch]);
        v.x = silu(v.x) * u.x * k.x; v.y = silu(v.y) * u.y * k.y;
        v.z = silu(v.z) * u.z * k.z; v.w = silu(v.w) * u.w * k.w;
    } else {
    v = *(const float4 *) (x + rb + base);
    if (SILU) {
        const float4 u = *(const float4 *) (x2 + rb + base);
        v.x = silu(v.x) * u.x * k.x; v.y = silu(v.y) * u.y * k.y;
        v.z = silu(v.z) * u.z * k.z; v.w = silu(v.w) * u.w * k.w;
    } else {
        v.x *= inv * k.x; v.y *= inv * k.y; v.z *= inv * k.z; v.w *= inv * k.w;
    }
    }
    { const float p0 = v.x + v.y, p1 = v.x - v.y, p2 = v.z + v.w, p3 = v.z - v.w;
      v.x = p0 + p2; v.y = p1 + p3; v.z = p0 - p2; v.w = p1 - p3; }
    #pragma unroll
    for (int bit = 1; bit < 32; bit <<= 1) {
        const bool upper = (lane & bit) != 0;
        const float ox = __shfl_xor(v.x, bit, 32), oy = __shfl_xor(v.y, bit, 32),
                    oz = __shfl_xor(v.z, bit, 32), ow = __shfl_xor(v.w, bit, 32);
        v.x = upper ? ox - v.x : v.x + ox; v.y = upper ? oy - v.y : v.y + oy;
        v.z = upper ? oz - v.z : v.z + oz; v.w = upper ? ow - v.w : v.w + ow;
    }
    *(float4 *) (s + e0) = v;
    __syncthreads();
    if (tid < 128) {
        float u[8];
        #pragma unroll
        for (int m = 0; m < 8; m++) u[m] = s[tid + 128 * m];
        #pragma unroll
        for (int len = 1; len < 8; len <<= 1) {
            #pragma unroll
            for (int m = 0; m < 8; m++) if ((m & len) == 0) { const float x0 = u[m], x1 = u[m + len]; u[m] = x0 + x1; u[m + len] = x0 - x1; }
        }
        #pragma unroll
        for (int m = 0; m < 8; m++) s[tid + 128 * m] = u[m] * 0.03125f;
    }
    __syncthreads();
    v = *(const float4 *) (s + e0);

    const float amax = warp_max(fmaxf(fmaxf(fabsf(v.x), fabsf(v.y)), fmaxf(fabsf(v.z), fabsf(v.w))));
    const float iscale = amax > 0.0f ? 127.0f / amax : 0.0f;
    const int q0 = __float2int_rn(v.x * iscale), q1 = __float2int_rn(v.y * iscale),
              q2 = __float2int_rn(v.z * iscale), q3 = __float2int_rn(v.w * iscale);
    const int sum = warp_sum_i(q0 + q1 + q2 + q3);
    const unsigned word = (unsigned) (q0 & 0xff) | ((unsigned) (q1 & 0xff) << 8)
                        | ((unsigned) (q2 & 0xff) << 16) | ((unsigned) (q3 & 0xff) << 24);
    if (PACKED) *(unsigned *) (xq + panel_off(nb_all, row, base)) = word;
    else ((unsigned *) (xq + rb))[base >> 2] = word;
    if (lane == 0) {
        const int blk = base >> 7;
        if (PACKED) { xs[(size_t) blk * batch + row] = amax / 127.0f; xsum[(size_t) blk * batch + row] = sum; }
        else { xs[(size_t) row * nb_all + blk] = amax / 127.0f; xsum[(size_t) row * nb_all + blk] = sum; }
    }
}

// Width-D entry quantiser: the row norm, then the same element work.
template <bool PACKED>
__device__ __forceinline__ void prep_d_span(Ctx & c, const float * x, const float * kvec, int nrows,
                                            int8_t * xq, float * xs, int * xsum) {
    constexpr int nchunks = D / 1024;
    const int total = nrows * nchunks;
    for (int u = blockIdx.x; u >= 0 && u < total; u = next_unit(c, total)) {
        c.dirty = true;
        const int row = u / nchunks, chunk = u - row * nchunks;
        const float * xr = x + (size_t) row * D;
        float ss = 0.0f;
        for (int i = threadIdx.x * 4; i < D; i += NT * 4) {
            const float4 t = *(const float4 *) (xr + i);
            ss = fmaf(t.x, t.x, ss); ss = fmaf(t.y, t.y, ss); ss = fmaf(t.z, t.z, ss); ss = fmaf(t.w, t.w, ss);
        }
        ss = block_sum_256(ss, c.red);
        const float inv = rsqrtf(ss / (float) D + NORM_EPS);
        prep_chunk_span<false, PACKED>(x, nullptr, kvec, D, NB_D, nrows, row, chunk, inv, c.lds, xq, xs, xsum);
        __syncthreads();
    }
    end_phase(c);
}

template <bool PACKED, bool GU_T>
__device__ __forceinline__ void prep_ff_span(Ctx & c, const float * gate, const float * up, const float * kvec,
                                             int nrows, int chunk_lo, int chunk_hi,
                                             int8_t * xq, float * xs, int * xsum) {
    const int nch = chunk_hi - chunk_lo;
    const int total = nrows * nch;
    for (int u = blockIdx.x; u >= 0 && u < total; u = next_unit(c, total)) {
        c.dirty = true;
        const int ch = u / nrows, row = u - ch * nrows;
        prep_chunk_span<true, PACKED, GU_T>(gate, up, kvec, FF, NB_FF, nrows, row, chunk_lo + ch, 1.0f, c.lds, xq, xs, xsum);
        __syncthreads();
    }
    end_phase(c);
}

// ---------------------------------------------------------------------------------------------

struct RP {
    const uint8_t * gate, * up, * down;
    const float * post_norm_s, * signs_ff;
    const float * xin;
    float * xout, * gu, * xs_d, * xs_ff;
    int8_t * xq_d, * xq_ff;
    int * xsum_d, * xsum_ff;
    unsigned * bar, * work;
    unsigned long long * prof;
    int B, npanels, group_chunks, ngroups;
    int tile_major;
};

constexpr int FF_CHUNKS = FF / 1024;   // 17

template <int NTOK, int WSPLIT, bool PACKED, bool GU_T = false>
__global__ void __launch_bounds__(NT) k_region(RP P) {
    __shared__ __attribute__((aligned(16))) float lds[LDS_FLOATS];
    __shared__ float red[8];
    __shared__ int s_unit;
    Ctx c { P.bar, P.work, P.prof, 0, 0, true, lds, red, &s_unit };
    const int B = P.B;
    const bool tm = P.tile_major != 0;
    if (P.prof && blockIdx.x == 0 && threadIdx.x == 0) P.prof[0] = wall_clock64();

    // The residual the down projection accumulates into. The API hands in and out as separate
    // matrices, so the incoming residual is copied once, before the barrier that precedes down.
    for (size_t i = (size_t) blockIdx.x * NT + threadIdx.x; i < (size_t) B * D; i += (size_t) gridDim.x * NT)
        P.xout[i] = P.xin[i];
    c.dirty = true;

    prep_d_span<PACKED>(c, P.xin, P.post_norm_s, B, P.xq_d, P.xs_d, P.xsum_d);
    grid_sync(c);

    for (int g = 0; g < P.ngroups; g++) {
        const int c0 = g * P.group_chunks, c1 = min(c0 + P.group_chunks, FF_CHUNKS);
        const int t0 = c0 * 32, t1 = c1 * 32;
        mv_seg<NB_D, 1, NTOK, WSPLIT, PACKED, GU_T>(c, P.gate, P.gu, FF, t0, t1, 0, P.xq_d, P.xs_d, P.xsum_d, P.npanels, tm, B);
        mv_seg<NB_D, 1, NTOK, WSPLIT, PACKED, GU_T>(c, P.up, P.gu + (size_t) B * FF, FF, t0, t1, 0, P.xq_d, P.xs_d, P.xsum_d, P.npanels, tm, B);
        grid_sync(c);
        prep_ff_span<PACKED, GU_T>(c, P.gu, P.gu + (size_t) B * FF, P.signs_ff, B, c0, c1, P.xq_ff, P.xs_ff, P.xsum_ff);
        grid_sync(c);
    }

    mv_seg<NB_FF, 2, NTOK, WSPLIT, PACKED>(c, P.down, P.xout, D, 0, D / 32, 1, P.xq_ff, P.xs_ff, P.xsum_ff, P.npanels, tm, B);
    grid_sync(c);
}

// ---------------------------------------------------------------------------------------------
// Host side: one state object per candidate, all allocation and no activation access in prepare.

// Four token panel widths. A fourth accumulator fragment under the deployed K split (panel 64)
// needs 256 VGPRs and spills 115 bytes per lane, so that rung is not built.
constexpr int PANELS[] = { 16, 32, 128, 256 };
constexpr int NPANEL_KINDS = 4;

inline const void * kernel_for(int kind, bool packed, bool gu_t) {
    if (gu_t) switch (kind) {
        case 0: return (const void *) k_region<1, 8, true, true>;
        case 1: return (const void *) k_region<2, 8, true, true>;
        case 2: return (const void *) k_region<1, 1, true, true>;
        default: return (const void *) k_region<2, 1, true, true>;
    }
    if (packed) switch (kind) {
        case 0: return (const void *) k_region<1, 8, true>;
        case 1: return (const void *) k_region<2, 8, true>;
        case 2: return (const void *) k_region<1, 1, true>;
        default: return (const void *) k_region<2, 1, true>;
    }
    switch (kind) {
        case 0: return (const void *) k_region<1, 8, false>;
        case 1: return (const void *) k_region<2, 8, false>;
        case 2: return (const void *) k_region<1, 1, false>;
        default: return (const void *) k_region<2, 1, false>;
    }
}

struct State {
    const uint8_t * gate, * up, * down;
    const float * norm, * signs;
    float * gu, * xs_d, * xs_ff;
    int8_t * xq_d, * xq_ff;
    int * xsum_d, * xsum_ff;
    unsigned * bar, * work;
    unsigned long long * prof;
    int max_batch, panel_cap, group_chunks, tile_major, packed, gu_t;
    size_t resident;
};

#define KS_CK(e) do { hipError_t _e = (e); if (_e != hipSuccess) { \
    fprintf(stderr, "%s:%d %s\n", __FILE__, __LINE__, hipGetErrorString(_e)); abort(); } } while (0)

// panel_cap is the widest token panel this candidate asks for; a smaller batch uses the widest
// panel that divides it, so one preparation serves every requested batch size.
inline State * make_state(const uint8_t * gate, const uint8_t * up, const uint8_t * down,
                          const float * norm, const float * signs,
                          int max_batch, int panel_cap, int group_chunks, int tile_major, int packed, int gu_t = 0) {
    State * s = new State{};
    s->gu_t = gu_t;
    s->gate = gate; s->up = up; s->down = down; s->norm = norm; s->signs = signs;
    s->max_batch = max_batch; s->panel_cap = panel_cap; s->packed = packed;
    s->group_chunks = group_chunks; s->tile_major = tile_major;
    const size_t B = (size_t) max_batch;
    void * p;
    KS_CK(hipMalloc(&p, 2 * B * FF * 4)); s->gu = (float *) p;
    KS_CK(hipMalloc(&p, B * D));          s->xq_d = (int8_t *) p;
    KS_CK(hipMalloc(&p, B * NB_D * 4));   s->xs_d = (float *) p;
    KS_CK(hipMalloc(&p, B * NB_D * 4));   s->xsum_d = (int *) p;
    KS_CK(hipMalloc(&p, B * FF));         s->xq_ff = (int8_t *) p;
    KS_CK(hipMalloc(&p, B * NB_FF * 4));  s->xs_ff = (float *) p;
    KS_CK(hipMalloc(&p, B * NB_FF * 4));  s->xsum_ff = (int *) p;
    KS_CK(hipMalloc(&p, 4096));           s->bar = (unsigned *) p;
    KS_CK(hipMalloc(&p, 4096));           s->work = (unsigned *) p;
    KS_CK(hipMalloc(&p, 512 * 8));        s->prof = (unsigned long long *) p;
    s->resident = (size_t) (FF / 32) * NB_D * TILE_BLOCK_BYTES * 2 + (size_t) (D / 32) * NB_FF * TILE_BLOCK_BYTES;
    return s;
}

inline void free_state(State * s) {
    if (!s) return;
    (void) hipFree(s->gu); (void) hipFree(s->xq_d); (void) hipFree(s->xs_d); (void) hipFree(s->xsum_d);
    (void) hipFree(s->xq_ff); (void) hipFree(s->xs_ff); (void) hipFree(s->xsum_ff);
    (void) hipFree(s->bar); (void) hipFree(s->work); (void) hipFree(s->prof);
    delete s;
}

inline void launch(State * s, int rows, const float * in, float * out, hipStream_t st) {
    int kind = 0;
    for (int k = 0; k < NPANEL_KINDS; k++)
        if (PANELS[k] <= s->panel_cap && PANELS[k] <= rows && rows % PANELS[k] == 0) kind = k;
    // The panel layout addresses whole groups of sixteen tokens; a batch that is not a multiple of
    // sixteen uses the canonical layout instead.
    const bool packed = s->packed && (rows % 16 == 0);
    const bool gu_t = s->gu_t && packed;
    const void * fn = kernel_for(kind, packed, gu_t);
    const int slot = gu_t ? 2 : (packed ? 1 : 0);
    static int grids[3][NPANEL_KINDS] = {};
    if (rows % PANELS[kind]) { fprintf(stderr, "spanning: no panel divides %d rows\n", rows); abort(); }
    if (!grids[slot][kind]) grids[slot][kind] = coop_grid(fn);

    RP P{};
    P.gate = s->gate; P.up = s->up; P.down = s->down;
    P.post_norm_s = s->norm; P.signs_ff = s->signs;
    P.xin = in; P.xout = out; P.gu = s->gu;
    P.xq_d = s->xq_d; P.xs_d = s->xs_d; P.xsum_d = s->xsum_d;
    P.xq_ff = s->xq_ff; P.xs_ff = s->xs_ff; P.xsum_ff = s->xsum_ff;
    P.bar = s->bar; P.work = s->work; P.prof = s->prof;
    P.B = rows; P.npanels = rows / PANELS[kind];
    P.group_chunks = s->group_chunks;
    P.ngroups = (FF_CHUNKS + s->group_chunks - 1) / s->group_chunks;
    P.tile_major = s->tile_major;

    // The driver does not reset scratch between intervals, so the barrier and unit counters are
    // cleared here, inside the timed call.
    KS_CK(hipMemsetAsync(s->bar, 0, 4096, st));
    KS_CK(hipMemsetAsync(s->work, 0, 4096, st));
    void * args[] = { (void *) &P };
    KS_CK(hipLaunchCooperativeKernel(fn, dim3(grids[slot][kind]), dim3(NT), args, 0, st));

    // Stage stamps, off by default: reading them forces a synchronisation, so this is a separate
    // diagnostic run, not part of a timed comparison.
    static const char * prof_env = getenv("KELANA_SPAN_PROF");
    if (prof_env && *prof_env == '1') {
        KS_CK(hipStreamSynchronize(st));
        const int n = 2 + 2 * P.ngroups + 1;
        std::vector<unsigned long long> pf(n);
        KS_CK(hipMemcpy(pf.data(), s->prof, n * sizeof(unsigned long long), hipMemcpyDeviceToHost));
        double mv = 0, pr = 0;
        for (int g = 0; g < P.ngroups; g++) {
            mv += (pf[2 + 2 * g] - pf[1 + 2 * g]) / 100.0;
            pr += (pf[3 + 2 * g] - pf[2 + 2 * g]) / 100.0;
        }
        fprintf(stderr, "# stages us rows=%d panel=%d packed=%d groups=%d: quant_in %.1f  gate_up %.1f  "
                        "nonlin_quant %.1f  down %.1f\n",
                rows, PANELS[kind], (int) packed, P.ngroups, (pf[1] - pf[0]) / 100.0, mv, pr,
                (pf[2 + 2 * P.ngroups] - pf[1 + 2 * P.ngroups]) / 100.0);
    }
}

} // namespace kelana_span
