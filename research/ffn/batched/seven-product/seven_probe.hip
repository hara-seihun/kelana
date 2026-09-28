// One level of Strassen on the deployed gate/up projection, with the fixed weight combinations
// compiled offline into a small-alphabet code.
//
// The default problem is real: the deployed ternary weights and FP16 block scales of one layer of
// the batch dataset, and real contextual token rows carried through the deployed FFN input
// transform. `--synthetic` selects random trits, synthetic scales and iid Gaussian activations,
// which is kept as a correctness case only. Timing uses the shared bench/timing.hpp contract:
// duration ramp, randomised candidate blocks inside repeated rounds, every sample retained with
// its round and host timestamps, and a sensor trace written beside them.
//
// The 2x2x2 block split this probe uses:
//
//   M dimension (weight rows) : the gate row tile and the up row tile a wave already owns
//   K dimension               : two 16-wide WMMA slices *inside one 128-scale block*
//   N dimension (tokens)      : two adjacent 16-token tiles
//
// Choosing the K split inside a scale block is what keeps the scheme exact. A partial product for
// one 128-block carries the scale sw[row] * sa[token], which does not depend on k, so the integer
// matmul over the block factors out completely and Strassen's cancellations happen in int32. No
// scale grouping, no scale rounding, no approximation of the weights. The seven-product kernel is
// required to be bit-identical to the eight-product control on the same codes, and `check`
// enforces that.
//
// What is *not* free is operand width. Five of the seven products take a sum or difference of two
// activation fragments. With A4 codes in [-7,7] the sums reach 14 and no longer fit a signed
// nibble, so the IU4 instruction cannot execute this plan on A4. It can on A3 codes in [-3,3]
// (sums in [-6,6]), and IU8 can on A7 codes in [-63,63] (sums in [-126,126]). Weight sums are in
// [-2,2] in every case.
//
//   eight-i4p  two-bit weight storage expanded to nibbles, 8 products      (fastest current shape)
//   eight-i4n  four-bit weight storage, 8 products                         (matched storage control)
//   eight-i8   two-bit weight storage expanded to bytes, 8 products
//   seven-i4   seven compiled operands at four bits, 7 products
//   seven-i8   seven compiled operands at eight bits, 7 products
//
// Activation width is a separate axis from the product count: eight-i4n/A4 and seven-i4/A3 are
// both four-bit-operand kernels but different numerics, so the honest speed comparison is
// seven-i4/A3 against eight-i4n/A3 and eight-i4p/A3, and the honest quality comparison is A3
// against A4 at equal product count.
#include "../arithmetic/maps.hpp"
#include "../bench/batch_dataset.h"
#include "../bench/telemetry.hpp"
#include "../bench/sha256.hpp"
#include "halo_format.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
#include <string>
#include <functional>
#include <algorithm>
#include <random>

using namespace kelana_arith;

#define HIP_OK(c) do { hipError_t e_ = (c); if (e_ != hipSuccess) { \
    printf("HIP error %s at line %d\n", hipGetErrorString(e_), __LINE__); exit(1);} } while (0)

#include "../bench/probe_measure.hpp"

// Host-side half to float, for the deployed FP16 block scales.
static inline float h2f_host(uint16_t bits) {
    _Float16 h; std::memcpy(&h, &bits, 2); return float(h);
}

constexpr int NW = 4;      // waves per workgroup
constexpr int KP = 4;      // Strassen k-pairs per 128-block (8 slices / 2)

__device__ __forceinline__ float h2f(unsigned bits) {
    unsigned short u = (unsigned short)bits; _Float16 h;
    __builtin_memcpy(&h, &u, 2); return (float)h;
}

// Offset ternary storage: code w+1 in {0,1,2}, two bits, same block layout as pack_two_bit.
// Expanding it to nibbles is pure bit spreading with no sign extension, and two offset operands
// add with a plain 32-bit add because no nibble can exceed 4. The WMMA then runs with an unsigned
// A operand and the constant offset is removed afterwards by a rank-one correction: adding c to
// every weight adds c * (column sum of the activation operand) to every row of the accumulator.
inline std::vector<uint8_t> pack_two_bit_off(const int8_t *w, int rows, int kdim) {
    int nb = kdim / KB;
    std::vector<uint8_t> out(size_t(rows / 16) * nb * 512, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            uint8_t *dst = out.data() + (size_t(tile) * nb + b) * 512;
            for (int r = 0; r < 16; ++r) {
                const int8_t *s = w + size_t(tile * 16 + r) * kdim + b * KB;
                for (int sl = 0; sl < SLICES; ++sl) {
                    uint32_t word = 0;
                    for (int j = 0; j < 16; ++j) word |= uint32_t(s[sl * 16 + j] + 1) << (2 * j);
                    std::memcpy(dst + sl * 64 + r * 4, &word, 4);
                }
            }
        }
    return out;
}

__device__ __forceinline__ int2v expand_u4(unsigned codes) {
    int2v r;
#pragma unroll
    for (int j = 0; j < 2; ++j) {
        unsigned v = (codes >> (16 * j)) & 0xffffu;
        unsigned x = (v | (v << 8)) & 0x00ff00ffu;
        x = (x | (x << 4)) & 0x0f0f0f0fu;
        r[j] = int((x | (x << 2)) & 0x33333333u);
    }
    return r;
}
__device__ __forceinline__ int2v neg_u4(int2v x) {   // 2 - code, still in {0,1,2}
    int2v r; r[0] = 0x22222222 - x[0]; r[1] = 0x22222222 - x[1]; return r;
}
__device__ __forceinline__ int2v add_u4(int2v a, int2v b) {
    int2v r; r[0] = a[0] + b[0]; r[1] = a[1] + b[1]; return r;
}

// ------------------------------------------------------------------------------- eight-product
// STORE 0: two-bit codes expanded to nibbles (iu4). 1: four-bit nibbles (iu4). 2: two-bit codes
// expanded to bytes (iu8). 3: offset two-bit codes expanded to unsigned nibbles with the rank-one
// correction in `corr` (iu4). Identical loop nest to the seven-product kernel below: same wave
// geometry, same token grouping, same per-block epilogue shape.
// SPLIT=1 gives the control the other structural advantage the seven-product kernel gets for free:
// one accumulator per k-parity, so eight independent WMMA chains instead of four. It costs four
// extra vector adds per accumulator per block and the same register class the seven products use.
// WMAP=1 gives one row tile to the whole workgroup and one token group to each wave, so the four
// waves of a workgroup stream the same weight bytes at the same time and the L1 serves three of
// the four. That is the other way to amortise weight re-reads, and unlike a wider token tile it
// costs no registers, so the seven-product kernel can use it too.
template <int TT, int STORE, int SPLIT = 0, int WMAP = 0, int NWV = NW>
__global__ __launch_bounds__(NWV * 32) void k_eight(
        const uint8_t *__restrict__ Wg, const uint8_t *__restrict__ Wu, const void *__restrict__ Bv,
        const uint16_t *__restrict__ sg, const uint16_t *__restrict__ su,
        const float *__restrict__ cscale, const int *__restrict__ corr,
        float *__restrict__ og, float *__restrict__ ou,
        int nb, int N, int FF) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = WMAP ? blockIdx.x : blockIdx.x * NWV + wave, col = lane & 15, half = lane >> 4;
    constexpr int WBYTES = STORE == 1 ? 1024 : 512;
    const uint8_t *gbase = Wg + size_t(tile) * nb * WBYTES;
    const uint8_t *ubase = Wu + size_t(tile) * nb * WBYTES;
    constexpr int AC = SPLIT ? 2 : 1;
    for (int tg = WMAP ? wave * TT * 16 : 0; tg < N; tg += (WMAP ? NWV : 1) * TT * 16) {
        int8v ag[TT][AC], au[TT][AC];
        float yg[TT][8], yu[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { yg[t][r] = 0.f; yu[t][r] = 0.f; }
        for (int b = 0; b < nb; ++b) {
            const uint8_t *gb = gbase + size_t(b) * WBYTES, *ub = ubase + size_t(b) * WBYTES;
            int row = tile * 16 + col;
            float gsl = h2f(sg[size_t(row) * nb + b]), usl = h2f(su[size_t(row) * nb + b]), gsr[8], usr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { gsr[r] = __shfl(gsl, 2 * r + half, 32); usr[r] = __shfl(usl, 2 * r + half, 32); }
#pragma unroll
            for (int t = 0; t < TT; ++t)
#pragma unroll
                for (int c = 0; c < AC; ++c) { ag[t][c] = int8v{}; au[t][c] = int8v{}; }
#pragma unroll 1
            for (int s = 0; s < SLICES; ++s) {
                if constexpr (STORE == 2) {
                    int4v wg = expand_i8(*(const unsigned *)(gb + s * 64 + col * 4));
                    int4v wu = expand_i8(*(const unsigned *)(ub + s * 64 + col * 4));
#pragma unroll
                    for (int t = 0; t < TT; ++t) {
                        int4v bf = ((const int4v *)Bv)[size_t(b * SLICES + s) * N + tg + t * 16 + col];
                        int c = SPLIT ? (s & 1) : 0;
                        ag[t][c] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wg, true, bf, ag[t][c], false);
                        au[t][c] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wu, true, bf, au[t][c], false);
                    }
                } else {
                    int2v wg, wu;
                    if constexpr (STORE == 1) {
                        wg = *(const int2v *)(gb + s * 128 + col * 8);
                        wu = *(const int2v *)(ub + s * 128 + col * 8);
                    } else if constexpr (STORE == 3) {
                        wg = expand_u4(*(const unsigned *)(gb + s * 64 + col * 4));
                        wu = expand_u4(*(const unsigned *)(ub + s * 64 + col * 4));
                    } else {
                        wg = expand_i4(*(const unsigned *)(gb + s * 64 + col * 4));
                        wu = expand_i4(*(const unsigned *)(ub + s * 64 + col * 4));
                    }
#pragma unroll
                    for (int t = 0; t < TT; ++t) {
                        int2v bf = ((const int2v *)Bv)[size_t(b * SLICES + s) * N + tg + t * 16 + col];
                        constexpr bool SA = STORE != 3;
                        int c = SPLIT ? (s & 1) : 0;
                        ag[t][c] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(SA, wg, true, bf, ag[t][c], false);
                        au[t][c] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(SA, wu, true, bf, au[t][c], false);
                    }
                }
            }
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                float cs = cscale[size_t(tg + t * 16 + col) * nb + b];
                int k = STORE == 3 ? corr[size_t(tg + t * 16 + col) * nb + b] : 0;
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    int gv = SPLIT ? ag[t][0][r] + ag[t][1][r] : ag[t][0][r];
                    int uv = SPLIT ? au[t][0][r] + au[t][1][r] : au[t][0][r];
                    yg[t][r] = __builtin_fmaf(float(gv - k), gsr[r] * cs, yg[t][r]);
                    yu[t][r] = __builtin_fmaf(float(uv - k), usr[r] * cs, yu[t][r]);
                }
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                size_t o = size_t(tg + t * 16 + col) * FF + tile * 16 + 2 * r + half;
                og[o] = yg[t][r]; ou[o] = yu[t][r];
            }
    }
}

// ------------------------------------------------------------------------------- seven-product
// Weight image: [tile][block][k-pair][7 operands][16 rows] fragments, compiled offline.
// Activation image: [block*KP + k-pair][token pair][7 operands][16 tokens] fragments, built by the
// producer. Operand m is exactly the pair (W, B) that product M_{m+1} multiplies.
template <int TT, bool IS8>
__global__ __launch_bounds__(NW * 32) void k_seven(
        const void *__restrict__ Wc, const void *__restrict__ Bc,
        const uint16_t *__restrict__ sg, const uint16_t *__restrict__ su,
        const float *__restrict__ cscale, float *__restrict__ og, float *__restrict__ ou,
        int nb, int N, int FF) {
    using frag = std::conditional_t<IS8, int4v, int2v>;
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    constexpr int PAIRS = TT / 2;
    const int npairs = N / 32;
    const frag *wbase = (const frag *)Wc + (size_t(tile) * nb * KP) * 7 * 16 + col;
    const frag *bbase = (const frag *)Bc + col;
    for (int tg = 0; tg < N; tg += TT * 16) {
        int8v acc[PAIRS][7];
        float yg[TT][8], yu[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { yg[t][r] = 0.f; yu[t][r] = 0.f; }
        for (int b = 0; b < nb; ++b) {
            int row = tile * 16 + col;
            float gsl = h2f(sg[size_t(row) * nb + b]), usl = h2f(su[size_t(row) * nb + b]), gsr[8], usr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { gsr[r] = __shfl(gsl, 2 * r + half, 32); usr[r] = __shfl(usl, 2 * r + half, 32); }
#pragma unroll
            for (int p = 0; p < PAIRS; ++p)
#pragma unroll
                for (int m = 0; m < 7; ++m) acc[p][m] = int8v{};
#pragma unroll 1
            for (int kp = 0; kp < KP; ++kp) {
                const frag *wf = wbase + (size_t(b) * KP + kp) * 7 * 16;
                const frag *bf = bbase + (size_t(b) * KP + kp) * size_t(npairs) * 7 * 16;
#pragma unroll
                for (int m = 0; m < 7; ++m) {
                    frag w = wf[m * 16];
#pragma unroll
                    for (int p = 0; p < PAIRS; ++p) {
                        frag a = bf[(size_t(tg / 32 + p) * 7 + m) * 16];
                        if constexpr (IS8)
                            acc[p][m] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, w, true, a, acc[p][m], false);
                        else
                            acc[p][m] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, w, true, a, acc[p][m], false);
                    }
                }
            }
            // C11 = M1+M4-M5+M7, C12 = M3+M5, C21 = M2+M4, C22 = M1-M2+M3+M6, in int32.
#pragma unroll
            for (int p = 0; p < PAIRS; ++p) {
                int t0 = 2 * p, t1 = 2 * p + 1;
                float cs0 = cscale[size_t(tg + t0 * 16 + col) * nb + b];
                float cs1 = cscale[size_t(tg + t1 * 16 + col) * nb + b];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    int c11 = acc[p][0][r] + acc[p][3][r] - acc[p][4][r] + acc[p][6][r];
                    int c12 = acc[p][2][r] + acc[p][4][r];
                    int c21 = acc[p][1][r] + acc[p][3][r];
                    int c22 = acc[p][0][r] - acc[p][1][r] + acc[p][2][r] + acc[p][5][r];
                    yg[t0][r] = __builtin_fmaf(float(c11), gsr[r] * cs0, yg[t0][r]);
                    yg[t1][r] = __builtin_fmaf(float(c12), gsr[r] * cs1, yg[t1][r]);
                    yu[t0][r] = __builtin_fmaf(float(c21), usr[r] * cs0, yu[t0][r]);
                    yu[t1][r] = __builtin_fmaf(float(c22), usr[r] * cs1, yu[t1][r]);
                }
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                size_t o = size_t(tg + t * 16 + col) * FF + tile * 16 + 2 * r + half;
                og[o] = yg[t][r]; ou[o] = yu[t][r];
            }
    }
}

// ------------------------------------------------ seven-product from compact two-bit storage
// Same seven products, but the five sum/difference operands are rebuilt in registers from the
// baseline two-bit weight image instead of being read as a compiled four-bit image. Weight traffic
// is then identical to the eight-product control, and the question becomes purely instruction
// count: one WMMA saved in eight against the operand construction and the output recombination.
template <int TT, int WMAP = 0, int NWV = NW>
__global__ __launch_bounds__(NWV * 32) void k_seven_packed(
        const uint8_t *__restrict__ Wg, const uint8_t *__restrict__ Wu, const int2v *__restrict__ Bc,
        const uint16_t *__restrict__ sg, const uint16_t *__restrict__ su,
        const float *__restrict__ cscale, const int *__restrict__ kgate, const int *__restrict__ kup,
        float *__restrict__ og, float *__restrict__ ou,
        int nb, int N, int FF) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = WMAP ? blockIdx.x : blockIdx.x * NWV + wave, col = lane & 15, half = lane >> 4;
    constexpr int PAIRS = TT / 2;
    const int npairs = N / 32;
    const uint8_t *gbase = Wg + size_t(tile) * nb * 512, *ubase = Wu + size_t(tile) * nb * 512;
    const int2v *bbase = Bc + col;
    for (int tg = WMAP ? wave * TT * 16 : 0; tg < N; tg += (WMAP ? NWV : 1) * TT * 16) {
        int8v acc[PAIRS][7];
        float yg[TT][8], yu[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { yg[t][r] = 0.f; yu[t][r] = 0.f; }
        for (int b = 0; b < nb; ++b) {
            const uint8_t *gb = gbase + size_t(b) * 512, *ub = ubase + size_t(b) * 512;
            int row = tile * 16 + col;
            float gsl = h2f(sg[size_t(row) * nb + b]), usl = h2f(su[size_t(row) * nb + b]), gsr[8], usr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { gsr[r] = __shfl(gsl, 2 * r + half, 32); usr[r] = __shfl(usl, 2 * r + half, 32); }
#pragma unroll
            for (int p = 0; p < PAIRS; ++p)
#pragma unroll
                for (int m = 0; m < 7; ++m) acc[p][m] = int8v{};
#pragma unroll 1
            for (int kp = 0; kp < KP; ++kp) {
                int2v g0 = expand_u4(*(const unsigned *)(gb + (2 * kp) * 64 + col * 4));
                int2v g1 = expand_u4(*(const unsigned *)(gb + (2 * kp + 1) * 64 + col * 4));
                int2v u0 = expand_u4(*(const unsigned *)(ub + (2 * kp) * 64 + col * 4));
                int2v u1 = expand_u4(*(const unsigned *)(ub + (2 * kp + 1) * 64 + col * 4));
                int2v w[7];
                w[0] = add_u4(g0, u1);              // W11+W22 + 2J
                w[1] = add_u4(u0, u1);              // W21+W22 + 2J
                w[2] = g0;                          // W11 + J
                w[3] = u1;                          // W22 + J
                w[4] = add_u4(g0, g1);              // W11+W12 + 2J
                w[5] = add_u4(u0, neg_u4(g0));      // W21-W11 + 2J
                w[6] = add_u4(g1, neg_u4(u1));      // W12-W22 + 2J
                const int2v *bf = bbase + (size_t(b) * KP + kp) * size_t(npairs) * 7 * 16;
#pragma unroll
                for (int m = 0; m < 7; ++m)
#pragma unroll
                    for (int p = 0; p < PAIRS; ++p) {
                        int2v a = bf[(size_t(tg / 32 + p) * 7 + m) * 16];
                        acc[p][m] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(false, w[m], true, a, acc[p][m], false);
                    }
            }
#pragma unroll
            for (int p = 0; p < PAIRS; ++p) {
                int t0 = 2 * p, t1 = 2 * p + 1;
                size_t i0 = size_t(tg + t0 * 16 + col) * nb + b, i1 = size_t(tg + t1 * 16 + col) * nb + b;
                float cs0 = cscale[i0], cs1 = cscale[i1];
                int k11 = kgate[i0], k12 = kgate[i1], k21 = kup[i0], k22 = kup[i1];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    int c11 = acc[p][0][r] + acc[p][3][r] - acc[p][4][r] + acc[p][6][r] - k11;
                    int c12 = acc[p][2][r] + acc[p][4][r] - k12;
                    int c21 = acc[p][1][r] + acc[p][3][r] - k21;
                    int c22 = acc[p][0][r] - acc[p][1][r] + acc[p][2][r] + acc[p][5][r] - k22;
                    yg[t0][r] = __builtin_fmaf(float(c11), gsr[r] * cs0, yg[t0][r]);
                    yg[t1][r] = __builtin_fmaf(float(c12), gsr[r] * cs1, yg[t1][r]);
                    yu[t0][r] = __builtin_fmaf(float(c21), usr[r] * cs0, yu[t0][r]);
                    yu[t1][r] = __builtin_fmaf(float(c22), usr[r] * cs1, yu[t1][r]);
                }
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                size_t o = size_t(tg + t * 16 + col) * FF + tile * 16 + 2 * r + half;
                og[o] = yg[t][r]; ou[o] = yu[t][r];
            }
    }
}

// ------------------------------------------------------------------------------------ host side

template <class T> struct Dev {
    T *p = nullptr; size_t n = 0;
    Dev() = default;
    explicit Dev(size_t count) : n(count) { HIP_OK(hipMalloc(&p, count * sizeof(T))); HIP_OK(hipMemset(p, 0, count * sizeof(T))); }
    void put(const std::vector<T> &v) { HIP_OK(hipMemcpy(p, v.data(), v.size() * sizeof(T), hipMemcpyHostToDevice)); }
    Dev(Dev &&o) noexcept : p(o.p), n(o.n) { o.p = nullptr; }
    Dev &operator=(Dev &&o) noexcept { std::swap(p, o.p); std::swap(n, o.n); return *this; }
    ~Dev() { if (p) hipFree(p); }
};

struct Problem {
    int D, FF, N, nb;
    std::vector<int8_t> gate, up;
    std::vector<uint16_t> gs, us;
    std::vector<float> act;                       // [N][D] pre-quantisation activations
    std::vector<int8_t> q8, q7, q4, q3;           // codes at +-127, +-63, +-7, +-3
    std::vector<float> s8, s7, s4, s3;            // [N][nb] activation scales
};

static Problem make_problem(int D, int FF, int N, uint64_t seed) {
    Problem p{D, FF, N, D / KB, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}};
    std::mt19937_64 rng(seed);
    p.gate.assign(size_t(FF) * D, 0); p.up.assign(size_t(FF) * D, 0);
    p.gs.assign(size_t(FF) * p.nb, 0); p.us.assign(size_t(FF) * p.nb, 0);
    for (size_t i = 0; i < p.gate.size(); ++i) {
        p.gate[i] = int8_t(int(rng() % 3) - 1);
        p.up[i] = int8_t(int(rng() % 3) - 1);
    }
    for (int row = 0; row < FF; ++row)
        for (int b = 0; b < p.nb; ++b) {
            float g = 0.0035f + 0.001f * float(rng() % 100) / 100.f;
            _Float16 hg = (_Float16)g, hu = (_Float16)(g * 1.1f);
            std::memcpy(&p.gs[size_t(row) * p.nb + b], &hg, 2);
            std::memcpy(&p.us[size_t(row) * p.nb + b], &hu, 2);
        }
    p.act.assign(size_t(N) * D, 0.f);
    p.q8.assign(size_t(N) * D, 0); p.q7.assign(size_t(N) * D, 0);
    p.q4.assign(size_t(N) * D, 0); p.q3.assign(size_t(N) * D, 0);
    p.s8.assign(size_t(N) * p.nb, 0.f); p.s7 = p.s8; p.s4 = p.s8; p.s3 = p.s8;
    std::normal_distribution<float> gauss(0.f, 1.f);
    for (int t = 0; t < N; ++t)
        for (int b = 0; b < p.nb; ++b) {
            float v[KB], amax = 0.f;
            for (int j = 0; j < KB; ++j) { v[j] = gauss(rng); amax = std::max(amax, std::fabs(v[j])); }
            struct Lev { int lim; std::vector<int8_t> *q; std::vector<float> *s; };
            Lev levels[4] = {{127, &p.q8, &p.s8}, {63, &p.q7, &p.s7}, {7, &p.q4, &p.s4}, {3, &p.q3, &p.s3}};
            for (int j = 0; j < KB; ++j) p.act[size_t(t) * D + b * KB + j] = v[j];
            for (auto &L : levels) {
                float sc = amax / float(L.lim);
                for (int j = 0; j < KB; ++j) {
                    int a = int(std::lround(v[j] / sc));
                    (*L.q)[size_t(t) * D + b * KB + j] = int8_t(std::max(-L.lim, std::min(L.lim, a)));
                }
                (*L.s)[size_t(t) * p.nb + b] = sc;
            }
        }
    return p;
}

// Plain B fragments: lane col supplies the 16 K values of token col.
template <class FRAG, int WIDTH>
static std::vector<FRAG> b_plain(const Problem &p, const std::vector<int8_t> &q) {
    std::vector<FRAG> out(size_t(p.nb * SLICES) * p.N);
    for (int t = 0; t < p.N; ++t)
        for (int k = 0; k < p.nb * SLICES; ++k) {
            uint8_t raw[16] = {};
            for (int j = 0; j < 16; ++j) {
                int v = q[size_t(t) * p.D + k * 16 + j];
                if (WIDTH == 8) raw[j] = uint8_t(v);
                else raw[j / 2] |= uint8_t(v & 0xf) << (4 * (j & 1));
            }
            FRAG f; std::memcpy(&f, raw, sizeof(FRAG));
            out[size_t(k) * p.N + t] = f;
        }
    return out;
}

// Seven activation operands per (k-pair, token pair). B11=(s0,tokA) B12=(s0,tokB)
// B21=(s1,tokA) B22=(s1,tokB); operands are M1..M7's B factor.
template <class FRAG, int WIDTH>
static std::vector<FRAG> b_seven(const Problem &p, const std::vector<int8_t> &q) {
    int nkp = p.nb * KP, npairs = p.N / 32;
    std::vector<FRAG> out(size_t(nkp) * npairs * 7 * 16);
    for (int kp = 0; kp < nkp; ++kp) {
        int s0 = (kp / KP) * SLICES + (kp % KP) * 2, s1 = s0 + 1;
        for (int i = 0; i < npairs; ++i)
            for (int col = 0; col < 16; ++col) {
                int ta = 32 * i + col, tb = 32 * i + 16 + col;
                auto Q = [&](int s, int tok, int j) { return int(q[size_t(tok) * p.D + s * 16 + j]); };
                for (int m = 0; m < 7; ++m) {
                    uint8_t raw[16] = {};
                    for (int j = 0; j < 16; ++j) {
                        int v = 0;
                        switch (m) {
                            case 0: v = Q(s0, ta, j) + Q(s1, tb, j); break;   // B11+B22
                            case 1: v = Q(s0, ta, j); break;                  // B11
                            case 2: v = Q(s0, tb, j) - Q(s1, tb, j); break;   // B12-B22
                            case 3: v = Q(s1, ta, j) - Q(s0, ta, j); break;   // B21-B11
                            case 4: v = Q(s1, tb, j); break;                  // B22
                            case 5: v = Q(s0, ta, j) + Q(s0, tb, j); break;   // B11+B12
                            case 6: v = Q(s1, ta, j) + Q(s1, tb, j); break;   // B21+B22
                        }
                        if (WIDTH == 8) raw[j] = uint8_t(v);
                        else raw[j / 2] |= uint8_t(v & 0xf) << (4 * (j & 1));
                    }
                    FRAG f; std::memcpy(&f, raw, sizeof(FRAG));
                    out[((size_t(kp) * npairs + i) * 7 + m) * 16 + col] = f;
                }
            }
    }
    return out;
}

// Seven compiled weight operands per (tile, block, k-pair). W11=gate s0, W12=gate s1,
// W21=up s0, W22=up s1; every entry is in [-2,2].
template <class FRAG, int WIDTH>
static std::vector<FRAG> w_seven(const Problem &p) {
    int tiles = p.FF / 16;
    std::vector<FRAG> out(size_t(tiles) * p.nb * KP * 7 * 16);
#pragma omp parallel for schedule(static)
    for (int tile = 0; tile < tiles; ++tile)
        for (int b = 0; b < p.nb; ++b)
            for (int kp = 0; kp < KP; ++kp) {
                int k0 = b * KB + kp * 32, k1 = k0 + 16;
                for (int m = 0; m < 7; ++m)
                    for (int r = 0; r < 16; ++r) {
                        size_t row = size_t(tile) * 16 + r;
                        uint8_t raw[16] = {};
                        for (int j = 0; j < 16; ++j) {
                            int g0 = p.gate[row * p.D + k0 + j], g1 = p.gate[row * p.D + k1 + j];
                            int u0 = p.up[row * p.D + k0 + j], u1 = p.up[row * p.D + k1 + j];
                            int v = 0;
                            switch (m) {
                                case 0: v = g0 + u1; break;   // W11+W22
                                case 1: v = u0 + u1; break;   // W21+W22
                                case 2: v = g0; break;        // W11
                                case 3: v = u1; break;        // W22
                                case 4: v = g0 + g1; break;   // W11+W12
                                case 5: v = u0 - g0; break;   // W21-W11
                                case 6: v = g1 - u1; break;   // W12-W22
                            }
                            if (WIDTH == 8) raw[j] = uint8_t(v);
                            else raw[j / 2] |= uint8_t(v & 0xf) << (4 * (j & 1));
                        }
                        FRAG f; std::memcpy(&f, raw, sizeof(FRAG));
                        out[(((size_t(tile) * p.nb + b) * KP + kp) * 7 + m) * 16 + r] = f;
                    }
            }
    return out;
}

// Rank-one corrections for the offset weight storage. Eight-product: every weight carries +1, so
// the correction is the activation sum over the 128-block. Seven-product: operand m carries
// off[m] * (column sum of its activation operand), recombined the same way the products are.
static std::vector<int> corr_eight(const Problem &p, const std::vector<int8_t> &q) {
    std::vector<int> out(size_t(p.N) * p.nb, 0);
    for (int t = 0; t < p.N; ++t)
        for (int b = 0; b < p.nb; ++b) {
            int s = 0;
            for (int j = 0; j < KB; ++j) s += q[size_t(t) * p.D + b * KB + j];
            out[size_t(t) * p.nb + b] = s;
        }
    return out;
}

static void corr_seven(const Problem &p, const std::vector<int8_t> &q,
                       std::vector<int> &kg, std::vector<int> &ku) {
    kg.assign(size_t(p.N) * p.nb, 0); ku.assign(size_t(p.N) * p.nb, 0);
    int npairs = p.N / 32;
    for (int b = 0; b < p.nb; ++b)
        for (int i = 0; i < npairs; ++i)
            for (int col = 0; col < 16; ++col) {
                int ta = 32 * i + col, tb = 32 * i + 16 + col;
                long L[7] = {};
                for (int kp = 0; kp < KP; ++kp) {
                    int s0 = b * SLICES + kp * 2, s1 = s0 + 1;
                    auto S = [&](int s, int tok) {
                        int a = 0;
                        for (int j = 0; j < 16; ++j) a += q[size_t(tok) * p.D + s * 16 + j];
                        return a;
                    };
                    int s0a = S(s0, ta), s0b = S(s0, tb), s1a = S(s1, ta), s1b = S(s1, tb);
                    L[0] += s0a + s1b; L[1] += s0a; L[2] += s0b - s1b; L[3] += s1a - s0a;
                    L[4] += s1b; L[5] += s0a + s0b; L[6] += s1a + s1b;
                }
                const int off[7] = {2, 2, 1, 1, 2, 2, 2};
                kg[size_t(ta) * p.nb + b] = int(off[0] * L[0] + off[3] * L[3] - off[4] * L[4] + off[6] * L[6]);
                kg[size_t(tb) * p.nb + b] = int(off[2] * L[2] + off[4] * L[4]);
                ku[size_t(ta) * p.nb + b] = int(off[1] * L[1] + off[3] * L[3]);
                ku[size_t(tb) * p.nb + b] = int(off[0] * L[0] - off[1] * L[1] + off[2] * L[2] + off[5] * L[5]);
            }
}

// -------------------------------------------------------------------------- problem provenance

// Real problem: the deployed ternary weights and FP16 block scales of one layer, and real
// contextual token rows carried through the deployed FFN input transform. Synthetic problem:
// random trits, synthetic scales and iid Gaussian activations, kept only as a correctness case.
struct Source {
    std::string kind, dataset, manifest_sha256, model, document, document_sha256, tokens_sha256;
    std::string bonsai_commit;
    int layer = -1;
};

static void decode_halo_ternary(const std::vector<uint8_t> &tiles, int rows, int kdim,
                                std::vector<int8_t> &trit, std::vector<uint16_t> &scale) {
    using namespace halo;
    const int ntiles = rows / TILE_ROWS, nblk = kdim / BLOCK;
    trit.assign(size_t(rows) * kdim, 0);
    scale.assign(size_t(rows) * nblk, 0);
#pragma omp parallel for schedule(static)
    for (int t = 0; t < ntiles; ++t) {
        uint8_t qs[24], qh[2], tr[128];
        for (int b = 0; b < nblk; ++b) {
            const uint8_t *base = tiles.data() + (size_t(t) * nblk + b) * TILE_BLOCK_BYTES;
            for (int lane = 0; lane < TILE_ROWS; ++lane) {
                std::memcpy(qs, base + tile_off_qs_a(lane), 16);
                std::memcpy(qs + 16, base + tile_off_qs_b(lane), 8);
                const uint8_t *tail = base + tile_off_tail(lane);
                qh[0] = tail[0]; qh[1] = tail[1];
                decode_block(qs, qh, tr);
                const int row = t * TILE_ROWS + lane;
                int8_t *dst = &trit[size_t(row) * kdim + b * BLOCK];
                for (int e = 0; e < BLOCK; ++e) dst[e] = int8_t(int(tr[e]) - 1);
                std::memcpy(&scale[size_t(row) * nblk + b], tail + 2, 2);
            }
        }
    }
}

// The deployed FFN input transform, on the host: post-attention RMS norm, the folded width-D sign
// vector, and the 1024-point Hadamard with the 1/32 orthonormal factor, exactly the sequence
// prep_chunk_r and the arithmetic candidates' producer apply before quantisation. Host float
// summation reassociates differently from the device reduction, so these values are the deployed
// transform of the real rows rather than a bit copy of the device's intermediate.
static std::vector<float> ffn_input_transform(const std::vector<float> &x, const std::vector<float> &kvec,
                                              int rows, int D) {
    std::vector<float> out(size_t(rows) * D);
#pragma omp parallel for schedule(static)
    for (int r = 0; r < rows; ++r) {
        const float *src = x.data() + size_t(r) * D;
        float ss = 0.f;
        for (int i = 0; i < D; ++i) ss += src[i] * src[i];
        const float inv = 1.0f / std::sqrt(ss / float(D) + 1e-5f);
        float *dst = out.data() + size_t(r) * D;
        for (int i = 0; i < D; ++i) dst[i] = src[i] * inv * kvec[i];
        for (int c = 0; c < D / 1024; ++c) {
            float *v = dst + c * 1024;
            for (int len = 1; len < 1024; len <<= 1)
                for (int i = 0; i < 1024; ++i)
                    if ((i & len) == 0) { float a = v[i], b = v[i + len]; v[i] = a + b; v[i + len] = a - b; }
            for (int i = 0; i < 1024; ++i) v[i] *= 0.03125f;
        }
    }
    return out;
}

// The directory's quantiser, applied identically at every width: deterministic, symmetric,
// per (token, 128-block), scale amax/L, round half away from zero, clamp to [-L, L].
static void quantise(const Problem &p, float levels, std::vector<int8_t> &q, std::vector<float> &s) {
    const int L = int(levels);
    q.assign(size_t(p.N) * p.D, 0);
    s.assign(size_t(p.N) * p.nb, 0.f);
#pragma omp parallel for schedule(static)
    for (int t = 0; t < p.N; ++t)
        for (int b = 0; b < p.nb; ++b) {
            const float *v = p.act.data() + size_t(t) * p.D + b * KB;
            float amax = 0.f;
            for (int j = 0; j < KB; ++j) amax = std::max(amax, std::fabs(v[j]));
            const float sc = amax / levels;
            for (int j = 0; j < KB; ++j) {
                int a = sc > 0.f ? int(std::lround(v[j] / sc)) : 0;
                q[size_t(t) * p.D + b * KB + j] = int8_t(std::max(-L, std::min(L, a)));
            }
            s[size_t(t) * p.nb + b] = sc;
        }
}

static void finish_problem(Problem &p) {
    quantise(p, 127.f, p.q8, p.s8);
    quantise(p, 63.f, p.q7, p.s7);
    quantise(p, 7.f, p.q4, p.s4);
    quantise(p, 3.f, p.q3, p.s3);
}

static Problem real_problem(const std::string &dir, int N, int ff_rows, Source &src) {
    kbatch::Dataset ds = kbatch::load(dir);
    if (N > ds.max_rows())
        throw std::runtime_error("dataset has " + std::to_string(ds.max_rows()) + " rows");
    const int FF = ff_rows > 0 ? ff_rows : ds.FF;
    Problem p{ds.D, FF, N, ds.D / KB, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}};
    std::vector<int8_t> gate, up;
    std::vector<uint16_t> gs, us;
    decode_halo_ternary(ds.gate_host, ds.FF, ds.D, gate, gs);
    decode_halo_ternary(ds.up_host, ds.FF, ds.D, up, us);
    p.gate.assign(gate.begin(), gate.begin() + size_t(FF) * ds.D);
    p.up.assign(up.begin(), up.begin() + size_t(FF) * ds.D);
    p.gs.assign(gs.begin(), gs.begin() + size_t(FF) * p.nb);
    p.us.assign(us.begin(), us.begin() + size_t(FF) * p.nb);
    std::vector<float> x_in, x_ref;
    ds.batch(N, x_in, x_ref);
    p.act = ffn_input_transform(x_in, ds.post_norm_s_host, N, ds.D);
    finish_problem(p);
    src = {"deployed layer weights and real contextual rows", dir, kbsha::sha256_file(dir + "/manifest.json"),
           ds.model, ds.document, ds.document_sha256, ds.tokens_sha256, ds.bonsai_commit, ds.layer};
    return p;
}

static Problem synthetic_problem(int D, int FF, int N, uint64_t seed, Source &src) {
    Problem p = make_problem(D, FF, N, seed);
    src = {"synthetic: random trits, synthetic scales, iid Gaussian activations", "", "", "", "", "", "", "",
           -1};
    return p;
}

// ------------------------------------------------------------------------------------- harness

// The shared interleaved contract: an untimed duration ramp, randomised candidate blocks inside
// repeated rounds, per-switch rewarming, every sample retained with its round, order and host
// timestamps, and a sensor trace recorded alongside. bench/timing.hpp drives candidate objects, so
// each map here is wrapped as one.
int main(int argc, char **argv) {
    std::string mode = "run", dataset = "/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00";
    std::string out_path;
    bool synthetic = false;
    int iters = 80, rounds = 10, warmup = 12, ramp_ms = 2000, ff_rows = 0;
    unsigned seed = 19073;
    std::vector<int> sizes;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        auto next = [&]() { if (i + 1 >= argc) throw std::runtime_error("missing value for " + a); return std::string(argv[++i]); };
        if (a == "check" || a == "run") mode = a;
        else if (a == "--dataset") dataset = next();
        else if (a == "--synthetic") synthetic = true;
        else if (a == "--iters") iters = std::stoi(next());
        else if (a == "--rounds") rounds = std::stoi(next());
        else if (a == "--warmup") warmup = std::stoi(next());
        else if (a == "--ramp-ms") ramp_ms = std::stoi(next());
        else if (a == "--seed") seed = unsigned(std::stoul(next()));
        else if (a == "--ff-rows") ff_rows = std::stoi(next());
        else if (a == "--json") out_path = next();
        else if (a == "--rows") {
            std::string v = next(), t;
            for (char c : v + ",") { if (c == ',') { if (!t.empty()) sizes.push_back(std::stoi(t)); t.clear(); } else t += c; }
        } else throw std::runtime_error("unknown argument " + a);
    }
    const bool check = mode == "check";
    if (sizes.empty()) sizes = check ? std::vector<int>{128} : std::vector<int>{32, 64, 128, 256};
    if (check && ff_rows == 0) ff_rows = 256;       // CPU reference cost, real rows of the real matrix

    hipDeviceProp_t prop{}; HIP_OK(hipGetDeviceProperties(&prop, 0));
    const int Nmax = *std::max_element(sizes.begin(), sizes.end());
    Source src;
    Problem p = synthetic ? synthetic_problem(5120, ff_rows ? ff_rows : 17408, Nmax, 20260927, src)
                          : real_problem(dataset, Nmax, ff_rows, src);
    const int D = p.D, FF = p.FF, nb = p.nb;
    printf("device %s  D=%d FF=%d  (gate+up = %.1f M ternary weights)\n", prop.gcnArchName, D, FF,
           2.0 * D * FF / 1e6);
    printf("problem: %s\n", src.kind.c_str());
    if (!src.dataset.empty())
        printf("  dataset %s  layer %d  manifest %s\n  document %s\n", src.dataset.c_str(), src.layer,
               src.manifest_sha256.substr(0, 16).c_str(), src.document.c_str());
    {
        size_t nz = 0;
        for (int8_t v : p.gate) nz += v != 0;
        printf("  gate nonzero fraction %.4f, first block scales %.6g %.6g\n",
               double(nz) / double(p.gate.size()), double(h2f_host(p.gs[0])), double(h2f_host(p.gs[1])));
    }

    auto g2 = pack_two_bit(p.gate.data(), FF, D), u2 = pack_two_bit(p.up.data(), FF, D);
    auto g4 = pack_nibble(p.gate.data(), FF, D), u4 = pack_nibble(p.up.data(), FF, D);
    auto go = pack_two_bit_off(p.gate.data(), FF, D), uo = pack_two_bit_off(p.up.data(), FF, D);
    auto w7_4 = w_seven<int2v, 4>(p);
    auto w7_8 = w_seven<int4v, 8>(p);
    Dev<uint8_t> dg2(g2.size()); dg2.put(g2);
    Dev<uint8_t> du2(u2.size()); du2.put(u2);
    Dev<uint8_t> dg4(g4.size()); dg4.put(g4);
    Dev<uint8_t> du4(u4.size()); du4.put(u4);
    Dev<uint8_t> dgo(go.size()); dgo.put(go);
    Dev<uint8_t> duo(uo.size()); duo.put(uo);
    Dev<int2v> dw74(w7_4.size()); dw74.put(w7_4);
    Dev<int4v> dw78(w7_8.size()); dw78.put(w7_8);
    Dev<uint16_t> dsg(p.gs.size()); dsg.put(p.gs);
    Dev<uint16_t> dsu(p.us.size()); dsu.put(p.us);

    auto B4_a4 = b_plain<int2v, 4>(p, p.q4);
    auto B4_a3 = b_plain<int2v, 4>(p, p.q3);
    auto B8_a8 = b_plain<int4v, 8>(p, p.q8);
    auto B8_a7 = b_plain<int4v, 8>(p, p.q7);
    auto C4_a3 = b_seven<int2v, 4>(p, p.q3);
    auto C8_a7 = b_seven<int4v, 8>(p, p.q7);
    Dev<int2v> dB4a4(B4_a4.size()); dB4a4.put(B4_a4);
    Dev<int2v> dB4a3(B4_a3.size()); dB4a3.put(B4_a3);
    Dev<int4v> dB8a8(B8_a8.size()); dB8a8.put(B8_a8);
    Dev<int4v> dB8a7(B8_a7.size()); dB8a7.put(B8_a7);
    Dev<int2v> dC4a3(C4_a3.size()); dC4a3.put(C4_a3);
    Dev<int4v> dC8a7(C8_a7.size()); dC8a7.put(C8_a7);
    Dev<float> ds4(p.s4.size()); ds4.put(p.s4);
    Dev<float> ds3(p.s3.size()); ds3.put(p.s3);
    Dev<float> ds8(p.s8.size()); ds8.put(p.s8);
    Dev<float> ds7(p.s7.size()); ds7.put(p.s7);
    auto ce3 = corr_eight(p, p.q3);
    std::vector<int> kg3, ku3; corr_seven(p, p.q3, kg3, ku3);
    Dev<int> dce3(ce3.size()); dce3.put(ce3);
    Dev<int> dkg3(kg3.size()); dkg3.put(kg3);
    Dev<int> dku3(ku3.size()); dku3.put(ku3);
    Dev<float> dog(size_t(Nmax) * FF), dou(size_t(Nmax) * FF);

    const int grid = FF / 16 / NW, gridw = FF / 16;
    const double w2b = 2.0 * g2.size(), w4b = 2.0 * g4.size();
    const double w74b = double(w7_4.size()) * sizeof(int2v), w78b = double(w7_8.size()) * sizeof(int4v);
    printf("weight images gate+up: two-bit %.2f MB, nibble %.2f MB, seven-i4 %.2f MB, seven-i8 %.2f MB\n",
           w2b / 1048576.0, w4b / 1048576.0, w74b / 1048576.0, w78b / 1048576.0);

    // Every launch the probe can make, by name. `s` is the HIP stream the timing contract owns.
    auto L_eight_i4p_a4 = [&](int tt, int N, hipStream_t s) {
        if (tt == 2) k_eight<2, 0><<<grid, NW * 32, 0, s>>>(dg2.p, du2.p, dB4a4.p, dsg.p, dsu.p, ds4.p, nullptr, dog.p, dou.p, nb, N, FF);
        else k_eight<4, 0><<<grid, NW * 32, 0, s>>>(dg2.p, du2.p, dB4a4.p, dsg.p, dsu.p, ds4.p, nullptr, dog.p, dou.p, nb, N, FF);
    };
    auto L_eight_i4o_a3 = [&](int tt, int N, hipStream_t s) {
        if (tt == 2) k_eight<2, 3><<<grid, NW * 32, 0, s>>>(dgo.p, duo.p, dB4a3.p, dsg.p, dsu.p, ds3.p, dce3.p, dog.p, dou.p, nb, N, FF);
        else k_eight<4, 3><<<grid, NW * 32, 0, s>>>(dgo.p, duo.p, dB4a3.p, dsg.p, dsu.p, ds3.p, dce3.p, dog.p, dou.p, nb, N, FF);
    };
    auto L_seven_i4c_a3 = [&](int N, hipStream_t s) {
        k_seven_packed<2><<<grid, NW * 32, 0, s>>>(dgo.p, duo.p, dC4a3.p, dsg.p, dsu.p, ds3.p, dkg3.p, dku3.p, dog.p, dou.p, nb, N, FF);
    };
    auto L_eight_i4o_w = [&](int nwv, int tt, int N, hipStream_t s) {
        if (nwv == 2) k_eight<2, 3, 0, 1, 2><<<gridw, 2 * 32, 0, s>>>(dgo.p, duo.p, dB4a3.p, dsg.p, dsu.p, ds3.p, dce3.p, dog.p, dou.p, nb, N, FF);
        else if (tt == 4) k_eight<4, 3, 0, 1, 4><<<gridw, 4 * 32, 0, s>>>(dgo.p, duo.p, dB4a3.p, dsg.p, dsu.p, ds3.p, dce3.p, dog.p, dou.p, nb, N, FF);
        else k_eight<2, 3, 0, 1, 4><<<gridw, 4 * 32, 0, s>>>(dgo.p, duo.p, dB4a3.p, dsg.p, dsu.p, ds3.p, dce3.p, dog.p, dou.p, nb, N, FF);
    };
    auto L_eight_i4p_w = [&](int nwv, int tt, int N, hipStream_t s) {
        if (nwv == 2) k_eight<2, 0, 0, 1, 2><<<gridw, 2 * 32, 0, s>>>(dg2.p, du2.p, dB4a4.p, dsg.p, dsu.p, ds4.p, nullptr, dog.p, dou.p, nb, N, FF);
        else if (tt == 4) k_eight<4, 0, 0, 1, 4><<<gridw, 4 * 32, 0, s>>>(dg2.p, du2.p, dB4a4.p, dsg.p, dsu.p, ds4.p, nullptr, dog.p, dou.p, nb, N, FF);
        else k_eight<2, 0, 0, 1, 4><<<gridw, 4 * 32, 0, s>>>(dg2.p, du2.p, dB4a4.p, dsg.p, dsu.p, ds4.p, nullptr, dog.p, dou.p, nb, N, FF);
    };
    auto L_seven_i4c_w = [&](int nwv, int N, hipStream_t s) {
        if (nwv == 2) k_seven_packed<2, 1, 2><<<gridw, 2 * 32, 0, s>>>(dgo.p, duo.p, dC4a3.p, dsg.p, dsu.p, ds3.p, dkg3.p, dku3.p, dog.p, dou.p, nb, N, FF);
        else k_seven_packed<2, 1, 4><<<gridw, 4 * 32, 0, s>>>(dgo.p, duo.p, dC4a3.p, dsg.p, dsu.p, ds3.p, dkg3.p, dku3.p, dog.p, dou.p, nb, N, FF);
    };
    auto L_seven_i4_compiled = [&](int N, hipStream_t s) {
        k_seven<2, false><<<grid, NW * 32, 0, s>>>(dw74.p, dC4a3.p, dsg.p, dsu.p, ds3.p, dog.p, dou.p, nb, N, FF);
    };
    auto L_eight_i8_a8 = [&](int tt, int N, hipStream_t s) {
        if (tt == 2) k_eight<2, 2><<<grid, NW * 32, 0, s>>>(dg2.p, du2.p, dB8a8.p, dsg.p, dsu.p, ds8.p, nullptr, dog.p, dou.p, nb, N, FF);
        else k_eight<4, 2><<<grid, NW * 32, 0, s>>>(dg2.p, du2.p, dB8a8.p, dsg.p, dsu.p, ds8.p, nullptr, dog.p, dou.p, nb, N, FF);
    };
    auto L_seven_i8_compiled = [&](int N, hipStream_t s) {
        k_seven<2, true><<<grid, NW * 32, 0, s>>>(dw78.p, dC8a7.p, dsg.p, dsu.p, ds7.p, dog.p, dou.p, nb, N, FF);
    };
    auto L_eight_i4n_a3 = [&](int tt, int N, hipStream_t s) {
        if (tt == 2) k_eight<2, 1><<<grid, NW * 32, 0, s>>>(dg4.p, du4.p, dB4a3.p, dsg.p, dsu.p, ds3.p, nullptr, dog.p, dou.p, nb, N, FF);
        else k_eight<4, 1><<<grid, NW * 32, 0, s>>>(dg4.p, du4.p, dB4a3.p, dsg.p, dsu.p, ds3.p, nullptr, dog.p, dou.p, nb, N, FF);
    };

    if (check) {
        const int N = sizes.front();
        std::vector<double> rf(size_t(N) * FF * 2, 0.0), ri[4];
        const std::vector<int8_t> *qs[4] = {&p.q8, &p.q7, &p.q4, &p.q3};
        const std::vector<float> *ss[4] = {&p.s8, &p.s7, &p.s4, &p.s3};
        for (int c = 0; c < 4; ++c) ri[c].assign(size_t(N) * FF * 2, 0.0);
#pragma omp parallel for schedule(static)
        for (int t = 0; t < N; ++t)
            for (int row = 0; row < FF; ++row)
                for (int b = 0; b < nb; ++b) {
                    const float hg = h2f_host(p.gs[size_t(row) * nb + b]), hu = h2f_host(p.us[size_t(row) * nb + b]);
                    double fg = 0, fu = 0;
                    long ig[4] = {}, iu[4] = {};
                    for (int j = 0; j < KB; ++j) {
                        const int wg = p.gate[size_t(row) * D + b * KB + j], wu = p.up[size_t(row) * D + b * KB + j];
                        const double v = p.act[size_t(t) * D + b * KB + j];
                        fg += wg * v; fu += wu * v;
                        for (int c = 0; c < 4; ++c) {
                            const int a = (*qs[c])[size_t(t) * D + b * KB + j];
                            ig[c] += wg * a; iu[c] += wu * a;
                        }
                    }
                    rf[size_t(t) * FF + row] += fg * double(hg);
                    rf[size_t(N) * FF + size_t(t) * FF + row] += fu * double(hu);
                    for (int c = 0; c < 4; ++c) {
                        const float sc = (*ss[c])[size_t(t) * nb + b];
                        ri[c][size_t(t) * FF + row] += double(float(ig[c]) * (hg * sc));
                        ri[c][size_t(N) * FF + size_t(t) * FF + row] += double(float(iu[c]) * (hu * sc));
                    }
                }
        auto fetch = [&]() {
            std::vector<float> h(size_t(N) * FF * 2);
            HIP_OK(hipMemcpy(h.data(), dog.p, size_t(N) * FF * 4, hipMemcpyDeviceToHost));
            HIP_OK(hipMemcpy(h.data() + size_t(N) * FF, dou.p, size_t(N) * FF * 4, hipMemcpyDeviceToHost));
            return h;
        };
        auto rms = [&](const std::vector<float> &h, const std::vector<double> &r) {
            double num = 0, den = 0;
            for (size_t i = 0; i < h.size(); ++i) { const double d = h[i] - r[i]; num += d * d; den += r[i] * r[i]; }
            return std::sqrt(num / den) * 100.0;
        };
        struct Res { std::string name; std::vector<float> out; int coderef; };
        std::vector<Res> got;
        auto record = [&](const std::string &name, int coderef) {
            HIP_OK(hipDeviceSynchronize()); HIP_OK(hipGetLastError());
            got.push_back({name, fetch(), coderef});
        };
        L_eight_i4p_a4(2, N, nullptr);                  record("eight-i4p/A4", 2);
        L_eight_i4n_a3(2, N, nullptr);                  record("eight-i4n/A3", 3);
        L_eight_i4o_a3(2, N, nullptr);                  record("eight-i4o/A3", 3);
        L_seven_i4_compiled(N, nullptr);                record("seven-i4/A3", 3);
        L_seven_i4c_a3(N, nullptr);                     record("seven-i4c/A3", 3);
        L_seven_i4c_w(2, N, nullptr);                   record("seven-i4c/A3.w2", 3);
        L_seven_i4c_w(4, N, nullptr);                   record("seven-i4c/A3.w4", 3);
        L_eight_i4o_w(2, 2, N, nullptr);                record("eight-i4o/A3.w2", 3);
        L_eight_i4o_w(4, 4, N, nullptr);                record("eight-i4o/A3.w4t4", 3);
        L_eight_i8_a8(2, N, nullptr);                   record("eight-i8/A8", 0);
        L_seven_i8_compiled(N, nullptr);                record("seven-i8/A7", 1);
        {
            L_eight_i8_a8(2, N, nullptr);
            HIP_OK(hipDeviceSynchronize());
            k_eight<2, 2><<<grid, NW * 32>>>(dg2.p, du2.p, dB8a7.p, dsg.p, dsu.p, ds7.p, nullptr, dog.p, dou.p, nb, N, FF);
            record("eight-i8/A7", 1);
        }
        printf("\n%-18s %14s %14s\n", "map", "rel RMS vs f32", "vs own codes");
        for (auto &g : got)
            printf("%-18s %13.4f%% %13.3e\n", g.name.c_str(), rms(g.out, rf), rms(g.out, ri[g.coderef]) / 100.0);
        int failures = 0;
        auto identical = [&](const std::string &a, const std::string &b) {
            const Res *ra = nullptr, *rb = nullptr;
            for (auto &g : got) { if (g.name == a) ra = &g; if (g.name == b) rb = &g; }
            if (!ra || !rb) { printf("missing %s or %s\n", a.c_str(), b.c_str()); ++failures; return; }
            size_t bad = 0; double worst = 0;
            for (size_t i = 0; i < ra->out.size(); ++i) {
                if (ra->out[i] != rb->out[i]) ++bad;
                worst = std::max(worst, std::fabs(double(ra->out[i]) - double(rb->out[i])));
            }
            if (bad) ++failures;
            printf("%-18s vs %-18s  differing outputs %zu of %zu, worst |diff| %.3e\n",
                   a.c_str(), b.c_str(), bad, ra->out.size(), worst);
        };
        identical("seven-i4/A3", "eight-i4n/A3");
        identical("seven-i4c/A3", "eight-i4n/A3");
        identical("seven-i4c/A3.w2", "eight-i4n/A3");
        identical("seven-i4c/A3.w4", "eight-i4n/A3");
        identical("eight-i4o/A3", "eight-i4n/A3");
        identical("eight-i4o/A3.w2", "eight-i4n/A3");
        identical("eight-i4o/A3.w4t4", "eight-i4n/A3");
        identical("seven-i8/A7", "eight-i8/A7");
        printf("%s\n", failures ? "CHECK FAILED" : "check passed");
        return failures ? 1 : 0;
    }

    // ------------------------------------------------------------------------------ timed run
    // bench/probe_measure.hpp owns the schedule, the sensor trace and the source/executable
    // fingerprints; every case here computes the same projection, so work_per_call is equal.
    for (int N : sizes) {
        std::vector<kbprobe::Case> cases;
        auto add = [&](const std::string &name, std::function<void(hipStream_t)> fn) {
            cases.push_back({name, (unsigned long long)(2.0 * D * FF * N), std::move(fn)});
        };
        add("eight-i4p-a4-t2", [&](hipStream_t s) { L_eight_i4p_a4(2, N, s); });
        add("eight-i4o-a3-t2", [&](hipStream_t s) { L_eight_i4o_a3(2, N, s); });
        add("seven-i4c-a3-t2", [&](hipStream_t s) { L_seven_i4c_a3(N, s); });
        add("eight-i4n-a3-t2", [&](hipStream_t s) { L_eight_i4n_a3(2, N, s); });
        // Control for the "more independent accumulator chains" explanation: eight products split
        // by k-parity into eight chains, the register class the seven products use, same tiling.
        add("eight-i4os-a3-t2", [&](hipStream_t s) {
            k_eight<2, 3, 1><<<grid, NW * 32, 0, s>>>(dgo.p, duo.p, dB4a3.p, dsg.p, dsu.p, ds3.p, dce3.p, dog.p, dou.p, nb, N, FF); });
        add("seven-i4-compiled-a3", [&](hipStream_t s) { L_seven_i4_compiled(N, s); });
        add("eight-i8-a8-t2", [&](hipStream_t s) { L_eight_i8_a8(2, N, s); });
        add("seven-i8-compiled-a7", [&](hipStream_t s) { L_seven_i8_compiled(N, s); });
        if (N >= 64) {
            add("eight-i4p-a4-t4", [&](hipStream_t s) { L_eight_i4p_a4(4, N, s); });
            add("eight-i4o-a3-t4", [&](hipStream_t s) { L_eight_i4o_a3(4, N, s); });
            add("eight-i4o-a3-w2", [&](hipStream_t s) { L_eight_i4o_w(2, 2, N, s); });
            add("eight-i4p-a4-w2", [&](hipStream_t s) { L_eight_i4p_w(2, 2, N, s); });
            add("seven-i4c-a3-w2", [&](hipStream_t s) { L_seven_i4c_w(2, N, s); });
        }
        if (N >= 128) {
            add("eight-i4o-a3-w4t4", [&](hipStream_t s) { L_eight_i4o_w(4, 4, N, s); });
            add("eight-i4p-a4-w4t4", [&](hipStream_t s) { L_eight_i4p_w(4, 4, N, s); });
            add("seven-i4c-a3-w4", [&](hipStream_t s) { L_seven_i4c_w(4, N, s); });
        }

        // Correctness is a separate recorded experiment; print the output hash of every case here
        // so a timed run also shows which maps agree at this size.
        printf("\n%d rows: output hashes\n", N);
        std::vector<float> out(size_t(N) * FF * 2);
        for (auto &c : cases) {
            c.launch(nullptr);
            HIP_OK(hipDeviceSynchronize()); HIP_OK(hipGetLastError());
            HIP_OK(hipMemcpy(out.data(), dog.p, size_t(N) * FF * 4, hipMemcpyDeviceToHost));
            HIP_OK(hipMemcpy(out.data() + size_t(N) * FF, dou.p, size_t(N) * FF * 4, hipMemcpyDeviceToHost));
            printf("  %-22s %s\n", c.name.c_str(), kbsha::sha256_hex(out.data(), out.size() * 4).substr(0, 16).c_str());
        }

        kbprobe::Config cfg;
        cfg.rows = N;
        cfg.iterations = iters;
        cfg.rounds = rounds;
        cfg.warmup = warmup;
        cfg.ramp_ms = ramp_ms;
        cfg.seed = seed + unsigned(N);
        cfg.work_unit = "MAC";
        cfg.scope = "Gate and up projection only, weights streamed every pass. Activation fragments, "
                    "the seven activation operands and the rank-one corrections are built on the host "
                    "outside timing, as in the other component probes; a whole-FFN candidate would pay "
                    "them in its producer. Seven-product and eight-product cases at the same activation "
                    "width produce bit-identical outputs.";
        cfg.input_description = src.kind + (src.dataset.empty() ? std::string() :
            "; dataset " + src.dataset + ", layer " + std::to_string(src.layer) +
            ", manifest sha256 " + src.manifest_sha256 + ", tokens sha256 " + src.tokens_sha256);
        cfg.source_files = {"seven_probe.hip", "../arithmetic/maps.hpp", "../bench/probe_measure.hpp"};
        const std::string j = kbprobe::measure(cases, cfg);
        if (!out_path.empty()) {
            std::string path = out_path;
            const size_t dot = path.rfind(".json");
            if (sizes.size() > 1 && dot != std::string::npos)
                path = path.substr(0, dot) + "-" + std::to_string(N) + ".json";
            FILE *f = fopen(path.c_str(), "wb");
            if (!f) throw std::runtime_error("cannot write " + path);
            fwrite(j.data(), 1, j.size(), f);
            fclose(f);
            printf("wrote %s\n", path.c_str());
        }
    }
    return 0;
}
