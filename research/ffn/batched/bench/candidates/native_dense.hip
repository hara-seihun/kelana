// Straightforward batched native baselines: one dense WMMA GEMM per projection, with the deployed
// quantisation and nonlinearity around them.
//
// These are the "what does ordinary hardware do with this batch" points. They keep the deployed
// input semantics exactly - the same RMS norm, the same folded sign vector, the same 1024-point
// Hadamard, the same per-128 int8 quantisation, produced by calling the engine's own prep_chunk_r -
// and replace only the projection. The reassociation does change and is stated per baseline below.
//
//   native_iu8   ternary weights expanded to int8, IU8 WMMA, int32 accumulation per 128-wide block
//                then FP32 across blocks. Same summation grouping as the deployed matvec, so the
//                arithmetic is the deployed arithmetic at a different schedule.
//   native_i4    the SAME ternary weights stored two per byte as signed 4-bit, unpacked to int8 in
//                registers and fed to the same IU8 WMMA. Bit-identical results to native_iu8 by
//                construction; it exists to measure the storage and bandwidth difference. This is
//                not a model-quality comparison between a ternary and a four-bit model, and nothing
//                here is quantised to four bits except the storage of values already in {-1,0,1}.
//                Whether IU4 WMMA itself is faster is a separate question, answered by
//                build/wmma-rates rather than assumed.
//   native_fp16  weights premultiplied by their block scale into FP16 and activations dequantised
//                to FP16, FP32 accumulation. This one DOES reassociate: the per-128 block scale is
//                folded into the weights, so the sum runs across the whole K in one accumulator
//                instead of being rescaled every 128, and both operands carry FP16 rounding. Its
//                error against the engine is a real numeric difference, not a bug.
#include "../../api.hpp"
#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include "device.hpp"
#include "phases.hpp"
#include "halo_format.h"
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <thread>
#include <vector>

using namespace halo;

namespace {

#define HC(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) { fprintf(stderr, "native_dense: %s: %s\n", #x, hipGetErrorString(e_)); abort(); } } while (0)

typedef int v2i __attribute__((ext_vector_type(2)));
typedef int v4i __attribute__((ext_vector_type(4)));
typedef int v8i __attribute__((ext_vector_type(8)));
typedef float v8f __attribute__((ext_vector_type(8)));
typedef _Float16 v16h __attribute__((ext_vector_type(16)));

enum Mode { M_I8 = 0, M_I4 = 1, M_F16 = 2 };

// ---------------------------------------------------------------------------------------------
// Deployed prep, called out of the engine's own phases.hpp so the input semantics are identical.

template <bool NORM>
__global__ void __launch_bounds__(NT) k_prep(PrepR a, int nchunks) {
    __shared__ __attribute__((aligned(16))) float lds[1024];
    __shared__ float red[8];
    const int row = blockIdx.x / nchunks, chunk = blockIdx.x - row * nchunks;
    float inv = 1.0f;
    if (NORM) {
        const float * x = a.x + (size_t) row * a.n;
        float ss = 0.0f;
        for (int i = threadIdx.x * 4; i < a.n; i += NT * 4) {
            const float4 t = *(const float4 *) (x + i);
            ss = fmaf(t.x, t.x, ss); ss = fmaf(t.y, t.y, ss); ss = fmaf(t.z, t.z, ss); ss = fmaf(t.w, t.w, ss);
        }
        ss = block_sum_256(ss, red);
        inv = rsqrtf(ss / (float) a.n + a.eps);
    }
    prep_chunk_r(a, row, chunk, inv, lds, 0);
}

// Activations into the same [rows/16][K/16][16][lane] tile order the weights use, so a WMMA
// operand load is 16 lanes over one contiguous 256-byte line instead of 16 separate strided
// lines. Without this the activation side, not the weights, dominates the memory traffic.
__global__ void __launch_bounds__(256) k_swizzle_a8(const int8_t * src, int8_t * dst, int M, int K) {
    const int ktiles = K / 16;
    const size_t g = (size_t) blockIdx.x * 256 + threadIdx.x;
    if (g >= (size_t) M * ktiles) return;
    const int row = (int) (g / ktiles), kt = (int) (g % ktiles);
    *(int4 *) (dst + ((size_t) ((row >> 4) * ktiles + kt) * 16 + (row & 15)) * 16) =
        *(const int4 *) (src + (size_t) row * K + kt * 16);
}
__global__ void __launch_bounds__(256) k_swizzle_ah(const int8_t * q, const float * s, __half * dst, int M, int K) {
    const int ktiles = K / 16;
    const size_t g = (size_t) blockIdx.x * 256 + threadIdx.x;
    if (g >= (size_t) M * ktiles) return;
    const int row = (int) (g / ktiles), kt = (int) (g % ktiles);
    const float sc = s[(size_t) row * (K / 128) + (kt * 16) / 128];
    __half * o = dst + ((size_t) ((row >> 4) * ktiles + kt) * 16 + (row & 15)) * 16;
    const int8_t * v = q + (size_t) row * K + kt * 16;
    #pragma unroll
    for (int j = 0; j < 16; j++) o[j] = __float2half((float) v[j] * sc);
}

// int8 activations and their per-128 scales into FP16, for the FP16 baseline only.
__global__ void __launch_bounds__(256) k_dequant_half(const int8_t * q, const float * s, __half * out, int n) {
    const size_t i = (size_t) blockIdx.x * 256 + threadIdx.x;
    const size_t total = (size_t) n * gridDim.y;
    (void) total;
    const size_t row = blockIdx.y;
    const size_t k = i;
    if ((int) k >= n) return;
    const float sc = s[row * (n / 128) + k / 128];
    out[row * n + k] = __float2half((float) q[row * n + k] * sc);
}

// ---------------------------------------------------------------------------------------------
// Dense WMMA GEMM. out[m][n] = bias[m][n] + sum_k A[m][k] * W[n][k].
//
// One WMMA 16x16x16 consumes 16 weight channels (the C register index) against 16 batch rows (the
// lane index). A workgroup owns 64 channels (four waves) and 32 batch rows.

struct GemmP {
    const void * W;
    const float * wscale;      // [N/16][K/128][16], null when the scale is folded into W
    const void * A;
    const float * ascale;      // [M][K/128], null for the FP16 path
    const float * bias;        // [M][N] added to the result, or null
    float * out;
    int M, N, K;
};

__device__ __forceinline__ v4i unpack_i4(v2i p) {
    // byte j of a packed dword holds k = 2j in the low nibble and k = 2j+1 in the high nibble
    v4i o;
    #pragma unroll
    for (int d = 0; d < 2; d++) {
        const unsigned u = (unsigned) p[d];
        unsigned lo = u & 0x0f0f0f0fu, hi = (u >> 4) & 0x0f0f0f0fu;
        // Sign-extend each 4-bit field in place. The usual (x ^ 0x08) - 0x08 trick is wrong here:
        // the subtraction borrows across byte lanes. Setting the top nibble from bit 3 does not.
        lo |= ((lo >> 3) & 0x01010101u) * 0xf0u;
        hi |= ((hi >> 3) & 0x01010101u) * 0xf0u;
        o[2 * d + 0] = (int) __builtin_amdgcn_perm(hi, lo, 0x05010400u);
        o[2 * d + 1] = (int) __builtin_amdgcn_perm(hi, lo, 0x07030602u);
    }
    return o;
}

// MT is how many 16-row tiles one workgroup owns. The weight operand is loaded once per k-tile
// and used MT times, so a larger batch amortises the weight traffic that dominates a small one.
template <int MODE, int MT>
__global__ void __launch_bounds__(256) k_gemm(GemmP p) {
    __shared__ float lds[32][129];   // two m-tiles of output at a time, +1 column against bank conflicts
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int half = lane >> 4, col = lane & 15;
    const int ntile = blockIdx.x * 8 + wave;
    const int m_base = blockIdx.y * (MT * 16);
    const int ktiles = p.K / 16, nblk = p.K / 128;

    const int8_t * Aq = (const int8_t *) p.A;
    const __half * Ah = (const __half *) p.A;

    int mt[MT];
    bool ok[MT];
    #pragma unroll
    for (int t = 0; t < MT; t++) { mt[t] = blockIdx.y * MT + t; ok[t] = m_base + t * 16 + col < p.M; }

    float acc[MT][8];
    #pragma unroll
    for (int t = 0; t < MT; t++)
        #pragma unroll
        for (int r = 0; r < 8; r++) acc[t][r] = 0.0f;

    if (MODE == M_F16) {
        v8f c[MT];
        #pragma unroll
        for (int t = 0; t < MT; t++) c[t] = v8f{0,0,0,0,0,0,0,0};
        const __half * Wh = (const __half *) p.W;
        for (int kt = 0; kt < ktiles; kt++) {
            const v16h A = *(const v16h *) (Wh + ((size_t) ntile * ktiles + kt) * 256 + col * 16);
            #pragma unroll
            for (int t = 0; t < MT; t++) {
                const v16h B = ok[t] ? *(const v16h *) (Ah + ((size_t) (mt[t] * ktiles + kt) * 16 + col) * 16) : v16h{};
                c[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(A, B, c[t]);
            }
        }
        #pragma unroll
        for (int t = 0; t < MT; t++)
            #pragma unroll
            for (int r = 0; r < 8; r++) acc[t][r] = c[t][r];
    } else {
        for (int b = 0; b < nblk; b++) {
            v8i c[MT];
            #pragma unroll
            for (int t = 0; t < MT; t++) c[t] = v8i{0,0,0,0,0,0,0,0};
            #pragma unroll
            for (int kk = 0; kk < 8; kk++) {
                const int kt = b * 8 + kk;
                v4i A;
                if (MODE == M_I8) A = *(const v4i *) ((const int8_t *) p.W + ((size_t) ntile * ktiles + kt) * 256 + col * 16);
                else              A = unpack_i4(*(const v2i *) ((const int8_t *) p.W + ((size_t) ntile * ktiles + kt) * 128 + col * 8));
                #pragma unroll
                for (int t = 0; t < MT; t++) {
                    const v4i B = ok[t] ? *(const v4i *) (Aq + ((size_t) (mt[t] * ktiles + kt) * 16 + col) * 16) : v4i{0,0,0,0};
                    c[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, A, true, B, c[t], false);
                }
            }
            // The 16 channel scales of this block are the same 64 bytes for every lane.
            const float4 * ws = (const float4 *) (p.wscale + ((size_t) ntile * nblk + b) * 16);
            const float4 w0 = ws[0], w1 = ws[1], w2 = ws[2], w3 = ws[3];
            const float wv[16] = { w0.x, w0.y, w0.z, w0.w, w1.x, w1.y, w1.z, w1.w,
                                   w2.x, w2.y, w2.z, w2.w, w3.x, w3.y, w3.z, w3.w };
            #pragma unroll
            for (int t = 0; t < MT; t++) {
                const float as = ok[t] ? p.ascale[(size_t) (m_base + t * 16 + col) * nblk + b] : 0.0f;
                #pragma unroll
                for (int r = 0; r < 8; r++) acc[t][r] = fmaf((float) c[t][r], wv[2 * r + half] * as, acc[t][r]);
            }
        }
    }

    // Output through LDS, two m-tiles at a time, so the global writes run along the channel axis.
    const int n_base = blockIdx.x * 128;
    #pragma unroll
    for (int t0 = 0; t0 < MT; t0 += 2) {
        __syncthreads();
        #pragma unroll
        for (int t = 0; t < 2; t++)
            #pragma unroll
            for (int r = 0; r < 8; r++) lds[t * 16 + col][wave * 16 + 2 * r + half] = acc[t0 + t][r];
        __syncthreads();
        for (int i = threadIdx.x; i < 32 * 128; i += 256) {
            const int rl = i >> 7, ch = i & 127;
            const int m = m_base + t0 * 16 + rl, n = n_base + ch;
            if (m < p.M && n < p.N) {
                const size_t o = (size_t) m * p.N + n;
                p.out[o] = (p.bias ? p.bias[o] : 0.0f) + lds[rl][ch];
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Host side: decode the deployed HALO tiles once, then build one representation per baseline.

struct Plain {                     // a decoded ternary matrix
    int N = 0, K = 0;
    std::vector<int8_t> trit;      // [N][K] in {-1,0,1}
    std::vector<float> scale;      // [N][K/128]
};

float half_to_float(uint16_t h) {
    const uint32_t s = (uint32_t) (h >> 15), e = (h >> 10) & 0x1f, m = h & 0x3ff;
    uint32_t bits;
    if (e == 0) bits = m ? ((s << 31) | ((127 - 15 + 1) << 23) | (m << 13)) : (s << 31);
    else if (e == 31) bits = (s << 31) | 0x7f800000u | (m << 13);
    else bits = (s << 31) | ((e - 15 + 127) << 23) | (m << 13);
    float f;
    memcpy(&f, &bits, 4);
    if (e == 0 && m) { // subnormal half, rebuild properly
        f = (float) m * 5.9604644775390625e-8f;
        if (s) f = -f;
    }
    return f;
}

Plain decode_halo(const uint8_t * tiles, int N, int K) {
    Plain p;
    p.N = N; p.K = K;
    p.trit.resize((size_t) N * K);
    p.scale.resize((size_t) N * (K / 128));
    const int ntiles = N / TILE_ROWS, nblk = K / BLOCK;
    const unsigned nthreads = std::max(1u, std::min(std::thread::hardware_concurrency(), (unsigned) ntiles));
    std::vector<std::thread> th;
    for (unsigned w = 0; w < nthreads; w++) th.emplace_back([&, w]() {
        uint8_t qs[24], qh[2], trit[128];
        for (int t = (int) w; t < ntiles; t += (int) nthreads)
            for (int b = 0; b < nblk; b++) {
                const uint8_t * base = tiles + ((size_t) t * nblk + b) * TILE_BLOCK_BYTES;
                for (int lane = 0; lane < TILE_ROWS; lane++) {
                    memcpy(qs, base + tile_off_qs_a(lane), 16);
                    memcpy(qs + 16, base + tile_off_qs_b(lane), 8);
                    const uint8_t * tail = base + tile_off_tail(lane);
                    qh[0] = tail[0]; qh[1] = tail[1];
                    uint16_t hs;
                    memcpy(&hs, tail + 2, 2);
                    decode_block(qs, qh, trit);
                    const int n = t * TILE_ROWS + lane;
                    int8_t * dst = &p.trit[(size_t) n * K + b * BLOCK];
                    for (int e = 0; e < BLOCK; e++) dst[e] = (int8_t) ((int) trit[e] - 1);
                    p.scale[(size_t) n * nblk + b] = half_to_float(hs);
                }
            }
    });
    for (auto & x : th) x.join();
    return p;
}

// [N/16][K/16][16][16] int8
std::vector<int8_t> swizzle_i8(const Plain & p) {
    std::vector<int8_t> o((size_t) p.N * p.K);
    const int kt = p.K / 16;
    for (int nt = 0; nt < p.N / 16; nt++)
        for (int k = 0; k < kt; k++)
            for (int i = 0; i < 16; i++)
                memcpy(&o[(((size_t) nt * kt + k) * 16 + i) * 16], &p.trit[(size_t) (nt * 16 + i) * p.K + k * 16], 16);
    return o;
}
// [N/16][K/16][16][8], two signed 4-bit values per byte
std::vector<int8_t> swizzle_i4(const Plain & p) {
    std::vector<int8_t> o((size_t) p.N * p.K / 2);
    const int kt = p.K / 16;
    for (int nt = 0; nt < p.N / 16; nt++)
        for (int k = 0; k < kt; k++)
            for (int i = 0; i < 16; i++) {
                const int8_t * src = &p.trit[(size_t) (nt * 16 + i) * p.K + k * 16];
                int8_t * dst = &o[(((size_t) nt * kt + k) * 16 + i) * 8];
                for (int j = 0; j < 8; j++)
                    dst[j] = (int8_t) ((src[2 * j] & 0x0f) | ((src[2 * j + 1] & 0x0f) << 4));
            }
    return o;
}
// [N/16][K/16][16][16] half, block scale folded in
std::vector<uint16_t> swizzle_f16(const Plain & p) {
    std::vector<uint16_t> o((size_t) p.N * p.K);
    const int kt = p.K / 16, nblk = p.K / 128;
    for (int nt = 0; nt < p.N / 16; nt++)
        for (int k = 0; k < kt; k++)
            for (int i = 0; i < 16; i++) {
                const int n = nt * 16 + i;
                const float sc = p.scale[(size_t) n * nblk + (k * 16) / 128];
                uint16_t * dst = &o[(((size_t) nt * kt + k) * 16 + i) * 16];
                for (int j = 0; j < 16; j++) {
                    const __half h = __float2half((float) p.trit[(size_t) n * p.K + k * 16 + j] * sc);
                    memcpy(&dst[j], &h, 2);
                }
            }
    return o;
}
// [N/16][K/128][16]
std::vector<float> swizzle_scale(const Plain & p) {
    const int nblk = p.K / 128;
    std::vector<float> o((size_t) p.N * nblk);
    for (int nt = 0; nt < p.N / 16; nt++)
        for (int b = 0; b < nblk; b++)
            for (int i = 0; i < 16; i++) o[((size_t) nt * nblk + b) * 16 + i] = p.scale[(size_t) (nt * 16 + i) * nblk + b];
    return o;
}

template <typename T> T * up(const std::vector<T> & h, size_t & total) {
    T * d = nullptr;
    HC(hipMalloc(&d, h.size() * sizeof(T)));
    HC(hipMemcpy(d, h.data(), h.size() * sizeof(T), hipMemcpyHostToDevice));
    total += h.size() * sizeof(T);
    return d;
}

struct State {
    int mode = 0, max_rows = 0;
    const float * norm = nullptr, * signs = nullptr;
    void * gate = nullptr, * upw = nullptr, * down = nullptr;
    float * gate_s = nullptr, * up_s = nullptr, * down_s = nullptr;
    int8_t * xq_d = nullptr, * xq_ff = nullptr, * xt_d = nullptr, * xt_ff = nullptr;
    float * xs_d = nullptr, * xs_ff = nullptr, * gbuf = nullptr, * ubuf = nullptr;
    int * xsum_d = nullptr, * xsum_ff = nullptr;
    __half * ah_d = nullptr, * ah_ff = nullptr;
    size_t bytes = 0;
};

void * prepare_mode(const kelana_batch::Weights & w, int max_batch, int mode) {
    if (w.width != D || w.hidden != FF) { fprintf(stderr, "native_dense: geometry mismatch\n"); abort(); }
    State * s = new State();
    s->mode = mode;
    s->max_rows = max_batch;
    s->norm = w.norm_device;
    s->signs = w.signs_device;
    struct Job { const uint8_t * src; int N, K; void ** dst; float ** sdst; };
    const Job jobs[3] = {
        { w.gate_host, FF, D,  &s->gate, &s->gate_s },
        { w.up_host,   FF, D,  &s->upw,  &s->up_s },
        { w.down_host, D,  FF, &s->down, &s->down_s },
    };
    for (const Job & j : jobs) {
        Plain p = decode_halo(j.src, j.N, j.K);
        if (mode == M_I8)       *j.dst = up(swizzle_i8(p), s->bytes);
        else if (mode == M_I4)  *j.dst = up(swizzle_i4(p), s->bytes);
        else                    *j.dst = up(swizzle_f16(p), s->bytes);
        *j.sdst = mode == M_F16 ? nullptr : up(swizzle_scale(p), s->bytes);
    }
    const size_t R = (size_t) max_batch;
    HC(hipMalloc(&s->xq_d, R * D));
    HC(hipMalloc(&s->xq_ff, R * FF));
    HC(hipMalloc(&s->xt_d, R * D));
    HC(hipMalloc(&s->xt_ff, R * FF));
    HC(hipMalloc(&s->xs_d, R * (D / 128) * 4));
    HC(hipMalloc(&s->xs_ff, R * (FF / 128) * 4));
    HC(hipMalloc(&s->xsum_d, R * (D / 128) * 4));
    HC(hipMalloc(&s->xsum_ff, R * (FF / 128) * 4));
    HC(hipMalloc(&s->gbuf, R * FF * 4));
    HC(hipMalloc(&s->ubuf, R * FF * 4));
    s->bytes += 2 * R * (D + FF) + R * ((D / 128) + (FF / 128)) * 8 + R * FF * 8;
    if (mode == M_F16) {
        HC(hipMalloc(&s->ah_d, R * D * 2));
        HC(hipMalloc(&s->ah_ff, R * FF * 2));
        s->bytes += R * (D + FF) * 2;
    }
    HC(hipDeviceSynchronize());
    return s;
}

void gemm(const State * s, int mode, const void * W, const float * ws, const void * A, const float * as,
          const float * bias, float * out, int M, int N, int K, hipStream_t st) {
    GemmP p{};
    p.W = W; p.wscale = ws; p.A = A; p.ascale = as; p.bias = bias; p.out = out;
    p.M = M; p.N = N; p.K = K;
    const int mt = M <= 32 ? 2 : 4;   // MT = 8 spills and runs 4x slower on this target
    const dim3 grid(N / 128, (M + mt * 16 - 1) / (mt * 16));
    #define LAUNCH(MD) do { \
        if (mt == 2)      hipLaunchKernelGGL((k_gemm<MD, 2>), grid, dim3(256), 0, st, p); \
        else if (mt == 4) hipLaunchKernelGGL((k_gemm<MD, 4>), grid, dim3(256), 0, st, p); \
        else              hipLaunchKernelGGL((k_gemm<MD, 8>), grid, dim3(256), 0, st, p); } while (0)
    if (mode == M_I8)      LAUNCH(M_I8);
    else if (mode == M_I4) LAUNCH(M_I4);
    else                   LAUNCH(M_F16);
    #undef LAUNCH
    (void) s;
}

void run(void * st, int rows, const float * input, float * output, hipStream_t stream) {
    State * s = (State *) st;
    const int mode = s->mode;

    { PrepR a{};
      a.x = input; a.kvec = s->norm; a.eps = NORM_EPS; a.n = D;
      a.flags = PREP_NORM | PREP_HADAMARD | PREP_QUANT;
      a.xq = s->xq_d; a.xs = s->xs_d; a.xsum = s->xsum_d;
      hipLaunchKernelGGL((k_prep<true>), dim3(rows * (D / 1024)), dim3(NT), 0, stream, a, D / 1024); }

    const void * Ad = s->xt_d;
    const float * Asd = s->xs_d;
    if (mode == M_F16) {
        hipLaunchKernelGGL(k_swizzle_ah, dim3((rows * (D / 16) + 255) / 256), dim3(256), 0, stream, s->xq_d, s->xs_d, s->ah_d, rows, D);
        Ad = s->ah_d; Asd = nullptr;
    } else {
        hipLaunchKernelGGL(k_swizzle_a8, dim3((rows * (D / 16) + 255) / 256), dim3(256), 0, stream, s->xq_d, s->xt_d, rows, D);
    }
    gemm(s, mode, s->gate, s->gate_s, Ad, Asd, nullptr, s->gbuf, rows, FF, D, stream);
    gemm(s, mode, s->upw,  s->up_s,   Ad, Asd, nullptr, s->ubuf, rows, FF, D, stream);

    { PrepR a{};
      a.x = s->gbuf; a.x2 = s->ubuf; a.kvec = s->signs; a.n = FF;
      a.flags = PREP_SILU_MUL | PREP_HADAMARD | PREP_QUANT;
      a.xq = s->xq_ff; a.xs = s->xs_ff; a.xsum = s->xsum_ff;
      hipLaunchKernelGGL((k_prep<false>), dim3(rows * (FF / 1024)), dim3(NT), 0, stream, a, FF / 1024); }

    const void * Af = s->xt_ff;
    const float * Asf = s->xs_ff;
    if (mode == M_F16) {
        hipLaunchKernelGGL(k_swizzle_ah, dim3((rows * (FF / 16) + 255) / 256), dim3(256), 0, stream, s->xq_ff, s->xs_ff, s->ah_ff, rows, FF);
        Af = s->ah_ff; Asf = nullptr;
    } else {
        hipLaunchKernelGGL(k_swizzle_a8, dim3((rows * (FF / 16) + 255) / 256), dim3(256), 0, stream, s->xq_ff, s->xt_ff, rows, FF);
    }
    // The down projection accumulates into the residual, so the batch's input rows are the bias.
    gemm(s, mode, s->down, s->down_s, Af, Asf, input, output, rows, D, FF, stream);
}

void release(void * st) {
    State * s = (State *) st;
    if (!s) return;
    for (void * p : { s->gate, s->upw, s->down, (void *) s->gate_s, (void *) s->up_s, (void *) s->down_s,
                      (void *) s->xq_d, (void *) s->xq_ff, (void *) s->xt_d, (void *) s->xt_ff,
                      (void *) s->xs_d, (void *) s->xs_ff,
                      (void *) s->xsum_d, (void *) s->xsum_ff, (void *) s->gbuf, (void *) s->ubuf,
                      (void *) s->ah_d, (void *) s->ah_ff })
        if (p) (void) hipFree(p);
    delete s;
}

size_t resident_bytes(void * st) { return st ? ((State *) st)->bytes : 0; }

void * prep_i8(const kelana_batch::Weights & w, int b) { return prepare_mode(w, b, M_I8); }
void * prep_i4(const kelana_batch::Weights & w, int b) { return prepare_mode(w, b, M_I4); }
void * prep_f16(const kelana_batch::Weights & w, int b) { return prepare_mode(w, b, M_F16); }

kelana_batch::Candidate make(const char * name, const char * desc, void * (*pf)(const kelana_batch::Weights &, int)) {
    kelana_batch::Candidate c{};
    c.name = name;
    c.claim = kelana_batch::Claim::approximate;
    c.description = desc;
    c.prepare = pf;
    c.run = run;
    c.release = release;
    c.resident_bytes = resident_bytes;
    return c;
}

kelana_batch::Candidate native_iu8() {
    return make("native_iu8", "dense IU8 WMMA over int8-expanded ternary weights, int32 per 128-block then FP32", prep_i8);
}
kelana_batch::Candidate native_i4() {
    return make("native_i4", "same ternary weights stored two per byte as 4-bit, unpacked to int8 for the same IU8 WMMA; storage comparison, not a model-quality comparison", prep_i4);
}
kelana_batch::Candidate native_fp16() {
    return make("native_fp16", "dense FP16 WMMA, block scale folded into the weights so the sum reassociates across the whole K", prep_f16);
}

} // namespace

KELANA_BATCH_REGISTER(native_iu8)
KELANA_BATCH_REGISTER(native_i4)
KELANA_BATCH_REGISTER(native_fp16)
