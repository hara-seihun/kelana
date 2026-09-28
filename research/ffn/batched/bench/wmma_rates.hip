// Raw WMMA issue rates on this GPU, so nobody has to assume a ratio between the integer widths.
//
// Each wave runs a long chain of independent WMMA instructions on register operands with no memory
// traffic, so the number measured is the instruction rate of the matrix unit, not a kernel. The
// accumulators are independent enough to cover the instruction latency and the result is consumed
// so nothing is eliminated.
#include <hip/hip_runtime.h>
#include <algorithm>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

typedef int v2i __attribute__((ext_vector_type(2)));
typedef int v4i __attribute__((ext_vector_type(4)));
typedef int v8i __attribute__((ext_vector_type(8)));
typedef float v8f __attribute__((ext_vector_type(8)));
typedef _Float16 v16h __attribute__((ext_vector_type(16)));

#define CHECK(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) { fprintf(stderr, "%s: %s\n", #x, hipGetErrorString(e_)); return 1; } } while (0)

constexpr int CHAIN = 4;     // independent accumulators per wave
constexpr int UNROLL = 8;    // instructions per accumulator per loop step

__global__ void k_iu8(int * out, int iters, int seed) {
    v4i a = { seed + 1, seed + 2, seed + 3, seed + 4 }, b = { seed + 5, seed + 6, seed + 7, seed + 8 };
    v8i c[CHAIN];
    for (int i = 0; i < CHAIN; i++) c[i] = v8i{0,0,0,0,0,0,0,0};
    for (int it = 0; it < iters; it++) {
        // Opaque to the compiler, so a loop-invariant operand pair cannot be folded into a closed
        // form. Once per outer step, so it does not serialise the chain being measured.
        asm volatile("" : "+v"(a), "+v"(b));
        #pragma unroll
        for (int u = 0; u < UNROLL; u++)
            #pragma unroll
            for (int i = 0; i < CHAIN; i++) c[i] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, a, true, b, c[i], false);
    }
    int s = 0;
    for (int i = 0; i < CHAIN; i++) for (int j = 0; j < 8; j++) s += c[i][j];
    if (s == 0x7fffffff) out[0] = s;
}

__global__ void k_iu4(int * out, int iters, int seed) {
    v2i a = { seed + 1, seed + 2 }, b = { seed + 3, seed + 4 };
    v8i c[CHAIN];
    for (int i = 0; i < CHAIN; i++) c[i] = v8i{0,0,0,0,0,0,0,0};
    for (int it = 0; it < iters; it++) {
        // Opaque to the compiler, so a loop-invariant operand pair cannot be folded into a closed
        // form. Once per outer step, so it does not serialise the chain being measured.
        asm volatile("" : "+v"(a), "+v"(b));
        #pragma unroll
        for (int u = 0; u < UNROLL; u++)
            #pragma unroll
            for (int i = 0; i < CHAIN; i++) c[i] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, a, true, b, c[i], false);
    }
    int s = 0;
    for (int i = 0; i < CHAIN; i++) for (int j = 0; j < 8; j++) s += c[i][j];
    if (s == 0x7fffffff) out[0] = s;
}

__global__ void k_f16(int * out, int iters, int seed) {
    v16h a, b;
    for (int i = 0; i < 16; i++) { a[i] = (_Float16) (seed + i); b[i] = (_Float16) (seed + 16 - i); }
    v8f c[CHAIN];
    for (int i = 0; i < CHAIN; i++) c[i] = v8f{0,0,0,0,0,0,0,0};
    for (int it = 0; it < iters; it++) {
        // Opaque to the compiler, so a loop-invariant operand pair cannot be folded into a closed
        // form. Once per outer step, so it does not serialise the chain being measured.
        asm volatile("" : "+v"(a), "+v"(b));
        #pragma unroll
        for (int u = 0; u < UNROLL; u++)
            #pragma unroll
            for (int i = 0; i < CHAIN; i++) c[i] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, b, c[i]);
    }
    float s = 0;
    for (int i = 0; i < CHAIN; i++) for (int j = 0; j < 8; j++) s += c[i][j];
    if (s == 1e30f) out[0] = 1;
}

__global__ void k_dot4(int * out, int iters, int seed) {
    int a = seed + 1, b = seed + 2;
    int c[CHAIN * 2];
    for (int i = 0; i < CHAIN * 2; i++) c[i] = 0;
    for (int it = 0; it < iters; it++) {
        // Opaque to the compiler, so a loop-invariant operand pair cannot be folded into a closed
        // form. Once per outer step, so it does not serialise the chain being measured.
        asm volatile("" : "+v"(a), "+v"(b));
        #pragma unroll
        for (int u = 0; u < UNROLL; u++)
            #pragma unroll
            for (int i = 0; i < CHAIN * 2; i++) c[i] = __builtin_amdgcn_sudot4(true, a, true, b, c[i], false);
    }
    int s = 0;
    for (int i = 0; i < CHAIN * 2; i++) s += c[i];
    if (s == 0x7fffffff) out[0] = s;
}

int main(int argc, char ** argv) {
    int iters = 4000, blocks = 0, threads = 256, reps = 5;
    for (int i = 1; i < argc; i++) {
        const std::string a = argv[i];
        if (a == "--iters" && i + 1 < argc) iters = atoi(argv[++i]);
        else if (a == "--blocks" && i + 1 < argc) blocks = atoi(argv[++i]);
        else if (a == "--reps" && i + 1 < argc) reps = atoi(argv[++i]);
    }
    hipDeviceProp_t prop{};
    CHECK(hipGetDeviceProperties(&prop, 0));
    if (!blocks) blocks = prop.multiProcessorCount * 8;
    const int waves = blocks * threads / 32;

    int * out = nullptr;
    CHECK(hipMalloc(&out, 4));
    CHECK(hipMemset(out, 0, 4));
    hipEvent_t e0, e1;
    CHECK(hipEventCreate(&e0));
    CHECK(hipEventCreate(&e1));

    struct Kind { const char * name; void (*fn)(int *, int, int); double macs; int chains; };
    const Kind kinds[] = {
        { "wmma_i32_16x16x16_iu8", k_iu8, 16.0 * 16 * 16, CHAIN },
        { "wmma_i32_16x16x16_iu4", k_iu4, 16.0 * 16 * 16, CHAIN },
        { "wmma_f32_16x16x16_f16", k_f16, 16.0 * 16 * 16, CHAIN },
        { "sudot4 (v_dot4_i32_iu8)",  k_dot4, 4.0,            CHAIN * 2 },
    };
    printf("%s, %d HIP processors (WGPs on gfx1151), %d blocks x %d threads (%d waves), %d iters x %d unroll\n",
           prop.gcnArchName, prop.multiProcessorCount, blocks, threads, waves, iters, UNROLL);
    printf("%-26s %10s %14s %14s\n", "instruction", "best ms", "issues/s", "TOPS (2*MAC)");
    printf("  (WMMA issues are per wave, sudot4 per lane; MACs per issue: WMMA 4096, sudot4 4)\n");
    for (const Kind & k : kinds) {
        double best = 1e9;
        for (int r = 0; r < reps; r++) {
            CHECK(hipEventRecord(e0, nullptr));
            hipLaunchKernelGGL(k.fn, dim3(blocks), dim3(threads), 0, nullptr, out, iters, r);
            CHECK(hipEventRecord(e1, nullptr));
            CHECK(hipDeviceSynchronize());
            float ms = 0;
            CHECK(hipEventElapsedTime(&ms, e0, e1));
            best = std::min(best, (double) ms);
        }
        // sdot4 is a per-lane instruction, the WMMA ones are per-wave.
        const bool per_wave = k.fn != k_dot4;
        const double units = per_wave ? (double) waves : (double) waves * 32.0;
        const double instr = units * (double) iters * UNROLL * k.chains;
        printf("%-26s %10.3f %14.4g %14.2f\n", k.name, best, instr / (best * 1e-3),
               2.0 * k.macs * instr / (best * 1e-3) / 1e12);
    }
    return 0;
}
