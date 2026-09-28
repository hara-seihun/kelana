#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>

// Finite binary32 times 2^149 is an integer. A 2048-pivot minor modulo 251
// proves full rank over Q and R, without floating-rank thresholds.
constexpr int P = 251, N = 2048;

int main(int argc, char **argv) {
    if (argc != 2) { std::cerr << "usage: witness nonzero-gate-up-rows.f32\n"; return 2; }
    try {
        std::ifstream in(argv[1], std::ios::binary | std::ios::ate);
        if (!in || in.tellg() <= 0 || size_t(in.tellg()) % (N*4))
            throw std::runtime_error("expected nonempty FP32 rows of width 2048");
        const size_t rows = size_t(in.tellg())/(N*4);
        in.seekg(0);
        std::array<uint8_t, 256> pow2{}; pow2[0] = 1;
        for (int i = 1; i < 256; ++i) pow2[i] = pow2[i-1]*2 % P;
        std::array<uint8_t, P> inv{};
        for (int a = 1; a < P; ++a)
            for (int b = 1; b < P; ++b)
                if (a*b % P == 1) inv[a] = b;
        std::vector<uint8_t> diff(size_t(P)*P*P);
        for (int factor = 0; factor < P; ++factor)
            for (int pivot = 0; pivot < P; ++pivot)
                for (int old = 0; old < P; ++old)
                    diff[(size_t(factor)*P+pivot)*P+old] = (old-factor*pivot%P+P)%P;
        std::vector<uint8_t> basis(size_t(N)*N, 0), row(N);
        std::array<uint8_t, N> occupied{};
        std::array<uint32_t, N> raw{};
        size_t rank = 0, used = 0;
        int pivot_product = 1;
        for (; used < rows && rank < N; ++used) {
            in.read(reinterpret_cast<char *>(raw.data()), N*4);
            if (!in) throw std::runtime_error("truncated row");
            for (int j = 0; j < N; ++j) {
                const uint32_t bits = raw[j];
                const int exp = (bits >> 23) & 255;
                if (exp == 255) throw std::runtime_error("nonfinite decoded coefficient");
                const uint32_t mantissa = exp ? (1u << 23) | (bits & 0x7fffff) : bits & 0x7fffff;
                const int v = (mantissa % P) * pow2[exp ? exp - 1 : 0] % P;
                row[j] = (bits >> 31) ? (P-v)%P : v;
            }
            for (int col = 0; col < N; ++col) {
                const int v = row[col];
                if (!v) continue;
                if (!occupied[col]) {
                    occupied[col] = 1;
                    pivot_product = pivot_product*v%P;
                    uint8_t *dst = basis.data()+size_t(col)*N;
                    const int inverse = inv[v];
                    for (int j = col; j < N; ++j) dst[j] = row[j]*inverse%P;
                    ++rank;
                    break;
                }
                const uint8_t *pivot = basis.data()+size_t(col)*N;
                const uint8_t *table = diff.data()+size_t(v)*P*P;
                row[col] = 0;
                for (int j = col+1; j < N; ++j)
                    row[j] = table[size_t(pivot[j])*P+row[j]];
            }
        }
        std::cout << "prime=251 input_width=2048 available_nonzero_rows=" << rows
                  << " rows_read=" << used << " rank_mod_251=" << rank
                  << " pivot_product_mod_251=" << pivot_product << '\n';
        return rank == N ? 0 : 1;
    } catch (const std::exception &e) { std::cerr << e.what() << '\n'; return 2; }
}
