#include <algorithm>
#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>

// BF16 finite values are integers after multiplying by 2^133.
// A nonzero minor modulo an odd prime is a nonzero minor over the reals.
constexpr int prime = 251;
static int residue(uint16_t bits) {
    int exponent = (bits >> 7) & 255;
    int fraction = bits & 127;
    if (exponent == 255) throw std::runtime_error("nonfinite BF16 weight");
    int mantissa = exponent ? 128 + fraction : fraction;
    int power = exponent ? exponent - 1 : 0;
    int two_power = 1;
    for (int i = 0; i < power; ++i) two_power = (two_power * 2) % prime;
    int value = (mantissa * two_power) % prime;
    return bits & 0x8000 ? (prime - value) % prime : value;
}

int main(int argc, char **argv) {
    if (argc < 4 || argc > 11) {
        std::cerr << "usage: rank down_proj.bf16 rows(1..2048) expert0 [expert1 ... expert7]\n";
        return 2;
    }
    try {
        int rows = std::stoi(argv[2]);
        int experts = argc - 3;
        int cols = experts * 512;
        if (rows < 1 || rows > 2048 || cols < rows) throw std::runtime_error("need rows <= experts*512 <= 4096");
        std::ifstream input(argv[1], std::ios::binary);
        if (!input) throw std::runtime_error("cannot open BF16 bank");
        std::vector<uint16_t> matrix(size_t(rows) * cols);
        std::array<uint16_t, 512> raw;
        for (int e = 0; e < experts; ++e) {
            int index = std::stoi(argv[3 + e]);
            if (index < 0 || index >= 16) throw std::runtime_error("expert outside first sixteen");
            for (int r = 0; r < rows; ++r) {
                input.seekg((size_t(index) * 2048 + r) * 512 * 2);
                input.read(reinterpret_cast<char *>(raw.data()), 1024);
                if (!input) throw std::runtime_error("truncated BF16 bank");
                for (int c = 0; c < 512; ++c)
                    matrix[size_t(r) * cols + e * 512 + c] = residue(raw[c]);
            }
        }
        std::array<int, prime> inverse{};
        for (int a = 1; a < prime; ++a)
            for (int b = 1; b < prime; ++b)
                if (a * b % prime == 1) inverse[a] = b;
        int rank = 0;
        int determinant = 1;
        for (int c = 0; c < cols && rank < rows; ++c) {
            int pivot = rank;
            while (pivot < rows && matrix[size_t(pivot) * cols + c] == 0) ++pivot;
            if (pivot == rows) continue;
            if (pivot != rank) {
                for (int j = c; j < cols; ++j)
                    std::swap(matrix[size_t(pivot) * cols + j], matrix[size_t(rank) * cols + j]);
                determinant = (prime - determinant) % prime;
            }
            determinant = determinant * matrix[size_t(rank) * cols + c] % prime;
            int inv = inverse[matrix[size_t(rank) * cols + c]];
            for (int i = rank + 1; i < rows; ++i) {
                int factor = int(matrix[size_t(i) * cols + c]) * inv % prime;
                if (!factor) continue;
                matrix[size_t(i) * cols + c] = 0;
                for (int j = c + 1; j < cols; ++j) {
                    int value = int(matrix[size_t(i) * cols + j]) - factor * int(matrix[size_t(rank) * cols + j]);
                    matrix[size_t(i) * cols + j] = (value % prime + prime) % prime;
                }
            }
            ++rank;
        }
        std::cout << "prime=" << prime << " rows=" << rows << " columns=" << cols << " rank=" << rank << " experts=";
        for (int i = 3; i < argc; ++i) std::cout << (i == 3 ? "" : ",") << argv[i];
        if (rows == cols) std::cout << " determinant_mod_prime=" << (rank == rows ? determinant : 0);
        std::cout << '\n';
        return rank == rows ? 0 : 1;
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 2;
    }
}
