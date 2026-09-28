#pragma once
#include <immintrin.h>
#include <algorithm>
#include <array>
#include <stdexcept>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

namespace ternary_simd {

struct Chunk {
    std::size_t column;
    unsigned length, width, representative_bits;
    std::size_t offset, tile_bytes;
};

struct Format {
    std::string name;
    std::size_t rows, columns, padded_rows, row_bits;
    bool byte_codes;
    std::vector<Chunk> chunks;
    std::vector<std::uint8_t> bytes;
};

struct alignas(64) Table { std::array<std::int16_t, 32> values{}; };
struct Lookup { std::vector<Table> tables; };

inline unsigned pow3(unsigned k) {
    unsigned n = 1;
    while (k--) n *= 3;
    return n;
}

inline Format pack(const std::vector<std::int8_t>& weights, std::size_t rows,
                   std::size_t columns, bool byte_codes) {
    if (columns > 255) throw std::runtime_error("SIMD int16 block supports at most 255 columns");
    Format f{byte_codes ? "byte_sign3_simd" : "packed_sign3_simd", rows, columns,
             ((rows+127)/128)*128, 0, byte_codes, {}, {}};
    std::size_t offset = 0;
    for (std::size_t column = 0; column < columns; column += 3) {
        const unsigned length = static_cast<unsigned>(std::min<std::size_t>(3, columns-column));
        const unsigned count = (pow3(length)+1)/2;
        unsigned representative_bits = 0;
        while ((1U << representative_bits) < count) ++representative_bits;
        const unsigned width = representative_bits+1;
        const std::size_t tile_bytes = byte_codes ? 32 : 4*width;
        f.chunks.push_back({column, length, width, representative_bits, offset, tile_bytes});
        f.row_bits += byte_codes ? 8 : width;
        offset += (f.padded_rows/32)*tile_bytes;
    }
    f.bytes.assign(offset, 0);
    for (const Chunk& chunk : f.chunks) {
        const unsigned n = pow3(chunk.length);
        for (std::size_t row = 0; row < rows; ++row) {
            unsigned code = 0, place = 1;
            for (unsigned j = 0; j < chunk.length; ++j) {
                code += static_cast<unsigned>(weights[row*columns+chunk.column+j]+1)*place;
                place *= 3;
            }
            const unsigned reflected = n-1-code;
            const unsigned key = std::min(code, reflected) |
                ((code > reflected ? 1U : 0U) << chunk.representative_bits);
            if (byte_codes) {
                f.bytes[chunk.offset+row] = static_cast<std::uint8_t>(key);
            } else {
                const std::size_t bit = (chunk.offset*8)+row*chunk.width;
                for (unsigned b = 0; b < chunk.width; ++b)
                    f.bytes[(bit+b)/8] |= static_cast<std::uint8_t>(((key >> b)&1U) << ((bit+b)%8));
            }
        }
    }
    return f;
}

inline void check_wire(const Format& format, const std::vector<std::int8_t>& weights) {
    for (const auto& chunk : format.chunks) {
        const unsigned n = pow3(chunk.length);
        for (std::size_t row = 0; row < format.rows; ++row) {
            unsigned key = 0;
            if (format.byte_codes) key = format.bytes[chunk.offset+row];
            else {
                const std::size_t begin = chunk.offset*8+row*chunk.width;
                for (unsigned bit = 0; bit < chunk.width; ++bit)
                    key |= ((format.bytes[(begin+bit)/8] >> ((begin+bit)%8))&1U) << bit;
            }
            unsigned code = key & ((1U << chunk.representative_bits)-1);
            if (code >= (n+1)/2) throw std::runtime_error("invalid sign-orbit representative");
            if (key & (1U << chunk.representative_bits)) code = n-1-code;
            for (unsigned j = 0; j < chunk.length; ++j) {
                if (static_cast<int>(code%3)-1 != weights[row*format.columns+chunk.column+j])
                    throw std::runtime_error("sign-orbit wire roundtrip mismatch");
                code /= 3;
            }
        }
    }
}

template<unsigned Length, unsigned Column>
inline __m512i coefficients() {
    alignas(64) static constexpr auto values = [] {
        std::array<std::int16_t, 32> a{};
        unsigned n = 1, place = 1, representative_bits = 0;
        for (unsigned j = 0; j < Length; ++j) n *= 3;
        for (unsigned j = 0; j < Column; ++j) place *= 3;
        while ((1U << representative_bits) < (n+1)/2) ++representative_bits;
        for (unsigned representative = 0; representative < (n+1)/2; ++representative) {
            const auto trit = static_cast<std::int16_t>(static_cast<int>((representative/place)%3)-1);
            a[representative] = trit;
            a[representative+(1U << representative_bits)] = -trit;
        }
        return a;
    }();
    return _mm512_load_si512(values.data());
}

template<unsigned Length>
inline __m512i prepare_chunk(const std::int8_t* query) {
    __m512i result = _mm512_mullo_epi16(_mm512_set1_epi16(query[0]), coefficients<Length, 0>());
    if constexpr (Length > 1)
        result = _mm512_add_epi16(result, _mm512_mullo_epi16(_mm512_set1_epi16(query[1]), coefficients<Length, 1>()));
    if constexpr (Length > 2)
        result = _mm512_add_epi16(result, _mm512_mullo_epi16(_mm512_set1_epi16(query[2]), coefficients<Length, 2>()));
    return result;
}

inline Lookup prepare(const Format& format, const std::int8_t* query) {
    Lookup lookup;
    lookup.tables.resize(format.chunks.size());
    for (std::size_t k = 0; k < format.chunks.size(); ++k) {
        const Chunk& chunk = format.chunks[k];
        const auto* q = query+chunk.column;
        const __m512i table = chunk.length == 3 ? prepare_chunk<3>(q) :
                              chunk.length == 2 ? prepare_chunk<2>(q) : prepare_chunk<1>(q);
        _mm512_store_si512(lookup.tables[k].values.data(), table);
    }
    return lookup;
}

template<unsigned Width>
inline __m256i unpack32(const std::uint8_t* source) {
    alignas(32) static const auto expansion = [] {
        std::array<std::uint8_t, 32> a{};
        for (unsigned group = 0; group < 4; ++group)
            for (unsigned byte = 0; byte < 8; ++byte)
                a[8*group+byte] = static_cast<std::uint8_t>(group*Width+(byte < Width ? byte : 0));
        return a;
    }();
    alignas(32) static const auto shifts = [] {
        std::array<std::uint8_t, 32> a{};
        for (unsigned i = 0; i < 32; ++i) a[i] = static_cast<std::uint8_t>((i%8)*Width);
        return a;
    }();
    const __m256i packed = _mm256_maskz_loadu_epi8((1U << (4*Width))-1, source);
    const __m256i expanded = _mm256_permutexvar_epi8(
        _mm256_load_si256(reinterpret_cast<const __m256i*>(expansion.data())), packed);
    const __m256i selected = _mm256_multishift_epi64_epi8(
        _mm256_load_si256(reinterpret_cast<const __m256i*>(shifts.data())), expanded);
    return _mm256_and_si256(selected, _mm256_set1_epi8((1U << Width)-1));
}

template<unsigned Width>
inline void check_unpack_basis() {
    alignas(32) std::array<std::uint8_t, 4*Width> packed{};
    alignas(32) std::array<std::uint8_t, 32> decoded{};
    for (int bit = -1; bit < static_cast<int>(32*Width); ++bit) {
        packed.fill(0);
        if (bit >= 0) packed[static_cast<unsigned>(bit)/8] = 1U << (bit%8);
        _mm256_store_si256(reinterpret_cast<__m256i*>(decoded.data()), unpack32<Width>(packed.data()));
        for (unsigned lane = 0; lane < 32; ++lane) {
            const unsigned expected = bit >= static_cast<int>(lane*Width) &&
                                      bit < static_cast<int>((lane+1)*Width)
                ? 1U << (bit-static_cast<int>(lane*Width)) : 0;
            if (decoded[lane] != expected) throw std::runtime_error("SIMD unpack basis mismatch");
        }
    }
}

inline void check_unpack() {
    check_unpack_basis<2>();
    check_unpack_basis<4>();
    check_unpack_basis<5>();
}

template<bool ByteCodes>
inline void evaluate_body(const Format& format, const Lookup& lookup, std::int64_t* output) {
    for (std::size_t row = 0; row < format.padded_rows; row += 128) {
        __m512i sums[4] = {_mm512_setzero_si512(), _mm512_setzero_si512(),
                           _mm512_setzero_si512(), _mm512_setzero_si512()};
        for (std::size_t k = 0; k < format.chunks.size(); ++k) {
            const Chunk& chunk = format.chunks[k];
            const __m512i table = _mm512_load_si512(lookup.tables[k].values.data());
            for (unsigned tile = 0; tile < 4; ++tile) {
                const std::uint8_t* source = format.bytes.data()+chunk.offset+(row/32+tile)*chunk.tile_bytes;
                __m256i keys;
                if constexpr (ByteCodes) {
                    keys = _mm256_loadu_si256(reinterpret_cast<const __m256i*>(source));
                } else {
                    keys = chunk.width == 5 ? unpack32<5>(source) :
                           chunk.width == 4 ? unpack32<4>(source) : unpack32<2>(source);
                }
                const __m512i indices = _mm512_cvtepu8_epi16(keys);
                sums[tile] = _mm512_add_epi16(sums[tile], _mm512_permutexvar_epi16(indices, table));
            }
        }
        alignas(64) std::array<std::int16_t, 128> result;
        for (unsigned tile = 0; tile < 4; ++tile) _mm512_store_si512(result.data()+32*tile, sums[tile]);
        for (std::size_t j = 0; j < 128 && row+j < format.rows; ++j) output[row+j] = result[j];
    }
}

inline void evaluate(const Format& format, const Lookup& lookup, std::int64_t* output) {
    if (format.byte_codes) evaluate_body<true>(format, lookup, output);
    else evaluate_body<false>(format, lookup, output);
}

} // namespace ternary_simd
