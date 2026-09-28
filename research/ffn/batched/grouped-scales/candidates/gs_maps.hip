// Grouped-scale whole-FFN candidates: can one scale over several adjacent 128-blocks delete the
// per-block integer-to-float epilogue?
//
// The deployed representation carries an FP16 weight scale per (row, 128-block) and an FP32
// activation scale per (token, 128-block). A WMMA integer accumulator therefore has to be read
// out, converted and scaled every 128 columns of K, even though nothing else forces the chain to
// break there. If both scales were constant over G adjacent blocks the accumulator could run for
// G*128 columns and the conversion would happen once per group.
//
// Making that true costs something on each side:
//
//   activation  one amax per (token, G*128) instead of per (token, 128). The changed producer
//               is timed; quantisation error rises where a block's amax was smaller.
//   weight      lam[i,b] -> L[i,g] * m[i,b] with m a positive integer folded into the matrix
//               operand. The operand width caps m: 7 for IU4, 127 for IU8. That cap is the
//               resolution of the scale, and it is the whole question.
//
// Modes, all on the same kernel so the differences are only the ones named:
//
//   PERBLOCK  deployed scales, epilogue every 128. Control.
//   ACTONLY   grouped activation amax, per-block weight scale, epilogue every 128. Isolates the
//             activation half of the error and the cscale traffic it saves.
//   SHARED    one fitted scale per group and no per-block correction at all. Numerically the
//             naive move. It is a scale-sharing ablation, not a runtime lower bound for
//             other representations or schedules.
//   ABSORB    the real construction: fitted L per group plus an integer multiplier per block
//             carried inside the operand, so the accumulation still runs the full G*128.
//
// Weight fitting is offline (untimed prepare); the activation grouping is inside run, in the
// producer, where it belongs.
#include "../../api.hpp"
#include "../../arithmetic/maps.hpp"
#include "halo_format.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
#include <algorithm>

using namespace kelana_arith;

namespace {

constexpr int NT = 256;
constexpr int NW = 4;
constexpr float NORM_EPS = 1e-5f;

enum Mode { PERBLOCK = 0, ACTONLY = 1, SHARED = 2, ABSORB = 3, ROWCTL = 4 };

void check(hipError_t e, const char *what) {
    if (e != hipSuccess) { std::fprintf(stderr, "gs: %s: %s\n", what, hipGetErrorString(e)); std::abort(); }
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

// Ternary two-bit codes -> int4 nibbles already multiplied by a per-(row, block) integer m in
// [1,7]. p marks the nonzero nibbles and h the negative ones, so m*p is the magnitude and
// (m*p ^ 15h) + h is its two's complement inside the nibble. One 32-bit multiply per 16 weights
// is the entire added cost over the plain expansion.
__device__ __forceinline__ int2v expand_i4_m(unsigned codes, unsigned m) {
    int2v r;
#pragma unroll
    for (int j = 0; j < 2; ++j) {
        unsigned v = (codes >> (16 * j)) & 0xffffu;
        unsigned x = (v | (v << 8)) & 0x00ff00ffu;
        x = (x | (x << 4)) & 0x0f0f0f0fu;
        x = (x | (x << 2)) & 0x33333333u;
        unsigned h = x & (x >> 1) & 0x11111111u;
        unsigned p = x & 0x11111111u;
        unsigned mag = p * m;
        r[j] = int((mag ^ ((h << 4) - h)) + h);
    }
    return r;
}

// Same for signed bytes and m in [1,127].
__device__ __forceinline__ int4v expand_i8_m(unsigned codes, unsigned m) {
    int4v r;
#pragma unroll
    for (int j = 0; j < 4; ++j) {
        unsigned v = (codes >> (8 * j)) & 0xffu;
        unsigned w = (v | (v << 12)) & 0x000f000fu;
        unsigned sel = (w | (w << 6)) & 0x03030303u;
        unsigned p = __builtin_amdgcn_perm(0u, 0x01000100u, sel);
        unsigned h = __builtin_amdgcn_perm(0u, 0x01000000u, sel);
        unsigned mag = p * m;
        r[j] = int((mag ^ ((h << 8) - h)) + h);
    }
    return r;
}

// Direct code-to-consumer map. No signed trit or magnitude intermediate is
// formed: the row's palette already contains the bytes the IU8 operand needs.
__device__ __forceinline__ int4v expand_i8_palette(unsigned codes, unsigned m) {
    int4v r;
    const unsigned palette = (m << 8) | ((-m & 255u) << 24);
#pragma unroll
    for (int j = 0; j < 4; ++j) {
        const unsigned v = (codes >> (8 * j)) & 255u;
        const unsigned w = v | (v << 12);
        const unsigned sel = (w | (w << 6)) & 0x03030303u;
        r[j] = int(__builtin_amdgcn_perm(0u, palette, sel));
    }
    return r;
}

template <int MAP> struct Traits {
    static constexpr bool four_bit = (MAP == 1);
    static constexpr size_t frag = MAP == 1 ? 8 : 16;
    static constexpr float levels = four_bit ? 7.0f : 127.0f;
    static constexpr int mmax = four_bit ? 7 : 127;
};

// ------------------------------------------------------------------ activation producer
//
// Identical to the arithmetic producer except that amax is reduced over GA adjacent 128-blocks
// and one scale per group is written.
template <int MAP, bool NORM, bool HAS_SIGN, int GA, int CLIP>
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
    if constexpr (GA == 0) {
        // Whole-row quantisation happens after all transformed chunks are ready.
        *(float4 *) ((float *) Bout + rb + base) = v;
    } else {
    float amax = warp_max(fmaxf(fmaxf(fabsf(v.x), fabsf(v.y)), fmaxf(fabsf(v.z), fabsf(v.w))));
    if constexpr (GA > 1) {
        __syncthreads();
        if (lane == 0) red[wave] = amax;
        __syncthreads();
        const int w0 = (wave / GA) * GA;
#pragma unroll
        for (int k = 0; k < GA; ++k) amax = fmaxf(amax, red[w0 + k]);
    }
    // CLIP is the quantiser step in permille of amax/levels. The deployed producer uses 1000,
    // which is MSE-optimal for nothing in particular: it only guarantees no clipping. A group
    // amax is a max over G*128 samples rather than 128, so its tail is further out and a shorter
    // step is worth more than the few clipped extremes cost.
    constexpr float L = Traits<MAP>::levels;
    constexpr float A = CLIP * 0.001f;
    float step = amax * (A / L);
    float iscale = step > 0.0f ? 1.0f / step : 0.0f;
    int q[4] = {__float2int_rn(v.x * iscale), __float2int_rn(v.y * iscale),
                __float2int_rn(v.z * iscale), __float2int_rn(v.w * iscale)};
#pragma unroll
    for (int j = 0; j < 4; ++j) q[j] = max(-int(L), min(int(L), q[j]));
    const int kslice = base >> 4, slot = base & 15;
    if constexpr (MAP == 1) {
        uint8_t *dst = (uint8_t *) Bout + (size_t(kslice) * Npad + row) * 8 + slot / 2;
        dst[0] = uint8_t((q[0] & 0xf) | ((q[1] & 0xf) << 4));
        dst[1] = uint8_t((q[2] & 0xf) | ((q[3] & 0xf) << 4));
    } else {
        uint8_t *dst = (uint8_t *) Bout + (size_t(kslice) * Npad + row) * 16 + slot;
#pragma unroll
        for (int j = 0; j < 4; ++j) dst[j] = uint8_t(q[j] & 0xff);
    }
    if (lane == 0 && (wave % GA) == 0)
        cscale[(size_t) row * (n / (KB * GA)) + ((base >> 7) / GA)] = step;
    if (rows) {}
    }
}

// ------------------------------------------------------------------ projection
//
// GG blocks share one accumulator and one epilogue. Scales arrive tile-major so every lane's load
// is contiguous; the control uses the same layout, so the only difference between modes is where
// the accumulator is broken.
template <int TT, int MAP, bool FUSE, int G, int MODE>
__global__ __launch_bounds__(NW * 32) void k_proj(
        const uint8_t *__restrict__ Wa, const uint8_t *__restrict__ Wb,
        const void *__restrict__ B,
        const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const uint8_t *__restrict__ ma, const uint8_t *__restrict__ mb,
        const float *__restrict__ cscale, const float *__restrict__ signs,
        const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride, int rowoff) {
    constexpr int GG = (MODE == SHARED || MODE == ABSORB) ? G : 1;      // blocks per accumulator
    constexpr int GS = (MODE == PERBLOCK || MODE == ROWCTL) ? 1 : G;    // blocks per activation scale
    constexpr int WB = 512;
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    const uint8_t *abase = Wa + size_t(tile) * nb * WB;
    const uint8_t *bbase = Wb + size_t(tile) * nb * WB;
    const int nsw = nb / GG, ncs = nb / GS;
    for (int tg = tg0; tg < Npad; tg += tstride) {
        float ya[TT][8], yb[TT][8];
#pragma unroll
        for (int t = 0; t < TT; ++t)
#pragma unroll
            for (int r = 0; r < 8; ++r) { ya[t][r] = 0.f; yb[t][r] = 0.f; }
        for (int unit = 0; unit < nsw; ++unit) {
            int8v aa[TT], ab[TT];
#pragma unroll
            for (int t = 0; t < TT; ++t) { aa[t] = int8v{}; ab[t] = int8v{}; }
#pragma unroll 1
            for (int sub = 0; sub < GG; ++sub) {
                const int blk = unit * GG + sub;
                unsigned mA = 1, mB = 1;
                if constexpr (MODE == ABSORB) {
                    mA = ma[(size_t(tile) * nb + blk) * 16 + col];
                    mB = mb[(size_t(tile) * nb + blk) * 16 + col];
                }
#pragma unroll 1
                for (int s = 0; s < SLICES; ++s) {
                    unsigned wca = *(const unsigned *) (abase + size_t(blk) * WB + s * 64 + col * 4);
                    unsigned wcb = *(const unsigned *) (bbase + size_t(blk) * WB + s * 64 + col * 4);
                    if constexpr (MAP == 1) {
                        int2v wa = MODE == ABSORB ? expand_i4_m(wca, mA) : expand_i4(wca);
                        int2v wb = MODE == ABSORB ? expand_i4_m(wcb, mB) : expand_i4(wcb);
#pragma unroll
                        for (int t = 0; t < TT; ++t) {
                            int2v bf = ((const int2v *) B)[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                            aa[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wa, true, bf, aa[t], false);
                            ab[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, wb, true, bf, ab[t], false);
                        }
                    } else {
                        int4v wa = MODE == ABSORB ? (MAP == 3 ? expand_i8_palette(wca, mA) : expand_i8_m(wca, mA)) : expand_i8(wca);
                        int4v wb = MODE == ABSORB ? (MAP == 3 ? expand_i8_palette(wcb, mB) : expand_i8_m(wcb, mB)) : expand_i8(wcb);
#pragma unroll
                        for (int t = 0; t < TT; ++t) {
                            int4v bf = ((const int4v *) B)[size_t(blk * SLICES + s) * Npad + tg + t * 16 + col];
                            aa[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wa, true, bf, aa[t], false);
                            ab[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(true, wb, true, bf, ab[t], false);
                        }
                    }
                }
            }
            float asl, bsl;
            if constexpr (MODE == ROWCTL) {   // the layout the arithmetic maps shipped with
                const int row = tile * 16 + col;
                asl = h2f(sa[size_t(row) * nb + unit]); bsl = h2f(sb[size_t(row) * nb + unit]);
            } else {
                asl = h2f(sa[(size_t(tile) * nsw + unit) * 16 + col]);
                bsl = h2f(sb[(size_t(tile) * nsw + unit) * 16 + col]);
            }
            float asr[8], bsr[8];
#pragma unroll
            for (int r = 0; r < 8; ++r) { asr[r] = __shfl(asl, 2 * r + half, 32); bsr[r] = __shfl(bsl, 2 * r + half, 32); }
            const int cu = (unit * GG) / GS;
#pragma unroll
            for (int t = 0; t < TT; ++t) {
                float cs = cscale[size_t(tg + t * 16 + col) * ncs + cu];
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

// ------------------------------------------------------------------ offline scale fitting

// Finite relative-error search for scales L*m, m in [1,M]. The grid begins at
// max(lam)/M and tries 64 larger steps. This does not claim a globally optimal fit.
void fit_group(const float *lam, int G, int M, float &Lbest, uint8_t *mbest) {
    float mx = 0;
    for (int b = 0; b < G; ++b) mx = std::max(mx, lam[b]);
    if (!(mx > 0)) { Lbest = 0; for (int b = 0; b < G; ++b) mbest[b] = 1; return; }
    float best = 1e30f;
    Lbest = mx / M;
    for (int k = 0; k < 64; ++k) {
        float L = (mx / M) * (1.0f + 0.008f * k);
        float e = 0;
        for (int b = 0; b < G; ++b) {
            int m = std::min(M, std::max(1, (int) std::lround(lam[b] / L)));
            float d = lam[b] > 0 ? (L * m - lam[b]) / lam[b] : 0.0f;
            e += d * d;
        }
        if (e < best) { best = e; Lbest = L; }
    }
    for (int b = 0; b < G; ++b)
        mbest[b] = (uint8_t) std::min(M, std::max(1, (int) std::lround(lam[b] / Lbest)));
}

// One scale per group, no per-block correction: minimises the same relative criterion.
float fit_shared(const float *lam, int G) {
    double a = 0, b = 0;
    for (int i = 0; i < G; ++i) if (lam[i] > 0) { a += 1.0 / lam[i]; b += 1.0 / (double(lam[i]) * lam[i]); }
    return b > 0 ? float(a / b) : 0.0f;
}

uint16_t f2h(float v) { _Float16 h = (_Float16) v; uint16_t u; std::memcpy(&u, &h, 2); return u; }
float h2f_host(uint16_t u) { _Float16 h; std::memcpy(&h, &u, 2); return (float) h; }

struct FitStats { double rel_sq = 0; size_t n = 0; };

// Build the tile-major scale image (and multiplier image for ABSORB) a projection needs.
void build_scales(const std::vector<uint16_t> &lam16, int rows, int nb, int G, int mode, int M,
                  std::vector<uint16_t> &sout, std::vector<uint8_t> &mout, FitStats &st) {
    const int GG = (mode == SHARED || mode == ABSORB) ? G : 1;
    const int nsw = nb / GG, tiles = rows / 16;
    sout.assign(size_t(tiles) * nsw * 16, 0);
    if (mode == ABSORB) mout.assign(size_t(tiles) * nb * 16, 1);
    std::vector<float> lam(GG);
    for (int row = 0; row < rows; ++row) {
        const int tile = row / 16, col = row % 16;
        for (int unit = 0; unit < nsw; ++unit) {
            for (int b = 0; b < GG; ++b) lam[b] = h2f_host(lam16[size_t(row) * nb + unit * GG + b]);
            if (GG == 1) {
                sout[mode == ROWCTL ? size_t(row) * nb + unit : (size_t(tile) * nsw + unit) * 16 + col]
                    = lam16[size_t(row) * nb + unit];
                continue;
            }
            float L;
            if (mode == SHARED) {
                L = fit_shared(lam.data(), GG);
                sout[(size_t(tile) * nsw + unit) * 16 + col] = f2h(L);
                float Lr = h2f_host(f2h(L));
                for (int b = 0; b < GG; ++b) if (lam[b] > 0) {
                    double d = (Lr - lam[b]) / lam[b]; st.rel_sq += d * d; ++st.n;
                }
            } else {
                std::vector<uint8_t> m(GG);
                fit_group(lam.data(), GG, M, L, m.data());
                sout[(size_t(tile) * nsw + unit) * 16 + col] = f2h(L);
                float Lr = h2f_host(f2h(L));
                for (int b = 0; b < GG; ++b) {
                    mout[(size_t(tile) * nb + unit * GG + b) * 16 + col] = m[b];
                    if (lam[b] > 0) { double d = (Lr * m[b] - lam[b]) / lam[b]; st.rel_sq += d * d; ++st.n; }
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
    uint8_t *mg = nullptr, *mu = nullptr, *md_a = nullptr, *md_b = nullptr;
    void *Bin = nullptr, *Bhid = nullptr;
    float *csin = nullptr, *cshid = nullptr, *hidden = nullptr, *transformed = nullptr;
    const float *norm = nullptr, *signs = nullptr;
    size_t bytes = 0;
    double scale_rel_rms = 0;
};

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

template <class T> void upload(T *&dst, const std::vector<T> &src, size_t &total) {
    check(hipMalloc(&dst, src.size() * sizeof(T)), "malloc");
    check(hipMemcpy(dst, src.data(), src.size() * sizeof(T), hipMemcpyHostToDevice), "upload");
    total += src.size() * sizeof(T);
}

template<bool WIDE>
std::vector<uint8_t> pack_carrier(const int8_t *weights, int rows, int columns) {
    auto packed = pack_two_bit(weights, rows, columns);
    if constexpr (WIDE) {
        for (size_t block = 0; block < packed.size(); block += 512) {
            uint8_t buffer[512];
            std::memcpy(buffer, packed.data() + block, 512);
            for (int row = 0; row < 16; ++row)
                for (int slice = 0; slice < 8; ++slice)
                    std::memcpy(packed.data() + block + row * 32 + slice * 4,
                                buffer + slice * 64 + row * 4, 4);
        }
    }
    return packed;
}

template <int MAP, int G, int MODE, int CLIP, bool WIDE = false>
void *prepare(const kelana_batch::Weights &w, int maxrows) {
    auto *p = new Plan{};
    p->D = w.width; p->FF = w.hidden; p->maxrows = maxrows;
    p->norm = w.norm_device; p->signs = w.signs_device;
    std::vector<int8_t> g, u, d;
    std::vector<uint16_t> gs, us, ds;
    decode_matrix(w.gate_host, p->FF, p->D, g, gs);
    decode_matrix(w.up_host, p->FF, p->D, u, us);
    decode_matrix(w.down_host, p->D, p->FF, d, ds);
    const int Dh = p->D / 2, nbd = p->FF / KB, nbg = p->D / KB, M = Traits<MAP>::mmax;
    std::vector<int8_t> d0(d.begin(), d.begin() + size_t(Dh) * p->FF), d1(d.begin() + size_t(Dh) * p->FF, d.end());
    std::vector<uint16_t> ds0(ds.begin(), ds.begin() + size_t(Dh) * nbd), ds1(ds.begin() + size_t(Dh) * nbd, ds.end());
    upload(p->wgu_a, pack_carrier<WIDE>(g.data(), p->FF, p->D), p->bytes);
    upload(p->wgu_b, pack_carrier<WIDE>(u.data(), p->FF, p->D), p->bytes);
    upload(p->wd_a, pack_carrier<WIDE>(d0.data(), Dh, p->FF), p->bytes);
    upload(p->wd_b, pack_carrier<WIDE>(d1.data(), Dh, p->FF), p->bytes);
    FitStats st;
    std::vector<uint16_t> sg, su, sd0, sd1;
    std::vector<uint8_t> mg, mu, md0, md1;
    build_scales(gs, p->FF, nbg, G ? G : nbg, MODE, M, sg, mg, st);
    build_scales(us, p->FF, nbg, G ? G : nbg, MODE, M, su, mu, st);
    build_scales(ds0, Dh, nbd, G ? G : nbd, MODE, M, sd0, md0, st);
    build_scales(ds1, Dh, nbd, G ? G : nbd, MODE, M, sd1, md1, st);
    p->scale_rel_rms = st.n ? std::sqrt(st.rel_sq / st.n) : 0.0;
    upload(p->sg, sg, p->bytes); upload(p->su, su, p->bytes);
    upload(p->sd_a, sd0, p->bytes); upload(p->sd_b, sd1, p->bytes);
    if constexpr (MODE == ABSORB) {
        upload(p->mg, mg, p->bytes); upload(p->mu, mu, p->bytes);
        upload(p->md_a, md0, p->bytes); upload(p->md_b, md1, p->bytes);
    }
    if (st.n)
        std::fprintf(stderr, "gs: map%d G%d mode%d weight-scale rel rms %.4f%%\n",
                     MAP, G, MODE, 100.0 * p->scale_rel_rms);
    const int Npad = (maxrows + 15) / 16 * 16;
    const int GS = (MODE == PERBLOCK || MODE == ROWCTL) ? 1 : G;
    size_t bin = size_t(p->D / 16) * Npad * Traits<MAP>::frag;
    size_t bhid = size_t(p->FF / 16) * Npad * Traits<MAP>::frag;
    check(hipMalloc(&p->Bin, bin), "Bin");
    check(hipMalloc(&p->Bhid, bhid), "Bhid");
    check(hipMemset(p->Bin, 0, bin), "Bin zero");
    check(hipMemset(p->Bhid, 0, bhid), "Bhid zero");
    size_t cin = size_t(Npad) * (GS ? p->D / (KB * GS) : 1) * 4;
    size_t chid = size_t(Npad) * (GS ? p->FF / (KB * GS) : 1) * 4;
    if constexpr (G == 0) {
        size_t scratch = size_t(Npad) * std::max(p->D, p->FF) * sizeof(float);
        check(hipMalloc(&p->transformed, scratch), "transformed");
        p->bytes += scratch;
    }
    check(hipMalloc(&p->csin, cin), "csin");
    check(hipMalloc(&p->cshid, chid), "cshid");
    check(hipMemset(p->csin, 0, cin), "csin zero");
    check(hipMemset(p->cshid, 0, chid), "cshid zero");
    check(hipMalloc(&p->hidden, size_t(Npad) * p->FF * 4), "hidden");
    p->bytes += bin + bhid + cin + chid + size_t(Npad) * p->FF * 4;
    return p;
}

void release(void *state) {
    auto *p = static_cast<Plan *>(state);
    for (void *q : {(void *) p->wgu_a, (void *) p->wgu_b, (void *) p->wd_a, (void *) p->wd_b,
                    (void *) p->sg, (void *) p->su, (void *) p->sd_a, (void *) p->sd_b,
                    (void *) p->mg, (void *) p->mu, (void *) p->md_a, (void *) p->md_b,
                    p->Bin, p->Bhid, (void *) p->csin, (void *) p->cshid, (void *) p->hidden, (void *) p->transformed})
        if (q) hipFree(q);
    delete p;
}
size_t resident_bytes(void *state) { return static_cast<Plan *>(state)->bytes; }

struct Stages {
    bool on = getenv("KELANA_GS_STAGES") != nullptr;
    hipEvent_t ev[5]{};
    const char *name[4] = {"prep_in", "gate_up_silu", "prep_hidden", "down_residual"};
    int at = 0;
    void mark(hipStream_t s) { if (!on) return; if (!ev[at]) hipEventCreate(&ev[at]); hipEventRecord(ev[at], s); ++at; }
    void report(const char *who, int rows) {
        if (!on) return;
        hipEventSynchronize(ev[4]);
        std::fprintf(stderr, "%-20s rows %-4d", who, rows);
        for (int i = 0; i < 4; ++i) { float t = 0; hipEventElapsedTime(&t, ev[i], ev[i + 1]);
            std::fprintf(stderr, "  %s %6.3f ms", name[i], t); }
        std::fprintf(stderr, "\n");
        at = 0;
    }
};

int group_split(int tiles, int groups) {
    int want = 320 / (tiles > 0 ? tiles : 1);
    return std::max(1, std::min(groups, want));
}

#include "../../scale-carrier/global.hpp"

template <int MAP, int G, int MODE, int CLIP>
void run(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    static Stages st;
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    constexpr int GA = (MODE == PERBLOCK || MODE == ROWCTL) ? 1 : G;
    st.mark(stream);
    k_prep<MAP, true, true, GA, CLIP><<<rows * (D / 1024), NT, 0, stream>>>(input, p->norm, p->Bin, p->csin, D, rows, Npad);
    st.mark(stream);
#define PROJ(TT, FUSE, WA, WB_, BFRAG, SA, SB, MA, MB, CS, SIGNS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF) \
    k_proj<TT, MAP, FUSE, G, MODE><<<dim3((TILES) / NW, group_split((TILES) / NW, Npad / (TT * 16))), \
        NW * 32, 0, stream>>>(WA, WB_, BFRAG, SA, SB, MA, MB, CS, SIGNS, RESID, OUT, NB, rows, Npad, OSTRIDE, ROWOFF)
    if (Npad % 64 == 0) {
        PROJ(4, true, p->wgu_a, p->wgu_b, p->Bin, p->sg, p->su, p->mg, p->mu, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    } else if (Npad % 32 == 0) {
        PROJ(2, true, p->wgu_a, p->wgu_b, p->Bin, p->sg, p->su, p->mg, p->mu, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    } else {
        PROJ(1, true, p->wgu_a, p->wgu_b, p->Bin, p->sg, p->su, p->mg, p->mu, p->csin, p->signs, nullptr, p->hidden, D / KB, FF / 16, FF, 0);
    }
    st.mark(stream);
    k_prep<MAP, false, false, GA, CLIP><<<rows * (FF / 1024), NT, 0, stream>>>(p->hidden, nullptr, p->Bhid, p->cshid, FF, rows, Npad);
    st.mark(stream);
    if (Npad % 64 == 0) {
        PROJ(4, false, p->wd_a, p->wd_b, p->Bhid, p->sd_a, p->sd_b, p->md_a, p->md_b, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    } else if (Npad % 32 == 0) {
        PROJ(2, false, p->wd_a, p->wd_b, p->Bhid, p->sd_a, p->sd_b, p->md_a, p->md_b, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    } else {
        PROJ(1, false, p->wd_a, p->wd_b, p->Bhid, p->sd_a, p->sd_b, p->md_a, p->md_b, p->cshid, nullptr, input, output, FF / KB, Dh / 16, D, Dh);
    }
#undef PROJ
    st.mark(stream);
    st.report("gs", rows);
}

template <int MAP, int G, int MODE, int CLIP = 1000>
kelana_batch::Candidate make(const char *name, const char *desc) {
    return {name, kelana_batch::Claim::approximate, desc,
            prepare<MAP, G, MODE, CLIP>, run<MAP, G, MODE, CLIP>, release, resident_bytes};
}

kelana_batch::Candidate c_ctl4()   { return make<1, 1, PERBLOCK>("gs-control-iu4-a4",
    "control: IU4, four-bit activations, deployed per-128 scales, tile-major scale layout"); }
kelana_batch::Candidate c_act8()   { return make<1, 8, ACTONLY>("gs-act1024-iu4-a4",
    "one activation amax per (token, 1024), per-128 weight scales, epilogue still per 128"); }
kelana_batch::Candidate c_sh8()    { return make<1, 8, SHARED>("gs-shared1024-iu4-a4",
    "scale-sharing ablation: one fitted scale per 1024 on both sides, no per-128 correction"); }
kelana_batch::Candidate c_abs8()   { return make<1, 8, ABSORB>("gs-absorb1024-iu4-a4",
    "joint scale per 1024 plus an int4 multiplier per 128-block folded into the matrix operand"); }
kelana_batch::Candidate c_abs4()   { return make<1, 4, ABSORB>("gs-absorb512-iu4-a4",
    "joint scale per 512 plus an int4 multiplier per 128-block folded into the matrix operand"); }
kelana_batch::Candidate c_abs2()   { return make<1, 2, ABSORB>("gs-absorb256-iu4-a4",
    "joint scale per 256 plus an int4 multiplier per 128-block folded into the matrix operand"); }
kelana_batch::Candidate c_ctl8()   { return make<2, 1, PERBLOCK>("gs-control-iu8-a8",
    "control: IU8, eight-bit activations, deployed per-128 scales, tile-major scale layout"); }
kelana_batch::Candidate c_abs8i8() { return make<2, 8, ABSORB>("gs-absorb1024-iu8-a8",
    "joint scale per 1024 plus an int8 multiplier per 128-block, where the operand has resolution"); }

// Same maps with a shortened quantiser step. Identical instruction counts, so these move error
// only; the control is here at its own best step so the comparison is like for like.
kelana_batch::Candidate c_ctl4c()  { return make<1, 1, PERBLOCK, 875>("gs-control-iu4-a4-clip875",
    "control with the per-128 quantiser step at 0.875 * amax/7"); }
kelana_batch::Candidate c_abs8c8() { return make<1, 8, ABSORB, 875>("gs-absorb1024-iu4-a4-clip875",
    "joint scale per 1024, int4 multiplier per 128-block, quantiser step at 0.875 * amax/7"); }
kelana_batch::Candidate c_abs8c0() { return make<1, 8, ABSORB, 800>("gs-absorb1024-iu4-a4-clip800",
    "joint scale per 1024, int4 multiplier per 128-block, quantiser step at 0.800 * amax/7"); }
kelana_batch::Candidate c_abs8c7() { return make<1, 8, ABSORB, 750>("gs-absorb1024-iu4-a4-clip750",
    "joint scale per 1024, int4 multiplier per 128-block, quantiser step at 0.750 * amax/7"); }
kelana_batch::Candidate c_abs8c6() { return make<1, 8, ABSORB, 700>("gs-absorb1024-iu4-a4-clip700",
    "joint scale per 1024, int4 multiplier per 128-block, quantiser step at 0.700 * amax/7"); }
kelana_batch::Candidate c_ctl4r()  { return make<1, 1, ROWCTL>("gs-control-iu4-a4-rowscales",
    "the control with scales indexed [row][block] instead of [tile][block][16], everything else equal"); }
kelana_batch::Candidate c_abs2c8() { return make<1, 2, ABSORB, 875>("gs-absorb256-iu4-a4-clip875",
    "joint scale per 256, int4 multiplier per 128-block, quantiser step at 0.875 * amax/7"); }
}
kelana_batch::Candidate c_palette8() { return make<3, 8, ABSORB>("gs-palette1024-iu8-a8",
    "same fitted scale carrier as gs-absorb1024-iu8-a8; direct code-to-scaled-byte palette"); }
kelana_batch::Candidate c_palette4() { return make<3, 4, ABSORB>("gs-palette512-iu8-a8",
    "four-block scale carrier with direct code-to-scaled-byte palette"); }
kelana_batch::Candidate c_palette2() { return make<3, 2, ABSORB>("gs-palette256-iu8-a8",
    "two-block scale carrier with direct code-to-scaled-byte palette"); }
kelana_batch::Candidate c_global4() {
    return {"gs-global-iu8-a8-tt4", kelana_batch::Claim::approximate,
        "one fitted weight scale per row; whole-row direct A8; one int32 carrier through whole K, TT4",
        prepare<3,0,ABSORB,1000>, run_global<4>, release, resident_bytes};
}
kelana_batch::Candidate c_global8() {
    return {"gs-global-iu8-a8-tt8", kelana_batch::Claim::approximate,
        "one fitted weight scale per row; whole-row direct A8; one int32 carrier through whole K, TT8",
        prepare<3,0,ABSORB,1000>, run_global<8>, release, resident_bytes};
}
kelana_batch::Candidate c_global8u2() {
    return {"gs-global-iu8-a8-tt8-u2", kelana_batch::Claim::approximate,
        "whole-K integer carrier TT8, slice loop unrolled twice",
        prepare<3,0,ABSORB,1000>, run_global<8,2>, release, resident_bytes};
}
kelana_batch::Candidate c_global_wide() {
    return {"gs-global-wide-iu8-a8", kelana_batch::Claim::approximate,
        "whole-K integer carrier TT8 with lane-contiguous uint4 block loads",
        prepare<3,0,ABSORB,1000,true>, run_global<8,1,true>, release, resident_bytes};
}
kelana_batch::Candidate c_global_wide4() {
    return {"gs-global-wide-iu8-a8-tt4", kelana_batch::Claim::approximate,
        "whole-K integer carrier TT4 with lane-contiguous uint4 block loads",
        prepare<3,0,ABSORB,1000,true>, run_global<4,1,true>, release, resident_bytes};
}
KELANA_BATCH_REGISTER(c_global_wide4)
KELANA_BATCH_REGISTER(c_global_wide)
KELANA_BATCH_REGISTER(c_global8u2)
KELANA_BATCH_REGISTER(c_global4)
KELANA_BATCH_REGISTER(c_global8)
KELANA_BATCH_REGISTER(c_palette8)
KELANA_BATCH_REGISTER(c_palette4)
KELANA_BATCH_REGISTER(c_palette2)
KELANA_BATCH_REGISTER(c_ctl4)
KELANA_BATCH_REGISTER(c_act8)
KELANA_BATCH_REGISTER(c_sh8)
KELANA_BATCH_REGISTER(c_abs8)
KELANA_BATCH_REGISTER(c_abs4)
KELANA_BATCH_REGISTER(c_abs2)
KELANA_BATCH_REGISTER(c_ctl8)
KELANA_BATCH_REGISTER(c_abs8i8)
KELANA_BATCH_REGISTER(c_ctl4c)
KELANA_BATCH_REGISTER(c_abs8c8)
KELANA_BATCH_REGISTER(c_abs8c0)
KELANA_BATCH_REGISTER(c_abs8c7)
KELANA_BATCH_REGISTER(c_abs8c6)
KELANA_BATCH_REGISTER(c_abs2c8)
KELANA_BATCH_REGISTER(c_ctl4r)
