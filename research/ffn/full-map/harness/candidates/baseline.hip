// Deployed Bonsai FFN, lifted out of kernels/halo_rows.hip without rewriting it: the same
// ph_prep / ph_matvec_auto phases, the same flags, segment geometry, block splits and device
// barrier, with the same TT dispatch launch_forward_rows performs (1/2/4 rows -> the dot4 kernel,
// 8 rows -> the WMMA kernel through MV_DOT4_MAX).
#include "../ffn_harness.h"
#include <hip/hip_runtime.h>
#include "device.hpp"
#include "phases.hpp"
#include <algorithm>
#include <cstdio>
#include <cstdlib>

using namespace halo;

namespace {

struct FfnParams {
    const uint8_t * gate, * up, * down;
    const float * post_norm_s, * signs_ff;
    float * x, * gu, * xs;
    int8_t * xq;
    int * xsum;
    unsigned * bar, * work;
    unsigned long long * prof;
    int nrows;
};

// halo_rows.hip lines 206-215: post-norm/sign/Hadamard/quant -> gate and up -> SiLU(g)*u/sign/
// Hadamard/quant -> down accumulated into the residual.
template <int TT>
__global__ void __launch_bounds__(NT) k_ffn(FfnParams P) {
    __shared__ __attribute__((aligned(16))) float lds[LDS_FLOATS];
    __shared__ float red[8];
    __shared__ int s_unit;
    Ctx c { P.bar, P.work, P.prof, 0, 0, true, lds, red, &s_unit };
    const int nrows = P.nrows;
    if (P.prof && blockIdx.x == 0 && threadIdx.x == 0) P.prof[0] = wall_clock64();

    { PrepR p{}; p.x = P.x; p.kvec = P.post_norm_s; p.eps = NORM_EPS; p.n = D; p.flags = PREP_NORM | PREP_HADAMARD | PREP_QUANT;
      p.xq = P.xq; p.xs = P.xs; p.xsum = P.xsum; ph_prep(c, p, nrows); }
    grid_sync(c);
    { MvR m{}; m.nseg = 2; m.seg[0] = { P.gate, P.gu, FF / 32, 0 }; m.seg[1] = { P.up, P.gu + (size_t) RMAX * FF, FF / 32, 0 }; m.total_tiles = 2 * FF / 32;
      ph_matvec_auto<NB_D, 1, TT, false>(c, m, P.xq, P.xs, P.xsum, nrows); }
    grid_sync(c);
    { PrepR p{}; p.x = P.gu; p.x2 = P.gu + (size_t) RMAX * FF; p.kvec = P.signs_ff; p.n = FF; p.flags = PREP_SILU_MUL | PREP_HADAMARD | PREP_QUANT;
      p.xq = P.xq; p.xs = P.xs; p.xsum = P.xsum; ph_prep(c, p, nrows); }
    grid_sync(c);
    { MvR m{}; m.nseg = 1; m.seg[0] = { P.down, P.x, D / 32, 1 }; m.total_tiles = D / 32;
      ph_matvec_auto<NB_FF, 2, TT, false>(c, m, P.xq, P.xs, P.xsum, nrows); }
    grid_sync(c);
}

const void * fn_for(int nrows) {
    return nrows <= 1 ? (const void *) k_ffn<1> : nrows <= 2 ? (const void *) k_ffn<2>
         : nrows <= 4 ? (const void *) k_ffn<4> : (const void *) k_ffn<8>;
}

int baseline_grid(int) {
    // launch_forward_rows takes the minimum over every row specialisation so one persistent grid
    // serves all of them; the same rule here keeps the geometry identical across row counts.
    static int g = std::min({ coop_grid((const void *) k_ffn<1>), coop_grid((const void *) k_ffn<2>),
                              coop_grid((const void *) k_ffn<4>), coop_grid((const void *) k_ffn<8>) });
    return g;
}

void * baseline_prepare(const kffn::Shape & s, const kffn::Weights &) {
    if (s.D != D || s.FF != FF || s.rmax != RMAX) { fprintf(stderr, "baseline: geometry mismatch\n"); abort(); }
    return nullptr;
}

void baseline_run(void *, const kffn::Shape &, const kffn::Weights & w, const kffn::Work & k, int nrows, hipStream_t st) {
    FfnParams P{};
    P.gate = w.gate; P.up = w.up; P.down = w.down;
    P.post_norm_s = w.post_norm_s; P.signs_ff = w.signs_ff;
    P.x = k.x; P.gu = k.gu; P.xq = k.xq; P.xs = k.xs; P.xsum = k.xsum;
    P.bar = k.bar; P.work = k.work; P.prof = k.prof; P.nrows = nrows;
    void * args[] = { (void *) &P };
    hipError_t e = hipLaunchCooperativeKernel(fn_for(nrows), dim3(k.grid), dim3(NT), args, 0, st);
    if (e != hipSuccess) { fprintf(stderr, "baseline launch failed: %s\n", hipGetErrorString(e)); abort(); }
}

const char * instruction(int nrows) { return nrows > MV_DOT4_MAX ? "wmma_i32_16x16x16_iu8_w32" : "sudot4"; }

const char * const stage_names[] = { "prep_post_norm", "mv_gate_up", "prep_silu_mul", "mv_down" };

kffn::Candidate baseline() {
    kffn::Candidate c{};
    c.name = "baseline";
    c.stages = stage_names;
    c.nstages = 4;
    c.emits_gate_up = true;
    c.emits_ff_quant = true;
    c.grid = baseline_grid;
    c.instruction = instruction;
    c.prepare = baseline_prepare;
    c.run = baseline_run;
    c.release = nullptr;
    return c;
}

} // namespace

KFFN_REGISTER(baseline)
