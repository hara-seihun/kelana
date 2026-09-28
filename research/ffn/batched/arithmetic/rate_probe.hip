// Raw WMMA issue rate on gfx1151 for the three operand classes a batched ternary FFN can use.
//
// The paired-FP16 map's whole value at 16+ tokens depends on which matrix instruction the hardware
// issues fastest per useful MAC. packed-wmma/NOTES.md measured F16 and IU8 at equal rates; IU4 was
// only quoted from AMD's discrete-RDNA3 table. This probe measures all three on this device.
//
// Each kernel issues `iters*16` matrix instructions on two independent accumulator chains with
// register-resident operands, so the number reported is issue cost, not memory or dependency stalls.
#include <hip/hip_runtime.h>
#include "../geometry.hpp"
#include <cstdio>
#include <vector>
#include <algorithm>

using half16 = _Float16 __attribute__((ext_vector_type(16)));
using int8v = int __attribute__((ext_vector_type(8)));
using int4v = int __attribute__((ext_vector_type(4)));
using int2v = int __attribute__((ext_vector_type(2)));
using float8 = float __attribute__((ext_vector_type(8)));

__global__ __launch_bounds__(128) void k_f16(const half16 *A, const half16 *B, float *out, int iters) {
    int lane = threadIdx.x & 31;
    half16 a = A[lane], b = B[lane];
    float8 C0 = {}, C1 = {};
#pragma unroll 1
    for (int t = 0; t < iters; ++t) {
#pragma unroll
        for (int s = 0; s < 8; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
            C0 = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, b, C0);
            C1 = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, b, C1);
        }
    }
    float acc = 0;
#pragma unroll
    for (int r = 0; r < 8; ++r) acc += C0[r] + C1[r];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

__global__ __launch_bounds__(128) void k_iu8(const int4v *A, const int4v *B, int *out, int iters) {
    int lane = threadIdx.x & 31;
    int4v a = A[lane], b = B[lane];
    int8v C0 = {}, C1 = {};
#pragma unroll 1
    for (int t = 0; t < iters; ++t) {
#pragma unroll
        for (int s = 0; s < 8; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
            C0 = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, a, true, b, C0, false);
            C1 = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, a, true, b, C1, false);
        }
    }
    int acc = 0;
#pragma unroll
    for (int r = 0; r < 8; ++r) acc += C0[r] + C1[r];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

__global__ __launch_bounds__(128) void k_iu4(const int2v *A, const int2v *B, int *out, int iters) {
    int lane = threadIdx.x & 31;
    int2v a = A[lane], b = B[lane];
    int8v C0 = {}, C1 = {};
#pragma unroll 1
    for (int t = 0; t < iters; ++t) {
#pragma unroll
        for (int s = 0; s < 8; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
            C0 = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, a, true, b, C0, false);
            C1 = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, a, true, b, C1, false);
        }
    }
    int acc = 0;
#pragma unroll
    for (int r = 0; r < 8; ++r) acc += C0[r] + C1[r];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

template <class T> struct Dev {
    T *p = nullptr;
    explicit Dev(size_t n) { hipMalloc(&p, n * sizeof(T)); hipMemset(p, 0, n * sizeof(T)); }
    ~Dev() { hipFree(p); }
};

template <class F> static float best_ms(F launch) {
    float best = 1e30f;
    for (int rep = 0; rep < 5; ++rep) {
        hipEvent_t a, b; hipEventCreate(&a); hipEventCreate(&b);
        hipDeviceSynchronize(); hipEventRecord(a);
        launch();
        hipEventRecord(b); hipEventSynchronize(b);
        float ms = 0; hipEventElapsedTime(&ms, a, b);
        best = std::min(best, ms);
        hipEventDestroy(a); hipEventDestroy(b);
    }
    return best;
}

int main() {
    hipDeviceProp_t prop{};
    hipGetDeviceProperties(&prop, 0);
    const auto geom=kelana_batch::geometry(prop);
    int simds = geom.simds;
    printf("device %s, %d WGP, %d CU, %d SIMD32\n", prop.gcnArchName, geom.wgps, geom.cus, simds);
    Dev<half16> dA(32), dB(32);
    Dev<int4v> dAi(32), dBi(32);
    Dev<int2v> dAn(32), dBn(32);
    Dev<float> dof(1 << 16);
    Dev<int> doi(1 << 16);
    const int iters = 2000, block_waves = 4, threads = block_waves * 32;
    printf("%-6s %10s %10s %10s %10s %14s\n", "waves", "f16 ns", "iu8 ns", "iu4 ns",
           "iu4/f16", "f16 instr/us/SIMD");
    for (int wps : {1, 2, 4, 8}) {
        int grid = simds * wps / block_waves;
        float mf = best_ms([&] { k_f16<<<grid, threads>>>(dA.p, dB.p, dof.p, iters); });
        float m8 = best_ms([&] { k_iu8<<<grid, threads>>>(dAi.p, dBi.p, doi.p, iters); });
        float m4 = best_ms([&] { k_iu4<<<grid, threads>>>(dAn.p, dBn.p, doi.p, iters); });
        double instr = double(iters) * 16.0;
        double nf = mf * 1e6 / instr, n8 = m8 * 1e6 / instr, n4 = m4 * 1e6 / instr;
        printf("%-6d %10.3f %10.3f %10.3f %10.3f %14.1f\n", wps, nf, n8, n4, n4 / nf,
               instr * wps / (mf * 1e3));
    }
    // Useful-MAC rates for the batched maps, all at 16 tokens per B tile:
    //   iu8 native   : 16 logical rows x 16 tokens x 16 K = 4096 MAC / instruction
    //   paired f16   : 32 logical rows (gate+up in one coefficient) x 16 x 16 = 8192 MAC
    //   iu4 native   : 4096 MAC / instruction
    return 0;
}
