#include "../simd_consumer.hpp"
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <numeric>
#include <stdexcept>
#include <string_view>
#include <vector>

using ternary_simd::Format;
using ternary_simd::Lookup;

// Both queries consume the same physical packed code. They retain separate
// signed16 accumulators and separate lookup tables, with no shared arithmetic.
template<bool ByteCodes>
[[gnu::noinline]] void evaluate_pair(const Format& format, const Lookup& a, const Lookup& b,
                                     std::int64_t* out_a, std::int64_t* out_b) {
    for (std::size_t row = 0; row < format.padded_rows; row += 128) {
        __m512i sa[4] = {}, sb[4] = {};
        for (std::size_t k = 0; k < format.chunks.size(); ++k) {
            const auto& chunk = format.chunks[k];
            const __m512i ta = _mm512_load_si512(a.tables[k].values.data());
            const __m512i tb = _mm512_load_si512(b.tables[k].values.data());
            for (unsigned tile = 0; tile < 4; ++tile) {
                const auto* source = format.bytes.data()+chunk.offset+(row/32+tile)*chunk.tile_bytes;
                __m256i keys;
                if constexpr (ByteCodes) keys = _mm256_loadu_si256(reinterpret_cast<const __m256i*>(source));
                else keys = chunk.width == 5 ? ternary_simd::unpack32<5>(source) :
                            chunk.width == 4 ? ternary_simd::unpack32<4>(source) :
                                               ternary_simd::unpack32<2>(source);
                const __m512i indices = _mm512_cvtepu8_epi16(keys);
                sa[tile] = _mm512_add_epi16(sa[tile], _mm512_permutexvar_epi16(indices, ta));
                sb[tile] = _mm512_add_epi16(sb[tile], _mm512_permutexvar_epi16(indices, tb));
            }
        }
        alignas(64) std::int16_t va[128], vb[128];
        for (unsigned tile = 0; tile < 4; ++tile) {
            _mm512_store_si512(va+32*tile, sa[tile]);
            _mm512_store_si512(vb+32*tile, sb[tile]);
        }
        for (std::size_t j = 0; j < 128 && row+j < format.rows; ++j) {
            out_a[row+j] = va[j];
            out_b[row+j] = vb[j];
        }
    }
}

[[gnu::noinline]] void independent(const Format& f, const Lookup& a, const Lookup& b,
                                   std::int64_t* oa, std::int64_t* ob) {
    ternary_simd::evaluate(f, a, oa);
    ternary_simd::evaluate(f, b, ob);
}

[[gnu::noinline]] void fused(const Format& f, const Lookup& a, const Lookup& b,
                             std::int64_t* oa, std::int64_t* ob) {
    if (f.byte_codes) evaluate_pair<true>(f, a, b, oa, ob);
    else evaluate_pair<false>(f, a, b, oa, ob);
}

std::uint32_t random_word(std::uint32_t& state) {
    state ^= state << 13; state ^= state >> 17; state ^= state << 5;
    return state;
}

int main(int argc, char** argv) {
    if (argc != 3 || std::atoi(argv[1]) < 1 || std::atoi(argv[1]) > 100 ||
        (std::string_view(argv[2]) != "warm" && std::string_view(argv[2]) != "fresh"))
        throw std::runtime_error("usage: paired REPEATS warm|fresh (1..100)");
    const bool fresh = std::string_view(argv[2]) == "fresh";
    constexpr std::size_t rows = 5120, cols = 128, pairs = 12;
    std::uint32_t seed = 0x4f3a127b;
    std::vector<std::int8_t> weights(rows*cols);
    for (auto& w : weights) w = static_cast<std::int8_t>(random_word(seed)%3)-1;
    std::array<std::array<std::int8_t, cols>, 2*pairs> queries{};
    for (auto& q : queries) for (auto& x : q) x = static_cast<std::int8_t>(random_word(seed)%256-128);
    std::vector<std::int64_t> oa(rows), ob(rows), ra(rows), rb(rows);
    volatile std::uint64_t sink = 0;
    for (bool bytes : {false, true}) {
        auto format = ternary_simd::pack(weights, rows, cols, bytes);
        ternary_simd::check_wire(format, weights);
        std::array<std::vector<double>, 2> times;
        for (int repeat = 0; repeat < std::atoi(argv[1]); ++repeat) {
            for (std::size_t p = 0; p < pairs; ++p) {
                const auto* qa = queries[2*p].data();
                const auto* qb = queries[2*p+1].data();
                const auto la = ternary_simd::prepare(format, qa);
                const auto lb = ternary_simd::prepare(format, qb);
                independent(format, la, lb, ra.data(), rb.data());
                for (std::size_t r = 0; repeat == 0 && r < rows; ++r) {
                    std::int64_t xa = 0, xb = 0;
                    for (std::size_t c = 0; c < cols; ++c) {
                        xa += static_cast<int>(weights[r*cols+c])*qa[c];
                        xb += static_cast<int>(weights[r*cols+c])*qb[c];
                    }
                    if (xa != ra[r] || xb != rb[r]) throw std::runtime_error("reference mismatch");
                }
                for (int pass = 0; pass < 2; ++pass) {
                    const int arm = (repeat+p+pass)%2;
                    const auto start = std::chrono::steady_clock::now();
                    if (fresh) {
                        const auto new_a = ternary_simd::prepare(format, qa);
                        const auto new_b = ternary_simd::prepare(format, qb);
                        if (arm) fused(format, new_a, new_b, oa.data(), ob.data());
                        else independent(format, new_a, new_b, oa.data(), ob.data());
                    } else if (arm) fused(format, la, lb, oa.data(), ob.data());
                    else independent(format, la, lb, oa.data(), ob.data());
                    const auto end = std::chrono::steady_clock::now();
                    if (oa != ra || ob != rb) throw std::runtime_error("paired output mismatch");
                    sink = sink + static_cast<std::uint64_t>(oa[p]+ob[rows-1-p]);
                    const double us = std::chrono::duration<double,std::micro>(end-start).count();
                    times[arm].push_back(us);
                    std::printf("sample format=%s prep=%s repeat=%d pair=%zu arm=%s us=%.3f\n",
                        bytes ? "byte" : "packed", fresh ? "fresh" : "warm", repeat, p,
                        arm ? "fused" : "independent", us);
                }
            }
        }
        for (auto& v : times) std::sort(v.begin(), v.end());
        std::printf("summary format=%s prep=%s rows=%zu cols=%zu pairs=%zu reps=%d bytes=%zu independent_us=%.3f fused_us=%.3f ratio=%.4f sink=%llu\n",
            bytes ? "byte" : "packed", fresh ? "fresh" : "warm", rows, cols, pairs, std::atoi(argv[1]), format.bytes.size(),
            times[0][times[0].size()/2], times[1][times[1].size()/2],
            times[1][times[1].size()/2]/times[0][times[0].size()/2],
            static_cast<unsigned long long>(sink));
    }
}
