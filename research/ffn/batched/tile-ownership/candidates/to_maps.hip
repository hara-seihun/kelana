// Whole-FFN candidates that change only who owns a weight tile.
//
// The projection kernels of the arithmetic and compact-scaled workers give one 16-row weight tile
// to each wave, and a wave walks the token axis TT tiles at a time. Every wave of a workgroup then
// streams a different tile's weights, and when the token axis has to be split across workgroups to
// fill the device, each split re-reads the whole weight stream.
//
// The other mapping, measured as a by-product in ../seven-product/README.md, gives one row tile to
// the whole workgroup and one token group to each wave. Then the waves of a workgroup read the same
// weight bytes at the same time, the tokens covered per weight read grow by the wave count instead
// of by the accumulator count, and the row-tile grid grows by the wave count, so the token axis
// needs fewer workgroup-level splits. It costs no registers. On the projection alone it was worth
// 1.110x to the eight-product IU4 map at 256 rows and lost badly at 128; this directory asks what
// it does to a whole FFN, on the kernels that are actually fast, with every producer, scale and
// epilogue included.
//
// Three ownership maps, one source, one epilogue:
//
//   tile     wave owns a row tile, workgroup covers NW tiles          (the deployed control)
//   share    workgroup owns a row tile, wave owns a token group
//   share-k  workgroup owns a row tile, wave owns (token group, K split); the K splits are
//            reduced through LDS at the end, which is the only variant that adds a boundary
//
// crossed with three operand classes, all of which keep the deployed ternary weights and their
// deployed FP16 block scales:
//
//   iu8-a8   v_wmma_i32_16x16x16_iu8, eight-bit activations, per-128 integer drain   (A8, primary)
//   csf16-a8 scaled FP16 weights in registers, eight-bit activation values as FP16, one FP32
//            accumulator across the whole K, no per-block epilogue                   (A8, fastest)
//   iu4-a4   v_wmma_i32_16x16x16_iu4, four-bit activations                           (A4)
//
// Nothing here changes activation precision, the quantiser, the weight representation or the
// summation semantics of a wave's own accumulator. The one numerical difference is in share-k,
// where the FP32 accumulation of a row's K is split into KS interleaved partial sums that are added
// at the end; the products are the same products.
//
// The producers, the packers and the epilogues are copied from the two owning directories so that
// this file's `tile` candidates are source-matched controls for its `share` candidates: within this
// file, the ownership map is the only difference. The owners' own candidates stay in the comparison
// as the external check that these controls reproduce them.
#include "../../api.hpp"
#include "../../arithmetic/maps.hpp"
#include "../../compact-scaled/scaled.hpp"
#include "halo_format.h"
#include <hip/hip_runtime.h>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

namespace {

using kelana_arith::KB;
using kelana_arith::SLICES;
using kelana_arith::half16;
using kelana_arith::float8;
using kelana_arith::int8v;
using kelana_arith::int4v;
using kelana_arith::int2v;

constexpr int NT = 256;            // producer threads per 1024-element chunk
constexpr int NW = 4;              // waves per projection workgroup
constexpr float NORM_EPS = 1e-5f;

enum Klass { C_IU8 = 0, C_IU4 = 1, C_F16S = 2 };
enum Own { O_TILE = 0, O_SHARE = 1 };

// Weight-word order inside a 512-byte (16 rows x 128 K) block.
//
//   L_SLICE  [slice][row]: the deployed order. A lane reads one dword per slice, 64 bytes from the
//            next, so a block costs eight narrow loads per matrix.
//   L_LANE   [row][slice]: one lane's eight dwords are contiguous, so a block is two uint4 loads.
//            Same bytes, same image size, same weights; the reported lever of the dense-byte
//            worker's dc-paircode-wide-a4. Nothing about it depends on ownership, which is why it
//            is a separate axis here.
enum Layout { L_SLICE = 0, L_LANE = 1 };

// Bytes of one (k-slice, token) B fragment.
template <int C> struct FragBytes { static constexpr int value = C == C_IU8 ? 16 : C == C_IU4 ? 8 : 32; };

void check(hipError_t e, const char *what) {
    if (e != hipSuccess) { std::fprintf(stderr, "tile-ownership: %s: %s\n", what, hipGetErrorString(e)); std::abort(); }
}

// The weight words a lane needs for one 128-block, in the form its layout allows.
//
//   L_SLICE  one dword per slice, fetched one slice ahead. Loaded in the slice that uses them the
//            two words issue behind that slice's fragment loads and the operand expansion then
//            waits on the whole outstanding queue. The final read wraps to slice 0, cached, unused.
//   L_LANE   the whole block in two uint4 loads before the slice loop, which needs the slice loop
//            unrolled so the word index is a constant.
#define LOOP_UNROLL(LAY) ((LAY) == L_LANE ? SLICES : 1)
template <int LAY> struct WideWords {
    unsigned w[LAY == L_LANE ? 8 : 1];
    __device__ __forceinline__ explicit WideWords(const uint8_t *p) {
        if constexpr (LAY == L_LANE) {
            const uint4 lo = *(const uint4 *) p, hi = *(const uint4 *) (p + 16);
            w[0] = lo.x; w[1] = lo.y; w[2] = lo.z; w[3] = lo.w;
            w[4] = hi.x; w[5] = hi.y; w[6] = hi.z; w[7] = hi.w;
        } else w[0] = *(const unsigned *) p;
    }
    __device__ __forceinline__ unsigned take(const uint8_t *p, int s) {
        if constexpr (LAY == L_LANE) return w[s];
        const unsigned cur = w[0];
        w[0] = *(const unsigned *) (p + (((s + 1) & (SLICES - 1)) * 64));
        return cur;
    }
};

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
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    if (lane == 0) red[wave] = v;
    __syncthreads();
    float t = 0;
#pragma unroll
    for (int w = 0; w < NT / 32; ++w) t += red[w];
    return t;
}

// ------------------------------------------------------------------ activation producer
//
// One workgroup per (row, 1024-chunk): post-attention RMS norm, the folded width-D sign vector and
// the 1024-point Hadamard with the 1/32 factor, exactly as the deployed prep_chunk_r and as both
// owning directories' producers. Only the destination representation differs by class, and the
// destination is the WMMA B fragment itself, [kslice][token][16].
//
//   C_IU8   eight-bit codes, scale amax/127 per (token, 128-block) written to cscale
//   C_IU4   four-bit codes, scale amax/7
//   C_F16S  the eight-bit code times its block scale, rounded to FP16; no cscale is read by the
//           projection because the activation carries its own scale
template <int C, bool NORM, bool HAS_SIGN>
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
            const float4 t = *(const float4 *) (x + rb + i);
            ss = fmaf(t.x, t.x, ss); ss = fmaf(t.y, t.y, ss);
            ss = fmaf(t.z, t.z, ss); ss = fmaf(t.w, t.w, ss);
        }
        ss = block_sum(ss, red);
        inv = rsqrtf(ss / (float) n + NORM_EPS);
    }
    float4 v = *(const float4 *) (x + rb + base);
    if constexpr (HAS_SIGN) {
        const float4 k = *(const float4 *) (kvec + base);
        v.x *= inv * k.x; v.y *= inv * k.y; v.z *= inv * k.z; v.w *= inv * k.w;
    }
    { float p0 = v.x + v.y, p1 = v.x - v.y, p2 = v.z + v.w, p3 = v.z - v.w;
      v.x = p0 + p2; v.y = p1 + p3; v.z = p0 - p2; v.w = p1 - p3; }
#pragma unroll
    for (int bit = 1; bit < 32; bit <<= 1) {
        const bool upper = (lane & bit) != 0;
        const float ox = __shfl_xor(v.x, bit, 32), oy = __shfl_xor(v.y, bit, 32);
        const float oz = __shfl_xor(v.z, bit, 32), ow = __shfl_xor(v.w, bit, 32);
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
                const float x0 = u[m], x1 = u[m + len]; u[m] = x0 + x1; u[m + len] = x0 - x1;
            }
#pragma unroll
        for (int m = 0; m < 8; ++m) s[tid + 128 * m] = u[m] * 0.03125f;
    }
    __syncthreads();
    v = *(const float4 *) (s + e0);
    constexpr float L = C == C_IU4 ? 7.0f : 127.0f;
    const float amax = warp_max(fmaxf(fmaxf(fabsf(v.x), fabsf(v.y)), fmaxf(fabsf(v.z), fabsf(v.w))));
    const float iscale = amax > 0.0f ? L / amax : 0.0f;
    const float f[4] = {v.x, v.y, v.z, v.w};
    int q[4];
#pragma unroll
    for (int j = 0; j < 4; ++j) q[j] = max(-int(L), min(int(L), __float2int_rn(f[j] * iscale)));
    const int kslice = base >> 4, slot = base & 15;
    if constexpr (C == C_IU4) {
        uint8_t *dst = (uint8_t *) Bout + (size_t(kslice) * Npad + row) * 8 + slot / 2;
        dst[0] = uint8_t((q[0] & 0xf) | ((q[1] & 0xf) << 4));
        dst[1] = uint8_t((q[2] & 0xf) | ((q[3] & 0xf) << 4));
    } else if constexpr (C == C_IU8) {
        uint8_t *dst = (uint8_t *) Bout + (size_t(kslice) * Npad + row) * 16 + slot;
#pragma unroll
        for (int j = 0; j < 4; ++j) dst[j] = uint8_t(q[j] & 0xff);
    } else {
        const float scale = amax * (1.0f / 127.0f);
        _Float16 *dst = (_Float16 *) Bout + (size_t(kslice) * Npad + row) * 16 + slot;
#pragma unroll
        for (int j = 0; j < 4; ++j) dst[j] = (_Float16) ((float) q[j] * scale);
    }
    if constexpr (C != C_F16S)
        if (lane == 0) cscale[(size_t) row * (n / KB) + (base >> 7)] = amax / L;
}

// ------------------------------------------------------------------ projection
//
// OWN = O_TILE   tile = blockIdx.x * NWV + wave, one token group per iteration per wave, the token
//                axis split across gridDim.y workgroups. Each split re-reads the weight stream.
// OWN = O_SHARE  tile = blockIdx.x, wave = (token group, K split). The NWV/KS token groups of a
//                workgroup advance together over the same weight bytes; KS > 1 additionally splits
//                the K axis across waves and reduces the partial sums through LDS.
//
// Everything else - operand construction, accumulation, scales, SiLU, residual - is the owning
// directories' code unchanged.
template <int C, int OWN, int TT, int KS, bool FUSE, int NWV, int LAY = L_SLICE>
__global__ __launch_bounds__(NWV * 32) void k_proj(
        const uint8_t *__restrict__ Wa, const uint8_t *__restrict__ Wb,
        const void *__restrict__ B,
        const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const float *__restrict__ cscale, const float *__restrict__ signs,
        const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int Nloop, int outstride, int rowoff) {
    constexpr int TGW = OWN == O_SHARE ? NWV / KS : 1;   // token groups resident per workgroup
    constexpr int WB = kelana_scaled::BLOCK_BYTES;       // 512, the same block for all three classes
    __shared__ float red[KS > 1 ? TGW * (KS - 1) * TT * 16 * 32 : 1];

    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int col = lane & 15, half = lane >> 4;
    const int tile = OWN == O_SHARE ? int(blockIdx.x) : int(blockIdx.x) * NWV + wave;
    const int tgw = OWN == O_SHARE ? wave / KS : 0, ks = OWN == O_SHARE ? wave % KS : 0;
    const uint8_t *abase = Wa + size_t(tile) * nb * WB;
    const uint8_t *bbase = Wb + size_t(tile) * nb * WB;

    const int G = Nloop / (TT * 16), stride = int(gridDim.y) * TGW;
    const int first = int(blockIdx.y) * TGW + tgw;

    // One token group. `active` is always true for the barrier-free schedules, whose loop is then
    // exactly the control's: bound by the token axis, no uniform trip count, no guard. Only the
    // K-split schedule needs every wave to reach the same barriers, and only it pays for that.
    const auto group = [&](int gidx, bool active) {
        const int tg = gidx * TT * 16;

        // Cross-wave reduction, if this schedule splits K, and the store. Written once for both
        // accumulator shapes: a float8 per token tile for the scaled-FP16 class, eight running
        // FP32 sums for the integer classes. Every wave reaches the barriers.
        const auto finish = [&](auto &A, auto &Bacc) {
            if constexpr (KS > 1) {
                float *slot = red + size_t(tgw * (KS - 1) + (ks > 0 ? ks - 1 : 0)) * (TT * 16 * 32) + lane;
                if (active && ks > 0) {
#pragma unroll
                    for (int t = 0; t < TT; ++t)
#pragma unroll
                        for (int r = 0; r < 8; ++r) {
                            slot[size_t(t * 8 + r) * 32] = A[t][r];
                            slot[size_t(TT * 8 + t * 8 + r) * 32] = Bacc[t][r];
                        }
                }
                __syncthreads();
                if (active && ks == 0) {
                    const float *p0 = red + size_t(tgw * (KS - 1)) * (TT * 16 * 32) + lane;
#pragma unroll
                    for (int k = 0; k < KS - 1; ++k) {
                        const float *p = p0 + size_t(k) * (TT * 16 * 32);
#pragma unroll
                        for (int t = 0; t < TT; ++t)
#pragma unroll
                            for (int r = 0; r < 8; ++r) {
                                A[t][r] += p[size_t(t * 8 + r) * 32];
                                Bacc[t][r] += p[size_t(TT * 8 + t * 8 + r) * 32];
                            }
                    }
                }
                __syncthreads();   // the next token group reuses the same LDS
            }
            if (!active || ks != 0) return;
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                const int token = tg + t * 16 + col;
                if (token >= rows) continue;
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    const int row = tile * 16 + 2 * r + half;
                    const size_t o = size_t(token) * outstride + row;
                    if constexpr (FUSE) out[o] = silu(A[t][r]) * Bacc[t][r] * signs[row];
                    else {
                        out[o] = resid[o] + A[t][r];
                        out[o + rowoff] = resid[o + rowoff] + Bacc[t][r];
                    }
                }
            }
        };

        if constexpr (C == C_F16S) {
            // No per-block epilogue: the block scale is folded into the weight operand and the
            // token scale into the activation, so the accumulator is the finished projection.
            float8 ca[TT], cb[TT];
#pragma unroll
            for (int t = 0; t < TT; ++t) { ca[t] = float8{}; cb[t] = float8{}; }
            if (active) {
                for (int blk = ks; blk < nb; blk += KS) {
                    unsigned atlo, athi, btlo, bthi;
                    kelana_scaled::scale_tables(sa[(size_t(tile) * nb + blk) * 16 + col], atlo, athi);
                    kelana_scaled::scale_tables(sb[(size_t(tile) * nb + blk) * 16 + col], btlo, bthi);
                    // The two weight words of the next slice are fetched a slice ahead. Loaded in
                    // the slice that uses them they schedule behind that slice's fragment loads,
                    // and the operand expansion then waits on the whole outstanding queue instead
                    // of on two words. The last iteration re-reads slice 0, cached and unused.
                    const uint8_t *ap = abase + size_t(blk) * WB + col * (LAY == L_LANE ? 32 : 4);
                    const uint8_t *bp = bbase + size_t(blk) * WB + col * (LAY == L_LANE ? 32 : 4);
                    WideWords<LAY> wa_w(ap), wb_w(bp);
#pragma unroll LOOP_UNROLL(LAY)
                    for (int s = 0; s < SLICES; ++s) {
                        const unsigned ca2 = wa_w.take(ap, s), cb2 = wb_w.take(bp, s);
                        const half16 wa = kelana_scaled::expand_scaled(ca2, atlo, athi);
                        const half16 wb = kelana_scaled::expand_scaled(cb2, btlo, bthi);
#pragma unroll
                        for (int t = 0; t < TT; ++t) {
                            const half16 bf = ((const half16 *) B)[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                            ca[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(wa, bf, ca[t]);
                            cb[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(wb, bf, cb[t]);
                        }
                    }
                }
            }
            finish(ca, cb);
        } else {
            float ya[TT][8], yb[TT][8];
#pragma unroll
            for (int t = 0; t < TT; ++t)
#pragma unroll
                for (int r = 0; r < 8; ++r) { ya[t][r] = 0.f; yb[t][r] = 0.f; }
            if (active) {
                for (int blk = ks; blk < nb; blk += KS) {
                    const uint8_t *ab = abase + size_t(blk) * WB, *bb = bbase + size_t(blk) * WB;
                    // Tile-major scale rows: the 16 scales a wave needs for a block are contiguous.
                    const float asl = h2f(sa[(size_t(tile) * nb + blk) * 16 + col]);
                    const float bsl = h2f(sb[(size_t(tile) * nb + blk) * 16 + col]);
                    float asr[8], bsr[8];
#pragma unroll
                    for (int r = 0; r < 8; ++r) { asr[r] = __shfl(asl, 2 * r + half, 32); bsr[r] = __shfl(bsl, 2 * r + half, 32); }
                    int8v aa[TT], ab2[TT];
#pragma unroll
                    for (int t = 0; t < TT; ++t) { aa[t] = int8v{}; ab2[t] = int8v{}; }
                    const uint8_t *ap = ab + col * (LAY == L_LANE ? 32 : 4);
                    const uint8_t *bp = bb + col * (LAY == L_LANE ? 32 : 4);
                    WideWords<LAY> wa_w(ap), wb_w(bp);
#pragma unroll LOOP_UNROLL(LAY)
                    for (int s = 0; s < SLICES; ++s) {
                        const unsigned ca2 = wa_w.take(ap, s), cb2 = wb_w.take(bp, s);
                        if constexpr (C == C_IU8) {
                            const int4v wa = kelana_arith::expand_i8(ca2);
                            const int4v wb = kelana_arith::expand_i8(cb2);
#pragma unroll
                            for (int t = 0; t < TT; ++t) {
                                const int4v bf = ((const int4v *) B)[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                                aa[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wa, true, bf, aa[t], false);
                                ab2[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wb, true, bf, ab2[t], false);
                            }
                        } else {
                            const int2v wa = kelana_arith::expand_i4(ca2);
                            const int2v wb = kelana_arith::expand_i4(cb2);
#pragma unroll
                            for (int t = 0; t < TT; ++t) {
                                const int2v bf = ((const int2v *) B)[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                                aa[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wa, true, bf, aa[t], false);
                                ab2[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wb, true, bf, ab2[t], false);
                            }
                        }
                    }
#pragma unroll
                    for (int t = 0; t < TT; ++t) {
                        const float cs = cscale[size_t(tg + t * 16 + col) * nb + blk];
#pragma unroll
                        for (int r = 0; r < 8; ++r) {
                            ya[t][r] = __builtin_fmaf(float(aa[t][r]), asr[r] * cs, ya[t][r]);
                            yb[t][r] = __builtin_fmaf(float(ab2[t][r]), bsr[r] * cs, yb[t][r]);
                        }
                    }
                }
            }
            finish(ya, yb);
        }
    };

    if constexpr (KS == 1) {
        for (int g = first; g < G; g += stride) group(g, true);
    } else {
        const int iters = (G + stride - 1) / stride;
        for (int it = 0; it < iters; ++it) { const int g = first + it * stride; group(g, g < G); }
    }
}

// ------------------------------------------------------------------ candidate plumbing

struct Plan {
    int D = 0, FF = 0, maxrows = 0;
    uint8_t *wg = nullptr, *wu = nullptr, *wd_a = nullptr, *wd_b = nullptr;
    uint16_t *sg = nullptr, *su = nullptr, *sd_a = nullptr, *sd_b = nullptr;
    void *Bin = nullptr, *Bhid = nullptr;
    float *csin = nullptr, *cshid = nullptr, *hidden = nullptr;
    const float *norm = nullptr, *signs = nullptr;
    size_t bytes = 0;
};

// HALO tile rows carry 32 logical rows per block; row r of tile t is lane (t & 1) * 16 + r of
// block t/2. Decoding and packing are untimed preparation.
void decode_matrix(const uint8_t *halo_bytes, int rows, int kdim,
                   std::vector<int8_t> &trits, std::vector<uint16_t> &scales) {
    const int nb = kdim / KB;
    trits.assign(size_t(rows) * kdim, 0);
    scales.assign(size_t(rows) * nb, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            const size_t src = (size_t(tile / 2) * nb + b) * halo::TILE_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                const int lane = (tile & 1) * 16 + r, row = tile * 16 + r;
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

// Two-bit ternary codes in lane-major order: [tile][block][row][8 slice dwords]. The same words
// kelana_arith::pack_two_bit writes, permuted so one lane's block is 32 contiguous bytes.
std::vector<uint8_t> pack_two_bit_lane(const int8_t *w, int rows, int kdim) {
    const int nb = kdim / KB;
    std::vector<uint8_t> out(size_t(rows / 16) * nb * 512, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            uint8_t *dst = out.data() + (size_t(tile) * nb + b) * 512;
            for (int r = 0; r < 16; ++r) {
                const int8_t *s = w + size_t(tile * 16 + r) * kdim + b * KB;
                for (int sl = 0; sl < SLICES; ++sl) {
                    uint32_t word = 0;
                    for (int j = 0; j < 16; ++j) {
                        const int v = s[sl * 16 + j];
                        word |= uint32_t(v == 0 ? 0 : (v > 0 ? 1 : 3)) << (2 * j);
                    }
                    std::memcpy(dst + r * 32 + sl * 4, &word, 4);
                }
            }
        }
    return out;
}

template <class T> void upload(T *&dst, const std::vector<T> &src, size_t &total) {
    check(hipMalloc(&dst, src.size() * sizeof(T)), "malloc");
    check(hipMemcpy(dst, src.data(), src.size() * sizeof(T), hipMemcpyHostToDevice), "upload");
    total += src.size() * sizeof(T);
}

// A shared-tile workgroup walks the token axis in whole groups of NW * TT * 16 columns, so a batch
// the group width does not divide reads fragments past the batch. Those reads alias the next
// k-slice's own valid columns; only the final slice runs off the end, so one group of slack
// fragments past the buffer is enough. Their outputs are discarded by the row guard.
constexpr int SLACK_TOKENS = 8 * 16 * NW;      // widest tile x widest wave fan-out

template <int CI, int CH, int LAY = L_SLICE>
void *prepare(const kelana_batch::Weights &w, int maxrows) {
    const auto pack = [](const int8_t *m, int rows, int kdim) {
        return LAY == L_LANE ? pack_two_bit_lane(m, rows, kdim) : kelana_arith::pack_two_bit(m, rows, kdim);
    };
    auto *p = new Plan{};
    p->D = w.width; p->FF = w.hidden; p->maxrows = maxrows;
    p->norm = w.norm_device; p->signs = w.signs_device;
    std::vector<int8_t> g, u, d;
    std::vector<uint16_t> gs, us, ds;
    decode_matrix(w.gate_host, p->FF, p->D, g, gs);
    decode_matrix(w.up_host, p->FF, p->D, u, us);
    decode_matrix(w.down_host, p->D, p->FF, d, ds);
    // Two-bit storage is byte-identical for all three classes: the integer maps expand it to
    // nibbles or bytes, the scaled map expands it to scaled halves, from the same 512-byte block.
    upload(p->wg, pack(g.data(), p->FF, p->D), p->bytes);
    upload(p->wu, pack(u.data(), p->FF, p->D), p->bytes);
    upload(p->sg, kelana_scaled::tile_major(gs, p->FF, p->D / KB), p->bytes);
    upload(p->su, kelana_scaled::tile_major(us, p->FF, p->D / KB), p->bytes);
    const int Dh = p->D / 2, nbf = p->FF / KB;
    std::vector<int8_t> d0(d.begin(), d.begin() + size_t(Dh) * p->FF), d1(d.begin() + size_t(Dh) * p->FF, d.end());
    std::vector<uint16_t> ds0(ds.begin(), ds.begin() + size_t(Dh) * nbf), ds1(ds.begin() + size_t(Dh) * nbf, ds.end());
    upload(p->wd_a, pack(d0.data(), Dh, p->FF), p->bytes);
    upload(p->wd_b, pack(d1.data(), Dh, p->FF), p->bytes);
    upload(p->sd_a, kelana_scaled::tile_major(ds0, Dh, nbf), p->bytes);
    upload(p->sd_b, kelana_scaled::tile_major(ds1, Dh, nbf), p->bytes);

    const int Npad = (maxrows + 15) / 16 * 16;
    const size_t bin = (size_t(p->D / 16) * Npad + SLACK_TOKENS) * FragBytes<CI>::value;
    const size_t bhid = (size_t(p->FF / 16) * Npad + SLACK_TOKENS) * FragBytes<CH>::value;
    check(hipMalloc(&p->Bin, bin), "Bin");
    check(hipMalloc(&p->Bhid, bhid), "Bhid");
    check(hipMemset(p->Bin, 0, bin), "Bin zero");
    check(hipMemset(p->Bhid, 0, bhid), "Bhid zero");
    // Token scales are indexed by token, so the same overshoot needs slack rows here.
    const size_t csin = size_t(Npad + SLACK_TOKENS) * (p->D / KB) * 4;
    const size_t cshid = size_t(Npad + SLACK_TOKENS) * (p->FF / KB) * 4;
    check(hipMalloc(&p->csin, csin), "csin");
    check(hipMalloc(&p->cshid, cshid), "cshid");
    check(hipMemset(p->csin, 0, csin), "csin zero");
    check(hipMemset(p->cshid, 0, cshid), "cshid zero");
    check(hipMalloc(&p->hidden, size_t(Npad) * p->FF * 4), "hidden");
    p->bytes += bin + bhid + csin + cshid + size_t(Npad) * p->FF * 4;
    return p;
}

void release(void *state) {
    auto *p = static_cast<Plan *>(state);
    for (void *q : {(void *) p->wg, (void *) p->wu, (void *) p->wd_a, (void *) p->wd_b,
                    (void *) p->sg, (void *) p->su, (void *) p->sd_a, (void *) p->sd_b,
                    p->Bin, p->Bhid, (void *) p->csin, (void *) p->cshid, (void *) p->hidden})
        if (q) hipFree(q);
    delete p;
}
size_t resident_bytes(void *state) { return static_cast<Plan *>(state)->bytes; }

// Enough workgroups to fill the device without splitting a weight stream that is already spread
// over more workgroups than the machine has compute units. The owning directories' heuristic,
// unchanged, so the two ownership maps are not separated by a different grid rule.
int group_split(int xgroups, int groups) {
    const int want = 320 / (xgroups > 0 ? xgroups : 1);
    return std::max(1, std::min(groups, want));
}

// The schedule of a projection, in the one form both ownership maps are special cases of.
//
// A batch of `ntiles` 16-token tiles is spent three ways: TT tiles held in one wave's accumulators,
// W waves of a workgroup that own different token groups of the same weight tile, and whatever is
// left walked serially or across workgroups. A wave rebuilds its weight operands once per token
// group it walks, so TT is operand reuse; W is grid parallelism that costs no registers and no
// re-read, because the W waves stream the same bytes together.
//
//   tile        W = 1 inside a workgroup of NW waves that each own a different row tile: the
//               deployed control. Its leftover token groups are walked serially, re-reading the
//               weight stream once per group, or split across workgroups, which re-reads it too.
//   share       W = NW, TT sized to cover the batch in one pass: the mapping measured as a
//               by-product in ../seven-product.
//   share-auto  TT first at the class's register budget, W = whatever the batch has left. Same TT
//               as the control, same wave count, fewer weight-stream reads - but when the batch
//               has nothing left it degenerates to W = 1, one wave per workgroup, which keeps the
//               grid change and drops the sharing.
//   share-w2    two waves per tile and half the width, the middle point of that trade.
//   share-k2    W = NW/2 token groups and two K splits per group, reduced through LDS.
//
// KELANA_TO_TT_GU / _DN and KELANA_TO_W_GU / _DN force a width or a wave fan-out for sweeps and
// matched-width runs.
//   adapt       the rule the measurements below imply: waves per tile is the larger of what one
//               pass over the batch needs at full width and what this stage's row-tile grid needs
//               to fill the device; one wave per tile is the control.
enum Sched { S_TILE = 0, S_SHARE = 1, S_SHARE_AUTO = 2, S_SHARE_K2 = 3, S_SHARE_W2 = 4, S_ADAPT = 5 };

struct Shape { int own, w, ks, tt; };

// Waves the grid should offer before the token axis is worth splitting: four per SIMD32 on this
// device's 80 units (../geometry.hpp). Gate/up owns 1088 row tiles and has them without sharing;
// the down projection owns 160 and does not.
constexpr int WAVES_WANTED = 320;

int env_int(const char *name, int fallback) {
    const char *v = getenv(name);
    return v && *v ? atoi(v) : fallback;
}

Shape shape_for(int klass, int sched, bool gate_up, int Npad, int tiles) {
    const int ntiles = std::max(1, Npad / 16);
    const int cap = klass == C_F16S ? 8 : 4;
    const auto ceil_div = [](int a, int b) { return (a + b - 1) / b; };
    Shape s{};
    if (sched == S_TILE) {
        const int want = klass == C_F16S ? (gate_up || Npad >= 256 ? 8 : 2) : (Npad >= 64 ? 4 : 2);
        s = {O_TILE, NW, 1, std::min(want, std::min(cap, ntiles))};
    } else if (sched == S_SHARE) {
        s = {O_SHARE, NW, 1, std::max(1, std::min(cap, ceil_div(ntiles, NW)))};
    } else if (sched == S_SHARE_K2) {
        s = {O_SHARE, NW, 2, std::max(1, std::min(cap, ceil_div(ntiles, NW / 2)))};
    } else if (sched == S_SHARE_W2) {
        s = {O_SHARE, 2, 1, std::max(1, std::min(cap, ceil_div(ntiles, 2)))};
    } else if (sched == S_ADAPT) {
        const int w = std::min(NW, std::max(ceil_div(ntiles, cap), ceil_div(WAVES_WANTED, std::max(1, tiles))));
        s = w <= 1 ? Shape{O_TILE, NW, 1, std::min(cap, ntiles)}
                   : Shape{O_SHARE, w, 1, std::max(1, std::min(cap, ceil_div(ntiles, w)))};
    } else {
        const int tt = std::min(cap, ntiles);
        s = {O_SHARE, std::min(NW, std::max(1, ntiles / tt)), 1, tt};
    }
    s.tt = env_int(gate_up ? "KELANA_TO_TT_GU" : "KELANA_TO_TT_DN", s.tt);
    if (s.own == O_SHARE) s.w = env_int(gate_up ? "KELANA_TO_W_GU" : "KELANA_TO_W_DN", s.w);
    return s;
}

// Optional per-stage timing, off unless KELANA_TO_STAGES is set. It synchronises between stages,
// so a timed acceptance run must leave it unset.
struct Stages {
    bool on = getenv("KELANA_TO_STAGES") != nullptr;
    hipEvent_t ev[5]{};
    const char *name[4] = {"prep_in", "gate_up_silu", "prep_hidden", "down_residual"};
    int at = 0;
    void mark(hipStream_t s) { if (!on) return; if (!ev[at]) hipEventCreate(&ev[at]); hipEventRecord(ev[at], s); ++at; }
    void report(const char *who, int rows) {
        if (!on) return;
        hipEventSynchronize(ev[4]);
        std::fprintf(stderr, "%-24s rows %-4d", who, rows);
        for (int i = 0; i < 4; ++i) { float t = 0; hipEventElapsedTime(&t, ev[i], ev[i + 1]);
            std::fprintf(stderr, "  %s %6.3f ms", name[i], t); }
        std::fprintf(stderr, "\n");
        at = 0;
    }
};

struct ProjArgs {
    const uint8_t *Wa, *Wb;
    const void *B;
    const uint16_t *sa, *sb;
    const float *cscale, *signs, *resid;
    float *out;
    int nb, rows, Npad, outstride, rowoff, tiles;
};

template <int C, int OWN, int TT, int KS, int WV, bool FUSE, int LAY>
void launch(const ProjArgs &a, int Nloop, hipStream_t stream) {
    constexpr int TGW = OWN == O_SHARE ? WV / KS : 1;
    const int G = Nloop / (TT * 16);
    const int xg = OWN == O_SHARE ? a.tiles : a.tiles / WV;
    const int yg = group_split(xg, (G + TGW - 1) / TGW);
    if (getenv("KELANA_TO_GRID"))
        std::fprintf(stderr, "launch C%d own%d tt%d ks%d wv%d fuse%d tiles%d grid %dx%d threads %d G%d\n",
                     C, OWN, TT, KS, WV, int(FUSE), a.tiles, xg, yg, WV * 32, G);
    k_proj<C, OWN, TT, KS, FUSE, WV, LAY><<<dim3(xg, yg), WV * 32, 0, stream>>>(
        a.Wa, a.Wb, a.B, a.sa, a.sb, a.cscale, a.signs, a.resid, a.out,
        a.nb, a.rows, a.Npad, Nloop, a.outstride, a.rowoff);
}

// The token axis is walked in whole tile groups, so a batch whose tile count the width does not
// divide is rounded up rather than given a narrower width.
template <int C, bool FUSE, int LAY>
void launch_proj(const ProjArgs &a, const Shape &s, int Npad, hipStream_t stream) {
#define GO(TTV, KSV, WV) do { \
        const int nloop = (Npad + TTV * 16 - 1) / (TTV * 16) * (TTV * 16); \
        if (s.own == O_TILE) launch<C, O_TILE, TTV, 1, NW, FUSE, LAY>(a, nloop, stream); \
        else                 launch<C, O_SHARE, TTV, KSV, WV, FUSE, LAY>(a, nloop, stream); \
        return; } while (0)
#define BY_TT(KSV, WV) do { \
        if constexpr (C == C_F16S) if (s.tt >= 8) GO(8, KSV, WV); \
        if (s.tt >= 4) GO(4, KSV, WV); \
        if (s.tt >= 2) GO(2, KSV, WV); \
        GO(1, KSV, WV); } while (0)
    if (s.ks == 2)     BY_TT(2, NW);
    else if (s.w >= 4) BY_TT(1, 4);
    else if (s.w == 2) BY_TT(1, 2);
    else               BY_TT(1, 1);
#undef BY_TT
#undef GO
}

const char *sched_name(int s) {
    return s == S_TILE ? "tile" : s == S_SHARE ? "share" : s == S_SHARE_AUTO ? "auto"
         : s == S_SHARE_W2 ? "w2" : s == S_ADAPT ? "adapt" : "k2";
}

// One stable label per instantiation, for the optional stage trace.
template <int C, int GU, int DN>
const char *who() {
    static char buf[64];
    if (!buf[0])
        std::snprintf(buf, sizeof buf, "%s %s/%s",
                      C == C_IU8 ? "iu8-a8" : C == C_IU4 ? "iu4-a4" : "csf16-a8",
                      sched_name(GU), sched_name(DN));
    return buf;
}

template <int C, int GU, int DN, int LAY = L_SLICE>
void run(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    static Stages st;
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    st.mark(stream);
    k_prep<C, true, true><<<rows * (D / 1024), NT, 0, stream>>>(input, p->norm, p->Bin, p->csin, D, Npad);
    st.mark(stream);
    {
        ProjArgs a{p->wg, p->wu, p->Bin, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden,
                   D / KB, rows, Npad, FF, 0, FF / 16};
        launch_proj<C, true, LAY>(a, shape_for(C, GU, true, Npad, a.tiles), Npad, stream);
    }
    st.mark(stream);
    k_prep<C, false, false><<<rows * (FF / 1024), NT, 0, stream>>>(p->hidden, nullptr, p->Bhid, p->cshid, FF, Npad);
    st.mark(stream);
    {
        ProjArgs a{p->wd_a, p->wd_b, p->Bhid, p->sd_a, p->sd_b, p->cshid, nullptr, input, output,
                   FF / KB, rows, Npad, D, Dh, Dh / 16};
        launch_proj<C, false, LAY>(a, shape_for(C, DN, false, Npad, a.tiles), Npad, stream);
    }
    st.mark(stream);
    st.report(who<C, GU, DN>(), rows);
}

template <int C, int GU, int DN, int LAY = L_SLICE>
kelana_batch::Candidate make(const char *name, const char *desc) {
    kelana_batch::Candidate c{};
    c.name = name;
    c.claim = kelana_batch::Claim::approximate;
    c.description = desc;
    c.prepare = prepare<C, C, LAY>;
    c.run = run<C, GU, DN, LAY>;
    c.release = release;
    c.resident_bytes = resident_bytes;
    return c;
}

// A8 primary: the deployed activation width on the integer instruction.
kelana_batch::Candidate iu8_tile() { return make<C_IU8, S_TILE, S_TILE>("to-iu8-a8-tile",
    "IU8/A8, wave owns a row tile: this file's source-matched control for the ownership change"); }
kelana_batch::Candidate iu8_share() { return make<C_IU8, S_SHARE, S_SHARE>("to-iu8-a8-share",
    "IU8/A8, workgroup owns a row tile and each of its four waves owns a token group"); }
kelana_batch::Candidate iu8_auto() { return make<C_IU8, S_SHARE_AUTO, S_SHARE_AUTO>("to-iu8-a8-share-auto",
    "IU8/A8, shared row tile with the control's tile width and the leftover token groups spent on waves"); }
kelana_batch::Candidate iu8_auto_dn() { return make<C_IU8, S_TILE, S_SHARE_AUTO>("to-iu8-a8-share-dn",
    "IU8/A8, control ownership at gate/up and shared row tiles only at the down projection"); }
kelana_batch::Candidate iu8_adapt() { return make<C_IU8, S_ADAPT, S_ADAPT>("to-iu8-a8-share-adapt",
    "IU8/A8, waves per shared row tile from batch coverage and grid fill, per projection"); }
kelana_batch::Candidate iu8_w2() { return make<C_IU8, S_SHARE_W2, S_SHARE_W2>("to-iu8-a8-share-w2",
    "IU8/A8, two waves per shared row tile at half the width: the middle of the width/fan-out trade"); }
kelana_batch::Candidate iu8_share_k2() { return make<C_IU8, S_SHARE_K2, S_SHARE_K2>("to-iu8-a8-share-k2",
    "IU8/A8, shared row tile with two K splits per token group reduced through LDS"); }
// A8 on the fastest current whole-FFN kernel.
kelana_batch::Candidate cs_tile() { return make<C_F16S, S_TILE, S_TILE>("to-csf16-a8-tile",
    "scaled-FP16/A8, wave owns a row tile: source-matched control on the fastest A8 kernel"); }
kelana_batch::Candidate cs_share() { return make<C_F16S, S_SHARE, S_SHARE>("to-csf16-a8-share",
    "scaled-FP16/A8, workgroup owns a row tile and each of its four waves owns a token group"); }
kelana_batch::Candidate cs_auto() { return make<C_F16S, S_SHARE_AUTO, S_SHARE_AUTO>("to-csf16-a8-share-auto",
    "scaled-FP16/A8, shared row tile at the control's eight-tile width, leftover token groups spent on waves"); }
kelana_batch::Candidate cs_auto_dn() { return make<C_F16S, S_TILE, S_SHARE_AUTO>("to-csf16-a8-share-dn",
    "scaled-FP16/A8, control ownership at gate/up and shared row tiles only at the down projection"); }
kelana_batch::Candidate cs_adapt() { return make<C_F16S, S_ADAPT, S_ADAPT>("to-csf16-a8-share-adapt",
    "scaled-FP16/A8, waves per shared row tile from batch coverage and grid fill, per projection"); }
kelana_batch::Candidate cs_w2() { return make<C_F16S, S_SHARE_W2, S_SHARE_W2>("to-csf16-a8-share-w2",
    "scaled-FP16/A8, two waves per shared row tile at half the width"); }
kelana_batch::Candidate cs_share_k2() { return make<C_F16S, S_SHARE_K2, S_SHARE_K2>("to-csf16-a8-share-k2",
    "scaled-FP16/A8, shared row tile with two K splits per token group reduced through LDS"); }
// A4 secondary, same source, same ownership change.
kelana_batch::Candidate iu4_tile() { return make<C_IU4, S_TILE, S_TILE>("to-iu4-a4-tile",
    "IU4/A4, wave owns a row tile: source-matched control"); }
kelana_batch::Candidate iu4_share() { return make<C_IU4, S_SHARE, S_SHARE>("to-iu4-a4-share",
    "IU4/A4, workgroup owns a row tile and each of its four waves owns a token group"); }
// The same three classes on lane-major weight words: a block in two uint4 loads instead of eight
// dword loads. Crossed with ownership so the two levers can be read apart.
kelana_batch::Candidate iu8_wide_tile() { return make<C_IU8, S_TILE, S_TILE, L_LANE>("to-iu8-a8-wide-tile",
    "IU8/A8, lane-major weight words read as two uint4 per block, control ownership"); }
kelana_batch::Candidate iu8_wide_adapt() { return make<C_IU8, S_ADAPT, S_ADAPT, L_LANE>("to-iu8-a8-wide-adapt",
    "IU8/A8, lane-major weight words and the adaptive shared-tile schedule"); }
kelana_batch::Candidate cs_wide_tile() { return make<C_F16S, S_TILE, S_TILE, L_LANE>("to-csf16-a8-wide-tile",
    "scaled-FP16/A8, lane-major weight words read as two uint4 per block, control ownership"); }
kelana_batch::Candidate cs_wide_adapt() { return make<C_F16S, S_ADAPT, S_ADAPT, L_LANE>("to-csf16-a8-wide-adapt",
    "scaled-FP16/A8, lane-major weight words and the adaptive shared-tile schedule"); }
kelana_batch::Candidate iu4_wide_tile() { return make<C_IU4, S_TILE, S_TILE, L_LANE>("to-iu4-a4-wide-tile",
    "IU4/A4, lane-major weight words read as two uint4 per block, control ownership"); }
kelana_batch::Candidate iu4_wide_adapt() { return make<C_IU4, S_ADAPT, S_ADAPT, L_LANE>("to-iu4-a4-wide-adapt",
    "IU4/A4, lane-major weight words and the adaptive shared-tile schedule"); }
kelana_batch::Candidate iu4_adapt() { return make<C_IU4, S_ADAPT, S_ADAPT>("to-iu4-a4-share-adapt",
    "IU4/A4, waves per shared row tile from batch coverage and grid fill, per projection"); }
kelana_batch::Candidate iu4_auto() { return make<C_IU4, S_SHARE_AUTO, S_SHARE_AUTO>("to-iu4-a4-share-auto",
    "IU4/A4, shared row tile at the control's tile width, leftover token groups spent on waves"); }

} // namespace

KELANA_BATCH_REGISTER(iu8_tile)
KELANA_BATCH_REGISTER(iu8_share)
KELANA_BATCH_REGISTER(iu8_auto)
KELANA_BATCH_REGISTER(iu8_auto_dn)
KELANA_BATCH_REGISTER(iu8_adapt)
KELANA_BATCH_REGISTER(iu8_w2)
KELANA_BATCH_REGISTER(iu8_share_k2)
KELANA_BATCH_REGISTER(cs_tile)
KELANA_BATCH_REGISTER(cs_share)
KELANA_BATCH_REGISTER(cs_auto)
KELANA_BATCH_REGISTER(cs_auto_dn)
KELANA_BATCH_REGISTER(cs_adapt)
KELANA_BATCH_REGISTER(cs_w2)
KELANA_BATCH_REGISTER(cs_share_k2)
KELANA_BATCH_REGISTER(iu4_tile)
KELANA_BATCH_REGISTER(iu4_share)
KELANA_BATCH_REGISTER(iu8_wide_tile)
KELANA_BATCH_REGISTER(iu8_wide_adapt)
KELANA_BATCH_REGISTER(cs_wide_tile)
KELANA_BATCH_REGISTER(cs_wide_adapt)
KELANA_BATCH_REGISTER(iu4_wide_tile)
KELANA_BATCH_REGISTER(iu4_wide_adapt)
KELANA_BATCH_REGISTER(iu4_adapt)
KELANA_BATCH_REGISTER(iu4_auto)
