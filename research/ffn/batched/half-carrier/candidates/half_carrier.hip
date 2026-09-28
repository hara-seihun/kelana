// Half-carrier accumulators for the batched ternary FFN.
//
// Hypothesis under test: the whole-FFN cost of the arithmetic family is partly set by how many
// VGPRs the *persistent* block accumulators take. `arithmetic/candidates/arith_maps.hip` keeps
// `float ya[TT][8]` and `float yb[TT][8]` live across all 40 (gate/up) or 136 (down) scale blocks,
// which is 2*TT*8 registers of a 256-register budget, and that is what stops the projection at
// four token tiles per wave. Four token tiles means a wave re-reads its weight slice
// ceil(Npad/64) times.
//
// Change the representation, not the algebra: carry the block accumulation as one packed FP16 pair
// per two outputs, using the native packed half ALU (v_pk_fma_f16). Persistent accumulator state
// halves, the per-block epilogue loses instructions, and eight token tiles per wave becomes
// reachable, which halves the weight stream at 128 and 256 rows. The ternary weights stay exact and
// the activation quantiser is byte-for-byte the arithmetic directory's.
//
// Pairing choice, after main's note: pack adjacent output rows of the *same* channel,
// h_g = (g_r, g_{r+1}) and h_u = (u_r, u_{r+1}), rather than (g_r, u_r) of one hidden unit. Both
// cost the identical instruction count while accumulating (see README); only the consumer differs,
// and the row pairing lets every consumer stage apply the same map to both lanes with no lane
// masking. `hc-unitpair-a4` is built anyway so the claim is measured, not asserted.
//
// Range. FP16 has no exponent room to spare, so each output row's FP16 block scales are multiplied
// by one power of two chosen at preparation, and the reciprocal power of two is applied at the
// final boundary. Powers of two are exact in both directions, so this introduces no error of its
// own; it only moves the accumulation into the part of the FP16 range where it has full precision.
// The width-FF Hadamard sign vector is folded into the up row scale at preparation, which is a sign
// flip, also exact.
//
// Approximations, kept separable by candidate:
//   * four-bit activation quantiser  - identical to arith-iu4-a4, present in every candidate here
//     including the control, so the control's output hash must equal arith-iu4-a4's.
//   * FP16 block accumulation        - hc-*pair-a4* against hc-control-iu4-a4.
//   * FP16 accumulation at the down projection only - hc-rowpair-a4-fp32down isolates it.
//   * packed-half polynomial SiLU    - hc-rowpair-a4-poly against hc-rowpair-a4.
#include "../../api.hpp"
#include "../../arithmetic/maps.hpp"
#include "halo_format.h"
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cstring>
#include <vector>
#include <algorithm>

using namespace kelana_arith;

namespace {

constexpr int NT = 256;            // prep threads per 1024-element chunk
constexpr int NW = 4;              // waves per projection workgroup
constexpr float NORM_EPS = 1e-5f;
// Row normalisation target: 2^e * max_block_scale lands in [2^-(SHIFT+1), 2^-SHIFT). With at most
// 896 per block-accumulator and 136 blocks at the down projection, the worst reachable partial sum
// is 896 * 2^-5 * 136 * max_token_scale, which keeps FP16's 65504 ceiling far away while leaving
// the small terms well above the 6.1e-5 normal boundary.
constexpr int SCALE_SHIFT = 5;

using half2v = _Float16 __attribute__((ext_vector_type(2)));

// Main's fixed-interval fits on [-3.5, 3.5], already rounded to binary16 and checked under
// half-rounded FMA evaluation: exact odd part g/2, zero at zero, even remainder a polynomial in
// z = g*g. Degree 6 reaches 0.0068897 maximum absolute SiLU error over all bounded binary16 g,
// degree 8 reaches 0.0030232 for one more packed FMA. Outside the radius the exact function is
// evaluated; the polynomial is never extrapolated.
constexpr float SILU6[3] = {0.2388916015625f, -0.0135345458984375f, 0.00041222572326660156f};
constexpr float SILU8[4] = {0.246826171875f, -0.0176849365234375f, 0.0010166168212890625f,
                            -0.000026285648345947266f};
constexpr float SILU_TAIL = 3.5f;

void check(hipError_t e, const char *what) {
    if (e != hipSuccess) { std::fprintf(stderr, "half-carrier: %s: %s\n", what, hipGetErrorString(e)); std::abort(); }
}

__device__ __forceinline__ float h2f(unsigned bits) {
    unsigned short u = (unsigned short) bits; _Float16 h;
    __builtin_memcpy(&h, &u, 2); return (float) h;
}
__device__ __forceinline__ float silu(float x) { return x / (1.0f + __expf(-x)); }
// v_cvt_pkrtz_f16_f32 packs two FP32 values into one register in one instruction.
//
// `pk` is applied only to WMMA accumulator values: a 128-element block of four-bit activations
// against ternary weights reaches at most 889, binary16 represents every integer to 2048, so
// round-toward-zero never rounds there.
//
// `splat` is a different matter. It converts a per-(token, 128-block) activation scale, which is an
// arbitrary FP32 value, and round-toward-zero truncates it: the half scale is never larger in
// magnitude than the float one, up to 2^-11 relative per block. That is a systematic downward bias
// belonging to the half carrier, not to the quantiser, and it is separate from the rounding of the
// accumulation itself. `splat_rne` is the alternative, at one more VALU instruction per token tile
// per block; `hc-rowpair-a4-tt8-down1-rne` measures what the difference is worth.
__device__ __forceinline__ half2v pk(float a, float b) {
    return __builtin_bit_cast(half2v, __builtin_amdgcn_cvt_pkrtz(a, b));
}
__device__ __forceinline__ half2v splat(float v) { return pk(v, v); }
__device__ __forceinline__ half2v splat_rne(float v) { _Float16 h = (_Float16) v; return half2v{h, h}; }
template <bool RNE> __device__ __forceinline__ half2v splat_cs(float v) {
    if constexpr (RNE) return splat_rne(v); else return splat(v);
}

// Packed SiLU on two lanes at once: five (degree 6) or six (degree 8) packed instructions, no lane
// selection and no reconstruction of a scalar gate value. The tail branch is per lane, and a wave
// whose lanes all stay inside the radius skips it on the exec mask.
template <int DEG>
__device__ __forceinline__ half2v poly_silu(half2v g) {
    half2v z = g * g, v;
    if constexpr (DEG == 8) {
        v = splat(SILU8[3]) * z + splat(SILU8[2]);
        v = v * z + splat(SILU8[1]);
        v = v * z + splat(SILU8[0]);
    } else {
        v = splat(SILU6[2]) * z + splat(SILU6[1]);
        v = v * z + splat(SILU6[0]);
    }
    half2v r = z * v + g * splat(0.5f);
    float g0 = (float) g[0], g1 = (float) g[1];
    if (__builtin_expect(fabsf(g0) > SILU_TAIL, 0)) r[0] = (_Float16) silu(g0);
    if (__builtin_expect(fabsf(g1) > SILU_TAIL, 0)) r[1] = (_Float16) silu(g1);
    return r;
}

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
//
// Transcribed from arithmetic/candidates/arith_maps.hip `k_prep` with MAP == 1 (four-bit, packed
// int4 nibble fragments) and nothing else changed: same RMS norm, same folded sign vector, same
// 1024-point Hadamard order, same deterministic symmetric quantiser at amax/7 with
// round-to-nearest-even and a [-7,7] clamp, same fragment layout. `hc-control-iu4-a4` exists to
// prove that transcription by output hash rather than by inspection.
template <bool NORM, bool HAS_SIGN>
__global__ __launch_bounds__(NT) void k_prep4(const float *__restrict__ x, const float *__restrict__ kvec,
        void *__restrict__ Bout, float *__restrict__ cscale, int n, int Npad) {
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
    constexpr float L = 7.0f;
    float iscale = amax > 0.0f ? L / amax : 0.0f;
    int q[4] = {__float2int_rn(v.x * iscale), __float2int_rn(v.y * iscale),
                __float2int_rn(v.z * iscale), __float2int_rn(v.w * iscale)};
#pragma unroll
    for (int j = 0; j < 4; ++j) q[j] = max(-int(L), min(int(L), q[j]));
    const int kslice = base >> 4, slot = base & 15;
    uint8_t *dst = (uint8_t *) Bout + (size_t(kslice) * Npad + row) * 8 + slot / 2;
    dst[0] = uint8_t((q[0] & 0xf) | ((q[1] & 0xf) << 4));
    dst[1] = uint8_t((q[2] & 0xf) | ((q[3] & 0xf) << 4));
    if (lane == 0) cscale[(size_t) row * (n / KB) + (base >> 7)] = amax / L;
}

// ------------------------------------------------------------------ projection
//
// A wave owns 16 physical rows of matrix A and 16 of matrix B (gate/up, or the two halves of the
// down matrix) and TT token tiles. ACC selects the carrier:
//
//   ACC 0  float ya[TT][8], yb[TT][8]        - matched control, the arithmetic directory's algebra
//   ACC 1  half2 hga[TT][4], hgb[TT][4]      - row-paired half carrier, (r, r+1) of one channel
//   ACC 2  half2 h[TT][8]                    - unit-paired half carrier, (gate_r, up_r) of one row
//
// SPLIT walks the whole K-block range once per matrix and parks the first matrix's carrier in LDS,
// so neither the persistent carrier nor the WMMA accumulator set is doubled. That is what makes
// eight token tiles per wave fit, and eight token tiles halve the weight stream at 128 and 256
// rows. Parking is affordable precisely because the carrier is packed: 128 bytes per lane instead
// of the 256 an FP32 pair of arrays would need.
//
// One matrix, TT token tiles, all K blocks, accumulating into one packed carrier.
template <int TT, bool CSRNE>
__device__ __forceinline__ void accumulate_matrix(
        const uint8_t *__restrict__ wbase, const half2v *__restrict__ sbase,
        const void *__restrict__ B, const float *__restrict__ cscale,
        int nb, int Npad, int tile, int col, int hlf, int tg, half2v (&h)[TT][4]) {
    constexpr int WB = 512;
#pragma unroll
    for (int t = 0; t < TT; ++t)
#pragma unroll
        for (int j = 0; j < 4; ++j) h[t][j] = splat(0.f);
    for (int blk = 0; blk < nb; ++blk) {
        const half2v *sp = sbase + (size_t(tile) * nb + blk) * 8 + hlf * 4;
        half2v s[4];
#pragma unroll
        for (int j = 0; j < 4; ++j) s[j] = sp[j];
        int8v acc[TT];
#pragma unroll
        for (int t = 0; t < TT; ++t) acc[t] = int8v{};
#pragma unroll 1
        for (int sl = 0; sl < SLICES; ++sl) {
            int2v w = expand_i4(*(const unsigned *) (wbase + size_t(blk) * WB + sl * 64 + col * 4));
#pragma unroll
            for (int t = 0; t < TT; ++t)
                acc[t] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, w, true,
                    ((const int2v *) B)[size_t(blk * SLICES + sl) * Npad + tg + t * 16 + col], acc[t], false);
        }
        // Keep the drain's scale loads out of the WMMA loop, where they would be live alongside
        // every accumulator.
        __builtin_amdgcn_sched_barrier(0);
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            half2v csh = splat_cs<CSRNE>(cscale[size_t(tg + t * 16 + col) * nb + blk]);
#pragma unroll
            for (int j = 0; j < 4; ++j)
                h[t][j] += pk(float(acc[t][2 * j]), float(acc[t][2 * j + 1])) * (s[j] * csh);
        }
    }
}

template <int TT, int ACC, int CONS, bool FUSE, bool SPLIT, bool CSRNE = false>
__global__ __launch_bounds__(NW * 32) void k_proj(
        const uint8_t *__restrict__ Wa, const uint8_t *__restrict__ Wb,
        const void *__restrict__ B,
        const uint16_t *__restrict__ sa, const uint16_t *__restrict__ sb,
        const half2v *__restrict__ pa, const half2v *__restrict__ pb,
        const half2v *__restrict__ ga, const half2v *__restrict__ gb,
        const float *__restrict__ gaf, const float *__restrict__ gbf,
        const float *__restrict__ cscale, const float *__restrict__ signs,
        const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride, int rowoff) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    constexpr int WB = 512;                       // two-bit ternary storage, 16 rows x 128 K
    const uint8_t *abase = Wa + size_t(tile) * nb * WB;
    const uint8_t *bbase = Wb + size_t(tile) * nb * WB;
    // Lane-private parking for the first matrix's carrier under SPLIT. Indexed so that consecutive
    // lanes hold consecutive dwords; only the owning lane reads what it wrote, so there is no
    // barrier and no sharing.
    constexpr bool STAGE = (ACC == 1 && SPLIT);
    constexpr int LDSN = STAGE ? TT * 4 * NW * 32 : 1;
    __shared__ half2v park[LDSN];
    const int slot = wave * 32 + lane;

    for (int tg = tg0; tg < Npad; tg += tstride) {
        float ya[TT][8], yb[TT][8];               // ACC 0 only
        half2v hga[TT][4], hgb[TT][4];            // ACC 1 only
        half2v hu[TT][8];                         // ACC 2 only
        if constexpr (STAGE) {
            accumulate_matrix<TT, CSRNE>(abase, pa, B, cscale, nb, Npad, tile, col, half, tg, hga);
#pragma unroll
            for (int t = 0; t < TT; ++t)
#pragma unroll
                for (int j = 0; j < 4; ++j) park[(t * 4 + j) * NW * 32 + slot] = hga[t][j];
            accumulate_matrix<TT, CSRNE>(bbase, pb, B, cscale, nb, Npad, tile, col, half, tg, hgb);
        } else if constexpr (ACC == 0) {
#pragma unroll
            for (int t = 0; t < TT; ++t)
#pragma unroll
                for (int r = 0; r < 8; ++r) { ya[t][r] = 0.f; yb[t][r] = 0.f; }
        } else if constexpr (ACC == 1) {
#pragma unroll
            for (int t = 0; t < TT; ++t)
#pragma unroll
                for (int j = 0; j < 4; ++j) { hga[t][j] = splat(0.f); hgb[t][j] = splat(0.f); }
        } else {
#pragma unroll
            for (int t = 0; t < TT; ++t)
#pragma unroll
                for (int r = 0; r < 8; ++r) hu[t][r] = splat(0.f);
        }

        for (int blk = 0; STAGE ? false : blk < nb; ++blk) {
            if constexpr (ACC == 0) {
                // Matched control: the arithmetic directory's FP32 carrier and shuffled scales.
                float asl = h2f(sa[(size_t(tile) * nb + blk) * 16 + col]);
                float bsl = h2f(sb[(size_t(tile) * nb + blk) * 16 + col]);
                float asr[8], bsr[8];
#pragma unroll
                for (int r = 0; r < 8; ++r) { asr[r] = __shfl(asl, 2 * r + half, 32); bsr[r] = __shfl(bsl, 2 * r + half, 32); }
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
            } else if constexpr (ACC == 1) {
                // Row-paired half carrier. The scale pairs come out of memory already in the lane's
                // order, so the 16 cross-lane scale broadcasts per block disappear as well.
                const half2v *sgp = pa + (size_t(tile) * nb + blk) * 8 + half * 4;
                const half2v *sup = pb + (size_t(tile) * nb + blk) * 8 + half * 4;
                half2v sg[4], su[4];
#pragma unroll
                for (int j = 0; j < 4; ++j) { sg[j] = sgp[j]; su[j] = sup[j]; }
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
                        half2v csh = splat_cs<CSRNE>(cscale[size_t(tg + t * 16 + col) * nb + blk]);
#pragma unroll
                        for (int j = 0; j < 4; ++j) {
                            hga[t][j] += pk(float(aa[t][2 * j]), float(aa[t][2 * j + 1])) * (sg[j] * csh);
                            hgb[t][j] += pk(float(ab[t][2 * j]), float(ab[t][2 * j + 1])) * (su[j] * csh);
                        }
                    }
            } else {
                // Unit-paired half carrier: one register holds the gate and up value of one row.
                const half2v *sp = pa + (size_t(tile) * nb + blk) * 16 + half * 8;
                half2v sgu[8];
#pragma unroll
                for (int r = 0; r < 8; ++r) sgu[r] = sp[r];
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
                    half2v csh = splat_cs<CSRNE>(cscale[size_t(tg + t * 16 + col) * nb + blk]);
#pragma unroll
                    for (int r = 0; r < 8; ++r)
                        hu[t][r] += pk(float(aa[t][r]), float(ab[t][r])) * (sgu[r] * csh);
                }
            }
        }

        // ------------------------------------------------------------ consumer boundary
        //
        // The per-row gains and the folded sign are loaded here rather than hoisted above the block
        // loop: holding them live across 40 blocks costs more than reloading them once per token
        // group, and at eight token tiles that difference is the difference between fitting and
        // spilling.
        float gafl[8], gbfl[8];
        half2v gah[4], gbh[4], gph[8];
        if constexpr (ACC == 1) {
#pragma unroll
            for (int j = 0; j < 4; ++j) { gah[j] = ga[tile * 8 + half * 4 + j]; gbh[j] = gb[tile * 8 + half * 4 + j]; }
            if constexpr (!FUSE) {
#pragma unroll
                for (int r = 0; r < 8; ++r) { gafl[r] = gaf[tile * 16 + 2 * r + half]; gbfl[r] = gbf[tile * 16 + 2 * r + half]; }
            }
        } else if constexpr (ACC == 2) {
#pragma unroll
            for (int r = 0; r < 8; ++r) gph[r] = ga[tile * 16 + half * 8 + r];
        }
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            int token = tg + t * 16 + col;
            if (token >= rows) continue;
            if constexpr (ACC == 1) {
#pragma unroll
                for (int j = 0; j < 4; ++j) {
                    int row0 = tile * 16 + 4 * j + half, row1 = row0 + 2;
                    size_t o0 = size_t(token) * outstride + row0, o1 = size_t(token) * outstride + row1;
                    half2v acc_g = STAGE ? park[(t * 4 + j) * NW * 32 + slot] : hga[t][j];
                    if constexpr (FUSE) {
                        // The row gain and the folded Hadamard sign are exact powers of two times a
                        // sign, so this stays inside the packed half domain.
                        half2v g = acc_g * gah[j], u = hgb[t][j] * gbh[j];
                        if constexpr (CONS != 0) {
                            half2v r = poly_silu<CONS>(g) * u;
                            out[o0] = (float) r[0]; out[o1] = (float) r[1];
                        } else {
                            out[o0] = silu((float) g[0]) * (float) u[0];
                            out[o1] = silu((float) g[1]) * (float) u[1];
                        }
                    } else {
                        out[o0] = resid[o0] + (float) acc_g[0] * gafl[2 * j];
                        out[o1] = resid[o1] + (float) acc_g[1] * gafl[2 * j + 1];
                        out[o0 + rowoff] = resid[o0 + rowoff] + (float) hgb[t][j][0] * gbfl[2 * j];
                        out[o1 + rowoff] = resid[o1 + rowoff] + (float) hgb[t][j][1] * gbfl[2 * j + 1];
                    }
                }
            } else if constexpr (ACC == 2) {
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    int row = tile * 16 + 2 * r + half;
                    size_t o = size_t(token) * outstride + row;
                    half2v v = hu[t][r] * gph[r];
                    if constexpr (FUSE) out[o] = silu((float) v[0]) * (float) v[1];
                    else { out[o] = resid[o] + (float) v[0]; out[o + rowoff] = resid[o + rowoff] + (float) v[1]; }
                }
            } else {
#pragma unroll
                for (int r = 0; r < 8; ++r) {
                    int row = tile * 16 + 2 * r + half;
                    size_t o = size_t(token) * outstride + row;
                    if constexpr (FUSE) out[o] = silu(ya[t][r]) * yb[t][r] * signs[row];
                    else { out[o] = resid[o] + ya[t][r]; out[o + rowoff] = resid[o + rowoff] + yb[t][r]; }
                }
            }
        }
    }
}

// The down projection has no natural second matrix. The arithmetic candidate splits it into rows
// [0, D/2) and [D/2, D) so one wave can carry 32 logical rows, which the paired FP16 map needs; the
// integer map does not. Dropping that split doubles the tile count, and doubling the tile count is
// what lets the down projection take eight token tiles without halving its wave population: waves
// per launch are tiles * ceil(Npad / (16*TT)), so the two factors cancel.
template <int TT, bool CSRNE = false>
__global__ __launch_bounds__(NW * 32) void k_down_single(
        const uint8_t *__restrict__ W, const half2v *__restrict__ sc, const float *__restrict__ gain,
        const void *__restrict__ B, const float *__restrict__ cscale,
        const float *__restrict__ resid, float *__restrict__ out,
        int nb, int rows, int Npad, int outstride) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int tile = blockIdx.x * NW + wave, col = lane & 15, half = lane >> 4;
    const int tg0 = blockIdx.y * TT * 16, tstride = gridDim.y * TT * 16;
    const uint8_t *wbase = W + size_t(tile) * nb * 512;
    for (int tg = tg0; tg < Npad; tg += tstride) {
        half2v h[TT][4];
        accumulate_matrix<TT, CSRNE>(wbase, sc, B, cscale, nb, Npad, tile, col, half, tg, h);
        float g[8];
#pragma unroll
        for (int r = 0; r < 8; ++r) g[r] = gain[tile * 16 + 2 * r + half];
#pragma unroll
        for (int t = 0; t < TT; ++t) {
            const int token = tg + t * 16 + col;
            if (token >= rows) continue;
#pragma unroll
            for (int j = 0; j < 4; ++j) {
                const size_t o0 = size_t(token) * outstride + tile * 16 + 4 * j + half, o1 = o0 + 2;
                out[o0] = resid[o0] + (float) h[t][j][0] * g[2 * j];
                out[o1] = resid[o1] + (float) h[t][j][1] * g[2 * j + 1];
            }
        }
    }
}

// ------------------------------------------------------------------ preparation

struct Plan {
    int D = 0, FF = 0, maxrows = 0;
    uint8_t *wgu_a = nullptr, *wgu_b = nullptr, *wd_a = nullptr, *wd_b = nullptr;
    uint16_t *sg = nullptr, *su = nullptr, *sd_a = nullptr, *sd_b = nullptr;
    uint8_t *wd_full = nullptr;
    half2v *pd_full = nullptr;
    float *gain_d_full = nullptr;
    half2v *pg = nullptr, *pu = nullptr, *pd_a = nullptr, *pd_b = nullptr;
    half2v *gain_g = nullptr, *gain_u = nullptr, *gain_da = nullptr, *gain_db = nullptr;
    float *gainf_da = nullptr, *gainf_db = nullptr;
    void *Bin = nullptr, *Bhid = nullptr;
    float *csin = nullptr, *cshid = nullptr, *hidden = nullptr;
    const float *norm = nullptr, *signs = nullptr;
    size_t bytes = 0;
    int underflow_rows = 0;
};

inline float h2f_host(uint16_t b) { _Float16 h; std::memcpy(&h, &b, 2); return (float) h; }
inline uint16_t f2h_host(float v) { _Float16 h = (_Float16) v; uint16_t b; std::memcpy(&b, &h, 2); return b; }

// HALO tile rows carry 32 logical rows per block; row r of tile t is lane (t & 1) * 16 + r of
// block t/2. Decoding is untimed preparation. Transcribed from the arithmetic candidate.
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

// One power of two per output row, chosen so the row's largest block scale sits just under
// 2^-SCALE_SHIFT. `gain` is the exact reciprocal, optionally carrying a folded Hadamard sign.
struct RowScale {
    std::vector<float> normalized;   // [rows][nb], already sign-folded
    std::vector<float> gain;         // [rows]
};
RowScale row_normalize(const std::vector<uint16_t> &s, int rows, int nb, const float *sign, int &underflow) {
    RowScale out;
    out.normalized.assign(size_t(rows) * nb, 0.f);
    out.gain.assign(rows, 1.f);
    for (int row = 0; row < rows; ++row) {
        float m = 0.f;
        for (int b = 0; b < nb; ++b) m = std::max(m, std::fabs(h2f_host(s[size_t(row) * nb + b])));
        int e = 0;
        if (m > 0.f) { int ex = 0; std::frexpf(m, &ex); e = -ex - SCALE_SHIFT; }
        const float f = std::ldexp(1.0f, e), sg = sign ? sign[row] : 1.0f;
        out.gain[row] = std::ldexp(1.0f, -e) * sg;
        for (int b = 0; b < nb; ++b) {
            float v = h2f_host(s[size_t(row) * nb + b]) * f;
            if (v != 0.f && std::fabs(v) < 6.103515625e-5f) ++underflow;
            out.normalized[size_t(row) * nb + b] = v;
        }
    }
    return out;
}

// Scale pairs in exactly the order a lane reads them. Row pairing: lane `half` of tile `tile`
// wants (row 4j+half, row 4j+2+half) for j in 0..3, so a lane's four pairs are 16 contiguous bytes.
std::vector<half2v> pack_rowpairs(const RowScale &rs, int rows, int nb) {
    std::vector<half2v> out(size_t(rows / 16) * nb * 8);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int b = 0; b < nb; ++b)
            for (int h = 0; h < 2; ++h)
                for (int j = 0; j < 4; ++j) {
                    int r0 = tile * 16 + 4 * j + h, r1 = r0 + 2;
                    out[(size_t(tile) * nb + b) * 8 + h * 4 + j] = half2v{
                        (_Float16) rs.normalized[size_t(r0) * nb + b], (_Float16) rs.normalized[size_t(r1) * nb + b]};
                }
    return out;
}
// Unit pairing: (matrix A row, matrix B row) of the same physical row, rows 2r+half.
std::vector<half2v> pack_unitpairs(const RowScale &a, const RowScale &b, int rows, int nb) {
    std::vector<half2v> out(size_t(rows / 16) * nb * 16);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int blk = 0; blk < nb; ++blk)
            for (int h = 0; h < 2; ++h)
                for (int r = 0; r < 8; ++r) {
                    int row = tile * 16 + 2 * r + h;
                    out[(size_t(tile) * nb + blk) * 16 + h * 8 + r] = half2v{
                        (_Float16) a.normalized[size_t(row) * nb + blk], (_Float16) b.normalized[size_t(row) * nb + blk]};
                }
    return out;
}
std::vector<half2v> pack_rowgain(const std::vector<float> &g, int rows) {
    std::vector<half2v> out(size_t(rows / 16) * 8);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int h = 0; h < 2; ++h)
            for (int j = 0; j < 4; ++j) {
                int r0 = tile * 16 + 4 * j + h;
                out[size_t(tile) * 8 + h * 4 + j] = half2v{(_Float16) g[r0], (_Float16) g[r0 + 2]};
            }
    return out;
}
std::vector<half2v> pack_unitgain(const std::vector<float> &a, const std::vector<float> &b, int rows) {
    std::vector<half2v> out(size_t(rows / 16) * 16);
    for (int tile = 0; tile < rows / 16; ++tile)
        for (int h = 0; h < 2; ++h)
            for (int r = 0; r < 8; ++r) {
                int row = tile * 16 + 2 * r + h;
                out[size_t(tile) * 16 + h * 8 + r] = half2v{(_Float16) a[row], (_Float16) b[row]};
            }
    return out;
}

template <class T> void upload(T *&dst, const std::vector<T> &src, size_t &total) {
    check(hipMalloc(&dst, src.size() * sizeof(T)), "malloc");
    check(hipMemcpy(dst, src.data(), src.size() * sizeof(T), hipMemcpyHostToDevice), "upload");
    total += src.size() * sizeof(T);
}

// ACC 0 control, ACC 1 row pairs, ACC 2 unit pairs; DOWNACC selects the down projection's carrier
// separately so the two approximations can be measured apart.
template <int ACC, int DOWNACC>
void *prepare(const kelana_batch::Weights &w, int maxrows) {
    auto *p = new Plan{};
    p->D = w.width; p->FF = w.hidden; p->maxrows = maxrows;
    p->norm = w.norm_device; p->signs = w.signs_device;
    std::vector<int8_t> g, u, d;
    std::vector<uint16_t> gs, us, ds;
    decode_matrix(w.gate_host, p->FF, p->D, g, gs);
    decode_matrix(w.up_host, p->FF, p->D, u, us);
    decode_matrix(w.down_host, p->D, p->FF, d, ds);
    const int Dh = p->D / 2, nbd = p->D / KB, nbf = p->FF / KB;
    std::vector<int8_t> d0(d.begin(), d.begin() + size_t(Dh) * p->FF), d1(d.begin() + size_t(Dh) * p->FF, d.end());
    std::vector<uint16_t> ds0(ds.begin(), ds.begin() + size_t(Dh) * nbf), ds1(ds.begin() + size_t(Dh) * nbf, ds.end());

    upload(p->wgu_a, pack_two_bit(g.data(), p->FF, p->D), p->bytes);
    upload(p->wgu_b, pack_two_bit(u.data(), p->FF, p->D), p->bytes);
    upload(p->wd_a, pack_two_bit(d0.data(), Dh, p->FF), p->bytes);
    upload(p->wd_b, pack_two_bit(d1.data(), Dh, p->FF), p->bytes);

    if constexpr (ACC == 0) {
        upload(p->sg, tile_major(gs, p->FF, nbd), p->bytes);
        upload(p->su, tile_major(us, p->FF, nbd), p->bytes);
    } else {
        // The width-FF Hadamard sign vector is folded into the up row scale: a sign flip, exact.
        RowScale rg = row_normalize(gs, p->FF, nbd, nullptr, p->underflow_rows);
        RowScale ru = row_normalize(us, p->FF, nbd, w.signs_host, p->underflow_rows);
        if constexpr (ACC == 1) {
            upload(p->pg, pack_rowpairs(rg, p->FF, nbd), p->bytes);
            upload(p->pu, pack_rowpairs(ru, p->FF, nbd), p->bytes);
            upload(p->gain_g, pack_rowgain(rg.gain, p->FF), p->bytes);
            upload(p->gain_u, pack_rowgain(ru.gain, p->FF), p->bytes);
        } else {
            upload(p->pg, pack_unitpairs(rg, ru, p->FF, nbd), p->bytes);
            upload(p->gain_g, pack_unitgain(rg.gain, ru.gain, p->FF), p->bytes);
        }
    }
    if constexpr (DOWNACC == 0) {
        upload(p->sd_a, tile_major(ds0, Dh, nbf), p->bytes);
        upload(p->sd_b, tile_major(ds1, Dh, nbf), p->bytes);
    } else if constexpr (DOWNACC == 3) {
        RowScale rd = row_normalize(ds, p->D, nbf, nullptr, p->underflow_rows);
        upload(p->wd_full, pack_two_bit(d.data(), p->D, p->FF), p->bytes);
        upload(p->pd_full, pack_rowpairs(rd, p->D, nbf), p->bytes);
        upload(p->gain_d_full, rd.gain, p->bytes);
    } else {
        RowScale ra = row_normalize(ds0, Dh, nbf, nullptr, p->underflow_rows);
        RowScale rb = row_normalize(ds1, Dh, nbf, nullptr, p->underflow_rows);
        if constexpr (DOWNACC == 1) {
            upload(p->pd_a, pack_rowpairs(ra, Dh, nbf), p->bytes);
            upload(p->pd_b, pack_rowpairs(rb, Dh, nbf), p->bytes);
            upload(p->gain_da, pack_rowgain(ra.gain, Dh), p->bytes);
            upload(p->gain_db, pack_rowgain(rb.gain, Dh), p->bytes);
            upload(p->gainf_da, ra.gain, p->bytes);
            upload(p->gainf_db, rb.gain, p->bytes);
        } else {
            upload(p->pd_a, pack_unitpairs(ra, rb, Dh, nbf), p->bytes);
            upload(p->gain_da, pack_unitgain(ra.gain, rb.gain, Dh), p->bytes);
        }
    }
    if (p->underflow_rows)
        std::fprintf(stderr, "half-carrier: %d normalized block scales below the FP16 normal boundary\n", p->underflow_rows);

    int Npad = (maxrows + 15) / 16 * 16;
    size_t bin = size_t(p->D / 16) * Npad * 8, bhid = size_t(p->FF / 16) * Npad * 8;
    check(hipMalloc(&p->Bin, bin), "Bin");
    check(hipMalloc(&p->Bhid, bhid), "Bhid");
    check(hipMemset(p->Bin, 0, bin), "Bin zero");
    check(hipMemset(p->Bhid, 0, bhid), "Bhid zero");
    check(hipMalloc(&p->csin, size_t(Npad) * nbd * 4), "csin");
    check(hipMalloc(&p->cshid, size_t(Npad) * nbf * 4), "cshid");
    check(hipMemset(p->csin, 0, size_t(Npad) * nbd * 4), "csin zero");
    check(hipMemset(p->cshid, 0, size_t(Npad) * nbf * 4), "cshid zero");
    check(hipMalloc(&p->hidden, size_t(Npad) * p->FF * 4), "hidden");
    p->bytes += bin + bhid + size_t(Npad) * (nbd + nbf) * 4 + size_t(Npad) * p->FF * 4;
    return p;
}

void release(void *state) {
    auto *p = static_cast<Plan *>(state);
    for (void *q : {(void *) p->wgu_a, (void *) p->wgu_b, (void *) p->wd_a, (void *) p->wd_b,
                    (void *) p->sg, (void *) p->su, (void *) p->sd_a, (void *) p->sd_b,
                    (void *) p->pg, (void *) p->pu, (void *) p->pd_a, (void *) p->pd_b,
                    (void *) p->wd_full, (void *) p->pd_full, (void *) p->gain_d_full,
                    (void *) p->gain_g, (void *) p->gain_u, (void *) p->gain_da, (void *) p->gain_db,
                    (void *) p->gainf_da, (void *) p->gainf_db,
                    p->Bin, p->Bhid, (void *) p->csin, (void *) p->cshid, (void *) p->hidden})
        if (q) hipFree(q);
    delete p;
}
size_t resident_bytes(void *state) { return static_cast<Plan *>(state)->bytes; }

struct Stages {
    bool on = getenv("KELANA_ARITH_STAGES") != nullptr;
    hipEvent_t ev[5]{};
    const char *name[4] = {"prep_in", "gate_up_silu", "prep_hidden", "down_residual"};
    int at = 0;
    void mark(hipStream_t s) { if (!on) return; if (!ev[at]) hipEventCreate(&ev[at]); hipEventRecord(ev[at], s); ++at; }
    void report(const char *who, int rows) {
        if (!on) return;
        hipEventSynchronize(ev[4]);
        std::fprintf(stderr, "%-26s rows %-4d", who, rows);
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

// TTCAP is the largest token-tile count this candidate will use; the actual count still has to
// divide the padded batch usefully, so a small batch falls back to the same rungs as the control.
template <int ACC, int DOWNACC, int CONS, int TTCAP, bool CSRNE = false>
void run(void *state, int rows, const float *input, float *output, hipStream_t stream) {
    auto *p = static_cast<Plan *>(state);
    static Stages st;
    const int D = p->D, FF = p->FF, Npad = (rows + 15) / 16 * 16, Dh = D / 2;
    st.mark(stream);
    k_prep4<true, true><<<rows * (D / 1024), NT, 0, stream>>>(input, p->norm, p->Bin, p->csin, D, Npad);
    st.mark(stream);

#define LAUNCH(TT, SPLIT, A, FUSE, WA, WB_, BF, SA, SB, PA, PB, GA, GB, GAF, GBF, CS, RESID, OUT, NB, TILES, OSTRIDE, ROWOFF) \
    k_proj<TT, A, CONS, FUSE, SPLIT, CSRNE><<<dim3((TILES) / NW, group_split((TILES) / NW, Npad / (TT * 16))), NW * 32, 0, stream>>>( \
        WA, WB_, BF, SA, SB, PA, PB, GA, GB, GAF, GBF, CS, p->signs, RESID, OUT, NB, rows, Npad, OSTRIDE, ROWOFF)
#define GU(TT, SPLIT) LAUNCH(TT, SPLIT, ACC, true, p->wgu_a, p->wgu_b, p->Bin, p->sg, p->su, p->pg, p->pu, \
        p->gain_g, p->gain_u, nullptr, nullptr, p->csin, nullptr, p->hidden, D / KB, FF / 16, FF, 0)
#define DOWN(TT, SPLIT) LAUNCH(TT, SPLIT, DOWNACC, false, p->wd_a, p->wd_b, p->Bhid, p->sd_a, p->sd_b, p->pd_a, p->pd_b, \
        p->gain_da, p->gain_db, p->gainf_da, p->gainf_db, p->cshid, input, output, FF / KB, Dh / 16, D, Dh)

    if (TTCAP >= 8 && Npad >= 128) GU(8, true);
    else if (Npad >= 64) GU(4, false);
    else if (Npad == 32) GU(2, false);
    else GU(1, false);
    st.mark(stream);
    k_prep4<false, false><<<rows * (FF / 1024), NT, 0, stream>>>(p->hidden, nullptr, p->Bhid, p->cshid, FF, Npad);
    st.mark(stream);
    // The down projection has D/2/16/NW = 40 workgroups against the gate/up projection's 272, so
    // widening its token tile costs more parallelism than it saves weight traffic. Measured both.
#define DOWN1(TT) k_down_single<TT, CSRNE><<<dim3(D / 16 / NW, group_split(D / 16 / NW, Npad / (TT * 16))), NW * 32, 0, stream>>>( \
        p->wd_full, p->pd_full, p->gain_d_full, p->Bhid, p->cshid, input, output, FF / KB, rows, Npad, D)
    if constexpr (DOWNACC == 3) {
        if (Npad >= 128) DOWN1(8);
        else if (Npad >= 64) DOWN1(4);
        else if (Npad == 32) DOWN1(2);
        else DOWN1(1);
    }
    else if (TTCAP >= 16 && Npad >= 128) DOWN(8, true);
    else if (Npad >= 64) DOWN(4, false);
    else if (Npad == 32) DOWN(2, false);
    else DOWN(1, false);
#undef DOWN1
#undef DOWN
#undef GU
#undef LAUNCH
    st.mark(stream);
    st.report("half-carrier", rows);
}

kelana_batch::Candidate control() {
    return {"hc-control-iu4-a4", kelana_batch::Claim::approximate,
            "matched control: the arithmetic directory's FP32 block carrier, this file's producer and packing",
            prepare<0, 0>, run<0, 0, 0, 4>, release, resident_bytes};
}
kelana_batch::Candidate rowpair() {
    return {"hc-rowpair-a4", kelana_batch::Claim::approximate,
            "packed FP16 carrier over adjacent rows of one channel, four token tiles, float SiLU boundary",
            prepare<1, 1>, run<1, 1, 0, 4>, release, resident_bytes};
}
kelana_batch::Candidate rowpair_tt8() {
    return {"hc-rowpair-a4-tt8", kelana_batch::Claim::approximate,
            "row-paired FP16 carrier with eight token tiles at the gate/up projection, split K passes",
            prepare<1, 1>, run<1, 1, 0, 8>, release, resident_bytes};
}
kelana_batch::Candidate rowpair_tt8_both() {
    return {"hc-rowpair-a4-tt8-both", kelana_batch::Claim::approximate,
            "row-paired FP16 carrier with eight token tiles at both projections",
            prepare<1, 1>, run<1, 1, 0, 16>, release, resident_bytes};
}
kelana_batch::Candidate rowpair_tt8_down1() {
    return {"hc-rowpair-a4-tt8-down1", kelana_batch::Claim::approximate,
            "eight token tiles at both projections, down projection as one unsplit matrix over all D rows",
            prepare<1, 3>, run<1, 3, 0, 8>, release, resident_bytes};
}
kelana_batch::Candidate rowpair_tt8_down1_rne() {
    return {"hc-rowpair-a4-tt8-down1-rne", kelana_batch::Claim::approximate,
            "the fastest schedule with the per-block activation scale converted round-to-nearest instead of truncated",
            prepare<1, 3>, run<1, 3, 0, 8, true>, release, resident_bytes};
}
kelana_batch::Candidate rowpair_tt8_down1_poly8() {
    return {"hc-rowpair-a4-tt8-down1-poly8", kelana_batch::Claim::approximate,
            "unsplit eight-tile down projection with the packed-half degree-8 SiLU consumer",
            prepare<1, 3>, run<1, 3, 8, 8>, release, resident_bytes};
}
kelana_batch::Candidate rowpair_fp32down() {
    return {"hc-rowpair-a4-fp32down", kelana_batch::Claim::approximate,
            "row-paired FP16 carrier at gate/up only, FP32 carrier at the down projection",
            prepare<1, 0>, run<1, 0, 0, 8>, release, resident_bytes};
}
kelana_batch::Candidate rowpair_poly6() {
    return {"hc-rowpair-a4-poly6", kelana_batch::Claim::approximate,
            "row-paired FP16 carrier consumed by a packed-half degree-6 SiLU with an exact tail branch",
            prepare<1, 1>, run<1, 1, 6, 8>, release, resident_bytes};
}
kelana_batch::Candidate rowpair_poly8() {
    return {"hc-rowpair-a4-poly8", kelana_batch::Claim::approximate,
            "row-paired FP16 carrier consumed by a packed-half degree-8 SiLU with an exact tail branch",
            prepare<1, 1>, run<1, 1, 8, 8>, release, resident_bytes};
}
kelana_batch::Candidate unitpair() {
    return {"hc-unitpair-a4", kelana_batch::Claim::approximate,
            "packed FP16 carrier holding the gate and up value of one hidden unit, four token tiles",
            prepare<2, 2>, run<2, 2, 0, 4>, release, resident_bytes};
}
}
KELANA_BATCH_REGISTER(control)
KELANA_BATCH_REGISTER(rowpair)
KELANA_BATCH_REGISTER(rowpair_tt8)
KELANA_BATCH_REGISTER(rowpair_tt8_both)
KELANA_BATCH_REGISTER(rowpair_tt8_down1)
KELANA_BATCH_REGISTER(rowpair_tt8_down1_rne)
KELANA_BATCH_REGISTER(rowpair_tt8_down1_poly8)
KELANA_BATCH_REGISTER(rowpair_fp32down)
KELANA_BATCH_REGISTER(rowpair_poly6)
KELANA_BATCH_REGISTER(rowpair_poly8)
KELANA_BATCH_REGISTER(unitpair)
