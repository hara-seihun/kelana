// Fully expanded paired operands: the gate/up pair coefficient g + 2047u materialised offline as
// the exact FP16 value the WMMA A operand consumes, in the register layout the instruction reads.
//
// The compact form (paired_codec.hpp) stores one nibble per pair and rebuilds those FP16 values on
// the fly with two V_PERM_B32 per four coefficients. This header stores the result of that decode
// instead, so the gate/up kernel issues a load where the compact kernel issues a decode. Nothing
// else about the arithmetic changes: the values, their order inside the A fragment and the block
// scales are identical, so the accumulation is bit for bit the compact one.
//
// One copy per (tile, block, slice, row). The two halves of a wave hold the same A fragment in
// RDNA3's w32 WMMA layout; they read the same 32 bytes rather than a second stored copy.
#pragma once
#include "../paired_codec.hpp"
#include "../paired_load.hpp"
#include <thread>

namespace kelana_ffn {

constexpr int EXP_ROW_BYTES = 32;                        // 16 fp16 pair coefficients
constexpr int EXP_SLICE_BYTES = 16 * EXP_ROW_BYTES;      // 16 rows of one 16-wide k slice
constexpr int EXP_OPERAND_BYTES = 8 * EXP_SLICE_BYTES;   // 8 slices span the 128-wide block
constexpr int EXP_SCALES_OFF = EXP_OPERAND_BYTES;
constexpr int EXP_BLOCK_BYTES = EXP_OPERAND_BYTES + 16 * 4; // + (gate, up) fp16 scale pair per row

// The FP16 bits decode_sixteen produces for this ternary pair, taken from the same table.
inline uint16_t pair_half_bits(int gate, int up) {
    const uint8_t code = pair_code(gate, up);
    return PAIR_HALF[code == 12 ? 8 : code];
}

// Expanded operands with the block scales lifted into their own array, so an operand block is
// exactly 4096 bytes and every block, slice and lane fragment keeps its natural alignment against
// the 128-byte cache line. The interleaved form above puts 64 scale bytes between blocks and
// shifts every second block off the line grid.
struct ExpandedSplit {
    std::vector<uint8_t> operands;  // [hidden/16][K/128][8 slices][16 rows][16 fp16]
    std::vector<uint8_t> scales;    // [hidden/16][K/128][16 rows][gate, up fp16]
};

inline ExpandedSplit pack_expanded_split_from_halo(const uint8_t *gate, const uint8_t *up,
                                                   int hidden, int kdim, int threads = 0) {
    if (hidden % 32 || kdim % 128) throw std::runtime_error("HALO expanded geometry");
    const int nb = kdim / 128, ntiles = hidden / 16;
    ExpandedSplit out;
    out.operands.resize(size_t(ntiles) * nb * EXP_OPERAND_BYTES);
    out.scales.resize(size_t(ntiles) * nb * 64);
    if (threads <= 0) threads = int(std::thread::hardware_concurrency());
    threads = std::max(1, std::min(threads, ntiles));

    auto worker = [&](int t0) {
        for (int tile = t0; tile < ntiles; tile += threads)
            for (int b = 0; b < nb; ++b) {
                const size_t src = (size_t(tile / 2) * nb + b) * halo::TILE_BLOCK_BYTES;
                const size_t blk = size_t(tile) * nb + b;
                auto *ops = reinterpret_cast<uint16_t *>(out.operands.data() + blk * EXP_OPERAND_BYTES);
                uint8_t *sc = out.scales.data() + blk * 64;
                for (int row = 0; row < 16; ++row) {
                    const int lane = (tile & 1) * 16 + row;
                    int8_t g[128], u[128];
                    uint16_t gs, us;
                    decode_halo_row(gate + src, lane, g, gs);
                    decode_halo_row(up + src, lane, u, us);
                    for (int j = 0; j < 128; ++j)
                        ops[(j / 16) * 256 + row * 16 + (j % 16)] = pair_half_bits(g[j], u[j]);
                    std::memcpy(sc + row * 4, &gs, 2);
                    std::memcpy(sc + row * 4 + 2, &us, 2);
                }
            }
    };
    std::vector<std::thread> pool;
    for (int t = 1; t < threads; ++t) pool.emplace_back(worker, t);
    worker(0);
    for (auto &th : pool) th.join();
    return out;
}

// Expands the deployed HALO gate and up tiles into [hidden/16][K/128] blocks of
// [8 slices][16 rows][16 fp16] operands followed by the 16 fp16 scale pairs.
inline std::vector<uint8_t> pack_expanded_from_halo(const uint8_t *gate, const uint8_t *up,
                                                    int hidden, int kdim, int threads = 0) {
    if (hidden % 32 || kdim % 128) throw std::runtime_error("HALO expanded geometry");
    const int nb = kdim / 128, ntiles = hidden / 16;
    std::vector<uint8_t> out(size_t(ntiles) * nb * EXP_BLOCK_BYTES);
    if (threads <= 0) threads = int(std::thread::hardware_concurrency());
    threads = std::max(1, std::min(threads, ntiles));

    auto worker = [&](int t0) {
        for (int tile = t0; tile < ntiles; tile += threads)
            for (int b = 0; b < nb; ++b) {
                const size_t src = (size_t(tile / 2) * nb + b) * halo::TILE_BLOCK_BYTES;
                uint8_t *dst = out.data() + (size_t(tile) * nb + b) * EXP_BLOCK_BYTES;
                auto *ops = reinterpret_cast<uint16_t *>(dst);
                for (int row = 0; row < 16; ++row) {
                    const int lane = (tile & 1) * 16 + row;
                    int8_t g[128], u[128];
                    uint16_t gs, us;
                    decode_halo_row(gate + src, lane, g, gs);
                    decode_halo_row(up + src, lane, u, us);
                    for (int j = 0; j < 128; ++j)
                        ops[(j / 16) * 256 + row * 16 + (j % 16)] = pair_half_bits(g[j], u[j]);
                    std::memcpy(dst + EXP_SCALES_OFF + row * 4, &gs, 2);
                    std::memcpy(dst + EXP_SCALES_OFF + row * 4 + 2, &us, 2);
                }
            }
    };
    std::vector<std::thread> pool;
    for (int t = 1; t < threads; ++t) pool.emplace_back(worker, t);
    worker(0);
    for (auto &th : pool) th.join();
    return out;
}

} // namespace kelana_ffn
