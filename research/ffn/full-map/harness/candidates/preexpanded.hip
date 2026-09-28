// Does precomputing the paired FP16 operands pay for itself once the traffic recurs?
//
// `preexpanded*` keeps the compact kernel's arithmetic and replaces its decode with a load from a
// weight image expanded offline: 4160 bytes per 16x128 block against 1088 compact and 896 in the
// two deployed HALO tensors. The pipeline depth over that wider stream is the one knob (PF).
//
// `staged` answers the other half of the question: decode the compact weights once per call into a
// transient operand cache and let the gate/up consumer read that, instead of decoding at every
// consumer. With one consumer per FFN it pays a write plus a read of the expanded image against a
// read of the compact one, which is the break-even arithmetic the report needs.
#include "../ffn_harness.h"
#include "../../preexpanded/expand_phases.hpp"
#include "../../paired_load.hpp"
#include <cstdio>
#include <cstdlib>

using namespace halo;
namespace {

struct Params {
    const uint8_t *weights, *compact, *down, *scales;
    uint8_t *cache;
    const float *norm, *signs;
    kffn::Work work;
    int nrows;
};
struct State { uint8_t *weights = nullptr, *compact = nullptr, *cache = nullptr, *scales = nullptr; };

void check(hipError_t e, const char *what) {
    if (e != hipSuccess) { std::fprintf(stderr, "preexpanded %s: %s\n", what, hipGetErrorString(e)); std::abort(); }
}

size_t expanded_bytes(const kffn::Shape &s) {
    return size_t(s.FF / 16) * (s.D / 128) * kelana_ffn::EXP_BLOCK_BYTES;
}
size_t compact_bytes(const kffn::Shape &s) {
    return size_t(s.FF / 16) * (s.D / 128) * kelana_ffn::PAIR_BLOCK_BYTES;
}

// One launch per FFN: norm/Hadamard/quant into the two digit planes, gate and up against the
// expanded operands with the fused SiLU product, hidden quantisation, down into the residual.
template<bool CAPTURE, int PF, bool STAGE, bool SPLIT = false, bool NTLOAD = false>
__global__ __launch_bounds__(NT, 8) void kernel(Params p) {
    __shared__ __attribute__((aligned(16))) float lds[LDS_FLOATS];
    __shared__ float red[8];
    __shared__ int unit;
    const auto &w = p.work;
    Ctx c{w.bar, w.work, w.prof, 0, 0, true, lds, red, &unit};
    auto *planes = static_cast<_Float16 *>(w.scratch);
    float *hidden = reinterpret_cast<float *>(planes + 16 * D);
    if (w.prof && blockIdx.x == 0 && threadIdx.x == 0) w.prof[0] = wall_clock64();
    if constexpr (STAGE) {
        ph_stage_operands<NB_D, FF>(c, p.compact, p.cache);
        grid_sync(c);
    }
    {
        PrepR a{}; a.x = w.x; a.kvec = p.norm; a.eps = NORM_EPS; a.n = D; a.xs = w.xs;
        ph_pair_prep(c, a, planes, p.nrows);
    }
    grid_sync(c);
    ph_expanded_gate_up<NB_D, FF, CAPTURE, PF, SPLIT, NTLOAD>(c, STAGE ? p.cache : p.weights, planes, w.xs, p.signs,
                                                      hidden, p.nrows, w.gu, w.gu + RMAX * FF, p.scales);
    grid_sync(c);
    {
        PrepR a{}; a.x = hidden; a.n = FF; a.flags = PREP_HADAMARD | PREP_QUANT;
        a.xq = w.xq; a.xs = w.xs; a.xsum = w.xsum;
        ph_prep(c, a, p.nrows);
    }
    grid_sync(c);
    {
        MvR m{}; m.nseg = 1; m.seg[0] = {p.down, w.x, D / 32, 1}; m.total_tiles = D / 32;
        if (p.nrows <= 1) ph_matvec_auto<NB_FF, 2, 1, false>(c, m, w.xq, w.xs, w.xsum, p.nrows);
        else ph_matvec_auto<NB_FF, 2, 8, false>(c, m, w.xq, w.xs, w.xsum, p.nrows);
    }
    grid_sync(c);
}

template<bool STAGE, bool SPLIT = false>
void *prepare(const kffn::Shape &s, const kffn::Weights &w) {
    if (s.D != D || s.FF != FF || s.rmax != RMAX) std::abort();
    auto *state = new State{};
    if constexpr (SPLIT) {
        auto packed = kelana_ffn::pack_expanded_split_from_halo(w.gate_host, w.up_host, FF, D);
        check(hipMalloc(&state->weights, packed.operands.size()), "malloc operands");
        check(hipMemcpy(state->weights, packed.operands.data(), packed.operands.size(), hipMemcpyHostToDevice), "upload operands");
        check(hipMalloc(&state->scales, packed.scales.size()), "malloc scales");
        check(hipMemcpy(state->scales, packed.scales.data(), packed.scales.size(), hipMemcpyHostToDevice), "upload scales");
    } else if constexpr (STAGE) {
        auto packed = kelana_ffn::pack_pair_from_halo(w.gate_host, w.up_host, FF, D);
        check(hipMalloc(&state->compact, packed.size()), "malloc compact");
        check(hipMemcpy(state->compact, packed.data(), packed.size(), hipMemcpyHostToDevice), "upload compact");
        // The cache is transient state, not a weight image: every call refills it before reading it.
        check(hipMalloc(&state->cache, expanded_bytes(s)), "malloc cache");
        check(hipMemset(state->cache, 0, expanded_bytes(s)), "clear cache");
    } else {
        auto packed = kelana_ffn::pack_expanded_from_halo(w.gate_host, w.up_host, FF, D);
        check(hipMalloc(&state->weights, packed.size()), "malloc weights");
        check(hipMemcpy(state->weights, packed.data(), packed.size(), hipMemcpyHostToDevice), "upload weights");
    }
    return state;
}

void release(void *p) {
    auto *s = static_cast<State *>(p);
    if (s->weights) check(hipFree(s->weights), "free weights");
    if (s->scales) check(hipFree(s->scales), "free scales");
    if (s->compact) check(hipFree(s->compact), "free compact");
    if (s->cache) check(hipFree(s->cache), "free cache");
    delete s;
}

template<bool CAPTURE, int PF, bool STAGE, bool SPLIT = false, bool NTLOAD = false>
int grid(int) { static int n = coop_grid((const void *) kernel<CAPTURE, PF, STAGE, SPLIT, NTLOAD>); return n; }

template<bool CAPTURE, int PF, bool STAGE, bool SPLIT = false, bool NTLOAD = false>
void run(void *state, const kffn::Shape &, const kffn::Weights &w, const kffn::Work &k, int nrows, hipStream_t stream) {
    if (k.scratch_bytes < 16 * D * sizeof(_Float16) + RMAX * FF * sizeof(float)) std::abort();
    auto *s = static_cast<State *>(state);
    Params p{s->weights, s->compact, w.down, s->scales, s->cache, w.post_norm_s, w.signs_ff, k, nrows};
    void *args[] = {&p};
    check(hipLaunchCooperativeKernel((const void *) kernel<CAPTURE, PF, STAGE, SPLIT, NTLOAD>, dim3(k.grid), dim3(NT), args, 0, stream),
          "launch");
}

const char *instruction(int n) {
    return n <= 1 ? "expanded-f16-gate-up/sudot4-down" : "expanded-f16-gate-up/iu8-down";
}
const char *const stages[] = {"prep_digit_planes", "expanded_gate_up_silu", "prep_hidden_quant", "mv_down"};
const char *const staged_stages[] = {"stage_operands", "prep_digit_planes", "expanded_gate_up_silu", "prep_hidden_quant", "mv_down"};

size_t expanded_weight_bytes(const kffn::Shape &s, int) {
    return expanded_bytes(s) + halo_tensor_bytes(s.D, s.FF);
}
// Recurring weight-side traffic of the staging variant: the compact image is read, the expanded
// cache is written and then read back, and the down projection is read.
size_t staged_weight_bytes(const kffn::Shape &s, int) {
    return compact_bytes(s) + 2 * expanded_bytes(s) + halo_tensor_bytes(s.D, s.FF);
}

// The split layout drops the 64 interleaved scale bytes, so its recurring read is 4096 bytes of
// operands plus 64 of scales per block: the same bytes, on the line grid.
size_t split_weight_bytes(const kffn::Shape &s, int) {
    return size_t(s.FF / 16) * (s.D / 128) * (kelana_ffn::EXP_OPERAND_BYTES + 64) + halo_tensor_bytes(s.D, s.FF);
}

template<bool CAPTURE, int PF, bool STAGE, bool SPLIT = false, bool NTLOAD = false>
kffn::Candidate make(const char *name) {
    kffn::Candidate c{};
    c.name = name;
    c.emits_gate_up = CAPTURE;
    c.emits_ff_quant = true;
    c.stages = STAGE ? staged_stages : stages;
    c.nstages = STAGE ? 5 : 4;
    c.grid = grid<CAPTURE, PF, STAGE, SPLIT, NTLOAD>;
    c.instruction = instruction;
    c.prepare = prepare<STAGE, SPLIT>;
    c.run = run<CAPTURE, PF, STAGE, SPLIT, NTLOAD>;
    c.release = release;
    c.weight_bytes = STAGE ? staged_weight_bytes : (SPLIT ? split_weight_bytes : expanded_weight_bytes);
    return c;
}

kffn::Candidate preexpanded() { return make<false, 4, false>("preexpanded"); }
kffn::Candidate preexpanded_capture() { return make<true, 4, false>("preexpanded-capture"); }
kffn::Candidate preexpanded_pf2() { return make<false, 2, false>("preexpanded-pf2"); }
kffn::Candidate preexpanded_pf8() { return make<false, 8, false>("preexpanded-pf8"); }
kffn::Candidate preexpanded_split() { return make<false, 4, false, true>("preexpanded-split"); }
kffn::Candidate preexpanded_split_capture() { return make<true, 4, false, true>("preexpanded-split-capture"); }
kffn::Candidate preexpanded_split_pf8() { return make<false, 8, false, true>("preexpanded-split-pf8"); }
kffn::Candidate preexpanded_nt() { return make<false, 4, false, false, true>("preexpanded-nt"); }
kffn::Candidate preexpanded_nt_pf8() { return make<false, 8, false, false, true>("preexpanded-nt-pf8"); }
kffn::Candidate staged() { return make<false, 4, true>("staged"); }
kffn::Candidate staged_capture() { return make<true, 4, true>("staged-capture"); }

}
KFFN_REGISTER(preexpanded)
KFFN_REGISTER(preexpanded_capture)
KFFN_REGISTER(preexpanded_pf2)
KFFN_REGISTER(preexpanded_pf8)
KFFN_REGISTER(preexpanded_split)
KFFN_REGISTER(preexpanded_split_capture)
KFFN_REGISTER(preexpanded_split_pf8)
KFFN_REGISTER(preexpanded_nt)
KFFN_REGISTER(preexpanded_nt_pf8)
KFFN_REGISTER(staged)
KFFN_REGISTER(staged_capture)
