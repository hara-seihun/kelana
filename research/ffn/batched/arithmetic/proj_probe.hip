// Batched gate/up projection: five arithmetic maps on the real FFN shape, weights streamed.
//
// Question: at 16-256 real tokens, does pairing two ternary rows into one FP16 coefficient buy
// throughput that a native integer instruction does not already give?
//
// Every kernel computes the same logical result for N tokens: gate[FF][D] and up[FF][D] ternary,
// FP16 scale per (row, 128-block), FP32 scale per (token, 128-block), FP32 output [N][FF].
// A wave owns 16 hidden units and TT token tiles of 16; weights stream from memory every pass.
//
//   paired1  4-bit activations, one digit plane, one FP16 WMMA per K16 slice per 32 logical rows
//   paired2  8-bit activations, two digit planes, two FP16 WMMA, same 32 logical rows
//   iu8      8-bit activations, two IU8 WMMA per K16 slice for gate and up
//   iu4n     4-bit activations, two IU4 WMMA, four-bit weight storage
//   iu4p     4-bit activations, two IU4 WMMA, two-bit weight storage expanded in registers
#include "maps.hpp"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>
#include <algorithm>
#include <random>

using namespace kelana_arith;

#define HIP_OK(c) do { hipError_t e_ = (c); if (e_ != hipSuccess) { \
    printf("HIP error %s at line %d\n", hipGetErrorString(e_), __LINE__); exit(1);} } while (0)

// --------------------------------------------------------------------------------- device kernels

// Common geometry: blockIdx.x indexes a group of NW row tiles; wave w owns row tile
// blockIdx.x*NW + w, i.e. hidden units [tile*16, tile*16+16). Token group loop is outermost so a
// wave's weight stream stays hot in cache across groups.
constexpr int NW = 4;

__device__ __forceinline__ float h2f(unsigned bits) {
    unsigned short u = (unsigned short)bits; _Float16 h;
    __builtin_memcpy(&h, &u, 2); return (float)h;
}

template <int TT>
__global__ __launch_bounds__(NW * 32) void k_paired1(
        const uint8_t *__restrict__ W, const half16 *__restrict__ B,
        const float *__restrict__ cscale, float *__restrict__ og, float *__restrict__ ou,
        int nb, int N, int FF) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const uint8_t *wbase = W + size_t(tile) * nb * PAIR_BLOCK_BYTES;
    for (int tg = 0; tg < N; tg += TT * 16) {
        float8 acc[TT];
        float yg[TT][8], yu[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { yg[t][r] = 0.f; yu[t][r] = 0.f; }
        for (int b = 0; b < nb; ++b) {
            const uint8_t *wb = wbase + size_t(b) * PAIR_BLOCK_BYTES;
            unsigned sc = *(const unsigned *)(wb + PAIR_CODES_BYTES + col * 4);
            float gsl = h2f(sc & 0xffffu), usl = h2f(sc >> 16), gsr[8], usr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { gsr[r] = __shfl(gsl, 2 * r + half, 32); usr[r] = __shfl(usl, 2 * r + half, 32); }
#pragma unroll
            for (int t = 0; t < TT; ++t) acc[t] = float8{};
#pragma unroll 1
            for (int s = 0; s < SLICES; ++s) {
                half16 a = decode_paired(*(const uint2 *)(wb + s * 128 + col * 8));
#pragma unroll
                for (int t = 0; t < TT; ++t)
                    acc[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(
                        a, B[size_t(b * SLICES + s) * N + tg + t * 16 + col], acc[t]);
            }
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                float cs = cscale[size_t(tg + t * 16 + col) * nb + b];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    float g, u; unpair(acc[t][r], g, u);
                    yg[t][r] = __builtin_fmaf(g, gsr[r] * cs, yg[t][r]);
                    yu[t][r] = __builtin_fmaf(u, usr[r] * cs, yu[t][r]);
                }
            }
        }
        // D element r of lane l is row 2r + l/16, column l%16: rows are the hidden units, columns
        // the tokens, so the store transposes into [token][hidden].
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                size_t o = size_t(tg + t * 16 + col) * FF + tile * 16 + 2 * r + half;
                og[o] = yg[t][r]; ou[o] = yu[t][r];
            }
    }
}

template <int TT>
__global__ __launch_bounds__(NW * 32) void k_paired2(
        const uint8_t *__restrict__ W, const half16 *__restrict__ Blo, const half16 *__restrict__ Bhi,
        const float *__restrict__ cscale, float *__restrict__ og, float *__restrict__ ou,
        int nb, int N, int FF) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const uint8_t *wbase = W + size_t(tile) * nb * PAIR_BLOCK_BYTES;
    for (int tg = 0; tg < N; tg += TT * 16) {
        float8 lo[TT], hi[TT];
        float yg[TT][8], yu[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { yg[t][r] = 0.f; yu[t][r] = 0.f; }
        for (int b = 0; b < nb; ++b) {
            const uint8_t *wb = wbase + size_t(b) * PAIR_BLOCK_BYTES;
            unsigned sc = *(const unsigned *)(wb + PAIR_CODES_BYTES + col * 4);
            float gsl = h2f(sc & 0xffffu), usl = h2f(sc >> 16), gsr[8], usr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { gsr[r] = __shfl(gsl, 2 * r + half, 32); usr[r] = __shfl(usl, 2 * r + half, 32); }
#pragma unroll
            for (int t = 0; t < TT; ++t) { lo[t] = float8{}; hi[t] = float8{}; }
#pragma unroll 1
            for (int s = 0; s < SLICES; ++s) {
                half16 a = decode_paired(*(const uint2 *)(wb + s * 128 + col * 8));
#pragma unroll
                for (int t = 0; t < TT; ++t) {
                    size_t bi = size_t(b * SLICES + s) * N + tg + t * 16 + col;
                    lo[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, Blo[bi], lo[t]);
                    hi[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, Bhi[bi], hi[t]);
                }
            }
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                float cs = cscale[size_t(tg + t * 16 + col) * nb + b];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    float g0, u0, g1, u1;
                    unpair(lo[t][r], g0, u0);
                    unpair(hi[t][r], g1, u1);
                    yg[t][r] = __builtin_fmaf(__builtin_fmaf(16.f, g1, g0), gsr[r] * cs, yg[t][r]);
                    yu[t][r] = __builtin_fmaf(__builtin_fmaf(16.f, u1, u0), usr[r] * cs, yu[t][r]);
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

// Native integer maps. MODE 0: IU8 with 8-bit activations, two-bit weight storage expanded to
// bytes. MODE 1: IU4, four-bit weight storage, no expansion. MODE 2: IU4, two-bit storage expanded
// to nibbles.
template <int TT, int MODE>
__global__ __launch_bounds__(NW * 32) void k_native(
        const uint8_t *__restrict__ Wg, const uint8_t *__restrict__ Wu, const void *__restrict__ Bv,
        const uint16_t *__restrict__ sg, const uint16_t *__restrict__ su,
        const float *__restrict__ cscale, float *__restrict__ og, float *__restrict__ ou,
        int nb, int N, int FF) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    constexpr int WBYTES = MODE == 1 ? 1024 : 512;
    const uint8_t *gbase = Wg + size_t(tile) * nb * WBYTES;
    const uint8_t *ubase = Wu + size_t(tile) * nb * WBYTES;
    for (int tg = 0; tg < N; tg += TT * 16) {
        int8v ag[TT], au[TT];
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
            for (int t = 0; t < TT; ++t) { ag[t] = int8v{}; au[t] = int8v{}; }
#pragma unroll 1
            for (int s = 0; s < SLICES; ++s) {
                if constexpr (MODE == 0) {
                    int4v wg = expand_i8(*(const unsigned *)(gb + s * 64 + col * 4));
                    int4v wu = expand_i8(*(const unsigned *)(ub + s * 64 + col * 4));
#pragma unroll
                    for (int t = 0; t < TT; ++t) {
                        int4v bfrag = ((const int4v *)Bv)[size_t(b * SLICES + s) * N + tg + t * 16 + col];
                        ag[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wg, true, bfrag, ag[t], false);
                        au[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wu, true, bfrag, au[t], false);
                    }
                } else {
                    int2v wg, wu;
                    if constexpr (MODE == 1) {
                        wg = *(const int2v *)(gb + s * 128 + col * 8);
                        wu = *(const int2v *)(ub + s * 128 + col * 8);
                    } else {
                        wg = expand_i4(*(const unsigned *)(gb + s * 64 + col * 4));
                        wu = expand_i4(*(const unsigned *)(ub + s * 64 + col * 4));
                    }
#pragma unroll
                    for (int t = 0; t < TT; ++t) {
                        int2v bfrag = ((const int2v *)Bv)[size_t(b * SLICES + s) * N + tg + t * 16 + col];
                        ag[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wg, true, bfrag, ag[t], false);
                        au[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wu, true, bfrag, au[t], false);
                    }
                }
            }
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                float cs = cscale[size_t(tg + t * 16 + col) * nb + b];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    yg[t][r] = __builtin_fmaf(float(ag[t][r]), gsr[r] * cs, yg[t][r]);
                    yu[t][r] = __builtin_fmaf(float(au[t][r]), usr[r] * cs, yu[t][r]);
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

// ------------------------------------------------------------------------------------ host driver

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
    std::vector<int8_t> gate, up;                 // ternary [FF][D]
    std::vector<uint16_t> gs, us;                 // FP16 scales [FF][nb]
    std::vector<int8_t> q;                        // int8 activations [N][D]
    std::vector<int8_t> q4;                       // 4-bit activations [N][D], values in [-8,7]
    std::vector<float> cscale;                    // [N][nb], 8-bit activation scale
    std::vector<float> cscale4;                   // [N][nb], 4-bit activation scale
};

// Deterministic symmetric 4-bit activation quantizer, per (token, 128-block): scale by the block
// maximum to 7 levels, round half away from zero, clamp to [-7,7]. The paired map additionally
// needs |sum of gate weight * digit| <= 1023, which 127 nonzeros x 7 satisfies with margin.
static Problem make_problem(int D, int FF, int N, uint64_t seed) {
    Problem p{D, FF, N, D / KB, {}, {}, {}, {}, {}, {}, {}};
    std::mt19937_64 rng(seed);
    p.gate.assign(size_t(FF) * D, 0); p.up.assign(size_t(FF) * D, 0);
    p.gs.assign(size_t(FF) * p.nb, 0); p.us.assign(size_t(FF) * p.nb, 0);
    // Ternary weights with at most 127 nonzeros per 128-block, matching the paired map's contract.
    for (size_t i = 0; i < p.gate.size(); ++i) {
        int r = int(rng() % 3) - 1;
        p.gate[i] = int8_t(r);
        p.up[i] = int8_t(int(rng() % 3) - 1);
    }
    for (int row = 0; row < FF; ++row)
        for (int b = 0; b < p.nb; ++b) {
            for (auto *w : {&p.gate, &p.up}) {
                int8_t *s = w->data() + size_t(row) * D + b * KB;
                int nz = 0; for (int j = 0; j < KB; ++j) nz += s[j] != 0;
                for (int j = 0; nz > 127 && j < KB; ++j) if (s[j]) { s[j] = 0; --nz; }
            }
            float g = 0.0035f + 0.001f * float(rng() % 100) / 100.f;
            _Float16 hg = (_Float16)g, hu = (_Float16)(g * 1.1f);
            std::memcpy(&p.gs[size_t(row) * p.nb + b], &hg, 2);
            std::memcpy(&p.us[size_t(row) * p.nb + b], &hu, 2);
        }
    p.q.assign(size_t(N) * D, 0); p.q4.assign(size_t(N) * D, 0);
    p.cscale.assign(size_t(N) * p.nb, 0.f);
    p.cscale4.assign(size_t(N) * p.nb, 0.f);
    std::normal_distribution<float> gauss(0.f, 1.f);
    for (int t = 0; t < N; ++t)
        for (int b = 0; b < p.nb; ++b) {
            float v[KB], amax = 0.f;
            for (int j = 0; j < KB; ++j) { v[j] = gauss(rng); amax = std::max(amax, std::fabs(v[j])); }
            float s8 = amax / 127.f, s4 = amax / 7.f;
            for (int j = 0; j < KB; ++j) {
                int a = int(std::lround(v[j] / s8));
                p.q[size_t(t) * D + b * KB + j] = int8_t(std::max(-127, std::min(127, a)));
                int c = int(std::lround(v[j] / s4));
                p.q4[size_t(t) * D + b * KB + j] = int8_t(std::max(-7, std::min(7, c)));
            }
            p.cscale[size_t(t) * p.nb + b] = s8;
            p.cscale4[size_t(t) * p.nb + b] = s4;
        }
    return p;
}

// B fragments: lane l supplies matrix column l%16, so one fragment is the 16 K values of one token.
static std::vector<half16> b_planes(const Problem &p, bool high) {
    std::vector<half16> out(size_t(p.nb * SLICES) * p.N);
    for (int t = 0; t < p.N; ++t)
        for (int k = 0; k < p.nb * SLICES; ++k) {
            half16 f{};
            for (int j = 0; j < 16; ++j) {
                int q = p.q[size_t(t) * p.D + k * 16 + j];
                int lo = ((q + 8) & 15) - 8;
                f[j] = (_Float16)(high ? (q - lo) >> 4 : lo);
            }
            out[size_t(k) * p.N + t] = f;
        }
    return out;
}
static std::vector<half16> b_single(const Problem &p) {
    std::vector<half16> out(size_t(p.nb * SLICES) * p.N);
    for (int t = 0; t < p.N; ++t)
        for (int k = 0; k < p.nb * SLICES; ++k) {
            half16 f{};
            for (int j = 0; j < 16; ++j) f[j] = (_Float16)p.q4[size_t(t) * p.D + k * 16 + j];
            out[size_t(k) * p.N + t] = f;
        }
    return out;
}
static std::vector<int4v> b_iu8(const Problem &p) {
    std::vector<int4v> out(size_t(p.nb * SLICES) * p.N);
    for (int t = 0; t < p.N; ++t)
        for (int k = 0; k < p.nb * SLICES; ++k) {
            int8_t bytes[16];
            for (int j = 0; j < 16; ++j) bytes[j] = p.q[size_t(t) * p.D + k * 16 + j];
            int4v f; std::memcpy(&f, bytes, 16);
            out[size_t(k) * p.N + t] = f;
        }
    return out;
}
static std::vector<int2v> b_iu4(const Problem &p) {
    std::vector<int2v> out(size_t(p.nb * SLICES) * p.N);
    for (int t = 0; t < p.N; ++t)
        for (int k = 0; k < p.nb * SLICES; ++k) {
            uint8_t nib[8] = {};
            for (int j = 0; j < 16; ++j) nib[j / 2] |= uint8_t(p.q4[size_t(t) * p.D + k * 16 + j] & 0xf) << (4 * (j & 1));
            int2v f; std::memcpy(&f, nib, 8);
            out[size_t(k) * p.N + t] = f;
        }
    return out;
}

struct Timing { float ms; };
template <class F> static float best_ms(F launch, int iters) {
    launch(); HIP_OK(hipDeviceSynchronize());
    float best = 1e30f;
    for (int r = 0; r < iters; ++r) {
        hipEvent_t a, b; HIP_OK(hipEventCreate(&a)); HIP_OK(hipEventCreate(&b));
        HIP_OK(hipEventRecord(a)); launch(); HIP_OK(hipEventRecord(b));
        HIP_OK(hipEventSynchronize(b));
        float ms = 0; HIP_OK(hipEventElapsedTime(&ms, a, b));
        best = std::min(best, ms);
        HIP_OK(hipEventDestroy(a)); HIP_OK(hipEventDestroy(b));
    }
    return best;
}

int main(int argc, char **argv) {
    int D = 5120, FF = 17408, iters = 20;
    bool check = argc > 1 && std::string(argv[1]) == "check";
    if (check) { D = 1024; FF = 128; }
    std::vector<int> sizes = check ? std::vector<int>{32} : std::vector<int>{16, 32, 64, 128, 256};
    if (argc > 2) iters = atoi(argv[2]);
    hipDeviceProp_t prop{}; HIP_OK(hipGetDeviceProperties(&prop, 0));
    printf("device %s  D=%d FF=%d  (gate+up = %.1f M ternary weights)\n", prop.gcnArchName, D, FF,
           2.0 * D * FF / 1e6);

    int Nmax = *std::max_element(sizes.begin(), sizes.end());
    Problem p = make_problem(D, FF, Nmax, 20260920);
    int nb = p.nb;

    auto paired = pack_paired(p.gate.data(), p.up.data(), p.gs.data(), p.us.data(), FF, D);
    auto g2 = pack_two_bit(p.gate.data(), FF, D), u2 = pack_two_bit(p.up.data(), FF, D);
    auto g4 = pack_nibble(p.gate.data(), FF, D), u4 = pack_nibble(p.up.data(), FF, D);
    Dev<uint8_t> dpaired(paired.size()); dpaired.put(paired);
    Dev<uint8_t> dg2(g2.size()); dg2.put(g2);
    Dev<uint8_t> du2(u2.size()); du2.put(u2);
    Dev<uint8_t> dg4(g4.size()); dg4.put(g4);
    Dev<uint8_t> du4(u4.size()); du4.put(u4);
    Dev<uint16_t> dsg(p.gs.size()); dsg.put(p.gs);
    Dev<uint16_t> dsu(p.us.size()); dsu.put(p.us);
    Dev<float> dcs(p.cscale.size()); dcs.put(p.cscale);
    Dev<float> dcs4(p.cscale4.size()); dcs4.put(p.cscale4);
    auto h1 = b_single(p), hlo = b_planes(p, false), hhi = b_planes(p, true);
    auto h8 = b_iu8(p);
    auto h4 = b_iu4(p);
    Dev<half16> dB1(h1.size()); dB1.put(h1);
    Dev<half16> dBlo(hlo.size()); dBlo.put(hlo);
    Dev<half16> dBhi(hhi.size()); dBhi.put(hhi);
    Dev<int4v> dB8(h8.size()); dB8.put(h8);
    Dev<int2v> dB4(h4.size()); dB4.put(h4);
    Dev<float> dog(size_t(Nmax) * FF), dou(size_t(Nmax) * FF);

    const int grid = FF / 16 / NW;
    printf("weight bytes gate+up: paired %.2f MB, two-bit %.2f MB, nibble %.2f MB\n",
           paired.size() / 1048576.0, 2.0 * g2.size() / 1048576.0, 2.0 * g4.size() / 1048576.0);

    if (check) {
        int N = 32;
        std::vector<float> ref_g(size_t(N) * FF), ref_u(size_t(N) * FF);
        std::vector<float> ref_g4(size_t(N) * FF), ref_u4(size_t(N) * FF);
        for (int t = 0; t < N; ++t)
            for (int row = 0; row < FF; ++row) {
                double a8g = 0, a8u = 0, a4g = 0, a4u = 0;
                for (int b = 0; b < nb; ++b) {
                    long sg8 = 0, su8 = 0, sg4 = 0, su4 = 0;
                    for (int j = 0; j < KB; ++j) {
                        int wg = p.gate[size_t(row) * D + b * KB + j], wu = p.up[size_t(row) * D + b * KB + j];
                        sg8 += wg * p.q[size_t(t) * D + b * KB + j];
                        su8 += wu * p.q[size_t(t) * D + b * KB + j];
                        sg4 += wg * p.q4[size_t(t) * D + b * KB + j];
                        su4 += wu * p.q4[size_t(t) * D + b * KB + j];
                    }
                    _Float16 hg, hu; std::memcpy(&hg, &p.gs[size_t(row) * nb + b], 2);
                    std::memcpy(&hu, &p.us[size_t(row) * nb + b], 2);
                    float cs = p.cscale[size_t(t) * nb + b], cs4 = p.cscale4[size_t(t) * nb + b];
                    a8g += double(float(sg8) * (float(hg) * cs)); a8u += double(float(su8) * (float(hu) * cs));
                    a4g += double(float(sg4) * (float(hg) * cs4)); a4u += double(float(su4) * (float(hu) * cs4));
                }
                ref_g[size_t(t) * FF + row] = float(a8g); ref_u[size_t(t) * FF + row] = float(a8u);
                ref_g4[size_t(t) * FF + row] = float(a4g); ref_u4[size_t(t) * FF + row] = float(a4u);
            }
        auto verify = [&](const char *name, const std::vector<float> &rg, const std::vector<float> &ru) {
            std::vector<float> hg(size_t(N) * FF), hu(size_t(N) * FF);
            HIP_OK(hipMemcpy(hg.data(), dog.p, hg.size() * 4, hipMemcpyDeviceToHost));
            HIP_OK(hipMemcpy(hu.data(), dou.p, hu.size() * 4, hipMemcpyDeviceToHost));
            double worst = 0; int bad = 0;
            for (size_t i = 0; i < hg.size(); ++i) {
                double dg = std::fabs(hg[i] - rg[i]), du = std::fabs(hu[i] - ru[i]);
                double sc = std::max(1e-6, double(std::max(std::fabs(rg[i]), std::fabs(ru[i]))));
                worst = std::max(worst, std::max(dg, du) / sc);
                if (std::max(dg, du) / sc > 1e-4) ++bad;
            }
            printf("  %-8s worst relative deviation %.3e, %d of %zu outside 1e-4\n", name, worst, bad, hg.size());
        };
        k_paired1<2><<<grid, NW * 32>>>(dpaired.p, dB1.p, dcs4.p, dog.p, dou.p, nb, N, FF);
        HIP_OK(hipDeviceSynchronize()); verify("paired1", ref_g4, ref_u4);
        k_paired2<2><<<grid, NW * 32>>>(dpaired.p, dBlo.p, dBhi.p, dcs.p, dog.p, dou.p, nb, N, FF);
        HIP_OK(hipDeviceSynchronize()); verify("paired2", ref_g, ref_u);
        k_native<2, 0><<<grid, NW * 32>>>(dg2.p, du2.p, dB8.p, dsg.p, dsu.p, dcs.p, dog.p, dou.p, nb, N, FF);
        HIP_OK(hipDeviceSynchronize()); verify("iu8", ref_g, ref_u);
        k_native<2, 1><<<grid, NW * 32>>>(dg4.p, du4.p, dB4.p, dsg.p, dsu.p, dcs4.p, dog.p, dou.p, nb, N, FF);
        HIP_OK(hipDeviceSynchronize()); verify("iu4n", ref_g4, ref_u4);
        k_native<2, 2><<<grid, NW * 32>>>(dg2.p, du2.p, dB4.p, dsg.p, dsu.p, dcs4.p, dog.p, dou.p, nb, N, FF);
        HIP_OK(hipDeviceSynchronize()); verify("iu4p", ref_g4, ref_u4);
        return 0;
    }

    printf("\n%-6s %-8s %10s %10s %12s %10s\n", "tokens", "map", "ms", "us/token", "TMAC/s", "GB/s");
    for (int N : sizes) {
        double macs = 2.0 * double(D) * FF * N;
        auto row = [&](const char *name, float ms, double wbytes) {
            printf("%-6d %-8s %10.4f %10.3f %12.2f %10.1f\n", N, name, ms, ms * 1e3 / N,
                   macs / (ms * 1e-3) / 1e12, wbytes / (ms * 1e-3) / 1e9);
        };
        double wp = double(paired.size()), w2 = 2.0 * g2.size(), w4 = 2.0 * g4.size();
#define RUN_TT(KERNEL_CALL)                                                        \
        (N == 16 ? best_ms([&] { constexpr int TT = 1; KERNEL_CALL; }, iters)      \
       : N == 32 ? best_ms([&] { constexpr int TT = 2; KERNEL_CALL; }, iters)      \
                 : best_ms([&] { constexpr int TT = 4; KERNEL_CALL; }, iters))
        row("paired1", RUN_TT((k_paired1<TT><<<grid, NW * 32>>>(dpaired.p, dB1.p, dcs4.p, dog.p, dou.p, nb, N, FF))), wp);
        row("paired2", RUN_TT((k_paired2<TT><<<grid, NW * 32>>>(dpaired.p, dBlo.p, dBhi.p, dcs.p, dog.p, dou.p, nb, N, FF))), wp);
        row("iu8", RUN_TT((k_native<TT, 0><<<grid, NW * 32>>>(dg2.p, du2.p, dB8.p, dsg.p, dsu.p, dcs.p, dog.p, dou.p, nb, N, FF))), w2);
        row("iu4n", RUN_TT((k_native<TT, 1><<<grid, NW * 32>>>(dg4.p, du4.p, dB4.p, dsg.p, dsu.p, dcs4.p, dog.p, dou.p, nb, N, FF))), w4);
        row("iu4p", RUN_TT((k_native<TT, 2><<<grid, NW * 32>>>(dg2.p, du2.p, dB4.p, dsg.p, dsu.p, dcs4.p, dog.p, dou.p, nb, N, FF))), w2);
#undef RUN_TT
    }
    return 0;
}
