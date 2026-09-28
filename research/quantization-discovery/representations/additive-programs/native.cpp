#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <string>
#include <vector>

constexpr int N = 128, K = 128, G = 8, Q = 64;

template <typename T> std::vector<T> load(const std::string& file) {
    std::ifstream input(file, std::ios::binary | std::ios::ate);
    if (!input || input.tellg() < 0 || static_cast<size_t>(input.tellg()) % sizeof(T)) std::abort();
    std::vector<T> data(static_cast<size_t>(input.tellg()) / sizeof(T));
    input.seekg(0);
    input.read(reinterpret_cast<char*>(data.data()), data.size() * sizeof(T));
    if (!input) std::abort();
    return data;
}

int code(const std::vector<uint8_t>& packed, int offset, int width) {
    int bit = offset * width;
    uint32_t word = packed[bit / 8];
    if (bit / 8 + 1 < static_cast<int>(packed.size())) word |= uint32_t(packed[bit / 8 + 1]) << 8;
    return (word >> (bit % 8)) & ((1 << width) - 1);
}

int main(int argc, char** argv) {
    if (argc != 2) return 2;
    std::string dir = argv[1];
    auto scalar = load<uint8_t>(dir + "/scalar5.bin");
    auto ss = load<float>(dir + "/scalar5-scale.bin");
    auto base = load<uint8_t>(dir + "/base.bin");
    auto residual = load<uint8_t>(dir + "/residual.bin");
    auto as = load<float>(dir + "/additive-scale.bin");
    auto inputs = load<int8_t>(dir + "/queries.bin");
    if (scalar.size() != N*K*5/8 || ss.size() != N || base.size() != N/G*K ||
        residual.size() != N*K/2 || as.size() != N/G || inputs.size() != Q*K) std::abort();
    double sums[2] = {0, 0};
    double elapsed[2] = {0, 0};
    for (int round = 0; round < 8; ++round) {
        for (int trial = 0; trial < 2; ++trial) {
            int arm = (trial + round) % 2;
            auto start = std::chrono::steady_clock::now();
            double checksum = 0;
            for (int repetition = 0; repetition < 32; ++repetition) {
                for (int query = 0; query < Q; ++query) {
                    const int8_t* x = inputs.data() + query * K;
                    int common[N/G] = {};
                    if (arm == 1) {
                        for (int group = 0; group < N/G; ++group)
                            for (int col = 0; col < K; ++col)
                                common[group] += (int(base[group*K+col]) - 128) * x[col];
                    }
                    for (int row = 0; row < N; ++row) {
                        int dot = arm == 1 ? common[row/G] : 0;
                        for (int col = 0; col < K; ++col)
                            dot += (code(arm ? residual : scalar, row*K+col, arm ? 4 : 5) - (arm ? 8 : 16)) * x[col];
                        checksum += double(dot) * double(arm ? as[row/G] : ss[row]);
                    }
                }
            }
            auto end = std::chrono::steady_clock::now();
            elapsed[arm] += std::chrono::duration<double>(end-start).count();
            sums[arm] += checksum;
        }
    }
    std::printf("{\"scalar5_us_per_query\":%.6f,\"additive_us_per_query\":%.6f,\"scalar5_checksum\":%.9g,\"additive_checksum\":%.9g}\n",
                elapsed[0]*1e6/(8*32*Q), elapsed[1]*1e6/(8*32*Q), sums[0], sums[1]);
}
