#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>

// Every finite BF16 value becomes an integer after multiplication by 2^133.
// Modular rank is a lower bound on rational rank. Exact signed-BF16 row
// relations independently supply an upper bound for the co-routed pair (1,4).
constexpr int p = 251, n = 2048, rows_per_expert = 1024, bank_experts = 16;
static uint8_t residue(uint16_t bits) {
    int exp = (bits >> 7) & 255;
    if (exp == 255) throw std::runtime_error("nonfinite weight");
    int mantissa = exp ? 128 + (bits & 127) : bits & 127;
    int power = exp ? exp - 1 : 0;
    int scale = 1;
    for (int i = 0; i < power; ++i) scale = scale * 2 % p;
    int value = mantissa * scale % p;
    return (bits & 0x8000) ? (p - value) % p : value;
}
int main(int argc, char **argv) {
    if (argc != 4) {
        std::cerr << "usage: witness gate_up_proj.bf16 expert0 expert1\n";
        return 2;
    }
    try {
        int experts[] = {std::stoi(argv[2]), std::stoi(argv[3])};
        std::ifstream input(argv[1], std::ios::binary);
        if (!input) throw std::runtime_error("cannot open bank");
        std::vector<uint8_t> a(size_t(n) * n);
        std::vector<uint16_t> raw(rows_per_expert * n);
        for (int e = 0; e < 2; ++e) {
            if (experts[e] < 0 || experts[e] >= bank_experts || experts[0] == experts[1])
                throw std::runtime_error("expected distinct experts in 0..15");
            input.seekg(size_t(experts[e]) * rows_per_expert * n * 2);
            input.read(reinterpret_cast<char *>(raw.data()), raw.size() * 2);
            if (!input) throw std::runtime_error("truncated bank");
            for (size_t j = 0; j < raw.size(); ++j) a[size_t(e * rows_per_expert) * n + j] = residue(raw[j]);
        }
        std::array<uint8_t, p> inverse{};
        for (int x = 1; x < p; ++x)
            for (int y = 1; y < p; ++y)
                if (x * y % p == 1) inverse[x] = y;
        // LUT of field subtraction avoids an integer division for each elimination cell.
        std::vector<uint8_t> subtract(size_t(p) * p * p);
        for (int factor = 0; factor < p; ++factor)
            for (int pivot = 0; pivot < p; ++pivot)
                for (int old = 0; old < p; ++old)
                    subtract[(size_t(factor) * p + pivot) * p + old] = (old - factor * pivot % p + p) % p;
        std::array<int, n> row_origin{};
        for (int i = 0; i < n; ++i) row_origin[i] = i;
        int determinant = 1, rank = 0, swaps = 0;
        for (int c = 0; c < n && rank < n; ++c) {
            int r = rank;
            while (r < n && a[size_t(r) * n + c] == 0) ++r;
            if (r == n) continue;
            if (r != rank) {
                for (int j = c; j < n; ++j) std::swap(a[size_t(r) * n + j], a[size_t(rank) * n + j]);
                std::swap(row_origin[r], row_origin[rank]);
                ++swaps;
                determinant = (p - determinant) % p;
            }
            int pivot = a[size_t(rank) * n + c];
            determinant = determinant * pivot % p;
            int inv = inverse[pivot];
            for (int i = rank + 1; i < n; ++i) {
                uint8_t *row = a.data() + size_t(i) * n;
                int factor = row[c] * inv % p;
                row[c] = 0;
                if (factor == 0) continue;
                const uint8_t *top = a.data() + size_t(rank) * n;
                const uint8_t *lut = subtract.data() + size_t(factor) * p * p;
                for (int j = c + 1; j < n; ++j) row[j] = lut[size_t(top[j]) * p + row[j]];
            }
            ++rank;
        }
        std::cout << "prime=" << p << " rank=" << rank << " rows=" << n
                  << " columns=" << n << " experts=" << experts[0] << "," << experts[1]
                  << " swaps=" << swaps << " determinant_mod_prime=" << (rank == n ? determinant : 0) << '\n';
        std::cout << "dependent_original_rows=";
        for (int i = rank; i < n; ++i) std::cout << (i == rank ? "" : ",") << row_origin[i];
        std::cout << '\n';
        if (experts[0] == 1 && experts[1] == 4) {
            // Four sign-identical/opposite pairs and one four-row identity.
            // The dependent row sets have distinct leading rows, so these five
            // exact rational relations are linearly independent.
            constexpr std::array<int, 12> ids = {17, 529, 49, 561, 1111, 1623,
                                                  1268, 1780, 497, 1009, 825, 313};
            std::array<std::array<uint16_t, n>, ids.size()> witness{};
            for (size_t i = 0; i < ids.size(); ++i) {
                int expert = experts[ids[i] / rows_per_expert];
                input.clear();
                input.seekg((size_t(expert) * rows_per_expert + ids[i] % rows_per_expert) * n * 2);
                input.read(reinterpret_cast<char *>(witness[i].data()), n * 2);
                if (!input) throw std::runtime_error("truncated witness row");
            }
            for (int c = 0; c < n; ++c) {
                for (int i = 0; i < 8; i += 2) {
                    // The source BF16 coefficients are finite and nonzero in
                    // these rows; flipping only sign is exact negation.
                    if ((witness[i][c] & 0x7fff) == 0 || (witness[i][c] & 0x7f80) == 0x7f80 ||
                        witness[i + 1][c] != (witness[i][c] ^ (i == 2 || i == 6 ? 0 : 0x8000)))
                        throw std::runtime_error("paired signed-row identity failed");
                }
                int sum = 0;
                for (int i = 8; i < 12; ++i) {
                    if ((witness[i][c] & 0x7fff) != 0x01d5)
                        throw std::runtime_error("four-row sentinel magnitude differs");
                    int sign = (witness[i][c] & 0x8000) ? -1 : 1;
                    sum += i == 8 ? sign : -sign;
                }
                if (sum) throw std::runtime_error("four-row signed identity failed");
            }
            if (rank > n - 5) throw std::runtime_error("modular rank exceeds exact upper bound");
            std::cout << "exact_relations=529=-17,561=49,1623=-1111,1780=1268,"
                         "497=1009+825+313 upper_rank=2043 exact_rank=" << rank << '\n';
        }
        return 0;
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 2;
    }
}
