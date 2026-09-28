// Interleaved instruction-rate comparison for the register-resident PERM observer.
//
// This replaces the sequential best-of-N component timing that the first version of this
// directory used. Two things it fixes:
//
//   1. The IU4 baseline is swept over the number of independent accumulator chains. Two
//      dependent chains can measure WMMA latency rather than WMMA issue rate, which would
//      understate the baseline and flatter the observer. The chain count that produces the
//      highest rate is the one the comparison uses.
//   2. Variants are measured in randomized interleaved rounds with the shared telemetry
//      recorder, in `kelana-batch-bench/2` format, so `bench/paired_analysis.py` consumes the
//      raw samples directly. Every variant is normalized to the same number of MAC per call, so
//      a round speed ratio from that analysis is a rate ratio.
//
// Everything measured here is register-resident: no memory traffic, no LDS, no epilogue. These
// are rates for the tested schedules, not a bound on every kernel that could use this map.
#include "kernels.hpp"
#include "../geometry.hpp"
#include "../bench/telemetry.hpp"
#define CHECK(c) do { hipError_t e_ = (c); if (e_ != hipSuccess) { \
    printf("HIP error %s at line %d\n", hipGetErrorString(e_), __LINE__); exit(1);} } while (0)
#include "../api.hpp"          // timing.hpp is typed on the shared Candidate interface
#include "../bench/timing.hpp" // reused for Block and blocks_json, not its Candidate loop
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <functional>
#include <numeric>
#include <random>
#include <algorithm>

template <class T> struct Dev {
    T *p = nullptr;
    explicit Dev(size_t n) { hipMalloc(&p, n * sizeof(T)); hipMemset(p, 0, n * sizeof(T)); }
    ~Dev() { hipFree(p); }
};

struct Variant {
    std::string name;
    std::string description;
    double mac_per_wave_per_iter;     // useful ternary MAC one wave performs per outer iteration
    double instr_per_wave_per_iter;   // model count; assembly counts are in count_instructions.py
    int iters = 0;                    // set so every variant does the same MAC per call
    std::function<void(int, hipStream_t)> launch;
};

int main(int argc, char **argv) {
    if (!std::getenv("KELANA_GPU_RESEARCH_LOCK")) {
        std::fprintf(stderr, "Use ../hardware-run for GPU work\n");
        return 1;
    }
    int rounds = 12, calls = 96, warmup = 8, ramp_ms = 2000, wps = 8;
    unsigned seed = 44711u;
    const char *json_path = nullptr;
    for (int i = 1; i < argc; ++i) {
        auto next = [&](int &v) { if (i + 1 < argc) v = atoi(argv[++i]); };
        if (!strcmp(argv[i], "--rounds")) next(rounds);
        else if (!strcmp(argv[i], "--calls")) next(calls);
        else if (!strcmp(argv[i], "--warmup")) next(warmup);
        else if (!strcmp(argv[i], "--ramp-ms")) next(ramp_ms);
        else if (!strcmp(argv[i], "--waves-per-simd")) next(wps);
        else if (!strcmp(argv[i], "--seed")) { int s = 0; next(s); seed = unsigned(s); }
        else if (!strcmp(argv[i], "--json") && i + 1 < argc) json_path = argv[++i];
    }

    hipDeviceProp_t prop{};
    CHECK(hipGetDeviceProperties(&prop, 0));
    const auto geom = kelana_batch::geometry(prop);
    const int simds = geom.simds, block_waves = 4, threads = block_waves * 32;
    const int grid = simds * wps / block_waves;
    const double waves = double(grid) * block_waves;
    printf("device %s, %d WGP, %d CU, %d SIMD32, %d waves/SIMD\n", prop.gcnArchName, geom.wgps,
           geom.cus, simds, wps);

    Dev<int2v> dA(32), dB(32);
    Dev<unsigned> din(128), dou(1 << 16);
    Dev<int> doi(1 << 16);
    {
        std::vector<unsigned> h(128);
        unsigned rng = 7u;
        for (auto &v : h) { rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5; v = rng & 0x07070707u; }
        CHECK(hipMemcpy(din.p, h.data(), h.size() * 4, hipMemcpyHostToDevice));
    }

    std::vector<Variant> v;
    auto add_iu4 = [&](int chains, auto kernel) {
        v.push_back({"iu4-wmma-chains" + std::to_string(chains),
                     "v_wmma_i32_16x16x16_iu4 with " + std::to_string(chains) +
                         " independent accumulator chains",
                     8.0 * chains * 4096.0, 8.0 * chains,
                     0, [=, this_A = dA.p, this_B = dB.p, o = doi.p](int it, hipStream_t s) {
                         kernel<<<grid, threads, 0, s>>>(this_A, this_B, o, it);
                     }});
    };
    add_iu4(1, k_iu4<1>); add_iu4(2, k_iu4<2>); add_iu4(4, k_iu4<4>); add_iu4(8, k_iu4<8>);

    v.push_back({"perm-issue-ceiling",
                 "8 independent v_perm_b32 per group, results never accumulated",
                 32.0 * 32.0 * 8.0, 32.0,
                 0, [=, i = din.p, o = dou.p](int it, hipStream_t s) {
                     k_perm_raw<<<grid, threads, 0, s>>>(i, o, it);
                 }});

    auto add_core = [&](int rq, int t, auto kernel) {
        v.push_back({"core-rq" + std::to_string(rq) + "-tok" + std::to_string(t),
                     "perm pairs accumulated by v_add3_u32, tables and selectors handed over",
                     32.0 * 16.0 * rq * t, 3.0 * rq * t,
                     0, [=, i = din.p, o = dou.p](int it, hipStream_t s) {
                         kernel<<<grid, threads, 0, s>>>(i, o, it);
                     }});
    };
    add_core(8, 4, k_core<8, 4>);
    add_core(16, 4, k_core<16, 4>);

    auto add_drain = [&](int rq, int t, auto kernel) {
        v.push_back({"freetables-rq" + std::to_string(rq) + "-tok" + std::to_string(t),
                     "adds the byte-lane drain a 128-input block forces; table build deleted",
                     32.0 * 64.0 * rq * t, 16.0 * rq * t,
                     0, [=, i = din.p, o = dou.p](int it, hipStream_t s) {
                         kernel<<<grid, threads, 0, s>>>(i, o, it);
                     }});
    };
    add_drain(8, 4, k_drain<8, 4>);

    auto add_full = [&](int rq, int t, auto kernel) {
        v.push_back({"full-rq" + std::to_string(rq) + "-tok" + std::to_string(t),
                     "drain plus online table construction from biased activation bytes",
                     32.0 * 64.0 * rq * t, 16.0 * rq * t + 40.0 * t,
                     0, [=, i = din.p, o = dou.p](int it, hipStream_t s) {
                         kernel<<<grid, threads, 0, s>>>(i, o, it);
                     }});
    };
    add_full(8, 4, k_full<8, 4>);
    add_full(16, 2, k_full<16, 2>);

    // Equal MAC per call, so a round speed ratio is a rate ratio.
    const double target_mac_per_call = 3.0e10;
    for (auto &x : v) {
        x.iters = std::max(1, int(target_mac_per_call / (x.mac_per_wave_per_iter * waves) + 0.5));
        printf("%-24s iters %6d  MAC/call %.3e  model MAC/lane/instr %6.2f\n", x.name.c_str(),
               x.iters, x.mac_per_wave_per_iter * x.iters * waves,
               x.mac_per_wave_per_iter / x.instr_per_wave_per_iter / 32.0);
    }

    hipStream_t stream;
    CHECK(hipStreamCreate(&stream));
    kbtelemetry::Recorder recorder(prop.pciDomainID, prop.pciBusID, prop.pciDeviceID);
    const std::string clients_before = kbtelemetry::client_snapshot();

    // Untimed rotating ramp, matching the shared driver: a call-count warmup does not outlast
    // the idle-to-load clock ramp.
    {
        const auto ramp_end = kbtelemetry::now_ns() + (long long)ramp_ms * 1000000;
        size_t which = 0;
        while (kbtelemetry::now_ns() < ramp_end) {
            auto &x = v[which++ % v.size()];
            for (int k = 0; k < 4; ++k) x.launch(x.iters, stream);
            CHECK(hipStreamSynchronize(stream));
        }
    }

    std::vector<kbtiming::Samples> samples(v.size());
    std::vector<size_t> order(v.size());
    std::iota(order.begin(), order.end(), 0);
    std::mt19937 rng(seed);
    for (int round = 0; round < rounds; ++round) {
        std::shuffle(order.begin(), order.end(), rng);
        const int count = calls / rounds + (round < calls % rounds);
        for (size_t position = 0; position < order.size(); ++position) {
            auto &x = v[order[position]];
            auto &r = samples[order[position]];
            for (int k = 0; k < (round == 0 ? warmup : 2); ++k) x.launch(x.iters, stream);
            CHECK(hipStreamSynchronize(stream));
            CHECK(hipGetLastError());
            std::vector<hipEvent_t> begin(count), end(count);
            for (int k = 0; k < count; ++k) { CHECK(hipEventCreate(&begin[k])); CHECK(hipEventCreate(&end[k])); }
            kbtiming::Block block{round, int(position), int(r.ms.size()), count,
                                  kbtelemetry::now_ns(), 0, 0};
            for (int k = 0; k < count; ++k) {
                CHECK(hipEventRecord(begin[k], stream));
                x.launch(x.iters, stream);
                CHECK(hipEventRecord(end[k], stream));
            }
            CHECK(hipStreamSynchronize(stream));
            CHECK(hipGetLastError());
            block.end_ns = kbtelemetry::now_ns();
            block.wall_ms = (block.end_ns - block.begin_ns) * 1e-6;
            r.wall_ms += block.wall_ms;
            r.blocks.push_back(block);
            for (int k = 0; k < count; ++k) {
                float ms = 0; CHECK(hipEventElapsedTime(&ms, begin[k], end[k]));
                r.ms.push_back(ms);
                CHECK(hipEventDestroy(begin[k])); CHECK(hipEventDestroy(end[k]));
            }
        }
    }
    const std::string trace = recorder.json();
    const std::string clients_after = kbtelemetry::client_snapshot();

    auto median = [](std::vector<double> x) {
        std::sort(x.begin(), x.end());
        return x.empty() ? 0.0 : x[x.size() / 2];
    };
    double iu4_best = 0;
    std::vector<double> rate(v.size());
    for (size_t i = 0; i < v.size(); ++i) {
        const double mac = v[i].mac_per_wave_per_iter * v[i].iters * waves;
        rate[i] = mac / (median(samples[i].ms) * 1e6) / simds;
        if (v[i].name.rfind("iu4-wmma", 0) == 0) iu4_best = std::max(iu4_best, rate[i]);
    }
    printf("\n%-24s %14s %12s %10s\n", "variant", "MAC/ns/SIMD", "median ms", "of best iu4");
    for (size_t i = 0; i < v.size(); ++i)
        printf("%-24s %14.1f %12.4f %10.3f\n", v[i].name.c_str(), rate[i], median(samples[i].ms),
               rate[i] / iu4_best);

    if (json_path) {
        std::string j = "{\n  \"format\": \"kelana-batch-bench/2\",\n";
        j += "  \"experiment\": \"register-observer instruction rates, register-resident operands\",\n";
        j += "  \"scope\": \"Rates for the tested schedules with all operands in registers. No "
             "memory traffic, LDS, scales or epilogue. Calls are normalized to equal useful "
             "ternary MAC, so a paired round speed ratio is a rate ratio. Not a bound on every "
             "kernel that could use this map.\",\n";
        j += "  \"device\": \"" + std::string(prop.gcnArchName) + "\",\n";
        j += "  \"wgps\": " + std::to_string(geom.wgps) + ", \"cus\": " + std::to_string(geom.cus) +
             ", \"simds\": " + std::to_string(simds) + ",\n";
        j += "  \"waves_per_simd\": " + std::to_string(wps) + ", \"rounds\": " + std::to_string(rounds) +
             ", \"calls_per_variant\": " + std::to_string(calls) + ", \"warmup\": " + std::to_string(warmup) +
             ", \"ramp_ms\": " + std::to_string(ramp_ms) + ", \"seed\": " + std::to_string(seed) + ",\n";
        j += "  \"gpu_clients_before\": " + clients_before + ",\n  \"runs\": [\n";
        char buf[1024];
        for (size_t i = 0; i < v.size(); ++i) {
            const double mac = v[i].mac_per_wave_per_iter * v[i].iters * waves;
            snprintf(buf, sizeof buf,
                     "%s    {\n      \"candidate\": \"%s\",\n      \"rows\": 1,\n"
                     "      \"description\": \"%s\",\n      \"iters_per_call\": %d,\n"
                     "      \"mac_per_call\": %.6e,\n      \"model_mac_per_lane_per_instruction\": %.4f,\n"
                     "      \"mac_per_ns_per_simd_at_median\": %.4f,\n      \"ms_median\": %.6f,\n",
                     i ? ",\n" : "", v[i].name.c_str(), v[i].description.c_str(), v[i].iters, mac,
                     v[i].mac_per_wave_per_iter / v[i].instr_per_wave_per_iter / 32.0,
                     rate[i], median(samples[i].ms));
            j += buf;
            j += "      \"timing_blocks\": " + kbtiming::blocks_json(samples[i]) + ",\n";
            j += "      \"ms_samples\": [";
            for (size_t k = 0; k < samples[i].ms.size(); ++k) {
                snprintf(buf, sizeof buf, "%s%.6f", k ? "," : "", samples[i].ms[k]);
                j += buf;
            }
            j += "]\n    }";
        }
        j += "\n  ],\n  \"telemetry\": [{\"rows\": 1, \"trace\": " + trace + "}],\n";
        j += "  \"gpu_clients_after\": " + clients_after + "\n}\n";
        FILE *f = fopen(json_path, "w");
        if (f) { fwrite(j.data(), 1, j.size(), f); fclose(f); printf("wrote %s\n", json_path); }
    }
    CHECK(hipStreamDestroy(stream));
    return 0;
}
