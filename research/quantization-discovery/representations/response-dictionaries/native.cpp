#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <immintrin.h>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>

using Clock = std::chrono::steady_clock;

template<class T> std::vector<T> load(const std::string& path) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file) std::abort();
    size_t bytes = file.tellg();
    if (bytes % sizeof(T)) std::abort();
    std::vector<T> result(bytes / sizeof(T));
    file.seekg(0);
    file.read(reinterpret_cast<char*>(result.data()), bytes);
    if (!file) std::abort();
    return result;
}

int main(int argc, char** argv) {
    if (argc != 5) return 2;
    std::string dir = argv[1];
    int rows = std::atoi(argv[2]), codes = std::atoi(argv[3]), repetitions = std::atoi(argv[4]);
    constexpr int chunks = 16, coordinates = 8;
    int bits = codes == 16 ? 4 : codes == 64 ? 6 : 0;
    if (!bits || rows <= 0 || repetitions <= 0) return 2;
    auto packed = load<uint8_t>(dir + "/ids.bin");
    auto dictionary = load<uint16_t>(dir + "/dictionary.bin");
    auto scales = load<uint16_t>(dir + "/scales.bin");
    auto inputs = load<int8_t>(dir + "/queries.bin");
    auto expected = load<float>(dir + "/expected.bin");
    if (packed.size() != (size_t(rows)*chunks*bits+7)/8 ||
        dictionary.size() != size_t(chunks*codes*coordinates) ||
        scales.size() != size_t(rows) || inputs.size()%128 || expected.size() != size_t(rows)*(inputs.size()/128)) return 3;
    std::vector<float> table(chunks*codes), output(rows);
    std::vector<double> samples;
    double checksum = 0, max_error = 0;
    const int queries = inputs.size()/128;
    for (int rep = 0; rep < repetitions; rep++) {
        for (int query = 0; query < queries; query++) {
            auto start = Clock::now();
            for (int j = 0; j < chunks; j++)
                for (int c = 0; c < codes; c++) {
                    float sum = 0;
                    for (int a = 0; a < coordinates; a++)
                        sum += _cvtsh_ss(dictionary[(j*codes+c)*8+a]) * inputs[query*128+j*8+a];
                    table[j*codes+c] = sum;
                }
            for (int row = 0; row < rows; row++) {
                float sum = 0;
                for (int j = 0; j < chunks; j++) {
                    size_t bit = size_t(row*chunks+j)*bits;
                    unsigned val = packed[bit/8];
                    if (bit%8+bits > 8) val |= unsigned(packed[bit/8+1]) << 8;
                    sum += table[j*codes+((val >> (bit%8)) & (codes-1))];
                }
                output[row] = sum*_cvtsh_ss(scales[row]);
            }
            auto end = Clock::now();
            samples.push_back(std::chrono::duration<double, std::micro>(end-start).count());
            checksum += output[(rep*queries+query)%rows];
            if (rep == 0)
                for (int row = 0; row < rows; row++)
                    max_error = std::max(max_error, double(std::abs(output[row]-expected[query*rows+row])));
        }
    }
    std::sort(samples.begin(), samples.end());
    std::cout << "{\"median_fresh_microseconds\":" << samples[samples.size()/2]
              << ",\"minimum_fresh_microseconds\":" << samples.front()
              << ",\"max_absolute_output_error\":" << max_error
              << ",\"checksum\":" << checksum << "}\n";
}
