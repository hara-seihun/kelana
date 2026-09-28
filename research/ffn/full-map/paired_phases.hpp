#pragma once
#include "paired_codec.hpp"
#include "phases.hpp"

namespace halo {
namespace {
using kelana_ffn::half16;
using kelana_ffn::float8;
using half4 = _Float16 __attribute__((ext_vector_type(4)));

// Same FP32 norm, butterfly and quantisation order as prep_chunk_r. Quantised values
// leave this producer as the two WMMA digit planes, not a byte buffer to decode later.
__device__ __forceinline__ void ph_pair_prep(Ctx &c, const PrepR &a,
                                            _Float16 *planes, int nrows) {
    int tid = threadIdx.x, lane = tid & 31, wave = tid >> 5;
    int nchunks = a.n / 1024, total = nrows * nchunks;
    for (int unit = blockIdx.x; unit >= 0 && unit < total; unit = next_unit(c, total)) {
        c.dirty = true;
        int row = unit / nchunks, chunk = unit % nchunks;
        const float *x = a.x + size_t(row) * a.n;
        float ss = 0.0f;
        for (int i = tid * 4; i < a.n; i += NT * 4) {
            float4 t = *(const float4 *)(x + i);
            ss = fmaf(t.x, t.x, ss); ss = fmaf(t.y, t.y, ss);
            ss = fmaf(t.z, t.z, ss); ss = fmaf(t.w, t.w, ss);
        }
        ss = block_sum_256(ss, c.red);
        float inv = rsqrtf(ss / float(a.n) + a.eps);
        int e0 = wave * 128 + lane * 4, base = chunk * 1024 + e0;
        float4 v = *(const float4 *)(x + base);
        float4 k = *(const float4 *)(a.kvec + base);
        v.x *= inv * k.x; v.y *= inv * k.y;
        v.z *= inv * k.z; v.w *= inv * k.w;
        {
            float p0 = v.x + v.y, p1 = v.x - v.y;
            float p2 = v.z + v.w, p3 = v.z - v.w;
            v.x = p0 + p2; v.y = p1 + p3; v.z = p0 - p2; v.w = p1 - p3;
        }
        #pragma unroll
        for (int bit = 1; bit < 32; bit <<= 1) {
            bool upper = (lane & bit) != 0;
            float ox = __shfl_xor(v.x, bit, 32), oy = __shfl_xor(v.y, bit, 32);
            float oz = __shfl_xor(v.z, bit, 32), ow = __shfl_xor(v.w, bit, 32);
            v.x = upper ? ox - v.x : v.x + ox; v.y = upper ? oy - v.y : v.y + oy;
            v.z = upper ? oz - v.z : v.z + oz; v.w = upper ? ow - v.w : v.w + ow;
        }
        *(float4 *)(c.lds + e0) = v;
        __syncthreads();
        if (tid < 128) {
            float u[8];
            #pragma unroll
            for (int m = 0; m < 8; ++m) u[m] = c.lds[tid + 128 * m];
            #pragma unroll
            for (int len = 1; len < 8; len <<= 1) {
                #pragma unroll
                for (int m = 0; m < 8; ++m) if ((m & len) == 0) {
                    float x0 = u[m], x1 = u[m + len];
                    u[m] = x0 + x1; u[m + len] = x0 - x1;
                }
            }
            #pragma unroll
            for (int m = 0; m < 8; ++m) c.lds[tid + 128 * m] = u[m] * 0.03125f;
        }
        __syncthreads();
        v = *(const float4 *)(c.lds + e0);
        float amax = warp_max(fmaxf(fmaxf(fabsf(v.x), fabsf(v.y)), fmaxf(fabsf(v.z), fabsf(v.w))));
        float iscale = amax > 0.0f ? 127.0f / amax : 0.0f;
        int q[4] = {__float2int_rn(v.x * iscale), __float2int_rn(v.y * iscale),
                    __float2int_rn(v.z * iscale), __float2int_rn(v.w * iscale)};
        half4 lo, hi;
        #pragma unroll
        for (int j = 0; j < 4; ++j) {
            int l = ((q[j] + 8) & 15) - 8;
            lo[j] = (_Float16) l; hi[j] = (_Float16) ((q[j] - l) >> 4);
        }
        *(half4 *)(planes + size_t(row) * a.n + base) = lo;
        *(half4 *)(planes + size_t(8 + row) * a.n + base) = hi;
        if (lane == 0) a.xs[row * (a.n / 128) + (base >> 7)] = amax / 127.0f;
        __syncthreads();
    }
    end_phase(c);
}

// 16 hidden units per tile. Each physical WMMA row holds its gate/up pair.
// Independent block scales force integer recovery before each FP32 FMA.
// Gate/up scalars survive only in registers through the nonlinearity.
template<int NB, int HIDDEN, bool CAPTURE = false>
__device__ __forceinline__ void ph_pair_gate_up(Ctx &c, const uint8_t *weights,
        const _Float16 *planes, const float *xs, const float *signs,
        float *hidden, int nrows, float *capture_gate = nullptr, float *capture_up = nullptr) {
    constexpr int PW = NB / NW;
    static_assert(NB % NW == 0);
    int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    int col = lane & 15, token = col & 7, plane = col >> 3, half = lane >> 4;
    constexpr int total = HIDDEN / 16;
    for (int tile = blockIdx.x; tile >= 0 && tile < total; tile = next_unit(c, total)) {
        c.dirty = true;
        float8 yg = {}, yu = {};
        float *scl = c.lds + (NW - 1) * 8 * 32 + wave * 32;
        const uint8_t *first = weights + (size_t(tile) * NB + wave * PW) * kelana_ffn::PAIR_BLOCK_BYTES;
        uint2 codes[8];
        #pragma unroll
        for (int s = 0; s < 8; ++s) codes[s] = *(const uint2 *)(first + s * 128 + (lane & 15) * 8);
        unsigned scales = *(const unsigned *)(first + kelana_ffn::PAIR_CODES_BYTES + (lane & 15) * 4);
        #pragma unroll 1
        for (int bi = 0; bi < PW; ++bi) {
            int block = wave * PW + bi;
            uint2 next[8]; unsigned next_scales = scales;
            #pragma unroll
            for (int s = 0; s < 8; ++s) next[s] = codes[s];
            if (bi + 1 < PW) {
                const uint8_t *w = weights + (size_t(tile) * NB + block + 1) * kelana_ffn::PAIR_BLOCK_BYTES;
                #pragma unroll
                for (int s = 0; s < 8; ++s) next[s] = *(const uint2 *)(w + s * 128 + (lane & 15) * 8);
                next_scales = *(const unsigned *)(w + kelana_ffn::PAIR_CODES_BYTES + (lane & 15) * 4);
            }
            if (lane < 16) {
                scl[lane] = __half2float(__ushort_as_half(scales & 0xffffu));
                scl[lane + 16] = __half2float(__ushort_as_half(scales >> 16));
            }
            __builtin_amdgcn_wave_barrier();
            float8 p = {};
            #pragma unroll
            for (int slice = 0; slice < 8; ++slice) {
                half16 a = kelana_ffn::decode_sixteen(codes[slice]);
                half16 b = *(const half16 *)(planes + size_t(plane * 8 + token) * (NB * 128)
                                            + block * 128 + slice * 16);
                p = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a, b, p);
            }
            float scale_x = xs[token * NB + block];
            #pragma unroll
            for (int r = 0; r < 8; ++r) {
                float g, u;
                kelana_ffn::unpair(p[r], g, u);
                float gp = kelana_ffn::plane_partner(g), up = kelana_ffn::plane_partner(u);
                // Only the low-plane lane writes; both halves execute the DPP instruction.
                g = fmaf(16.0f, gp, g); u = fmaf(16.0f, up, u);
                int row = r * 2 + half;
                yg[r] = fmaf(g, scl[row] * scale_x, yg[r]);
                yu[r] = fmaf(u, scl[row + 16] * scale_x, yu[r]);
            }
            #pragma unroll
            for (int s = 0; s < 8; ++s) codes[s] = next[s];
            scales = next_scales;
        }
        float gate[8];
        for (int pass = 0; pass < 2; ++pass) {
            float8 y = pass == 0 ? yg : yu;
            if (wave) {
                #pragma unroll
                for (int r = 0; r < 8; ++r) c.lds[((wave - 1) * 8 + r) * 32 + lane] = y[r];
            }
            __syncthreads();
            if (wave == 0 && col < nrows) {
                #pragma unroll
                for (int r = 0; r < 8; ++r) {
                    float v = y[r];
                    #pragma unroll
                    for (int w = 1; w < NW; ++w) v += c.lds[((w - 1) * 8 + r) * 32 + lane];
                    int row = tile * 16 + 2 * r + half;
                    size_t o = size_t(token) * HIDDEN + row;
                    if (pass == 0) {
                        gate[r] = v;
                        if constexpr (CAPTURE) capture_gate[o] = v;
                    } else {
                        if constexpr (CAPTURE) capture_up[o] = v;
                        hidden[o] = silu(gate[r]) * v * signs[row];
                    }
                }
            }
            __syncthreads();
        }
    }
    end_phase(c);
}
}
}
