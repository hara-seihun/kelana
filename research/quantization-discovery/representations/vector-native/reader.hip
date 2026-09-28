#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <stdexcept>
#include <string>
#include <vector>

constexpr int K = 1024, H = 3072, B = 8;
#define HIP(call) do { auto e = call; if (e != hipSuccess) throw std::runtime_error(std::string(#call) + ": " + hipGetErrorString(e)); } while (0)

std::string directory;
template<class T> std::vector<T> load(const char* name, size_t count) {
    std::ifstream f(directory + "/" + name, std::ios::binary);
    if (!f) throw std::runtime_error(name);
    std::vector<T> result(count);
    f.read(reinterpret_cast<char*>(result.data()), count * sizeof(T));
    if (f.gcount() != static_cast<std::streamsize>(count * sizeof(T)) || f.peek() != EOF) throw std::runtime_error(std::string("size mismatch: ") + name);
    return result;
}
template<class T> struct Device {
    T* p;
    explicit Device(size_t count) { HIP(hipMalloc(&p, count * sizeof(T))); }
    ~Device() { hipFree(p); }
    Device(const Device&) = delete;
    void from(const std::vector<T>& v) { HIP(hipMemcpy(p, v.data(), v.size() * sizeof(T), hipMemcpyHostToDevice)); }
};

// One 32-lane gfx1151 wave owns a hidden row. Each lane consumes 32 pairs.
// The selected table entry holds the already-gained gate/up pair; the gain is not reapplied.
__global__ void projection(const uint8_t* __restrict__ indices,
                           const __half2* __restrict__ pairs,
                           const __half* __restrict__ scales,
                           const float* __restrict__ x, float* __restrict__ out,
                           int rows, int mode) {
    int row = blockIdx.x, batch = blockIdx.y, lane = threadIdx.x;
    float gate = 0, up = 0;
    const float* input = x + batch * K;
    for (int k = lane; k < K; k += 32) {
        float a, b;
        if (mode == 2) {
            __half2 v = pairs[row * K + k];
            a = __half2float(__low2half(v));
            b = __half2float(__high2half(v));
        } else {
            uint8_t code = indices[row * K + k];
            if (mode != 1) {
                __half2 v = pairs[code];
                a = __half2float(__low2half(v));
                b = __half2float(__high2half(v));
            } else {
                float s = __half2float(scales[code >> 4]);
                int ga = ((code >> 2) & 3) * 2 - 3;
                int ub = (code & 3) * 2 - 3;
                a = __half2float(__float2half_rn(s * ga));
                b = __half2float(__float2half_rn(s * ub));
            }
        }
        float xv = input[k];
        gate = fmaf(xv, a, gate);
        up = fmaf(xv, b, up);
    }
    for (int delta = 16; delta > 0; delta >>= 1) {
        gate += __shfl_down(gate, delta, 32);
        up += __shfl_down(up, delta, 32);
    }
    if (lane == 0) out[batch * rows + row] = (gate / (1.0f + expf(-gate))) * up;
}

struct Stats { double median, min, max; };
Stats stats(std::vector<float> samples) {
    std::sort(samples.begin(), samples.end());
    return {samples[samples.size()/2], samples.front(), samples.back()};
}

int main(int argc, char** argv) {
    try {
        if (argc != 2) throw std::runtime_error("usage: reader BUILD_DIR");
        directory = argv[1];
        auto idxP = load<uint8_t>("polar.u8", H*K);
        auto idxS = load<uint8_t>("scalar.u8", H*K);
        auto idxL = load<uint8_t>("learned.u8", H*K);
        auto polar = load<__half2>("polar.f16", 256);
        auto learned = load<__half2>("learned.f16", 256);
        auto scales = load<__half>("scalar-scales.f16", 16);
        auto expanded = load<__half2>("original.f16", H*K);
        auto x = load<float>("inputs.f32", B*K);
        std::array<std::vector<float>,4> reference = {load<float>("reference-polar.f32", B*H),
             load<float>("reference-scalar.f32", B*H), load<float>("reference-original.f32", B*H),
             load<float>("reference-learned.f32", B*H)};
        auto gain = load<__half>("gain.f16", 1);
        Device<uint8_t> dp(H*K), ds(H*K), dl(H*K);
        Device<__half2> dt(256), de(H*K), dlt(256);
        Device<__half> dsc(16);
        Device<float> dx(B*K), dy(B*H);
        dp.from(idxP); ds.from(idxS); dl.from(idxL); de.from(expanded); dlt.from(learned); dsc.from(scales); dx.from(x);
        HIP(hipDeviceSynchronize());
        const double radii[8] = {.22,.46,.72,1.04,1.46,2.02,2.80,4.0};
        std::vector<__half2> prepared(256);
        auto begin = std::chrono::steady_clock::now();
        for (int r=0; r<8; r++) for (int a=0; a<32; a++) {
            double angle = a * (2.0 * 3.14159265358979323846 / 32.0);
            prepared[r*32+a] = __halves2half2(__float2half_rn(static_cast<float>(radii[r] * __half2float(gain[0]) * std::cos(angle))),
                                               __float2half_rn(static_cast<float>(radii[r] * __half2float(gain[0]) * std::sin(angle))));
        }
        int table_bit_differences = 0;
        for (int i=0; i<256; i++) if (std::memcmp(&prepared[i], &polar[i], sizeof(__half2))) table_bit_differences++;
        if (table_bit_differences != 0) throw std::runtime_error("prepared polar table differs from charged image");
        dt.from(polar);
        HIP(hipDeviceSynchronize());
        auto end = std::chrono::steady_clock::now();
        double preparation_us = std::chrono::duration<double,std::micro>(end-begin).count();
        hipEvent_t start, stop; HIP(hipEventCreate(&start)); HIP(hipEventCreate(&stop));
        std::array<std::vector<float>,4> results;
        std::cout << std::setprecision(9) << "{\"preparation_host_and_upload_us\":" << preparation_us
                  << ",\"table_f16_pair_differences\":" << table_bit_differences << ",\"cases\":[";
        for (int batch : {1, 8}) {
            for (int mode=0; mode<4; mode++) {
                for (int warm=0;warm<8;warm++) projection<<<dim3(H,batch),32>>>(mode==0?dp.p:mode==3?dl.p:ds.p, mode==0?dt.p:mode==2?de.p:mode==3?dlt.p:nullptr, dsc.p, dx.p, dy.p,H,mode);
                HIP(hipDeviceSynchronize());
                projection<<<dim3(H,batch),32>>>(mode==0?dp.p:mode==3?dl.p:ds.p, mode==0?dt.p:mode==2?de.p:mode==3?dlt.p:nullptr, dsc.p, dx.p, dy.p,H,mode);
                results[mode].resize(batch * H);
                HIP(hipMemcpy(results[mode].data(), dy.p, results[mode].size()*sizeof(float), hipMemcpyDeviceToHost));
            }
            for (int mode=0;mode<4;mode++) {
                double error=0, norm=0;
                for (size_t i=0;i<results[mode].size();i++) {
                    if (!std::isfinite(results[mode][i])) throw std::runtime_error("nonfinite native output");
                    double delta=results[mode][i]-reference[mode][i];
                    error+=delta*delta;
                    norm+=double(reference[mode][i])*reference[mode][i];
                }
                if (!(norm > 0 && std::sqrt(error/norm) <= 1e-5))
                    throw std::runtime_error("native output failed independent FP32 reference before timing");
            }
            auto numerical = [&](int mode) {
                double squared=0, norm=0, max_abs=0;
                for (size_t i=0; i<results[mode].size();i++) {
                    double delta=results[mode][i]-results[2][i];
                    squared+=delta*delta; norm+=double(results[2][i])*results[2][i]; max_abs=std::max(max_abs,std::abs(delta));
                }
                return std::array<double,2>{std::sqrt(squared/norm),max_abs};
            };
            std::array<std::vector<float>,4> timings;
            for (int round=0;round<11;round++) {
                for (int turn=0;turn<4;turn++) {
                    int mode = (turn + round) % 4;
                    HIP(hipEventRecord(start));
                    for (int i=0;i<32;i++) projection<<<dim3(H,batch),32>>>(mode==0?dp.p:mode==3?dl.p:ds.p, mode==0?dt.p:mode==2?de.p:mode==3?dlt.p:nullptr, dsc.p, dx.p, dy.p,H,mode);
                    HIP(hipEventRecord(stop)); HIP(hipEventSynchronize(stop));
                    float elapsed; HIP(hipEventElapsedTime(&elapsed,start,stop)); timings[mode].push_back(elapsed*1000.f/32.f);
                }
            }
            for (int mode=0;mode<4;mode++) {
                auto s=stats(timings[mode]); auto n=numerical(mode);
                double reference_squared=0, reference_norm=0, reference_max=0;
                for (size_t i=0;i<results[mode].size();i++) {
                    double delta=results[mode][i]-reference[mode][i];
                    reference_squared+=delta*delta;
                    reference_norm+=double(reference[mode][i])*reference[mode][i];
                    reference_max=std::max(reference_max,std::abs(delta));
                }
                if (batch!=1 || mode!=0) std::cout << ',';
                std::cout << "{\"batch\":" << batch << ",\"method\":\"" << (mode==0?"polar":mode==1?"scalar":mode==2?"expanded_fp16":"learned_pair")
                          << "\",\"kernel_us_median\":" << s.median << ",\"kernel_us_min\":" << s.min << ",\"kernel_us_max\":" << s.max
                          << ",\"relative_rms_to_original\":" << n[0] << ",\"max_abs_to_original\":" << n[1]
                          << ",\"relative_rms_to_numpy\":" << std::sqrt(reference_squared/reference_norm)
                          << ",\"max_abs_to_numpy\":" << reference_max << '}';
            }
        }
        std::cout << "]}\n";
        HIP(hipEventDestroy(start)); HIP(hipEventDestroy(stop));
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
