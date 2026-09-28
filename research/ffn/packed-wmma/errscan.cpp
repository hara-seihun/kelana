// Exactness campaign for the packed construction on gfx1151.
//
// V_WMMA_F32_16X16X16_F16 is NOT bit-exact on exactly representable integer operands: the measured
// accumulator deviates from the exact integer p by a few ulp of its own magnitude. The decoder must
// therefore round u as well, and correctness needs |err(p)| < 1/2. This tool runs the real digit
// pipeline over many random tiles, dumps the raw accumulators, and reports the error margin plus
// end-to-end equality against the integer reference.
#include "packed.hpp"
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <random>
#include <vector>
#define HIP(x) do { hipError_t e=(x); if(e!=hipSuccess){printf("HIP %d %s\n",__LINE__,hipGetErrorString(e));exit(1);} } while(0)

__global__ void k_dump(const v16h* A, const v16h* B, float* out, int tiles) {
    int lane = threadIdx.x & 31;
    for (int t = 0; t < tiles; ++t) {
        v8f C = {0,0,0,0,0,0,0,0};
        const v16h* a = A + size_t(t)*SLICES*32; const v16h* b = B + size_t(t)*SLICES*32;
        for (int s = 0; s < SLICES; ++s) C = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(a[s*32+lane], b[s*32+lane], C);
        for (int r = 0; r < 8; ++r) out[(size_t(t)*32+lane)*8+r] = C[r];
    }
}

struct Stats { double worst = 0; long long worst_p = 0; long long nonexact = 0, n = 0; int fail = 0; int maxp = 0; };

static void gen_x(int dist, std::mt19937 &g, int8_t X[KDIM][COLS]) {
    std::uniform_int_distribution<int> full(-128,127), hi(112,127), lohi(-128,-112), near8(-8,8);
    std::bernoulli_distribution coin(0.5);
    for (int k = 0; k < KDIM; ++k) for (int c = 0; c < COLS; ++c) {
        int q;
        switch (dist) {
            case 0: q = full(g); break;                                    // uniform int8
            case 1: q = hi(g); break;                                      // clustered at the top, high plane L1 ~ 1024
            case 2: q = coin(g) ? hi(g) : lohi(g); break;                  // both extremes
            case 3: q = (coin(g) ? 1 : -1) * (120 + (g() & 7)); break;     // |q| in [120,127]
            case 4: q = 16*near8(g) + ((g()&15)-8); break;                 // wide spread of both digits
            default: q = full(g); break;
        }
        X[k][c] = (int8_t) q;
    }
}

int main(int argc, char **argv) {
    const int tiles = argc > 1 ? atoi(argv[1]) : 256;
    std::mt19937 g(20260915);
    std::vector<v16h> A(size_t(tiles)*SLICES*32), B(size_t(tiles)*SLICES*32);
    std::vector<float> fs(size_t(tiles)*32), fp(size_t(tiles)*32);
    std::vector<int8_t> Wall(size_t(tiles)*ROWS*KDIM);
    std::vector<int> Rall(size_t(tiles)*ROWS*COLS);
    std::vector<int8_t> Dlo(size_t(tiles)*KDIM*COLS), Dhi(size_t(tiles)*KDIM*COLS);

    std::uniform_int_distribution<int> tw(-1,1);
    std::bernoulli_distribution dense(0.5);
    for (int t = 0; t < tiles; ++t) {
        int8_t (*W)[KDIM] = (int8_t(*)[KDIM]) &Wall[size_t(t)*ROWS*KDIM];
        bool nozero = dense(g);
        for (int r = 0; r < ROWS; ++r) for (int k = 0; k < KDIM; ++k)
            W[r][k] = nozero ? (int8_t)((g() & 1) ? 1 : -1) : (int8_t) tw(g);
        static int8_t X[KDIM][COLS];
        gen_x(t % 5, g, X);
        Digits d; split_digits(X, d);
        pack_weights_f16(W, &A[size_t(t)*SLICES*32]);
        pack_digits_f16(d, &B[size_t(t)*SLICES*32]);
        pack_factors(d, &fs[size_t(t)*32], &fp[size_t(t)*32]);
        for (int k = 0; k < KDIM; ++k) for (int c = 0; c < COLS; ++c) {
            Dlo[(size_t(t)*KDIM+k)*COLS+c] = d.lo[k][c];
            Dhi[(size_t(t)*KDIM+k)*COLS+c] = d.hi[k][c];
        }
        reference(W, X, (int(*)[COLS]) &Rall[size_t(t)*ROWS*COLS]);
    }

    v16h *dA, *dB; float *dO;
    HIP(hipMalloc(&dA, A.size()*sizeof(v16h))); HIP(hipMalloc(&dB, B.size()*sizeof(v16h)));
    HIP(hipMalloc(&dO, size_t(tiles)*256*sizeof(float)));
    HIP(hipMemcpy(dA, A.data(), A.size()*sizeof(v16h), hipMemcpyHostToDevice));
    HIP(hipMemcpy(dB, B.data(), B.size()*sizeof(v16h), hipMemcpyHostToDevice));
    hipLaunchKernelGGL(k_dump, dim3(1), dim3(32), 0, 0, dA, dB, dO, tiles);
    HIP(hipDeviceSynchronize());
    std::vector<float> got(size_t(tiles)*256);
    HIP(hipMemcpy(got.data(), dO, got.size()*sizeof(float), hipMemcpyDeviceToHost));

    Stats st;
    std::vector<double> ucomb(size_t(tiles)*32*16);
    for (int t = 0; t < tiles; ++t) {
        const int8_t (*W)[KDIM] = (const int8_t(*)[KDIM]) &Wall[size_t(t)*ROWS*KDIM];
        for (int lane = 0; lane < 32; ++lane) for (int r = 0; r < 8; ++r) {
            int m = 2*r + (lane >> 4), j = lane & 15, c = j & 7, plane = j >> 3;
            long long u = 0, v = 0;
            for (int k = 0; k < KDIM; ++k) {
                int dg = plane ? Dhi[(size_t(t)*KDIM+k)*COLS+c] : Dlo[(size_t(t)*KDIM+k)*COLS+c];
                u += W[2*m][k]*dg; v += W[2*m+1][k]*dg;
            }
            long long p = u + (long long) RADIX * v;
            float pg = got[(size_t(t)*32+lane)*8+r];
            double e = (double) pg - (double) p;
            ++st.n;
            if (llabs(p) > st.maxp) st.maxp = (int) llabs(p);
            if (e != 0) { ++st.nonexact; if (fabs(e) > fabs(st.worst)) { st.worst = e; st.worst_p = p; } }
            float vd = nearbyintf(pg * (1.0f/2047.0f));
            float ud = nearbyintf(fmaf(-2047.0f, vd, pg));
            if ((long long) vd != v || (long long) ud != u) ++st.fail;
            ucomb[((size_t(t)*32+lane)*8+r)*2+0] = ud;
            ucomb[((size_t(t)*32+lane)*8+r)*2+1] = vd;
        }
    }
    // end-to-end: recombine the two planes and compare with the integer reference
    int e2e = 0;
    for (int t = 0; t < tiles; ++t) {
        const int *R = &Rall[size_t(t)*ROWS*COLS];
        for (int lane = 0; lane < 32; ++lane) for (int r = 0; r < 8; ++r) for (int part = 0; part < 2; ++part) {
            int partner = lane ^ 8;
            double self = ucomb[((size_t(t)*32+lane)*8+r)*2+part];
            double other = ucomb[((size_t(t)*32+partner)*8+r)*2+part];
            double val = self*fs[size_t(t)*32+lane] + other*fp[size_t(t)*32+lane];
            int row, col; cand_owner(lane, r, part, row, col);
            if (val != (double) R[row*COLS+col]) ++e2e;
        }
    }
    printf("tiles %d: accumulators %lld, non-exact %lld (%.2f%%), worst err %+g at p=%lld (margin to 1/2: %.4f), max|p| %d\n",
           tiles, st.n, st.nonexact, 100.0*st.nonexact/st.n, st.worst, st.worst_p, 0.5 - fabs(st.worst), st.maxp);
    printf("rounded decode failures %d, end-to-end mismatches %d\n", st.fail, e2e);
    return st.fail + e2e;
}
