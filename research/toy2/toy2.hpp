#pragma once
#include <hip/hip_runtime.h>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

#define HIP(call) do { auto status = (call); if (status != hipSuccess) { \
  std::fprintf(stderr, "%s: %s\n", #call, hipGetErrorString(status)); std::exit(1); } } while (0)

struct Prepared {
    uint32_t rows[4];
    int biases[2];
    uint32_t fused[2];
    int bias;
    int hi, lo;
};

inline uint32_t nibble_word(const int *values) {
    uint32_t out = 0;
    for (int i = 0; i < 4; ++i) out |= (uint32_t(values[i]) & 15u) << (4 * i);
    return out;
}

inline void trits(int rank, int count, int *out) {
    for (int i = 0; i < count; ++i) { out[i] = rank % 3 - 1; rank /= 3; }
}

inline Prepared prepare(const int *a) {
    Prepared p{};
    constexpr int signs[3][2] = {{1,1}, {1,-1}, {-1,1}};
    for (auto &s : signs) {
        int k0 = s[1] * a[2] + 7 * s[0] * a[0];
        int k1 = s[1] * a[3] + 7 * s[0] * a[1];
        if (-8 <= k0 && k0 <= 7 && -8 <= k1 && k1 <= 7) {
            p.hi = s[0]; p.lo = s[1]; break;
        }
    }
    if (!p.hi) std::abort();
    int row0[4] = {p.hi*a[0], p.hi*a[1], p.hi, 0};
    int row1[4] = {p.lo*a[2], p.lo*a[3], 0, p.lo};
    int fused[4];
    for (int k = 0; k < 4; ++k) fused[k] = row1[k] + 7 * row0[k];
    p.rows[0] = nibble_word(row0); p.rows[1] = nibble_word(row1);
    p.rows[2] = p.rows[0] << 16; p.rows[3] = p.rows[1] << 16;
    p.biases[0] = 3 - p.hi * (a[0] + a[1] + 1);
    p.biases[1] = 3 - p.lo * (a[2] + a[3] + 1);
    p.fused[0] = nibble_word(fused); p.fused[1] = p.fused[0] << 16;
    p.bias = p.biases[1] + 7 * p.biases[0];
    return p;
}

inline uint32_t pack_input(const int *t) {
    uint32_t x = 0;
    for (int k = 0; k < 8; ++k) x |= uint32_t(t[k] + 1) << (2 * k);
    return x;
}

__host__ __device__ inline uint32_t expand(uint32_t x) {
    x = (x | (x << 8)) & 0x00ff00ffu;
    x = (x | (x << 4)) & 0x0f0f0f0fu;
    return (x | (x << 2)) & 0x33333333u;
}

inline uint32_t reference(const int *a, const int *t, const Prepared &p) {
    int d00 = a[0]*t[0] + a[1]*t[1] + t[2];
    int d10 = a[2]*t[0] + a[3]*t[1] + t[3];
    int d01 = a[0]*t[4] + a[1]*t[5] + t[6];
    int d11 = a[2]*t[4] + a[3]*t[5] + t[7];
    return uint32_t(p.lo*d10 + 3 + 7*(p.hi*d00 + 3)) |
           (uint32_t(p.lo*d11 + 3 + 7*(p.hi*d01 + 3)) << 8);
}

__device__ __forceinline__ int dot(uint32_t w, uint32_t x, int c) {
    return __builtin_amdgcn_sudot8(true, int(w), false, int(x), c, false);
}

// Volatile keeps repeated register-resident experiments from becoming one evaluation.
// Early-clobber outputs keep temporaries distinct from every still-live operand.
__device__ __forceinline__ uint32_t elementwise(uint32_t x, const uint32_t *w) {
    uint32_t out, a, b, c, d;
    asm volatile(
        "v_dot8_i32_iu4 %1, %6, %5, %10 neg_lo:[1,0,0]\n\t"
        "v_dot8_i32_iu4 %2, %7, %5, %11 neg_lo:[1,0,0]\n\t"
        "v_dot8_i32_iu4 %3, %8, %5, %10 neg_lo:[1,0,0]\n\t"
        "v_dot8_i32_iu4 %4, %9, %5, %11 neg_lo:[1,0,0]\n\t"
        "v_mad_u32_u24 %1, %1, 7, %2\n\t"
        "v_mad_u32_u24 %3, %3, 7, %4\n\t"
        "v_lshl_or_b32 %0, %3, 8, %1"
        : "=&v"(out), "=&v"(a), "=&v"(b), "=&v"(c), "=&v"(d)
        : "v"(x), "v"(w[0]), "v"(w[1]), "v"(w[2]), "v"(w[3]), "v"(w[4]), "v"(w[5]));
    return out;
}

__device__ __forceinline__ uint32_t packed(uint32_t x, const uint32_t *w) {
    uint32_t out, a, b;
    asm volatile(
        "v_dot8_i32_iu4 %1, %4, %3, %6 neg_lo:[1,0,0]\n\t"
        "v_dot8_i32_iu4 %2, %5, %3, %6 neg_lo:[1,0,0]\n\t"
        "v_lshl_or_b32 %0, %2, 8, %1"
        : "=&v"(out), "=&v"(a), "=&v"(b)
        : "v"(x), "v"(w[0]), "v"(w[1]), "v"(w[2]));
    return out;
}

template<bool Packed>
__device__ __forceinline__ uint32_t evaluate(uint32_t x, const uint32_t *w) {
    if constexpr (Packed) return packed(x, w);
    else return elementwise(x, w);
}
