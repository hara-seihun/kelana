#include "toy2.hpp"
#include <algorithm>
#include <cstring>
#include <random>
#include <vector>

constexpr int stream_batch = 64;
constexpr int resident_batch = 16;
constexpr float warmup_ms = 150;
constexpr int samples = 11;
constexpr int columns = 8;
constexpr int resident_threads = 32768;
constexpr int resident_iterations = 256;

struct Data {
    int n;
    std::vector<uint32_t> base, fused, input, expected;
    explicit Data(int count) : n(count), base(6*count), fused(3*count), input(count), expected(count) {}
    void put(int i, int ar, int bc) {
        int a[4], t[8]; trits(ar, 4, a); trits(bc, 8, t);
        Prepared p = prepare(a);
        for (int k = 0; k < 4; ++k) base[k*n+i] = p.rows[k];
        for (int k = 0; k < 2; ++k) base[(k+4)*n+i] = p.biases[k];
        fused[i] = p.fused[0]; fused[n+i] = p.fused[1]; fused[2*n+i] = p.bias;
        input[i] = expand(pack_input(t));
        expected[i] = reference(a, t, p);
    }
};

template<class T> struct Device {
    T *p = nullptr;
    explicit Device(size_t n) { HIP(hipMalloc(&p, n*sizeof(T))); }
    explicit Device(const std::vector<T> &v) : Device(v.size()) {
        HIP(hipMemcpy(p, v.data(), v.size()*sizeof(T), hipMemcpyHostToDevice));
    }
    ~Device() { HIP(hipFree(p)); }
    Device(const Device&) = delete;
    Device& operator=(const Device&) = delete;
};

struct Uploaded {
    int n;
    Device<uint32_t> base, fused, input, output;
    explicit Uploaded(const Data &d) : n(d.n), base(d.base), fused(d.fused), input(d.input), output(d.n) {}
};

template<bool Packed>
__global__ void streaming(const uint32_t *__restrict__ coefficients,
                          const uint32_t *__restrict__ input,
                          uint32_t *__restrict__ output, int n) {
    int i = int(blockIdx.x*blockDim.x + threadIdx.x);
    if (i >= n) return;
    uint32_t w[Packed ? 3 : 6];
    #pragma unroll
    for (int k = 0; k < (Packed ? 3 : 6); ++k) w[k] = coefficients[k*n+i];
    output[i] = evaluate<Packed>(input[i], w);
}

template<bool Packed>
__global__ void resident(const uint32_t *__restrict__ coefficients,
                         const uint32_t *__restrict__ input,
                         uint32_t *__restrict__ output, int n, int iterations) {
    int i = int(blockIdx.x*blockDim.x + threadIdx.x);
    if (i >= resident_threads) return;
    uint32_t w[Packed ? 3 : 6], x[columns], sum[columns]{};
    #pragma unroll
    for (int k = 0; k < (Packed ? 3 : 6); ++k) w[k] = coefficients[k*n+i];
    #pragma unroll
    for (int j = 0; j < columns; ++j) x[j] = input[j*resident_threads+i];
    #pragma unroll 1
    for (int r = 0; r < iterations; ++r) {
        #pragma unroll
        for (int j = 0; j < columns; ++j) sum[j] += evaluate<Packed>(x[j], w);
    }
    #pragma unroll
    for (int j = 0; j < columns; ++j) output[j*resident_threads+i] = sum[j];
}

static void launch(const Uploaded &d, bool fused, bool replay) {
    const uint32_t *w = fused ? d.fused.p : d.base.p;
    int threads = replay ? resident_threads : d.n;
    dim3 grid((threads+255)/256), block(256);
    if (replay) {
        if (fused) resident<true><<<grid,block>>>(w, d.input.p, d.output.p, d.n, resident_iterations);
        else resident<false><<<grid,block>>>(w, d.input.p, d.output.p, d.n, resident_iterations);
    } else {
        if (fused) streaming<true><<<grid,block>>>(w, d.input.p, d.output.p, d.n);
        else streaming<false><<<grid,block>>>(w, d.input.p, d.output.p, d.n);
    }
    HIP(hipGetLastError());
}

static void validate(const Data &data, const Uploaded &device, bool replay) {
    std::vector<uint32_t> result(data.n);
    for (bool fused : {false,true}) {
        launch(device, fused, replay);
        HIP(hipMemcpy(result.data(), device.output.p, result.size()*sizeof(uint32_t), hipMemcpyDeviceToHost));
        for (int i = 0; i < data.n; ++i) {
            uint32_t expected = data.expected[i] * uint32_t(replay ? resident_iterations : 1);
            if (result[i] != expected) {
                std::fprintf(stderr, "%s/%s case %d: got %u, expected %u\n",
                    replay ? "resident" : "streaming", fused ? "packed" : "int4", i, result[i], expected);
                std::exit(3);
            }
        }
    }
}

static float measure(const Uploaded &d, bool fused, bool replay, hipEvent_t start, hipEvent_t end) {
    int launches = replay ? resident_batch : stream_batch;
    HIP(hipEventRecord(start));
    for (int i = 0; i < launches; ++i) launch(d, fused, replay);
    HIP(hipEventRecord(end)); HIP(hipEventSynchronize(end));
    float ms; HIP(hipEventElapsedTime(&ms, start, end));
    return ms / launches;
}

static float median(std::vector<float> values) {
    std::sort(values.begin(), values.end()); return values[values.size()/2];
}

static void array_json(const std::vector<float> &v) {
    std::printf("[");
    for (size_t i = 0; i < v.size(); ++i) std::printf("%s%.6f", i ? "," : "", v[i]);
    std::printf("]");
}

static void benchmark(const Data &data, bool replay) {
    Uploaded d(data);
    validate(data, d, replay);
    hipEvent_t start, end; HIP(hipEventCreate(&start)); HIP(hipEventCreate(&end));
    float warmed = 0;
    HIP(hipEventRecord(start));
    while (warmed < warmup_ms) {
        for (int i = 0; i < 32; ++i) { launch(d, false, replay); launch(d, true, replay); }
        HIP(hipEventRecord(end)); HIP(hipEventSynchronize(end));
        HIP(hipEventElapsedTime(&warmed, start, end));
    }
    std::vector<float> base, fused, ratios;
    for (int round = 0; round < samples; ++round) {
        float b, f;
        if (round % 2 == 0) { b = measure(d, false, replay, start, end); f = measure(d, true, replay, start, end); }
        else { f = measure(d, true, replay, start, end); b = measure(d, false, replay, start, end); }
        base.push_back(b); fused.push_back(f); ratios.push_back(b/f);
    }
    HIP(hipEventDestroy(start)); HIP(hipEventDestroy(end));
    validate(data, d, replay);
    double maps = replay ? double(resident_threads)*columns*resident_iterations : data.n;
    std::printf("{\"mode\":\"%s\",\"input_cases\":%d,\"maps_per_launch\":%.0f,"
                "\"replays\":%d,\"launches_per_sample\":%d,\"int4_ms\":", replay ? "register_replay" : "streaming",
                data.n, maps, replay ? resident_iterations : 1, replay ? resident_batch : stream_batch);
    array_json(base); std::printf(",\"packed_ms\":"); array_json(fused);
    std::printf(",\"int4_median_ms\":%.6f,\"packed_median_ms\":%.6f,"
                "\"median_paired_speedup\":%.6f,\"int4_Gmaps_s\":%.6f,\"packed_Gmaps_s\":%.6f,\"mismatches\":0}",
                median(base), median(fused), median(ratios), maps/median(base)/1e6, maps/median(fused)/1e6);
}

int main(int argc, char **argv) {
    uint32_t seed = argc > 1 ? uint32_t(std::strtoul(argv[1], nullptr, 10)) : 20260919;
    hipDeviceProp_t device{}; HIP(hipGetDeviceProperties(&device, 0));
    if (std::strncmp(device.gcnArchName, "gfx1151", 7) != 0) {
        std::fprintf(stderr, "Expected gfx1151, got %s\n", device.gcnArchName); return 1;
    }
    // The CPU reference uses scalar matrix arithmetic, not the fused dot expression.
    {
        Data exhaustive(81*6561);
        for (int ar = 0; ar < 81; ++ar)
            for (int bc = 0; bc < 6561; ++bc) exhaustive.put(ar*6561+bc, ar, bc);
        Uploaded d(exhaustive); validate(exhaustive, d, false);
    }
    int driver, runtime;
    HIP(hipDriverGetVersion(&driver)); HIP(hipRuntimeGetVersion(&runtime));
    std::printf("{\"device\":\"%s\",\"architecture\":\"%s\",\"compute_units\":%d,"
                "\"hip_driver\":%d,\"hip_runtime\":%d,\"seed\":%u,\"samples\":%d,\"warmup_target_ms\":150,"
                "\"exhaustive_cases_per_implementation\":531441,\"packing_timed\":false,\"results\":[",
                device.name, device.gcnArchName, device.multiProcessorCount, driver, runtime, seed, samples);
    std::mt19937 rng(seed);
    std::uniform_int_distribution<int> random_a(0,80), random_bc(0,6560);
    {
        Data data(1<<20);
        for (int i = 0; i < data.n; ++i) {
            int a = random_a(rng), bc = random_bc(rng);
            data.put(i, a, bc);
        }
        benchmark(data, false);
    }
    std::printf(",");
    {
        Data data(resident_threads*columns);
        for (int i = 0; i < resident_threads; ++i) {
            int a = random_a(rng);
            for (int j = 0; j < columns; ++j) data.put(j*resident_threads+i, a, random_bc(rng));
        }
        benchmark(data, true);
    }
    std::printf("]}\n");
}
