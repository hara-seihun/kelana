// Whole-FFN candidates that defer the paired-FP16 radix separation across several 128-blocks.
//
// The paired map packs a gate row and an up row into one FP16 coefficient g + 2047*u and reads the
// two channels back out of the accumulator after every 128-block, because the weight scales and the
// activation scale change there. Everything in this file exists to make the carrier survive G
// adjacent blocks instead of one:
//
//   weights      one shared FP16 scale per (row, G blocks) for gate and for up, fitted offline to
//                the deployed per-block scales. L_g and L_u are independent, since the epilogue
//                applies them separately. The integer-multiplier form lam -> L*m was measured and
//                dropped: with M*(1+R) <= 2048 keeping the operand an exact FP16 integer, raising M
//                costs headroom as 1/M^2 (M=3 -> 113, M=7 -> 20) and buys almost no fit
//                (6.15% against 6.17% at G=8). See ../carrier_scan.py and ../README.md.
//   activations  one amax per (token, G*128) instead of per (token, 128), computed in the producer.
//   accumulator  one float8 per token tile runs G*128 columns of K, and the epilogue - decode,
//                two scale multiplies, two FMAs per logical row - is paid once per G blocks.
//
// G = 1 is the matched control: same file, same kernels, same tiling, same producer, same scale
// layout, so a comparison against it isolates the deferral and nothing else.
//
// The separation is exact while |S_low| <= 1023, where S_low is the gate channel's integer sum over
// the whole deferred run. That is not implied by any counting bound (a single 128-block already
// admits 7*102 = 714), so it is a measured property of this weight/activation pair, reported with
// its observed maxima in ../README.md, not a proof. The high channel needs no bound: u = rint(p/R)
// and g = p - R*u recover any integer u exactly under the low bound; a larger high channel only
// raises |p| and with it the FP32 condition, which ../defer_probe.hip measures natively.
#include "../../api.hpp"
#include "../../arithmetic/maps.hpp"
#include "halo_format.h"
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>

using namespace kelana_arith;

namespace {

constexpr int NT = 256;            // prep threads per 1024-element chunk
constexpr int NW = 4;              // waves per projection workgroup
constexpr float NORM_EPS = 1e-5f;
constexpr int CODE_BLOCK_BYTES = 1024;   // paired codes only; scales live in their own array

void check(hipError_t e, const char *what) {
    if (e != hipSuccess) { std::fprintf(stderr, "dfr: %s: %s\n", what, hipGetErrorString(e)); std::abort(); }
}

__device__ __forceinline__ float h2f(unsigned bits) {
    unsigned short u = (unsigned short) bits; _Float16 h;
    __builtin_memcpy(&h, &u, 2); return (float) h;
}
__device__ __forceinline__ float silu(float x) { return x / (1.0f + __expf(-x)); }
__device__ __forceinline__ float warp_max(float v) {
    for (int b = 1; b < 32; b <<= 1) v = fmaxf(v, __shfl_xor(v, b, 32));
    return v;
}
__device__ __forceinline__ float block_sum(float v, float *red) {
    for (int b = 1; b < 32; b <<= 1) v += __shfl_xor(v, b, 32);
    int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    if (lane == 0) red[wave] = v;
    __syncthreads();
    float t = 0;
#pragma unroll
    for (int w = 0; w < NT / 32; ++w) t += red[w];
    return t;
}

// ------------------------------------------------------------------ activation producer

// One workgroup per (row, 1024-chunk); the normalisation, folded sign and Hadamard order are the
// deployed prep_chunk_r's. The only change from the arithmetic worker's producer is the amax
// reduction, which now spans G waves (G*128 elements) so one activation scale covers the whole
// deferred run. CLIP shortens the quantiser step, as ../grouped-scales measured for grouped amax.
template <int G, bool NORM, bool HAS_SIGN, int CLIP_PCT, bool WANT_L1 = false>
__global__ __launch_bounds__(NT) void k_prep(const float *__restrict__ x, const float *__restrict__ kvec,
        void *__restrict__ Bout, float *__restrict__ cscale, int n, int rows, int Npad,
        uint16_t *__restrict__ l1out = nullptr) {
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
    float amax = warp_max(fmaxf(fmaxf(fabsf(v.x), fabsf(v.y)), fmaxf(fabsf(v.z), fabsf(v.w))));
    if constexpr (G > 1) {
        // one amax per G waves: the deferred run shares one activation scale
        __syncthreads();
        if (lane == 0) red[wave] = amax;
        __syncthreads();
        const int w0 = (wave / G) * G;
        float m = red[w0];
#pragma unroll
        for (int w = 1; w < G; ++w) m = fmaxf(m, red[w0 + w]);
        amax = m;
    }
    constexpr float L = 7.0f, CLIP = CLIP_PCT * 0.01f;
    float step = amax * CLIP / L;
    float iscale = amax > 0.0f ? 1.0f / step : 0.0f;
    int q[4] = {__float2int_rn(v.x * iscale), __float2int_rn(v.y * iscale),
                __float2int_rn(v.z * iscale), __float2int_rn(v.w * iscale)};
#pragma unroll
    for (int j = 0; j < 4; ++j) q[j] = max(-int(L), min(int(L), q[j]));
    const int kslice = base >> 4, slot = base & 15;
    _Float16 *dst = (_Float16 *) Bout + (size_t(kslice) * Npad + row) * 16 + slot;
#pragma unroll
    for (int j = 0; j < 4; ++j) dst[j] = (_Float16) q[j];
    if (lane == 0 && (wave % G) == 0)
        cscale[(size_t) row * (n / (G * KB)) + base / (G * KB)] = amax > 0.0f ? step : 0.0f;
    if constexpr (WANT_L1) {
        // sum |q| over this warp's 128-block: the certificate the scheduler spends, one warp
        // reduction on values already in registers.
        int a = abs(q[0]) + abs(q[1]) + abs(q[2]) + abs(q[3]);
#pragma unroll
        for (int b = 1; b < 32; b <<= 1) a += __shfl_xor(a, b, 32);
        if (lane == 0) l1out[(size_t) row * (n / KB) + (base >> 7)] = (uint16_t) a;
    }
    if (rows) {}
}

// ------------------------------------------------------------------ projection

// A wave owns 16 physical weight rows (32 logical, through the pairing) and TT token tiles. The
// accumulator runs G*128 columns before anything is decoded.
template <int TT, int G, int UN, bool FUSE>
__global__ __launch_bounds__(NW * 32) void k_proj(
        const uint8_t *__restrict__ W, const void *__restrict__ B,
        const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const float *__restrict__ cscale, const float *__restrict__ signs,
        const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride, int rowoff) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    const int ngroups = nb / G;
    const uint8_t *wbase = W + size_t(tile) * nb * CODE_BLOCK_BYTES;
    for (int tg = tg0; tg < Npad; tg += tstride) {
        float ya[TT][8], yb[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { ya[t][r] = 0.f; yb[t][r] = 0.f; }
        for (int gp = 0; gp < ngroups; ++gp) {
            float8 acc[TT];
#pragma unroll
            for (int t = 0; t < TT; ++t) acc[t] = float8{};
            // Slice s of block b sits at (b*SLICES + s)*128 bytes, so a deferred run of G blocks is
            // one flat contiguous sweep of G*SLICES K16 slices - the same loop shape the control
            // runs, just longer.
            const int k0 = gp * G * SLICES;
#pragma unroll 1
            for (int j = 0; j < G; ++j) {
#pragma unroll UN
                for (int s = 0; s < SLICES; ++s) {
                    const int q = j * SLICES + s;
                    half16 a = decode_paired(*(const uint2 *) (wbase + size_t(k0 + q) * 128 + col * 8));
#pragma unroll
                    for (int t = 0; t < TT; ++t)
                        acc[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(
                            a, ((const half16 *) B)[size_t(k0 + q) * Npad + tg + t * 16 + col], acc[t]);
                }
            }
            float asl = h2f(sa[(size_t(tile) * ngroups + gp) * 16 + col]);
            float bsl = h2f(sb[(size_t(tile) * ngroups + gp) * 16 + col]);
            float asr[8], bsr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { asr[r] = __shfl(asl, 2 * r + half, 32); bsr[r] = __shfl(bsl, 2 * r + half, 32); }
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                float cs = cscale[size_t(tg + t * 16 + col) * ngroups + gp];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    float g, u; unpair(acc[t][r], g, u);
                    ya[t][r] = __builtin_fmaf(g, asr[r] * cs, ya[t][r]);
                    yb[t][r] = __builtin_fmaf(u, bsr[r] * cs, yb[t][r]);
                }
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            int token = tg + t * 16 + col;
            if (token >= rows) continue;
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                int row = tile * 16 + 2 * r + half;
                size_t o = size_t(token) * outstride + row;
                if constexpr (FUSE) out[o] = silu(ya[t][r]) * yb[t][r] * signs[row];
                else {
                    out[o] = resid[o] + ya[t][r];
                    out[o + rowoff] = resid[o + rowoff] + yb[t][r];
                }
            }
        }
    }
}


// ------------------------------------------------------------------ certificate schedule

// |S_low| <= sum_k |q_k| over whichever columns the accumulator has run. One 128-block is always
// safe (7*128 = 896 <= 1023), so a greedy walk that starts a new run whenever the next block would
// take the running L1 budget past BUDGET always terminates and always certifies. The 16 tokens of
// a WMMA B tile share one schedule, taken from their maximum, because they share the accumulator's
// K position; runs never cross a group boundary, so the scale the epilogue applies is unchanged
// and the candidate stays the same numerical object as deferral over the whole group.
template <int G, int BUDGET>
__global__ void k_sched(const uint16_t *__restrict__ l1, uint8_t *__restrict__ sched,
                        int nb, int rows, int nunits, int ts) {
    const int ngroups = nb / G;
    const int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= nunits * ngroups) return;
    const int unit = idx / ngroups, gp = idx - unit * ngroups;
    // Greedy over run lengths 1, 2, 4, 8. Restricting to powers of two costs a little deferral and
    // buys a projection kernel small enough to stay in the instruction cache: with all eight
    // lengths compiled in, the same candidate ran 2.9x slower at four token tiles.
    unsigned mask = 0;
    int m[G];
#pragma unroll
    for (int j = 0; j < G; ++j) {
        int v = 0;
        for (int t = 0; t < ts; ++t) {
            const int token = unit * ts + t;
            if (token < rows) v = max(v, int(l1[(size_t) token * nb + gp * G + j]));
        }
        m[j] = v;
    }
    for (int j = 0; j < G;) {
        int best = 1;
        for (int len = 2; len <= G; len <<= 1) {
            if (j + len > G) break;
            int sum = 0;
            for (int i = 0; i < len; ++i) sum += m[j + i];
            if (sum <= BUDGET) best = len;
        }
        j += best;
        mask |= 1u << (j - 1);
    }
    sched[idx] = (uint8_t) (mask | (1u << (G - 1)));
}

// Same projection as k_proj, except that a run ends where the schedule says it must. One schedule
// unit covers exactly the TT*16 tokens one pass of the tg loop owns, so the run length is uniform
// across the wave and the inner loop keeps the flat, branch-free shape that k_proj needs to reach
// the instruction rate. The scales, the quantiser and the group are identical to deferral over the
// whole group; only the FP32 summation order of the partial runs differs.
// One deferred run of a compile-time number of blocks. The trip count has to be a constant or the
// compiler will not keep the flat, unrolled shape that reaches the instruction rate: a
// variable-length version of exactly this loop cost 2.8x on the whole FFN.
template <int TT, int BLOCKS, int UN>
__device__ __forceinline__ void run_blocks(float8 (&acc)[TT], const uint8_t *__restrict__ wbase,
        const void *__restrict__ B, int k0, int Npad, int tg, int col) {
#pragma unroll
    for (int t = 0; t < TT; ++t) acc[t] = float8{};
#pragma unroll UN
    for (int q = 0; q < BLOCKS * SLICES; ++q) {
        half16 a = decode_paired(*(const uint2 *) (wbase + size_t(k0 + q) * 128 + col * 8));
#pragma unroll
        for (int t = 0; t < TT; ++t)
            acc[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(
                a, ((const half16 *) B)[size_t(k0 + q) * Npad + tg + t * 16 + col], acc[t]);
    }
}

template <int TT, int G, int UN, bool FUSE>
__global__ __launch_bounds__(NW * 32) void k_proj_cert(
        const uint8_t *__restrict__ W, const void *__restrict__ B,
        const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const float *__restrict__ cscale, const uint8_t *__restrict__ sched,
        const float *__restrict__ signs, const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride, int rowoff) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    const int ngroups = nb / G;
    const uint8_t *wbase = W + size_t(tile) * nb * CODE_BLOCK_BYTES;
    for (int tg = tg0; tg < Npad; tg += tstride) {
        float ya[TT][8], yb[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { ya[t][r] = 0.f; yb[t][r] = 0.f; }
        const uint8_t *unit = sched + size_t(tg / (TT * 16)) * ngroups;
        for (int gp = 0; gp < ngroups; ++gp) {
            const float asl = h2f(sa[(size_t(tile) * ngroups + gp) * 16 + col]);
            const float bsl = h2f(sb[(size_t(tile) * ngroups + gp) * 16 + col]);
            float asr[8], bsr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { asr[r] = __shfl(asl, 2 * r + half, 32); bsr[r] = __shfl(bsl, 2 * r + half, 32); }
            // readfirstlane: the schedule is wave-uniform, but the compiler cannot prove it from a
            // global load, and a divergent switch turns the run loop into an exec-masked waterfall.
            const unsigned mask = __builtin_amdgcn_readfirstlane(unit[gp]);
            int j = 0;
            while (j < G) {
#ifdef DFR_NOSPLIT
                const int len = G;
#else
                const int len = __builtin_amdgcn_readfirstlane(__ffs(int(mask >> j)));
#endif
                const int k0 = (gp * G + j) * SLICES;
                float8 acc[TT];
                switch (len) {
                    case 1: run_blocks<TT, 1, UN>(acc, wbase, B, k0, Npad, tg, col); break;
                    case 2: run_blocks<TT, 2, UN>(acc, wbase, B, k0, Npad, tg, col); break;
                    case 4: run_blocks<TT, 4, UN>(acc, wbase, B, k0, Npad, tg, col); break;
                    default: run_blocks<TT, 8, UN>(acc, wbase, B, k0, Npad, tg, col); break;
                }
#pragma unroll
                for (int t = 0; t < TT; ++t) {
                    const float cs = cscale[size_t(tg + t * 16 + col) * ngroups + gp];
#pragma unroll
                    for (int r = 0; r < 8; ++r) {
                        float g, u; unpair(acc[t][r], g, u);
                        ya[t][r] = __builtin_fmaf(g, asr[r] * cs, ya[t][r]);
                        yb[t][r] = __builtin_fmaf(u, bsr[r] * cs, yb[t][r]);
                    }
                }
                j += len;
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            int token = tg + t * 16 + col;
            if (token >= rows) continue;
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                int row = tile * 16 + 2 * r + half;
                size_t o = size_t(token) * outstride + row;
                if constexpr (FUSE) out[o] = silu(ya[t][r]) * yb[t][r] * signs[row];
                else {
                    out[o] = resid[o] + ya[t][r];
                    out[o + rowoff] = resid[o + rowoff] + yb[t][r];
                }
            }
        }
    }
}


// The certificate picks the run length. For every token and every group, find the largest R in
// {1,2,4,8} for which every aligned run of R blocks has sum_k |q_k| <= BUDGET, and take the minimum
// over the batch. R = 1 is always legal: one 128-block of four-bit activations has L1 <= 7*128 =
// 896 <= 1023. The scale group stays 8 whatever R comes out, so the numerical object does not move
// with the data; only the FP32 summation order of the partial runs does.
template <int G, int BUDGET>
__global__ void k_pick(const uint16_t *__restrict__ l1, int *__restrict__ chosen,
                       int nb, int rows) {
    const int ngroups = nb / G, units = rows * ngroups;
    int best = G;
    for (int idx = blockIdx.x * blockDim.x + threadIdx.x; idx < units; idx += gridDim.x * blockDim.x) {
        const int token = idx / ngroups, gp = idx - token * ngroups;
        int m[G];
#pragma unroll
        for (int j = 0; j < G; ++j) m[j] = int(l1[(size_t) token * nb + gp * G + j]);
        int here = 1;
        for (int R = 2; R <= G; R <<= 1) {
            bool ok = true;
            for (int base = 0; base < G; base += R) {
                int sum = 0;
                for (int i = 0; i < R; ++i) sum += m[base + i];
                if (sum > BUDGET) { ok = false; break; }
            }
            if (ok) here = R; else break;
        }
        best = min(best, here);
    }
    atomicMin(chosen, best);
}

// k_proj with the scale group and the accumulator run length separated: scales and the activation
// amax belong to groups of GS blocks, the carrier is separated every R blocks, R divides GS. The
// kernel exits immediately unless the certificate chose its R, so the four compiled lengths cost
// three empty launches per projection and no branch in the loop.
template <int TT, int GS, int R, int UN, bool FUSE>
__global__ __launch_bounds__(NW * 32) void k_proj_run(
        const uint8_t *__restrict__ W, const void *__restrict__ B,
        const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const float *__restrict__ cscale, const int *__restrict__ chosen,
        const float *__restrict__ signs, const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride, int rowoff) {
    if (*chosen != R) return;
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    const int ngroups = nb / GS, nruns = nb / R;
    const uint8_t *wbase = W + size_t(tile) * nb * CODE_BLOCK_BYTES;
    for (int tg = tg0; tg < Npad; tg += tstride) {
        float ya[TT][8], yb[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { ya[t][r] = 0.f; yb[t][r] = 0.f; }
        for (int ri = 0; ri < nruns; ++ri) {
            const int gp = (ri * R) / GS;
            float8 acc[TT];
#pragma unroll
            for (int t = 0; t < TT; ++t) acc[t] = float8{};
            const int k0 = ri * R * SLICES;
#pragma unroll UN
            for (int q = 0; q < R * SLICES; ++q) {
                half16 a = decode_paired(*(const uint2 *) (wbase + size_t(k0 + q) * 128 + col * 8));
#pragma unroll
                for (int t = 0; t < TT; ++t)
                    acc[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(
                        a, ((const half16 *) B)[size_t(k0 + q) * Npad + tg + t * 16 + col], acc[t]);
            }
            const float asl = h2f(sa[(size_t(tile) * ngroups + gp) * 16 + col]);
            const float bsl = h2f(sb[(size_t(tile) * ngroups + gp) * 16 + col]);
            float asr[8], bsr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { asr[r] = __shfl(asl, 2 * r + half, 32); bsr[r] = __shfl(bsl, 2 * r + half, 32); }
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                const float cs = cscale[size_t(tg + t * 16 + col) * ngroups + gp];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    float g, u; unpair(acc[t][r], g, u);
                    ya[t][r] = __builtin_fmaf(g, asr[r] * cs, ya[t][r]);
                    yb[t][r] = __builtin_fmaf(u, bsr[r] * cs, yb[t][r]);
                }
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            int token = tg + t * 16 + col;
            if (token >= rows) continue;
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                int row = tile * 16 + 2 * r + half;
                size_t o = size_t(token) * outstride + row;
                if constexpr (FUSE) out[o] = silu(ya[t][r]) * yb[t][r] * signs[row];
                else {
                    out[o] = resid[o] + ya[t][r];
                    out[o + rowoff] = resid[o + rowoff] + yb[t][r];
                }
            }
        }
    }
}


// Per work-unit certificate. A work unit is exactly the TT*16 tokens one pass of the projection's
// tg loop owns, which is the finest granularity at which the run length can change without either
// a variable-length inner loop or re-reading the weight stream once per token tile. One workgroup
// per (unit, group): each thread takes one token, the maxima over the unit are reduced in LDS, and
// the run lengths that fail the budget are OR-ed into the unit's failure mask.
template <int G, int BUDGET>
__global__ __launch_bounds__(64) void k_pick_units(const uint16_t *__restrict__ l1,
        uint8_t *__restrict__ fail, int nb, int rows, int ts) {
    __shared__ int red[64][G];
    const int ngroups = nb / G;
    const int unit = blockIdx.x / ngroups, gp = blockIdx.x - unit * ngroups;
    const int t = threadIdx.x, token = unit * ts + t;
#pragma unroll
    for (int j = 0; j < G; ++j)
        red[t][j] = (t < ts && token < rows) ? int(l1[(size_t) token * nb + gp * G + j]) : 0;
    __syncthreads();
    if (t >= G) return;
    int m = 0;
    for (int i = 0; i < 64; ++i) m = max(m, red[i][t]);
    red[0][t] = m;                       // reuse: row 0 now holds the unit's per-block maxima
    __syncthreads();
    if (t) return;
    unsigned bad = 0;
    for (int R = 2, bit = 0; R <= G; R <<= 1, ++bit)
        for (int base = 0; base < G; base += R) {
            int sum = 0;
            for (int i = 0; i < R; ++i) sum += red[0][base + i];
            if (sum > BUDGET) { bad |= 1u << bit; break; }
        }
    if (bad) atomicOr((unsigned *) (fail + (unit & ~3u)), bad << (8 * (unit & 3)));
}

__device__ __forceinline__ int chosen_run(unsigned bad, int G) {
    int r = 1;
    for (int R = 2, bit = 0; R <= G; R <<= 1, ++bit) {
        if (bad & (1u << bit)) break;
        r = R;
    }
    return r;
}

// k_proj_run, with the run length chosen per work unit instead of per call. Each of the four
// compiled lengths sweeps the same grid and skips the units that chose a different length, so the
// total work is unchanged and the cost is three extra launches whose workgroups exit at the tg
// test. The inner loop is still a compile-time constant length.
template <int TT, int GS, int R, int UN, bool FUSE>
__global__ __launch_bounds__(NW * 32) void k_proj_unit(
        const uint8_t *__restrict__ W, const void *__restrict__ B,
        const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const float *__restrict__ cscale, const uint8_t *__restrict__ fail,
        const float *__restrict__ signs, const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride, int rowoff) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    const int ngroups = nb / GS, nruns = nb / R;
    const uint8_t *wbase = W + size_t(tile) * nb * CODE_BLOCK_BYTES;
    for (int tg = tg0; tg < Npad; tg += tstride) {
        if (chosen_run(fail[tg / (TT * 16)], GS) != R) continue;
        float ya[TT][8], yb[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { ya[t][r] = 0.f; yb[t][r] = 0.f; }
        for (int ri = 0; ri < nruns; ++ri) {
            const int gp = (ri * R) / GS;
            float8 acc[TT];
#pragma unroll
            for (int t = 0; t < TT; ++t) acc[t] = float8{};
            const int k0 = ri * R * SLICES;
#pragma unroll UN
            for (int q = 0; q < R * SLICES; ++q) {
                half16 a = decode_paired(*(const uint2 *) (wbase + size_t(k0 + q) * 128 + col * 8));
#pragma unroll
                for (int t = 0; t < TT; ++t)
                    acc[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(
                        a, ((const half16 *) B)[size_t(k0 + q) * Npad + tg + t * 16 + col], acc[t]);
            }
            const float asl = h2f(sa[(size_t(tile) * ngroups + gp) * 16 + col]);
            const float bsl = h2f(sb[(size_t(tile) * ngroups + gp) * 16 + col]);
            float asr[8], bsr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { asr[r] = __shfl(asl, 2 * r + half, 32); bsr[r] = __shfl(bsl, 2 * r + half, 32); }
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                const float cs = cscale[size_t(tg + t * 16 + col) * ngroups + gp];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    float g, u; unpair(acc[t][r], g, u);
                    ya[t][r] = __builtin_fmaf(g, asr[r] * cs, ya[t][r]);
                    yb[t][r] = __builtin_fmaf(u, bsr[r] * cs, yb[t][r]);
                }
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            int token = tg + t * 16 + col;
            if (token >= rows) continue;
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                int row = tile * 16 + 2 * r + half;
                size_t o = size_t(token) * outstride + row;
                if constexpr (FUSE) out[o] = silu(ya[t][r]) * yb[t][r] * signs[row];
                else {
                    out[o] = resid[o] + ya[t][r];
                    out[o + rowoff] = resid[o + rowoff] + yb[t][r];
                }
            }
        }
    }
}

// ------------------------------------------------------------------ host packing

// Paired codes without the per-block scale tail: 1024 bytes per (16 rows x 128 K).
std::vector<uint8_t> pack_codes(const int8_t *gate, const int8_t *up, int rows, int kdim) {
    int nb = kdim / KB;
    std::vector<uint8_t> out(size_t(rows / 16) * nb * CODE_BLOCK_BYTES, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            uint8_t *dst = out.data() + (size_t(tile) * nb + b) * CODE_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                const int8_t *g = gate + size_t(tile * 16 + r) * kdim + b * KB;
                const int8_t *u = up + size_t(tile * 16 + r) * kdim + b * KB;
                for (int j = 0; j < KB; ++j)
                    dst[(j / 16) * 128 + r * 8 + (j % 16) / 2] |= pair_code(g[j], u[j]) << (4 * (j & 1));
            }
        }
    return out;
}

// One shared scale per (row, G blocks), stored [tile][group][16 rows] - the 16 scales a wave needs
// for one group in 32 contiguous bytes. L minimises the relative RMS of L against the deployed
// per-block scales: L = sum(1/lam) / sum(1/lam^2). At G = 1 it returns lam itself, so the control
// carries the deployed scales unchanged.
std::vector<uint16_t> group_scales(const std::vector<uint16_t> &lam, int rows, int nb, int G) {
    const int ngroups = nb / G;
    std::vector<uint16_t> out(size_t(rows / 16) * ngroups * 16);
    for (int row = 0; row < rows; ++row)
        for (int gp = 0; gp < ngroups; ++gp) {
            double a = 0, b = 0;
            for (int j = 0; j < G; ++j) {
                _Float16 h; std::memcpy(&h, &lam[size_t(row) * nb + gp * G + j], 2);
                double l = (double) (float) h;
                if (l > 0) { a += 1.0 / l; b += 1.0 / (l * l); }
            }
            _Float16 L = (_Float16) (float) (b > 0 ? a / b : 0.0);
            std::memcpy(&out[(size_t(row / 16) * ngroups + gp) * 16 + row % 16], &L, 2);
        }
    return out;
}

// ------------------------------------------------------------------ candidate plumbing

struct Plan {
    int D = 0, FF = 0, maxrows = 0, G = 1;
    uint8_t *wgu = nullptr, *wd = nullptr;
    uint16_t *sg = nullptr, *su = nullptr, *sd0 = nullptr, *sd1 = nullptr;
    void *Bin = nullptr, *Bhid = nullptr;
    float *csin = nullptr, *cshid = nullptr, *hidden = nullptr;
    uint16_t *l1in = nullptr, *l1hid = nullptr;     // per (token, 128-block) L1 of the quantised activation
    uint8_t *schin = nullptr, *schhid = nullptr;    // per (token tile, group) run-boundary bits
    int *pick = nullptr;                            // [2] certified run length, input and hidden
    const float *norm = nullptr, *signs = nullptr;
    size_t bytes = 0;
};

void decode_matrix(const uint8_t *halo_bytes, int rows, int kdim,
                   std::vector<int8_t> &trits, std::vector<uint16_t> &scales) {
    int nb = kdim / 128;
    trits.assign(size_t(rows) * kdim, 0);
    scales.assign(size_t(rows) * nb, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            size_t src = (size_t(tile / 2) * nb + b) * halo::TILE_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                int lane = (tile & 1) * 16 + r, row = tile * 16 + r;
                uint8_t qs[24], t128[128];
                std::memcpy(qs, halo_bytes + src + halo::tile_off_qs_a(lane), 16);
                std::memcpy(qs + 16, halo_bytes + src + halo::tile_off_qs_b(lane), 8);
                const uint8_t *tail = halo_bytes + src + halo::tile_off_tail(lane);
                halo::decode_block(qs, tail, t128);
                std::memcpy(&scales[size_t(row) * nb + b], tail + 2, 2);
                for (int j = 0; j < 128; ++j) trits[size_t(row) * kdim + b * 128 + j] = int8_t(int(t128[j]) - 1);
            }
        }
}

template <class T> void upload(T *&dst, const std::vector<T> &src, size_t &total) {
    check(hipMalloc(&dst, src.size() * sizeof(T)), "malloc");
    check(hipMemcpy(dst, src.data(), src.size() * sizeof(T), hipMemcpyHostToDevice), "upload");
    total += src.size() * sizeof(T);
}

template <int G>
void *prepare(const kelana_batch::Weights &w, int maxrows) {
    auto *p = new Plan{};
    p->D = w.width; p->FF = w.hidden; p->maxrows = maxrows; p->G = G;
    p->norm = w.norm_device; p->signs = w.signs_device;
    std::vector<int8_t> g, u, d;
    std::vector<uint16_t> gs, us, ds;
    decode_matrix(w.gate_host, p->FF, p->D, g, gs);
    decode_matrix(w.up_host, p->FF, p->D, u, us);
    decode_matrix(w.down_host, p->D, p->FF, d, ds);
    const int Dh = p->D / 2, nbd = p->D / KB, nbf = p->FF / KB;
    std::vector<int8_t> d0(d.begin(), d.begin() + size_t(Dh) * p->FF), d1(d.begin() + size_t(Dh) * p->FF, d.end());
    std::vector<uint16_t> ds0(ds.begin(), ds.begin() + size_t(Dh) * nbf), ds1(ds.begin() + size_t(Dh) * nbf, ds.end());
    upload(p->wgu, pack_codes(g.data(), u.data(), p->FF, p->D), p->bytes);
    upload(p->wd, pack_codes(d0.data(), d1.data(), Dh, p->FF), p->bytes);
    upload(p->sg, group_scales(gs, p->FF, nbd, G), p->bytes);
    upload(p->su, group_scales(us, p->FF, nbd, G), p->bytes);
    upload(p->sd0, group_scales(ds0, Dh, nbf, G), p->bytes);
    upload(p->sd1, group_scales(ds1, Dh, nbf, G), p->bytes);
    const int Npad = (maxrows + 15) / 16 * 16;
    const size_t bin = size_t(p->D / 16) * Npad * 32, bhid = size_t(p->FF / 16) * Npad * 32;
    check(hipMalloc(&p->Bin, bin), "Bin");
    check(hipMalloc(&p->Bhid, bhid), "Bhid");
    check(hipMemset(p->Bin, 0, bin), "Bin zero");
    check(hipMemset(p->Bhid, 0, bhid), "Bhid zero");
    const size_t csin = size_t(Npad) * (nbd / G) * 4, cshid = size_t(Npad) * (nbf / G) * 4;
    check(hipMalloc(&p->csin, csin), "csin");
    check(hipMalloc(&p->cshid, cshid), "cshid");
    check(hipMemset(p->csin, 0, csin), "csin zero");
    check(hipMemset(p->cshid, 0, cshid), "cshid zero");
    check(hipMalloc(&p->hidden, size_t(Npad) * p->FF * 4), "hidden");
    const size_t l1in = size_t(Npad) * nbd * 2, l1hid = size_t(Npad) * nbf * 2;
    const size_t schin = size_t(Npad / 16) * (nbd / G), schhid = size_t(Npad / 16) * (nbf / G);   // >= one entry per schedule unit
    check(hipMalloc(&p->l1in, l1in), "l1in");
    check(hipMalloc(&p->l1hid, l1hid), "l1hid");
    check(hipMalloc(&p->schin, schin), "schin");
    check(hipMalloc(&p->schhid, schhid), "schhid");
    check(hipMalloc(&p->pick, 8), "pick");
    check(hipMemset(p->l1in, 0, l1in), "l1in zero");
    check(hipMemset(p->l1hid, 0, l1hid), "l1hid zero");
    check(hipMemset(p->schin, 0xff, schin), "schin fill");
    check(hipMemset(p->schhid, 0xff, schhid), "schhid fill");
    p->bytes += l1in + l1hid + schin + schhid;
    p->bytes += bin + bhid + csin + cshid + size_t(Npad) * p->FF * 4;
    return p;
}

void release(void *state) {
    auto *p = static_cast<Plan *>(state);
    for (void *q : {(void *) p->wgu, (void *) p->wd, (void *) p->sg, (void *) p->su,
                    (void *) p->sd0, (void *) p->sd1, p->Bin, p->Bhid,
                    (void *) p->csin, (void *) p->cshid, (void *) p->hidden,
                    (void *) p->l1in, (void *) p->l1hid, (void *) p->schin, (void *) p->schhid,
                    (void *) p->pick})
        if (q) hipFree(q);
    delete p;
}
size_t resident_bytes(void *state) { return static_cast<Plan *>(state)->bytes; }

struct Stages {
    bool on = getenv("KELANA_DFR_STAGES") != nullptr;
    hipEvent_t ev[5]{};
    const char *name[4] = {"prep_in", "gate_up_silu", "prep_hidden", "down_residual"};
    int at = 0;
    void mark(hipStream_t s) { if (!on) return; if (!ev[at]) hipEventCreate(&ev[at]); hipEventRecord(ev[at], s); ++at; }
    void report(const char *who, int rows) {
        if (!on) return;
        hipEventSynchronize(ev[4]);
        std::fprintf(stderr, "%-22s rows %-4d", who, rows);
        for (int i = 0; i < 4; ++i) { float t = 0; hipEventElapsedTime(&t, ev[i], ev[i + 1]);
            std::fprintf(stderr, "  %s %6.3f ms", name[i], t); }
        std::fprintf(stderr, "\n");
        at = 0;
    }
};

int group_split(int tiles, int groups) {
    int want = 320 / (tiles > 0 ? tiles : 1);
    return std::max(1, std::min(groups, want));
}

template <int G, int UN, int CLIP_PCT>
void run(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    static Stages st;
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    st.mark(stream);
    k_prep<G, true, true, CLIP_PCT><<<rows * (D / 1024), NT, 0, stream>>>(
        input, p->norm, p->Bin, p->csin, D, rows, Npad);
    st.mark(stream);
#define PROJ(TT, FUSE, W, BF, SA, SB, CS, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF) \
    k_proj<TT, G, UN, FUSE><<<dim3((TILES) / NW, group_split((TILES) / NW, Npad / (TT * 16))), \
        NW * 32, 0, stream>>>(W, BF, SA, SB, CS, SIGNS, RESID, OUT, NB, rows, Npad, OSTRIDE, ROWOFF)
    if (Npad >= 64) {
        PROJ(4, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    } else if (Npad == 32) {
        PROJ(2, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    } else {
        PROJ(1, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    }
    st.mark(stream);
    k_prep<G, false, false, CLIP_PCT><<<rows * (FF / 1024), NT, 0, stream>>>(
        p->hidden, nullptr, p->Bhid, p->cshid, FF, rows, Npad);
    st.mark(stream);
    if (Npad >= 64) {
        PROJ(4, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    } else if (Npad == 32) {
        PROJ(2, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    } else {
        PROJ(1, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    }
#undef PROJ
    st.mark(stream);
    st.report(G == 1 ? "dfr-control" : "dfr-defer", rows);
}

template <int G, int UN, int CLIP_PCT>
kelana_batch::Candidate make(const char *name, const char *desc) {
    kelana_batch::Candidate c{};
    c.name = name;
    c.claim = kelana_batch::Claim::approximate;
    c.description = desc;
    c.prepare = prepare<G>;
    c.run = run<G, UN, CLIP_PCT>;
    c.release = release;
    c.resident_bytes = resident_bytes;
    return c;
}


// Certificate-scheduled run. Same group-8 scales and quantiser as run<8,...>; the accumulator is
// split wherever the L1 budget says it must be. The producer's extra reduction, the scheduler
// launch and the schedule read are all inside the timed region.
template <int G, int UN, int BUDGET>
void run_cert(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    static Stages st;
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    const int nbd = D / KB, nbf = FF / KB;
    st.mark(stream);
    k_prep<G, true, true, 100, true><<<rows * (D / 1024), NT, 0, stream>>>(
        input, p->norm, p->Bin, p->csin, D, rows, Npad, p->l1in);
    const int ts = Npad >= 64 ? 64 : Npad, nunits = (Npad + ts - 1) / ts;
    k_sched<G, BUDGET><<<(nunits * (nbd / G) + 63) / 64, 64, 0, stream>>>(
        p->l1in, p->schin, nbd, rows, nunits, ts);
    st.mark(stream);
#define PROJC(TT, FUSE, W, BF, SA, SB, CS, SCH, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF) \
    k_proj_cert<TT, G, UN, FUSE><<<dim3((TILES) / NW, group_split((TILES) / NW, Npad / (TT * 16))), \
        NW * 32, 0, stream>>>(W, BF, SA, SB, CS, SCH, SIGNS, RESID, OUT, NB, rows, Npad, OSTRIDE, ROWOFF)
    if (Npad >= 64) {
        PROJC(4, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->schin, p->signs, nullptr, p->hidden, nbd, FF / 16, FF, 0);
    } else if (Npad == 32) {
        PROJC(2, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->schin, p->signs, nullptr, p->hidden, nbd, FF / 16, FF, 0);
    } else {
        PROJC(1, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->schin, p->signs, nullptr, p->hidden, nbd, FF / 16, FF, 0);
    }
    st.mark(stream);
    k_prep<G, false, false, 100, true><<<rows * (FF / 1024), NT, 0, stream>>>(
        p->hidden, nullptr, p->Bhid, p->cshid, FF, rows, Npad, p->l1hid);
    k_sched<G, BUDGET><<<(nunits * (nbf / G) + 63) / 64, 64, 0, stream>>>(
        p->l1hid, p->schhid, nbf, rows, nunits, ts);
    st.mark(stream);
    if (Npad >= 64) {
        PROJC(4, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, p->schhid, nullptr, input, output, nbf, Dh / 16, D, Dh);
    } else if (Npad == 32) {
        PROJC(2, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, p->schhid, nullptr, input, output, nbf, Dh / 16, D, Dh);
    } else {
        PROJC(1, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, p->schhid, nullptr, input, output, nbf, Dh / 16, D, Dh);
    }
#undef PROJC
    st.mark(stream);
    st.report("dfr-cert", rows);
}

template <int G, int UN, int BUDGET>
kelana_batch::Candidate make_cert(const char *name, const char *desc) {
    kelana_batch::Candidate c{};
    c.name = name;
    c.claim = kelana_batch::Claim::approximate;
    c.description = desc;
    c.prepare = prepare<G>;
    c.run = run_cert<G, UN, BUDGET>;
    c.release = release;
    c.resident_bytes = resident_bytes;
    return c;
}

kelana_batch::Candidate dfr_cert1023() {
    return make_cert<8, 2, 1023>("dfr-cert1023-paired-a4",
        "group-8 scales, separation forced wherever the per-token-tile L1 certificate says the carrier could wrap");
}
kelana_batch::Candidate dfr_cert_unbounded() {
    return make_cert<8, 2, 1000000>("dfr-cert-unbounded-paired-a4",
        "the certificate kernel with a budget nothing can exceed: isolates the scheduling machinery from the shorter runs");
}


// Certified fixed split: group-8 scales throughout, one certified run length per projection per
// call, chosen on device from the activations that call actually quantised. Producer reduction,
// the picking kernel and the three empty launches are all inside the timed region.
template <int G, int UN, int BUDGET>
void run_certfixed(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    static Stages st;
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    const int nbd = D / KB, nbf = FF / KB;
    const int init[2] = {G, G};
    st.mark(stream);
    check(hipMemcpyAsync(p->pick, init, 8, hipMemcpyHostToDevice, stream), "pick init");
    k_prep<G, true, true, 100, true><<<rows * (D / 1024), NT, 0, stream>>>(
        input, p->norm, p->Bin, p->csin, D, rows, Npad, p->l1in);
    k_pick<G, BUDGET><<<40, 64, 0, stream>>>(p->l1in, p->pick, nbd, rows);
    st.mark(stream);
#define PROJR(TT, R, FUSE, W, BF, SA, SB, CS, PICK, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF) \
    k_proj_run<TT, G, R, UN, FUSE><<<dim3((TILES) / NW, group_split((TILES) / NW, Npad / (TT * 16))), \
        NW * 32, 0, stream>>>(W, BF, SA, SB, CS, PICK, SIGNS, RESID, OUT, NB, rows, Npad, OSTRIDE, ROWOFF)
#define PROJR_ALL(TT, FUSE, W, BF, SA, SB, CS, PICK, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF) \
    PROJR(TT, 1, FUSE, W, BF, SA, SB, CS, PICK, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF); \
    PROJR(TT, 2, FUSE, W, BF, SA, SB, CS, PICK, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF); \
    PROJR(TT, 4, FUSE, W, BF, SA, SB, CS, PICK, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF); \
    PROJR(TT, 8, FUSE, W, BF, SA, SB, CS, PICK, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF)
    if (Npad >= 64) {
        PROJR_ALL(4, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->pick, p->signs, nullptr, p->hidden, nbd, FF / 16, FF, 0);
    } else if (Npad == 32) {
        PROJR_ALL(2, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->pick, p->signs, nullptr, p->hidden, nbd, FF / 16, FF, 0);
    } else {
        PROJR_ALL(1, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->pick, p->signs, nullptr, p->hidden, nbd, FF / 16, FF, 0);
    }
    st.mark(stream);
    k_prep<G, false, false, 100, true><<<rows * (FF / 1024), NT, 0, stream>>>(
        p->hidden, nullptr, p->Bhid, p->cshid, FF, rows, Npad, p->l1hid);
    k_pick<G, BUDGET><<<40, 64, 0, stream>>>(p->l1hid, p->pick + 1, nbf, rows);
    st.mark(stream);
    if (Npad >= 64) {
        PROJR_ALL(4, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, p->pick + 1, nullptr, input, output, nbf, Dh / 16, D, Dh);
    } else if (Npad == 32) {
        PROJR_ALL(2, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, p->pick + 1, nullptr, input, output, nbf, Dh / 16, D, Dh);
    } else {
        PROJR_ALL(1, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, p->pick + 1, nullptr, input, output, nbf, Dh / 16, D, Dh);
    }
#undef PROJR_ALL
#undef PROJR
    st.mark(stream);
    st.report("dfr-certfixed", rows);
}

template <int G, int UN, int BUDGET>
kelana_batch::Candidate make_certfixed(const char *name, const char *desc) {
    kelana_batch::Candidate c{};
    c.name = name; c.claim = kelana_batch::Claim::approximate; c.description = desc;
    c.prepare = prepare<G>; c.run = run_certfixed<G, UN, BUDGET>;
    c.release = release; c.resident_bytes = resident_bytes;
    return c;
}

kelana_batch::Candidate dfr_certfixed1023() {
    return make_certfixed<8, 2, 1023>("dfr-certfixed1023-paired-a4",
        "group-8 scales, run length certified per call by the activation L1 budget of 1023");
}
kelana_batch::Candidate dfr_certfixed_unbounded() {
    return make_certfixed<8, 2, 1000000>("dfr-certfixed-unbounded-paired-a4",
        "the certified-split machinery with a budget nothing can exceed: isolates its overhead");
}


// Certified split with the run length chosen per work unit.
template <int G, int UN, int BUDGET>
void run_certunit(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    static Stages st;
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    const int nbd = D / KB, nbf = FF / KB;
    const int ts = Npad >= 64 ? 64 : Npad, nunits = (Npad + ts - 1) / ts;
    const size_t failbytes = size_t((nunits + 3) & ~3);
    st.mark(stream);
    check(hipMemsetAsync(p->schin, 0, failbytes, stream), "fail zero");
    k_prep<G, true, true, 100, true><<<rows * (D / 1024), NT, 0, stream>>>(
        input, p->norm, p->Bin, p->csin, D, rows, Npad, p->l1in);
    k_pick_units<G, BUDGET><<<nunits * (nbd / G), 64, 0, stream>>>(p->l1in, p->schin, nbd, rows, ts);
    st.mark(stream);
#define PROJU(TT, R, FUSE, W, BF, SA, SB, CS, FAIL, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF) \
    k_proj_unit<TT, G, R, UN, FUSE><<<dim3((TILES) / NW, group_split((TILES) / NW, Npad / (TT * 16))), \
        NW * 32, 0, stream>>>(W, BF, SA, SB, CS, FAIL, SIGNS, RESID, OUT, NB, rows, Npad, OSTRIDE, ROWOFF)
#define PROJU_ALL(TT, FUSE, W, BF, SA, SB, CS, FAIL, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF) \
    PROJU(TT, 1, FUSE, W, BF, SA, SB, CS, FAIL, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF); \
    PROJU(TT, 2, FUSE, W, BF, SA, SB, CS, FAIL, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF); \
    PROJU(TT, 4, FUSE, W, BF, SA, SB, CS, FAIL, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF); \
    PROJU(TT, 8, FUSE, W, BF, SA, SB, CS, FAIL, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF)
    if (Npad >= 64) {
        PROJU_ALL(4, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->schin, p->signs, nullptr, p->hidden, nbd, FF / 16, FF, 0);
    } else if (Npad == 32) {
        PROJU_ALL(2, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->schin, p->signs, nullptr, p->hidden, nbd, FF / 16, FF, 0);
    } else {
        PROJU_ALL(1, true, p->wgu, p->Bin, p->sg, p->su, p->csin, p->schin, p->signs, nullptr, p->hidden, nbd, FF / 16, FF, 0);
    }
    st.mark(stream);
    check(hipMemsetAsync(p->schhid, 0, failbytes, stream), "fail zero");
    k_prep<G, false, false, 100, true><<<rows * (FF / 1024), NT, 0, stream>>>(
        p->hidden, nullptr, p->Bhid, p->cshid, FF, rows, Npad, p->l1hid);
    k_pick_units<G, BUDGET><<<nunits * (nbf / G), 64, 0, stream>>>(p->l1hid, p->schhid, nbf, rows, ts);
    st.mark(stream);
    if (Npad >= 64) {
        PROJU_ALL(4, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, p->schhid, nullptr, input, output, nbf, Dh / 16, D, Dh);
    } else if (Npad == 32) {
        PROJU_ALL(2, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, p->schhid, nullptr, input, output, nbf, Dh / 16, D, Dh);
    } else {
        PROJU_ALL(1, false, p->wd, p->Bhid, p->sd0, p->sd1, p->cshid, p->schhid, nullptr, input, output, nbf, Dh / 16, D, Dh);
    }
#undef PROJU_ALL
#undef PROJU
    st.mark(stream);
    st.report("dfr-certunit", rows);
}

template <int G, int UN, int BUDGET>
kelana_batch::Candidate make_certunit(const char *name, const char *desc) {
    kelana_batch::Candidate c{};
    c.name = name; c.claim = kelana_batch::Claim::approximate; c.description = desc;
    c.prepare = prepare<G>; c.run = run_certunit<G, UN, BUDGET>;
    c.release = release; c.resident_bytes = resident_bytes;
    return c;
}

kelana_batch::Candidate dfr_certunit1023() {
    return make_certunit<8, 2, 1023>("dfr-certunit1023-paired-a4",
        "group-8 scales, run length certified per projection work unit rather than per call");
}

kelana_batch::Candidate dfr_control() {
    return make<1, 2, 100>("dfr-control-paired-a4",
        "matched control: paired FP16 g+2047u separated every 128-block, deployed per-block scales");
}
kelana_batch::Candidate dfr_defer2() {
    return make<2, 2, 100>("dfr-defer2-paired-a4",
        "paired FP16 carrier separated every 2 blocks (256 columns), shared weight and activation scale");
}
kelana_batch::Candidate dfr_defer4() {
    return make<4, 2, 100>("dfr-defer4-paired-a4",
        "paired FP16 carrier separated every 4 blocks (512 columns), shared weight and activation scale");
}
kelana_batch::Candidate dfr_defer8() {
    return make<8, 2, 100>("dfr-defer8-paired-a4",
        "paired FP16 carrier separated every 8 blocks (1024 columns), shared weight and activation scale");
}
kelana_batch::Candidate dfr_defer4_clip80() {
    return make<4, 2, 80>("dfr-defer4-paired-a4-clip80",
        "deferral over 4 blocks with the grouped quantiser step shortened to 0.8*amax/7");
}
kelana_batch::Candidate dfr_defer8_clip80() {
    return make<8, 2, 80>("dfr-defer8-paired-a4-clip80",
        "deferral over 8 blocks with the grouped quantiser step shortened to 0.8*amax/7");
}
kelana_batch::Candidate dfr_control_u1() {
    return make<1, 1, 100>("dfr-control-paired-a4-u1",
        "matched control with the slice loop rolled, the shape the arithmetic worker's paired map uses");
}
kelana_batch::Candidate dfr_defer8_u4() {
    return make<8, 4, 100>("dfr-defer8-paired-a4-u4",
        "deferral over 8 blocks with the slice loop unrolled four times");
}
}
KELANA_BATCH_REGISTER(dfr_control)
KELANA_BATCH_REGISTER(dfr_defer2)
KELANA_BATCH_REGISTER(dfr_defer4)
KELANA_BATCH_REGISTER(dfr_defer8)
KELANA_BATCH_REGISTER(dfr_defer4_clip80)
KELANA_BATCH_REGISTER(dfr_defer8_clip80)
KELANA_BATCH_REGISTER(dfr_control_u1)
KELANA_BATCH_REGISTER(dfr_defer8_u4)
KELANA_BATCH_REGISTER(dfr_cert1023)
KELANA_BATCH_REGISTER(dfr_cert_unbounded)
KELANA_BATCH_REGISTER(dfr_certfixed1023)
KELANA_BATCH_REGISTER(dfr_certfixed_unbounded)
KELANA_BATCH_REGISTER(dfr_certunit1023)
