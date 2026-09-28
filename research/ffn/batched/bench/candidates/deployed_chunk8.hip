// The comparison reference: the deployed Bonsai FFN, unmodified, over a batch.
//
// The deployed multi-row kernel carries RMAX = 8 rows, so a batch of N rows is N/8 consecutive
// launches of exactly that kernel with exactly the phases, flags, segment geometry, block splits
// and device barrier of kernels/halo_rows.hip lines 206-215. Nothing about the arithmetic changes
// with the batch size, so this is both the numeric reference and the honest "what the engine would
// do today with N rows" timing point: the row-count cost of the deployed schedule, including its
// per-launch cooperative grid and its per-chunk weight traffic.
//
// Everything input-dependent is inside run: the residual copy, both quantisations, the projections,
// the nonlinearity and the accumulate. prepare only allocates.
#include "../../api.hpp"
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

template <int TT>
__global__ void __launch_bounds__(NT) k_ffn(FfnParams P) {
    __shared__ __attribute__((aligned(16))) float lds[LDS_FLOATS];
    __shared__ float red[8];
    __shared__ int s_unit;
    Ctx c { P.bar, P.work, P.prof, 0, 0, true, lds, red, &s_unit };
    const int nrows = P.nrows;
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

// launch_forward_rows takes the minimum over every row specialisation so one persistent grid serves
// all of them; the same rule keeps the geometry identical across chunk sizes here.
int deployed_grid() {
    static int g = std::min({ coop_grid((const void *) k_ffn<1>), coop_grid((const void *) k_ffn<2>),
                              coop_grid((const void *) k_ffn<4>), coop_grid((const void *) k_ffn<8>) });
    return g;
}

constexpr int BAR_STRIDE = 16, WORK_STRIDE = 64;
constexpr int RING_SLOTS = 1 << 15;

struct State {
    kelana_batch::Weights w;
    int max_rows = 0, grid = 0;
    int8_t * xq = nullptr;
    float * xs = nullptr, * gu = nullptr;
    int * xsum = nullptr;
    unsigned * bar_ring = nullptr, * work_ring = nullptr;
    int slot = 0;
    size_t bytes = 0;
};

#define HC(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) { fprintf(stderr, "deployed_chunk8: %s: %s\n", #x, hipGetErrorString(e_)); abort(); } } while (0)

void * prepare(const kelana_batch::Weights & w, int max_batch) {
    if (w.width != D || w.hidden != FF) { fprintf(stderr, "deployed_chunk8: geometry mismatch\n"); abort(); }
    State * s = new State();
    s->w = w;
    s->max_rows = max_batch;
    s->grid = deployed_grid();
    HC(hipMalloc(&s->xq, (size_t) RMAX * FF));
    HC(hipMalloc(&s->xs, (size_t) RMAX * (FF / 128) * 4));
    HC(hipMalloc(&s->xsum, (size_t) RMAX * (FF / 128) * 4));
    HC(hipMalloc(&s->gu, (size_t) 2 * RMAX * FF * 4));
    HC(hipMalloc(&s->bar_ring, (size_t) RING_SLOTS * BAR_STRIDE * 4));
    HC(hipMalloc(&s->work_ring, (size_t) RING_SLOTS * WORK_STRIDE * 4));
    HC(hipMemset(s->bar_ring, 0, (size_t) RING_SLOTS * BAR_STRIDE * 4));
    HC(hipMemset(s->work_ring, 0, (size_t) RING_SLOTS * WORK_STRIDE * 4));
    s->bytes = (size_t) RMAX * FF + (size_t) RMAX * (FF / 128) * 8 + (size_t) 2 * RMAX * FF * 4
             + (size_t) RING_SLOTS * (BAR_STRIDE + WORK_STRIDE) * 4;
    HC(hipDeviceSynchronize());
    return s;
}

void run(void * st, int rows, const float * input, float * output, hipStream_t stream) {
    State * s = (State *) st;
    // The deployed down projection accumulates into the residual it was given, so the batch starts
    // as a copy of the input rows. This copy is input-dependent work and stays inside the interval.
    HC(hipMemcpyAsync(output, input, (size_t) rows * D * 4, hipMemcpyDeviceToDevice, stream));
    const int chunks = (rows + RMAX - 1) / RMAX;
    if (s->slot + chunks > RING_SLOTS) {
        // A reused non-zero barrier slot would let grid_sync pass without synchronising, so the ring
        // is re-zeroed when it wraps. One memset every RING_SLOTS/chunks calls.
        HC(hipMemsetAsync(s->bar_ring, 0, (size_t) RING_SLOTS * BAR_STRIDE * 4, stream));
        HC(hipMemsetAsync(s->work_ring, 0, (size_t) RING_SLOTS * WORK_STRIDE * 4, stream));
        s->slot = 0;
    }
    for (int c = 0; c < chunks; c++) {
        const int n = std::min(RMAX, rows - c * RMAX);
        FfnParams P{};
        P.gate = s->w.gate_device; P.up = s->w.up_device; P.down = s->w.down_device;
        P.post_norm_s = s->w.norm_device; P.signs_ff = s->w.signs_device;
        P.x = output + (size_t) c * RMAX * D;
        P.gu = s->gu; P.xq = s->xq; P.xs = s->xs; P.xsum = s->xsum;
        P.bar = s->bar_ring + (size_t) s->slot * BAR_STRIDE;
        P.work = s->work_ring + (size_t) s->slot * WORK_STRIDE;
        P.prof = nullptr;
        P.nrows = n;
        s->slot++;
        void * args[] = { (void *) &P };
        HC(hipLaunchCooperativeKernel(fn_for(n), dim3(s->grid), dim3(NT), args, 0, stream));
    }
}

void release(void * st) {
    State * s = (State *) st;
    if (!s) return;
    hipFree(s->xq); hipFree(s->xs); hipFree(s->xsum); hipFree(s->gu);
    hipFree(s->bar_ring); hipFree(s->work_ring);
    delete s;
}

size_t resident_bytes(void * st) { return st ? ((State *) st)->bytes : 0; }

kelana_batch::Candidate deployed_chunk8() {
    kelana_batch::Candidate c{};
    c.name = "deployed_chunk8";
    c.claim = kelana_batch::Claim::exact_reference;
    c.description = "deployed Bonsai FFN kernel, unmodified, run as rows/8 consecutive 8-row launches";
    c.prepare = prepare;
    c.run = run;
    c.release = release;
    c.resident_bytes = resident_bytes;
    return c;
}

} // namespace

KELANA_BATCH_REGISTER(deployed_chunk8)
