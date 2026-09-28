// Native gfx1151 behaviour of a three-channel ternary packing in one FP16 WMMA.
//
// Two questions the integer algebra cannot answer.
//
//   1. Does the hardware accumulator stay close enough to the exact integer for the channels to
//      separate? v_wmma_f32_16x16x16_f16 is not bit-exact on exactly representable integer
//      operands (../../packed-wmma/NOTES.md), and the minimal radix ladder [1, 33, 1089] leaves
//      only 0.5 of room in an accumulator that reaches 17968. `check` measures the deviation and
//      the separation failures directly.
//
//   2. Does one packed instruction plus its mandatory decode beat three native IU4 instructions?
//      A triple must separate its channels after every single WMMA (../feasibility.cpp), so the
//      decode never amortises. `rate` times the complete work unit -- 48 logical rows x 16 tokens
//      of ternary product -- with register-resident operands, so nothing but issue cost is in it.
//
// Modes: layout, check [tiles], rate.
#include <hip/hip_runtime.h>
#include "../geometry.hpp"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>
#include "radix.hpp"

using half16 = _Float16 __attribute__((ext_vector_type(16)));
using int8v = int __attribute__((ext_vector_type(8)));
using int2v = int __attribute__((ext_vector_type(2)));
using float8 = float __attribute__((ext_vector_type(8)));

#define CHECK(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) { \
    std::fprintf(stderr, "%s:%d %s: %s\n", __FILE__, __LINE__, #x, hipGetErrorString(e_)); \
    std::exit(1); } } while (0)

namespace {

// ---------------------------------------------------------------------------- layout and check

// One wave per tile: A row l%16, B column l%16, D element r of lane l is D[2r + l/16][l%16].
__global__ __launch_bounds__(32) void k_tile(const half16 *__restrict__ A,
                                             const half16 *__restrict__ B,
                                             float *__restrict__ out) {
    const int lane = threadIdx.x & 31, tile = blockIdx.x;
    float8 C = {};
    C = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(A[tile * 32 + lane], B[tile * 32 + lane], C);
#pragma unroll
    for (int r = 0; r < 8; ++r) out[size_t(tile) * 256 + (2 * r + lane / 16) * 16 + (lane % 16)] = C[r];
}

struct Stats {
    double max_dev = 0;          // largest |native - exact integer|
    size_t nonintegral = 0, total = 0;
    size_t sep_fail_minimal = 0, sep_fail_optimal = 0;   // channel separation failures per ladder
    double max_abs_p = 0;
    double worst_bottom_err = 0;
};

// Pack 16x16 ternary weight triples into FP16 operands and 16x16 ternary activations, run the
// native instruction, and compare with the exact integer accumulator.
void campaign(int tiles, unsigned seed, Stats & sMin, Stats & sOpt) {
    const kelana_triple::Ladder L[2] = {kelana_triple::MINIMAL, kelana_triple::OPTIMAL};
    Stats * S[2] = {&sMin, &sOpt};

    std::vector<half16> hA(size_t(tiles) * 32), hB(size_t(tiles) * 32);
    std::vector<float> hOut(size_t(tiles) * 256);
    half16 *dA, *dB; float *dOut;
    CHECK(hipMalloc(&dA, hA.size() * sizeof(half16)));
    CHECK(hipMalloc(&dB, hB.size() * sizeof(half16)));
    CHECK(hipMalloc(&dOut, hOut.size() * sizeof(float)));

    unsigned rng = seed ? seed : 1u;
    auto next = [&] { rng = rng * 1664525u + 1013904223u; return rng; };
    auto trit = [&](int density) { unsigned v = next(); return int(v % 100) < density ? ((v >> 8) & 1 ? 1 : -1) : 0; };

    for (int li = 0; li < 2; ++li) {
        const kelana_triple::Ladder & lad = L[li];
        std::vector<int8_t> W(size_t(tiles) * 3 * 256), X(size_t(tiles) * 256);
        for (int t = 0; t < tiles; ++t) {
            // Five activation/weight regimes, including the all-extreme corner where every digit
            // sum reaches its bound of 16.
            const int regime = t % 5;
            const int wd = regime == 0 ? 100 : regime == 1 ? 40 : regime == 2 ? 100 : regime == 3 ? 70 : 100;
            const int ad = regime == 0 ? 100 : regime == 1 ? 60 : regime == 2 ? 100 : regime == 3 ? 80 : 100;
            for (int i = 0; i < 16; ++i) {
                for (int c = 0; c < 3; ++c)
                    for (int k = 0; k < 16; ++k)
                        W[((size_t(t) * 3 + c) * 16 + i) * 16 + k] =
                            regime == 2 ? 1 : regime == 4 ? int8_t(c == 1 ? -1 : 1) : int8_t(trit(wd));
                for (int k = 0; k < 16; ++k)
                    X[(size_t(t) * 16 + i) * 16 + k] = regime == 2 ? 1 : regime == 4 ? -1 : int8_t(trit(ad));
            }
            for (int lane = 0; lane < 32; ++lane) {
                const int row = lane % 16;
                for (int k = 0; k < 16; ++k) {
                    const int w0 = W[((size_t(t) * 3 + 0) * 16 + row) * 16 + k];
                    const int w1 = W[((size_t(t) * 3 + 1) * 16 + row) * 16 + k];
                    const int w2 = W[((size_t(t) * 3 + 2) * 16 + row) * 16 + k];
                    hA[size_t(t) * 32 + lane][k] = (_Float16) float(lad.pack(w0, w1, w2));
                    hB[size_t(t) * 32 + lane][k] = (_Float16) float(X[(size_t(t) * 16 + row) * 16 + k]);
                }
            }
        }
        CHECK(hipMemcpy(dA, hA.data(), hA.size() * sizeof(half16), hipMemcpyHostToDevice));
        CHECK(hipMemcpy(dB, hB.data(), hB.size() * sizeof(half16), hipMemcpyHostToDevice));
        k_tile<<<tiles, 32>>>(dA, dB, dOut);
        CHECK(hipGetLastError());
        CHECK(hipMemcpy(hOut.data(), dOut, hOut.size() * sizeof(float), hipMemcpyDeviceToHost));

        Stats & st = *S[li];
        for (int t = 0; t < tiles; ++t)
            for (int i = 0; i < 16; ++i)
                for (int j = 0; j < 16; ++j) {
                    long long s[3] = {0, 0, 0};
                    for (int c = 0; c < 3; ++c)
                        for (int k = 0; k < 16; ++k)
                            s[c] += (long long) W[((size_t(t) * 3 + c) * 16 + i) * 16 + k] *
                                    X[(size_t(t) * 16 + j) * 16 + k];
                    const double exact = double(s[0]) + double(lad.R1) * double(s[1]) +
                                         double(lad.R2) * double(s[2]);
                    const float p = hOut[size_t(t) * 256 + i * 16 + j];
                    const double dev = std::fabs(double(p) - exact);
                    st.total++;
                    st.max_dev = std::max(st.max_dev, dev);
                    st.max_abs_p = std::max(st.max_abs_p, std::fabs(exact));
                    if (p != std::nearbyintf(p)) st.nonintegral++;
                    float v0, v1, v2;
                    lad.decode(p, v0, v1, v2);
                    if (v2 != float(s[2]) || v1 != float(s[1])) {
                        if (li == 0) st.sep_fail_minimal++; else st.sep_fail_optimal++;
                    }
                    st.worst_bottom_err = std::max(st.worst_bottom_err, std::fabs(double(v0) - double(s[0])));
                }
    }
    CHECK(hipFree(dA)); CHECK(hipFree(dB)); CHECK(hipFree(dOut));
}

// ------------------------------------------------------------------------------------ rate

// Each kernel issues `iters * UNITS` complete work units on two independent chains. A unit is
// 48 logical ternary rows x 16 tokens x 16 K, whichever way it is reached.
constexpr int UNITS = 8;

// Pure issue cost of one instruction class. The accumulator input is a constant zero and the
// result is consumed by an empty asm block, so consecutive instructions are independent and no
// arithmetic is charged to the measurement. This is the number a dependent accumulator chain
// need not reach with too few independent waves. Compare equal physical wave counts; the earlier
// arithmetic probe used the same incorrect 40-SIMD normalization as this probe. At the same
// largest wave count the two stored probes agree, rather than differing by a factor of two.
__global__ __launch_bounds__(128) void k_f16_issue(const half16 *A, const half16 *B, float *out, int iters) {
    const int lane = threadIdx.x & 31;
    half16 a = A[lane], b = B[lane];
    const float8 Z = {};
#pragma unroll 1
    for (int t = 0; t < iters; ++t)
#pragma unroll
        for (int s = 0; s < UNITS; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
            float8 P = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, b, Z);
            asm volatile("" :: "v"(P));
        }
    out[blockIdx.x * blockDim.x + threadIdx.x] = 0.f;
}

__global__ __launch_bounds__(128) void k_iu4_issue(const int2v *A, const int2v *B, int *out, int iters) {
    const int lane = threadIdx.x & 31;
    int2v a = A[lane], b = B[lane];
    const int8v Z = {};
#pragma unroll 1
    for (int t = 0; t < iters; ++t)
#pragma unroll
        for (int s = 0; s < UNITS; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
            int8v P = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, a, true, b, Z, false);
            asm volatile("" :: "v"(P));
        }
    out[blockIdx.x * blockDim.x + threadIdx.x] = 0;
}

// Ceiling for the triple map: the packed instruction with the decode removed. Not a usable map --
// the channels are still superposed -- but it bounds what any decode strategy could reach.
__global__ __launch_bounds__(128) void k_ceiling(const half16 *A, const half16 *B, float *out, int iters) {
    const int lane = threadIdx.x & 31;
    half16 a = A[lane], b = B[lane];
    const float8 Z = {};
    float8 P0 = {};
#pragma unroll 1
    for (int t = 0; t < iters; ++t)
#pragma unroll
        for (int s = 0; s < UNITS; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
            P0 += __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, b, Z);
        }
    float acc = 0;
#pragma unroll
    for (int r = 0; r < 8; ++r) acc += P0[r];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

// The real triple map: fresh zero accumulator, one WMMA, then the two separating divisions and
// three accumulations for every one of the eight accumulator elements this lane owns.
template <int R1, int R2>
__global__ __launch_bounds__(128) void k_triple(const half16 *A, const half16 *B, float *out, int iters) {
    const int lane = threadIdx.x & 31;
    half16 a = A[lane], b = B[lane];
    float8 accR = {}, acc1 = {}, acc2 = {};
    const float inv1 = 1.0f / float(R1), inv2 = 1.0f / float(R2);
#pragma unroll 1
    for (int t = 0; t < iters; ++t)
#pragma unroll
        for (int s = 0; s < UNITS; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
            float8 Z = {};
            float8 P = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, b, Z);
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                const float v2 = __builtin_rintf(P[r] * inv2);
                const float rr = __builtin_fmaf(-float(R2), v2, P[r]);
                const float v1 = __builtin_rintf(rr * inv1);
                accR[r] += rr; acc1[r] += v1; acc2[r] += v2;
            }
        }
    float acc = 0;
#pragma unroll
    for (int r = 0; r < 8; ++r) acc += accR[r] + acc1[r] + acc2[r];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

// Power-of-two ladder [1, 32, 1024], legal only when at most 15 activations per K16 group are
// nonzero. Decode becomes one bias add, one float-to-int convert and two bitfield reads.
__global__ __launch_bounds__(128) void k_triple_pow2(const half16 *A, const half16 *B, int *out, int iters) {
    const int lane = threadIdx.x & 31;
    half16 a = A[lane], b = B[lane];
    int8v accU = {}, acc1 = {}, acc2 = {};
#pragma unroll 1
    for (int t = 0; t < iters; ++t)
#pragma unroll
        for (int s = 0; s < UNITS; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
            float8 Z = {};
            float8 P = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, b, Z);
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                const unsigned u = (unsigned) (P[r] + 15855.5f);
                accU[r] += int(u);
                acc1[r] += int((u >> 5) & 31u);
                acc2[r] += int(u >> 10);
            }
        }
    int acc = 0;
#pragma unroll
    for (int r = 0; r < 8; ++r) acc += accU[r] + acc1[r] + acc2[r];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

// Matched native baseline: three IU4 instructions reach the same 48 rows x 16 tokens, and their
// accumulators need no separation, so they chain in place.
__global__ __launch_bounds__(128) void k_iu4x3(const int2v *A, const int2v *B, int *out, int iters) {
    const int lane = threadIdx.x & 31;
    int2v a = A[lane], b = B[lane];
    int8v C0 = {}, C1 = {}, C2 = {};
#pragma unroll 1
    for (int t = 0; t < iters; ++t)
#pragma unroll
        for (int s = 0; s < UNITS; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
            C0 = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, a, true, b, C0, false);
            C1 = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, a, true, b, C1, false);
            C2 = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, a, true, b, C2, false);
        }
    int acc = 0;
#pragma unroll
    for (int r = 0; r < 8; ++r) acc += C0[r] + C1[r] + C2[r];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

// The pair, for scale: one FP16 WMMA carries 32 logical rows and separates once per eight
// instructions, so its decode is amortised. Emitted here as two instructions plus one eighth of a
// decode, which is what the deployed paired map does per K16 slice.
__global__ __launch_bounds__(128) void k_pair(const half16 *A, const half16 *B, float *out, int iters) {
    const int lane = threadIdx.x & 31;
    half16 a = A[lane], b = B[lane];
    float8 P0 = {}, acc1 = {}, accR = {};
#pragma unroll 1
    for (int t = 0; t < iters; ++t)
#pragma unroll
        for (int s = 0; s < UNITS; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
            P0 = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, b, P0);
            if (s % 8 == 7) {       // one separation per K128 block, as the paired map does
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    const float v1 = __builtin_rintf(P0[r] * (1.0f / 2017.0f));
                    accR[r] += __builtin_fmaf(-2017.0f, v1, P0[r]);
                    acc1[r] += v1;
                }
                P0 = float8{};
            }
        }
    float acc = 0;
#pragma unroll
    for (int r = 0; r < 8; ++r) acc += P0[r] + acc1[r] + accR[r];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

// Pure VALU rate, to price decode instructions in the same units as the matrix instructions.
// Eight independent chains so the measurement is issue cost rather than FMA latency.
__global__ __launch_bounds__(128) void k_valu(float *out, int iters) {
    float v[8], b = 1.000001f, c = 0.5f;
#pragma unroll
    for (int i = 0; i < 8; ++i) v[i] = float(threadIdx.x + i);
#pragma unroll 1
    for (int t = 0; t < iters; ++t)
#pragma unroll
        for (int s = 0; s < UNITS * 4; ++s)
#pragma unroll
            for (int i = 0; i < 8; ++i) v[i] = __builtin_fmaf(v[i], b, c);
    float acc = 0;
#pragma unroll
    for (int i = 0; i < 8; ++i) acc += v[i];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

template <class F> float best_ms(F launch) {
    float best = 1e30f;
    for (int rep = 0; rep < 5; ++rep) {
        hipEvent_t a, b; hipEventCreate(&a); hipEventCreate(&b);
        CHECK(hipDeviceSynchronize()); hipEventRecord(a);
        launch();
        hipEventRecord(b); hipEventSynchronize(b);
        float ms = 0; hipEventElapsedTime(&ms, a, b);
        best = std::min(best, ms);
        hipEventDestroy(a); hipEventDestroy(b);
    }
    return best;
}

std::string g_json;
void jline(const std::string & s) { g_json += s; }
std::string num(double v) { char b[64]; snprintf(b, sizeof b, "%.6g", v); return b; }

}  // namespace

int main(int argc, char ** argv) {
    const std::string mode = argc > 1 ? argv[1] : "check";
    hipDeviceProp_t prop{};
    CHECK(hipGetDeviceProperties(&prop, 0));
    const auto geom=kelana_batch::geometry(prop);
    const int simds = geom.simds;
    std::printf("device %s, %d WGP, %d CU, %d SIMD32, clock %.2f GHz nominal\n", prop.gcnArchName,
                geom.wgps, geom.cus, simds, prop.clockRate / 1e6);

    if (mode == "layout") {
        // Confirm that D's first index is the A row before any exactness number is reported.
        std::vector<half16> hA(32), hB(32);
        std::vector<float> hOut(256);
        for (int lane = 0; lane < 32; ++lane)
            for (int k = 0; k < 16; ++k) {
                hA[lane][k] = (_Float16) (k == 0 ? float(lane % 16 + 1) : 0.0f);
                hB[lane][k] = (_Float16) (k == 0 ? 1.0f : 0.0f);
            }
        half16 *dA, *dB; float *dOut;
        CHECK(hipMalloc(&dA, 32 * sizeof(half16))); CHECK(hipMalloc(&dB, 32 * sizeof(half16)));
        CHECK(hipMalloc(&dOut, 256 * sizeof(float)));
        CHECK(hipMemcpy(dA, hA.data(), 32 * sizeof(half16), hipMemcpyHostToDevice));
        CHECK(hipMemcpy(dB, hB.data(), 32 * sizeof(half16), hipMemcpyHostToDevice));
        k_tile<<<1, 32>>>(dA, dB, dOut);
        CHECK(hipMemcpy(hOut.data(), dOut, 256 * sizeof(float), hipMemcpyDeviceToHost));
        bool a_major = true;
        for (int i = 0; i < 16 && a_major; ++i)
            for (int j = 0; j < 16; ++j) if (hOut[i * 16 + j] != float(i + 1)) { a_major = false; break; }
        std::printf("D[first][second] first index is the %s index: %s\n",
                    a_major ? "A row" : "B column", a_major ? "confirmed" : "NOT as documented");
        std::printf("row 0: "); for (int j = 0; j < 4; ++j) std::printf("%.0f ", hOut[j]);
        std::printf("| row 3: "); for (int j = 0; j < 4; ++j) std::printf("%.0f ", hOut[3 * 16 + j]);
        std::printf("\n");
        return a_major ? 0 : 1;
    }

    if (mode == "check") {
        const int tiles = argc > 2 ? std::atoi(argv[2]) : 4000;
        Stats sMin{}, sOpt{};
        campaign(tiles, 12345u, sMin, sOpt);
        std::printf("\n%d tiles per ladder, %zu accumulators each.\n", tiles, sMin.total);
        std::printf("%-18s %-11s %-13s %-12s %-14s %-12s\n", "ladder", "max |P|",
                    "max deviation", "non-integral", "separation", "margin");
        const char * names[2] = {"[1, 33, 1089]", "[1, 60, 1987]"};
        const Stats * S[2] = {&sMin, &sOpt};
        const double margins[2] = {0.5, 14.0};
        for (int i = 0; i < 2; ++i) {
            const size_t fails = i == 0 ? S[i]->sep_fail_minimal : S[i]->sep_fail_optimal;
            std::printf("%-18s %-11.0f %-13.6g %-12.3f%% %-14s %-12.1f\n", names[i], S[i]->max_abs_p,
                        S[i]->max_dev, 100.0 * double(S[i]->nonintegral) / double(S[i]->total),
                        fails ? (std::to_string(fails) + " FAILURES").c_str() : "exact", margins[i]);
        }
        std::printf("\nThe deviation is what the proof cannot bound: the ISA documents round-to-nearest-even\n"
                    "for the float forms but not the internal dot precision, so these are measurements over\n"
                    "the tried inputs, not a hardware bound.\n");
        g_json = "{\n  \"tiles\": " + std::to_string(tiles) +
                 ",\n  \"accumulators_per_ladder\": " + std::to_string(sMin.total) +
                 ",\n  \"minimal\": { \"radices\": [1,33,1089], \"max_abs_p\": " + num(sMin.max_abs_p) +
                 ", \"max_deviation\": " + num(sMin.max_dev) + ", \"nonintegral_fraction\": " +
                 num(double(sMin.nonintegral) / double(sMin.total)) + ", \"separation_failures\": " +
                 std::to_string(sMin.sep_fail_minimal) + ", \"margin\": 0.5 },\n" +
                 "  \"optimal\": { \"radices\": [1,60,1987], \"max_abs_p\": " + num(sOpt.max_abs_p) +
                 ", \"max_deviation\": " + num(sOpt.max_dev) + ", \"nonintegral_fraction\": " +
                 num(double(sOpt.nonintegral) / double(sOpt.total)) + ", \"separation_failures\": " +
                 std::to_string(sOpt.sep_fail_optimal) + ", \"margin\": 14.0 }\n}\n";
        if (argc > 3) { FILE * f = fopen(argv[3], "w"); fputs(g_json.c_str(), f); fclose(f); }
        return 0;
    }

    if (mode == "rate") {
        const int iters = 2000, block_waves = 4, threads = block_waves * 32;
        half16 *dA, *dB; int2v *dAi, *dBi; float *dof; int *doi;
        CHECK(hipMalloc(&dA, 32 * sizeof(half16))); CHECK(hipMalloc(&dB, 32 * sizeof(half16)));
        CHECK(hipMalloc(&dAi, 32 * sizeof(int2v))); CHECK(hipMalloc(&dBi, 32 * sizeof(int2v)));
        CHECK(hipMalloc(&dof, (1 << 16) * sizeof(float))); CHECK(hipMalloc(&doi, (1 << 16) * sizeof(int)));
        CHECK(hipMemset(dA, 0, 32 * sizeof(half16))); CHECK(hipMemset(dB, 0, 32 * sizeof(half16)));
        CHECK(hipMemset(dAi, 0, 32 * sizeof(int2v))); CHECK(hipMemset(dBi, 0, 32 * sizeof(int2v)));

        std::printf("\nns per work unit (48 logical ternary rows x 16 tokens x 16 K) per wave,\n"
                    "with `simds * waves` waves resident. Single instructions are priced in the\n"
                    "same units: one f16 or iu4 WMMA, one VALU instruction. The trailing columns\n"
                    "divide by the waves a SIMD issues concurrently, giving per-SIMD cost.\n");
        std::printf("%-6s %-9s %-9s %-10s %-9s %-9s %-8s %-8s %-8s %-10s\n", "waves", "iu4 x3",
                    "triple", "triple p2", "pair", "ceiling", "f16", "iu4", "valu", "triple/iu4");
        std::string rows;
        for (int wps : {1, 2, 4, 8}) {
            const int grid = simds * wps / block_waves;
            const double units = double(iters) * UNITS;
            auto per = [&](float ms) { return ms * 1e6 / units; };
            const float m_iu4 = best_ms([&] { k_iu4x3<<<grid, threads>>>(dAi, dBi, doi, iters); });
            const float m_tri = best_ms([&] { k_triple<60, 1987><<<grid, threads>>>(dA, dB, dof, iters); });
            const float m_tp2 = best_ms([&] { k_triple_pow2<<<grid, threads>>>(dA, dB, doi, iters); });
            const float m_pair = best_ms([&] { k_pair<<<grid, threads>>>(dA, dB, dof, iters); });
            const float m_ceil = best_ms([&] { k_ceiling<<<grid, threads>>>(dA, dB, dof, iters); });
            const float m_f16 = best_ms([&] { k_f16_issue<<<grid, threads>>>(dA, dB, dof, iters); });
            const float m_i4 = best_ms([&] { k_iu4_issue<<<grid, threads>>>(dAi, dBi, doi, iters); });
            const float m_valu = best_ms([&] { k_valu<<<grid, threads>>>(dof, iters); });
            CHECK(hipGetLastError());
            // k_valu issues UNITS*4*8 VALU instructions per iteration; price one of them.
            const double ns_iu4 = per(m_iu4), ns_tri = per(m_tri), ns_tp2 = per(m_tp2),
                         ns_pair = per(m_pair) * 1.5, ns_ceil = per(m_ceil),
                         ns_f16 = per(m_f16), ns_i4 = per(m_i4), ns_valu = per(m_valu) / 32.0;
            // Per-wave cost times the waves a SIMD issues concurrently is the per-SIMD cost of
            // one instruction. Printing it here means no reader has to reconstruct the divisor.
            const double per_simd = double(wps);
            std::printf("%-6d %-9.3f %-9.3f %-10.3f %-9.3f %-9.3f %-8.3f %-8.3f %-8.4f %-10.2f"
                        "   | per SIMD: f16 %.3f  iu4 %.3f  valu %.4f  iu4 %.1f MAC/ns\n", wps,
                        ns_iu4, ns_tri, ns_tp2, ns_pair, ns_ceil, ns_f16, ns_i4, ns_valu,
                        ns_tri / ns_iu4, ns_f16 / per_simd, ns_i4 / per_simd, ns_valu / per_simd,
                        4096.0 / (ns_i4 / per_simd));
            rows += std::string(rows.empty() ? "" : ",\n") + "    { \"waves_per_simd\": " +
                    std::to_string(wps) + ", \"iu4x3\": " + num(ns_iu4) + ", \"triple\": " + num(ns_tri) +
                    ", \"triple_pow2\": " + num(ns_tp2) + ", \"pair_scaled_to_48_rows\": " + num(ns_pair) +
                    ", \"packed_no_decode\": " + num(ns_ceil) + ", \"f16_wmma\": " + num(ns_f16) +
                    ", \"iu4_wmma\": " + num(ns_i4) + ", \"valu_op\": " + num(ns_valu) +
                    ", \"physical_waves_per_simd\": " + std::to_string(wps) +
                    ", \"f16_wmma_ns_per_simd\": " + num(ns_f16 / double(wps)) +
                    ", \"iu4_wmma_ns_per_simd\": " + num(ns_i4 / double(wps)) +
                    ", \"valu_op_ns_per_simd\": " + num(ns_valu / double(wps)) +
                    ", \"iu4_mac_per_ns_per_simd\": " + num(4096.0 * double(wps) / ns_i4) + " }";
        }
        std::printf("\n`pair` is scaled by 3/2 so its column is also 48 logical rows: the pair carries 32 per\n"
                    "instruction and separates once per eight, the triple carries 48 and separates every time.\n");
        g_json = "{\n  \"unit\": \"48 logical ternary rows x 16 tokens x 16 K\",\n  \"device\": \"" +
                 std::string(prop.gcnArchName) + "\",\n  \"wgps\": "+std::to_string(geom.wgps)+", \"cus\": "+std::to_string(geom.cus)+", \"simds\": "+std::to_string(geom.simds)+",\n  \"timing_units\": \"Stored per-column values are ns elapsed per per-wave work unit. Dividing by physical_waves_per_simd gives the per-SIMD cost of one instruction; the *_ns_per_simd fields are that division already applied. Samples recorded before the geometry fix carry a waves_per_simd label that is twice the physical value -- see normalize_issue_rate.py.\",\n  \"rows\": [\n" + rows + "\n  ]\n}\n";
        if (argc > 2) { FILE * f = fopen(argv[2], "w"); fputs(g_json.c_str(), f); fclose(f); }
        return 0;
    }

    std::fprintf(stderr, "usage: triple_probe layout | check [tiles] [json] | rate [json]\n");
    return 2;
}
