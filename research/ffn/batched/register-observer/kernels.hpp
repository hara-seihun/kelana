// Shared kernels for the register-resident PERM observer experiments.
//
// The map: for one activation pair (a1,a2) of one token, the eight dynamic bytes of a PERM
// operand pair hold the eight nonzero two-trit outcomes biased by 14,
//
//   lo = [ a1+a2 | a1-a2 | a1 | a2 ] + 14      hi = 0x1c1c1c1c - lo   (bytewise, no borrow)
//
// and a weight selector byte, prepared offline from two ternary weights of one output row, names
// one of them, or 12 for the (0,0) pattern which PERM answers with 0x00. One PERM therefore
// delivers four output rows x two weights = 8 MAC into carry-free unsigned byte lanes. The
// missing 14 per zero pattern is an offline per-(row, block) constant.
//
// Every kernel here is register-resident on purpose: no memory traffic, no LDS, no epilogue.
#pragma once
#include <hip/hip_runtime.h>

using int2v = int __attribute__((ext_vector_type(2)));
using int8v = int __attribute__((ext_vector_type(8)));

__device__ __forceinline__ unsigned perm(unsigned hi, unsigned lo, unsigned sel) {
    return __builtin_amdgcn_perm(hi, lo, sel);
}
__device__ __forceinline__ unsigned add3(unsigned a, unsigned b, unsigned c) {
    unsigned r;
    asm("v_add3_u32 %0, %1, %2, %3" : "=v"(r) : "v"(a), "v"(b), "v"(c));
    return r;
}

// ---------------------------------------------------------------- IU4 WMMA baseline
// Independent accumulator chains are the variable: two dependent chains can be latency-limited
// rather than issue-limited, so CHAINS is swept and the highest rate is the issue rate.
template <int CHAINS>
__global__ __launch_bounds__(128) void k_iu4(const int2v *A, const int2v *B, int *out, int iters) {
    int lane = threadIdx.x & 31;
    int2v a = A[lane], b = B[lane];
    int8v C[CHAINS];
#pragma unroll
    for (int c = 0; c < CHAINS; ++c) C[c] = int8v{};
#pragma unroll 1
    for (int t = 0; t < iters; ++t) {
#pragma unroll
        for (int s = 0; s < 8; ++s) {
            asm volatile("" : "+v"(a), "+v"(b));
#pragma unroll
            for (int c = 0; c < CHAINS; ++c)
                C[c] = __builtin_amdgcn_wmma_i32_16x16x16_iu4_w32(true, a, true, b, C[c], false);
        }
    }
    int acc = 0;
#pragma unroll
    for (int c = 0; c < CHAINS; ++c)
#pragma unroll
        for (int r = 0; r < 8; ++r) acc += C[c][r];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

// ------------------------------------------------------- PERM issue rate, no dependencies
__global__ __launch_bounds__(128) void k_perm_raw(const unsigned *in, unsigned *out, int iters) {
    int lane = threadIdx.x & 31;
    unsigned lo = in[lane], hi = in[lane + 32], s0 = in[lane + 64], s1 = in[lane + 96];
    unsigned r[8];
#pragma unroll
    for (int i = 0; i < 8; ++i) r[i] = 0;
#pragma unroll 1
    for (int t = 0; t < iters; ++t) {
#pragma unroll
        for (int s = 0; s < 4; ++s) {
            asm volatile("v_perm_b32 %0, %8, %9, %10\n\t"
                         "v_perm_b32 %1, %8, %9, %11\n\t"
                         "v_perm_b32 %2, %9, %8, %10\n\t"
                         "v_perm_b32 %3, %9, %8, %11\n\t"
                         "v_perm_b32 %4, %8, %9, %11\n\t"
                         "v_perm_b32 %5, %8, %9, %10\n\t"
                         "v_perm_b32 %6, %9, %8, %11\n\t"
                         "v_perm_b32 %7, %9, %8, %10"
                         : "=v"(r[0]), "=v"(r[1]), "=v"(r[2]), "=v"(r[3]), "=v"(r[4]),
                           "=v"(r[5]), "=v"(r[6]), "=v"(r[7])
                         : "v"(hi), "v"(lo), "v"(s0), "v"(s1));
        }
    }
    unsigned acc = 0;
#pragma unroll
    for (int i = 0; i < 8; ++i) acc += r[i];
    out[blockIdx.x * blockDim.x + threadIdx.x] = acc;
}

// ------------------------------------------- ceiling: PERM + ADD3 only, tables handed over
// RQ row quads (4 output rows each) x T tokens. Two activation pairs per ADD3.
// MAC per inner step = RQ*4 rows * T tokens * 2 pairs * 2 weights.
template <int RQ, int T>
__global__ __launch_bounds__(128) void k_core(const unsigned *in, unsigned *out, int iters) {
    int lane = threadIdx.x & 31;
    unsigned lo[T], hi[T], sel[RQ][2], acc[T][RQ];
#pragma unroll
    for (int t = 0; t < T; ++t) {
        lo[t] = in[(lane + t) & 31];
        hi[t] = 0x1c1c1c1cu - lo[t];
#pragma unroll
        for (int q = 0; q < RQ; ++q) acc[t][q] = 0;
    }
#pragma unroll
    for (int q = 0; q < RQ; ++q) {
        sel[q][0] = in[32 + ((lane + q) & 31)];
        sel[q][1] = in[64 + ((lane + q) & 31)];
    }
#pragma unroll 1
    for (int it = 0; it < iters; ++it) {
#pragma unroll
        for (int t = 0; t < T; ++t) asm volatile("" : "+v"(lo[t]), "+v"(hi[t]));
#pragma unroll
        for (int t = 0; t < T; ++t)
#pragma unroll
            for (int q = 0; q < RQ; ++q) {
                unsigned p0 = perm(hi[t], lo[t], sel[q][0]);
                unsigned p1 = perm(hi[t], lo[t], sel[q][1]);
                acc[t][q] = add3(acc[t][q], p0, p1);
            }
    }
    unsigned s = 0;
#pragma unroll
    for (int t = 0; t < T; ++t)
#pragma unroll
        for (int q = 0; q < RQ; ++q) s += acc[t][q];
    out[blockIdx.x * blockDim.x + threadIdx.x] = s;
}

// ------------------- best conceivable schedule: free tables, mandatory accumulate and drain
// Same inner loop as k_core plus the byte-lane drain that a 128-input block forces every eight
// pairs. Table construction is deleted outright, so no schedule of this family can beat it.
template <int RQ, int T>
__global__ __launch_bounds__(128) void k_drain(const unsigned *in, unsigned *out, int iters) {
    int lane = threadIdx.x & 31;
    // Four distinct tables per token, one per activation pair in the window. They must differ
    // across the window or the compiler common-subexpressions the PERMs away and the kernel
    // stops representing the schedule.
    unsigned lo[T][4], hi[T][4], sel[RQ][2], acc[T][RQ], w0[T][RQ], w1[T][RQ];
#pragma unroll
    for (int t = 0; t < T; ++t) {
#pragma unroll
        for (int j = 0; j < 4; ++j) {
            lo[t][j] = in[(lane + t * 4 + j) & 31];
            hi[t][j] = 0x1c1c1c1cu - lo[t][j];
        }
#pragma unroll
        for (int q = 0; q < RQ; ++q) { acc[t][q] = 0; w0[t][q] = 0; w1[t][q] = 0; }
    }
#pragma unroll
    for (int q = 0; q < RQ; ++q) {
        sel[q][0] = in[32 + ((lane + q) & 31)];
        sel[q][1] = in[64 + ((lane + q) & 31)];
    }
#pragma unroll 1
    for (int it = 0; it < iters; ++it) {
#pragma unroll
        for (int t = 0; t < T; ++t)
#pragma unroll
            for (int j = 0; j < 4; ++j) asm volatile("" : "+v"(lo[t][j]), "+v"(hi[t][j]));
#pragma unroll
        for (int j = 0; j < 4; ++j)
#pragma unroll
            for (int t = 0; t < T; ++t)
#pragma unroll
                for (int q = 0; q < RQ; ++q) {
                    unsigned p0 = perm(hi[t][j], lo[t][j], sel[q][0]);
                    unsigned p1 = perm(hi[t][j], lo[t][j], sel[q][1]);
                    // first window step writes instead of accumulating, so no reset is needed
                    acc[t][q] = j == 0 ? add3(0u, p0, p1) : add3(acc[t][q], p0, p1);
                }
#pragma unroll
        for (int t = 0; t < T; ++t)
#pragma unroll
            for (int q = 0; q < RQ; ++q) {
                w0[t][q] += perm(0u, acc[t][q], 0x0c020c00u);
                w1[t][q] += perm(0u, acc[t][q], 0x0c030c01u);
            }
    }
    unsigned s = 0;
#pragma unroll
    for (int t = 0; t < T; ++t)
#pragma unroll
        for (int q = 0; q < RQ; ++q) s += w0[t][q] + w1[t][q];
    out[blockIdx.x * blockDim.x + threadIdx.x] = s;
}

// ---------------------------------------------------------------- production table build
// Four biased activations x = a+7 packed as bytes give both tables of two pairs in ten
// instructions, with no carry or borrow crossing a byte:
//   U  = X + 0x07070707            bytes a_i + 14
//   S  = X + (X >> 8)              byte 0 = a1+a2+14, byte 2 = a3+a4+14
//   D  = (X + 0x0e0e0e0e) - (X>>8) byte 0 = a1-a2+14, byte 2 = a3-a4+14
//   SD = perm(S, D, 0x02060004)    [S0 D0 S2 D2]
//   lo0 = perm(SD, U, 0x01000504)  [s14 d14 u1 u2]      lo1 = perm(SD, U, 0x03020706)
//   hi  = 0x1c1c1c1c - lo
struct Tables { unsigned lo0, hi0, lo1, hi1; };
__device__ __forceinline__ Tables build(unsigned X) {
    unsigned U = X + 0x07070707u;
    unsigned X8 = X >> 8;
    unsigned S = X + X8;
    unsigned D = (X + 0x0e0e0e0eu) - X8;
    unsigned SD = perm(S, D, 0x02060004u);
    Tables t;
    t.lo0 = perm(SD, U, 0x01000504u);
    t.hi0 = 0x1c1c1c1cu - t.lo0;
    t.lo1 = perm(SD, U, 0x03020706u);
    t.hi1 = 0x1c1c1c1cu - t.lo1;
    return t;
}

// ------------------------------------------------ full inner loop: table build + unpack
// One iteration covers eight activation pairs (16 activations of a 128-block) for T tokens
// and RQ row quads, including the per-token table construction and the byte-lane drain.
template <int RQ, int T>
__global__ __launch_bounds__(128) void k_full(const unsigned *in, unsigned *out, int iters) {
    int lane = threadIdx.x & 31;
    unsigned acc[T][RQ], w0[T][RQ], w1[T][RQ];
    unsigned sel[RQ][2];
    unsigned X[T][4];  // 16 biased activations per token, the step's slice of the block
#pragma unroll
    for (int t = 0; t < T; ++t) {
#pragma unroll
        for (int q = 0; q < RQ; ++q) { acc[t][q] = 0; w0[t][q] = 0; w1[t][q] = 0; }
#pragma unroll
        for (int j = 0; j < 4; ++j) X[t][j] = in[(lane + t * 4 + j) & 31] & 0x0e0e0e0eu;
    }
#pragma unroll
    for (int q = 0; q < RQ; ++q) {
        sel[q][0] = in[32 + ((lane + q) & 31)];
        sel[q][1] = in[64 + ((lane + q) & 31)];
    }
#pragma unroll 1
    for (int it = 0; it < iters; ++it) {
#pragma unroll
        for (int t = 0; t < T; ++t)
#pragma unroll
            for (int j = 0; j < 4; ++j) asm volatile("" : "+v"(X[t][j]));
#pragma unroll
        for (int j = 0; j < 4; ++j) {
            Tables tb[T];
#pragma unroll
            for (int t = 0; t < T; ++t) tb[t] = build(X[t][j]);
#pragma unroll
            for (int t = 0; t < T; ++t)
#pragma unroll
                for (int q = 0; q < RQ; ++q) {
                    unsigned p0 = perm(tb[t].hi0, tb[t].lo0, sel[q][0]);
                    unsigned p1 = perm(tb[t].hi1, tb[t].lo1, sel[q][1]);
                    acc[t][q] = add3(acc[t][q], p0, p1);
                }
        }
        // drain byte lanes into 16-bit lanes once per eight pairs
#pragma unroll
        for (int t = 0; t < T; ++t)
#pragma unroll
            for (int q = 0; q < RQ; ++q) {
                w0[t][q] += acc[t][q] & 0x00ff00ffu;
                w1[t][q] += (acc[t][q] >> 8) & 0x00ff00ffu;
                acc[t][q] = 0;
            }
    }
    unsigned s = 0;
#pragma unroll
    for (int t = 0; t < T; ++t)
#pragma unroll
        for (int q = 0; q < RQ; ++q) s += w0[t][q] + w1[t][q];
    out[blockIdx.x * blockDim.x + threadIdx.x] = s;
}

// ---------------------------------------------------------------------------- correctness
// One wave computes 4 output rows x T tokens over K ternary weights with the observer, and
// the host checks the exact integer dot products.
__global__ void k_check(const unsigned *sel, const unsigned *actx, int *out, int rows4, int K) {
    // actx[m] packs four biased activations x = a+7 of one token; sel[k/2] is one selector
    // dword covering four output rows.
    unsigned accw0 = 0, accw1 = 0, acc = 0;
    int steps = 0;
    for (int k = 0; k < K; k += 4) {
        Tables tb = build(actx[k / 4]);
        acc += perm(tb.hi0, tb.lo0, sel[k / 2]);
        ++steps;
        acc += perm(tb.hi1, tb.lo1, sel[k / 2 + 1]);
        if (++steps == 8) {
            accw0 += acc & 0x00ff00ffu;
            accw1 += (acc >> 8) & 0x00ff00ffu;
            acc = 0; steps = 0;
        }
    }
    accw0 += acc & 0x00ff00ffu;
    accw1 += (acc >> 8) & 0x00ff00ffu;
    out[0] = int(accw0 & 0xffffu);          // row 0 biased sum
    out[1] = int(accw1 & 0xffffu);          // row 1
    out[2] = int((accw0 >> 16) & 0xffffu);  // row 2
    out[3] = int((accw1 >> 16) & 0xffffu);  // row 3
    (void)rows4;
}

