// Whole-FFN candidates that consume densely packed five-trit bytes.
//
// Both maps here run the arithmetic worker's IU4 four-bit pipeline unchanged: the same producer
// (post-attention RMS norm, folded sign, 1024-point Hadamard, deterministic symmetric four-bit
// block quantiser written straight into WMMA B fragments), the same tiling, the same per-block
// scales, the same SiLU/product/sign epilogue and the same residual accumulation. The only thing
// that differs is how a ternary weight reaches the matrix instruction:
//
//   dc-dense5-a4     26 bytes per (row, 128-block), 1.625 bits per weight. Stored HALO five-trit
//                    bytes. Two multiplies and two shifts per byte pair lift a byte into two
//                    nine-valued two-trit codes plus one trit, and a code *is* the permute
//                    selector that produces the int4 operand byte. No weight is ever formed.
//   dc-paircode-a4   32 bytes per (row, 128-block), 2.000 bits per weight. The same nine-valued
//                    code, already sitting in its own nibble, so expansion is a mask, a shift
//                    and two permutes. This is the control: identical output, identical traffic
//                    shape to the arithmetic worker's two-bit image, minimal expansion work. It
//                    isolates bits-per-weight from instructions-per-weight, which is the only
//                    axis the dense byte actually moves.
//
// All three paths have matched arith-iu4-a4 output hashes on the recorded real rows.
// They preserve its approximate A4 numerical construction, not the deployed A8 model.
#include "../../api.hpp"
#include "../dense5.hpp"
#include <cstdio>
#include <cstdlib>
#include <vector>

using namespace kelana_dense;

namespace {

constexpr int NT = 256;            // prep threads per 1024-element chunk
constexpr int NW = 4;              // waves per projection workgroup
constexpr float NORM_EPS = 1e-5f;

using int8v = int __attribute__((ext_vector_type(8)));
using int2vv = int __attribute__((ext_vector_type(2)));

void check(hipError_t e, const char *what) {
    if (e != hipSuccess) { std::fprintf(stderr, "dense: %s: %s\n", what, hipGetErrorString(e)); std::abort(); }
}

__device__ __forceinline__ float h2f(unsigned bits) {
    unsigned short u = (unsigned short) bits; _Float16 h;
    __builtin_memcpy(&h, &u, 2); return (float) h;
}
__device__ __forceinline__ float silu(float x) { return x / (1.0f + __expf(-x)); }
__device__ __forceinline__ float warp_max(float v) {
    for (int b = 1; b < 32; b <<= 1) v = fmaxf(v, __shfl_xor(v, b, 32));
    return v;
}
__device__ __forceinline__ float block_sum(float v, float *red) {
    for (int b = 1; b < 32; b <<= 1) v += __shfl_xor(v, b, 32);
    int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    if (lane == 0) red[wave] = v;
    __syncthreads();
    float t = 0;
#pragma unroll
    for (int w = 0; w < NT / 32; ++w) t += red[w];
    return t;
}

// ------------------------------------------------------------------ activation producer
// The arithmetic candidate's normalisation, sign folding, Hadamard and A4 quantiser,
// writing packed int4 B fragments. Fragment (kslice, token) holds one token's sixteen K values.
template <bool NORM, bool HAS_SIGN>
__global__ __launch_bounds__(NT) void k_prep(const float *__restrict__ x, const float *__restrict__ kvec,
        void *__restrict__ Bout, float *__restrict__ cscale, int n, int rows, int Npad) {
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
            float4 t = *(const float4 *) (x + rb + i);
            ss = fmaf(t.x, t.x, ss); ss = fmaf(t.y, t.y, ss);
            ss = fmaf(t.z, t.z, ss); ss = fmaf(t.w, t.w, ss);
        }
        ss = block_sum(ss, red);
        inv = rsqrtf(ss / (float) n + NORM_EPS);
    }
    float4 v = *(const float4 *) (x + rb + base);
    if constexpr (HAS_SIGN) {
        float4 k = *(const float4 *) (kvec + base);
        v.x *= inv * k.x; v.y *= inv * k.y; v.z *= inv * k.z; v.w *= inv * k.w;
    }
    { float p0 = v.x + v.y, p1 = v.x - v.y, p2 = v.z + v.w, p3 = v.z - v.w;
      v.x = p0 + p2; v.y = p1 + p3; v.z = p0 - p2; v.w = p1 - p3; }
#pragma unroll
    for (int bit = 1; bit < 32; bit <<= 1) {
        bool upper = (lane & bit) != 0;
        float ox = __shfl_xor(v.x, bit, 32), oy = __shfl_xor(v.y, bit, 32);
        float oz = __shfl_xor(v.z, bit, 32), ow = __shfl_xor(v.w, bit, 32);
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
                float x0 = u[m], x1 = u[m + len]; u[m] = x0 + x1; u[m + len] = x0 - x1;
            }
#pragma unroll
        for (int m = 0; m < 8; ++m) s[tid + 128 * m] = u[m] * 0.03125f;
    }
    __syncthreads();
    v = *(const float4 *) (s + e0);
    float amax = warp_max(fmaxf(fmaxf(fabsf(v.x), fabsf(v.y)), fmaxf(fabsf(v.z), fabsf(v.w))));
    float iscale = amax > 0.0f ? 7.0f / amax : 0.0f;
    int q[4] = {__float2int_rn(v.x * iscale), __float2int_rn(v.y * iscale),
                __float2int_rn(v.z * iscale), __float2int_rn(v.w * iscale)};
#pragma unroll
    for (int j = 0; j < 4; ++j) q[j] = max(-7, min(7, q[j]));
    const int kslice = base >> 4, slot = base & 15;
    uint8_t *dst = (uint8_t *) Bout + (size_t(kslice) * Npad + row) * 8 + slot / 2;
    dst[0] = uint8_t((q[0] & 0xf) | ((q[1] & 0xf) << 4));
    dst[1] = uint8_t((q[2] & 0xf) | ((q[3] & 0xf) << 4));
    if (lane == 0) cscale[(size_t) row * (n / KB) + (base >> 7)] = amax / 7.0f;
    if (rows) {}
}

// ------------------------------------------------------------------ weight paths

// Dense: one 128-block of one row is 26 stored bytes in three aligned sections. The eight K16
// operand fragments come out in the order 0,1,2,3,6,4,5,7 because slice 6 is finished by the
// fifth trits of the first four dwords; integer accumulation does not care about slice order.
// Two phases so the loaded bytes and the pending fifth-trit codes do not all have to be live at
// once: section S0 finishes slices 0..3 and then slice 6, after which its registers are dead
// before section S1 and S2 are touched at all.
struct DenseHalf {
    uint4 s0;
    unsigned cc[4];
};

__device__ __forceinline__ uint4 dense_load0(const uint8_t *base, int col) {
    return *(const uint4 *) (base + col * 16);
}
__device__ __forceinline__ uint2 dense_load1(const uint8_t *base, int col) {
    return *(const uint2 *) (base + DENSE_S1_OFF + col * 8);
}
__device__ __forceinline__ unsigned dense_load2(const uint8_t *base, int col) {
    return *(const unsigned short *) (base + DENSE_S2_OFF + col * 2);
}

__device__ __forceinline__ int2vv dense_slice(unsigned src, unsigned &cc) {
    DenseDword r = peel_dword(src);
    cc = cc_of(r);
    uint2v v = slice_of(r);
    return int2vv{int(v[0]), int(v[1])};
}
__device__ __forceinline__ int2vv dense_slice6(const unsigned cc[4]) {
    uint2v v = slice_from_cc(cc[0], cc[1], cc[2], cc[3]);
    return int2vv{int(v[0]), int(v[1])};
}
__device__ __forceinline__ int2vv dense_slice7(unsigned cc4, unsigned cc5, unsigned s2) {
    return int2vv{int(expand_codes(perm(cc5, cc4, 0x06040200u))),
                  int(expand_codes(tail_codes(s2)))};
}
__device__ __forceinline__ int2vv pair_slice(const uint8_t *base, int sl, int col) {
    uint2v v = expand_paircode(*(const unsigned *) (base + sl * 64 + col * 4));
    return int2vv{int(v[0]), int(v[1])};
}
__device__ __forceinline__ int2vv pair_slice_word(unsigned word) {
    uint2v v = expand_paircode(word);
    return int2vv{int(v[0]), int(v[1])};
}

// ------------------------------------------------------------------ projection
// A wave owns 16 physical weight rows and TT token tiles. FUSE folds SiLU, the product and the
// hidden sign into the store; otherwise the two row sets accumulate onto the incoming residual.
// WMAP 0 dense five-trit bytes, 1 nibble codes with per-slice dword loads, 2 nibble codes with
// the dense map's wide load shape.
template <int TT, int WMAP, bool FUSE>
__global__ __launch_bounds__(NW * 32) void k_proj(
        const uint8_t *__restrict__ Wa, const uint8_t *__restrict__ Wb,
        const void *__restrict__ B,
        const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const float *__restrict__ cscale, const float *__restrict__ signs,
        const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride, int rowoff) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    constexpr int WB = WMAP == 0 ? DENSE_BLOCK_BYTES : PAIR_BLOCK_BYTES;
    const uint8_t *abase = Wa + size_t(tile) * nb * WB;
    const uint8_t *bbase = Wb + size_t(tile) * nb * WB;
    for (int tg = tg0; tg < Npad; tg += tstride) {
        float ya[TT][8], yb[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { ya[t][r] = 0.f; yb[t][r] = 0.f; }
        for (int blk = 0; blk < nb; ++blk) {
            float asl = h2f(sa[(size_t(tile) * nb + blk) * 16 + col]);
            float bsl = h2f(sb[(size_t(tile) * nb + blk) * 16 + col]);
            float asr[8], bsr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { asr[r] = __shfl(asl, 2 * r + half, 32); bsr[r] = __shfl(bsl, 2 * r + half, 32); }
            int8v aa[TT], ab[TT];
#pragma unroll
            for (int t = 0; t < TT; ++t) { aa[t] = int8v{}; ab[t] = int8v{}; }
            const uint8_t *ap = abase + size_t(blk) * WB, *bp = bbase + size_t(blk) * WB;
            const int bslice = blk * SLICES;
#define MAC(SL, WA_, WB_)                                                                         \
            {                                                                                     \
                int2vv wa_ = (WA_), wb_ = (WB_);                                                  \
                _Pragma("unroll") for (int t = 0; t < TT; ++t) {                                   \
                    int2vv bf = ((const int2vv *) B)[size_t(bslice + (SL)) * Npad + tg + t * 16 + col]; \
                    aa[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wa_, true, bf, aa[t], false); \
                    ab[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wb_, true, bf, ab[t], false); \
                }                                                                                 \
            }
            if constexpr (WMAP == 0) {
                {
                    uint4 a0 = dense_load0(ap, col), b0 = dense_load0(bp, col);
                    unsigned ca[4], cb[4];
                    MAC(0, dense_slice(a0.x, ca[0]), dense_slice(b0.x, cb[0]))
                    MAC(1, dense_slice(a0.y, ca[1]), dense_slice(b0.y, cb[1]))
                    MAC(2, dense_slice(a0.z, ca[2]), dense_slice(b0.z, cb[2]))
                    MAC(3, dense_slice(a0.w, ca[3]), dense_slice(b0.w, cb[3]))
                    MAC(6, dense_slice6(ca), dense_slice6(cb))
                }
                {
                    uint2 a1 = dense_load1(ap, col), b1 = dense_load1(bp, col);
                    unsigned ca4, ca5, cb4, cb5;
                    MAC(4, dense_slice(a1.x, ca4), dense_slice(b1.x, cb4))
                    MAC(5, dense_slice(a1.y, ca5), dense_slice(b1.y, cb5))
                    MAC(7, dense_slice7(ca4, ca5, dense_load2(ap, col)),
                           dense_slice7(cb4, cb5, dense_load2(bp, col)))
                }
            } else if constexpr (WMAP == 1) {
#pragma unroll 1
                for (int s = 0; s < SLICES; ++s) MAC(s, pair_slice(ap, s, col), pair_slice(bp, s, col))
            } else {
                {
                    uint4 a0 = *(const uint4 *) (ap + col * 32), b0 = *(const uint4 *) (bp + col * 32);
                    MAC(0, pair_slice_word(a0.x), pair_slice_word(b0.x))
                    MAC(1, pair_slice_word(a0.y), pair_slice_word(b0.y))
                    MAC(2, pair_slice_word(a0.z), pair_slice_word(b0.z))
                    MAC(3, pair_slice_word(a0.w), pair_slice_word(b0.w))
                }
                {
                    uint4 a1 = *(const uint4 *) (ap + col * 32 + 16), b1 = *(const uint4 *) (bp + col * 32 + 16);
                    MAC(4, pair_slice_word(a1.x), pair_slice_word(b1.x))
                    MAC(5, pair_slice_word(a1.y), pair_slice_word(b1.y))
                    MAC(6, pair_slice_word(a1.z), pair_slice_word(b1.z))
                    MAC(7, pair_slice_word(a1.w), pair_slice_word(b1.w))
                }
            }
#undef MAC
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                float cs = cscale[size_t(tg + t * 16 + col) * nb + blk];
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    ya[t][r] = __builtin_fmaf(float(aa[t][r]), asr[r] * cs, ya[t][r]);
                    yb[t][r] = __builtin_fmaf(float(ab[t][r]), bsr[r] * cs, yb[t][r]);
                }
            }
        }
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            int token = tg + t * 16 + col;
            if (token >= rows) continue;
#pragma unroll
            for (int r = 0; r < 8; ++r) {
                int row = tile * 16 + 2 * r + half;
                size_t o = size_t(token) * outstride + row;
                if constexpr (FUSE) out[o] = silu(ya[t][r]) * yb[t][r] * signs[row];
                else {
                    out[o] = resid[o] + ya[t][r];
                    out[o + rowoff] = resid[o + rowoff] + yb[t][r];
                }
            }
        }
    }
}

// ------------------------------------------------------------------ candidate plumbing

struct Plan {
    int D = 0, FF = 0, maxrows = 0;
    uint8_t *wg = nullptr, *wu = nullptr, *wd0 = nullptr, *wd1 = nullptr;
    uint16_t *sg = nullptr, *su = nullptr, *sd0 = nullptr, *sd1 = nullptr;
    void *Bin = nullptr, *Bhid = nullptr;
    float *csin = nullptr, *cshid = nullptr, *hidden = nullptr;
    const float *norm = nullptr, *signs = nullptr;
    size_t bytes = 0;
};

// HALO tile rows carry 32 logical rows per block; row r of tile t is lane (t & 1) * 16 + r of
// block t/2. Decoding is untimed preparation.
void decode_matrix(const uint8_t *halo_bytes, int rows, int kdim,
                   std::vector<int8_t> &trits, std::vector<uint16_t> &scales) {
    int nb = kdim / 128;
    trits.assign(size_t(rows) * kdim, 0);
    scales.assign(size_t(rows) * nb, 0);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b) {
            size_t src = (size_t(tile / 2) * nb + b) * halo::TILE_BLOCK_BYTES;
            for (int r = 0; r < 16; ++r) {
                int lane = (tile & 1) * 16 + r, row = tile * 16 + r;
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

inline std::vector<uint16_t> tile_major(const std::vector<uint16_t> &s, int rows, int nb) {
    std::vector<uint16_t> out(s.size());
    for (int row = 0; row < rows; ++row)
        for (int b = 0; b < nb; ++b)
            out[(size_t(row / 16) * nb + b) * 16 + row % 16] = s[size_t(row) * nb + b];
    return out;
}

template <class T> void upload(T *&dst, const std::vector<T> &src, size_t &total) {
    check(hipMalloc(&dst, src.size() * sizeof(T)), "malloc");
    check(hipMemcpy(dst, src.data(), src.size() * sizeof(T), hipMemcpyHostToDevice), "upload");
    total += src.size() * sizeof(T);
}

template <int WMAP>
std::vector<uint8_t> pack_for(const int8_t *w, int rows, int kdim) {
    if constexpr (WMAP == 0) return pack_dense(w, rows, kdim);
    else if constexpr (WMAP == 1) return pack_paircode<false>(w, rows, kdim);
    else return pack_paircode<true>(w, rows, kdim);
}

template <int WMAP>
void *prepare(const kelana_batch::Weights &w, int maxrows) {
    auto *p = new Plan{};
    p->D = w.width; p->FF = w.hidden; p->maxrows = maxrows;
    p->norm = w.norm_device; p->signs = w.signs_device;
    std::vector<int8_t> g, u, d;
    std::vector<uint16_t> gs, us, ds;
    decode_matrix(w.gate_host, p->FF, p->D, g, gs);
    decode_matrix(w.up_host, p->FF, p->D, u, us);
    decode_matrix(w.down_host, p->D, p->FF, d, ds);
    int Dh = p->D / 2, nbf = p->FF / KB;
    std::vector<int8_t> d0(d.begin(), d.begin() + size_t(Dh) * p->FF), d1(d.begin() + size_t(Dh) * p->FF, d.end());
    std::vector<uint16_t> ds0(ds.begin(), ds.begin() + size_t(Dh) * nbf), ds1(ds.begin() + size_t(Dh) * nbf, ds.end());
    upload(p->wg, pack_for<WMAP>(g.data(), p->FF, p->D), p->bytes);
    upload(p->wu, pack_for<WMAP>(u.data(), p->FF, p->D), p->bytes);
    upload(p->wd0, pack_for<WMAP>(d0.data(), Dh, p->FF), p->bytes);
    upload(p->wd1, pack_for<WMAP>(d1.data(), Dh, p->FF), p->bytes);
    upload(p->sg, tile_major(gs, p->FF, p->D / KB), p->bytes);
    upload(p->su, tile_major(us, p->FF, p->D / KB), p->bytes);
    upload(p->sd0, tile_major(ds0, Dh, nbf), p->bytes);
    upload(p->sd1, tile_major(ds1, Dh, nbf), p->bytes);
    int Npad = (maxrows + 15) / 16 * 16;
    size_t bin = size_t(p->D / 16) * Npad * 8, bhid = size_t(p->FF / 16) * Npad * 8;
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
    for (void *q : {(void *) p->wg, (void *) p->wu, (void *) p->wd0, (void *) p->wd1,
                    (void *) p->sg, (void *) p->su, (void *) p->sd0, (void *) p->sd1,
                    p->Bin, p->Bhid, (void *) p->csin, (void *) p->cshid, (void *) p->hidden})
        if (q) hipFree(q);
    delete p;
}
size_t resident_bytes(void *state) { return static_cast<Plan *>(state)->bytes; }

int group_split(int tiles, int groups) {
    int want = 320 / (tiles > 0 ? tiles : 1);
    return std::max(1, std::min(groups, want));
}

template <int WMAP>
void run(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    k_prep<true, true><<<rows * (D / 1024), NT, 0, stream>>>(input, p->norm, p->Bin, p->csin, D, rows, Npad);
#define PROJ(TT, FUSE, WA, WB_, BFRAG, SA, SB, CS, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF) \
    k_proj<TT, WMAP, FUSE><<<dim3((TILES) / NW, group_split((TILES) / NW, Npad / (TT * 16))),    \
        NW * 32, 0, stream>>>(WA, WB_, BFRAG, SA, SB, CS, SIGNS, RESID, OUT, NB, rows, Npad, OSTRIDE, ROWOFF)
    if (Npad % 64 == 0) {
        PROJ(4, true, p->wg, p->wu, p->Bin, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    } else if (Npad % 32 == 0) {
        PROJ(2, true, p->wg, p->wu, p->Bin, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    } else {
        PROJ(1, true, p->wg, p->wu, p->Bin, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    }
    k_prep<false, false><<<rows * (FF / 1024), NT, 0, stream>>>(p->hidden, nullptr, p->Bhid, p->cshid, FF, rows, Npad);
    if (Npad % 64 == 0) {
        PROJ(4, false, p->wd0, p->wd1, p->Bhid, p->sd0, p->sd1, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    } else if (Npad % 32 == 0) {
        PROJ(2, false, p->wd0, p->wd1, p->Bhid, p->sd0, p->sd1, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    } else {
        PROJ(1, false, p->wd0, p->wd1, p->Bhid, p->sd0, p->sd1, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    }
#undef PROJ
}

kelana_batch::Candidate dense5_a4() {
    return {"dc-dense5-a4", kelana_batch::Claim::approximate,
            "dense five-trit HALO bytes at 1.625 bpw peeled into permute selectors, native IU4, four-bit activations",
            prepare<0>, run<0>, release, resident_bytes};
}
kelana_batch::Candidate paircode_a4() {
    return {"dc-paircode-a4", kelana_batch::Claim::approximate,
            "nine-valued two-trit code one per nibble at 2.000 bpw, per-slice dword loads, native IU4",
            prepare<1>, run<1>, release, resident_bytes};
}
kelana_batch::Candidate paircode_wide_a4() {
    return {"dc-paircode-wide-a4", kelana_batch::Claim::approximate,
            "control: 2.000 bpw nibble codes read with the dense map's wide uint4 load shape, native IU4",
            prepare<2>, run<2>, release, resident_bytes};
}
}
KELANA_BATCH_REGISTER(dense5_a4)
KELANA_BATCH_REGISTER(paircode_a4)
KELANA_BATCH_REGISTER(paircode_wide_a4)
