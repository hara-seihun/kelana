#include <algorithm>
#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>

// All finite IEEE754 binary32 values times 2^149 are integers. A nonzero
// 2006-row minor modulo 251 certifies independence of all distinct down
// columns of the eight co-routed experts over the rationals/reals.
constexpr int P = 251, OUT = 2048;

int main(int argc, char **argv) {
    if (argc != 2) {
        std::cerr << "usage: witness distinct-down-columns.f32\n";
        return 2;
    }
    try {
        std::ifstream input(argv[1], std::ios::binary | std::ios::ate);
        if (!input || input.tellg() <= 0 || size_t(input.tellg()) % (OUT*4))
            throw std::runtime_error("expected FP32 column vectors of length 2048");
        const size_t rows = size_t(input.tellg())/(OUT*4);
        if (rows > OUT) throw std::runtime_error("more columns than output dimension");
        input.seekg(0);
        std::array<uint8_t, 256> pow2{};
        pow2[0] = 1;
        for (int i = 1; i < 256; ++i) pow2[i] = pow2[i-1]*2 % P;
        std::array<uint8_t, P> inv{};
        for (int x = 1; x < P; ++x)
            for (int y = 1; y < P; ++y)
                if (x*y % P == 1) inv[x] = y;
        std::vector<uint8_t> matrix(rows*OUT);
        std::array<uint32_t, OUT> raw{};
        for (size_t row = 0; row < rows; ++row) {
            input.read(reinterpret_cast<char *>(raw.data()), OUT*4);
            if (!input) throw std::runtime_error("truncated decoded columns");
            for (int out = 0; out < OUT; ++out) {
                const uint32_t bits = raw[out];
                const int exp = (bits >> 23) & 255;
                if (exp == 255) throw std::runtime_error("nonfinite FP32 coefficient");
                const uint32_t mantissa = exp ? (1u << 23) | (bits & 0x7fffff) : bits & 0x7fffff;
                const int v = (mantissa % P) * pow2[exp ? exp - 1 : 0] % P;
                matrix[row*OUT+out] = (bits >> 31) ? (P-v)%P : v;
            }
        }
        std::vector<uint8_t> diff(size_t(P)*P*P);
        for (int factor = 0; factor < P; ++factor)
            for (int pivot = 0; pivot < P; ++pivot)
                for (int old = 0; old < P; ++old)
                    diff[(size_t(factor)*P+pivot)*P+old] = (old-factor*pivot%P+P)%P;
        size_t rank = 0;
        int pivot_product = 1;
        for (int col = 0; col < OUT && rank < rows; ++col) {
            size_t pivot_row = rank;
            while (pivot_row < rows && !matrix[pivot_row*OUT+col]) ++pivot_row;
            if (pivot_row == rows) continue;
            if (pivot_row != rank) {
                for (int k = col; k < OUT; ++k)
                    std::swap(matrix[pivot_row*OUT+k], matrix[rank*OUT+k]);
                pivot_product = (P-pivot_product)%P;
            }
            const uint8_t *pivot = matrix.data()+rank*OUT;
            const int value = pivot[col];
            pivot_product = pivot_product*value%P;
            const int inverse = inv[value];
            for (size_t row = rank+1; row < rows; ++row) {
                uint8_t *dst = matrix.data()+row*OUT;
                const int factor = dst[col]*inverse%P;
                dst[col] = 0;
                if (!factor) continue;
                const uint8_t *table = diff.data()+size_t(factor)*P*P;
                for (int k = col+1; k < OUT; ++k)
                    dst[k] = table[size_t(pivot[k])*P+dst[k]];
            }
            ++rank;
        }
        std::cout << "prime=251 distinct_columns=" << rows << " output_width=" << OUT
                  << " rank_mod_251=" << rank << " pivot_product_mod_251=" << pivot_product << '\n';
        return rank == rows ? 0 : 1;
    } catch (const std::exception &ex) {
        std::cerr << ex.what() << '\n';
        return 2;
    }
}
