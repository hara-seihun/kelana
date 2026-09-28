// The group-5 candidate that consumes HALO's stored bytes directly, end to end.
//
// A HALO block already packs five trits per qs byte and four per qh byte, and pack5 is injective
// (check.cpp proves it), so the stored byte *is* a table index. The consumer therefore never
// extracts a bit field, never expands a weight, and reads exactly the deployed 26 bytes per row
// per block through the deployed vector load. That removes every cost the 43-group map paid for
// its own five-bit selector format.
//
// What remains is the exchange this experiment exists to price:
//   - the consumer's cost is one packed add per (row, slot) per token pair, served from LDS;
//   - the producer must build 243 forms per slot per token tile, in the same LDS, and that build
//     is amortised only over the rows one workgroup holds, not over the batch.
//
// Both kernels here run the gate/up geometry over a token tile of 64 and repeat for larger
// batches, so the table map and the WMMA baseline pay the same weight re-reads and are directly
// comparable. Operands are probe data; correctness of the arithmetic is check.cpp's job.

#include <hip/hip_runtime.h>
#include <hip/hip_fp16.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <algorithm>

#define HC(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) { \
    fprintf(stderr, "%s:%d %s -> %s\n", __FILE__, __LINE__, #x, hipGetErrorString(e_)); exit(1); } } while (0)

namespace {

constexpr int K = 5120;
constexpr int NB = K / 128;
constexpr int GU_ROWS = 34816;
constexpr int SLOTS = 26;        // 24 qs bytes of five trits, 2 qh bytes of four
constexpr int NP = 32;           // 32 planes of two tokens: a 64-token tile per pass
constexpr int ENTRIES = 256;     // byte-indexed, 243 reachable

// ------------------------------------------------------------------------------------------
// One slot table: 256 entries of 32 planes. Entry stride 32 dwords puts every entry on bank 0,
// which is exactly why the consumer rotates its plane index by the lane: at each step the 32
// lanes then touch 32 distinct banks whatever their selector bytes are.

// qbyte[q] is pack5's byte for base-3 value q. It is input-independent, so it is built once per
// kernel and the per-entry work reduces to one add and one store: the index arithmetic that
// dominated the first version is gone entirely.
__device__ __forceinline__ void fill_qbyte(unsigned char * qbyte, int tid, int nthr) {
    for (int q = tid; q < 243; q += nthr) qbyte[q] = (unsigned char) ((q * 256u + 242u) / 243u);
}

template <int WAVES>
__device__ __forceinline__ void build_slot(unsigned * tab, const unsigned char * qbyte,
                                           const unsigned * a, int tid) {
    constexpr int NTHR = WAVES * 32;
    constexpr int SLICES = NTHR / 32;         // threads sharing one plane
    const int plane = tid & 31;
    const int slice = tid >> 5;
    const unsigned a0 = a[0], a1 = a[1], a2 = a[2], a3 = a[3], a4 = a[4];
    // lo[9] covers the two low base-3 digits and is reused by every high triple.
    unsigned lo[9];
    #pragma unroll
    for (int d3 = 0; d3 < 3; d3++) {
        const unsigned u = d3 == 0 ? (0u - a3) : (d3 == 1 ? 0u : a3);
        #pragma unroll
        for (int d4 = 0; d4 < 3; d4++)
            lo[d3 * 3 + d4] = u + (d4 == 0 ? (0u - a4) : (d4 == 1 ? 0u : a4));
    }
    // 27 high triples, strided across the slices so each thread walks its own few.
    for (int qh = slice; qh < 27; qh += SLICES) {
        const int d0 = qh / 9, r = qh - d0 * 9, d1 = r / 3, d2 = r - d1 * 3;
        const unsigned hi = (d0 == 0 ? (0u - a0) : (d0 == 1 ? 0u : a0))
                          + (d1 == 0 ? (0u - a1) : (d1 == 1 ? 0u : a1))
                          + (d2 == 0 ? (0u - a2) : (d2 == 1 ? 0u : a2));
        const int q0 = qh * 9;
        #pragma unroll
        for (int ql = 0; ql < 9; ql++)
            tab[(unsigned) qbyte[q0 + ql] * NP + plane] = hi + lo[ql];
    }
}

// The five block-local input positions a qs byte covers, and the four a qh byte covers, straight
// from HALO's peel order. slot < 24 is qs byte 4d+j; slot 24,25 are the qh bytes.
__device__ __forceinline__ void slot_positions(int slot, int * pos, int & n) {
    if (slot < 24) {
        const int d = slot >> 2, j = slot & 3, w = j & 1, half = j >> 1, p = 2 * d + w;
        pos[0] = 8 * p + 2 * half;
        pos[1] = 8 * p + 2 * half + 1;
        pos[2] = 8 * p + 4 + 2 * half;
        pos[3] = 8 * p + 4 + 2 * half + 1;
        pos[4] = 96 + 4 * d + j;
        n = 5;
    } else {
        const int h = slot - 24;
        pos[0] = 120 + 2 * h; pos[1] = 121 + 2 * h; pos[2] = 124 + 2 * h; pos[3] = 125 + 2 * h;
        pos[4] = -1; n = 4;
    }
}

// The producer emits activations already packed the way the table build consumes them:
// xpack[block][position][plane] holds tokens 2p and 2p+1 of one input position in one dword. It
// is O(K * tokens) work done once per token tile, against O(rows * K * tokens) of consumption,
// and it is what makes the build's reads coalesce across lanes.
__global__ void k_pack_activations(const int8_t * __restrict__ xq, unsigned * __restrict__ xpack) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    const int plane = i & 31, pos = (i >> 5) & 127, b = i >> 12;
    if (b >= NB) return;
    const int col = b * 128 + pos;
    const int lo = xq[(size_t) (2 * plane) * K + col];
    const int hi = xq[(size_t) (2 * plane + 1) * K + col];
    xpack[i] = (unsigned) (lo & 0xffff) | ((unsigned) hi << 16);
}

// REBUILD=false keeps a stale table instead of rebuilding it per (tile, block, slot). The result
// is arithmetic nonsense and is never reported as a candidate; it exists only to split the fused
// cost into the part the consumer pays and the part the producer pays.
template <int WAVES, bool REBUILD = true>
__global__ __launch_bounds__(WAVES * 32) void k_halo5(const uint8_t * __restrict__ w,
                                                      const unsigned * __restrict__ xpack,
                                                      const float * __restrict__ xs,
                                                      float * __restrict__ out,
                                                      int tiles_per_wg, int chunks) {
    __shared__ unsigned tab[ENTRIES * NP];
    __shared__ unsigned char qbyte[243];
    const int tid = threadIdx.x, lane = tid & 31, wave = tid >> 5;
    fill_qbyte(qbyte, tid, WAVES * 32);
    const int plane = lane;                    // the lane's plane rotation
    (void) wave;

    float y[2 * NP];
    #pragma unroll
    for (int t = 0; t < 2 * NP; t++) y[t] = 0.0f;

    #pragma unroll 1
    for (int chunk = 0; chunk < chunks; chunk++) {
        const unsigned * xc = xpack;   // one packed tile per chunk, rebuilt by the producer
        #pragma unroll 1
        for (int ti = 0; ti < tiles_per_wg; ti++) {
            // Every wave owns a different 32-row tile at the same block, so one built table
            // serves all WAVES*32 rows the workgroup holds. That row count is the only thing the
            // build amortises over, and registers cap it: it does not grow with the batch.
            const int tile = blockIdx.x * tiles_per_wg * WAVES + ti * WAVES + wave;
            const uint8_t * run = w + (size_t) tile * NB * 896;
            #pragma unroll 1
            for (int b = 0; b < NB; b++) {
                const uint8_t * bp = run + (size_t) b * 896;
                // The deployed load: 16 + 8 + 4 bytes per lane, coalesced across the tile.
                const uint4 qa = *(const uint4 *) (bp + lane * 16);
                const uint2 qb = *(const uint2 *) (bp + 512 + lane * 8);
                const unsigned tail = *(const unsigned *) (bp + 768 + lane * 4);
                const unsigned qs[6] = { qa.x, qa.y, qa.z, qa.w, qb.x, qb.y };
                const float wscale = __half2float(__ushort_as_half((unsigned short) (tail >> 16)));

                unsigned acc[NP];
                #pragma unroll
                for (int p = 0; p < NP; p++) acc[p] = 0u;

                #pragma unroll 1
                for (int slot = 0; slot < SLOTS; slot++) {
                    int pos[5], n;
                    slot_positions(slot, pos, n);
                    // The producer's five packed activation pairs for this plane.
                    unsigned a[5];
                    #pragma unroll
                    for (int i = 0; i < 5; i++)
                        a[i] = (i >= 4 && n == 4) ? 0u
                             : xc[((size_t) b * 128 + pos[i]) * 32 + plane];
                    if (REBUILD || (ti == 0 && b == 0)) {
                        __syncthreads();
                        build_slot<WAVES>(tab, qbyte, a, tid);
                        __syncthreads();
                    }
                    // The stored byte is the index. No field extraction, no weight expansion.
                    const unsigned idx = slot < 24 ? ((qs[slot >> 2] >> (8 * (slot & 3))) & 255u)
                                                   : ((tail >> (8 * (slot - 24))) & 255u);
                    const unsigned * e = &tab[idx * NP];
                    #pragma unroll
                    for (int p = 0; p < NP; p++) acc[p] += e[p ^ plane];
                }
                #pragma unroll
                for (int p = 0; p < NP; p++) {
                    const int tp = p ^ plane;
                    const int bias = SLOTS * 640;
                    const int lo = int(acc[p] & 65535) - bias;
                    const int hi = int(acc[p] >> 16) - bias;
                    y[2 * p] = fmaf((float) lo, wscale * xs[(2 * tp) * NB + b], y[2 * p]);
                    y[2 * p + 1] = fmaf((float) hi, wscale * xs[(2 * tp + 1) * NB + b], y[2 * p + 1]);
                }
            }
        }
    }
    float s = 0.0f;
    #pragma unroll
    for (int t = 0; t < 2 * NP; t++) s += y[t];
    out[blockIdx.x * (WAVES * 32) + tid] = s;
}

// ------------------------------------------------------------------------------------------
// The baseline at the same token tiling: 64 tokens per pass, weights re-read per pass, one HALO
// peel per row-block feeding four 16-token WMMA groups.

typedef int v4i __attribute__((ext_vector_type(4)));
typedef int v8i __attribute__((ext_vector_type(8)));
__device__ __forceinline__ unsigned peel(unsigned & p) { unsigned m = p * 3u; p = m & 0x00ff00ffu; return ((m >> 8) & 0x00ff00ffu); }
__device__ __forceinline__ unsigned peel_last(unsigned & p) { unsigned m = p * 3u; return ((m >> 8) & 0x00ff00ffu); }
__device__ __forceinline__ int swap16(int v) { return __builtin_amdgcn_permlanex16(v, v, 0x76543210u, 0xfedcba98u, false, false); }

template <int WAVES>
__global__ __launch_bounds__(WAVES * 32) void k_wmma64(const uint8_t * __restrict__ w,
                                                       const int8_t * __restrict__ xq,
                                                       const float * __restrict__ xs,
                                                       float * __restrict__ out,
                                                       int tiles_per_wg, int chunks) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    float y1[4][8], y2[4][8];
    #pragma unroll
    for (int g = 0; g < 4; g++)
        #pragma unroll
        for (int r = 0; r < 8; r++) { y1[g][r] = 0.0f; y2[g][r] = 0.0f; }

    #pragma unroll 1
    for (int chunk = 0; chunk < chunks; chunk++) {
        const int8_t * xc = xq + (size_t) chunk * 64 * K;
        #pragma unroll 1
        for (int ti = 0; ti < tiles_per_wg; ti++) {
            const int tile = blockIdx.x * tiles_per_wg * WAVES + ti * WAVES + wave;
            const uint8_t * run = w + (size_t) tile * NB * 896;
            #pragma unroll 1
            for (int b = 0; b < NB; b++) {
                const uint8_t * bp = run + (size_t) b * 896;
                const uint4 qa = *(const uint4 *) (bp + lane * 16);
                const uint2 qb = *(const uint2 *) (bp + 512 + lane * 8);
                const unsigned tail = *(const unsigned *) (bp + 768 + lane * 4);
                unsigned tr[32];
                const unsigned dw[6] = { qa.x, qa.y, qa.z, qa.w, qb.x, qb.y };
                #pragma unroll
                for (int d = 0; d < 6; d++) {
                    unsigned P0 = dw[d] & 0x00ff00ffu, P1 = (dw[d] >> 8) & 0x00ff00ffu;
                    unsigned t0 = peel(P0), t1 = peel(P0), t2 = peel(P0), t3 = peel(P0), t4 = peel_last(P0);
                    unsigned u0 = peel(P1), u1 = peel(P1), u2 = peel(P1), u3 = peel(P1), u4 = peel_last(P1);
                    tr[4*d] = t0 | (t1 << 8); tr[4*d+1] = t2 | (t3 << 8);
                    tr[4*d+2] = u0 | (u1 << 8); tr[4*d+3] = u2 | (u3 << 8);
                    tr[24+d] = t4 | (u4 << 8);
                }
                unsigned P = (tail & 0xffu) | ((tail << 8) & 0xff0000u);
                unsigned h0 = peel(P), h1 = peel(P), h2 = peel(P), h3 = peel_last(P);
                tr[30] = h0 | (h1 << 8); tr[31] = h2 | (h3 << 8);
                const float wscale = __half2float(__ushort_as_half((unsigned short) (tail >> 16)));
                #pragma unroll
                for (int g = 0; g < 4; g++) {
                    const int8_t * xb = xc + ((size_t) g * 16 * NB + b) * 128;
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
    }
    float s = 0.0f;
    #pragma unroll
    for (int g = 0; g < 4; g++)
        #pragma unroll
        for (int r = 0; r < 8; r++) s += y1[g][r] + y2[g][r];
    out[blockIdx.x * (WAVES * 32) + threadIdx.x] = s;
}

// ------------------------------------------------------------------------------------------

double median(std::vector<double> v) { std::sort(v.begin(), v.end()); return v[v.size() / 2]; }
int g_wgp = 20; double g_clk = 2.9;

struct Res { const char * name; int tokens; double ms_med, ms_min, rate, gbps; int vgpr; double lds_kb; std::vector<double> s; };
std::vector<Res> g_res;

template <typename F> std::vector<double> timeit(F && f, int iters, int warmup) {
    hipEvent_t a, b; HC(hipEventCreate(&a)); HC(hipEventCreate(&b));
    std::vector<double> out;
    for (int i = 0; i < warmup; i++) f();
    HC(hipDeviceSynchronize());
    for (int i = 0; i < iters; i++) {
        HC(hipEventRecord(a)); f(); HC(hipEventRecord(b)); HC(hipEventSynchronize(b));
        float ms = 0; HC(hipEventElapsedTime(&ms, a, b)); out.push_back(ms);
    }
    HC(hipEventDestroy(a)); HC(hipEventDestroy(b));
    return out;
}

uint8_t * d_w; int8_t * d_xq; unsigned * d_xpack; float * d_xs, * d_out;

} // namespace

int main(int argc, char ** argv) {
    int iters = 15, warmup = 3;
    const char * json = nullptr;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--iters") && i + 1 < argc) iters = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--warmup") && i + 1 < argc) warmup = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--json") && i + 1 < argc) json = argv[++i];
    }
    hipDeviceProp_t prop{}; HC(hipGetDeviceProperties(&prop, 0));
    g_wgp = prop.multiProcessorCount;
    printf("device %s, %d work-group processors; rates are MAC/clk/WGP at an assumed %.2f GHz\n",
           prop.gcnArchName, g_wgp, g_clk);

    std::vector<uint8_t> h(1 << 20);
    for (size_t i = 0; i < h.size(); i++) h[i] = (uint8_t) ((i * 1103515245u + 12345u) >> 16);
    const size_t wbytes = (size_t) (GU_ROWS / 32) * NB * 896;
    HC(hipMalloc(&d_w, wbytes));
    for (size_t o = 0; o < wbytes; o += h.size())
        HC(hipMemcpy(d_w + o, h.data(), std::min(h.size(), wbytes - o), hipMemcpyHostToDevice));
    const size_t xqb = (size_t) 256 * K;
    HC(hipMalloc(&d_xq, xqb));
    for (size_t o = 0; o < xqb; o += h.size())
        HC(hipMemcpy((uint8_t *) d_xq + o, h.data(), std::min(h.size(), xqb - o), hipMemcpyHostToDevice));
    std::vector<float> xs(256 * NB, 0.0009f);
    HC(hipMalloc(&d_xs, xs.size() * 4));
    HC(hipMemcpy(d_xs, xs.data(), xs.size() * 4, hipMemcpyHostToDevice));
    HC(hipMalloc(&d_out, (size_t) GU_ROWS * 4));
    HC(hipMalloc(&d_xpack, (size_t) NB * 128 * 32 * 4));

    constexpr int WAVES = 8;
    const int wgs = 34;                              // 34 workgroups of 8 waves
    const int tiles = GU_ROWS / 32;
    const int tiles_per_wave = tiles / (wgs * WAVES);

    for (int tokens : {64, 128, 256}) {
        const int chunks = tokens / 64;
        {   // consumer alone, inside the real kernel: the same loads, indices and packed adds with
            // the table build removed. Not a candidate, a cost split.
            auto f = [&] { hipLaunchKernelGGL((k_halo5<WAVES, false>), dim3(wgs), dim3(WAVES * 32), 0, 0,
                                              d_w, d_xpack, d_xs, d_out, tiles_per_wave, chunks); };
            auto s = timeit(f, iters, warmup); HC(hipGetLastError());
            hipFuncAttributes at{}; (void) hipFuncGetAttributes(&at, (const void *) k_halo5<WAVES, false>);
            const double macs = (double) (wgs * WAVES * tiles_per_wave * 32) * K * tokens;
            Res r{"consumer-only-no-build", tokens, median(s), *std::min_element(s.begin(), s.end()), 0, 0, at.numRegs, at.sharedSizeBytes / 1024.0, s};
            r.rate = macs / (r.ms_med * 1e-3) / (g_clk * 1e9) / g_wgp;
            g_res.push_back(r);
            printf("  consumer-only      tok=%3d  %8.3f ms  %7.1f MAC/clk/WGP  vgpr=%d lds=%.1fKB\n",
                   tokens, r.ms_med, r.rate, r.vgpr, r.lds_kb);
        }
        {   // table map: one wave owns one 32-row tile, the workgroup shares one slot table
            auto f = [&] {
                // The producer runs once per token tile, inside the measured interval.
                for (int c = 0; c < chunks; c++)
                    hipLaunchKernelGGL(k_pack_activations, dim3(NB * 128 * 32 / 256), dim3(256), 0, 0,
                                       d_xq + (size_t) c * 64 * K, d_xpack);
                hipLaunchKernelGGL((k_halo5<WAVES>), dim3(wgs), dim3(WAVES * 32), 0, 0,
                                   d_w, d_xpack, d_xs, d_out, tiles_per_wave, chunks);
            };
            auto s = timeit(f, iters, warmup); HC(hipGetLastError());
            hipFuncAttributes at{}; hipFuncGetAttributes(&at, (const void *) k_halo5<WAVES>);
            const double macs = (double) (wgs * WAVES * tiles_per_wave * 32) * K * tokens;
            const double bytes = (double) (wgs * WAVES * tiles_per_wave) * NB * 896 * chunks;
            Res r{"table-group5-halo", tokens, median(s), *std::min_element(s.begin(), s.end()), 0, 0, at.numRegs, at.sharedSizeBytes / 1024.0, s};
            r.rate = macs / (r.ms_med * 1e-3) / (g_clk * 1e9) / g_wgp;
            r.gbps = bytes / (r.ms_med * 1e-3) / 1e9;
            g_res.push_back(r);
            printf("  table-group5-halo  tok=%3d  %8.3f ms  %7.1f MAC/clk/WGP  %6.1f GB/s  vgpr=%d lds=%.1fKB\n",
                   tokens, r.ms_med, r.rate, r.gbps, r.vgpr, r.lds_kb);
        }
        {
            auto f = [&] { hipLaunchKernelGGL((k_wmma64<WAVES>), dim3(wgs), dim3(WAVES * 32), 0, 0,
                                              d_w, d_xq, d_xs, d_out, tiles_per_wave, chunks); };
            auto s = timeit(f, iters, warmup); HC(hipGetLastError());
            hipFuncAttributes at{}; hipFuncGetAttributes(&at, (const void *) k_wmma64<WAVES>);
            const double macs = (double) (wgs * WAVES * tiles_per_wave * 32) * K * tokens;
            const double bytes = (double) (wgs * WAVES * tiles_per_wave) * NB * 896 * chunks;
            Res r{"wmma-int8", tokens, median(s), *std::min_element(s.begin(), s.end()), 0, 0, at.numRegs, at.sharedSizeBytes / 1024.0, s};
            r.rate = macs / (r.ms_med * 1e-3) / (g_clk * 1e9) / g_wgp;
            r.gbps = bytes / (r.ms_med * 1e-3) / 1e9;
            g_res.push_back(r);
            printf("  wmma-int8          tok=%3d  %8.3f ms  %7.1f MAC/clk/WGP  %6.1f GB/s  vgpr=%d lds=%.1fKB\n",
                   tokens, r.ms_med, r.rate, r.gbps, r.vgpr, r.lds_kb);
        }
    }

    if (json) {
        FILE * f = fopen(json, "w");
        fprintf(f, "{\n  \"device\": \"gfx1151\", \"wgp\": %d, \"clock_ghz\": %.2f,\n  \"rows\": [\n", g_wgp, g_clk);
        for (size_t i = 0; i < g_res.size(); i++) {
            const Res & r = g_res[i];
            fprintf(f, "    {\"candidate\": \"%s\", \"tokens\": %d, \"ms_median\": %.6f, \"ms_min\": %.6f, "
                       "\"mac_per_clk_wgp\": %.3f, \"weight_gbps\": %.3f, \"vgpr\": %d, \"lds_kb\": %.2f, \"samples\": [",
                    r.name, r.tokens, r.ms_med, r.ms_min, r.rate, r.gbps, r.vgpr, r.lds_kb);
            for (size_t j = 0; j < r.s.size(); j++) fprintf(f, "%s%.6f", j ? ", " : "", r.s[j]);
            fprintf(f, "]}%s\n", i + 1 < g_res.size() ? "," : "");
        }
        fprintf(f, "  ]\n}\n");
        fclose(f);
        printf("wrote %s\n", json);
    }
    return 0;
}
