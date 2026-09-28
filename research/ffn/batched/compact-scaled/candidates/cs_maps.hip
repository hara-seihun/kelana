// Whole-FFN candidates: compact two-bit ternary weights, scaled FP16 operands in registers, one
// FP32 WMMA accumulator across the entire K.
//
// Residual in, residual out, four kernels on the caller's stream, the same shape the arithmetic
// worker's maps use: producer, gate/up with fused SiLU, hidden producer, down onto the residual.
// What differs is the projection's inner arithmetic.
//
// The integer maps accumulate int32 over one 128-block, then drain that accumulator to FP32,
// multiply by the weight's block scale and the token's block scale, and add into a running FP32
// sum. That epilogue runs 40 times per row for the gate/up projection and 136 times for the down
// projection, and it costs a shuffle of the scale row, a global load of the token scale and two
// FMAs per accumulator element, per block.
//
// Here the block scale is folded into the A operand while it is being built: a ternary weight times
// an FP16 scale is exactly the scale's bit pattern, that pattern with bit 15 flipped, or zero, so
// the fold is byte selection and not arithmetic (scaled.hpp, Kelana/ScaledTrit.lean). The token
// scale is folded into the activation by the producer. The WMMA then accumulates FP32 over all
// 5120 or 17408 elements with no epilogue at all: the accumulator holds the finished projection.
//
// This is not the expanded-FP16 baseline. `native_fp16` in bench/candidates stores every weight as
// a 16-bit premultiplied value: 534 MB against this directory's 71.0 MB, 7.5x the weight image and
// its bandwidth. Here the stored image is the same 512 bytes per (16 rows x 128 K) the integer maps
// read, and the 16-bit form exists only in registers.
//
//   cs-scaled-f16-a8      activations are the deployed eight-bit code times its block scale,
//                         rounded to FP16. Near-A8 input semantics, one extra rounding.
//   cs-scaled-f16-a8-t4   the same map with the four-token-tile cap the integer maps run at.
//                         Dropping the integer accumulators is what lets the headline candidate
//                         carry eight tiles without spilling, and this is the ablation that shows
//                         what the wider tile is worth.
//   cs-scaled-f16-direct  activations are the transformed float rounded straight to FP16, with no
//                         eight-bit grid. A distinct quality rung, and a cheaper producer.
//
// Weights are never approximated: the deployed trits with their deployed FP16 block scales. The
// approximation is the activation rounding, and the reassociation is stated above: one FP32 sum
// over the whole K instead of per-128 integer sums combined in FP32. FP16 WMMA products of FP16
// operands are exact in FP32; the order and internal rounding of the hardware's accumulation are
// not documented, so the error is measured against a control rather than argued from a bound.
#include "../../api.hpp"
#include "../scaled.hpp"
#include "halo_format.h"
#include <hip/hip_runtime.h>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <vector>

using namespace kelana_scaled;

namespace {

constexpr int NT = 256;            // producer threads per 1024-element chunk
constexpr int NW = 4;              // waves per projection workgroup
constexpr float NORM_EPS = 1e-5f;

void check(hipError_t e, const char *what) {
    if (e != hipSuccess) { std::fprintf(stderr, "compact-scaled: %s: %s\n", what, hipGetErrorString(e)); std::abort(); }
}

__device__ __forceinline__ float silu(float x) { return x / (1.0f + __expf(-x)); }
__device__ __forceinline__ float warp_max(float v) {
    for (int b = 1; b < 32; b <<= 1) v = fmaxf(v, __shfl_xor(v, b, 32));
    return v;
}
__device__ __forceinline__ float block_sum(float v, float *red) {
    for (int b = 1; b < 32; b <<= 1) v += __shfl_xor(v, b, 32);
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    if (lane == 0) red[wave] = v;
    __syncthreads();
    float t = 0;
#pragma unroll
    for (int w = 0; w < NT / 32; ++w) t += red[w];
    return t;
}

// ------------------------------------------------------------------ activation producer

// One workgroup per (row, 1024-chunk). Identical normalisation, folded sign and 1024-point Hadamard
// to the deployed prep_chunk_r; only the output representation differs. A8 keeps the deployed
// eight-bit quantiser and writes q*scale as FP16, so the input semantics stay the deployed ones up
// to one rounding. Otherwise the transformed float is rounded straight to FP16.
//
// The destination is the WMMA B fragment itself: [kslice][token][16], which is what lane l%16
// supplies to the matrix instruction. There is no int8 buffer for a later kernel to re-read.
template <bool NORM, bool HAS_SIGN, bool A8>
__global__ __launch_bounds__(NT) void k_prep(const float *__restrict__ x, const float *__restrict__ kvec,
        _Float16 *__restrict__ Bout, int n, int Npad) {
    __shared__ __attribute__((aligned(16))) float s[1024];
    __shared__ float red[NT / 32];
    const int nchunks = n / 1024, tid = threadIdx.x, lane = tid & 31, wave = tid >> 5;
    const int row = blockIdx.x / nchunks, chunk = blockIdx.x - row * nchunks;
    const int e0 = wave * 128 + lane * 4, base = chunk * 1024 + e0;
    const size_t rb = (size_t) row * n;
    float inv = 1.0f;
    if constexpr (NORM) {
        float ss = 0.0f;
        for (int i = tid * 4; i < n; i += NT * 4) {
            const float4 t = *(const float4 *) (x + rb + i);
            ss = fmaf(t.x, t.x, ss); ss = fmaf(t.y, t.y, ss);
            ss = fmaf(t.z, t.z, ss); ss = fmaf(t.w, t.w, ss);
        }
        ss = block_sum(ss, red);
        inv = rsqrtf(ss / (float) n + NORM_EPS);
    }
    float4 v = *(const float4 *) (x + rb + base);
    if constexpr (HAS_SIGN) {
        const float4 k = *(const float4 *) (kvec + base);
        v.x *= inv * k.x; v.y *= inv * k.y; v.z *= inv * k.z; v.w *= inv * k.w;
    }
    { float p0 = v.x + v.y, p1 = v.x - v.y, p2 = v.z + v.w, p3 = v.z - v.w;
      v.x = p0 + p2; v.y = p1 + p3; v.z = p0 - p2; v.w = p1 - p3; }
#pragma unroll
    for (int bit = 1; bit < 32; bit <<= 1) {
        const bool upper = (lane & bit) != 0;
        const float ox = __shfl_xor(v.x, bit, 32), oy = __shfl_xor(v.y, bit, 32);
        const float oz = __shfl_xor(v.z, bit, 32), ow = __shfl_xor(v.w, bit, 32);
        v.x = upper ? ox - v.x : v.x + ox; v.y = upper ? oy - v.y : v.y + oy;
        v.z = upper ? oz - v.z : v.z + oz; v.w = upper ? ow - v.w : v.w + ow;
    }
    *(float4 *) (s + e0) = v;
    __syncthreads();
    if (tid < 128) {
        float u[8];
#pragma unroll
        for (int m = 0; m < 8; ++m) u[m] = s[tid + 128 * m];
#pragma unroll
        for (int len = 1; len < 8; len <<= 1)
#pragma unroll
            for (int m = 0; m < 8; ++m) if ((m & len) == 0) {
                const float x0 = u[m], x1 = u[m + len]; u[m] = x0 + x1; u[m + len] = x0 - x1;
            }
#pragma unroll
        for (int m = 0; m < 8; ++m) s[tid + 128 * m] = u[m] * 0.03125f;
    }
    __syncthreads();
    v = *(const float4 *) (s + e0);
    float f[4] = {v.x, v.y, v.z, v.w};
    if constexpr (A8) {
        // The deployed quantiser over the 128-element block this warp owns, then back to a real
        // value: amax/127 per (row, block), round to nearest even, clamp, multiply.
        const float amax = warp_max(fmaxf(fmaxf(fabsf(v.x), fabsf(v.y)), fmaxf(fabsf(v.z), fabsf(v.w))));
        const float iscale = amax > 0.0f ? 127.0f / amax : 0.0f, scale = amax * (1.0f / 127.0f);
#pragma unroll
        for (int j = 0; j < 4; ++j)
            f[j] = (float) max(-127, min(127, __float2int_rn(f[j] * iscale))) * scale;
    }
    const int kslice = base >> 4, slot = base & 15;
    _Float16 *dst = Bout + (size_t(kslice) * Npad + row) * 16 + slot;
#pragma unroll
    for (int j = 0; j < 4; ++j) dst[j] = (_Float16) f[j];
}

// ------------------------------------------------------------------ projection

// A wave owns 16 weight rows of each of two matrices and TT token tiles. The A operand is built
// once per (block, slice) and used TT times against both matrices' accumulators.
//
// There is no per-block epilogue: ca and cb are the finished projections when the K loop ends.
// FUSE folds SiLU, the product and the hidden sign into the store; otherwise the two row sets are
// accumulated onto the incoming residual, which is what the down projection needs.
template <int TT, bool FUSE>
__global__ __launch_bounds__(NW * 32) void k_proj(
        const uint8_t *__restrict__ Wa, const uint8_t *__restrict__ Wb,
        const _Float16 *__restrict__ B,
        const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const float *__restrict__ signs, const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int Nloop, int outstride, int rowoff) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    const uint8_t *abase = Wa + size_t(tile) * nb * BLOCK_BYTES;
    const uint8_t *bbase = Wb + size_t(tile) * nb * BLOCK_BYTES;
    // Npad is the B fragment stride, Nloop the token axis this launch walks. They differ when the
    // tile width does not divide the batch's tile count: the last step then reads fragment rows
    // past the batch, which the caller's allocation slack covers and the row guard below discards.
    for (int tg = tg0; tg < Nloop; tg += tstride) {
        float8 ca[TT], cb[TT];
#pragma unroll
        for (int t = 0; t < TT; ++t) { ca[t] = float8{}; cb[t] = float8{}; }
        for (int blk = 0; blk < nb; ++blk) {
            // Tile-major scale rows: the 16 scales one wave needs for a block are 32 contiguous
            // bytes, and each lane keeps its own row's scale as two byte tables for the block.
            unsigned atlo, athi, btlo, bthi;
            scale_tables(sa[(size_t(tile) * nb + blk) * 16 + col], atlo, athi);
            scale_tables(sb[(size_t(tile) * nb + blk) * 16 + col], btlo, bthi);
#pragma unroll 1
            for (int s = 0; s < SLICES; ++s) {
                const half16 wa = weight_operand(abase, blk, s, col, atlo, athi);
                const half16 wb = weight_operand(bbase, blk, s, col, btlo, bthi);
#pragma unroll
                for (int t = 0; t < TT; ++t) {
                    const half16 bf = ((const half16 *) B)[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                    ca[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(wa, bf, ca[t]);
                    cb[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(wb, bf, cb[t]);
                }
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            const int token = tg + t * 16 + col;
            if (token >= rows) continue;
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                const int row = tile * 16 + 2 * r + half;
                const size_t o = size_t(token) * outstride + row;
                if constexpr (FUSE) out[o] = silu(ca[t][r]) * cb[t][r] * signs[row];
                else {
                    out[o] = resid[o] + ca[t][r];
                    out[o + rowoff] = resid[o + rowoff] + cb[t][r];
                }
            }
        }
    }
}

// ------------------------------------------------------------------ candidate plumbing

struct Plan {
    int D = 0, FF = 0, maxrows = 0, maxtt = 4;
    bool a8 = true;
    uint8_t *wg = nullptr, *wu = nullptr, *wd_a = nullptr, *wd_b = nullptr;
    uint16_t *sg = nullptr, *su = nullptr, *sd_a = nullptr, *sd_b = nullptr;
    _Float16 *Bin = nullptr, *Bhid = nullptr;
    float *hidden = nullptr;
    const float *norm = nullptr, *signs = nullptr;
    size_t bytes = 0;
};

// HALO tile rows carry 32 logical rows per block; row r of tile t is lane (t & 1) * 16 + r of
// block t/2. Decoding and packing are untimed preparation. Scales stay raw FP16 bits.
void decode_matrix(const uint8_t *halo_bytes, int rows, int kdim,
                   std::vector<int8_t> &trits, std::vector<uint16_t> &scales) {
    const int nb = kdim / KB;
    trits.assign(size_t(rows) * kdim, 0);
    scales.assign(size_t(rows) * nb, 0);
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
                for (int j = 0; j < 128; ++j) trits[size_t(row) * kdim + b * 128 + j] = int8_t(int(t128[j]) - 1);
            }
        }
}

template <class T> void upload(T *&dst, const std::vector<T> &src, size_t &total) {
    check(hipMalloc(&dst, src.size() * sizeof(T)), "malloc");
    check(hipMemcpy(dst, src.data(), src.size() * sizeof(T), hipMemcpyHostToDevice), "upload");
    total += src.size() * sizeof(T);
}

template <bool A8, int MAXTT>
void *prepare(const kelana_batch::Weights &w, int maxrows) {
    auto *p = new Plan{};
    p->D = w.width; p->FF = w.hidden; p->maxrows = maxrows; p->maxtt = MAXTT; p->a8 = A8;
    p->norm = w.norm_device; p->signs = w.signs_device;
    std::vector<int8_t> g, u, d;
    std::vector<uint16_t> gs, us, ds;
    decode_matrix(w.gate_host, p->FF, p->D, g, gs);
    decode_matrix(w.up_host, p->FF, p->D, u, us);
    decode_matrix(w.down_host, p->D, p->FF, d, ds);
    upload(p->wg, pack_two_bit(g.data(), p->FF, p->D), p->bytes);
    upload(p->wu, pack_two_bit(u.data(), p->FF, p->D), p->bytes);
    upload(p->sg, tile_major(gs, p->FF, p->D / KB), p->bytes);
    upload(p->su, tile_major(us, p->FF, p->D / KB), p->bytes);
    // The down matrix has no natural row partner; splitting it in half only needs both halves to
    // consume the same activation vector, which every row of one projection does.
    const int Dh = p->D / 2, nbf = p->FF / KB;
    std::vector<int8_t> d0(d.begin(), d.begin() + size_t(Dh) * p->FF), d1(d.begin() + size_t(Dh) * p->FF, d.end());
    std::vector<uint16_t> ds0(ds.begin(), ds.begin() + size_t(Dh) * nbf), ds1(ds.begin() + size_t(Dh) * nbf, ds.end());
    upload(p->wd_a, pack_two_bit(d0.data(), Dh, p->FF), p->bytes);
    upload(p->wd_b, pack_two_bit(d1.data(), Dh, p->FF), p->bytes);
    upload(p->sd_a, tile_major(ds0, Dh, nbf), p->bytes);
    upload(p->sd_b, tile_major(ds1, Dh, nbf), p->bytes);

    // A projection rounds its token axis up to a whole tile group, so a batch whose tile count the
    // width does not divide reads up to 112 token columns past Npad. The fragment index is
    // slice * Npad + token, so those reads alias the next k-slice's own valid columns and only the
    // final slice runs off the end: one tile group of fragments past the whole buffer is enough,
    // not a slack column in every slice. The aliased columns belong to invalid tokens and their
    // outputs are discarded by the row guard, so no arithmetic depends on what they hold. The
    // hidden buffer needs nothing, being indexed by real rows only.
    const int Npad = (maxrows + 15) / 16 * 16;
    const size_t slack = 8 * 16 * 32;   // 128 fragments, 4 KiB
    const size_t bin = size_t(p->D / 16) * Npad * 32 + slack,
                 bhid = size_t(p->FF / 16) * Npad * 32 + slack;
    check(hipMalloc(&p->Bin, bin), "Bin");
    check(hipMalloc(&p->Bhid, bhid), "Bhid");
    check(hipMemset(p->Bin, 0, bin), "Bin zero");
    check(hipMemset(p->Bhid, 0, bhid), "Bhid zero");
    check(hipMalloc(&p->hidden, size_t(Npad) * p->FF * 4), "hidden");
    p->bytes += bin + bhid + size_t(Npad) * p->FF * 4;
    return p;
}

void release(void *state) {
    auto *p = static_cast<Plan *>(state);
    for (void *q : {(void *) p->wg, (void *) p->wu, (void *) p->wd_a, (void *) p->wd_b,
                    (void *) p->sg, (void *) p->su, (void *) p->sd_a, (void *) p->sd_b,
                    (void *) p->Bin, (void *) p->Bhid, (void *) p->hidden})
        if (q) hipFree(q);
    delete p;
}
size_t resident_bytes(void *state) { return static_cast<Plan *>(state)->bytes; }

// Enough workgroups to fill the device without splitting a weight stream that is already spread
// over more workgroups than the machine has compute units.
int group_split(int xgroups, int groups) {
    const int want = 320 / (xgroups > 0 ? xgroups : 1);
    return std::max(1, std::min(groups, want));
}

// Token tiles per wave. A wider tile reads the weight stream fewer times, and this map can afford
// one: with no integer accumulator to drain, only the FP32 sums live in registers, so eight tiles
// cost 227 VGPRs with no spill where the integer maps spilled at 256. The width pays only while the
// grid still fills the device, and the two projections have different room for it.
//
// Gate/up owns 1088 row tiles, so 272 workgroups exist before the token axis is split at all: take
// the widest tile the batch allows. Down owns 160 row tiles in 40 workgroups and has to split the
// token axis to fill the machine, which re-reads its weights once per split. Below 256 rows the
// splits are what it wants; at 256 the weight traffic wins and the widest tile is better.
//
// Measured on this target rather than derived: whole-FFN medians at 32/64/128/256 rows over the
// grid of both widths, recorded in README.md. KELANA_SCALED_TT_GU / _DN force a width so the fit
// can be rechecked on another shape without a rebuild.
int pick_tt(bool gate_up, int Npad, int maxtt) {
    const int ntiles = std::max(1, Npad / 16);
    const char *env = getenv(gate_up ? "KELANA_SCALED_TT_GU" : "KELANA_SCALED_TT_DN");
    if (env) return std::max(1, std::min(atoi(env), ntiles));
    const int cap = std::min(maxtt, ntiles);
    return gate_up || Npad >= 256 ? std::min(8, cap) : std::min(2, cap);
}

// Optional per-stage timing, off unless KELANA_SCALED_STAGES is set. It synchronises between
// stages, so a timed acceptance run must leave it unset.
struct Stages {
    bool on = getenv("KELANA_SCALED_STAGES") != nullptr;
    hipEvent_t ev[5]{};
    const char *name[4] = {"prep_in", "gate_up_silu", "prep_hidden", "down_residual"};
    int at = 0;
    void mark(hipStream_t s) { if (!on) return; if (!ev[at]) hipEventCreate(&ev[at]); hipEventRecord(ev[at], s); ++at; }
    void report(const char *who, int rows) {
        if (!on) return;
        hipEventSynchronize(ev[4]);
        std::fprintf(stderr, "%-22s rows %-4d", who, rows);
        for (int i = 0; i < 4; ++i) { float t = 0; hipEventElapsedTime(&t, ev[i], ev[i + 1]);
            std::fprintf(stderr, "  %s %6.3f ms", name[i], t); }
        std::fprintf(stderr, "\n");
        at = 0;
    }
};

// The token axis is walked in whole tile groups, so a batch whose tile count the width does not
// divide is rounded up here rather than given a narrower width: 200 rows is 13 tiles, and 13 is
// prime, so requiring a divisor would drop that batch to one tile per wave. The rounded-up rows are
// read from the activation buffer's slack and discarded by the row guard.
template <bool FUSE>
void launch_proj(int Npad, int tiles, int maxtt, hipStream_t stream,
                 const uint8_t *Wa, const uint8_t *Wb, const _Float16 *B,
                 const uint16_t *sa, const uint16_t *sb, const float *signs,
                 const float *resid, float *out, int nb, int rows, int outstride, int rowoff) {
    const int xg = tiles / NW, tt = pick_tt(FUSE, Npad, maxtt);
#define GO(TT) do { \
        const int nloop = (Npad + TT * 16 - 1) / (TT * 16) * (TT * 16); \
        const dim3 grid(xg, group_split(xg, nloop / (TT * 16))); \
        k_proj<TT, FUSE><<<grid, NW * 32, 0, stream>>>( \
            Wa, Wb, B, sa, sb, signs, resid, out, nb, rows, Npad, nloop, outstride, rowoff); } while (0)
    if (tt >= 8)      GO(8);
    else if (tt >= 4) GO(4);
    else if (tt >= 2) GO(2);
    else              GO(1);
#undef GO
}

template <bool A8, int MAXTT>
void run(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    // The tile cap is a build-time property of the candidate; the environment override exists so a
    // tuning sweep can A/B the cap on identical kernels.
    static const int maxtt = getenv("KELANA_SCALED_MAXTT") ? atoi(getenv("KELANA_SCALED_MAXTT")) : MAXTT;
    auto *p = static_cast<Plan *>(state);
    static Stages st;
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    st.mark(stream);
    k_prep<true, true, A8><<<rows * (D / 1024), NT, 0, stream>>>(input, p->norm, p->Bin, D, Npad);
    st.mark(stream);
    launch_proj<true>(Npad, FF / 16, maxtt, stream,
        (const uint8_t *) p->wg, (const uint8_t *) p->wu, (const _Float16 *) p->Bin,
        (const uint16_t *) p->sg, (const uint16_t *) p->su, p->signs, (const float *) nullptr,
        p->hidden, D / KB, rows, FF, 0);
    st.mark(stream);
    k_prep<false, false, A8><<<rows * (FF / 1024), NT, 0, stream>>>(p->hidden, nullptr, p->Bhid, FF, Npad);
    st.mark(stream);
    launch_proj<false>(Npad, Dh / 16, maxtt, stream,
        (const uint8_t *) p->wd_a, (const uint8_t *) p->wd_b, (const _Float16 *) p->Bhid,
        (const uint16_t *) p->sd_a, (const uint16_t *) p->sd_b, (const float *) nullptr, input,
        output, FF / KB, rows, D, Dh);
    st.mark(stream);
    st.report(A8 ? (MAXTT >= 8 ? "cs-f16-a8" : "cs-f16-a8-t4") : "cs-f16-direct", rows);
}

kelana_batch::Candidate scaled_a8() {
    return {"cs-scaled-f16-a8", kelana_batch::Claim::approximate,
            "two-bit ternary expanded to scaled FP16 in registers, eight-bit activation values as FP16, one FP32 accumulator across K",
            prepare<true, 8>, run<true, 8>, release, resident_bytes};
}
kelana_batch::Candidate scaled_a8_t4() {
    return {"cs-scaled-f16-a8-t4", kelana_batch::Claim::approximate,
            "the same map capped at four token tiles per wave, the cap the integer maps run at: the tile-width ablation",
            prepare<true, 4>, run<true, 4>, release, resident_bytes};
}
kelana_batch::Candidate scaled_direct() {
    return {"cs-scaled-f16-direct", kelana_batch::Claim::approximate,
            "same scaled-FP16 weights with activations rounded straight to FP16, no eight-bit grid",
            prepare<false, 8>, run<false, 8>, release, resident_bytes};
}

} // namespace

KELANA_BATCH_REGISTER(scaled_a8)
KELANA_BATCH_REGISTER(scaled_a8_t4)
KELANA_BATCH_REGISTER(scaled_direct)
