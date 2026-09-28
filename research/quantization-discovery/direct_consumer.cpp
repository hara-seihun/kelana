#include <algorithm>
#include <array>
#include <charconv>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>
#include "simd_consumer.hpp"

namespace {

using Clock = std::chrono::steady_clock;
using Nanoseconds = std::uint64_t;

volatile std::uint64_t benchmark_sink = 0;

struct Dimensions {
    std::size_t rows;
    std::size_t columns;
    std::size_t query_count;
    std::size_t repeats;
};

struct Chunk {
    std::size_t column;
    std::uint8_t trits;
    std::uint8_t bits;
    std::uint32_t radix;
};

struct PackedFormat {
    std::string name;
    std::string description;
    std::vector<Chunk> chunks;
    std::size_t row_bits;
    std::size_t padding_trits_per_row;
    std::size_t wire_bytes;
    std::vector<std::uint8_t> bytes;
};

struct Lookup {
    std::vector<std::int16_t> values;
};

struct TimingSeries {
    std::vector<std::vector<Nanoseconds>> samples;
};

struct BasicMethodResult {
    std::string name;
    std::string format;
    std::vector<std::string> checksums;
    TimingSeries evaluation;
};

struct DirectMethodResult {
    std::string name;
    std::string format;
    std::vector<std::string> checksums;
    std::size_t lut_entries;
    TimingSeries preparation;
    TimingSeries cold_evaluation;
    TimingSeries cold_total;
    TimingSeries warm_setup;
    TimingSeries warm_evaluation;
};

std::size_t checked_product(std::size_t a, std::size_t b, std::string_view what) {
    if (a != 0 && b > std::numeric_limits<std::size_t>::max() / a) {
        throw std::runtime_error(std::string(what) + " size overflows size_t");
    }
    return a * b;
}

std::size_t parse_positive(std::string_view text, std::string_view name) {
    std::size_t value = 0;
    const auto result = std::from_chars(text.data(), text.data() + text.size(), value);
    if (result.ec != std::errc{} || result.ptr != text.data() + text.size() || value == 0) {
        throw std::runtime_error(std::string(name) + " must be a positive integer");
    }
    return value;
}

std::vector<std::int8_t> read_i8_file(const std::string& path, std::size_t expected_bytes) {
    std::ifstream input(path, std::ios::binary | std::ios::ate);
    if (!input) {
        throw std::runtime_error("cannot open " + path);
    }
    const auto end = input.tellg();
    if (end < 0 || static_cast<std::uintmax_t>(end) != expected_bytes) {
        throw std::runtime_error(path + " has " + std::to_string(end < 0 ? 0 : static_cast<std::uintmax_t>(end)) +
                                 " bytes; expected " + std::to_string(expected_bytes));
    }
    std::vector<std::int8_t> data(expected_bytes);
    input.seekg(0);
    input.read(reinterpret_cast<char*>(data.data()), static_cast<std::streamsize>(expected_bytes));
    if (!input) {
        throw std::runtime_error("failed to read " + path);
    }
    return data;
}

std::uint8_t bits_for_radix(std::uint32_t radix) {
    std::uint8_t bits = 0;
    std::uint32_t capacity = 1;
    while (capacity < radix) {
        capacity <<= 1;
        ++bits;
    }
    return bits;
}

std::uint32_t power3(std::uint8_t trits) {
    std::uint32_t result = 1;
    for (std::uint8_t i = 0; i < trits; ++i) {
        result *= 3;
    }
    return result;
}

std::vector<std::uint8_t> uniform_chunks(std::size_t columns, std::uint8_t width) {
    std::vector<std::uint8_t> widths;
    for (std::size_t covered = 0; covered < columns;) {
        const auto remaining = columns - covered;
        const auto next = static_cast<std::uint8_t>(std::min<std::size_t>(width, remaining));
        widths.push_back(next);
        covered += next;
    }
    return widths;
}

std::vector<std::uint8_t> mixed_5_6_chunks(std::size_t columns) {
    std::vector<std::uint8_t> widths;
    std::size_t covered = 0;
    std::size_t pattern_index = 0;
    while (covered < columns) {
        const std::uint8_t planned = pattern_index % 24 < 16 ? 5 : 6;
        const auto width = static_cast<std::uint8_t>(std::min<std::size_t>(planned, columns - covered));
        widths.push_back(width);
        covered += width;
        ++pattern_index;
    }
    return widths;
}

void put_bits(std::uint8_t* row, std::size_t bit_offset, std::uint32_t value, std::uint8_t width) {
    for (std::uint8_t bit = 0; bit < width; ++bit) {
        if ((value >> bit) & 1U) {
            const std::size_t position = bit_offset + bit;
            row[position / 8] |= static_cast<std::uint8_t>(1U << (position % 8));
        }
    }
}

std::uint32_t get_bits(const std::uint8_t* data, std::size_t bit_offset, std::uint8_t width) {
    const std::size_t byte = bit_offset / 8;
    const unsigned shift = static_cast<unsigned>(bit_offset % 8);
    std::uint32_t value = data[byte];
    if (shift + width > 8) value |= static_cast<std::uint32_t>(data[byte + 1]) << 8;
    if (shift + width > 16) value |= static_cast<std::uint32_t>(data[byte + 2]) << 16;
    return (value >> shift) & ((1U << width) - 1U);
}

PackedFormat pack_weights(const std::vector<std::int8_t>& weights,
                          const Dimensions& dimensions,
                          std::string name,
                          std::string description,
                          const std::vector<std::uint8_t>& widths) {
    PackedFormat format;
    format.name = std::move(name);
    format.description = std::move(description);

    std::size_t column = 0;
    std::size_t row_bits = 0;
    for (const std::uint8_t width : widths) {
        const std::uint32_t radix = power3(width);
        const std::uint8_t bits = bits_for_radix(radix);
        format.chunks.push_back(Chunk{column, width, bits, radix});
        column += width;
        row_bits += bits;
    }
    if (column < dimensions.columns) {
        throw std::runtime_error("internal chunk plan does not cover all columns");
    }
    format.row_bits = row_bits;
    format.padding_trits_per_row = column - dimensions.columns;
    const std::size_t stream_bits = checked_product(dimensions.rows, format.row_bits, "packed wire bits");
    format.wire_bytes = (stream_bits + 7) / 8;
    format.bytes.assign(format.wire_bytes, 0);

    for (std::size_t row_index = 0; row_index < dimensions.rows; ++row_index) {
        std::size_t bit_offset = row_index * format.row_bits;
        for (const Chunk& chunk : format.chunks) {
            std::uint32_t code = 0;
            std::uint32_t place = 1;
            for (std::uint8_t j = 0; j < chunk.trits; ++j) {
                std::int8_t trit = 0;
                if (chunk.column + j < dimensions.columns) {
                    trit = weights[row_index * dimensions.columns + chunk.column + j];
                }
                code += static_cast<std::uint32_t>(trit + 1) * place;
                place *= 3;
            }
            put_bits(format.bytes.data(), bit_offset, code, chunk.bits);
            bit_offset += chunk.bits;
        }
    }
    return format;
}

[[gnu::noinline]] void dense_evaluate(const std::vector<std::int8_t>& weights,
                    const std::int8_t* query,
                    const Dimensions& dimensions,
                    std::vector<std::int64_t>& output) {
    const bool fits_i32 = dimensions.columns <=
                          static_cast<std::size_t>(std::numeric_limits<std::int32_t>::max() / 128);
    for (std::size_t row = 0; row < dimensions.rows; ++row) {
        const std::int8_t* weight_row = weights.data() + row * dimensions.columns;
        if (fits_i32) {
            std::int32_t sum = 0;
            for (std::size_t column = 0; column < dimensions.columns; ++column) {
                sum += static_cast<std::int32_t>(weight_row[column]) * static_cast<std::int32_t>(query[column]);
            }
            output[row] = sum;
        } else {
            std::int64_t sum = 0;
            for (std::size_t column = 0; column < dimensions.columns; ++column) {
                sum += static_cast<std::int32_t>(weight_row[column]) * static_cast<std::int32_t>(query[column]);
            }
            output[row] = sum;
        }
    }
}

void packed_scalar_evaluate(const PackedFormat& format,
                            const std::int8_t* query,
                            const Dimensions& dimensions,
                            std::vector<std::int64_t>& output) {
    for (std::size_t row = 0; row < dimensions.rows; ++row) {
        std::size_t bit_offset = row * format.row_bits;
        std::int64_t sum = 0;
        for (const Chunk& chunk : format.chunks) {
            std::uint32_t code = get_bits(format.bytes.data(), bit_offset, chunk.bits);
            for (std::uint8_t j = 0; j < chunk.trits; ++j) {
                if (chunk.column + j < dimensions.columns) {
                    const std::int32_t trit = static_cast<std::int32_t>(code % 3) - 1;
                    sum += trit * static_cast<std::int32_t>(query[chunk.column + j]);
                }
                code /= 3;
            }
            bit_offset += chunk.bits;
        }
        output[row] = sum;
    }
}

std::size_t lookup_entries(const PackedFormat& format) {
    std::size_t entries = 0;
    for (const Chunk& chunk : format.chunks) {
        entries += chunk.radix;
    }
    return entries;
}

Lookup prepare_lookup(const PackedFormat& format, const std::int8_t* query) {
    Lookup lookup;
    lookup.values.resize(lookup_entries(format));
    std::size_t table_offset = 0;
    for (const Chunk& chunk : format.chunks) {
        std::array<std::int8_t, 8> digits{};
        digits.fill(-1);
        std::int32_t sum = 0;
        for (std::uint8_t j = 0; j < chunk.trits; ++j) {
            sum -= static_cast<std::int32_t>(query[chunk.column + j]);
        }
        for (std::uint32_t code = 0; code < chunk.radix; ++code) {
            lookup.values[table_offset + code] = static_cast<std::int16_t>(sum);
            for (std::uint8_t j = 0; j < chunk.trits; ++j) {
                const std::int32_t query_value = static_cast<std::int32_t>(query[chunk.column + j]);
                if (digits[j] < 1) {
                    ++digits[j];
                    sum += query_value;
                    break;
                }
                digits[j] = -1;
                sum -= 2 * query_value;
            }
        }
        table_offset += chunk.radix;
    }
    return lookup;
}

void direct_evaluate(const PackedFormat& format,
                     const Lookup& lookup,
                     const Dimensions& dimensions,
                     std::vector<std::int64_t>& output) {
    for (std::size_t row = 0; row < dimensions.rows; ++row) {
        std::size_t bit_offset = row * format.row_bits;
        std::size_t table_offset = 0;
        std::int64_t sum = 0;
        for (const Chunk& chunk : format.chunks) {
            const std::uint32_t code = get_bits(format.bytes.data(), bit_offset, chunk.bits);
            sum += lookup.values[table_offset + code];
            bit_offset += chunk.bits;
            table_offset += chunk.radix;
        }
        output[row] = sum;
    }
}

std::string output_checksum(const std::vector<std::int64_t>& output) {
    std::uint64_t hash = 14695981039346656037ULL;
    for (const std::int64_t signed_value : output) {
        const std::uint64_t value = static_cast<std::uint64_t>(signed_value);
        for (unsigned byte = 0; byte < 8; ++byte) {
            hash ^= (value >> (byte * 8)) & 0xffU;
            hash *= 1099511628211ULL;
        }
    }
    constexpr char digits[] = "0123456789abcdef";
    std::string text(18, '0');
    text[0] = '0';
    text[1] = 'x';
    for (unsigned i = 0; i < 16; ++i) {
        text[17 - i] = digits[(hash >> (i * 4)) & 0xfU];
    }
    return text;
}

void require_equal(const std::vector<std::int64_t>& actual,
                   const std::vector<std::int64_t>& expected,
                   std::string_view method,
                   std::size_t query_index) {
    for (std::size_t row = 0; row < actual.size(); ++row) {
        if (actual[row] != expected[row]) {
            throw std::runtime_error(std::string(method) + " mismatch at query " + std::to_string(query_index) +
                                     ", row " + std::to_string(row) + ": got " +
                                     std::to_string(actual[row]) + ", expected " +
                                     std::to_string(expected[row]));
        }
    }
}

Nanoseconds elapsed(Clock::time_point start, Clock::time_point end) {
    return static_cast<Nanoseconds>(std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count());
}

void consume_output(const std::vector<std::int64_t>& output) {
    const std::string checksum = output_checksum(output);
    std::uint64_t value = 0;
    std::from_chars(checksum.data() + 2, checksum.data() + checksum.size(), value, 16);
    benchmark_sink = benchmark_sink ^ value;
}

BasicMethodResult benchmark_dense(const std::vector<std::int8_t>& weights,
                                  const std::vector<std::int8_t>& queries,
                                  const Dimensions& dimensions,
                                  const std::vector<std::vector<std::int64_t>>& reference,
                                  const std::vector<std::string>& checksums) {
    BasicMethodResult result{"dense_i8", "dense_i8", checksums, {}};
    result.evaluation.samples.resize(dimensions.query_count);
    std::vector<std::int64_t> output(dimensions.rows);
    for (std::size_t query_index = 0; query_index < dimensions.query_count; ++query_index) {
        const std::int8_t* query = queries.data() + query_index * dimensions.columns;
        auto& samples = result.evaluation.samples[query_index];
        samples.reserve(dimensions.repeats);
        for (std::size_t repeat = 0; repeat < dimensions.repeats; ++repeat) {
            const auto start = Clock::now();
            dense_evaluate(weights, query, dimensions, output);
            const auto end = Clock::now();
            samples.push_back(elapsed(start, end));
            require_equal(output, reference[query_index], result.name, query_index);
            consume_output(output);
        }
    }
    return result;
}

std::string method_suffix(const auto& format) {
    constexpr std::string_view prefix = "packed_base3_";
    if (format.name.starts_with(prefix)) return format.name.substr(prefix.size());
    return format.name;
}

BasicMethodResult benchmark_scalar(const PackedFormat& format,
                                   const std::vector<std::int8_t>& queries,
                                   const Dimensions& dimensions,
                                   const std::vector<std::vector<std::int64_t>>& reference,
                                   const std::vector<std::string>& checksums) {
    BasicMethodResult result{"packed_scalar_" + method_suffix(format), format.name, checksums, {}};
    result.evaluation.samples.resize(dimensions.query_count);
    std::vector<std::int64_t> output(dimensions.rows);
    for (std::size_t query_index = 0; query_index < dimensions.query_count; ++query_index) {
        const std::int8_t* query = queries.data() + query_index * dimensions.columns;
        auto& samples = result.evaluation.samples[query_index];
        samples.reserve(dimensions.repeats);
        for (std::size_t repeat = 0; repeat < dimensions.repeats; ++repeat) {
            const auto start = Clock::now();
            packed_scalar_evaluate(format, query, dimensions, output);
            const auto end = Clock::now();
            samples.push_back(elapsed(start, end));
            require_equal(output, reference[query_index], result.name, query_index);
            consume_output(output);
        }
    }
    return result;
}

std::size_t lookup_entries(const ternary_simd::Format& format) {
    return format.chunks.size()*32;
}

ternary_simd::Lookup prepare_lookup(const ternary_simd::Format& format, const std::int8_t* query) {
    return ternary_simd::prepare(format, query);
}

void direct_evaluate(const ternary_simd::Format& format, const ternary_simd::Lookup& lookup,
                     const Dimensions&, std::vector<std::int64_t>& output) {
    ternary_simd::evaluate(format, lookup, output.data());
}

DirectMethodResult benchmark_direct(const auto& format,
                                    const std::vector<std::int8_t>& queries,
                                    const Dimensions& dimensions,
                                    const std::vector<std::vector<std::int64_t>>& reference,
                                    const std::vector<std::string>& checksums) {
    DirectMethodResult result;
    result.name = "direct_lut_" + method_suffix(format);
    result.format = format.name;
    result.checksums = checksums;
    result.lut_entries = lookup_entries(format);
    result.preparation.samples.resize(dimensions.query_count);
    result.cold_evaluation.samples.resize(dimensions.query_count);
    result.cold_total.samples.resize(dimensions.query_count);
    result.warm_setup.samples.resize(dimensions.query_count);
    result.warm_evaluation.samples.resize(dimensions.query_count);

    std::vector<std::int64_t> output(dimensions.rows);
    for (std::size_t query_index = 0; query_index < dimensions.query_count; ++query_index) {
        const std::int8_t* query = queries.data() + query_index * dimensions.columns;
        auto& prep_samples = result.preparation.samples[query_index];
        auto& cold_eval_samples = result.cold_evaluation.samples[query_index];
        auto& cold_total_samples = result.cold_total.samples[query_index];
        prep_samples.reserve(dimensions.repeats);
        cold_eval_samples.reserve(dimensions.repeats);
        cold_total_samples.reserve(dimensions.repeats);

        for (std::size_t repeat = 0; repeat < dimensions.repeats; ++repeat) {
            const auto total_start = Clock::now();
            auto lookup = prepare_lookup(format, query);
            const auto evaluation_start = Clock::now();
            direct_evaluate(format, lookup, dimensions, output);
            const auto end = Clock::now();
            prep_samples.push_back(elapsed(total_start, evaluation_start));
            cold_eval_samples.push_back(elapsed(evaluation_start, end));
            cold_total_samples.push_back(elapsed(total_start, end));
            require_equal(output, reference[query_index], result.name + " cold", query_index);
            consume_output(output);
        }

        const auto setup_start = Clock::now();
        auto warm_lookup = prepare_lookup(format, query);
        const auto setup_end = Clock::now();
        result.warm_setup.samples[query_index].push_back(elapsed(setup_start, setup_end));

        auto& warm_samples = result.warm_evaluation.samples[query_index];
        warm_samples.reserve(dimensions.repeats);
        for (std::size_t repeat = 0; repeat < dimensions.repeats; ++repeat) {
            const auto start = Clock::now();
            direct_evaluate(format, warm_lookup, dimensions, output);
            const auto end = Clock::now();
            warm_samples.push_back(elapsed(start, end));
            require_equal(output, reference[query_index], result.name + " warm", query_index);
            consume_output(output);
        }
    }
    return result;
}

std::array<BasicMethodResult, 3> benchmark_paired(
    const std::vector<std::int8_t>& weights, const std::vector<std::int8_t>& queries,
    const Dimensions& dimensions, const std::vector<std::vector<std::int64_t>>& reference,
    const std::vector<std::string>& checksums, const ternary_simd::Format& packed,
    const ternary_simd::Format& byte) {
    std::array<BasicMethodResult, 3> results{{
        {"paired_dense_i8", "dense_i8", checksums, {}},
        {"paired_cold_packed_sign3_simd", packed.name, checksums, {}},
        {"paired_cold_byte_sign3_simd", byte.name, checksums, {}}
    }};
    for (auto& result : results) result.evaluation.samples.resize(dimensions.query_count);
    std::vector<std::int64_t> output(dimensions.rows);
    for (std::size_t query_index = 0; query_index < dimensions.query_count; ++query_index) {
        const auto* query = queries.data()+query_index*dimensions.columns;
        for (std::size_t repeat = 0; repeat < dimensions.repeats; ++repeat) {
            for (unsigned position = 0; position < 3; ++position) {
                const unsigned method = static_cast<unsigned>((position+repeat+query_index)%3);
                const auto begin = Clock::now();
                if (method == 0) dense_evaluate(weights, query, dimensions, output);
                else {
                    const auto& format = method == 1 ? packed : byte;
                    const auto lookup = ternary_simd::prepare(format, query);
                    ternary_simd::evaluate(format, lookup, output.data());
                }
                const auto end = Clock::now();
                results[method].evaluation.samples[query_index].push_back(elapsed(begin, end));
                require_equal(output, reference[query_index], results[method].name, query_index);
                consume_output(output);
            }
        }
    }
    return results;
}

struct Summary {
    Nanoseconds minimum;
    Nanoseconds p50;
    Nanoseconds p90;
    Nanoseconds maximum;
    long double mean;
};

Summary summarize(const std::vector<Nanoseconds>& samples) {
    std::vector<Nanoseconds> sorted = samples;
    std::sort(sorted.begin(), sorted.end());
    long double total = 0;
    for (const Nanoseconds sample : sorted) {
        total += sample;
    }
    const auto nearest_rank = [&](long double percentile) {
        const std::size_t rank = static_cast<std::size_t>(std::ceil(percentile * sorted.size()));
        return sorted[std::max<std::size_t>(1, rank) - 1];
    };
    return Summary{sorted.front(), nearest_rank(0.50L), nearest_rank(0.90L), sorted.back(), total / sorted.size()};
}

void print_string_array(const std::vector<std::string>& values) {
    std::cout << '[';
    for (std::size_t i = 0; i < values.size(); ++i) {
        if (i != 0) std::cout << ',';
        std::cout << '"' << values[i] << '"';
    }
    std::cout << ']';
}

void print_timing(const TimingSeries& timing) {
    std::cout << "{\"unit\":\"ns\",\"sample_order\":\"query_then_repeat\",\"samples_ns\":[";
    for (std::size_t query = 0; query < timing.samples.size(); ++query) {
        if (query != 0) std::cout << ',';
        std::cout << '[';
        for (std::size_t repeat = 0; repeat < timing.samples[query].size(); ++repeat) {
            if (repeat != 0) std::cout << ',';
            std::cout << timing.samples[query][repeat];
        }
        std::cout << ']';
    }
    std::cout << "],\"per_query_summary\":[";
    for (std::size_t query = 0; query < timing.samples.size(); ++query) {
        if (query != 0) std::cout << ',';
        const Summary summary = summarize(timing.samples[query]);
        std::cout << "{\"min\":" << summary.minimum
                  << ",\"p50_nearest_rank\":" << summary.p50
                  << ",\"p90_nearest_rank\":" << summary.p90
                  << ",\"max\":" << summary.maximum
                  << ",\"mean\":" << std::fixed << std::setprecision(1)
                  << static_cast<double>(summary.mean) << '}';
    }
    std::cout << "]}";
}

void print_format(const PackedFormat& format, const Dimensions& dimensions) {
    const std::size_t stream_bits = checked_product(dimensions.rows, format.row_bits, "packed wire bits");
    std::cout << "{\"description\":\"" << format.description
              << "\",\"layout\":\"row-major contiguous bitstream; rows use an implicit fixed bit stride; chunk codes concatenate least-significant-bit first\""
              << ",\"digit_mapping\":\"trit + 1, least-significant base-3 digit is the first column in a chunk\""
              << ",\"code_bit_endianness\":\"little-endian within each row bitstream\""
              << ",\"chunks_per_row\":" << format.chunks.size()
              << ",\"chunk_trits\":[";
    for (std::size_t i = 0; i < format.chunks.size(); ++i) {
        if (i != 0) std::cout << ',';
        std::cout << static_cast<unsigned>(format.chunks[i].trits);
    }
    std::cout << "],\"chunk_code_bits\":[";
    for (std::size_t i = 0; i < format.chunks.size(); ++i) {
        if (i != 0) std::cout << ',';
        std::cout << static_cast<unsigned>(format.chunks[i].bits);
    }
    std::cout << "],\"row_bits\":" << format.row_bits
              << ",\"stream_end_padding_bits\":" << format.wire_bytes * 8 - stream_bits
              << ",\"padding_trits_per_row\":" << format.padding_trits_per_row
              << ",\"padding_trits_total\":" << checked_product(dimensions.rows, format.padding_trits_per_row, "padding")
              << ",\"code_stream_bytes\":" << format.wire_bytes
              << ",\"row_offsets_bytes\":0"
              << ",\"row_offsets\":\"implicit fixed bit stride\""
              << ",\"total_wire_bytes\":" << format.wire_bytes << '}';
}

void print_basic_method(const BasicMethodResult& result) {
    std::cout << "{\"name\":\"" << result.name << "\",\"format\":\"" << result.format
              << "\",\"exact_match_all_queries\":true,\"output\":{\"type\":\"int64\",\"checksum\":\"fnv1a64 over little-endian int64 row outputs\",\"per_query\":";
    print_string_array(result.checksums);
    std::cout << "},\"timing\":{\"evaluation\":";
    print_timing(result.evaluation);
    std::cout << "}}";
}

void print_direct_method(const DirectMethodResult& result) {
    std::cout << "{\"name\":\"" << result.name << "\",\"format\":\"" << result.format
              << "\",\"exact_match_all_queries\":true,\"output\":{\"type\":\"int64\",\"checksum\":\"fnv1a64 over little-endian int64 row outputs\",\"per_query\":";
    print_string_array(result.checksums);
    std::cout << "},\"query_lut\":{\"entry_type\":\"int16\",\"entries_per_query\":" << result.lut_entries
              << ",\"data_bytes_per_query\":" << result.lut_entries * sizeof(std::int16_t)
              << ",\"offset_bytes_per_query\":0,\"total_workspace_bytes_per_query\":" << result.lut_entries * sizeof(std::int16_t)
              << "},\"timing\":{\"preparation\":";
    print_timing(result.preparation);
    std::cout << ",\"cold_evaluation\":";
    print_timing(result.cold_evaluation);
    std::cout << ",\"cold_total\":";
    print_timing(result.cold_total);
    std::cout << ",\"warm_setup\":";
    print_timing(result.warm_setup);
    std::cout << ",\"warm_evaluation\":";
    print_timing(result.warm_evaluation);
    std::cout << "}}";
}

void print_format(const ternary_simd::Format& format, const Dimensions&) {
    std::cout << "{\"layout\":\"chunk-major;32-row tiles;sign-orbit indices\",\"row_bits\":"
              << format.row_bits << ",\"padded_rows\":" << format.padded_rows
              << ",\"padding_rows\":" << format.padded_rows-format.rows
              << ",\"chunks_per_row\":" << format.chunks.size()
              << ",\"total_wire_bytes\":" << format.bytes.size()
              << ",\"row_offsets_bytes\":0,\"isa\":\"AVX512VBMI,AVX512BW,AVX512VL\"}";
}

int run(int argc, char** argv) {
    if (argc != 7) {
        throw std::runtime_error("usage: direct_consumer WEIGHTS_I8 QUERIES_I8 ROWS COLUMNS QUERY_COUNT REPEATS");
    }
    const Dimensions dimensions{
        parse_positive(argv[3], "ROWS"),
        parse_positive(argv[4], "COLUMNS"),
        parse_positive(argv[5], "QUERY_COUNT"),
        parse_positive(argv[6], "REPEATS")};
    if (dimensions.columns > static_cast<std::size_t>(std::numeric_limits<std::int64_t>::max() / 128)) {
        throw std::runtime_error("COLUMNS is too large for exact int64 accumulation");
    }

    const std::size_t weight_bytes = checked_product(dimensions.rows, dimensions.columns, "weights");
    const std::size_t query_bytes = checked_product(dimensions.query_count, dimensions.columns, "queries");
    const std::size_t output_values = checked_product(dimensions.rows, dimensions.query_count, "outputs");
    const std::size_t output_bytes = checked_product(output_values, sizeof(std::int64_t), "outputs");
    const std::vector<std::int8_t> weights = read_i8_file(argv[1], weight_bytes);
    const std::vector<std::int8_t> queries = read_i8_file(argv[2], query_bytes);
    for (std::size_t i = 0; i < weights.size(); ++i) {
        if (weights[i] < -1 || weights[i] > 1) {
            throw std::runtime_error("weight byte " + std::to_string(i) + " is not a trit");
        }
    }

    const PackedFormat packed_k5 = pack_weights(weights, dimensions, "packed_base3_k5",
                                                 "uniform five-trit chunks", uniform_chunks(dimensions.columns, 5));
    const PackedFormat packed_k8 = pack_weights(weights, dimensions, "packed_base3_k8",
                                                 "uniform eight-trit chunks", uniform_chunks(dimensions.columns, 8));
    const PackedFormat packed_mixed = pack_weights(weights, dimensions, "packed_base3_mixed5_6",
                                                    "repeating 16 five-trit then 8 six-trit chunks",
                                                    mixed_5_6_chunks(dimensions.columns));

    std::vector<std::vector<std::int64_t>> reference(dimensions.query_count,
                                                      std::vector<std::int64_t>(dimensions.rows));
    std::vector<std::string> checksums;
    checksums.reserve(dimensions.query_count);
    for (std::size_t query_index = 0; query_index < dimensions.query_count; ++query_index) {
        dense_evaluate(weights, queries.data() + query_index * dimensions.columns, dimensions,
                       reference[query_index]);
        checksums.push_back(output_checksum(reference[query_index]));
    }

    ternary_simd::check_unpack();
    const auto simd_packed = ternary_simd::pack(weights, dimensions.rows, dimensions.columns, false);
    const auto simd_byte = ternary_simd::pack(weights, dimensions.rows, dimensions.columns, true);
    ternary_simd::check_wire(simd_packed, weights);
    ternary_simd::check_wire(simd_byte, weights);

    const BasicMethodResult dense = benchmark_dense(weights, queries, dimensions, reference, checksums);
    const BasicMethodResult scalar_k5 = benchmark_scalar(packed_k5, queries, dimensions, reference, checksums);
    const BasicMethodResult scalar_k8 = benchmark_scalar(packed_k8, queries, dimensions, reference, checksums);
    const BasicMethodResult scalar_mixed = benchmark_scalar(packed_mixed, queries, dimensions, reference, checksums);
    const DirectMethodResult direct_k5 = benchmark_direct(packed_k5, queries, dimensions, reference, checksums);
    const DirectMethodResult direct_k8 = benchmark_direct(packed_k8, queries, dimensions, reference, checksums);
    const DirectMethodResult direct_mixed = benchmark_direct(packed_mixed, queries, dimensions, reference, checksums);
    const DirectMethodResult direct_simd = benchmark_direct(simd_packed, queries, dimensions, reference, checksums);
    const DirectMethodResult direct_simd_byte = benchmark_direct(simd_byte, queries, dimensions, reference, checksums);
    const auto paired = benchmark_paired(weights, queries, dimensions, reference, checksums, simd_packed, simd_byte);

    std::cout << "{\"schema\":\"kelana.direct-consumer.v1\",\"simd_unpack_basis_checks\":355,\"simd_weight_roundtrip_trits_per_format\":"
              << weight_bytes << ",\"input\":{"
              << "\"rows\":" << dimensions.rows
              << ",\"columns\":" << dimensions.columns
              << ",\"query_count\":" << dimensions.query_count
              << ",\"repeats\":" << dimensions.repeats
              << ",\"weights\":{\"type\":\"int8 trit\",\"layout\":\"row-major [rows,columns]\",\"bytes\":" << weight_bytes << "}"
              << ",\"queries\":{\"type\":\"int8\",\"layout\":\"row-major [query_count,columns]\",\"bytes\":" << query_bytes << "}"
              << ",\"outputs\":{\"type\":\"int64\",\"layout\":\"row-major [query_count,rows]\",\"bytes\":" << output_bytes << "}}"
              << ",\"formats\":{\"dense_i8\":{\"layout\":\"row-major int8\",\"data_bytes\":" << weight_bytes
              << ",\"total_wire_bytes\":" << weight_bytes << "},\"packed_base3_k5\":";
    print_format(packed_k5, dimensions);
    std::cout << ",\"packed_base3_k8\":";
    print_format(packed_k8, dimensions);
    std::cout << ",\"packed_base3_mixed5_6\":";
    print_format(packed_mixed, dimensions);
    std::cout << ",\"packed_sign3_simd\":";
    print_format(simd_packed, dimensions);
    std::cout << ",\"byte_sign3_simd\":";
    print_format(simd_byte, dimensions);
    std::cout << "},\"methods\":[";
    print_basic_method(dense);
    std::cout << ',';
    print_basic_method(scalar_k5);
    std::cout << ',';
    print_basic_method(scalar_k8);
    std::cout << ',';
    print_basic_method(scalar_mixed);
    std::cout << ',';
    print_direct_method(direct_k5);
    std::cout << ',';
    print_direct_method(direct_k8);
    std::cout << ',';
    print_direct_method(direct_mixed);
    std::cout << ',';
    print_direct_method(direct_simd);
    std::cout << ',';
    print_direct_method(direct_simd_byte);
    for (const auto& method : paired) {
        std::cout << ',';
        print_basic_method(method);
    }
    std::cout << "],\"paired_order\":\"query-major;rotated method order each repeat;fresh LUT allocation,preparation,evaluation and destruction included\",\"benchmark_sink\":\"0x" << std::hex << benchmark_sink << std::dec << "\"}\n";
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    try {
        return run(argc, argv);
    } catch (const std::exception& error) {
        std::cerr << "direct_consumer: " << error.what() << '\n';
        return 1;
    }
}
