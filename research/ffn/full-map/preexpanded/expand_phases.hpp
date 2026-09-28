// Gate/up phase over fully expanded paired operands, and the producer that builds those operands
// from compact pair blocks inside a call.
//
// The consumer is ph_pair_gate_up with its decode deleted: the A fragment is loaded, not rebuilt,
// and every later instruction (the eight WMMA accumulations, the g + 2047u recovery, the digit
// plane recombination, the per-block scale FMAs and the SiLU product) is the compact kernel's, in
// the compact kernel's order. What changes is the byte stream: 4160 bytes per 16x128 block instead
// of 1088.
#pragma once
#include "expand_codec.hpp"
#include "../paired_phases.hpp"

namespace halo {
namespace {

using kelana_ffn::EXP_BLOCK_BYTES;
using kelana_ffn::EXP_SCALES_OFF;
using kelana_ffn::half16;

using uint4v = unsigned __attribute__((ext_vector_type(4)));

// NT marks the operand stream non-temporal. The expanded image is 181 MB against a 32 MB last
// level cache, so it can only evict the digit planes and the down tensor it shares that cache with.
template<bool NT = false>
__device__ __forceinline__ half16 load_operand(const uint8_t *block, int slice, int row) {
    const auto *p = (const uint4v *) (block + slice * kelana_ffn::EXP_SLICE_BYTES + row * kelana_ffn::EXP_ROW_BYTES);
    if constexpr (NT) {
        uint4v a = __builtin_nontemporal_load(p);
        uint4v b = __builtin_nontemporal_load(p + 1);
        unsigned v[8] = {a.x, a.y, a.z, a.w, b.x, b.y, b.z, b.w};
        return __builtin_bit_cast(half16, *(const kelana_ffn::uint8v *) v);
    }
    return *(const half16 *) p;
}

// PF slices of the A stream are kept in flight. The compact kernel prefetches a whole block ahead
// in 32 VGPRs because a block of codes is 64 bytes per lane; a block of expanded operands is 256
// bytes per lane, so the same depth would cost 64 VGPRs and the occupancy that hides the latency.
// The pipeline depth is therefore a knob, not a whole block.
// SPLIT selects the layout: interleaved 4160-byte blocks (operand bytes followed by their scales),
// or 4096-byte operand blocks with the scales in their own array, which keeps every block on the
// 128-byte line grid.
template<int NB, int HIDDEN, bool CAPTURE = false, int PF = 4, bool SPLIT = false, bool NT = false>
__device__ __forceinline__ void ph_expanded_gate_up(Ctx &c, const uint8_t *weights,
        const _Float16 *planes, const float *xs, const float *signs,
        float *hidden, int nrows, float *capture_gate = nullptr, float *capture_up = nullptr,
        const uint8_t *scale_base = nullptr) {
    constexpr int PW = NB / NW;
    static_assert(NB % NW == 0 && (PF == 1 || PF == 2 || PF == 4 || PF == 8), "pipeline depth");
    int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    int col = lane & 15, token = col & 7, plane = col >> 3, half = lane >> 4;
    constexpr int total = HIDDEN / 16;
    for (int tile = blockIdx.x; tile >= 0 && tile < total; tile = next_unit(c, total)) {
        c.dirty = true;
        float8 yg = {}, yu = {};
        float *scl = c.lds + (NW - 1) * 8 * 32 + wave * 32;
        constexpr int STRIDE = SPLIT ? kelana_ffn::EXP_OPERAND_BYTES : EXP_BLOCK_BYTES;
        const size_t blk0 = size_t(tile) * NB + wave * PW;
        const uint8_t *w = weights + blk0 * STRIDE;
        const uint8_t *sb = SPLIT ? scale_base + blk0 * 64 : w + EXP_SCALES_OFF;
        half16 buf[PF];
        #pragma unroll
        for (int s = 0; s < PF; ++s) buf[s] = load_operand<NT>(w, s, col);
        unsigned scales = *(const unsigned *) (sb + col * 4);
        #pragma unroll 1
        for (int bi = 0; bi < PW; ++bi) {
            const bool more = bi + 1 < PW;
            const uint8_t *wn = more ? w + STRIDE : w;
            const uint8_t *sn = SPLIT ? (more ? sb + 64 : sb) : wn + EXP_SCALES_OFF;
            unsigned next_scales = *(const unsigned *) (sn + col * 4);
            if (lane < 16) {
                scl[lane] = __half2float(__ushort_as_half(scales & 0xffffu));
                scl[lane + 16] = __half2float(__ushort_as_half(scales >> 16));
            }
            __builtin_amdgcn_wave_barrier();
            float8 p = {};
            #pragma unroll
            for (int slice = 0; slice < 8; ++slice) {
                half16 a = buf[slice % PF];
                buf[slice % PF] = load_operand<NT>(slice + PF < 8 ? w : wn, (slice + PF) & 7, col);
                half16 b = *(const half16 *)(planes + size_t(plane * 8 + token) * (NB * 128)
                                            + (wave * PW + bi) * 128 + slice * 16);
                p = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, b, p);
            }
            float scale_x = xs[token * NB + wave * PW + bi];
            #pragma unroll
            for (int r = 0; r < 8; ++r) {
                float g, u;
                kelana_ffn::unpair(p[r], g, u);
                float gp = kelana_ffn::plane_partner(g), up = kelana_ffn::plane_partner(u);
                g = fmaf(16.0f, gp, g); u = fmaf(16.0f, up, u);
                int row = r * 2 + half;
                yg[r] = fmaf(g, scl[row] * scale_x, yg[r]);
                yu[r] = fmaf(u, scl[row + 16] * scale_x, yu[r]);
            }
            w = wn;
            sb = sn;
            scales = next_scales;
        }
        float gate[8];
        for (int pass = 0; pass < 2; ++pass) {
            float8 y = pass == 0 ? yg : yu;
            if (wave) {
                #pragma unroll
                for (int r = 0; r < 8; ++r) c.lds[((wave - 1) * 8 + r) * 32 + lane] = y[r];
            }
            __syncthreads();
            if (wave == 0 && col < nrows) {
                #pragma unroll
                for (int r = 0; r < 8; ++r) {
                    float v = y[r];
                    #pragma unroll
                    for (int w2 = 1; w2 < NW; ++w2) v += c.lds[((w2 - 1) * 8 + r) * 32 + lane];
                    int row = tile * 16 + 2 * r + half;
                    size_t o = size_t(token) * HIDDEN + row;
                    if (pass == 0) {
                        gate[r] = v;
                        if constexpr (CAPTURE) capture_gate[o] = v;
                    } else {
                        if constexpr (CAPTURE) capture_up[o] = v;
                        hidden[o] = silu(gate[r]) * v * signs[row];
                    }
                }
            }
            __syncthreads();
        }
    }
    end_phase(c);
}

// Producer for the staging variant: decodes every compact pair block once into the transient
// operand cache the consumer above reads. One workgroup takes one 16x128 block; 128 of its threads
// each turn one row's 16 nibble codes into one 32-byte A fragment.
template<int NB, int HIDDEN>
__device__ __forceinline__ void ph_stage_operands(Ctx &c, const uint8_t *compact, uint8_t *cache) {
    constexpr int total = (HIDDEN / 16) * NB;
    const int tid = threadIdx.x, row = tid & 15, slice = tid >> 4;
    for (int blk = blockIdx.x; blk >= 0 && blk < total; blk = next_unit(c, total)) {
        c.dirty = true;
        const uint8_t *src = compact + size_t(blk) * kelana_ffn::PAIR_BLOCK_BYTES;
        uint8_t *dst = cache + size_t(blk) * EXP_BLOCK_BYTES;
        if (tid < 128) {
            uint2 codes = *(const uint2 *) (src + slice * 128 + row * 8);
            *(half16 *) (dst + slice * kelana_ffn::EXP_SLICE_BYTES + row * kelana_ffn::EXP_ROW_BYTES)
                = kelana_ffn::decode_sixteen(codes);
        }
        if (tid < 16)
            *(unsigned *) (dst + EXP_SCALES_OFF + tid * 4)
                = *(const unsigned *) (src + kelana_ffn::PAIR_CODES_BYTES + tid * 4);
    }
    end_phase(c);
}

}
}
