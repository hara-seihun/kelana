// Native consumer components on gfx1151: does reading a *product of two packed channels* straight
// out of one packed value beat decoding both channels and multiplying?
//
// Every candidate is the exact ISA sequence, written in inline asm, so the compared numbers are
// issue costs of known instruction sequences rather than of whatever the compiler chose. build.sh
// dumps the real assembly next to the results.
//
//   check   exactness of every sequence against an int64 reference, exhaustive where the domain is
//           finite, plus the predicted validity region
//   rate    matched randomized issue-rate comparison, register-resident, per physical SIMD32
//
// Nothing here is an FFN, and the producer of a packed value is not free. `w-pack-fused` includes
// the shift-add that builds p, and `w-bare-mul` is the cost of multiplying two channels that were
// never packed at all.
#include <hip/hip_runtime.h>
#include "../../bench/telemetry.hpp"
#include "../../geometry.hpp"
#include "pack.hpp"
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <random>
#include <string>
#include <vector>

using namespace kelana_dc;

// ---------------------------------------------------------------------------- wide radix, R=65536
// 2 ops: 32-bit square, signed extract of bits [17,31].
__device__ __forceinline__ int w_fused_lo(int p) {
    int r;
    asm volatile("v_mul_lo_u32 %0, %1, %1\n\tv_bfe_i32 %0, %0, 17, 15" : "=v"(r) : "v"(p));
    return r;
}
// 2 ops, both nominally full rate: 24x24 multiply keeping the low 32 bits of a 48-bit product.
__device__ __forceinline__ int w_fused_24(int p) {
    int r;
    asm volatile("v_mul_i32_i24 %0, %1, %1\n\tv_bfe_i32 %0, %0, 17, 15" : "=v"(r) : "v"(p));
    return r;
}
// 4 ops: recover g, recover u, multiply.
__device__ __forceinline__ int w_decode_24(int p) {
    int g, u;
    asm volatile("v_bfe_i32 %0, %2, 0, 16\n\t"
                 "v_add_nc_u32 %1, 0x8000, %2\n\t"
                 "v_ashrrev_i32 %1, 16, %1\n\t"
                 "v_mul_i32_i24 %0, %0, %1"
                 : "=&v"(g), "=&v"(u) : "v"(p));
    return g;
}
__device__ __forceinline__ int w_decode_lo(int p) {
    int g, u;
    asm volatile("v_bfe_i32 %0, %2, 0, 16\n\t"
                 "v_add_nc_u32 %1, 0x8000, %2\n\t"
                 "v_ashrrev_i32 %1, 16, %1\n\t"
                 "v_mul_lo_u32 %0, %0, %1"
                 : "=&v"(g), "=&v"(u) : "v"(p));
    return g;
}
// 4 ops: product, gate sign bit read directly from p, mask. No channel is reconstructed.
__device__ __forceinline__ int w_fused_relu(int p) {
    int r, s;
    asm volatile("v_mul_i32_i24 %0, %2, %2\n\t"
                 "v_bfe_i32 %0, %0, 17, 15\n\t"
                 "v_bfe_i32 %1, %2, 15, 1\n\t"
                 "v_bfi_b32 %0, %1, 0, %0"
                 : "=&v"(r), "=&v"(s) : "v"(p));
    return r;
}
// 5 ops.
__device__ __forceinline__ int w_decode_relu(int p) {
    int g, u;
    asm volatile("v_bfe_i32 %0, %2, 0, 16\n\t"
                 "v_add_nc_u32 %1, 0x8000, %2\n\t"
                 "v_ashrrev_i32 %1, 16, %1\n\t"
                 "v_max_i32 %0, 0, %0\n\t"
                 "v_mul_i32_i24 %0, %0, %1"
                 : "=&v"(g), "=&v"(u) : "v"(p));
    return g;
}
// 3 ops: the fused consumer with its real producer, starting from two separate channel registers.
// g and u arrive in different registers, exactly as they would from two matrix accumulators.
__device__ __forceinline__ int w_pack_fused(int g, int u) {
    int r;
    asm volatile("v_lshl_add_u32 %0, %2, 16, %1\n\t" // p = g + 65536*u
                 "v_mul_i32_i24 %0, %0, %0\n\t"
                 "v_bfe_i32 %0, %0, 17, 15"
                 : "=&v"(r) : "v"(g), "v"(u));
    return r;
}
// 1 op: the same two separate channels, multiplied.
__device__ __forceinline__ int w_sep_mul(int g, int u) {
    int r;
    asm volatile("v_mul_i32_i24 %0, %1, %2" : "=v"(r) : "v"(g), "v"(u));
    return r;
}

// Packed-polynomial rule: P(g+Ru) = P(g) + R*u*P'(g) mod R^2. Toy quartic-SiLU antiderivative
// P(x) = 480x^2 + 80x^3 - x^5, so u*P'(g) = u*(960g + 240g^2 - 5g^4).
// 8 ops, two of them 32-bit multiplies.
__device__ __forceinline__ int w_poly_fused(int p) {
    int t2, t3, r;
    asm volatile("v_mul_i32_i24 %0, %3, %3\n\t"        // t2 = p^2
                 "v_mul_lo_u32 %1, %0, %3\n\t"         // t3 = p^3
                 "v_mul_i32_i24 %2, %3, 80\n\t"        // 80p   (one literal per instruction)
                 "v_add_nc_u32 %2, 0x1e0, %2\n\t"      // 480 + 80p
                 "v_sub_nc_u32 %2, %2, %1\n\t"         // 480 + 80p - p^3
                 "v_mul_lo_u32 %2, %0, %2\n\t"         // P(p) mod 2^32
                 "v_add_nc_u32 %2, 0x8000, %2\n\t"
                 "v_bfe_i32 %2, %2, 16, 16"
                 : "=&v"(t2), "=&v"(t3), "=&v"(r) : "v"(p));
    return r;
}
// 9 ops, all 24-bit: decode both channels, then Horner on the derivative.
__device__ __forceinline__ int w_poly_decode(int p) {
    int g, u, t;
    asm volatile("v_bfe_i32 %0, %3, 0, 16\n\t"
                 "v_add_nc_u32 %1, 0x8000, %3\n\t"
                 "v_ashrrev_i32 %1, 16, %1\n\t"
                 "v_mul_i32_i24 %2, %0, %0\n\t"        // g^2
                 "v_mul_i32_i24 %2, %2, -5\n\t"        // -5g^2
                 "v_add_nc_u32 %2, 240, %2\n\t"        // 240 - 5g^2
                 "v_mad_i32_i24 %2, %0, %2, 960\n\t"   // 960 + 240g - 5g^3
                 "v_mul_i32_i24 %2, %0, %2\n\t"        // 960g + 240g^2 - 5g^4
                 "v_mul_i32_i24 %0, %1, %2"            // u * P'(g)
                 : "=&v"(g), "=&v"(u), "=&v"(t) : "v"(p));
    return g;
}

// ---------------------------------------------------------------------------- narrow radix, R=1024
__device__ __forceinline__ int n_fused(int p) {
    int r;
    asm volatile("v_mul_i32_i24 %0, %1, %1\n\tv_bfe_i32 %0, %0, 11, 9" : "=v"(r) : "v"(p));
    return r;
}
// The single unrepresentable product g*u = +256 is detected from the square itself: p = +-16400,
// p^2 = 0x10080100.
__device__ __forceinline__ int n_fused_guard(int p, int k256) {
    int r, q;
    asm volatile("v_mul_i32_i24 %1, %2, %2\n\t"
                 "v_bfe_i32 %0, %1, 11, 9\n\t"
                 "v_cmp_eq_u32 vcc_lo, 0x10080100, %1\n\t"
                 "v_cndmask_b32 %0, %0, %3, vcc_lo"
                 : "=&v"(r), "=&v"(q) : "v"(p), "v"(k256) : "vcc");
    return r;
}
__device__ __forceinline__ int n_decode(int p) {
    int g, u;
    asm volatile("v_bfe_i32 %0, %2, 0, 10\n\t"
                 "v_add_nc_u32 %1, 0x200, %2\n\t"
                 "v_ashrrev_i32 %1, 10, %1\n\t"
                 "v_mul_i32_i24 %0, %0, %1"
                 : "=&v"(g), "=&v"(u) : "v"(p));
    return g;
}
// Float in, float out: what an FP16 WMMA accumulator actually hands a consumer.
__device__ __forceinline__ float n_fused_f32(float p) {
    float r;
    asm volatile("v_cvt_i32_f32 %0, %1\n\t"
                 "v_mul_i32_i24 %0, %0, %0\n\t"
                 "v_bfe_i32 %0, %0, 11, 9\n\t"
                 "v_cvt_f32_i32 %0, %0"
                 : "=v"(r) : "v"(p));
    return r;
}
__device__ __forceinline__ float n_decode_f32(float p) {
    float g, u;
    asm volatile("v_mul_f32 %1, 0x3a800000, %2\n\t"      // u = p/1024
                 "v_rndne_f32 %1, %1\n\t"
                 "v_fma_f32 %0, %1, 0xc4800000, %2\n\t"  // g = p - 1024u
                 "v_mul_f32 %0, %0, %1"
                 : "=&v"(g), "=&v"(u) : "v"(p));
    return g;
}

// ---------------------------------------------------------------------------- rate probe
// One FP32 WMMA accumulator tile holds eight values per lane, so a real consumer always has eight
// independent inputs in hand. Each candidate is therefore emitted stage by stage across those eight
// chains: one single-instruction asm block per value per stage, in stage-major order. Dependent
// instructions end up eight apart, so what is measured is issue cost rather than gfx11
// dependent-issue bubbles, which inline asm cannot cover with s_delay_alu hints. The one sequence
// that must keep two instructions adjacent is the R=1024 guard, because it routes through VCC.
constexpr int kChains = 8;

#define OP1(NAME, TEXT)                                                                            \
    __device__ __forceinline__ int NAME(int a) {                                                   \
        int r;                                                                                     \
        asm volatile(TEXT : "=v"(r) : "v"(a));                                                     \
        return r;                                                                                  \
    }
#define OP2(NAME, TEXT)                                                                            \
    __device__ __forceinline__ int NAME(int a, int b) {                                            \
        int r;                                                                                     \
        asm volatile(TEXT : "=v"(r) : "v"(a), "v"(b));                                             \
        return r;                                                                                  \
    }

OP1(i_sq24, "v_mul_i32_i24 %0, %1, %1")
OP1(i_sqlo, "v_mul_lo_u32 %0, %1, %1")
OP1(i_bfe_prod_w, "v_bfe_i32 %0, %1, 17, 15")
OP1(i_bfe_prod_n, "v_bfe_i32 %0, %1, 11, 9")
OP1(i_bfe_poly, "v_bfe_i32 %0, %1, 16, 16")
OP1(i_bfe_gate_w, "v_bfe_i32 %0, %1, 0, 16")
OP1(i_bfe_gate_n, "v_bfe_i32 %0, %1, 0, 10")
OP1(i_bfe_sign_w, "v_bfe_i32 %0, %1, 15, 1")
OP1(i_add_half_w, "v_add_nc_u32 %0, 0x8000, %1")
OP1(i_add_half_n, "v_add_nc_u32 %0, 0x200, %1")
OP1(i_ashr16, "v_ashrrev_i32 %0, 16, %1")
OP1(i_ashr10, "v_ashrrev_i32 %0, 10, %1")
OP1(i_max0, "v_max_i32 %0, 0, %1")
OP1(i_mul80, "v_mul_i32_i24 %0, %1, 80")
OP1(i_add480, "v_add_nc_u32 %0, 0x1e0, %1")
OP1(i_muln5, "v_mul_i32_i24 %0, %1, -5")
OP1(i_add240, "v_add_nc_u32 %0, 240, %1")
OP1(i_cvt_i32, "v_cvt_i32_f32 %0, %1")
OP1(i_cvt_f32, "v_cvt_f32_i32 %0, %1")
OP1(f_scale, "v_mul_f32 %0, 0x3a800000, %1")
OP1(f_rndne, "v_rndne_f32 %0, %1")
OP2(i_mul24, "v_mul_i32_i24 %0, %1, %2")
OP2(i_mullo, "v_mul_lo_u32 %0, %1, %2")
OP2(i_sub, "v_sub_nc_u32 %0, %1, %2")
OP2(i_mask_not, "v_bfi_b32 %0, %1, 0, %2")
OP2(i_pack16, "v_lshl_add_u32 %0, %1, 16, %2")
OP2(i_mad960, "v_mad_i32_i24 %0, %1, %2, 960")
OP2(f_mul, "v_mul_f32 %0, %1, %2")
OP2(f_gate, "v_fma_f32 %0, %1, 0xc4800000, %2")

// VCC forces these two to stay adjacent and dependent.
__device__ __forceinline__ int i_guard(int gu, int sq, int k256) {
    int r = gu;
    asm volatile("v_cmp_eq_u32 vcc_lo, 0x10080100, %1\n\t"
                 "v_cndmask_b32 %0, %0, %2, vcc_lo"
                 : "+v"(r) : "v"(sq), "v"(k256) : "vcc");
    return r;
}

#define STAGE for (int c = 0; c < kChains; ++c)
typedef int Tile[kChains];

struct VEmpty {
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) { STAGE o[c] = p[c]; }
};
struct VWSepMul { // channels never packed, held in two registers: one multiply
    __device__ static void run(Tile &g, Tile &u, Tile &o, int) { STAGE o[c] = i_mul24(g[c], u[c]); }
};
struct VWFused24 {
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile t;
        STAGE t[c] = i_sq24(p[c]);
        STAGE o[c] = i_bfe_prod_w(t[c]);
    }
};
struct VWFusedLo {
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile t;
        STAGE t[c] = i_sqlo(p[c]);
        STAGE o[c] = i_bfe_prod_w(t[c]);
    }
};
struct VWDecode24 {
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile g, u;
        STAGE g[c] = i_bfe_gate_w(p[c]);
        STAGE u[c] = i_add_half_w(p[c]);
        STAGE u[c] = i_ashr16(u[c]);
        STAGE o[c] = i_mul24(g[c], u[c]);
    }
};
struct VWDecodeLo {
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile g, u;
        STAGE g[c] = i_bfe_gate_w(p[c]);
        STAGE u[c] = i_add_half_w(p[c]);
        STAGE u[c] = i_ashr16(u[c]);
        STAGE o[c] = i_mullo(g[c], u[c]);
    }
};
struct VWFusedRelu {
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile t, s;
        STAGE t[c] = i_sq24(p[c]);
        STAGE t[c] = i_bfe_prod_w(t[c]);
        STAGE s[c] = i_bfe_sign_w(p[c]);
        STAGE o[c] = i_mask_not(s[c], t[c]);
    }
};
struct VWDecodeRelu {
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile g, u;
        STAGE g[c] = i_bfe_gate_w(p[c]);
        STAGE u[c] = i_add_half_w(p[c]);
        STAGE u[c] = i_ashr16(u[c]);
        STAGE g[c] = i_max0(g[c]);
        STAGE o[c] = i_mul24(g[c], u[c]);
    }
};
struct VWPackFused { // the real producer: pack two separate channel registers, then consume
    __device__ static void run(Tile &g, Tile &u, Tile &o, int) {
        Tile t;
        STAGE t[c] = i_pack16(u[c], g[c]);
        STAGE t[c] = i_sq24(t[c]);
        STAGE o[c] = i_bfe_prod_w(t[c]);
    }
};
struct VWPolyFused { // P(g+Ru) = P(g) + R*u*P'(g) mod R^2, P = 480x^2 + 80x^3 - x^5
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile t2, t3, x;
        STAGE t2[c] = i_sq24(p[c]);
        STAGE t3[c] = i_mullo(t2[c], p[c]);
        STAGE x[c] = i_mul80(p[c]);
        STAGE x[c] = i_add480(x[c]);
        STAGE x[c] = i_sub(x[c], t3[c]);
        STAGE x[c] = i_mullo(t2[c], x[c]);
        STAGE x[c] = i_add_half_w(x[c]);
        STAGE o[c] = i_bfe_poly(x[c]);
    }
};
struct VWPolyDecode { // decode both channels, then Horner on P'(g) = 960g + 240g^2 - 5g^4
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile g, u, t;
        STAGE g[c] = i_bfe_gate_w(p[c]);
        STAGE u[c] = i_add_half_w(p[c]);
        STAGE u[c] = i_ashr16(u[c]);
        STAGE t[c] = i_mul24(g[c], g[c]);
        STAGE t[c] = i_muln5(t[c]);
        STAGE t[c] = i_add240(t[c]);
        STAGE t[c] = i_mad960(g[c], t[c]);
        STAGE t[c] = i_mul24(g[c], t[c]);
        STAGE o[c] = i_mul24(u[c], t[c]);
    }
};
struct VNFused {
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile t;
        STAGE t[c] = i_sq24(p[c]);
        STAGE o[c] = i_bfe_prod_n(t[c]);
    }
};
struct VNFusedGuard {
    __device__ static void run(Tile &p, Tile &q, Tile &o, int k256) {
        Tile t, r;
        STAGE t[c] = i_sq24(p[c]);
        STAGE r[c] = i_bfe_prod_n(t[c]);
        STAGE o[c] = i_guard(r[c], t[c], k256);
    }
};
struct VNDecode {
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile g, u;
        STAGE g[c] = i_bfe_gate_n(p[c]);
        STAGE u[c] = i_add_half_n(p[c]);
        STAGE u[c] = i_ashr10(u[c]);
        STAGE o[c] = i_mul24(g[c], u[c]);
    }
};
struct VNFusedF32 { // float accumulator in, float product out; wrong on g*u = +256
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile t;
        STAGE t[c] = i_cvt_i32(p[c]);
        STAGE t[c] = i_sq24(t[c]);
        STAGE t[c] = i_bfe_prod_n(t[c]);
        STAGE o[c] = i_cvt_f32(t[c]);
    }
};
struct VNFusedF32Guard { // same, with the +-16400 detector, so its domain matches n-decode-f32
    __device__ static void run(Tile &p, Tile &q, Tile &o, int k256) {
        Tile s, t;
        STAGE s[c] = i_cvt_i32(p[c]);
        STAGE s[c] = i_sq24(s[c]);
        STAGE t[c] = i_bfe_prod_n(s[c]);
        STAGE t[c] = i_guard(t[c], s[c], k256);
        STAGE o[c] = i_cvt_f32(t[c]);
    }
};
struct VNDecodeF32 { // all-float decode and multiply
    __device__ static void run(Tile &p, Tile &q, Tile &o, int) {
        Tile g, u;
        STAGE u[c] = f_scale(p[c]);
        STAGE u[c] = f_rndne(u[c]);
        STAGE g[c] = f_gate(u[c], p[c]);
        STAGE o[c] = f_mul(g[c], u[c]);
    }
};
#undef STAGE

// `in` carries the first operand tile and `in2` the second. Packed candidates read only `in`;
// the separate-channel candidates read g from `in` and u from `in2`, so no candidate ever
// manufactures its second operand out of the first.
template <class V> __global__ __launch_bounds__(128) void k_rate(const int *in, const int *in2, int *out, int iters) {
    const int lane = threadIdx.x & 31;
    Tile p, q, acc;
    const int k256 = 256;
#pragma unroll
    for (int c = 0; c < kChains; ++c) {
        p[c] = in[(lane * kChains + c) & 255];
        q[c] = in2[(lane * kChains + c) & 255];
        acc[c] = 0;
    }
#pragma unroll 1
    for (int t = 0; t < iters; ++t) {
#pragma unroll
        for (int c = 0; c < kChains; ++c) { asm volatile("" : "+v"(p[c])); asm volatile("" : "+v"(q[c])); }
        V::run(p, q, acc, k256);
    }
    int s = 0;
#pragma unroll
    for (int c = 0; c < kChains; ++c) s += acc[c];
    out[blockIdx.x * blockDim.x + threadIdx.x] = s;
}

// A whole bounded bilinear output: S = sum_i c_i*p_i^2 in int32 with one extraction at the end,
// against decoding every element. Ternary c; both paths treat c identically, and both carry four
// independent partial sums so the accumulation dependency is not what is being measured.
template <bool FUSED>
__global__ __launch_bounds__(128) void k_bilinear(const int *P, const int *C, int *out, int iters, int fanin) {
    const int base = (threadIdx.x & 31) * 4;
    int S = 0;
#pragma unroll 1
    for (int t = 0; t < iters; ++t) {
        int s[4] = {0, 0, 0, 0};
        for (int i = 0; i < fanin; i += 4) {
#pragma unroll
            for (int j = 0; j < 4; ++j) {
                int p = P[(base + i + j) & 1023], c = C[(base + i + j) & 255], q;
                if (FUSED) {
                    q = i_sq24(p);
                } else {
                    int g = i_bfe_gate_w(p), u = i_ashr16(i_add_half_w(p));
                    q = i_mul24(g, u);
                }
                s[j] += i_mul24(q, c);
            }
        }
        int sum = (s[0] + s[1]) + (s[2] + s[3]);
        S += FUSED ? i_bfe_poly(i_add_half_w(sum)) : sum;
    }
    out[blockIdx.x * blockDim.x + threadIdx.x] = S;
}
// ---------------------------------------------------------------------------- exactness
__global__ void k_check_wide(int glo, int gspan, int ulo, int uspan, unsigned long long *st) {
    long long idx = (long long)blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= (long long)gspan * uspan) return;
    int g = glo + int(idx / uspan), u = ulo + int(idx % uspan);
    int p = g + 65536 * u;
    long long ref = (long long)g * u;
    bool predicted = ((long long)g * g < 131072) && ref >= -16384 && ref < 16384;
    int lo = w_fused_lo(p), m24 = w_fused_24(p), dec = w_decode_24(p);
    int rel = w_fused_relu(p), drel = w_decode_relu(p);
    int packed = w_pack_fused(g, u), sep = w_sep_mul(g, u);
    long long relref = (g > 0 ? (long long)g * u : 0);
    bool ok_lo = lo == ref, ok_24 = m24 == ref;
    if (predicted) {
        if (!ok_lo) atomicAdd(&st[0], 1ull);
        if (!ok_24) atomicAdd(&st[1], 1ull);
        if (rel != relref) atomicAdd(&st[2], 1ull);
        if (dec != ref) atomicAdd(&st[5], 1ull);
        if (drel != relref) atomicAdd(&st[6], 1ull);
        if (g > -128 && g < 128 && (int)(((unsigned)p >> 15) & 1u) != (g < 0 ? 1 : 0)) atomicAdd(&st[7], 1ull);
        atomicAdd(&st[8], 1ull);
        if (packed != ref) atomicAdd(&st[16], 1ull);
        if (sep != ref) atomicAdd(&st[17], 1ull);
    } else {
        if (ok_lo) atomicAdd(&st[3], 1ull);
        if (ok_24) atomicAdd(&st[4], 1ull);
    }
    // is v_mul_i32_i24 exact exactly when p fits a signed 24-bit operand?
    if (predicted) {
        bool p24 = p >= -8388608 && p < 8388608;
        if (p24) {
            atomicAdd(&st[15], 1ull);
            if (!ok_24) atomicAdd(&st[13], 1ull);
        } else if (ok_24) {
            atomicAdd(&st[14], 1ull);
        }
    }
    // claimed domain |g|,|u| <= 127
    if (g >= -127 && g <= 127 && u >= -127 && u <= 127) {
        atomicAdd(&st[9], 1ull);
        if (!ok_lo) atomicAdd(&st[10], 1ull);
        if (!ok_24) atomicAdd(&st[11], 1ull);
        if (rel != relref) atomicAdd(&st[12], 1ull);
        if (packed != ref) atomicAdd(&st[18], 1ull);
        if (sep != ref) atomicAdd(&st[19], 1ull);
    }
}

__global__ void k_check_narrow(int lo, int span, unsigned long long *st) {
    long long idx = (long long)blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= (long long)span * span) return;
    int g = lo + int(idx / span), u = lo + int(idx % span);
    int p = g + 1024 * u;
    long long ref = (long long)g * u;
    bool predicted = ((long long)g * g < 2048) && ref >= -256 && ref < 256;
    int f = n_fused(p), gd = n_fused_guard(p, 256), d = n_decode(p);
    float ff = n_fused_f32(__int2float_rn(p)), fd = n_decode_f32(__int2float_rn(p));
    float ffg = __int2float_rn(n_fused_guard(int(__int2float_rn(p)), 256));
    if (predicted) {
        if (f != ref) atomicAdd(&st[0], 1ull);
        if (d != ref) atomicAdd(&st[1], 1ull);
        if (ff != float(ref)) atomicAdd(&st[2], 1ull);
        if (fd != float(ref)) atomicAdd(&st[3], 1ull);
        atomicAdd(&st[5], 1ull);
    }
    if ((predicted || ref == 256) && gd != ref) atomicAdd(&st[4], 1ull);
    if (g >= -16 && g <= 16 && u >= -16 && u <= 16) {
        if (ffg != float(ref)) atomicAdd(&st[13], 1ull);
        if (fd != float(ref)) atomicAdd(&st[14], 1ull);
        if (ff != float(ref)) atomicAdd(&st[15], 1ull);
    }
    if (ref == 256) atomicAdd(&st[6], 1ull);
    if (ref == 256 && g >= -16 && g <= 16 && u >= -16 && u <= 16) {
        atomicAdd(&st[12], 1ull);
        if (gd != ref) atomicAdd(&st[11], 1ull);
    }
    // the stated FP16 operand domain |g|,|u| <= 16
    if (g >= -16 && g <= 16 && u >= -16 && u <= 16) {
        atomicAdd(&st[7], 1ull);
        if (f != ref) atomicAdd(&st[8], 1ull);
        if (gd != ref) atomicAdd(&st[9], 1ull);
        if (__int2float_rn(p) != float(p)) atomicAdd(&st[10], 1ull);
    }
}

// Packed polynomial: exhaustive over the stated toy domain g in [-3,3], u in [-7,7].
__global__ void k_check_poly(unsigned long long *st) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= 7 * 15) return;
    int g = idx / 15 - 3, u = idx % 15 - 7;
    int p = g + 65536 * u;
    long long gg = (long long)g * g;
    long long dP = 960ll * g + 240ll * gg - 5ll * gg * gg;
    long long ref = (long long)u * dP;
    long long Pg = 480ll * gg + 80ll * gg * g - gg * gg * g;
    int f = w_poly_fused(p), d = w_poly_decode(p);
    if (f != ref) atomicAdd(&st[0], 1ull);
    if (d != ref) atomicAdd(&st[1], 1ull);
    if (!(Pg >= -32768 && Pg < 32768)) atomicAdd(&st[2], 1ull);
    if (!(ref >= -32768 && ref < 32768)) atomicAdd(&st[3], 1ull);
    atomicAdd(&st[4], 1ull);
}

// S = sum c_i p_i^2, one extraction per output, random trials inside the stated bounds.
__global__ void k_check_bilinear(int trials, int fanin, int gbound, unsigned long long *st) {
    int t = blockIdx.x * blockDim.x + threadIdx.x;
    if (t >= trials) return;
    unsigned seed = 0x9e3779b9u * (unsigned)(t + 1);
    auto rnd = [&]() { seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5; return seed; };
    int S = 0;
    long long L = 0, T = 0;
    for (int i = 0; i < fanin; ++i) {
        int g = int(rnd() % (2 * gbound + 1)) - gbound;
        int u = int(rnd() % (2 * gbound + 1)) - gbound;
        int c = int(rnd() % 3) - 1;
        int p = g + 65536 * u, q;
        asm volatile("v_mul_i32_i24 %0, %1, %1\n\tv_mul_i32_i24 %0, %0, %2\n\tv_add_nc_u32 %0, %0, %3"
                     : "=&v"(q) : "v"(p), "v"(c), "v"(S));
        S = q;
        L += (long long)c * g * g;
        T += (long long)c * g * u;
    }
    int r;
    asm volatile("v_add_nc_u32 %0, 0x10000, %1\n\tv_bfe_i32 %0, %0, 17, 15" : "=v"(r) : "v"(S));
    bool in_bounds = L >= -65536 && L < 65536 && T >= -16384 && T < 16384;
    if (in_bounds && r != T) atomicAdd(&st[0], 1ull);
    if (!in_bounds) atomicAdd(&st[1], 1ull);
    atomicAdd(&st[2], 1ull);
}

// ---------------------------------------------------------------------------- harness
template <class T> struct Dev {
    T *p = nullptr;
    size_t n;
    explicit Dev(size_t n_) : n(n_) { hipMalloc(&p, n * sizeof(T)); hipMemset(p, 0, n * sizeof(T)); }
    ~Dev() { hipFree(p); }
    void put(const std::vector<T> &v) { hipMemcpy(p, v.data(), v.size() * sizeof(T), hipMemcpyHostToDevice); }
    std::vector<T> get() const {
        std::vector<T> v(n);
        hipMemcpy(v.data(), p, n * sizeof(T), hipMemcpyDeviceToHost);
        return v;
    }
};

static void die(const char *what) {
    hipError_t e = hipDeviceSynchronize();
    if (e == hipSuccess) e = hipGetLastError();
    if (e != hipSuccess) { fprintf(stderr, "FAIL %s: %s\n", what, hipGetErrorString(e)); exit(1); }
}

static double median(std::vector<double> v) {
    std::sort(v.begin(), v.end());
    return v[v.size() / 2];
}

// Same timing-block record and field names as bench/timing.hpp, so bench/paired_analysis.py reads
// this file without a special case.
struct Block {
    int round, order, first_sample, calls;
    long long begin_ns, end_ns;
    double wall_ms;
};
static std::string blocks_json(const std::vector<Block> &bs) {
    std::ostringstream o;
    o.precision(17);
    o << '[';
    bool first = true;
    for (const auto &b : bs) {
        if (!first) o << ',';
        first = false;
        o << "{\"round\":" << b.round << ",\"order\":" << b.order << ",\"first_sample\":" << b.first_sample
          << ",\"calls\":" << b.calls << ",\"begin_ns\":" << b.begin_ns << ",\"end_ns\":" << b.end_ns
          << ",\"wall_ms\":" << b.wall_ms << '}';
    }
    o << ']';
    return o.str();
}

static float time_ms(const std::function<void()> &f) {
    hipEvent_t a, b;
    hipEventCreate(&a); hipEventCreate(&b);
    hipDeviceSynchronize(); hipEventRecord(a);
    f();
    hipEventRecord(b); hipEventSynchronize(b);
    float ms = 0; hipEventElapsedTime(&ms, a, b);
    hipEventDestroy(a); hipEventDestroy(b);
    return ms;
}

int main(int argc, char **argv) {
    std::string mode = argc > 1 ? argv[1] : "check";
    hipDeviceProp_t prop{};
    hipGetDeviceProperties(&prop, 0);
    const auto geom = kelana_batch::geometry(prop);
    printf("{\"device\":\"%s\",\"hip_multiprocessor_count\":%d,\"wgps\":%d,\"cus\":%d,\"simd32_count\":%d,\n",
           prop.gcnArchName, geom.hip_processors, geom.wgps, geom.cus, geom.simds);

    if (mode == "check") {
        const int glo = -400, gspan = 801, ulo = -2048, uspan = 4097;
        Dev<unsigned long long> ws(24);
        long long cases = (long long)gspan * uspan;
        k_check_wide<<<(cases + 255) / 256, 256>>>(glo, gspan, ulo, uspan, ws.p);
        die("check_wide");
        auto w = ws.get();
        printf("\"wide\":{\"box\":\"g[%d,%d] u[%d,%d]\",\"cases\":%lld,\"in_predicted_region\":%llu,\n",
               glo, glo + gspan - 1, ulo, ulo + uspan - 1, cases, w[8]);
        printf(" \"fail_in_predicted_region\":{\"fused_mul_lo\":%llu,\"fused_mul_i24\":%llu,\"fused_relu\":%llu,\"decode\":%llu,\"decode_relu\":%llu},\n",
               w[0], w[1], w[2], w[5], w[6]);
        printf(" \"correct_outside_predicted_region\":{\"fused_mul_lo\":%llu,\"fused_mul_i24\":%llu},\n", w[3], w[4]);
        printf(" \"gate_sign_bit_failures\":%llu,\n", w[7]);
        printf(" \"mul_i24_vs_24bit_operand\":{\"cases_with_p_in_24_bits\":%llu,\"fail_with_p_in_24_bits\":%llu,\"correct_with_p_over_24_bits\":%llu},\n",
               w[15], w[13], w[14]);
        printf(" \"producer_sequences\":{\"pack_then_fused_fail_in_predicted_region\":%llu,\"separate_multiply_fail_in_predicted_region\":%llu,\"pack_then_fused_fail_in_claimed_domain\":%llu,\"separate_multiply_fail_in_claimed_domain\":%llu},\n",
               w[16], w[17], w[18], w[19]);
        printf(" \"claimed_domain_127\":{\"cases\":%llu,\"fail_fused_mul_lo\":%llu,\"fail_fused_mul_i24\":%llu,\"fail_fused_relu\":%llu}},\n",
               w[9], w[10], w[11], w[12]);

        const int nlo = -64, nspan = 129;
        Dev<unsigned long long> ns(24);
        k_check_narrow<<<(nspan * nspan + 255) / 256, 256>>>(nlo, nspan, ns.p);
        die("check_narrow");
        auto n = ns.get();
        printf("\"narrow\":{\"box\":\"g,u[%d,%d]\",\"in_predicted_region\":%llu,\"gu_eq_256_cases\":%llu,\n",
               nlo, nlo + nspan - 1, n[5], n[6]);
        printf(" \"fail_in_predicted_region\":{\"fused\":%llu,\"decode\":%llu,\"fused_f32\":%llu,\"decode_f32\":%llu},\n",
               n[0], n[1], n[2], n[3]);
        printf(" \"guard_failures_including_gu_256\":%llu,\n", n[4]);
        printf(" \"float_paths_over_claimed_domain_16\":{\"cases\":1089,\"fused_f32_guarded\":%llu,\"decode_f32\":%llu,\"fused_f32_unguarded\":%llu},\n",
               n[13], n[14], n[15]);
        printf(" \"claimed_domain_16\":{\"cases\":%llu,\"fail_fused\":%llu,\"fail_guarded\":%llu,\"p_not_exact_in_f32\":%llu,\"gu_256_cases\":%llu,\"guard_fail_on_gu_256\":%llu}},\n",
               n[7], n[8], n[9], n[10], n[12], n[11]);

        Dev<unsigned long long> ps(8);
        k_check_poly<<<1, 128>>>(ps.p);
        die("check_poly");
        auto pp = ps.get();
        printf("\"poly\":{\"cases\":%llu,\"fail_fused\":%llu,\"fail_decode\":%llu,\"low_part_out_of_range\":%llu,\"high_part_out_of_range\":%llu},\n",
               pp[4], pp[0], pp[1], pp[2], pp[3]);

        const int trials = 1 << 20, fanin = 128, gbound = 7;
        Dev<unsigned long long> bs(8);
        k_check_bilinear<<<(trials + 255) / 256, 256>>>(trials, fanin, gbound, bs.p);
        die("check_bilinear");
        auto b = bs.get();
        printf("\"bilinear\":{\"trials\":%llu,\"fanin\":%d,\"channel_bound\":%d,\"failures_in_bounds\":%llu,\"out_of_bounds_trials\":%llu}\n",
               b[2], fanin, gbound, b[0], b[1]);
        printf("}\n");
        // Expected nonzero counts are characterizations, not failures: fused_mul_i24 outside a
        // signed 24-bit p (w[1], w[14], w[16]), the unguarded R=1024 sequence on g*u = +256
        // (n[8], n[15]) and the domain-specific +-16400 detector outside its domain (n[4]).
        return (w[0] || w[5] || w[6] || w[7] || w[10] || w[11] || w[12] || w[13] || w[18] || w[19] || n[0] ||
                n[1] || n[2] || n[3] || n[9] || n[11] || n[13] || n[14] || pp[0] || pp[1] || pp[2] || pp[3] || b[0] || b[1])
                   ? 2
                   : 0;
    }

    // ---------------------------------------------------------------------- rate mode
    // Randomized warmed blocks, every sample retained with its round and position, GPU clock and
    // power telemetry recorded across each group. The JSON is kelana-batch-bench/2 so
    // ../../bench/paired_analysis.py reads it directly; `rows` carries waves per SIMD32 for the
    // consumer groups and 1 for the bilinear component group.
    const int iters = argc > 2 ? atoi(argv[2]) : 4000;
    const int rounds = argc > 3 ? atoi(argv[3]) : 15;
    const int calls = argc > 4 ? atoi(argv[4]) : 3;
    const unsigned seed = argc > 5 ? unsigned(atoi(argv[5])) : 20260915u;
    const int threads = 128, block_waves = 4;
    std::mt19937 rng(seed);
    std::vector<int> wide_p(256), wide_g(256), wide_u(256), narrow_p(256), narrow_f(256);
    for (int i = 0; i < 256; ++i) {
        int g = int(rng() % 255) - 127, u = int(rng() % 255) - 127;
        wide_p[i] = g + 65536 * u;
        wide_g[i] = g;
        wide_u[i] = u;
        int gn = int(rng() % 33) - 16, un = int(rng() % 33) - 16;
        narrow_p[i] = gn + 1024 * un;
        float f = float(narrow_p[i]);
        std::memcpy(&narrow_f[i], &f, 4);
    }
    const int bfanin = 128, bouts = 200;
    std::vector<int> bp(1024), bc(256);
    for (int i = 0; i < 1024; ++i) {
        int g = int(rng() % 15) - 7, u = int(rng() % 15) - 7;
        bp[i] = g + 65536 * u;
    }
    for (int i = 0; i < 256; ++i) bc[i] = int(rng() % 3) - 1;
    Dev<int> dw(256), dg(256), du(256), dn(256), dnf(256), dout(1 << 16), dbp(1024), dbc(256);
    dw.put(wide_p); dg.put(wide_g); du.put(wide_u);
    dn.put(narrow_p); dnf.put(narrow_f); dbp.put(bp); dbc.put(bc);

    struct Cand {
        std::string name;
        int ops;
        std::string note;
        int rows;    // waves per SIMD32, or 1 for the bilinear group
        int grid;
        double apps;  // consumer applications, or accumulated terms, per launch
        std::function<void()> launch;
        std::vector<double> ms;
        std::vector<Block> blocks;
    };
    std::vector<Cand> cands;
    // buf 0 packed wide, 1 packed narrow, 2 packed narrow as float, 3 separate channels g and u
    auto add_rate = [&](const char *name, int ops, const char *note, int buf, int wps, auto tag) {
        using V = decltype(tag);
        const int *in = buf == 0 ? dw.p : (buf == 1 ? dn.p : (buf == 2 ? dnf.p : dg.p));
        const int *in2 = buf == 3 ? du.p : in;
        int *o = dout.p, grid = geom.simds * wps / block_waves;
        cands.push_back({name, ops, note, wps, grid, double(iters) * kChains,
                         [=] { k_rate<V><<<grid, threads>>>(in, in2, o, iters); }, {}, {}});
    };
    for (int wps : {2, 8}) {
        add_rate("empty", 0, "loop overhead only", 0, wps, VEmpty{});
        add_rate("w-sep-mul", 1, "separate g,u registers: one v_mul_i32_i24", 3, wps, VWSepMul{});
        add_rate("w-fused-24", 2, "v_mul_i32_i24 square + v_bfe_i32", 0, wps, VWFused24{});
        add_rate("w-fused-lo", 2, "v_mul_lo_u32 square + v_bfe_i32", 0, wps, VWFusedLo{});
        add_rate("w-decode-24", 4, "decode g,u then v_mul_i32_i24", 0, wps, VWDecode24{});
        add_rate("w-decode-lo", 4, "decode g,u then v_mul_lo_u32", 0, wps, VWDecodeLo{});
        add_rate("w-fused-relu", 4, "product + gate sign bit mask", 0, wps, VWFusedRelu{});
        add_rate("w-decode-relu", 5, "decode, v_max_i32, multiply", 0, wps, VWDecodeRelu{});
        add_rate("w-pack-fused", 3, "separate g,u: v_lshl_add_u32 producer then the fused consumer", 3, wps, VWPackFused{});
        add_rate("w-poly-fused", 8, "packed quartic, two 32-bit multiplies", 0, wps, VWPolyFused{});
        add_rate("w-poly-decode", 9, "decode then Horner on P'", 0, wps, VWPolyDecode{});
        add_rate("n-fused", 2, "R=1024 square + v_bfe_i32(11,9)", 1, wps, VNFused{});
        add_rate("n-fused-guard", 4, "R=1024 with the g*u=+256 detector", 1, wps, VNFusedGuard{});
        add_rate("n-decode", 4, "R=1024 decode then multiply", 1, wps, VNDecode{});
        add_rate("n-fused-f32", 4, "float in/out, domain excludes g*u=+256", 2, wps, VNFusedF32{});
        add_rate("n-fused-f32-guard", 6, "float in/out, guarded, domain matches n-decode-f32", 2, wps, VNFusedF32Guard{});
        add_rate("n-decode-f32", 4, "float decode then multiply", 2, wps, VNDecodeF32{});
    }
    {
        int grid = geom.simds * 8 / block_waves;
        double terms = double(bouts) * bfanin;
        const int *P = dbp.p, *C = dbc.p;
        int *o = dout.p;
        cands.push_back({"bilinear-fused", 0, "sum c*p^2, one extraction per output", 1, grid, terms,
                         [=] { k_bilinear<true><<<grid, threads>>>(P, C, o, bouts, bfanin); }, {}, {}});
        cands.push_back({"bilinear-decode", 0, "decode every element", 1, grid, terms,
                         [=] { k_bilinear<false><<<grid, threads>>>(P, C, o, bouts, bfanin); }, {}, {}});
    }

    std::string clients_before = kbtelemetry::client_snapshot();
    // The first measured group otherwise runs while the GPU is still ramping: an unramped run
    // records 0.625 GHz at the start and 2.6 GHz at the end, which is a larger effect than any
    // difference being measured. Spin before each group and record the ramp in the telemetry trace.
    auto ramp = [&](double seconds) {
        int grid = geom.simds * 8 / block_waves;
        auto t0 = std::chrono::steady_clock::now();
        while (std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count() < seconds) {
            for (int k = 0; k < 8; ++k) k_rate<VWPolyFused><<<grid, threads>>>(dw.p, dw.p, dout.p, iters);
            hipDeviceSynchronize();
        }
        die("ramp");
    };
    ramp(2.0);
    std::vector<std::pair<int, std::string>> traces;
    for (int rows : {2, 8, 1}) {
        std::vector<int> group;
        for (size_t i = 0; i < cands.size(); ++i) if (cands[i].rows == rows) group.push_back(int(i));
        ramp(0.5);
        kbtelemetry::Recorder recorder(prop.pciDomainID, prop.pciBusID, prop.pciDeviceID);
        for (int round = 0; round < rounds; ++round) {
            std::shuffle(group.begin(), group.end(), rng);
            for (size_t position = 0; position < group.size(); ++position) {
                Cand &c = cands[group[position]];
                for (int k = 0; k < (round == 0 ? 3 : 2); ++k) c.launch();
                hipDeviceSynchronize();
                die(c.name.c_str());
                std::vector<hipEvent_t> a(calls), b(calls);
                for (int k = 0; k < calls; ++k) { hipEventCreate(&a[k]); hipEventCreate(&b[k]); }
                Block blk{round, int(position), int(c.ms.size()), calls, kbtelemetry::now_ns(), 0, 0};
                for (int k = 0; k < calls; ++k) {
                    hipEventRecord(a[k]);
                    c.launch();
                    hipEventRecord(b[k]);
                }
                hipDeviceSynchronize();
                die(c.name.c_str());
                blk.end_ns = kbtelemetry::now_ns();
                blk.wall_ms = (blk.end_ns - blk.begin_ns) * 1e-6;
                c.blocks.push_back(blk);
                for (int k = 0; k < calls; ++k) {
                    float ms = 0;
                    hipEventElapsedTime(&ms, a[k], b[k]);
                    c.ms.push_back(ms);
                    hipEventDestroy(a[k]); hipEventDestroy(b[k]);
                }
            }
        }
        traces.emplace_back(rows, recorder.json());
    }

    printf("\"format\":\"kelana-batch-bench/2\",\n"
           "\"schedule\":\"randomized warmed candidate blocks within each round, every sample retained\",\n"
           "\"rows_meaning\":\"waves per SIMD32 for the consumer groups; 1 for the bilinear component group\",\n"
           "\"isolation\":\"../../hardware-run serializes participating research workers only. Other GPU clients and host power competition are not excluded.\",\n"
           "\"clock_ramp\":\"2s of dispatch before the first group and 0.5s before each group; the trace still records what the clock did\",\n"
           "\"rounds\":%d,\"calls_per_block\":%d,\"seed\":%u,\"iters\":%d,\"chains\":%d,\n"
           "\"bilinear\":{\"fanin\":%d,\"outputs_per_lane\":%d},\n"
           "\"gpu_clients_before\":%s,\n\"runs\":[\n",
           rounds, calls, seed, iters, kChains, bfanin, bouts, clients_before.c_str());
    for (size_t i = 0; i < cands.size(); ++i) {
        Cand &c = cands[i];
        double med = median(c.ms), mean = 0;
        for (double v : c.ms) mean += v;
        mean /= c.ms.size();
        double ns_wave = med * 1e6 / c.apps;
        printf(" {\"candidate\":\"%s\",\"rows\":%d,\"ops\":%d,\"note\":\"%s\",\"grid\":%d,"
               "\"applications_per_launch\":%.0f,\"ms_median\":%.6f,\"ms_mean\":%.6f,"
               "\"ms_min\":%.6f,\"ms_max\":%.6f,"
               "\"ns_per_application_per_wave\":%.4f,\"ns_per_application_per_simd32\":%.4f,\n"
               "  \"timing_blocks\":%s,\n  \"ms_samples\":[",
               c.name.c_str(), c.rows, c.ops, c.note.c_str(), c.grid, c.apps, med, mean,
               *std::min_element(c.ms.begin(), c.ms.end()), *std::max_element(c.ms.begin(), c.ms.end()),
               ns_wave, c.rows == 1 ? ns_wave : ns_wave / c.rows, blocks_json(c.blocks).c_str());
        for (size_t k = 0; k < c.ms.size(); ++k) printf("%s%.6f", k ? "," : "", c.ms[k]);
        printf("]}%s\n", i + 1 == cands.size() ? "" : ",");
        fprintf(stderr, "%-16s rows=%d ops=%d median %9.4f ms  %7.4f ns/app/SIMD32\n", c.name.c_str(),
                c.rows, c.ops, med, c.rows == 1 ? ns_wave : ns_wave / c.rows);
    }
    printf("],\n\"telemetry\":[");
    for (size_t i = 0; i < traces.size(); ++i)
        printf("%s{\"rows\":%d,\"trace\":%s}", i ? "," : "", traces[i].first, traces[i].second.c_str());
    printf("],\n\"gpu_clients_after\":%s\n}\n", kbtelemetry::client_snapshot().c_str());
    return 0;
}
