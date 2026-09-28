// Does the deferred carrier separate exactly on this hardware?
//
// Two things can break the separation as the run gets longer, and neither is settled by counting:
//
//   wrap    |S_low| must stay <= 1023. Only the low channel needs a bound: u = rint(p/2047) and
//           g = p - 2047u recover any integer u once |g| <= R/2, so a large high channel is not a
//           wrap. This probe reports the realised maxima of both channels anyway.
//   float   V_WMMA_F32_16X16X16_F16 is not bit-exact on exactly representable integer operands:
//           ../../packed-wmma/NOTES.md measured up to 0.043 absolute deviation at |p| = 802,528
//           with no proved bound. Deferring raises |p|, so the deviation has to be measured again
//           at each deferral length rather than assumed.
//
// The reference is the same product accumulated by V_WMMA_I32_16X16X16_IU4 over the same operands,
// which is exact integer arithmetic. Every (row, token, deferred run) of the chosen rows is checked.
//
// Build and run:
//   hipcc --offload-arch=gfx1151 -O3 -std=c++17 -I /path/to/workspace/projects/bonsai-halo/src \
//         defer_probe.hip -o build/defer_probe
//   ../hardware-run ./build/defer_probe /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
//         [rows] [tokens] > results/defer-probe-layer0.txt
#include <hip/hip_runtime.h>
#include "halo_format.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <string>
#include <vector>

using half16 = _Float16 __attribute__((ext_vector_type(16)));
using uint8v = unsigned __attribute__((ext_vector_type(8)));
using int8v = int __attribute__((ext_vector_type(8)));
using int2v = int __attribute__((ext_vector_type(2)));
using float8 = float __attribute__((ext_vector_type(8)));

#define CK(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) { \
    std::fprintf(stderr, "%s: %s\n", #x, hipGetErrorString(e_)); std::exit(1); } } while (0)

static const uint16_t PAIR_HALF[9] = {0xe800, 0xe7ff, 0xe7fe, 0xbc00, 0x3c00, 0x67fe, 0x67ff, 0x6800, 0x0000};
static inline uint8_t pair_code(int g, int u) { int i = (u + 1) * 3 + g + 1; return i == 4 ? 12 : i - (i > 4); }

__device__ __forceinline__ unsigned byte_selectors(unsigned x) {
    x = (x | (x << 8)) & 0x00ff00ffu;
    return (x | (x << 4)) & 0x0f0f0f0fu;
}
__device__ __forceinline__ uint2 decode_four(unsigned codes) {
    unsigned s = byte_selectors(codes & 0xffffu);
    unsigned lo = __builtin_amdgcn_perm(0x00fffe00u, 0x00feff00u, s);
    unsigned hi = __builtin_amdgcn_perm(0x6867673cu, 0xbce7e7e8u, s);
    return make_uint2(__builtin_amdgcn_perm(hi, lo, 0x05010400u),
                      __builtin_amdgcn_perm(hi, lo, 0x07030602u));
}
__device__ __forceinline__ half16 decode_paired(uint2 codes) {
    uint2 a = decode_four(codes.x), b = decode_four(codes.x >> 16);
    uint2 c = decode_four(codes.y), d = decode_four(codes.y >> 16);
    uint8v r = {a.x, a.y, b.x, b.y, c.x, c.y, d.x, d.y};
    return __builtin_bit_cast(half16, r);
}

// The shipped decoder, unchanged.
__device__ __forceinline__ void unpair(float p, float &g, float &u) {
    u = __builtin_rintf(p * (1.0f / 2047.0f));
    g = __builtin_rintf(__builtin_fmaf(-2047.0f, u, p));
}

struct Counters {
    unsigned long long checked;
    unsigned long long decode_mismatch;   // decoded pair != exact integer pair
    unsigned long long wrap;              // |S_low| > 1023, the only algebraic failure
    unsigned max_dev_bits;                // max |p - exact| as float bits
    unsigned max_abs_p_bits;
    int max_low, max_high;
};

__device__ void amax_u(unsigned *slot, unsigned v) { atomicMax(slot, v); }

// One wave per (row tile of 16, token tile of 16). SL = 16-wide K slices in one deferred run.
template <int SL>
__global__ __launch_bounds__(32) void k_probe(const uint8_t *__restrict__ Apair,
        const uint8_t *__restrict__ Ag, const uint8_t *__restrict__ Au,
        const void *__restrict__ Bf, const void *__restrict__ Bi,
        int nslices, int ntok16, Counters *c) {
    const int lane = threadIdx.x, col = lane & 15, half = lane >> 4;
    const int tile = blockIdx.x, tt = blockIdx.y;
    const uint8_t *ap = Apair + size_t(tile) * nslices * 128 + col * 8;
    const uint8_t *ag = Ag + size_t(tile) * nslices * 128 + col * 8;
    const uint8_t *au = Au + size_t(tile) * nslices * 128 + col * 8;
    for (int k0 = 0; k0 + SL <= nslices; k0 += SL) {
        float8 accf = float8{};
        int8v accg = int8v{}, accu = int8v{};
#pragma unroll 1
        for (int q = 0; q < SL; ++q) {
            const size_t k = size_t(k0 + q);
            half16 a = decode_paired(*(const uint2 *) (ap + k * 128));
            accf = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(
                a, ((const half16 *) Bf)[k * ntok16 * 16 + tt * 16 + col], accf);
            int2v wg = *(const int2v *) (ag + k * 128);
            int2v wu = *(const int2v *) (au + k * 128);
            int2v bi = ((const int2v *) Bi)[k * ntok16 * 16 + tt * 16 + col];
            accg = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wg, true, bi, accg, false);
            accu = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wu, true, bi, accu, false);
        }
#pragma unroll
        for (int r = 0; r < 8; ++r) {
            const int lo = accg[r], hi = accu[r];
            const double exact = double(lo) + 2047.0 * double(hi);
            float g, u;
            unpair(accf[r], g, u);
            const float dev = float(double(accf[r]) - exact);
            atomicAdd(&c->checked, 1ull);
            if (int(u) != hi || int(g) != lo) atomicAdd(&c->decode_mismatch, 1ull);
            if (abs(lo) > 1023) atomicAdd(&c->wrap, 1ull);
            amax_u(&c->max_dev_bits, __float_as_uint(fabsf(dev)));
            amax_u(&c->max_abs_p_bits, __float_as_uint(fabsf(accf[r])));
            atomicMax(&c->max_low, abs(lo));
            atomicMax(&c->max_high, abs(hi));
        }
        if (half) {}
    }
}

// ------------------------------------------------------------------ host side

static std::vector<uint8_t> read_file(const std::string &p) {
    FILE *f = fopen(p.c_str(), "rb");
    if (!f) { std::fprintf(stderr, "cannot read %s\n", p.c_str()); std::exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    std::vector<uint8_t> v((size_t) n, 0);
    if (n && fread(v.data(), 1, size_t(n), f) != size_t(n)) std::exit(1);
    fclose(f);
    return v;
}

static void decode_matrix(const std::vector<uint8_t> &halo_bytes, int rows, int kdim,
                          std::vector<int8_t> &trits) {
    const int nb = kdim / 128;
    trits.assign(size_t(rows) * kdim, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            const size_t src = (size_t(tile / 2) * nb + b) * halo::TILE_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                const int lane = (tile & 1) * 16 + r, row = tile * 16 + r;
                uint8_t qs[24], t128[128];
                std::memcpy(qs, halo_bytes.data() + src + halo::tile_off_qs_a(lane), 16);
                std::memcpy(qs + 16, halo_bytes.data() + src + halo::tile_off_qs_b(lane), 8);
                halo::decode_block(qs, halo_bytes.data() + src + halo::tile_off_tail(lane), t128);
                for (int j = 0; j < 128; ++j)
                    trits[size_t(row) * kdim + b * 128 + j] = int8_t(int(t128[j]) - 1);
            }
        }
}

static void hadamard_1024(float *v) {
    for (int h = 1; h < 1024; h <<= 1)
        for (int i = 0; i < 1024; i += 2 * h)
            for (int j = i; j < i + h; ++j) {
                float a = v[j], b = v[j + h];
                v[j] = a + b; v[j + h] = a - b;
            }
    for (int i = 0; i < 1024; ++i) v[i] *= 0.03125f;
}

int main(int argc, char **argv) {
    const std::string dir = argc > 1 ? argv[1] : "/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00";
    const int rows = argc > 2 ? atoi(argv[2]) : 2048;      // weight rows checked
    const int tokens = argc > 3 ? atoi(argv[3]) : 256;
    const float clip = argc > 4 ? (float) atof(argv[4]) : 1.0f;   // quantiser step = clip * amax / 7
    const int D = 5120, FF = 17408;
    const int nslices = D / 16;

    std::vector<int8_t> g, u;
    decode_matrix(read_file(dir + "/gate.halo"), FF, D, g);
    decode_matrix(read_file(dir + "/up.halo"), FF, D, u);

    // real activations: RMS norm, folded sign, 1024-point Hadamard, four-bit quantiser
    std::vector<float> x(size_t(tokens) * D), k(D);
    {
        std::vector<uint8_t> kb = read_file(dir + "/post_norm_s.f32");
        std::memcpy(k.data(), kb.data(), size_t(D) * 4);
        for (int c = 0; c < tokens / 8; ++c) {
            std::vector<uint8_t> b = read_file(dir + "/c" + std::string(c < 10 ? "00" : c < 100 ? "0" : "") +
                                               std::to_string(c) + "/x_in.f32");
            std::memcpy(x.data() + size_t(c) * 8 * D, b.data(), size_t(8) * D * 4);
        }
    }
    std::vector<float> uact(size_t(tokens) * D);
    for (int t = 0; t < tokens; ++t) {
        double ss = 0;
        for (int i = 0; i < D; ++i) ss += double(x[size_t(t) * D + i]) * x[size_t(t) * D + i];
        const float inv = float(1.0 / std::sqrt(ss / D + 1e-5));
        for (int i = 0; i < D; ++i) uact[size_t(t) * D + i] = x[size_t(t) * D + i] * inv * k[i];
        for (int c = 0; c < D / 1024; ++c) hadamard_1024(uact.data() + size_t(t) * D + c * 1024);
    }

    printf("dataset %s\nrows %d tokens %d clip %.3f\n", dir.c_str(), rows, tokens, clip);
    printf("%-5s %-6s %12s %10s %10s %10s %14s %12s\n", "G", "cols", "checked", "wrap",
           "max|low|", "max|high|", "max|p|", "max|dev|");

    const int ntok16 = tokens / 16, ntiles = rows / 16;
    // paired codes and int4 nibbles, both in [tile][slice][16 rows][8 bytes]
    std::vector<uint8_t> Ap(size_t(ntiles) * nslices * 128, 0), Ag(Ap.size(), 0), Au(Ap.size(), 0);
    for (int tile = 0; tile < ntiles; ++tile)
        for (int sl = 0; sl < nslices; ++sl)
            for (int r = 0; r < 16; ++r) {
                uint8_t *dp = Ap.data() + (size_t(tile) * nslices + sl) * 128 + r * 8;
                uint8_t *dg = Ag.data() + (size_t(tile) * nslices + sl) * 128 + r * 8;
                uint8_t *du = Au.data() + (size_t(tile) * nslices + sl) * 128 + r * 8;
                const size_t o = size_t(tile * 16 + r) * D + sl * 16;
                for (int j = 0; j < 16; ++j) {
                    dp[j / 2] |= uint8_t(pair_code(g[o + j], u[o + j]) << (4 * (j & 1)));
                    dg[j / 2] |= uint8_t((g[o + j] & 0xf) << (4 * (j & 1)));
                    du[j / 2] |= uint8_t((u[o + j] & 0xf) << (4 * (j & 1)));
                }
            }
    uint8_t *dAp, *dAg, *dAu;
    CK(hipMalloc(&dAp, Ap.size())); CK(hipMemcpy(dAp, Ap.data(), Ap.size(), hipMemcpyHostToDevice));
    CK(hipMalloc(&dAg, Ag.size())); CK(hipMemcpy(dAg, Ag.data(), Ag.size(), hipMemcpyHostToDevice));
    CK(hipMalloc(&dAu, Au.size())); CK(hipMemcpy(dAu, Au.data(), Au.size(), hipMemcpyHostToDevice));

    void *dBf, *dBi;
    CK(hipMalloc(&dBf, size_t(nslices) * tokens * 32));
    CK(hipMalloc(&dBi, size_t(nslices) * tokens * 8));

    for (int G : {1, 2, 4, 8, 20, 40}) {
        const int gsz = G * 128;
        if (D % gsz) continue;
        // quantise with one amax per (token, G*128)
        std::vector<_Float16> Bf(size_t(nslices) * tokens * 16, (_Float16) 0.f);
        std::vector<uint8_t> Bi(size_t(nslices) * tokens * 8, 0);
        for (int t = 0; t < tokens; ++t)
            for (int gp = 0; gp < D / gsz; ++gp) {
                float amax = 0;
                for (int i = 0; i < gsz; ++i) amax = fmaxf(amax, fabsf(uact[size_t(t) * D + gp * gsz + i]));
                const float step = amax * clip / 7.0f, iscale = amax > 0 ? 1.0f / step : 0.f;
                for (int i = 0; i < gsz; ++i) {
                    int q = int(std::nearbyintf(uact[size_t(t) * D + gp * gsz + i] * iscale));
                    q = q > 7 ? 7 : q < -7 ? -7 : q;
                    const int kk = gp * gsz + i, sl = kk / 16, j = kk % 16;
                    Bf[(size_t(sl) * tokens + t) * 16 + j] = (_Float16) float(q);
                    Bi[(size_t(sl) * tokens + t) * 8 + j / 2] |= uint8_t((q & 0xf) << (4 * (j & 1)));
                }
            }
        CK(hipMemcpy(dBf, Bf.data(), Bf.size() * 2, hipMemcpyHostToDevice));
        CK(hipMemcpy(dBi, Bi.data(), Bi.size(), hipMemcpyHostToDevice));
        Counters h{}, *d;
        CK(hipMalloc(&d, sizeof h));
        CK(hipMemcpy(d, &h, sizeof h, hipMemcpyHostToDevice));
        dim3 grid(ntiles, ntok16);
        switch (G) {
            case 1:  k_probe<8><<<grid, 32>>>(dAp, dAg, dAu, dBf, dBi, nslices, ntok16, d); break;
            case 2:  k_probe<16><<<grid, 32>>>(dAp, dAg, dAu, dBf, dBi, nslices, ntok16, d); break;
            case 4:  k_probe<32><<<grid, 32>>>(dAp, dAg, dAu, dBf, dBi, nslices, ntok16, d); break;
            case 8:  k_probe<64><<<grid, 32>>>(dAp, dAg, dAu, dBf, dBi, nslices, ntok16, d); break;
            case 20: k_probe<160><<<grid, 32>>>(dAp, dAg, dAu, dBf, dBi, nslices, ntok16, d); break;
            default: k_probe<320><<<grid, 32>>>(dAp, dAg, dAu, dBf, dBi, nslices, ntok16, d); break;
        }
        CK(hipDeviceSynchronize());
        CK(hipMemcpy(&h, d, sizeof h, hipMemcpyDeviceToHost));
        CK(hipFree(d));
        printf("%-5d %-6d %12llu %10llu %10d %10d %14.0f %12.6f   mismatch %llu\n", G, gsz,
               h.checked, h.wrap, h.max_low, h.max_high, __builtin_bit_cast(float, h.max_abs_p_bits),
               __builtin_bit_cast(float, h.max_dev_bits), h.decode_mismatch);
        fflush(stdout);
    }
    return 0;
}
