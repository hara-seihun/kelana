#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>

// Every finite BF16 number multiplied by 2^133 is an integer. Nonzero rank
// modulo 251 of that integer matrix certifies rank over Q and R.
constexpr int P = 251, OUT = 2048, HIDDEN = 512, BANK = 16;
static uint8_t residue(uint16_t bits, const std::array<uint8_t, 256> &pow2) {
    const int exp = (bits >> 7) & 255;
    if (exp == 255) throw std::runtime_error("nonfinite BF16 coefficient");
    const int mantissa = exp ? 128 + (bits & 127) : bits & 127;
    const int v = mantissa * pow2[exp ? exp - 1 : 0] % P;
    return (bits & 0x8000) ? (P - v) % P : v;
}
int main(int argc, char **argv) {
    if (argc != 3) {
        std::cerr << "usage: witness down_proj.bf16 held.0.ffn_moe_topk-0.bin\n";
        return 2;
    }
    try {
        std::ifstream route_file(argv[2], std::ios::binary | std::ios::ate);
        if (!route_file || route_file.tellg() < 0 || route_file.tellg() % (8 * sizeof(int32_t)))
            throw std::runtime_error("invalid route file");
        const size_t tokens = size_t(route_file.tellg()) / (8 * sizeof(int32_t));
        if (tokens <= 113) throw std::runtime_error("missing held token 113");
        route_file.seekg(113 * 8 * sizeof(int32_t));
        std::array<int32_t, 8> ids{};
        route_file.read(reinterpret_cast<char *>(ids.data()), ids.size() * sizeof(int32_t));
        if (ids != std::array<int32_t, 8>{10,3,239,129,1,225,109,190})
            throw std::runtime_error("held route identity changed");
        std::ifstream bank(argv[1], std::ios::binary | std::ios::ate);
        if (!bank || bank.tellg() != std::streampos(size_t(BANK) * OUT * HIDDEN * 2))
            throw std::runtime_error("unexpected original bank size");
        const std::array<int, 3> experts{10,3,1};
        constexpr int ROWS = 3 * HIDDEN;
        std::array<uint8_t, 256> pow2{};
        pow2[0] = 1;
        for (int i = 1; i < 256; ++i) pow2[i] = pow2[i-1] * 2 % P;
        std::array<uint8_t, P> inverse{};
        for (int x = 1; x < P; ++x)
            for (int y = 1; y < P; ++y)
                if (x * y % P == 1) inverse[x] = y;
        // Table makes each elimination update one read and one write.
        std::vector<uint8_t> subtract(size_t(P) * P * P);
        for (int f = 0; f < P; ++f)
            for (int v = 0; v < P; ++v)
                for (int old = 0; old < P; ++old)
                    subtract[(size_t(f)*P+v)*P+old] = (old-f*v%P+P)%P;
        std::vector<uint8_t> matrix(size_t(ROWS)*OUT);
        std::vector<uint16_t> weights(size_t(OUT)*HIDDEN);
        for (int j = 0; j < 3; ++j) {
            bank.seekg(size_t(experts[j]) * OUT * HIDDEN * 2);
            bank.read(reinterpret_cast<char *>(weights.data()), weights.size()*2);
            if (!bank) throw std::runtime_error("truncated expert");
            for (int out = 0; out < OUT; ++out)
                for (int in = 0; in < HIDDEN; ++in)
                    matrix[size_t(j*HIDDEN+in)*OUT+out] = residue(weights[size_t(out)*HIDDEN+in], pow2);
        }
        int rank = 0, pivot_product = 1;
        for (int col = 0; col < OUT && rank < ROWS; ++col) {
            int pivot_row = rank;
            while (pivot_row < ROWS && !matrix[size_t(pivot_row)*OUT+col]) ++pivot_row;
            if (pivot_row == ROWS) continue;
            if (pivot_row != rank)
                for (int k = col; k < OUT; ++k)
                    std::swap(matrix[size_t(pivot_row)*OUT+k], matrix[size_t(rank)*OUT+k]);
            const auto *pivot = matrix.data()+size_t(rank)*OUT;
            const int value = pivot[col];
            pivot_product = pivot_product * value % P;
            const int inv = inverse[value];
            for (int row = rank+1; row < ROWS; ++row) {
                auto *dst = matrix.data()+size_t(row)*OUT;
                const int f = dst[col]*inv%P;
                dst[col] = 0;
                if (!f) continue;
                const auto *table = subtract.data()+size_t(f)*P*P;
                for (int k = col+1; k < OUT; ++k)
                    dst[k] = table[size_t(pivot[k])*P+dst[k]];
            }
            ++rank;
        }
        std::cout << "held_token=113 experts=10,3,1 stacked_down_shape=2048x1536"
                  << " rank_mod_251=" << rank
                  << " pivot_product_mod_251=" << pivot_product << '\n';
        // This witness certifies a lower bound, not exact rational rank.
        // 1366 coordinates already exceed the eight-expert dense break-even.
        return rank >= 1366 ? 0 : 1;
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}
