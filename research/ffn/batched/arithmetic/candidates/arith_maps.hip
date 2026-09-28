// Whole-FFN candidates for the batched arithmetic maps.
//
// Residual in, residual out, for N real tokens. Four kernels on the caller's stream:
//
//   1. post-attention RMS norm, folded sign, 1024-point Hadamard, four-bit block quantisation
//      written straight into WMMA B fragments (no int8 buffer to re-read),
//   2. gate and up projection with SiLU, product and the hidden sign applied in registers,
//   3. hidden Hadamard and four-bit block quantisation into B fragments,
//   4. down projection accumulated onto the incoming residual.
//
// The maps differ only in how the ternary weights meet those activations:
//
//   arith-paired-a4  one FP16 coefficient g + 2047*u carries a gate row and an up row, so one
//                    v_wmma_f32_16x16x16_f16 covers 32 logical rows x 16 tokens. The down matrix
//                    pairs row d with row d + D/2, which have no relation beyond sharing the input.
//   arith-iu4-a4     v_wmma_i32_16x16x16_iu4 on the same four-bit activations, two-bit weight
//                    storage expanded to nibbles in registers. Half the issue cost per instruction
//                    on gfx1151, exact integer accumulation, no radix recovery.
//
// Both are approximate only through the activation quantiser: deterministic symmetric four-bit,
// per (row, 128-block), scale amax/7, round-to-nearest-even, clamped to [-7, 7]. There is no
// stochastic component and no seed. Weights stay exactly the deployed ternary values with their
// deployed FP16 block scales.
#include "../../api.hpp"
#include "../maps.hpp"
#include "halo_format.h"
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <algorithm>

using namespace kelana_arith;

namespace {

constexpr int NT = 256;            // prep threads per 1024-element chunk
constexpr int NW = 4;              // waves per projection workgroup
constexpr float NORM_EPS = 1e-5f;

void check(hipError_t e, const char *what) {
    if (e != hipSuccess) { std::fprintf(stderr, "arith: %s: %s\n", what, hipGetErrorString(e)); std::abort(); }
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

// One workgroup per (row, 1024-chunk). Identical normalisation, sign folding and Hadamard order to
// the deployed prep_chunk_r; only the quantiser and the destination layout differ. MAP 0 writes
// FP16 B fragments, MAP 1 writes packed int4 nibbles. Fragment (kslice, token) holds the 16 K
// values of one token, which is what WMMA lane l%16 supplies.
template <int MAP> struct Traits {
    static constexpr bool four_bit = (MAP == 0 || MAP == 1);
    static constexpr bool paired_weights = (MAP == 0 || MAP == 3);
    static constexpr int wblock = paired_weights ? PAIR_BLOCK_BYTES : 512;
    static constexpr size_t frag = MAP == 1 ? 8 : MAP == 2 ? 16 : 32;
    static constexpr int planes = MAP == 3 ? 2 : 1;
    static constexpr float levels = four_bit ? 7.0f : 127.0f;
};

template <int MAP, bool NORM, bool HAS_SIGN>
__global__ __launch_bounds__(NT) void k_prep(const float *__restrict__ x, const float *__restrict__ kvec,
        void *__restrict__ Bout, void *__restrict__ Bout2, float *__restrict__ cscale, int n, int rows, int Npad) {
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
    // Deterministic symmetric four-bit quantiser over the 128-element block this warp owns.
    float amax = warp_max(fmaxf(fmaxf(fabsf(v.x), fabsf(v.y)), fmaxf(fabsf(v.z), fabsf(v.w))));
    constexpr float L = Traits<MAP>::levels;
    float iscale = amax > 0.0f ? L / amax : 0.0f;
    int q[4] = {__float2int_rn(v.x * iscale), __float2int_rn(v.y * iscale),
                __float2int_rn(v.z * iscale), __float2int_rn(v.w * iscale)};
#pragma unroll
    for (int j = 0; j < 4; ++j) q[j] = max(-int(L), min(int(L), q[j]));
    const int kslice = base >> 4, slot = base & 15;
    if constexpr (MAP == 0) {
        _Float16 *dst = (_Float16 *) Bout + (size_t(kslice) * Npad + row) * 16 + slot;
#pragma unroll
        for (int j = 0; j < 4; ++j) dst[j] = (_Float16) q[j];
    } else if constexpr (MAP == 1) {
        uint8_t *dst = (uint8_t *) Bout + (size_t(kslice) * Npad + row) * 8 + slot / 2;
        dst[0] = uint8_t((q[0] & 0xf) | ((q[1] & 0xf) << 4));
        dst[1] = uint8_t((q[2] & 0xf) | ((q[3] & 0xf) << 4));
    } else if constexpr (MAP == 2) {
        uint8_t *dst = (uint8_t *) Bout + (size_t(kslice) * Npad + row) * 16 + slot;
#pragma unroll
        for (int j = 0; j < 4; ++j) dst[j] = uint8_t(q[j] & 0xff);
    } else {
        // Exact eight-bit input as two FP16 digit planes: q = lo + 16 * hi with lo in [-8,7].
        _Float16 *lo = (_Float16 *) Bout + (size_t(kslice) * Npad + row) * 16 + slot;
        _Float16 *hi = (_Float16 *) Bout2 + (size_t(kslice) * Npad + row) * 16 + slot;
#pragma unroll
        for (int j = 0; j < 4; ++j) {
            int l = ((q[j] + 8) & 15) - 8;
            lo[j] = (_Float16) l; hi[j] = (_Float16) ((q[j] - l) >> 4);
        }
    }
    if (lane == 0) cscale[(size_t) row * (n / KB) + (base >> 7)] = amax / L;
    if (rows) {}  // rows is documentation for the caller's padding contract
}

// ------------------------------------------------------------------ projection

// A wave owns 16 physical weight rows and TT token tiles. FUSE folds SiLU, the product and the
// hidden sign into the store; otherwise the two row sets are stored separately and, for the down
// projection, accumulated onto the incoming residual.
template <int TT, int MAP, bool FUSE>
__global__ __launch_bounds__(NW * 32) void k_proj(
        const uint8_t *__restrict__ Wa, const uint8_t *__restrict__ Wb,
        const void *__restrict__ B, const void *__restrict__ B2,
        const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const float *__restrict__ cscale, const float *__restrict__ signs,
        const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride, int rowoff) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    constexpr int WB = Traits<MAP>::wblock;
    const uint8_t *abase = Wa + size_t(tile) * nb * WB;
    const uint8_t *bbase = Wb + size_t(tile) * nb * WB;
    for (int tg = tg0; tg < Npad; tg += tstride) {
        float ya[TT][8], yb[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { ya[t][r] = 0.f; yb[t][r] = 0.f; }
        for (int blk = 0; blk < nb; ++blk) {
            float asl, bsl, asr[8], bsr[8];
            if constexpr (Traits<MAP>::paired_weights) {
                unsigned sc = *(const unsigned *) (abase + size_t(blk) * WB + PAIR_CODES_BYTES + col * 4);
                asl = h2f(sc & 0xffffu); bsl = h2f(sc >> 16);
            } else {
                // Tile-major: the 16 scales one wave needs for a block are 32 contiguous bytes.
                // The row-major form this used to index put every lane's dword 2*nb bytes from
                // its neighbour's, twice per block. Worth 3% of the whole FFN at 256 rows, A/B'd
                // on identical kernels in research/ffn/batched/grouped-scales/README.md.
                asl = h2f(sa[(size_t(tile) * nb + blk) * 16 + col]);
                bsl = h2f(sb[(size_t(tile) * nb + blk) * 16 + col]);
            }
#pragma unroll
            for (int r = 0; r < 8; ++r) { asr[r] = __shfl(asl, 2 * r + half, 32); bsr[r] = __shfl(bsl, 2 * r + half, 32); }
            if constexpr (MAP == 0) {
                float8 acc[TT];
#pragma unroll
                for (int t = 0; t < TT; ++t) acc[t] = float8{};
#pragma unroll 1
                for (int s = 0; s < SLICES; ++s) {
                    half16 a = decode_paired(*(const uint2 *) (abase + size_t(blk) * WB + s * 128 + col * 8));
#pragma unroll
                    for (int t = 0; t < TT; ++t)
                        acc[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(
                            a, ((const half16 *) B)[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col], acc[t]);
                }
#pragma unroll
                for (int t = 0; t < TT; ++t) {
                    float cs = cscale[size_t(tg + t * 16 + col) * nb + blk];
#pragma unroll
                    for (int r = 0; r < 8; ++r) {
                        float g, u; unpair(acc[t][r], g, u);
                        ya[t][r] = __builtin_fmaf(g, asr[r] * cs, ya[t][r]);
                        yb[t][r] = __builtin_fmaf(u, bsr[r] * cs, yb[t][r]);
                    }
                }
            } else if constexpr (MAP == 3) {
                float8 lo[TT], hi[TT];
#pragma unroll
                for (int t = 0; t < TT; ++t) { lo[t] = float8{}; hi[t] = float8{}; }
#pragma unroll 1
                for (int s = 0; s < SLICES; ++s) {
                    half16 a = decode_paired(*(const uint2 *) (abase + size_t(blk) * WB + s * 128 + col * 8));
#pragma unroll
                    for (int t = 0; t < TT; ++t) {
                        size_t bi = size_t(blk * SLICES + s) * Npad + tg + t * 16 + col;
                        lo[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, ((const half16 *) B)[bi], lo[t]);
                        hi[t] = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, ((const half16 *) B2)[bi], hi[t]);
                    }
                }
#pragma unroll
                for (int t = 0; t < TT; ++t) {
                    float cs = cscale[size_t(tg + t * 16 + col) * nb + blk];
#pragma unroll
                    for (int r = 0; r < 8; ++r) {
                        float g0, u0, g1, u1;
                        unpair(lo[t][r], g0, u0); unpair(hi[t][r], g1, u1);
                        ya[t][r] = __builtin_fmaf(__builtin_fmaf(16.f, g1, g0), asr[r] * cs, ya[t][r]);
                        yb[t][r] = __builtin_fmaf(__builtin_fmaf(16.f, u1, u0), bsr[r] * cs, yb[t][r]);
                    }
                }
            } else if constexpr (MAP == 2) {
                int8v aa[TT], ab[TT];
#pragma unroll
                for (int t = 0; t < TT; ++t) { aa[t] = int8v{}; ab[t] = int8v{}; }
#pragma unroll 1
                for (int s = 0; s < SLICES; ++s) {
                    int4v wa = expand_i8(*(const unsigned *) (abase + size_t(blk) * WB + s * 64 + col * 4));
                    int4v wb = expand_i8(*(const unsigned *) (bbase + size_t(blk) * WB + s * 64 + col * 4));
#pragma unroll
                    for (int t = 0; t < TT; ++t) {
                        int4v bf = ((const int4v *) B)[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                        aa[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wa, true, bf, aa[t], false);
                        ab[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wb, true, bf, ab[t], false);
                    }
                }
#pragma unroll
                for (int t = 0; t < TT; ++t) {
                    float cs = cscale[size_t(tg + t * 16 + col) * nb + blk];
#pragma unroll
                    for (int r = 0; r < 8; ++r) {
                        ya[t][r] = __builtin_fmaf(float(aa[t][r]), asr[r] * cs, ya[t][r]);
                        yb[t][r] = __builtin_fmaf(float(ab[t][r]), bsr[r] * cs, yb[t][r]);
                    }
                }
            } else {
                int8v aa[TT], ab[TT];
#pragma unroll
                for (int t = 0; t < TT; ++t) { aa[t] = int8v{}; ab[t] = int8v{}; }
#pragma unroll 1
                for (int s = 0; s < SLICES; ++s) {
                    int2v wa = expand_i4(*(const unsigned *) (abase + size_t(blk) * WB + s * 64 + col * 4));
                    int2v wb = expand_i4(*(const unsigned *) (bbase + size_t(blk) * WB + s * 64 + col * 4));
#pragma unroll
                    for (int t = 0; t < TT; ++t) {
                        int2v bf = ((const int2v *) B)[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                        aa[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wa, true, bf, aa[t], false);
                        ab[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wb, true, bf, ab[t], false);
                    }
                }
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
    uint8_t *wgu_a = nullptr, *wgu_b = nullptr, *wd_a = nullptr, *wd_b = nullptr;
    uint16_t *sg = nullptr, *su = nullptr, *sd_a = nullptr, *sd_b = nullptr;
    void *Bin = nullptr, *Bhid = nullptr, *Bin2 = nullptr, *Bhid2 = nullptr;
    float *csin = nullptr, *cshid = nullptr, *hidden = nullptr;
    const float *norm = nullptr, *signs = nullptr;
    size_t bytes = 0;
};

// HALO tile rows carry 32 logical rows per block; row r of tile t is lane (t & 1) * 16 + (r) of
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

// Scales in the order a wave reads them: [tile][block][16 rows].
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

template <int MI, int MH>
void *prepare(const kelana_batch::Weights &w, int maxrows) {
    auto *p = new Plan{};
    p->D = w.width; p->FF = w.hidden; p->maxrows = maxrows;
    p->norm = w.norm_device; p->signs = w.signs_device;
    std::vector<int8_t> g, u, d;
    std::vector<uint16_t> gs, us, ds;
    decode_matrix(w.gate_host, p->FF, p->D, g, gs);
    decode_matrix(w.up_host, p->FF, p->D, u, us);
    decode_matrix(w.down_host, p->D, p->FF, d, ds);
    // The down matrix has no natural row partner; pairing rows d and d + D/2 only needs them to
    // consume the same activation vector, which every row of one projection does.
    int Dh = p->D / 2;
    std::vector<int8_t> d0(d.begin(), d.begin() + size_t(Dh) * p->FF), d1(d.begin() + size_t(Dh) * p->FF, d.end());
    int nbf = p->FF / KB;
    std::vector<uint16_t> ds0(ds.begin(), ds.begin() + size_t(Dh) * nbf), ds1(ds.begin() + size_t(Dh) * nbf, ds.end());
    if constexpr (Traits<MI>::paired_weights) {
        upload(p->wgu_a, pack_paired(g.data(), u.data(), gs.data(), us.data(), p->FF, p->D), p->bytes);
    } else {
        upload(p->wgu_a, pack_two_bit(g.data(), p->FF, p->D), p->bytes);
        upload(p->wgu_b, pack_two_bit(u.data(), p->FF, p->D), p->bytes);
        upload(p->sg, tile_major(gs, p->FF, p->D / KB), p->bytes);
        upload(p->su, tile_major(us, p->FF, p->D / KB), p->bytes);
    }
    if constexpr (Traits<MH>::paired_weights) {
        upload(p->wd_a, pack_paired(d0.data(), d1.data(), ds0.data(), ds1.data(), Dh, p->FF), p->bytes);
    } else {
        upload(p->wd_a, pack_two_bit(d0.data(), Dh, p->FF), p->bytes);
        upload(p->wd_b, pack_two_bit(d1.data(), Dh, p->FF), p->bytes);
        upload(p->sd_a, tile_major(ds0, Dh, nbf), p->bytes);
        upload(p->sd_b, tile_major(ds1, Dh, nbf), p->bytes);
    }
    int Npad = (maxrows + 15) / 16 * 16;
    size_t bin = size_t(p->D / 16) * Npad * Traits<MI>::frag;
    size_t bhid = size_t(p->FF / 16) * Npad * Traits<MH>::frag;
    check(hipMalloc(&p->Bin, bin), "Bin");
    check(hipMalloc(&p->Bhid, bhid), "Bhid");
    check(hipMemset(p->Bin, 0, bin), "Bin zero");
    check(hipMemset(p->Bhid, 0, bhid), "Bhid zero");
    if constexpr (Traits<MI>::planes == 2) {
        check(hipMalloc(&p->Bin2, bin), "Bin2");
        check(hipMemset(p->Bin2, 0, bin), "Bin2 zero");
        p->bytes += bin;
    }
    if constexpr (Traits<MH>::planes == 2) {
        check(hipMalloc(&p->Bhid2, bhid), "Bhid2");
        check(hipMemset(p->Bhid2, 0, bhid), "Bhid2 zero");
        p->bytes += bhid;
    }
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
    for (void *q : {(void *) p->wgu_a, (void *) p->wgu_b, (void *) p->wd_a, (void *) p->wd_b,
                    (void *) p->sg, (void *) p->su, (void *) p->sd_a, (void *) p->sd_b,
                    p->Bin, p->Bhid, p->Bin2, p->Bhid2, (void *) p->csin, (void *) p->cshid, (void *) p->hidden})
        if (q) hipFree(q);
    delete p;
}
size_t resident_bytes(void *state) { return static_cast<Plan *>(state)->bytes; }

const char *name_of(int mi, int mh) {
    static const char *n[4] = {"paired-a4", "iu4-a4", "iu8-a8", "paired-a8"};
    static char buf[64];
    std::snprintf(buf, sizeof buf, "arith-%s/%s", n[mi], n[mh]);
    return buf;
}

// Optional per-stage timing, off unless KELANA_ARITH_STAGES is set. It synchronises between
// stages, so a timed acceptance run must leave it unset.
struct Stages {
    bool on = getenv("KELANA_ARITH_STAGES") != nullptr;
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

// Enough workgroups to fill the device without splitting a weight stream that is already spread
// over more workgroups than the machine has compute units.
int group_split(int tiles, int groups) {
    int want = 320 / (tiles > 0 ? tiles : 1);
    return std::max(1, std::min(groups, want));
}

template <int MI, int MH>
void run(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    static Stages st;
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    st.mark(stream);
    k_prep<MI, true, true><<<rows * (D / 1024), NT, 0, stream>>>(
        input, p->norm, p->Bin, p->Bin2, p->csin, D, rows, Npad);
    st.mark(stream);
#define PROJ(MAP, TT, FUSE, WA, WB_, BFRAG, BFRAG2, SA, SB, CS, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF) \
    k_proj<TT, MAP, FUSE><<<dim3((TILES) / NW, group_split((TILES) / NW, Npad / (TT * 16))), \
        NW * 32, 0, stream>>>( \
        WA, WB_, BFRAG, BFRAG2, SA, SB, CS, SIGNS, RESID, OUT, NB, rows, Npad, OSTRIDE, ROWOFF)
    if (Npad >= 64) {
        PROJ(MI, 4, true, p->wgu_a, p->wgu_b, p->Bin, p->Bin2, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    } else if (Npad == 32) {
        PROJ(MI, 2, true, p->wgu_a, p->wgu_b, p->Bin, p->Bin2, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    } else {
        PROJ(MI, 1, true, p->wgu_a, p->wgu_b, p->Bin, p->Bin2, p->sg, p->su, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    }
    st.mark(stream);
    k_prep<MH, false, false><<<rows * (FF / 1024), NT, 0, stream>>>(
        p->hidden, nullptr, p->Bhid, p->Bhid2, p->cshid, FF, rows, Npad);
    st.mark(stream);
    if (Npad >= 64) {
        PROJ(MH, 4, false, p->wd_a, p->wd_b, p->Bhid, p->Bhid2, p->sd_a, p->sd_b, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    } else if (Npad == 32) {
        PROJ(MH, 2, false, p->wd_a, p->wd_b, p->Bhid, p->Bhid2, p->sd_a, p->sd_b, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    } else {
        PROJ(MH, 1, false, p->wd_a, p->wd_b, p->Bhid, p->Bhid2, p->sd_a, p->sd_b, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    }
#undef PROJ
    st.mark(stream);
    st.report(name_of(MI, MH), rows);
}

kelana_batch::Candidate paired_a4() {
    return {"arith-paired-a4", kelana_batch::Claim::approximate,
            "paired FP16 g+2047u, deterministic symmetric four-bit activations at both projections",
            prepare<0, 0>, run<0, 0>, release, resident_bytes};
}
kelana_batch::Candidate iu4_a4() {
    return {"arith-iu4-a4", kelana_batch::Claim::approximate,
            "native IU4 on two-bit ternary storage, deterministic symmetric four-bit activations",
            prepare<1, 1>, run<1, 1>, release, resident_bytes};
}
// Controls with the same kernels, tiling, producers and epilogue, differing only in activation
// width and matrix instruction. They isolate what the four-bit step actually buys.
kelana_batch::Candidate iu8_a8() {
    return {"arith-iu8-a8", kelana_batch::Claim::approximate,
            "native IU8 on two-bit ternary storage, deployed eight-bit activation quantiser",
            prepare<2, 2>, run<2, 2>, release, resident_bytes};
}
kelana_batch::Candidate paired_a8() {
    return {"arith-paired-a8", kelana_batch::Claim::approximate,
            "paired FP16 coefficient with two exact activation digit planes, eight-bit activations",
            prepare<3, 3>, run<3, 3>, release, resident_bytes};
}
// The configuration main's full-model evaluation actually measured: four-bit at the FFN input,
// eight-bit at the down projection's activation.
kelana_batch::Candidate iu4_a4_down8() {
    return {"arith-iu4-a4-down8", kelana_batch::Claim::approximate,
            "IU4 four-bit gate/up input, IU8 eight-bit hidden activation for the down projection",
            prepare<1, 2>, run<1, 2>, release, resident_bytes};
}
kelana_batch::Candidate paired_a4_down8() {
    return {"arith-paired-a4-down8", kelana_batch::Claim::approximate,
            "paired FP16 four-bit gate/up input, paired FP16 two-plane eight-bit down activation",
            prepare<0, 3>, run<0, 3>, release, resident_bytes};
}
}
KELANA_BATCH_REGISTER(paired_a4)
KELANA_BATCH_REGISTER(iu4_a4)
KELANA_BATCH_REGISTER(iu8_a8)
KELANA_BATCH_REGISTER(paired_a8)
KELANA_BATCH_REGISTER(iu4_a4_down8)
KELANA_BATCH_REGISTER(paired_a4_down8)
