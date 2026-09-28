#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>

// Multiplication by 2^133 makes every finite BF16 coefficient integral.
// Reduction modulo 251 is a ring map on these scaled coefficients.
constexpr int P = 251, N = 2048, R = 1024, E = 16;
static uint8_t residue(uint16_t bits, const std::array<uint8_t, 256> &powers) {
    const int exponent = (bits >> 7) & 255;
    if (exponent == 255) throw std::runtime_error("nonfinite BF16 coefficient");
    const int mantissa = exponent ? 128 + (bits & 127) : bits & 127;
    const int v = mantissa * powers[exponent ? exponent - 1 : 0] % P;
    return (bits & 0x8000) ? (P - v) % P : v;
}
int main(int argc, char **argv) {
    if (argc != 3) {
        std::cerr << "usage: witness gate_up_proj.bf16 train-or-held.0.ffn_moe_topk-0.bin\n";
        return 2;
    }
    try {
        std::ifstream routes(argv[2], std::ios::binary | std::ios::ate);
        if (!routes || routes.tellg() < 0 || routes.tellg() % (8 * sizeof(int32_t)))
            throw std::runtime_error("invalid route file");
        const size_t tokens = size_t(routes.tellg()) / (8 * sizeof(int32_t));
        routes.seekg(0);
        std::vector<int32_t> ids(tokens * 8);
        routes.read(reinterpret_cast<char *>(ids.data()), ids.size() * sizeof(int32_t));
        std::ifstream bank(argv[1], std::ios::binary | std::ios::ate);
        if (!bank || bank.tellg() != std::streampos(size_t(E) * R * N * 2))
            throw std::runtime_error("unexpected bank size");
        std::array<uint8_t, 256> powers{};
        powers[0] = 1;
        for (int i = 1; i < 256; ++i) powers[i] = powers[i-1] * 2 % P;
        std::array<uint8_t, P> inverse{};
        for (int x = 1; x < P; ++x)
            for (int y = 1; y < P; ++y)
                if (x * y % P == 1) inverse[x] = y;
        std::vector<uint8_t> lut(size_t(P) * P * P);
        for (int f = 0; f < P; ++f)
            for (int v = 0; v < P; ++v)
                for (int old = 0; old < P; ++old)
                    lut[(size_t(f) * P + v) * P + old] = (old - f * v % P + P) % P;
        std::vector<uint16_t> raw(R * N);
        std::vector<uint8_t> matrix(size_t(8 * R) * N);
        std::vector<int> selected(8 * R);
        for (size_t t = 0; t < tokens; ++t) {
            std::array<int, 8> route{};
            int nselected = 0;
            for (int i = 0; i < 8; ++i) {
                const int e = ids[t*8+i];
                if (e < 0 || e >= 256) throw std::runtime_error("invalid route ID");
                if (e >= E) continue;
                for (int j = 0; j < nselected; ++j)
                    if (route[j] == e) throw std::runtime_error("duplicate route ID");
                route[nselected++] = e;
            }
            if (nselected < 3) continue;
            bank.clear();
            for (int j = 0; j < nselected; ++j) {
                bank.seekg(size_t(route[j]) * R * N * 2);
                bank.read(reinterpret_cast<char *>(raw.data()), raw.size() * 2);
                if (!bank) throw std::runtime_error("truncated bank");
                for (size_t k = 0; k < raw.size(); ++k)
                    matrix[size_t(j*R)*N+k] = residue(raw[k], powers);
            }
            const int count = nselected * R;
            for (int i = 0; i < count; ++i) selected[i] = i;
            int rank = 0, pivots_product = 1;
            std::vector<int> rank_after_expert(nselected);
            for (int c = 0; c < N && rank < N; ++c) {
                int r = rank;
                while (r < count && matrix[size_t(r)*N+c] == 0) ++r;
                if (r == count) continue;
                if (r != rank) {
                    for (int k = c; k < N; ++k)
                        std::swap(matrix[size_t(r)*N+k], matrix[size_t(rank)*N+k]);
                    std::swap(selected[r], selected[rank]);
                }
                const uint8_t *pivot = matrix.data()+size_t(rank)*N;
                const int value = pivot[c];
                pivots_product = pivots_product * value % P;
                const int inv = inverse[value];
                for (int row = rank+1; row < count; ++row) {
                    uint8_t *dst = matrix.data()+size_t(row)*N;
                    const int f = dst[c]*inv%P;
                    dst[c] = 0;
                    if (!f) continue;
                    const uint8_t *table = lut.data()+size_t(f)*P*P;
                    for (int k = c+1; k < N; ++k)
                        dst[k] = table[size_t(pivot[k])*P+dst[k]];
                }
                ++rank;
                // Once full column rank is established, later routes are unnecessary.
            }
            for (int i = 0; i < rank; ++i) ++rank_after_expert[selected[i]/R];
            std::cout << "token=" << t << " route=";
            for (int j = 0; j < 8; ++j) std::cout << (j ? "," : "") << ids[t*8+j];
            std::cout << " available=";
            for (int j = 0; j < nselected; ++j)
                std::cout << (j ? "," : "") << route[j] << ":" << rank_after_expert[j];
            std::cout << " rank_mod_251=" << rank << " pivot_product_mod_251=" << pivots_product << '\n';
            if (rank == N) return 0;
        }
        throw std::runtime_error("no full-rank route in available original slice");
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}
