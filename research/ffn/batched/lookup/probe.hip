// Rate probe for ternary lookup / shared-addition maps at batched FFN token counts.
//
// It measures the three quantities that decide whether a table map can win at 32-256 tokens,
// on the real gate/up geometry (K = 5120, 34816 fused gate/up rows):
//
//   consume  the steady-state cost of "one packed add per (row, group)" with the group's table
//            already resident in LDS. This is the map's ceiling: no build, no weight decode.
//   build    the cost of constructing the 3^G forms of one group for a token tile, which is
//            what a workgroup must pay before its rows can consume them.
//   wmma     the deployed engine's arithmetic at the same shape: peel the HALO block to int8
//            trits and feed v_wmma_i32_16x16x16_iu8, one decode per row-block for all tokens.
//
// Rates normalize elapsed time by the supplied --clock GHz and HIP processor count (WGP).
// These are estimated MAC/clock/WGP, not measured cycle counts. Group probes also count padded
// tail products. Compare raw elapsed times when interpreting clock-sensitive differences.
//
// The probe deliberately does not compute a correct FFN: the operands are shaped like the real
// ones but carry probe data, and correctness of the packed lookup arithmetic itself is checked
// separately by check.cpp. Nothing here is a bit-exactness claim.

#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <string>
#include <vector>
#include <algorithm>

#define HC(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) { \
    fprintf(stderr, "%s:%d %s -> %s\n", __FILE__, __LINE__, #x, hipGetErrorString(e_)); exit(1); } } while (0)

namespace {

constexpr int K = 5120;          // Bonsai FFN input width
constexpr int NB = K / 128;      // 40 scale blocks of 128 inputs
constexpr int GU_ROWS = 34816;   // gate and up interleaved, 2 * 17408

// Groups per 128-input scale block for a group size G. The last group is padded with zero
// inputs when 128 is not a multiple of G, exactly as the deployed 43-group map pads input 129.
constexpr int groups_per_block(int G) { return (128 + G - 1) / G; }
constexpr int pow3(int G) { return G == 0 ? 1 : 3 * pow3(G - 1); }

// ------------------------------------------------------------------------------------------
// Consume: one packed add per (row, group), table resident in LDS.
//
// lane = output row, so the table index is divergent across the wave; that is forced, because a
// token-major layout with a uniform index needs the whole token tile of an entry in LDS at once
// and no useful group size fits. NP = TOK/2 dwords per entry hold two tokens per dword as
// (a + BIAS) + 65536 * (b + BIAS), the representation the deployed 43-group map carries through
// all of its adds.
//
// RSTEP rows per lane is the knob that decides how many rows a workgroup can amortise a table
// build over. It trades directly against NP for registers, which is the whole point of the
// measurement: a larger token tile buys nothing here, it spends the registers that rows need.

// SWIZZLE picks how an entry's NP planes are laid out in LDS:
//   0  planes contiguous, the natural layout. Every entry starts on bank (e*NP) mod 32, so when
//      NP is a multiple of 32 all lanes contend for one bank at every step.
//   1  entry stride padded by one dword, which spreads the entry starts across banks but leaves
//      the lanes' random indices to collide on their own.
//   2  plane index XORed with the lane, so at every step the 32 lanes touch 32 distinct planes.
//      With NP a power of two this makes the gather conflict-free whatever the indices are; a
//      lane then owns a rotated token order, which costs only a permuted scale read per block.
//   3  both. The rotation only has NP distinct values, so for NP < 32 lanes still share a
//      rotation and collide in pairs or worse; padding the entry stride breaks the remaining
//      ties, which is what lets a small token tile keep the roof and spend its registers on rows.
template <int G, int NP, int RSTEP, int WAVES, int SLOT_PASS, int SWIZZLE, bool LOAD_WEIGHTS>
__global__ __launch_bounds__(WAVES * 32) void k_consume(const uint8_t * __restrict__ widx,
                                                        const float * __restrict__ xs,
                                                        float * __restrict__ out,
                                                        int rows_per_wg) {
    constexpr int SLOTS = groups_per_block(G);
    constexpr int E = pow3(G);
    constexpr int PASSES = (SLOTS + SLOT_PASS - 1) / SLOT_PASS;
    constexpr int STRIDE = (SWIZZLE == 1 || SWIZZLE == 3) ? NP + 1 : NP;
    constexpr int PMASK = NP - 1;
    __shared__ unsigned tab[SLOT_PASS * E * STRIDE];

    const int tid = threadIdx.x, lane = tid & 31, wave = tid >> 5;
    // A deterministic, input-independent fill: the probe measures the consume loop, and the
    // values only have to be live data the compiler cannot fold away.
    for (int i = tid; i < SLOT_PASS * E * STRIDE; i += WAVES * 32) tab[i] = 0x00010001u * (unsigned) (i & 255);
    __syncthreads();

    const int row0 = blockIdx.x * rows_per_wg + wave * 32 + lane;
    const int rstride = WAVES * 32;
    const int rot = (SWIZZLE >= 2) ? (lane & PMASK) : 0;

    float y[RSTEP][2 * NP];
    #pragma unroll
    for (int r = 0; r < RSTEP; r++)
        #pragma unroll
        for (int t = 0; t < 2 * NP; t++) y[r][t] = 0.0f;

    #pragma unroll 1
    for (int b = 0; b < NB; b++) {
        unsigned acc[RSTEP][NP];
        #pragma unroll
        for (int r = 0; r < RSTEP; r++)
            #pragma unroll
            for (int p = 0; p < NP; p++) acc[r][p] = 0u;

        #pragma unroll 1
        for (int pass = 0; pass < PASSES; pass++) {
            #pragma unroll 1
            for (int s = 0; s < SLOT_PASS; s++) {
                const int slot = pass * SLOT_PASS + s;
                if (slot >= SLOTS) break;
                // Weight bytes are stored slot-major so lane = row reads them coalesced; this is
                // the layout a G = 5 map gets for free from HALO's own five-trits-per-byte qs.
                #pragma unroll
                for (int r = 0; r < RSTEP; r++) {
                    unsigned idx;
                    if (LOAD_WEIGHTS) {
                        const uint8_t * wp = widx + ((size_t) b * SLOTS + slot) * (size_t) GU_ROWS + row0;
                        idx = wp[r * rstride];
                    } else {
                        idx = (unsigned) (row0 * 2654435761u + slot * 40503u + r) >> 20;
                    }
                    idx = (E <= 256) ? idx % E : idx & (E - 1);
                    const unsigned * e = &tab[(s * E + idx) * STRIDE];
                    #pragma unroll
                    for (int p = 0; p < NP; p++) acc[r][p] += e[SWIZZLE >= 2 ? (p ^ rot) : p];
                }
            }
        }
        // One decode and scale FMA per 128-input block: tokens stay packed through the whole
        // scale group and only the block boundary unpacks them.
        const int bias = SLOTS * 128 * G;
        #pragma unroll
        for (int r = 0; r < RSTEP; r++) {
            #pragma unroll
            for (int p = 0; p < NP; p++) {
                int lo = int(acc[r][p] & 65535) - bias;
                int hi = int(acc[r][p] >> 16) - bias;
                // The lane's plane p carries token pair p ^ rot, so the scale read follows the
                // same rotation and nothing else in the schedule has to change.
                const int tp = (SWIZZLE >= 2) ? (p ^ rot) : p;
                y[r][2 * p] = fmaf((float) lo, xs[2 * tp * NB + b], y[r][2 * p]);
                y[r][2 * p + 1] = fmaf((float) hi, xs[(2 * tp + 1) * NB + b], y[r][2 * p + 1]);
            }
        }
    }
    #pragma unroll
    for (int r = 0; r < RSTEP; r++) {
        float s = 0.0f;
        #pragma unroll
        for (int t = 0; t < 2 * NP; t++) s += y[r][t];
        out[row0 + r * rstride] = s;
    }
}

// ------------------------------------------------------------------------------------------
// Build: construct the 3^G packed forms of one group from its G packed activation pairs, by the
// obvious prefix product, which is the cheapest construction available (one add per entry per
// level, with the zero digit a copy and the negative digit a subtract).

template <int G, int NP, int WAVES>
__global__ __launch_bounds__(WAVES * 32) void k_build(const int8_t * __restrict__ xq,
                                                      unsigned * __restrict__ sink, int reps) {
    constexpr int SLOTS = groups_per_block(G);
    constexpr int E = pow3(G);
    __shared__ unsigned tab[E * NP];
    const int tid = threadIdx.x, nthr = WAVES * 32;

    unsigned guard = 0;
    for (int rep = 0; rep < reps; rep++) {
        for (int slot = 0; slot < SLOTS; slot++) {
            // The G packed activation pairs this group selects from, one per input position.
            unsigned v[G][NP];
            #pragma unroll
            for (int g = 0; g < G; g++)
                #pragma unroll
                for (int p = 0; p < NP; p++) {
                    int a = xq[((rep + slot + g) * 128 + (2 * p) % 128) & 65535];
                    int c = xq[((rep + slot + g) * 128 + (2 * p + 1) % 128) & 65535];
                    v[g][p] = unsigned(a & 65535) | (unsigned(c) << 16);
                }
            if (tid == 0) for (int p = 0; p < NP; p++) tab[p] = 0u;
            __syncthreads();
            int span = 1;
            #pragma unroll
            for (int g = 0; g < G; g++) {
                // level g: entries [0,span) already hold the forms of the first g inputs.
                for (int i = tid; i < span; i += nthr) {
                    #pragma unroll
                    for (int p = 0; p < NP; p++) {
                        unsigned base = tab[i * NP + p];
                        tab[(span + i) * NP + p] = base + v[g][p];
                        tab[(2 * span + i) * NP + p] = base - v[g][p];
                    }
                }
                span *= 3;
                __syncthreads();
            }
            guard += tab[(tid % E) * NP];
        }
    }
    if (guard == 0xdeadbeefu) sink[tid] = guard;
}

// ------------------------------------------------------------------------------------------
// WMMA reference: the deployed arithmetic. One HALO block peel per 32 rows, then int8 WMMA over
// every token group of 16. This is the thing the map has to beat at 32-256 tokens.

typedef int v4i __attribute__((ext_vector_type(4)));
typedef int v8i __attribute__((ext_vector_type(8)));
__device__ __forceinline__ unsigned peel(unsigned & p) { unsigned m = p * 3u; p = m & 0x00ff00ffu; return ((m >> 8) & 0x00ff00ffu); }
__device__ __forceinline__ unsigned peel_last(unsigned & p) { unsigned m = p * 3u; return ((m >> 8) & 0x00ff00ffu); }
__device__ __forceinline__ int swap16(int v) { return __builtin_amdgcn_permlanex16(v, v, 0x76543210u, 0xfedcba98u, false, false); }

template <int TOKG, int WAVES>
__global__ __launch_bounds__(WAVES * 32) void k_wmma(const uint8_t * __restrict__ w,
                                                     const int8_t * __restrict__ xq,
                                                     const float * __restrict__ xs,
                                                     float * __restrict__ out, int tiles_per_wg) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile0 = blockIdx.x * tiles_per_wg + wave;
    const int tstride = WAVES;
    float y1[TOKG][8], y2[TOKG][8];
    #pragma unroll
    for (int g = 0; g < TOKG; g++)
        #pragma unroll
        for (int r = 0; r < 8; r++) { y1[g][r] = 0.0f; y2[g][r] = 0.0f; }

    #pragma unroll 1
    for (int ti = 0; ti < tiles_per_wg; ti += tstride) {
        const int tile = tile0 + ti;
        const uint8_t * run = w + (size_t) tile * NB * 896;
        #pragma unroll 1
        for (int b = 0; b < NB; b++) {
            const uint8_t * bp = run + (size_t) b * 896;
            uint4 qa = *(const uint4 *) (bp + lane * 16);
            uint2 qb = *(const uint2 *) (bp + 512 + lane * 8);
            unsigned tail = *(const unsigned *) (bp + 768 + lane * 4);
            unsigned tr[32];
            const unsigned dw[6] = { qa.x, qa.y, qa.z, qa.w, qb.x, qb.y };
            #pragma unroll
            for (int d = 0; d < 6; d++) {
                unsigned P0 = dw[d] & 0x00ff00ffu, P1 = (dw[d] >> 8) & 0x00ff00ffu;
                unsigned t0 = peel(P0), t1 = peel(P0), t2 = peel(P0), t3 = peel(P0), t4 = peel_last(P0);
                unsigned u0 = peel(P1), u1 = peel(P1), u2 = peel(P1), u3 = peel(P1), u4 = peel_last(P1);
                tr[4 * d] = t0 | (t1 << 8); tr[4 * d + 1] = t2 | (t3 << 8);
                tr[4 * d + 2] = u0 | (u1 << 8); tr[4 * d + 3] = u2 | (u3 << 8);
                tr[24 + d] = t4 | (u4 << 8);
            }
            unsigned P = (tail & 0xffu) | ((tail << 8) & 0xff0000u);
            unsigned h0 = peel(P), h1 = peel(P), h2 = peel(P), h3 = peel_last(P);
            tr[30] = h0 | (h1 << 8); tr[31] = h2 | (h3 << 8);
            const float wscale = __half2float(__ushort_as_half((unsigned short) (tail >> 16)));
            // Every token group reuses this one decode; that is why decode stops mattering as
            // the batch grows, and why the map's "no weight expansion" edge is a small-batch edge.
            #pragma unroll 1
            for (int g = 0; g < TOKG; g++) {
                const int8_t * xb = xq + ((size_t) g * 16 * NB + b) * 128;
                v8i C1 = {0,0,0,0,0,0,0,0}, C2 = {0,0,0,0,0,0,0,0};
                #pragma unroll
                for (int kb = 0; kb < 8; kb++) {
                    const v4i A = { (int) tr[4*kb], (int) tr[4*kb+1], (int) tr[4*kb+2], (int) tr[4*kb+3] };
                    const v4i As = { swap16(A.x), swap16(A.y), swap16(A.z), swap16(A.w) };
                    const int4 bx = *(const int4 *) (xb + kb * 16);
                    const v4i B = { bx.x, bx.y, bx.z, bx.w };
                    C1 = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, A, true, B, C1, false);
                    C2 = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, As, true, B, C2, false);
                }
                const float xsb = wscale * xs[(lane & 15) * NB + b];
                #pragma unroll
                for (int r = 0; r < 8; r++) {
                    y1[g][r] = fmaf((float) C1[r], xsb, y1[g][r]);
                    y2[g][r] = fmaf((float) C2[r], xsb, y2[g][r]);
                }
            }
        }
    }
    float s = 0.0f;
    #pragma unroll
    for (int g = 0; g < TOKG; g++)
        #pragma unroll
        for (int r = 0; r < 8; r++) s += y1[g][r] + y2[g][r];
    out[blockIdx.x * (WAVES * 32) + threadIdx.x] = s;
}

// ------------------------------------------------------------------------------------------

struct Sample { double ms; };

double median(std::vector<double> v) {
    if (v.empty()) return 0.0;
    std::sort(v.begin(), v.end());
    return v[v.size() / 2];
}

int g_cu = 40;
double g_clk_ghz = 2.9;

struct Row {
    std::string kind; int G, tok, rstep, waves, swizzle; bool loads;
    double ms_med, ms_min, mac_per_clk_cu, lds_kb; int vgpr; double occupancy_waves;
    double macs, bytes;
    std::vector<double> samples;
};
std::vector<Row> g_rows;

template <typename F>
void timeit(F && f, int iters, int warmup, std::vector<double> & out) {
    hipEvent_t a, b; HC(hipEventCreate(&a)); HC(hipEventCreate(&b));
    for (int i = 0; i < warmup; i++) f();
    HC(hipDeviceSynchronize());
    for (int i = 0; i < iters; i++) {
        HC(hipEventRecord(a));
        f();
        HC(hipEventRecord(b));
        HC(hipEventSynchronize(b));
        float ms = 0; HC(hipEventElapsedTime(&ms, a, b));
        out.push_back(ms);
    }
    HC(hipEventDestroy(a)); HC(hipEventDestroy(b));
}

void attrs(const void * fn, double & lds_kb, int & vgpr) {
    hipFuncAttributes at{};
    if (hipFuncGetAttributes(&at, fn) == hipSuccess) {
        lds_kb = at.sharedSizeBytes / 1024.0;
        vgpr = at.numRegs;
    } else { lds_kb = 0; vgpr = 0; }
}

uint8_t * d_widx = nullptr; int8_t * d_xq = nullptr; float * d_xs = nullptr;
float * d_out = nullptr; unsigned * d_sink = nullptr; uint8_t * d_w = nullptr;

template <int G, int NP, int RSTEP, int WAVES, int SLOT_PASS, int SWIZZLE, bool LOADW>
void run_consume(int iters, int warmup) {
    constexpr int SLOTS = groups_per_block(G);
    const int rows_per_wg = WAVES * 32 * RSTEP;
    const int blocks = GU_ROWS / rows_per_wg;
    if (blocks < 1) return;
    auto launch = [&] {
        hipLaunchKernelGGL((k_consume<G, NP, RSTEP, WAVES, SLOT_PASS, SWIZZLE, LOADW>),
                           dim3(blocks), dim3(WAVES * 32), 0, 0, d_widx, d_xs, d_out, rows_per_wg);
    };
    std::vector<double> s;
    timeit(launch, iters, warmup, s);
    HC(hipGetLastError());
    Row r;
    r.kind = "consume"; r.G = G; r.tok = 2 * NP; r.rstep = RSTEP; r.waves = WAVES;
    r.swizzle = SWIZZLE; r.loads = LOADW;
    r.ms_med = median(s); r.ms_min = *std::min_element(s.begin(), s.end());
    // Useful MACs the consumed adds stand for: rows * K * tokens, with the padded tail of the
    // last group in each block counted as real work the map still pays for.
    r.macs = (double) (blocks * rows_per_wg) * (double) (SLOTS * G) * (double) (2 * NP) * (double) NB;
    r.mac_per_clk_cu = r.macs / (r.ms_med * 1e-3) / (g_clk_ghz * 1e9) / g_cu;
    r.bytes = LOADW ? (double) (blocks * rows_per_wg) * (double) SLOTS * (double) NB : 0.0;
    attrs((const void *) k_consume<G, NP, RSTEP, WAVES, SLOT_PASS, SWIZZLE, LOADW>, r.lds_kb, r.vgpr);
    r.occupancy_waves = 0;
    r.samples = s;
    g_rows.push_back(r);
    printf("  G=%d tok=%3d rows/lane=%d slots/pass=%2d %-8s %-6s %7.3f ms  %7.1f MAC/clk/CU  %6.1f GB/s  lds=%5.1fKB vgpr=%3d\n",
           G, 2 * NP, RSTEP, SLOT_PASS,
           SWIZZLE == 0 ? "plain" : (SWIZZLE == 1 ? "padded" : (SWIZZLE == 2 ? "xor-lane" : "pad+xor")),
           LOADW ? "+wload" : "noload",
           r.ms_med, r.mac_per_clk_cu, r.bytes / (r.ms_med * 1e-3) / 1e9, r.lds_kb, r.vgpr);
}

template <int G, int NP, int WAVES>
void run_build(int iters, int warmup) {
    constexpr int SLOTS = groups_per_block(G);
    constexpr int E = pow3(G);
    const int blocks = g_cu;
    const int reps = 64;
    auto launch = [&] {
        hipLaunchKernelGGL((k_build<G, NP, WAVES>), dim3(blocks), dim3(WAVES * 32), 0, 0, d_xq, d_sink, reps);
    };
    std::vector<double> s;
    timeit(launch, iters, warmup, s);
    HC(hipGetLastError());
    Row r;
    r.kind = "build"; r.G = G; r.tok = 2 * NP; r.rstep = 0; r.waves = WAVES; r.swizzle = 0; r.loads = false; r.bytes = 0;
    r.ms_med = median(s); r.ms_min = *std::min_element(s.begin(), s.end());
    // Report the build as the number of rows a workgroup must consume before the build is 10%
    // overhead: that is the quantity that decides whether a group size is usable at all.
    r.macs = 0;
    attrs((const void *) k_build<G, NP, WAVES>, r.lds_kb, r.vgpr);
    // per-block-per-slot-table build time, in the same units as one consume add.
    double per_table_ms = r.ms_med / ((double) blocks * reps * SLOTS) * blocks;
    r.mac_per_clk_cu = per_table_ms * 1e-3 * g_clk_ghz * 1e9; // clocks per table build per CU
    r.samples = s;
    g_rows.push_back(r);
    printf("  build   G=%d tok=%2d entries=%5d waves=%d  %8.3f ms  %9.0f clk/table/CU  lds=%5.1fKB vgpr=%d\n",
           G, 2 * NP, E, WAVES, r.ms_med, r.mac_per_clk_cu, r.lds_kb, r.vgpr);
}

template <int TOKG, int WAVES>
void run_wmma(int iters, int warmup) {
    const int tiles = GU_ROWS / 32;
    const int blocks = g_cu * 2;
    const int tiles_per_wg = tiles / blocks;
    auto launch = [&] {
        hipLaunchKernelGGL((k_wmma<TOKG, WAVES>), dim3(blocks), dim3(WAVES * 32), 0, 0,
                           d_w, d_xq, d_xs, d_out, tiles_per_wg);
    };
    std::vector<double> s;
    timeit(launch, iters, warmup, s);
    HC(hipGetLastError());
    Row r;
    r.kind = "wmma"; r.G = 0; r.tok = TOKG * 16; r.rstep = 0; r.waves = WAVES; r.swizzle = 0; r.loads = true;
    r.ms_med = median(s); r.ms_min = *std::min_element(s.begin(), s.end());
    const double done_rows = (double) (blocks * WAVES * (tiles_per_wg / WAVES) * 32);
    r.macs = done_rows * (double) K * (double) (TOKG * 16);
    r.mac_per_clk_cu = r.macs / (r.ms_med * 1e-3) / (g_clk_ghz * 1e9) / g_cu;
    r.bytes = done_rows / 32.0 * (double) NB * 896.0;
    attrs((const void *) k_wmma<TOKG, WAVES>, r.lds_kb, r.vgpr);
    r.samples = s;
    g_rows.push_back(r);
    printf("  wmma tok=%3d  %7.3f ms  %7.1f MAC/clk/CU  %6.1f GB/s weights  vgpr=%d\n",
           TOKG * 16, r.ms_med, r.mac_per_clk_cu, r.bytes / (r.ms_med * 1e-3) / 1e9, r.vgpr);
}

void write_json(const char * path) {
    FILE * f = fopen(path, "w");
    if (!f) { fprintf(stderr, "cannot write %s\n", path); return; }
    fprintf(f, "{\n  \"device\": \"gfx1151\", \"cu\": %d, \"clock_ghz\": %.3f,\n", g_cu, g_clk_ghz);
    fprintf(f, "  \"geometry\": {\"K\": %d, \"blocks\": %d, \"gate_up_rows\": %d},\n", K, NB, GU_ROWS);
    fprintf(f, "  \"rows\": [\n");
    for (size_t i = 0; i < g_rows.size(); i++) {
        const Row & r = g_rows[i];
        fprintf(f, "    {\"kind\": \"%s\", \"group\": %d, \"tokens\": %d, \"rows_per_lane\": %d, \"waves\": %d, "
                   "\"lds_layout\": \"%s\", \"loads_weights\": %s, \"ms_median\": %.6f, \"ms_min\": %.6f, "
                   "\"metric\": %.4f, \"gbps\": %.3f, \"lds_kb\": %.2f, \"vgpr\": %d, \"samples\": [",
                r.kind.c_str(), r.G, r.tok, r.rstep, r.waves,
                r.swizzle == 0 ? "plain" : (r.swizzle == 1 ? "padded" : (r.swizzle == 2 ? "xor-lane" : "pad+xor")),
                r.loads ? "true" : "false", r.ms_med, r.ms_min, r.mac_per_clk_cu,
                r.bytes > 0 ? r.bytes / (r.ms_med * 1e-3) / 1e9 : 0.0, r.lds_kb, r.vgpr);
        for (size_t j = 0; j < r.samples.size(); j++) fprintf(f, "%s%.6f", j ? ", " : "", r.samples[j]);
        fprintf(f, "]}%s\n", i + 1 < g_rows.size() ? "," : "");
    }
    fprintf(f, "  ]\n}\n");
    fclose(f);
    printf("wrote %s\n", path);
}

} // namespace

int main(int argc, char ** argv) {
    int iters = 30, warmup = 5;
    const char * json = nullptr;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--iters") && i + 1 < argc) iters = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--warmup") && i + 1 < argc) warmup = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--json") && i + 1 < argc) json = argv[++i];
        else if (!strcmp(argv[i], "--clock") && i + 1 < argc) g_clk_ghz = atof(argv[++i]);
    }
    hipDeviceProp_t prop{};
    HC(hipGetDeviceProperties(&prop, 0));
    // HIP reports gfx1151's 20 work-group processors; rocminfo counts the 40 compute units inside
    // them, and LDS and the matrix units are per work-group processor. Rates are per WGP here.
    g_cu = prop.multiProcessorCount;
    printf("device %s, %d work-group processors, LDS %zu B/workgroup, assumed clock %.2f GHz\n"
           "rates are MAC per clock per work-group processor\n",
           prop.gcnArchName, g_cu, (size_t) prop.sharedMemPerBlock, g_clk_ghz);

    // Weight selector bytes, largest group layout (43 slots covers every G we probe).
    const size_t widx_bytes = (size_t) NB * 43 * GU_ROWS;
    HC(hipMalloc(&d_widx, widx_bytes));
    std::vector<uint8_t> h(1 << 20);
    for (size_t i = 0; i < h.size(); i++) h[i] = (uint8_t) ((i * 1103515245u + 12345u) >> 16);
    for (size_t o = 0; o < widx_bytes; o += h.size())
        HC(hipMemcpy(d_widx + o, h.data(), std::min(h.size(), widx_bytes - o), hipMemcpyHostToDevice));

    const size_t xq_bytes = (size_t) 256 * K;   // 256 tokens of quantised activations
    HC(hipMalloc(&d_xq, xq_bytes));
    for (size_t o = 0; o < xq_bytes; o += h.size())
        HC(hipMemcpy((uint8_t *) d_xq + o, h.data(), std::min(h.size(), xq_bytes - o), hipMemcpyHostToDevice));
    HC(hipMalloc(&d_xs, sizeof(float) * 256 * NB));
    std::vector<float> xs(256 * NB, 0.0009f);
    HC(hipMemcpy(d_xs, xs.data(), xs.size() * sizeof(float), hipMemcpyHostToDevice));
    HC(hipMalloc(&d_out, sizeof(float) * (size_t) GU_ROWS * 4));
    HC(hipMalloc(&d_sink, 4096));
    const size_t wbytes = (size_t) (GU_ROWS / 32) * NB * 896;
    HC(hipMalloc(&d_w, wbytes));
    for (size_t o = 0; o < wbytes; o += h.size())
        HC(hipMemcpy(d_w + o, h.data(), std::min(h.size(), wbytes - o), hipMemcpyHostToDevice));

    printf("\n-- native int8 WMMA on HALO ternary blocks, one decode per row-block --\n");
    run_wmma<2, 8>(iters, warmup);    // 32 tokens
    run_wmma<4, 8>(iters, warmup);    // 64 tokens
    run_wmma<8, 8>(iters, warmup);    // 128 tokens
    run_wmma<16, 8>(iters, warmup);   // 256 tokens

    printf("\n-- LDS layout: what the gather costs when the indices are divergent (group 5, 32 tokens) --\n");
    run_consume<5, 16, 1, 8, 3, 0, false>(iters, warmup);
    run_consume<5, 16, 1, 8, 3, 1, false>(iters, warmup);
    run_consume<5, 16, 1, 8, 3, 2, false>(iters, warmup);
    run_consume<5, 16, 1, 8, 3, 3, false>(iters, warmup);

    printf("\n-- consume ceiling, no weight traffic. The roof the map can never pass is 64*G --\n");
    run_consume<3, 4, 4, 8, 43, 3, false>(iters, warmup);
    run_consume<3, 8, 2, 8, 43, 3, false>(iters, warmup);
    run_consume<3, 16, 1, 8, 22, 3, false>(iters, warmup);
    run_consume<3, 32, 1, 8, 11, 3, false>(iters, warmup);
    run_consume<4, 4, 4, 8, 32, 3, false>(iters, warmup);
    run_consume<4, 8, 2, 8, 16, 3, false>(iters, warmup);
    run_consume<4, 16, 1, 8, 8, 3, false>(iters, warmup);
    run_consume<4, 32, 1, 8, 4, 3, false>(iters, warmup);
    run_consume<5, 4, 8, 8, 12, 3, false>(iters, warmup);
    run_consume<5, 4, 4, 8, 12, 3, false>(iters, warmup);
    run_consume<5, 8, 2, 8, 6, 3, false>(iters, warmup);
    run_consume<5, 16, 1, 8, 3, 3, false>(iters, warmup);
    run_consume<5, 32, 1, 8, 1, 3, false>(iters, warmup);

    printf("\n-- same, with a byte-per-slot selector load: the cost of not using HALO's own layout --\n");
    run_consume<3, 4, 4, 8, 43, 3, true>(iters, warmup);
    run_consume<3, 32, 1, 8, 11, 3, true>(iters, warmup);
    run_consume<5, 4, 8, 8, 12, 3, true>(iters, warmup);
    run_consume<5, 16, 1, 8, 3, 3, true>(iters, warmup);
    run_consume<5, 32, 1, 8, 1, 3, true>(iters, warmup);

    printf("\n-- table build cost per group table --\n");
    run_build<3, 4, 8>(iters, warmup);
    run_build<4, 4, 8>(iters, warmup);
    run_build<5, 4, 8>(iters, warmup);
    run_build<5, 16, 8>(iters, warmup);

    if (json) write_json(json);
    return 0;
}
