// Whole-FFN candidates for the three-channel ternary packing, and its matched native baseline.
//
// Residual in, residual out, for N real tokens, through the same four-kernel shape the arithmetic
// maps use: producer, gate/up with fused SiLU, hidden producer, down accumulated onto the residual.
// Both candidates quantise activations to ternary and differ only in how the ternary weights meet
// them:
//
//   tp-triple-a2  one FP16 operand w0 + 60*w1 + 1987*w2 carries three ternary weight rows, so one
//                 v_wmma_f32_16x16x16_f16 covers 48 logical rows x 16 tokens. Ternary activations
//                 bound each channel's K16 partial sum by 16, which is what makes the three
//                 channels separable -- and also why they must be separated after every single
//                 instruction, since no radix ladder inside an FP16 operand survives two.
//   tp-iu4-a2     v_wmma_i32_16x16x16_iu4 on the same ternary activations, two-bit weight storage
//                 expanded to nibbles in registers, one logical row per matrix row, exact integer
//                 accumulation and no separation at all.
//
// The two share the producer, the tiling policy, the epilogue and the quantiser, so the difference
// between them is the map. tp-iu4-a2 is also the speed of native IU4 at four-bit activations: the
// instruction, the operand widths and the traffic are identical, only the quantiser differs. That
// matters for reading these numbers, because four-bit activations are much better behaved than
// ternary ones at whole-model quality.
//
// The activation quantiser is a deterministic per (row, 128-block) ternary map of the TWN form:
// threshold 0.7 * mean|v|, code sign(v) outside it, scale the mean magnitude of the coded entries.
// Weights are never approximated: they stay the deployed ternary values with their deployed FP16
// block scales.
#include "../../api.hpp"
#include "../triple_kernels.hpp"
#include "halo_format.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <algorithm>

using namespace kelana_triple;
using namespace kelana_triple_kernels;

namespace {

// ------------------------------------------------------------------ candidate plumbing

struct Plan {
    int D = 0, FF = 0, maxrows = 0, FFpad = 0, Dpad = 0;
    bool triple = false;
    uint8_t *wg = nullptr, *wu = nullptr, *wd = nullptr;
    uint16_t *sg = nullptr, *su = nullptr, *sd = nullptr;
    void *Bin = nullptr, *Bhid = nullptr;
    float *csin = nullptr, *cshid = nullptr, *hidden = nullptr;
    const float *norm = nullptr, *signs = nullptr;
    size_t bytes = 0;
};

// HALO tile rows carry 32 logical rows per block; row r of tile t is lane (t & 1) * 16 + r of
// block t/2. Decoding is untimed preparation.
void decode_matrix(const uint8_t *halo_bytes, int rows, int kdim,
                   std::vector<int8_t> &trits, std::vector<uint16_t> &scales, int padded_rows) {
    const int nb = kdim / 128;
    trits.assign(size_t(padded_rows) * kdim, 0);
    scales.assign(size_t(padded_rows) * nb, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            const size_t src = (size_t(tile / 2) * nb + b) * halo::TILE_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                const int lane = (tile & 1) * 16 + r, row = tile * 16 + r;
                uint8_t qs[24], t128[128];
                std::memcpy(qs, halo_bytes + src + halo::tile_off_qs_a(lane), 16);
                std::memcpy(qs + 16, halo_bytes + src + halo::tile_off_qs_b(lane), 8);
                const uint8_t *tail = halo_bytes + src + halo::tile_off_tail(lane);
                halo::decode_block(qs, tail, t128);
                std::memcpy(&scales[size_t(row) * nb + b], tail + 2, 2);
                for (int j = 0; j < 128; ++j)
                    trits[size_t(row) * kdim + b * 128 + j] = int8_t(int(t128[j]) - 1);
            }
        }
}

template <class T> void upload(T *&dst, const std::vector<T> &src, size_t &total) {
    check(hipMalloc(&dst, src.size() * sizeof(T)), "malloc");
    check(hipMemcpy(dst, src.data(), src.size() * sizeof(T), hipMemcpyHostToDevice), "upload");
    total += src.size() * sizeof(T);
}

template <bool TRIPLE>
void *prepare(const kelana_batch::Weights &w, int maxrows) {
    auto *p = new Plan{};
    p->D = w.width; p->FF = w.hidden; p->maxrows = maxrows; p->triple = TRIPLE;
    p->norm = w.norm_device; p->signs = w.signs_device;
    const int unit = TRIPLE ? ROWS_PER_TILE : 16;
    p->FFpad = (p->FF + unit - 1) / unit * unit;
    p->Dpad = (p->D + unit - 1) / unit * unit;
    std::vector<int8_t> g, u, d;
    std::vector<uint16_t> gs, us, ds;
    decode_matrix(w.gate_host, p->FF, p->D, g, gs, p->FFpad);
    decode_matrix(w.up_host, p->FF, p->D, u, us, p->FFpad);
    decode_matrix(w.down_host, p->D, p->FF, d, ds, p->Dpad);
    if constexpr (TRIPLE) {
        upload(p->wg, pack_triple(g.data(), gs.data(), p->FFpad, p->D, LAD), p->bytes);
        upload(p->wu, pack_triple(u.data(), us.data(), p->FFpad, p->D, LAD), p->bytes);
        upload(p->wd, pack_triple(d.data(), ds.data(), p->Dpad, p->FF, LAD), p->bytes);
    } else {
        upload(p->wg, pack_two_bit(g.data(), p->FFpad, p->D), p->bytes);
        upload(p->wu, pack_two_bit(u.data(), p->FFpad, p->D), p->bytes);
        upload(p->wd, pack_two_bit(d.data(), p->Dpad, p->FF), p->bytes);
        upload(p->sg, gs, p->bytes); upload(p->su, us, p->bytes); upload(p->sd, ds, p->bytes);
    }
    const int Npad = (maxrows + 15) / 16 * 16;
    const size_t frag = TRIPLE ? 32 : 8;
    const size_t bin = size_t(p->D / 16) * Npad * frag, bhid = size_t(p->FF / 16) * Npad * frag;
    check(hipMalloc(&p->Bin, bin), "Bin");
    check(hipMalloc(&p->Bhid, bhid), "Bhid");
    check(hipMemset(p->Bin, 0, bin), "Bin zero");
    check(hipMemset(p->Bhid, 0, bhid), "Bhid zero");
    check(hipMalloc(&p->csin, size_t(Npad) * (p->D / KB) * 4), "csin");
    check(hipMalloc(&p->cshid, size_t(Npad) * (p->FF / KB) * 4), "cshid");
    check(hipMemset(p->csin, 0, size_t(Npad) * (p->D / KB) * 4), "csin zero");
    check(hipMemset(p->cshid, 0, size_t(Npad) * (p->FF / KB) * 4), "cshid zero");
    check(hipMalloc(&p->hidden, size_t(Npad) * p->FF * 4), "hidden");
    p->bytes += bin + bhid + size_t(Npad) * ((p->D + p->FF) / KB) * 4 + size_t(Npad) * p->FF * 4;
    return p;
}

void release(void *state) {
    auto *p = static_cast<Plan *>(state);
    for (void *q : {(void *) p->wg, (void *) p->wu, (void *) p->wd, (void *) p->sg, (void *) p->su,
                    (void *) p->sd, p->Bin, p->Bhid, (void *) p->csin, (void *) p->cshid, (void *) p->hidden})
        if (q) hipFree(q);
    delete p;
}
size_t resident_bytes(void *state) { return static_cast<Plan *>(state)->bytes; }

// Enough workgroups to fill the device without splitting a weight stream already spread over more
// workgroups than the machine has compute units.
int group_split(int tiles, int groups) {
    const int want = 320 / (tiles > 0 ? tiles : 1);
    return std::max(1, std::min(groups, want));
}

struct Stages {
    bool on = getenv("KELANA_TRIPLE_STAGES") != nullptr;
    hipEvent_t ev[5]{};
    const char *name[4] = {"prep_in", "gate_up_silu", "prep_hidden", "down_residual"};
    int at = 0;
    void mark(hipStream_t s) { if (!on) return; if (!ev[at]) hipEventCreate(&ev[at]); hipEventRecord(ev[at], s); ++at; }
    void report(const char *who, int rows) {
        if (!on) return;
        hipEventSynchronize(ev[4]);
        std::fprintf(stderr, "%-16s rows %-4d", who, rows);
        for (int i = 0; i < 4; ++i) { float t = 0; hipEventElapsedTime(&t, ev[i], ev[i + 1]);
            std::fprintf(stderr, "  %s %6.3f ms", name[i], t); }
        std::fprintf(stderr, "\n");
        at = 0;
    }
};

template <bool TRIPLE>
void run(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    static Stages st;
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16;
    st.mark(stream);
    k_prep<TRIPLE, true, true><<<rows * (D / 1024), NT, 0, stream>>>(
        input, p->norm, p->Bin, p->csin, D, Npad);
    st.mark(stream);
    // Two token tiles is this map's ceiling. Three decoded channels need three output
    // accumulators and three per-block accumulators per token tile, 48 registers against the
    // native map's 16, so four token tiles spills 117 VGPRs to scratch. The native baseline runs
    // four. Gate and up are separate passes over the hidden buffer for the same reason.
    if constexpr (TRIPLE) {
        const int gtiles = p->FFpad / ROWS_PER_TILE, dtiles = p->Dpad / ROWS_PER_TILE;
#define TPROJ(TT, EPI, WA, BF, CS, SG, RS, OUT, NB, TILES, OSTRIDE, OROWS) \
        k_proj_triple<TT, EPI><<<dim3(((TILES) + NW - 1) / NW, \
            group_split(((TILES) + NW - 1) / NW, Npad / (TT * 16))), \
            NW * 32, 0, stream>>>(WA, (const half16 *) (BF), CS, SG, RS, OUT, NB, rows, Npad, \
            OSTRIDE, OROWS, TILES)
#define TGATEUP(TT) \
        TPROJ(TT, 1, p->wg, p->Bin, p->csin, nullptr, nullptr, p->hidden, D / KB, gtiles, FF, FF); \
        TPROJ(TT, 2, p->wu, p->Bin, p->csin, p->signs, nullptr, p->hidden, D / KB, gtiles, FF, FF)
        if (Npad >= 32) { TGATEUP(2); } else { TGATEUP(1); }
#undef TGATEUP
        st.mark(stream);
        k_prep<TRIPLE, false, false><<<rows * (FF / 1024), NT, 0, stream>>>(
            p->hidden, nullptr, p->Bhid, p->cshid, FF, Npad);
        st.mark(stream);
        if (Npad >= 32) {
            TPROJ(2, 0, p->wd, p->Bhid, p->cshid, nullptr, input, output, FF / KB, dtiles, D, D);
        } else {
            TPROJ(1, 0, p->wd, p->Bhid, p->cshid, nullptr, input, output, FF / KB, dtiles, D, D);
        }
#undef TPROJ
    } else {
        const int gtiles = p->FFpad / 16, dtiles = p->Dpad / 16;
#define IPROJ(TT, FUSE, WA, WB_, BF, SA, SB, CS, SG, RS, OUT, NB, TILES, OSTRIDE, OROWS) \
        k_proj_iu4<TT, FUSE><<<dim3(((TILES) + NW - 1) / NW, \
            group_split(((TILES) + NW - 1) / NW, Npad / (TT * 16))), \
            NW * 32, 0, stream>>>(WA, WB_, (const int2v *) (BF), SA, SB, CS, SG, RS, OUT, NB, rows, \
            Npad, OSTRIDE, OROWS, TILES)
        if (Npad >= 64) {
            IPROJ(4, true, p->wg, p->wu, p->Bin, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, gtiles, FF, FF);
        } else if (Npad == 32) {
            IPROJ(2, true, p->wg, p->wu, p->Bin, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, gtiles, FF, FF);
        } else {
            IPROJ(1, true, p->wg, p->wu, p->Bin, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, gtiles, FF, FF);
        }
        st.mark(stream);
        k_prep<TRIPLE, false, false><<<rows * (FF / 1024), NT, 0, stream>>>(
            p->hidden, nullptr, p->Bhid, p->cshid, FF, Npad);
        st.mark(stream);
        if (Npad >= 64) {
            IPROJ(4, false, p->wd, nullptr, p->Bhid, p->sd, nullptr, p->cshid, nullptr, input, output, FF / KB, dtiles, D, D);
        } else if (Npad == 32) {
            IPROJ(2, false, p->wd, nullptr, p->Bhid, p->sd, nullptr, p->cshid, nullptr, input, output, FF / KB, dtiles, D, D);
        } else {
            IPROJ(1, false, p->wd, nullptr, p->Bhid, p->sd, nullptr, p->cshid, nullptr, input, output, FF / KB, dtiles, D, D);
        }
#undef IPROJ
    }
    st.mark(stream);
    st.report(TRIPLE ? "tp-triple-a2" : "tp-iu4-a2", rows);
}

kelana_batch::Candidate triple_a2() {
    return {"tp-triple-a2", kelana_batch::Claim::approximate,
            "three ternary weight rows per FP16 operand (1,60,1987), ternary activations, decode every K16",
            prepare<true>, run<true>, release, resident_bytes};
}
kelana_batch::Candidate iu4_a2() {
    return {"tp-iu4-a2", kelana_batch::Claim::approximate,
            "native IU4 on the same ternary activations and the same producer, epilogue and tiling policy",
            prepare<false>, run<false>, release, resident_bytes};
}
}
KELANA_BATCH_REGISTER(triple_a2)
KELANA_BATCH_REGISTER(iu4_a2)
