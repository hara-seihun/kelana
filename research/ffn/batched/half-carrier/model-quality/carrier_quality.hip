// The half carrier inside the whole model.
//
// `hc-rowpair-a4-tt8-down1-rne` wins 1.19x on one FFN at 256 rows and perturbs that FFN's output by
// 0.127% (layer 0) against a matched control. Whether that perturbation matters is a question about
// 64 layers, attention, recurrent state and logits, and it cannot be answered by rounding a finished
// FP32 projection to binary16: the carrier's error comes from *accumulating* 40 or 136 per-block
// products in binary16, under a dyadic row gauge, with the activation scale converted per block.
//
// This translation unit links in place of `halo_rows.o` and includes the unchanged upstream source,
// so attention, state, the head and every barrier keep their deployed order. Two FFN phases are
// interposed:
//
//   ph_prep          the candidate's direct symmetric activation quantiser, at the gate/up input
//                    and optionally at the hidden activation. Transcribed from
//                    research/ffn/batched/lossy/quality.hip, which owns that intervention.
//   ph_matvec_auto   the gate/up and down projections, re-run with the packed-half block carrier.
//
// Everything else in the model, including the four other matvecs per layer and both projections on
// layers outside the mask, goes to the upstream implementation untouched.
//
// Differences from the standalone candidate, declared rather than hidden:
//
//   * The weight operand is the deployed HALO tile read through `peel`/`dot4`, not the candidate's
//     repacked two-bit image read through IU4 WMMA. Both produce the same integer: the block dot of
//     four-bit activations against ternary weights is at most 896 in magnitude and integer
//     arithmetic is exact, so the value entering the carrier is identical.
//   * A lane here owns one output row and TT token rows, where the candidate's lane owns eight
//     output rows and TT token tiles. The carrier pairs token rows instead of output rows. The two
//     pairings were measured to agree to 6.6e-10 relative, so this is a lane placement difference.
//   * The candidate pairs (r, r+1) of one channel; with an odd token count the last lane of a pair
//     carries a duplicate, which is discarded.
//   * Block order is sequential, 0..NB-1, in one accumulator, which is the candidate's order. The
//     deployed schedule splits K across eight waves and, at the down projection, across two atomic
//     parts; that split is what this phase gives up, and it is why the phase is slower.
//   * The transformed float that the quantiser rounds comes from the deployed `prep_chunk_r`, not
//     from the candidate's own producer. They compute the same norm, sign and Hadamard in a
//     different association, so a small number of codes can differ at rounding boundaries.
#include "policy.hpp"
#include "phases.hpp"
#include <cstdio>
#include <cstdlib>

namespace {
__constant__ CarrierPolicy policy;
__device__ unsigned count_quant[64], count_gu[64], count_down[64], count_declined[64];

// Capture buffers for one 8-row pass at one layer. Sized for the deployed maximum of 8 rows.
constexpr int CAP_ROWS = 8;
__device__ float  cap_x_in[CAP_ROWS * halo::D];
__device__ signed char cap_xq_in[CAP_ROWS * halo::D];
__device__ float  cap_xs_in[CAP_ROWS * (halo::D / 128)];
__device__ float  cap_gate_up[2 * CAP_ROWS * halo::FF];
__device__ signed char cap_xq_hid[CAP_ROWS * halo::FF];
__device__ float  cap_xs_hid[CAP_ROWS * (halo::FF / 128)];
__device__ float  cap_x_out[CAP_ROWS * halo::D];
}

namespace halo {
namespace {

// ---------------------------------------------------------------- activation quantiser
//
// Transcribed from lossy/quality.hip with the stochastic and A8-code paths removed: this directory
// only ever wants the direct symmetric quantiser the batched candidate uses.
__device__ __forceinline__ void hc_ffn_prep(Ctx &c, const PrepR &a, int nrows) {
    const bool down = policy.down && c.gen >= 10 && (c.gen - 10) % 10 == 0 && a.n == FF &&
                      a.flags == (PREP_SILU_MUL | PREP_HADAMARD | PREP_QUANT);
    const bool input = c.gen >= 8 && (c.gen - 8) % 10 == 0 && a.n == D &&
                       a.flags == (PREP_NORM | PREP_HADAMARD | PREP_QUANT);
    const int layer = input ? int((c.gen - 8) / 10) : down ? int((c.gen - 10) / 10) : -1;
    if (layer < 0 || layer >= 64 || !(policy.layers & (uint64_t(1) << layer)) || policy.bits >= 8) {
        ph_prep(c, a, nrows);
        return;
    }
    const int chunks = a.n / 1024, total = nrows * chunks, tid = threadIdx.x, lane = tid & 31, wave = tid >> 5;
    const int limit = (1 << (policy.bits - 1)) - 1;
    for (int u = blockIdx.x; u >= 0 && u < total; u = next_unit(c, total)) {
        c.dirty = true;
        const int row = u / chunks, chunk = u % chunks;
        float inv = 1.f;
        if (input) {
            const float *x = a.x + size_t(row) * a.n;
            float ss = 0;
            for (int i = tid * 4; i < a.n; i += NT * 4) {
                float4 v = *(const float4 *) (x + i);
                ss = fmaf(v.x, v.x, ss); ss = fmaf(v.y, v.y, ss);
                ss = fmaf(v.z, v.z, ss); ss = fmaf(v.w, v.w, ss);
            }
            ss = block_sum_256(ss, c.red);
            inv = rsqrtf(ss / float(a.n) + a.eps);
        }
        const bool capture = policy.capture_layer == layer && row < 8;
        if (capture && input)
            for (int i = tid; i < 1024; i += NT) cap_x_in[row * D + chunk * 1024 + i] = a.x[size_t(row) * a.n + chunk * 1024 + i];
        prep_chunk_r(a, row, chunk, inv, c.lds, 0);
        __syncthreads();
        const int base = chunk * 1024 + wave * 128 + lane * 4;
        int8_t *q = a.xq + size_t(row) * a.n + base;
        const float4 t = *(const float4 *) (c.lds + wave * 128 + lane * 4);
        const float amax = warp_max(fmaxf(fmaxf(fabsf(t.x), fabsf(t.y)), fmaxf(fabsf(t.z), fabsf(t.w))));
        const float iscale = amax > 0 ? float(limit) / amax : 0.f;
        int sum = 0;
#pragma unroll
        for (int j = 0; j < 4; ++j) {
            int value = __float2int_rn((&t.x)[j] * iscale);
            value = max(-limit, min(limit, value));
            q[j] = int8_t(value); sum += value;
        }
        sum = warp_sum_i(sum);
        if (lane == 0) {
            const int index = row * (a.n / 128) + base / 128;
            a.xs[index] = amax / float(limit);
            a.xsum[index] = sum;
        }
        if (capture) {
            signed char *dq = input ? cap_xq_in + size_t(row) * D : cap_xq_hid + size_t(row) * FF;
#pragma unroll
            for (int j = 0; j < 4; ++j) dq[base + j] = (signed char) q[j];
            if (lane == 0) (input ? cap_xs_in + size_t(row) * (D / 128) : cap_xs_hid + size_t(row) * (FF / 128))[base / 128] = amax / float(limit);
        }
        if (tid == 0) atomicAdd(count_quant + layer, 1u);
        __syncthreads();
    }
    end_phase(c);
}

// ---------------------------------------------------------------- half-carrier projection

using half2v = _Float16 __attribute__((ext_vector_type(2)));

__device__ __forceinline__ half2v pk(float a, float b) {
    return __builtin_bit_cast(half2v, __builtin_amdgcn_cvt_pkrtz(a, b));
}
// The candidate's two forms for the per-block activation scale. Truncation is what
// `hc-rowpair-a4-tt8-down1` does and round-to-nearest is what `-rne` does; the latter is preferred
// and is what this file defaults to.
__device__ __forceinline__ half2v cvt_scale2(float a, float b) {
    if (policy.scale_rne) return half2v{(_Float16) a, (_Float16) b};
    return pk(a, b);
}

// One tile of 32 output rows, all NB blocks, TT token rows, carried in binary16.
//
// Pass one takes the row's dyadic gauge from its own largest block scale, exactly as the
// candidate's `row_normalize` does at preparation; here the weights only exist on the device in
// HALO form, so the gauge is recomputed from the same tail bytes rather than shipped alongside.
// Powers of two are exact in both directions while the scaled values stay representable.
//
// FP32 is available as a control: the same unit decomposition, the same sequential block order and
// the same gauge, differing only in what the running sum is stored in. It separates what this
// phase's schedule costs from what the representation costs, and a run where it scores zero against
// the deployed control would mean the schedule is free and every measured difference is the
// carrier. It does not score zero, and the amount by which it does not is the ordering difference
// declared above.
template <int NB, int TT, bool HALF, bool REVERSE = false>
__device__ __forceinline__ void hc_matvec(Ctx &c, const MvR &m, const int8_t *xq_g,
                                          const float *xs, const int *xsum, int nrows, int layer, bool gu) {
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5;
    const int groups = m.total_tiles / NW;
    cptr xq = xptr(xq_g);
    cfptr xsc = sptr(xs);
    cptr xsumc = iptr(xsum);
    for (int u = blockIdx.x; u >= 0 && u < groups; u = next_unit(c, groups)) {
        c.dirty = true;
        int tile = u * NW + wave, si = 0;
        MvSegR seg = m.seg[0];
        if (m.nseg > 1 && tile >= seg.ntiles) {
            tile -= seg.ntiles; seg = m.seg[1]; si = 1;
            if (m.nseg > 2 && tile >= seg.ntiles) { tile -= seg.ntiles; seg = m.seg[2]; si = 2; }
        }
        const bool capture = policy.capture_layer == layer;
        const uint8_t *base = seg.w + (size_t) tile * NB * TILE_BLOCK_BYTES;

        float mx = 0.f;
        for (int b = 0; b < NB; ++b) {
            const unsigned tail = *(const unsigned *) (base + size_t(b) * TILE_BLOCK_BYTES + tile_off_tail(lane));
            mx = fmaxf(mx, fabsf(__half2float(__ushort_as_half((unsigned short) (tail >> 16)))));
        }
        int ex = 0;
        if (mx > 0.f) frexpf(mx, &ex);
        const float gauge = mx > 0.f ? ldexpf(1.0f, -ex - policy.scale_shift) : 1.0f;
        const _Float16 gain = (_Float16) (1.0f / gauge);

        // Token rows paired into one register, so the accumulation runs on v_pk_fma_f16.
        constexpr int HP = (TT + 1) / 2;
        half2v y[HP];
        float yf[TT];
#pragma unroll
        for (int h = 0; h < HP; ++h) y[h] = pk(0.f, 0.f);
#pragma unroll
        for (int r = 0; r < TT; ++r) yf[r] = 0.f;

        for (int bi = 0; bi < NB; ++bi) {
            const int b = REVERSE ? NB - 1 - bi : bi;
            const uint8_t *run = base + size_t(b) * TILE_BLOCK_BYTES;
            const uint4 qa = *(const uint4 *) (run + tile_off_qs_a(lane));
            const uint2 qb = *(const uint2 *) (run + tile_off_qs_b(lane));
            const unsigned tail = *(const unsigned *) (run + tile_off_tail(lane));
            const unsigned dw[6] = {qa.x, qa.y, qa.z, qa.w, qb.x, qb.y};
            // The deployed three-stream peel, unchanged, producing this lane's 32 packed trit words.
            unsigned tr[32];
#pragma unroll
            for (int d = 0; d < 6; ++d) {
                unsigned P0 = dw[d] & 0x00ff00ffu, P1 = (dw[d] >> 8) & 0x00ff00ffu;
                const unsigned t0 = peel(P0), t1 = peel(P0), t2 = peel(P0), t3 = peel(P0), t4 = peel_last(P0);
                const unsigned u0 = peel(P1), u1 = peel(P1), u2 = peel(P1), u3 = peel(P1), u4 = peel_last(P1);
                tr[4 * d] = t0 | (t1 << 8); tr[4 * d + 1] = t2 | (t3 << 8);
                tr[4 * d + 2] = u0 | (u1 << 8); tr[4 * d + 3] = u2 | (u3 << 8);
                tr[24 + d] = t4 | (u4 << 8);
            }
            {
                unsigned P = (tail & 0xffu) | ((tail << 8) & 0xff0000u);
                const unsigned h0 = peel(P), h1 = peel(P), h2 = peel(P), h3 = peel_last(P);
                tr[30] = h0 | (h1 << 8); tr[31] = h2 | (h3 << 8);
            }
            const _Float16 ws = (_Float16) (__half2float(__ushort_as_half((unsigned short) (tail >> 16))) * gauge);
            float acc_f[TT];
#pragma unroll
            for (int r = 0; r < TT; ++r) {
                int acc = 0;
                if (r < nrows) {
                    cptr xb = xq + (size_t) r * (NB * 32) + b * 32;
#pragma unroll
                    for (int d = 0; d < 6; ++d) {
                        acc = dot4(tr[4 * d], xb[4 * d + 0], acc);
                        acc = dot4(tr[4 * d + 1], xb[4 * d + 1], acc);
                        acc = dot4(tr[4 * d + 2], xb[4 * d + 2], acc);
                        acc = dot4(tr[4 * d + 3], xb[4 * d + 3], acc);
                        acc = dot4(tr[24 + d], xb[24 + d], acc);
                    }
                    acc = dot4(tr[30], xb[30], acc);
                    acc = dot4(tr[31], xb[31], acc);
                    acc -= xsumc[r * NB + b];
                }
                acc_f[r] = float(acc);
            }
            if constexpr (HALF) {
#pragma unroll
                for (int h = 0; h < HP; ++h) {
                    const int r0 = 2 * h, r1 = r0 + 1 < TT ? r0 + 1 : r0;
                    const float s0 = r0 < nrows ? xsc[r0 * NB + b] : 0.f;
                    const float s1 = r1 < nrows ? xsc[r1 * NB + b] : 0.f;
                    // scale product in binary16, then one packed fused multiply-add per token pair:
                    // exactly the candidate's `h += pk(acc) * (s * csh)`.
                    y[h] += pk(acc_f[r0], acc_f[r1]) * (half2v{ws, ws} * cvt_scale2(s0, s1));
                }
            } else {
                const float wsf = (float) ws;
#pragma unroll
                for (int r = 0; r < TT; ++r)
                    if (r < nrows) yf[r] = __builtin_fmaf(acc_f[r], wsf * xsc[r * NB + b], yf[r]);
            }
        }

        const int N = seg.ntiles * 32;
#pragma unroll
        for (int r = 0; r < TT; ++r) {
            if (r >= nrows) continue;
            const float v = HALF ? (float) (y[r >> 1][r & 1] * gain) : yf[r] * (1.0f / gauge);
            float *out = seg.out + (size_t) r * N + (size_t) tile * 32 + lane;
            if (seg.add) *out += v; else *out = v;
            if (capture && r < CAP_ROWS) {
                if (gu) cap_gate_up[(size_t(si) * CAP_ROWS + r) * FF + tile * 32 + lane] = *out;
                else    cap_x_out[size_t(r) * D + tile * 32 + lane] = *out;
            }
        }
        if (threadIdx.x == 0) atomicAdd((gu ? count_gu : count_down) + layer, 1u);
        __syncthreads();
    }
    end_phase(c);
}

// The two FFN projections are identified by their operand shape and by the phase generation, and
// both have to agree before the carrier takes the phase. A projection the carrier was asked for and
// did not take is counted, so a silent fallback cannot be mistaken for a measured result.
template <int NB, int KS, int TT, bool Q8>
__device__ __forceinline__ void hc_matvec_auto(Ctx &c, const MvR &m, const int8_t *xq,
                                               const float *xs, const int *xsum, int nrows) {
    constexpr bool SHAPE_GU = (NB == NB_D && KS == 1);
    constexpr bool SHAPE_DOWN = (NB == NB_FF && KS == 2);
    if constexpr (Q8 || !(SHAPE_GU || SHAPE_DOWN)) {
        ph_matvec_auto<NB, KS, TT, Q8>(c, m, xq, xs, xsum, nrows);
    } else {
        const bool gu = SHAPE_GU && m.nseg == 2 && m.total_tiles == 2 * (FF / 32);
        const bool dn = SHAPE_DOWN && m.nseg == 1 && m.total_tiles == D / 32;
        int layer = -1;
        if (gu && c.gen >= 9 && (c.gen - 9) % 10 == 0) layer = int((c.gen - 9) / 10);
        if (dn && c.gen >= 11 && (c.gen - 11) % 10 == 0) layer = int((c.gen - 11) / 10);
        const bool wanted = layer >= 0 && layer < 64 && (policy.carrier & (uint64_t(1) << layer)) &&
                            (gu ? policy.carrier_gu : policy.carrier_down);
        const bool possible = (m.total_tiles % NW) == 0;
        if (wanted && possible) {
            if (policy.carrier_fp32 == 2)    hc_matvec<NB, TT, false, true>(c, m, xq, xs, xsum, nrows, layer, gu);
            else if (policy.carrier_fp32 == 1) hc_matvec<NB, TT, false>(c, m, xq, xs, xsum, nrows, layer, gu);
            else                               hc_matvec<NB, TT, true>(c, m, xq, xs, xsum, nrows, layer, gu);
        } else {
            if (wanted && !possible && threadIdx.x == 0 && blockIdx.x == 0)
                atomicAdd(count_declined + layer, 1u);
            ph_matvec_auto<NB, KS, TT, Q8>(c, m, xq, xs, xsum, nrows);
        }
    }
}

}
}

// The engine links this translation unit in place of halo_rows.o. Including the unchanged upstream
// source keeps attention, state, head and barrier ordering intact.
#define ph_prep hc_ffn_prep
#define ph_matvec_auto hc_matvec_auto
#include "halo_rows.hip"
#undef ph_matvec_auto
#undef ph_prep

namespace {
void check(hipError_t e) {
    if (e != hipSuccess) { std::fprintf(stderr, "carrier policy: %s\n", hipGetErrorString(e)); std::abort(); }
}
}
void set_carrier_policy(CarrierPolicy p) { check(hipMemcpyToSymbol(HIP_SYMBOL(policy), &p, sizeof(p))); }
void reset_carrier_counts() {
    unsigned zero[64] = {};
    check(hipMemcpyToSymbol(HIP_SYMBOL(count_quant), zero, sizeof(zero)));
    check(hipMemcpyToSymbol(HIP_SYMBOL(count_gu), zero, sizeof(zero)));
    check(hipMemcpyToSymbol(HIP_SYMBOL(count_down), zero, sizeof(zero)));
    check(hipMemcpyToSymbol(HIP_SYMBOL(count_declined), zero, sizeof(zero)));
}
template <class T, class S> static void fetch(std::vector<T> &dst, const S &sym, size_t n) {
    dst.resize(n);
    check(hipMemcpyFromSymbol(dst.data(), sym, n * sizeof(T)));
}
void read_capture(Capture &c) {
    fetch(c.x_in, HIP_SYMBOL(cap_x_in), 8 * size_t(halo::D));
    fetch(c.xq_in, HIP_SYMBOL(cap_xq_in), 8 * size_t(halo::D));
    fetch(c.xs_in, HIP_SYMBOL(cap_xs_in), 8 * size_t(halo::D / 128));
    fetch(c.gate_up, HIP_SYMBOL(cap_gate_up), 2 * 8 * size_t(halo::FF));
    fetch(c.xq_hidden, HIP_SYMBOL(cap_xq_hid), 8 * size_t(halo::FF));
    fetch(c.xs_hidden, HIP_SYMBOL(cap_xs_hid), 8 * size_t(halo::FF / 128));
    fetch(c.x_out, HIP_SYMBOL(cap_x_out), 8 * size_t(halo::D));
}
void read_carrier_counts(CarrierCounts &c) {
    check(hipMemcpyFromSymbol(c.quant, HIP_SYMBOL(count_quant), sizeof(c.quant)));
    check(hipMemcpyFromSymbol(c.gate_up, HIP_SYMBOL(count_gu), sizeof(c.gate_up)));
    check(hipMemcpyFromSymbol(c.down, HIP_SYMBOL(count_down), sizeof(c.down)));
    check(hipMemcpyFromSymbol(c.declined, HIP_SYMBOL(count_declined), sizeof(c.declined)));
}
