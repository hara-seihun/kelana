// Exactness of the register-resident PERM observer, and how far one PERM destination byte reaches.
//
// Rates live in rate_bench.hip. This program checks that the map computes exact ternary
// projection sums on the GPU against an integer reference, and enumerates the single-byte
// alphabet argument that fixes the group size at two trits.
#include "kernels.hpp"
#include "../geometry.hpp"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>
#include <algorithm>

template <class T> struct Dev {
    T *p = nullptr;
    explicit Dev(size_t n) { hipMalloc(&p, n * sizeof(T)); hipMemset(p, 0, n * sizeof(T)); }
    ~Dev() { hipFree(p); }
};

static bool check_run(int K, unsigned seed, bool verbose, int *cases) {
    std::vector<int> act(K);
    std::vector<unsigned> sel(K / 2);
    std::vector<int> w(4 * K);
    unsigned rng = seed;
    auto next = [&] { rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5; return rng; };
    for (int k = 0; k < K; ++k) act[k] = int(next() % 15u) - 7;
    for (int r = 0; r < 4; ++r)
        for (int k = 0; k < K; ++k) w[r * K + k] = int(next() % 3u) - 1;
    // selector byte for pattern (w1,w2): table byte order [s, d, a1, a2] then negatives
    auto code = [](int w1, int w2) -> unsigned {
        if (w1 == 1 && w2 == 1) return 0;
        if (w1 == 1 && w2 == -1) return 1;
        if (w1 == 1 && w2 == 0) return 2;
        if (w1 == 0 && w2 == 1) return 3;
        if (w1 == -1 && w2 == -1) return 4;
        if (w1 == -1 && w2 == 1) return 5;
        if (w1 == -1 && w2 == 0) return 6;
        if (w1 == 0 && w2 == -1) return 7;
        return 12;  // (0,0): PERM emits 0x00
    };
    std::vector<int> nnz(4, 0);
    for (int k = 0; k < K; k += 2) {
        unsigned s = 0;
        for (int r = 0; r < 4; ++r) {
            unsigned c = code(w[r * K + k], w[r * K + k + 1]);
            s |= c << (8 * r);
            if (c != 12) ++nnz[r];
        }
        sel[k / 2] = s;
    }
    std::vector<unsigned> actx(K / 4, 0);
    for (int k = 0; k < K; ++k) actx[k / 4] |= unsigned(act[k] + 7) << (8 * (k % 4));
    Dev<unsigned> dsel(sel.size()), dact(K / 4); Dev<int> dout(4);
    hipMemcpy(dsel.p, sel.data(), sel.size() * 4, hipMemcpyHostToDevice);
    hipMemcpy(dact.p, actx.data(), actx.size() * 4, hipMemcpyHostToDevice);
    k_check<<<1, 1>>>(dsel.p, dact.p, dout.p, 4, K);
    int got[4] = {};
    hipMemcpy(got, dout.p, 16, hipMemcpyDeviceToHost);
    bool ok = true;
    for (int r = 0; r < 4; ++r) {
        long ref = 0;
        for (int k = 0; k < K; ++k) ref += long(w[r * K + k]) * act[k];
        long observed = long(got[r]) - 14L * nnz[r];  // offline bias correction
        if (observed != ref) ok = false;
        if (verbose || observed != ref)
            printf("  K=%d row %d: observer %ld, reference %ld, nonzero pairs %d%s\n", K, r,
                   observed, ref, nnz[r], observed == ref ? "" : "   MISMATCH");
        ++*cases;
    }
    if (!verbose) return ok;
    // How far the single-byte alphabet reaches: a PERM destination byte takes at most ten
    // values (eight dynamic operand bytes, 0x00 from selector 12, 0xff from 13). A two-trit
    // group needs nine, so it fits. For three activations the question is how many of the 27
    // signed sums are distinct for the worst A4 triple actually present in the data.
    int worst = 0, wa = 0, wb = 0, wc = 0;
    for (int a = -7; a <= 7; ++a)
        for (int b = a; b <= 7; ++b)
            for (int c = b; c <= 7; ++c) {
                bool seen[64] = {};
                int distinct = 0;
                for (int w1 = -1; w1 <= 1; ++w1)
                    for (int w2 = -1; w2 <= 1; ++w2)
                        for (int w3 = -1; w3 <= 1; ++w3) {
                            int s = w1 * a + w2 * b + w3 * c + 32;
                            if (!seen[s]) { seen[s] = true; ++distinct; }
                        }
                if (distinct > worst) { worst = distinct; wa = a; wb = b; wc = c; }
            }
    printf("  perm byte alphabet 10; two-trit outcomes 9 (fits); worst three-activation triple "
           "(%d,%d,%d) has %d distinct sums\n", wa, wb, wc, worst);
    return ok;
}

int main() {
    if (!std::getenv("KELANA_GPU_RESEARCH_LOCK")) {
        std::fprintf(stderr, "Use ../hardware-run for GPU work\n");
        return 1;
    }
    hipDeviceProp_t prop{};
    hipGetDeviceProperties(&prop, 0);
    const auto geom = kelana_batch::geometry(prop);
    printf("device %s, %d WGP, %d CU, %d SIMD32\n", prop.gcnArchName, geom.wgps, geom.cus,
           geom.simds);
    int cases = 0;
    bool ok = check_run(128, 20260915u, true, &cases);
    for (unsigned trial = 0; trial < 512; ++trial) {
        int K = 8 * (1 + int(trial % 16));  // 8..128 activations, every window length
        ok &= check_run(K, 11u + 7919u * trial, false, &cases);
    }
    printf("%s: %d row cases, K in 8..128\n", ok ? "observer projection exact" : "FAILED", cases);
    return ok ? 0 : 1;
}
