// What does a weight stream of a given size actually cost on this part?
//
// The expanded-operand experiment measures far less bandwidth than the compact one on the same
// kernel shape, so the byte budget itself has to be measured rather than assumed. This probe reads
// a contiguous region with the gate/up kernel's own access shape - 32 bytes per lane, the two
// halves of a wave reading the same fragment as RDNA3's w32 WMMA layout requires - and sweeps the
// footprint. `--unique` drops the half-wave duplication so the two effects separate.
//
//   hipcc --offload-arch=gfx1151 -O3 -std=c++17 bandwidth_probe.hip -o bandwidth-probe
#include <hip/hip_runtime.h>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#define CHECK(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) { fprintf(stderr, "%s: %s\n", #x, hipGetErrorString(e_)); exit(1); } } while (0)

using half16 = _Float16 __attribute__((ext_vector_type(16)));

// MIX pairs every weight fragment with a fragment from a small resident buffer, the way the gate/up
// kernel pairs each A operand with a digit-plane B operand of the same width. Both streams then
// share one vmcnt queue.
template <bool DUP, bool MIX>
__global__ __launch_bounds__(256) void read_kernel(const uint8_t * __restrict__ base, size_t frags,
                                                   const uint8_t * __restrict__ hot, size_t hot_frags, float * sink) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const size_t waves = (size_t) gridDim.x * 8;
    const size_t wid = (size_t) blockIdx.x * 8 + wave;
    const int slot = DUP ? (lane & 15) : lane;          // duplicated half-waves, or 32 distinct
    const int per_wave = DUP ? 16 : 32;
    float acc = 0.0f;
    for (size_t f = wid * per_wave + slot; f < frags; f += waves * per_wave) {
        half16 v = *(const half16 *) (base + f * 32);
        acc += (float) v[0] + (float) v[15];
        if constexpr (MIX) {
            half16 h = *(const half16 *) (hot + (f % hot_frags) * 32);
            acc += (float) h[0] + (float) h[15];
        }
    }
    if (acc == 12345.678f) sink[0] = acc;               // never true; keeps the loads live
}

int main(int argc, char ** argv) {
    bool dup = true, mix = false;
    size_t cap_mb = 512;
    std::vector<size_t> mbs = { 4, 8, 16, 24, 32, 48, 64, 96, 128, 181, 256 };
    for (int i = 1; i < argc; i++) {
        std::string a = argv[i];
        if (a == "--unique") dup = false;
        else if (a == "--mix") mix = true;
        else if (a == "--cap-mb") cap_mb = std::stoul(argv[++i]);
    }
    hipDeviceProp_t prop{};
    CHECK(hipGetDeviceProperties(&prop, 0));
    uint8_t * buf = nullptr;
    CHECK(hipMalloc(&buf, cap_mb << 20));
    CHECK(hipMemset(buf, 1, cap_mb << 20));
    float * sink = nullptr;
    CHECK(hipMalloc(&sink, 4));
    uint8_t * hot = nullptr;                            // the digit planes are 160 KB
    const size_t hot_bytes = 160 << 10;
    CHECK(hipMalloc(&hot, hot_bytes));
    CHECK(hipMemset(hot, 1, hot_bytes));

    const int grid = prop.multiProcessorCount * 2;      // the gate/up kernel's occupancy
    hipEvent_t e0, e1;
    CHECK(hipEventCreate(&e0));
    CHECK(hipEventCreate(&e1));
    printf("# %s, %d CUs, %s half-wave fragments%s, grid %d x 256\n",
           prop.gcnArchName, prop.multiProcessorCount, dup ? "duplicated" : "unique",
           mix ? ", paired with a 160 KB resident stream" : "", grid);
    printf("# footprint_MB  GB/s  ms_per_pass\n");
    for (size_t mb : mbs) {
        if (mb > cap_mb) continue;
        const size_t bytes = mb << 20, frags = bytes / 32;
        const size_t hot_frags = hot_bytes / 32;
        auto launch = [&] {
            if (dup && mix) hipLaunchKernelGGL((read_kernel<true, true>), dim3(grid), dim3(256), 0, 0, buf, frags, hot, hot_frags, sink);
            else if (dup) hipLaunchKernelGGL((read_kernel<true, false>), dim3(grid), dim3(256), 0, 0, buf, frags, hot, hot_frags, sink);
            else if (mix) hipLaunchKernelGGL((read_kernel<false, true>), dim3(grid), dim3(256), 0, 0, buf, frags, hot, hot_frags, sink);
            else hipLaunchKernelGGL((read_kernel<false, false>), dim3(grid), dim3(256), 0, 0, buf, frags, hot, hot_frags, sink);
        };
        for (int i = 0; i < 3; i++) launch();
        CHECK(hipDeviceSynchronize());
        const int iters = std::max<int>(5, (int) (2000 / std::max<size_t>(mb, 1)));
        CHECK(hipEventRecord(e0));
        for (int i = 0; i < iters; i++) launch();
        CHECK(hipEventRecord(e1));
        CHECK(hipDeviceSynchronize());
        float ms = 0;
        CHECK(hipEventElapsedTime(&ms, e0, e1));
        const double per = ms / iters;
        printf("%12zu  %6.1f  %8.4f\n", mb, (double) bytes / (per * 1e-3) / 1e9, per);
        fflush(stdout);
    }
    return 0;
}
