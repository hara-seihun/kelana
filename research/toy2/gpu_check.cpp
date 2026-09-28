#include "toy2.hpp"
#include <cstring>
#include <vector>

__global__ void check_maps(const Prepared *p, const uint32_t *input, uint64_t *output, int count) {
    int i = int(blockIdx.x * blockDim.x + threadIdx.x);
    if (i >= count) return;
    Prepared a = p[i / 6561];
    uint32_t x = expand(input[i]);
    uint32_t d00 = dot(a.rows[0], x, a.biases[0]);
    uint32_t d10 = dot(a.rows[1], x, a.biases[1]);
    uint32_t d01 = dot(a.rows[2], x, a.biases[0]);
    uint32_t d11 = dot(a.rows[3], x, a.biases[1]);
    uint32_t baseline = (d10 + 7 * d00) | ((d11 + 7 * d01) << 8);
    uint32_t candidate = uint32_t(dot(a.fused[0], x, a.bias)) |
                         (uint32_t(dot(a.fused[1], x, a.bias)) << 8);
    output[i] = uint64_t(candidate) | (uint64_t(baseline) << 32);
}

int main() {
    hipDeviceProp_t device{};
    HIP(hipGetDeviceProperties(&device, 0));
    if (std::strncmp(device.gcnArchName, "gfx1151", 7) != 0) {
        std::fprintf(stderr, "Expected gfx1151, got %s\n", device.gcnArchName);
        return 1;
    }
    constexpr int count = 81 * 6561;
    std::vector<Prepared> prepared(81);
    std::vector<uint32_t> input(count), expected(count);
    std::vector<uint64_t> output(count);
    for (int ar = 0; ar < 81; ++ar) {
        int a[4]; trits(ar, 4, a);
        prepared[ar] = prepare(a);
        for (int bc = 0; bc < 6561; ++bc) {
            int t[8]; trits(bc, 8, t);
            int i = ar * 6561 + bc;
            input[i] = pack_input(t);
            expected[i] = reference(a, t, prepared[ar]);
        }
    }
    Prepared *dp = nullptr; uint32_t *di = nullptr; uint64_t *dout = nullptr;
    HIP(hipMalloc(&dp, prepared.size() * sizeof(Prepared)));
    HIP(hipMalloc(&di, input.size() * sizeof(uint32_t)));
    HIP(hipMalloc(&dout, output.size() * sizeof(uint64_t)));
    HIP(hipMemcpy(dp, prepared.data(), prepared.size() * sizeof(Prepared), hipMemcpyHostToDevice));
    HIP(hipMemcpy(di, input.data(), input.size() * sizeof(uint32_t), hipMemcpyHostToDevice));
    hipLaunchKernelGGL(check_maps, dim3((count + 255) / 256), dim3(256), 0, 0, dp, di, dout, count);
    HIP(hipGetLastError());
    HIP(hipMemcpy(output.data(), dout, output.size() * sizeof(uint64_t), hipMemcpyDeviceToHost));
    for (int i = 0; i < count; ++i) {
        if (uint32_t(output[i]) != expected[i] || uint32_t(output[i] >> 32) != expected[i]) {
            std::fprintf(stderr, "case %d: candidate=%u baseline=%u expected=%u\n", i,
                         uint32_t(output[i]), uint32_t(output[i] >> 32), expected[i]);
            return 3;
        }
    }
    HIP(hipFree(dp)); HIP(hipFree(di)); HIP(hipFree(dout));
    std::printf("{\"architecture\":\"%s\",\"matrix_cases\":%d,\"mismatches\":0,"
                "\"scope\":\"Native instruction correctness, not a timing benchmark\"}\n",
                device.gcnArchName, count);
}
