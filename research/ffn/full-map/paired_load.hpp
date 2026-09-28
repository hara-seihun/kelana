#pragma once
#include "paired_codec.hpp"
#include "halo_format.h"

namespace kelana_ffn {
inline void decode_halo_row(const uint8_t *block, int lane, int8_t *signed_trits, uint16_t &scale) {
    uint8_t qs[24], trits[128];
    std::memcpy(qs, block + halo::tile_off_qs_a(lane), 16);
    std::memcpy(qs + 16, block + halo::tile_off_qs_b(lane), 8);
    const uint8_t *tail = block + halo::tile_off_tail(lane);
    halo::decode_block(qs, tail, trits);
    std::memcpy(&scale, tail + 2, 2);
    for (int i = 0; i < 128; ++i) signed_trits[i] = int(trits[i]) - 1;
}

inline std::vector<uint8_t> pack_pair_from_halo(const uint8_t *gate, const uint8_t *up,
                                                int hidden, int kdim) {
    if (hidden % 32 || kdim % 128) throw std::runtime_error("HALO pair geometry");
    int nb = kdim / 128;
    std::vector<uint8_t> result(size_t(hidden / 16) * nb * PAIR_BLOCK_BYTES, 0);
    for (int tile = 0; tile < hidden / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            size_t src = (size_t(tile / 2) * nb + b) * halo::TILE_BLOCK_BYTES;
            auto *dst = result.data() + (size_t(tile) * nb + b) * PAIR_BLOCK_BYTES;
            for (int row = 0; row < 16; ++row) {
                int lane = (tile & 1) * 16 + row;
                int8_t g[128], u[128]; uint16_t gs, us;
                decode_halo_row(gate + src, lane, g, gs);
                decode_halo_row(up + src, lane, u, us);
                pack_pair_row(dst, row, g, u, gs, us);
            }
        }
    return result;
}
}
