// What the region's arithmetic can cost at best on this device: the sustained rate of the exact
// instruction mix the projections issue, with no memory traffic at all.
//
//   wmma   : v_wmma_i32_16x16x16_iu8_w32 back to back, the ceiling for the projections.
//   decode : the HALO block decode (peel chain) alone.
//   mixed  : one block decode followed by the WMMA work that block feeds at a given panel width,
//            which is the ratio the candidates actually issue.
#include <hip/hip_runtime.h>
#include "halo_kernels.h"
#include "device.hpp"
#include <algorithm>
#include <cstdio>
#include <vector>

using namespace halo;

typedef int v4i __attribute__((ext_vector_type(4)));
typedef int v8i __attribute__((ext_vector_type(8)));

__global__ void k_wmma(int iters, int * sink) {
    v8i C0 = {0,0,0,0,0,0,0,0}, C1 = C0, C2 = C0, C3 = C0;
    v4i A = { (int) (threadIdx.x * 7 + 1), 0x01020304, 0x05060708, 0x090a0b0c };
    v4i B = { (int) (threadIdx.x * 3 + 2), 0x0c0b0a09, 0x08070605, 0x04030201 };
    for (int i = 0; i < iters; i++) {
        C0 = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, A, true, B, C0, false);
        C1 = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, A, true, B, C1, false);
        C2 = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, A, true, B, C2, false);
        C3 = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, A, true, B, C3, false);
    }
    if (sink) sink[threadIdx.x] = C0[0] + C1[1] + C2[2] + C3[3];
}

__device__ __forceinline__ void decode_once(uint4 qa, uint2 qb, unsigned tail, unsigned tr[32]) {
    const unsigned dw[6] = { qa.x, qa.y, qa.z, qa.w, qb.x, qb.y };
    #pragma unroll
    for (int d = 0; d < 6; d++) {
        unsigned P0 = dw[d] & 0x00ff00ffu, P1 = (dw[d] >> 8) & 0x00ff00ffu;
        unsigned t0 = peel(P0), t1 = peel(P0), t2 = peel(P0), t3 = peel(P0), t4 = peel_last(P0);
        unsigned u0 = peel(P1), u1 = peel(P1), u2 = peel(P1), u3 = peel(P1), u4 = peel_last(P1);
        tr[4*d] = t0 | (t1 << 8); tr[4*d+1] = t2 | (t3 << 8);
        tr[4*d+2] = u0 | (u1 << 8); tr[4*d+3] = u2 | (u3 << 8);
        tr[24+d] = t4 | (u4 << 8);
    }
    unsigned P = (tail & 0xffu) | ((tail << 8) & 0xff0000u);
    unsigned h0 = peel(P), h1 = peel(P), h2 = peel(P), h3 = peel_last(P);
    tr[30] = h0 | (h1 << 8); tr[31] = h2 | (h3 << 8);
}

__global__ void k_decode(int iters, int * sink) {
    uint4 qa = make_uint4(threadIdx.x * 2654435761u, 0x12345678u, 0x9abcdef0u, 0x0f0e0d0cu);
    uint2 qb = make_uint2(0x11223344u, 0x55667788u);
    unsigned tail = 0x3c001234u, acc = 0;
    for (int i = 0; i < iters; i++) {
        unsigned tr[32];
        decode_once(qa, qb, tail, tr);
        #pragma unroll
        for (int k = 0; k < 32; k++) acc ^= tr[k];
        qa.x += acc;
    }
    if (sink) sink[threadIdx.x] = (int) acc;
}

template <int NTOK>
__global__ void k_mixed(int iters, int * sink) {
    uint4 qa = make_uint4(threadIdx.x * 2654435761u, 0x12345678u, 0x9abcdef0u, 0x0f0e0d0cu);
    uint2 qb = make_uint2(0x11223344u, 0x55667788u);
    unsigned tail = 0x3c001234u;
    v8i C1[NTOK], C2[NTOK];
    #pragma unroll
    for (int f = 0; f < NTOK; f++) { C1[f] = (v8i){0,0,0,0,0,0,0,0}; C2[f] = C1[f]; }
    v4i B = { (int) (threadIdx.x * 3 + 2), 0x0c0b0a09, 0x08070605, 0x04030201 };
    for (int i = 0; i < iters; i++) {
        unsigned tr[32];
        decode_once(qa, qb, tail, tr);
        #pragma unroll
        for (int kb = 0; kb < 8; kb++) {
            const v4i A = { (int) tr[4*kb], (int) tr[4*kb+1], (int) tr[4*kb+2], (int) tr[4*kb+3] };
            const v4i As = { (int) __builtin_amdgcn_permlanex16(A.x, A.x, 0x76543210u, 0xfedcba98u, false, false), A.y, A.z, A.w };
            #pragma unroll
            for (int f = 0; f < NTOK; f++) {
                C1[f] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, A, true, B, C1[f], false);
                C2[f] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, As, true, B, C2[f], false);
            }
        }
        qa.x += (unsigned) C1[0][0];
    }
    if (sink) { int a = 0; for (int f = 0; f < NTOK; f++) a += C1[f][0] + C2[f][1]; sink[threadIdx.x] = a; }
}

// The candidates' actual inner loop, one wave walking a real weight tile and a real panel-layout
// activation buffer, with the block epilogue. LOADB adds the B fragment loads, EPI the per-block
// scale FMAs, so the three variants separate arithmetic, activation traffic and epilogue.
template <int NTOK, bool LOADB, bool EPI>
__global__ void __launch_bounds__(256) k_inner(int iters, const uint8_t * __restrict__ w,
                                               const int8_t * __restrict__ xq, const float * xs,
                                               const int * xsum, int nb, float * out) {
    __shared__ float scl_s[8 * 32];
    const int lane = threadIdx.x & 31, wave = threadIdx.x >> 5, half = lane >> 4, col = lane & 15;
    float * scl = scl_s + wave * 32;
    float y1[NTOK][8], y2[NTOK][8];
    #pragma unroll
    for (int f = 0; f < NTOK; f++)
        #pragma unroll
        for (int r = 0; r < 8; r++) { y1[f][r] = 0.0f; y2[f][r] = 0.0f; }
    const size_t tile = (blockIdx.x * 8 + wave) % 64;
    const uint8_t * run0 = w + tile * nb * TILE_BLOCK_BYTES;
    const int8_t * xb = xq + (size_t) (blockIdx.x % 4) * nb * 2048 + col * 16;
    for (int i = 0; i < iters; i++) {
        #pragma unroll 1
        for (int b = 0; b < 8; b++) {
            const uint8_t * run = run0 + (size_t) b * TILE_BLOCK_BYTES;
            uint4 qa = *(const uint4 *) (run + tile_off_qs_a(lane));
            uint2 qb = *(const uint2 *) (run + tile_off_qs_b(lane));
            unsigned tail = *(const unsigned *) (run + tile_off_tail(lane));
            unsigned tr[32];
            decode_once(qa, qb, tail, tr);
            scl[(lane & 1) * 16 + (lane >> 1)] = __half2float(__ushort_as_half((unsigned short) (tail >> 16)));
            v8i C1[NTOK], C2[NTOK];
            #pragma unroll
            for (int f = 0; f < NTOK; f++) { C1[f] = (v8i){0,0,0,0,0,0,0,0}; C2[f] = C1[f]; }
            #pragma unroll
            for (int kb = 0; kb < 8; kb++) {
                const v4i A = { (int) tr[4*kb], (int) tr[4*kb+1], (int) tr[4*kb+2], (int) tr[4*kb+3] };
                const v4i As = { (int) __builtin_amdgcn_permlanex16(A.x, A.x, 0x76543210u, 0xfedcba98u, false, false), A.y, A.z, A.w };
                #pragma unroll
                for (int f = 0; f < NTOK; f++) {
                    v4i B;
                    if (LOADB) { const int4 bx = *(const int4 *) (xb + (size_t) (f * nb + b) * 2048 + kb * 256); B = (v4i){ bx.x, bx.y, bx.z, bx.w }; }
                    else B = (v4i){ (int) tr[kb], 0x01020304, 0x05060708, 0x090a0b0c };
                    C1[f] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, A, true, B, C1[f], false);
                    C2[f] = __builtin_amdgcn_wmma_i32_16x16x16_iu8_w32(false, As, true, B, C2[f], false);
                }
            }
            if (EPI) {
                const float4 * s1p = (const float4 *) (scl + half * 16 + 8 * half);
                const float4 * s2p = (const float4 *) (scl + half * 16 + 8 * (half ^ 1));
                const float4 s1a = s1p[0], s1b = s1p[1], s2a = s2p[0], s2b = s2p[1];
                const float s1[8] = { s1a.x, s1a.y, s1a.z, s1a.w, s1b.x, s1b.y, s1b.z, s1b.w };
                const float s2[8] = { s2a.x, s2a.y, s2a.z, s2a.w, s2b.x, s2b.y, s2b.z, s2b.w };
                #pragma unroll
                for (int f = 0; f < NTOK; f++) {
                    const int xsc = xsum[(size_t) b * 256 + f * 16 + col];
                    const float xsb = xs[(size_t) b * 256 + f * 16 + col];
                    #pragma unroll
                    for (int r = 0; r < 8; r++) {
                        y1[f][r] = fmaf((float) (C1[f][r] - xsc), s1[r] * xsb, y1[f][r]);
                        y2[f][r] = fmaf((float) (C2[f][r] - xsc), s2[r] * xsb, y2[f][r]);
                    }
                }
            } else {
                #pragma unroll
                for (int f = 0; f < NTOK; f++)
                    #pragma unroll
                    for (int r = 0; r < 8; r++) { y1[f][r] += (float) C1[f][r]; y2[f][r] += (float) C2[f][r]; }
            }
        }
    }
    if (out) { float a = 0; for (int f = 0; f < NTOK; f++) for (int r = 0; r < 8; r++) a += y1[f][r] + y2[f][r]; out[threadIdx.x] = a; }
}

int main() {
    hipDeviceProp_t prop; (void) hipGetDeviceProperties(&prop, 0);
    printf("# %s, %d HIP processors (WGPs on gfx1151), nominal clock %d kHz\n", prop.gcnArchName, prop.multiProcessorCount, prop.clockRate);
    int * sink = nullptr; (void) hipMalloc(&sink, 4096);
    const int grid = prop.multiProcessorCount * 4, block = 256;
    const double waves = (double) grid * block / 32.0;

    auto timed = [&](const char * name, void (*fn)(int, int *), int iters, double wmma_per_iter, double blocks_per_iter) {
        fn<<<grid, block>>>(8, sink);
        (void) hipDeviceSynchronize();
        hipEvent_t a, b; (void) hipEventCreate(&a); (void) hipEventCreate(&b);
        std::vector<double> ms;
        for (int r = 0; r < 7; r++) {
            (void) hipEventRecord(a, 0);
            fn<<<grid, block>>>(iters, sink);
            (void) hipEventRecord(b, 0);
            (void) hipEventSynchronize(b);
            float t = 0; (void) hipEventElapsedTime(&t, a, b);
            ms.push_back(t);
        }
        std::sort(ms.begin(), ms.end());
        const double s = ms[0] / 1e3;
        const double wmma = waves * iters * wmma_per_iter;
        const double blk = waves * iters * blocks_per_iter;
        printf("%-12s %8.3f ms   wmma/s %9.3f G   TOPS %7.2f   blockdecode/s %8.3f G\n",
               name, ms[0], wmma / s / 1e9, wmma * 4096 * 2 / s / 1e12, blk / s / 1e9);
    };

    timed("wmma", k_wmma, 200000, 4, 0);
    timed("decode", k_decode, 200000, 0, 1);
    timed("mixed-n1", k_mixed<1>, 40000, 16, 1);
    timed("mixed-n2", k_mixed<2>, 40000, 32, 1);
    timed("mixed-n4", k_mixed<4>, 20000, 64, 1);

    // Same inner loop against real buffers: 64 weight tiles of 8 blocks (1.8 MB, L2 resident) and
    // a panel-layout activation buffer.
    const int nb = 8;
    uint8_t * w; int8_t * xq; float * xs, * out; int * xsum;
    (void) hipMalloc(&w, (size_t) 64 * nb * TILE_BLOCK_BYTES);
    (void) hipMalloc(&xq, (size_t) 4 * 4 * nb * 2048);
    (void) hipMalloc(&xs, 4096 * sizeof(float));
    (void) hipMalloc(&xsum, 4096 * sizeof(int));
    (void) hipMalloc(&out, 4096 * sizeof(float));
    (void) hipMemset(w, 0x5a, (size_t) 64 * nb * TILE_BLOCK_BYTES);
    (void) hipMemset(xq, 0x03, (size_t) 4 * 4 * nb * 2048);
    (void) hipMemset(xs, 0, 4096 * sizeof(float));
    (void) hipMemset(xsum, 0, 4096 * sizeof(int));

    auto timed_inner = [&](const char * name, void (*fn)(int, const uint8_t *, const int8_t *, const float *, const int *, int, float *), int iters) {
        fn<<<grid, block>>>(4, w, xq, xs, xsum, nb, out);
        (void) hipDeviceSynchronize();
        hipEvent_t a, b; (void) hipEventCreate(&a); (void) hipEventCreate(&b);
        std::vector<double> ms;
        for (int r = 0; r < 7; r++) {
            (void) hipEventRecord(a, 0);
            fn<<<grid, block>>>(iters, w, xq, xs, xsum, nb, out);
            (void) hipEventRecord(b, 0);
            (void) hipEventSynchronize(b);
            float t = 0; (void) hipEventElapsedTime(&t, a, b);
            ms.push_back(t);
        }
        std::sort(ms.begin(), ms.end());
        const double s = ms[0] / 1e3;
        const double wmma = waves * iters * 8.0 * 32.0;   // 8 blocks, 32 WMMA each at NTOK = 2
        printf("%-12s %8.3f ms   wmma/s %9.3f G   TOPS %7.2f\n", name, ms[0], wmma / s / 1e9, wmma * 4096 * 2 / s / 1e12);
    };
    timed_inner("inner-bare", k_inner<2, false, false>, 5000);
    timed_inner("inner-loadB", k_inner<2, true, false>, 5000);
    timed_inner("inner-full", k_inner<2, true, true>, 5000);
    return 0;
}
